#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load central configurations (.env)
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    source "$PROJECT_ROOT/.env.example"
fi

# Resolve MODELS_DIR (supports absolute paths and paths relative to project root)
if [[ "$MODELS_DIR" == /* ]]; then
    RESOLVED_MODELS_DIR="$MODELS_DIR"
else
    RESOLVED_MODELS_DIR="$PROJECT_ROOT/${MODELS_DIR#./}"
fi
MODEL_PATH="$RESOLVED_MODELS_DIR/$MODEL_FILE"
LOG_FILE="$PROJECT_ROOT/logs/llama.log"
PIDS_DIR="$PROJECT_ROOT/logs/pids"
mkdir -p "$PIDS_DIR"
PID_FILE="$PIDS_DIR/llama.pid"

# ── Helpers ────────────────────────────────────────────────────────────────────

is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        kill -0 "$pid" 2>/dev/null
    else
        return 1
    fi
}

status() {
    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo "✅ llama.cpp is running  (PID $pid, port $LLAMA_PORT)"
    else
        echo "🔴 llama.cpp is NOT running"
    fi
}

stop() {
    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo "🛑 Stopping llama.cpp (PID $pid)..."
        kill "$pid" && rm -f "$PID_FILE"
        echo "   Done."
    else
        echo "⚠️  llama.cpp is not running."
    fi
}

start() {
    # ── Pre-flight checks ───────────────────────────────────────────────────────

    if ! command -v llama-server &> /dev/null; then
        echo "❌ Error: llama-server not found in PATH."
        echo "=> Please run: ./scripts/install-deps.sh"
        exit 1
    fi

    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo "⚠️  llama.cpp is already running (PID $pid, port $LLAMA_PORT)."
        echo "   Use '$0 stop' to stop it first, or '$0 restart' to restart."
        exit 0
    fi

    if [ ! -f "$MODEL_PATH" ]; then
        echo "❌ Error: model not found at $MODEL_PATH"
        echo "=> Please set MODEL_FILE in .env and place the .gguf file in models/"
        exit 1
    fi

    mkdir -p "$PROJECT_ROOT/logs"

    # ── Launch ──────────────────────────────────────────────────────────────────

    echo "🚀 Starting llama.cpp server..."
    echo "   Model : $MODEL_FILE"
    echo "   Port  : $LLAMA_PORT"

    llama-server \
        -m "$MODEL_PATH" \
        --host 127.0.0.1 \
        --port "$LLAMA_PORT" \
        -ngl 99 \
        -c 16384 \
        -t 8 \
        --flash-attn auto \
        --cache-type-k q8_0 \
        --temp 0.7 \
        > "$LOG_FILE" 2>&1 &

    local pid=$!
    echo "$pid" > "$PID_FILE"

    # ── Wait for the server to be ready ────────────────────────────────────────

    echo -n "   Waiting for server to be ready"
    local retries=30
    while [ $retries -gt 0 ]; do
        if curl -sf "http://127.0.0.1:$LLAMA_PORT/health" > /dev/null 2>&1; then
            echo ""
            echo "✅ llama.cpp is running! (PID $pid, port $LLAMA_PORT)"
            echo "   Logs: $LOG_FILE"
            return 0
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            echo ""
            echo "❌ llama.cpp crashed on startup. Last log lines:"
            tail -20 "$LOG_FILE"
            rm -f "$PID_FILE"
            exit 1
        fi
        echo -n "."
        sleep 1
        (( retries-- ))
    done

    echo ""
    echo "⚠️  Server did not respond after 30s (still may be loading)."
    echo "   PID: $pid — check logs: $LOG_FILE"
}

# ── Entry point ────────────────────────────────────────────────────────────────

case "${1:-start}" in
    start)   start   ;;
    stop)    stop    ;;
    restart) stop; sleep 1; start ;;
    status)  status  ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
