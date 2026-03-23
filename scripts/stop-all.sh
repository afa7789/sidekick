#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIDS_DIR="$PROJECT_ROOT/logs/pids"

echo "=> Shutting down all Sidekick services..."

for service in llama silverbullet opencode; do
    if [ -f "$PIDS_DIR/${service}.pid" ]; then
        pid=$(cat "$PIDS_DIR/${service}.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo "   Stopping $service (PID $pid)..."
            kill "$pid" && rm -f "$PIDS_DIR/${service}.pid"
        else
            rm -f "$PIDS_DIR/${service}.pid"
        fi
    fi
done

echo "=> Everything has been successfully terminated."
