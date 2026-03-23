#!/usr/bin/env bash

# =================================================================
# AI Model Download Script
# =================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load variables
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

MODEL_URL="https://huggingface.co/$MODEL_REPO/resolve/main/$MODEL_FILE"

echo "==========================================================="
echo "  Local GGUF Model Installer"
echo "  Downloading: $MODEL_FILE"
echo "==========================================================="
echo ""
echo "=> Models directory: $RESOLVED_MODELS_DIR"

mkdir -p "$RESOLVED_MODELS_DIR"

if [ -f "$RESOLVED_MODELS_DIR/$MODEL_FILE" ]; then
    echo "=> ✅ Model already exists at: $RESOLVED_MODELS_DIR/$MODEL_FILE"
    echo "=> No download required. You are all set!"
    exit 0
fi

echo "=> Downloading from: $MODEL_REPO"
echo "=> Saving to: $RESOLVED_MODELS_DIR/$MODEL_FILE"
echo "=> LFM2-24B is ~24GB. This will take a while!"
echo ""

curl -L --progress-bar -o "$RESOLVED_MODELS_DIR/$MODEL_FILE" "$MODEL_URL"

if [ $? -eq 0 ]; then
    echo ""
    echo "=> ✅ Download completed successfully!"
    echo "=> You can now run: ./scripts/start-all.sh"
else
    echo ""
    echo "=> ❌ Error during download."
    rm -f "$RESOLVED_MODELS_DIR/$MODEL_FILE"
    exit 1
fi
