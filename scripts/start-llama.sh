#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load central configurations (.env)
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    source "$PROJECT_ROOT/.env.example"
fi

MODEL_PATH="$PROJECT_ROOT/models/$MODEL_FILE"

echo "Accelerating llama.cpp server..."
echo "Using model: $MODEL_FILE on port $PORT"

# Verify if llama-server is installed
if ! command -v llama-server &> /dev/null; then
    echo "❌ error: llama-server not found in PATH."
    echo "=> Please run: ./scripts/install-deps.sh"
    exit 1
fi

# Execute the local GGUF server and pipe logs to the background
llama-server \
  -m "$MODEL_PATH" \
  --host 127.0.0.1 \
  --port $PORT \
  -ngl 99 \
  -c 16384 \
  -t 8 \
  --flash-attn auto \
  --cache-type-k q8_0 \
  --temp 0.7 \
  > "$PROJECT_ROOT/logs/llama.log" 2>&1
