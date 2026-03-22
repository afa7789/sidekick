#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIDS_DIR="$PROJECT_ROOT/logs/pids"

echo "=> Shutting down all local AI Stack services..."

# Stop llama.cpp using its PID file
if [ -f "$PIDS_DIR/llama.pid" ]; then
    pid=$(cat "$PIDS_DIR/llama.pid")
    if kill -0 "$pid" 2>/dev/null; then
        echo "   Stopping llama.cpp (PID $pid)..."
        kill "$pid" && rm -f "$PIDS_DIR/llama.pid"
    else
        rm -f "$PIDS_DIR/llama.pid"
    fi
fi

# Stop opencode using its PID file
if [ -f "$PIDS_DIR/opencode.pid" ]; then
    pid=$(cat "$PIDS_DIR/opencode.pid")
    if kill -0 "$pid" 2>/dev/null; then
        echo "   Stopping opencode (PID $pid)..."
        kill "$pid" && rm -f "$PIDS_DIR/opencode.pid"
    else
        rm -f "$PIDS_DIR/opencode.pid"
    fi
fi

echo "=> Everything has been successfully terminated."
