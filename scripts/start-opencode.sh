#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIDS_DIR="$PROJECT_ROOT/logs/pids"
mkdir -p "$PIDS_DIR"
PID_FILE="$PIDS_DIR/opencode.pid"

echo "=> Starting OpenCode CLI..."
opencode &
echo $! > "$PID_FILE"
