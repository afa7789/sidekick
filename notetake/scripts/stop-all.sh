#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIDS_DIR="$PROJECT_ROOT/logs/pids"

echo "=> Shutting down all Sidekick services..."

# Stop llama.cpp
if [ -f "$PIDS_DIR/llama.pid" ]; then
    pid=$(cat "$PIDS_DIR/llama.pid")
    if kill -0 "$pid" 2>/dev/null; then
        echo "   Stopping llama.cpp (PID $pid)..."
        kill "$pid" && rm -f "$PIDS_DIR/llama.pid"
    else
        rm -f "$PIDS_DIR/llama.pid"
    fi
fi

# Stop Silverbullet
if [ -f "$PIDS_DIR/silverbullet.pid" ]; then
    pid=$(cat "$PIDS_DIR/silverbullet.pid")
    if kill -0 "$pid" 2>/dev/null; then
        echo "   Stopping Silverbullet (PID $pid)..."
        kill "$pid" && rm -f "$PIDS_DIR/silverbullet.pid"
    else
        rm -f "$PIDS_DIR/silverbullet.pid"
    fi
fi

echo "=> Everything has been successfully terminated."
