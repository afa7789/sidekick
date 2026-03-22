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

cd ~/llama.cpp-bin || { echo "❌ error: llama.cpp-bin directory not found. Please install llama.cpp."; exit 1; }

# Execute the local GGUF server and pipe logs to the background
./llama-server \
  -m "$MODEL_PATH" \
  --host 127.0.0.1 \
  --port $PORT \
  -ngl 99 \
  -c 16384 \
  -t 8 \
  --flash-attn \
  --cache-type-k q8_0 \
  --temp 0.7 \
  > "$PROJECT_ROOT/logs/llama.log" 2>&1
