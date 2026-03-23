#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load central configurations (.env)
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    source "$PROJECT_ROOT/.env.example"
fi

LOG_FILE="$PROJECT_ROOT/logs/silverbullet.log"
PIDS_DIR="$PROJECT_ROOT/logs/pids"
mkdir -p "$PIDS_DIR"
PID_FILE="$PIDS_DIR/silverbullet.pid"

# Resolve notes path relative to project root
NOTES_PATH="$PROJECT_ROOT/${NOTES_DIR#./}"

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
        echo "✅ Silverbullet is running  (PID $pid, port $NOTES_PORT)"
        echo "   Open: http://localhost:$NOTES_PORT"
    else
        echo "🔴 Silverbullet is NOT running"
    fi
}

stop() {
    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo "🛑 Stopping Silverbullet (PID $pid)..."
        kill "$pid" && rm -f "$PID_FILE"
        echo "   Done."
    else
        echo "⚠️  Silverbullet is not running."
    fi
}

start() {
    # ── Pre-flight checks ───────────────────────────────────────────────────────

    if ! command -v npx &> /dev/null; then
        echo "❌ Error: npx not found. Please install Node.js."
        exit 1
    fi

    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo "⚠️  Silverbullet is already running (PID $pid, port $NOTES_PORT)."
        echo "   Use '$0 stop' to stop it first, or '$0 restart' to restart."
        exit 0
    fi

    mkdir -p "$NOTES_PATH"
    mkdir -p "$PROJECT_ROOT/logs"

    # ── Launch ──────────────────────────────────────────────────────────────────

    echo "🚀 Starting Silverbullet (notes UI)..."
    echo "   Notes : $NOTES_PATH"
    echo "   Port  : $NOTES_PORT"

    SB_PORT="$NOTES_PORT" npx @silverbulletmd/silverbullet "$NOTES_PATH" \
        > "$LOG_FILE" 2>&1 &

    local pid=$!
    echo "$pid" > "$PID_FILE"

    # ── Wait for the server to be ready ────────────────────────────────────────

    echo -n "   Waiting for server to be ready"
    local retries=30
    while [ $retries -gt 0 ]; do
        if curl -sf "http://127.0.0.1:$NOTES_PORT" > /dev/null 2>&1; then
            echo ""
            echo "✅ Silverbullet is running! (PID $pid)"
            echo "   Open: http://localhost:$NOTES_PORT"
            echo "   Logs: $LOG_FILE"
            return 0
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            echo ""
            echo "❌ Silverbullet crashed on startup. Last log lines:"
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
