#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load central configurations (.env)
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    source "$PROJECT_ROOT/.env.example"
fi

echo "=== STARTING SIDEKICK STACK ==="

# Start llama.cpp if not already running
if curl -s "http://localhost:$LLAMA_PORT/health" > /dev/null 2>&1; then
    echo "=> llama.cpp server is already online on port $LLAMA_PORT."
else
    echo "=> Starting llama.cpp server..."
    "$PROJECT_ROOT/scripts/start-llama.sh"
fi

echo ""

# Start Silverbullet if not already running
if curl -s "http://localhost:$NOTES_PORT" > /dev/null 2>&1; then
    echo "=> Silverbullet is already online on port $NOTES_PORT."
else
    echo "=> Starting Silverbullet (notes UI)..."
    "$PROJECT_ROOT/scripts/start-silverbullet.sh"
fi

echo ""
echo "=== SIDEKICK IS READY ==="
echo "   Notes UI : http://localhost:$NOTES_PORT"
echo "   LLM API  : http://localhost:$LLAMA_PORT"
echo ""
echo "   Use './scripts/agent.sh notes/roadmap.md' to improve a note with AI."
echo "   Use './scripts/stop-all.sh' to shut everything down."
