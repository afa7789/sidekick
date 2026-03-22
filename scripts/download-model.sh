#!/usr/bin/env bash

# =================================================================
# AI Model Download Script
# =================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL_DIR="$PROJECT_ROOT/models"

# Load variables (Read from .env if it exists, otherwise use .env.example)
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    source "$PROJECT_ROOT/.env.example"
fi

MODEL_URL="https://huggingface.co/$MODEL_REPO/resolve/main/$MODEL_FILE"

echo "==========================================================="
echo "  Local GGUF Model Installer"
echo "  Downloading: $MODEL_FILE"
echo "==========================================================="
echo ""
echo "Preparing the models folder..."

mkdir -p "$MODEL_DIR"

if [ -f "$MODEL_DIR/$MODEL_FILE" ]; then
    echo "=> ✅ Model already exists at: $MODEL_DIR/$MODEL_FILE"
    echo "=> No download required. You are all set!"
    exit 0
fi

echo "=> Downloading from repository: $MODEL_REPO"
echo "=> Saving to: $MODEL_DIR/$MODEL_FILE"
echo "=> Models are usually 5GB to 10GB. This might take a few minutes!"
echo ""

# Download tracking the progress
curl -L -o "$MODEL_DIR/$MODEL_FILE" "$MODEL_URL"

if [ $? -eq 0 ]; then
    echo ""
    echo "=> ✅ Download completed successfully!"
    echo "=> You can now start your local AI Stack!"
else
    echo ""
    echo "=> ❌ Error during download. Checking for network issues..."
    rm -f "$MODEL_DIR/$MODEL_FILE" # Clean partial corrupted file
    exit 1
fi
