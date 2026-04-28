#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    source "$PROJECT_ROOT/.env.example"
fi

VL_MODEL="models/Qwen2-VL-7B-Instruct-Q4_K_M.gguf"
VL_MMPROJ="models/Qwen2-VL-7B-Instruct-vision-encoder.gguf"
VL_PORT="${VL_PORT:-8080}"
VL_NGL="${VL_NGL:-99}"
VL_CTX="${VL_CTX:-3000}"

LOG_FILE="$PROJECT_ROOT/logs/vl.log"
PIDS_DIR="$PROJECT_ROOT/logs/pids"
mkdir -p "$PIDS_DIR"
PID_FILE="$PIDS_DIR/vl.pid"

prepare_log_file() {
    mkdir -p "$PROJECT_ROOT/logs"
    if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
        local ts
        ts="$(date +%Y%m%d-%H%M%S)"
        mv "$LOG_FILE" "$PROJECT_ROOT/logs/vl-${ts}.log"
    fi
    : > "$LOG_FILE"
}

is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        kill -0 "$pid" 2>/dev/null
    else
        return 1
    fi
}

is_port_in_use() {
    lsof -nP -iTCP:"$VL_PORT" -sTCP:LISTEN >/dev/null 2>&1
}

is_healthy() {
    curl -sf "http://127.0.0.1:$VL_PORT/health" > /dev/null 2>&1
}

status() {
    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo "✅ Qwen-VL is running (PID $pid, port $VL_PORT)"
    else
        echo "🔴 Qwen-VL is NOT running"
    fi
}

stop() {
    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo "🛑 Stopping Qwen-VL (PID $pid)..."
        kill "$pid" && rm -f "$PID_FILE"
        echo "   Done."
    else
        echo "⚠️  Qwen-VL is not running."
    fi
}

download() {
    echo "📥 Downloading Qwen-VL models..."

    if [ -f "$PROJECT_ROOT/$VL_MODEL" ]; then
        echo "   $VL_MODEL already exists, skipping download."
    else
        echo "   Downloading $VL_MODEL (~5GB)..."
        curl -L -o "$PROJECT_ROOT/$VL_MODEL" \
            "https://huggingface.co/Qwen/Qwen2-VL-7B-Instruct-GGUF/resolve/main/Qwen2-VL-7B-Instruct-Q4_K_M.gguf"
    fi

    if [ -f "$PROJECT_ROOT/$VL_MMPROJ" ]; then
        echo "   $VL_MMPROJ already exists, skipping download."
    else
        echo "   Downloading $VL_MMPROJ..."
        curl -L -o "$PROJECT_ROOT/$VL_MMPROJ" \
            "https://huggingface.co/Qwen/Qwen2-VL-7B-Instruct-GGUF/resolve/main/mmproj-model-f16.gguf"
    fi

    echo "   Download complete!"
}

start() {
    local force_restart="${1:-false}"

    if ! command -v llama-server &> /dev/null; then
        echo "❌ Error: llama-server not found in PATH."
        echo "=> Please run: ./scripts/install-deps.sh"
        exit 1
    fi

    if [ ! -f "$PROJECT_ROOT/$VL_MODEL" ]; then
        echo "❌ Error: model not found at $PROJECT_ROOT/$VL_MODEL"
        echo "=> Run: $0 download"
        exit 1
    fi

    if [ ! -f "$PROJECT_ROOT/$VL_MMPROJ" ]; then
        echo "❌ Error: mmproj not found at $PROJECT_ROOT/$VL_MMPROJ"
        echo "=> Run: $0 download"
        exit 1
    fi

    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        if is_port_in_use; then
            if [ "$force_restart" = "true" ]; then
                echo "🔄 Restart requested. Stopping current Qwen-VL (PID $pid)..."
                stop
                sleep 1
            elif is_healthy; then
                echo "✅ Qwen-VL is already running and healthy (PID $pid, port $VL_PORT)."
                return 0
            else
                echo "⚠️  Qwen-VL is running (PID $pid) but not healthy. Restarting..."
                stop
                sleep 1
            fi
        fi
        rm -f "$PID_FILE"
    fi

    if is_port_in_use; then
        echo "❌ Error: port $VL_PORT is already in use."
        lsof -nP -iTCP:"$VL_PORT" -sTCP:LISTEN | tail -n +2
        exit 1
    fi

    prepare_log_file

    echo "🚀 Starting Qwen-VL server..."
    echo "   Model  : $VL_MODEL"
    echo "   MMPROJ : $VL_MMPROJ"
    echo "   Port   : $VL_PORT"
    echo "   Tuning : ngl=$VL_NGL ctx=$VL_CTX"

    llama-server \
        -m "$PROJECT_ROOT/$VL_MODEL" \
        --mmproj "$PROJECT_ROOT/$VL_MMPROJ" \
        --host 127.0.0.1 \
        --port "$VL_PORT" \
        -ngl "$VL_NGL" \
        -c "$VL_CTX" \
        > "$LOG_FILE" 2>&1 &

    local pid=$!
    echo "$pid" > "$PID_FILE"

    echo -n "   Waiting for server to be ready"
    local retries=60
    while [ $retries -gt 0 ]; do
        if curl -sf "http://127.0.0.1:$VL_PORT/health" > /dev/null 2>&1; then
            echo ""
            echo "✅ Qwen-VL is running! (PID $pid, port $VL_PORT)"
            echo "   Logs: $LOG_FILE"
            return 0
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            echo ""
            echo "❌ Qwen-VL crashed on startup. Last log lines:"
            tail -20 "$LOG_FILE"
            rm -f "$PID_FILE"
            exit 1
        fi
        echo -n "."
        sleep 1
        (( retries-- ))
    done

    echo ""
    echo "⚠️  Server did not respond after 60s."
    echo "   PID: $pid — check logs: $LOG_FILE"
}

case "${1:-start}" in
    start)    start false ;;
    stop)     stop ;;
    restart)  start true ;;
    status)   status ;;
    download) download ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|download}"
        exit 1
        ;;
esac
