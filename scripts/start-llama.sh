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

# llama.cpp tuning defaults (can be overridden in .env)
LLAMA_NGL="${LLAMA_NGL:-35}"
LLAMA_CTX="${LLAMA_CTX:-4096}"
LLAMA_BATCH="${LLAMA_BATCH:-256}"
LLAMA_UBATCH="${LLAMA_UBATCH:-256}"
LLAMA_THREADS="${LLAMA_THREADS:-8}"
LLAMA_FA="${LLAMA_FA:-true}"
LLAMA_REASONING_BUDGET="${LLAMA_REASONING_BUDGET:-}"
LLAMA_REASONING="${LLAMA_REASONING:-}"

LOG_FILE="$PROJECT_ROOT/logs/llama.log"
PIDS_DIR="$PROJECT_ROOT/logs/pids"
mkdir -p "$PIDS_DIR"
PID_FILE="$PIDS_DIR/llama.pid"
LAST_MODEL_FILE="$PIDS_DIR/last-model.txt"

prepare_log_file() {
    mkdir -p "$PROJECT_ROOT/logs"

    if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
        local ts
        ts="$(date +%Y%m%d-%H%M%S)"
        local archived_log="$PROJECT_ROOT/logs/llama-${ts}.log"
        mv "$LOG_FILE" "$archived_log"
        echo "🧹 Rotated previous log to: $archived_log"
    fi

    : > "$LOG_FILE"
}

list_available_models() {
    if [ ! -d "$RESOLVED_MODELS_DIR" ]; then
        return 0
    fi

    find "$RESOLVED_MODELS_DIR" -maxdepth 1 -type f -name "*.gguf" -print | while read -r file; do
        basename "$file"
    done | sort
}

is_interactive_shell() {
    [ -t 0 ] && [ -t 1 ]
}

select_model() {
    local selected_model=""
    local env_model_path=""
    local last_model=""
    local -a available_models=()

    while IFS= read -r model; do
        [ -n "$model" ] && available_models+=("$model")
    done < <(list_available_models)

    if [ ${#available_models[@]} -eq 0 ]; then
        echo ""
        echo "❌ Error: no .gguf models found in $RESOLVED_MODELS_DIR"
        echo "=> Download one with: ./scripts/download-model.sh"
        return 1
    fi

    env_model_path="$RESOLVED_MODELS_DIR/$MODEL_FILE"
    if [ -n "$MODEL_FILE" ] && [ -f "$env_model_path" ]; then
        selected_model="$MODEL_FILE"
    fi

    if [ -z "$selected_model" ] && [ -f "$LAST_MODEL_FILE" ]; then
        last_model="$(cat "$LAST_MODEL_FILE" 2>/dev/null)"
        if [ -n "$last_model" ] && [ -f "$RESOLVED_MODELS_DIR/$last_model" ]; then
            selected_model="$last_model"
        fi
    fi

    if [ -z "$selected_model" ]; then
        if [ ${#available_models[@]} -eq 1 ]; then
            selected_model="${available_models[0]}"
        elif is_interactive_shell; then
            echo "🧠 Multiple models found. Choose one:"
            local i=1
            for model in "${available_models[@]}"; do
                echo "   $i) $model"
                ((i++))
            done

            local choice=""
            while true; do
                read -rp "Select model [1-${#available_models[@]}]: " choice
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#available_models[@]} ]; then
                    selected_model="${available_models[$((choice-1))]}"
                    break
                fi
                echo "Invalid choice. Try again."
            done
        else
            selected_model="${available_models[0]}"
        fi
    fi

    printf "%s" "$selected_model"
}

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

is_port_in_use() {
    lsof -nP -iTCP:"$LLAMA_PORT" -sTCP:LISTEN >/dev/null 2>&1
}

is_healthy() {
    curl -sf "http://127.0.0.1:$LLAMA_PORT/health" > /dev/null 2>&1
}

supports_reasoning_budget() {
    llama-server -h 2>&1 | grep -q -- "--reasoning-budget"
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
    local force_restart="${1:-false}"

    # ── Pre-flight checks ───────────────────────────────────────────────────────

    if ! command -v llama-server &> /dev/null; then
        echo "❌ Error: llama-server not found in PATH."
        echo "=> Please run: ./scripts/install-deps.sh"
        exit 1
    fi

    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        if is_port_in_use; then
            if [ "$force_restart" = "true" ]; then
                echo "🔄 Restart requested. Stopping current llama.cpp (PID $pid)..."
                stop
                sleep 1
            elif is_healthy; then
                echo "✅ llama.cpp is already running and healthy (PID $pid, port $LLAMA_PORT)."
                return 0
            else
                echo "⚠️  llama.cpp is running (PID $pid) but not healthy yet. Restarting..."
                stop
                sleep 1
            fi
        fi

        if [ -f "$PID_FILE" ]; then
            echo "⚠️  Stale PID file detected (PID $pid is alive but port $LLAMA_PORT is not listening)."
            echo "   Removing stale PID file and continuing startup..."
            rm -f "$PID_FILE"
        fi
    fi

    if is_port_in_use; then
        echo "❌ Error: port $LLAMA_PORT is already in use by another process."
        echo "=> Free the port or change LLAMA_PORT in .env"
        lsof -nP -iTCP:"$LLAMA_PORT" -sTCP:LISTEN | tail -n +2
        exit 1
    fi

    local selected_model
    selected_model="$(select_model)" || exit 1
    local model_path="$RESOLVED_MODELS_DIR/$selected_model"

    if [ ! -f "$model_path" ]; then
        echo "❌ Error: model not found at $model_path"
        echo "=> Please set MODEL_FILE in .env or place a .gguf file in $RESOLVED_MODELS_DIR"
        exit 1
    fi

    printf "%s" "$selected_model" > "$LAST_MODEL_FILE"

    prepare_log_file

    # ── Launch ──────────────────────────────────────────────────────────────────

    echo "🚀 Starting llama.cpp server..."
    echo "   Model : $selected_model"
    echo "   Port  : $LLAMA_PORT"

    if [ "$LLAMA_CTX" -gt 8192 ] 2>/dev/null; then
        echo "   ⚠️  High context configured (LLAMA_CTX=$LLAMA_CTX)."
        echo "   If you see Metal OOM errors, reduce LLAMA_CTX to 4096."
    fi

    echo "   Tuning: ngl=$LLAMA_NGL ctx=$LLAMA_CTX b=$LLAMA_BATCH ub=$LLAMA_UBATCH t=$LLAMA_THREADS fa=$LLAMA_FA"

    local -a llama_cmd=(
        llama-server
        -m "$model_path"
        --host 127.0.0.1
        --port "$LLAMA_PORT"
        -ngl "$LLAMA_NGL"
        -c "$LLAMA_CTX"
        -b "$LLAMA_BATCH"
        -ub "$LLAMA_UBATCH"
        -t "$LLAMA_THREADS"
        --cache-type-k q8_0
        --temp 0.7
    )

    local llama_fa_normalized
    local llama_fa_value
    llama_fa_normalized="$(printf '%s' "$LLAMA_FA" | tr '[:upper:]' '[:lower:]')"

    case "$llama_fa_normalized" in
        true|1|yes|on)
            llama_fa_value="on"
            ;;
        false|0|no|off)
            llama_fa_value="off"
            ;;
        auto)
            llama_fa_value="auto"
            ;;
        *)
            echo "   ⚠️  Invalid LLAMA_FA='$LLAMA_FA'. Falling back to auto."
            llama_fa_value="auto"
            ;;
    esac

    llama_cmd+=( --flash-attn "$llama_fa_value" )

    if [ -n "$LLAMA_REASONING" ]; then
        llama_cmd+=( --reasoning "$LLAMA_REASONING" )
    fi

    if [ -n "$LLAMA_REASONING_BUDGET" ]; then
        if supports_reasoning_budget; then
            llama_cmd+=( --reasoning-budget "$LLAMA_REASONING_BUDGET" )
        else
            echo "   ⚠️  LLAMA_REASONING_BUDGET is set, but this llama-server does not support --reasoning-budget. Ignoring it."
        fi
    fi

    "${llama_cmd[@]}" > "$LOG_FILE" 2>&1 &

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
    start)   start false ;;
    stop)    stop    ;;
    restart) start true ;;
    status)  status  ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
