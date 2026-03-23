#!/bin/bash
# sync-opencode-models.sh - Sync local models with opencode config
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env for OPENROUTER_API_KEY and MODELS_DIR
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    source "$PROJECT_ROOT/.env.example"
fi

CONFIG_DIR="${HOME}/.config/opencode"
CONFIG_FILE="${CONFIG_DIR}/opencode.json"

# Resolve MODEL_DIR from MODELS_DIR in .env
if [[ "${MODELS_DIR}" == /* ]]; then
    MODEL_DIR="${MODELS_DIR}"
else
    MODEL_DIR="$(cd "$PROJECT_ROOT/${MODELS_DIR#./}" 2>/dev/null && pwd || echo "$PROJECT_ROOT/${MODELS_DIR#./}")"
fi

list_models() {
    if [ -d "$MODEL_DIR" ]; then
        ls -1 "$MODEL_DIR"/*.gguf 2>/dev/null | while read f; do
            basename "$f"
        done
    fi
}

list_running_servers() {
    ps aux | grep -E "llama-server|llama\.cpp" | grep -v grep | awk '{
        for (i=1; i<=NF; i++) {
            if ($i ~ /--port/) port=$(i+1)
            if ($i ~ /\.gguf/) model=$i
        }
        gsub(/.*\//, "", model)
        print port":"model
    }'
}

update_config() {
    local port="$1"
    local model="$2"

    mkdir -p "$CONFIG_DIR"

    local openrouter_block=""
    if [ -n "${OPENROUTER_API_KEY}" ] && [ "${OPENROUTER_API_KEY}" != "your-openrouter-api-key" ]; then
        openrouter_block=",
    \"openrouter\": {
      \"options\": {
        \"baseURL\": \"https://openrouter.ai/api/v1\",
        \"apiKey\": \"${OPENROUTER_API_KEY}\"
      }
    }"
    fi

    cat > "$CONFIG_FILE" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "local": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama.cpp (local)",
      "options": {
        "baseURL": "http://127.0.0.1:${port}/v1"
      },
      "models": {
        "${model}": {
          "name": "${model%.gguf}"
        }
      }
    }${openrouter_block}
  },
  "model": "openrouter/free",
  "small_model": "openrouter/free"
}
EOF

    if [ -n "$openrouter_block" ]; then
        echo "Updated config: port=${port}, model=${model}, openrouter=enabled"
    else
        echo "Updated config: port=${port}, model=${model}"
    fi
}

echo "=== opencode model sync ==="
echo ""

MODELS=($(list_models))
RUNNING=($(list_running_servers))

echo "Available models (${#MODELS[@]}):"
for m in "${MODELS[@]}"; do echo "  - $m"; done
echo ""

echo "Running servers (${#RUNNING[@]}):"
for r in "${RUNNING[@]}"; do echo "  - $r"; done
echo ""

if [ ${#RUNNING[@]} -eq 1 ]; then
    IFS=':' read -r port model <<< "${RUNNING[0]}"
    update_config "$port" "$model"
elif [ ${#RUNNING[@]} -gt 1 ]; then
    echo "Multiple servers running. Using first one."
    IFS=':' read -r port model <<< "${RUNNING[0]}"
    update_config "$port" "$model"
elif [ ${#MODELS[@]} -gt 0 ]; then
    echo "No server running, but models available."
    update_config 8080 "${MODELS[0]}"
    echo ""
    echo "To start server manually:"
    echo "  llama-server -m ${MODEL_DIR}/${MODELS[0]} --host 127.0.0.1 --port 8080 -ngl 99 -c 16384"
else
    echo "No models found in ${MODEL_DIR}"
fi

echo ""
echo "Current opencode model: $(grep '"model"' "$CONFIG_FILE" 2>/dev/null | grep -o 'local/[^"]*' || echo 'none')"
