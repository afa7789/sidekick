#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load central configurations (.env)
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    source "$PROJECT_ROOT/.env.example"
fi

echo "=== STARTING LOCAL AI STACK ==="

# Check if llama.cpp server is already running on the correct port
if curl -s http://localhost:$PORT/v1/models > /dev/null; then
  echo "=> llama.cpp server is already online on port $PORT."
else
  echo "=> Starting llama.cpp server in the background..."
  nohup "$PROJECT_ROOT/scripts/start-llama.sh" &
  echo "=> Waiting 10 seconds for the model to load into Unified Memory..."
  sleep 10
fi

echo "=> Launching OpenCode CLI..."
opencode
