#!/usr/bin/env bash

# =================================================================
# AI Model Download Script (legacy)
# =================================================================
# Prefer using llmfit to select and install the right model for your machine.
#
# Setup options:
#   1. As git submodule in parent directory:
#      cd ..
#      git submodule add https://github.com/AlexsJones/llmfit.git
#      cd llmfit && cargo build --release
#
#   2. Or install globally:
#      cargo install llmfit
#
# Auto-detection checks (in order):
#   - Is llmfit in PATH?
#   - Is it at ../llmfit/target/release/llmfit?
#
# Keep this script only as a fallback for direct/manual downloads.
# =================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Try to locate llmfit
find_llmfit() {
    if command -v llmfit &> /dev/null; then
        command -v llmfit
        return 0
    fi
    
    local parent_dir
    parent_dir="$(cd "$PROJECT_ROOT/.." && pwd)"
    
    if [ -f "$parent_dir/llmfit/target/release/llmfit" ]; then
        echo "$parent_dir/llmfit/target/release/llmfit"
        return 0
    fi
    
    return 1
}

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
echo "  Local GGUF Model Installer (legacy fallback)"
echo "==========================================================="
echo ""
echo "ℹ️  Recommended: Use llmfit to auto-detect best model:"

LLMFIT_PATH="$(find_llmfit 2>/dev/null || echo '')"
if [ -n "$LLMFIT_PATH" ]; then
    echo "   ✅ llmfit found at: $LLMFIT_PATH"
    echo ""
    echo "   Add to ~/.zshrc or ~/.bashrc:"
    echo "   alias llmfit_sidekick='export LLMFIT_MODELS_DIR=\"$RESOLVED_MODELS_DIR\" && $LLMFIT_PATH'"
    echo ""
    echo "   Then reload and run:"
    echo "   source ~/.zshrc && llmfit_sidekick"
else
    echo "   ❌ llmfit not found."
    echo ""
    echo "   Install it (choose one):"
    echo "   Option 1 - As submodule: cd .. && git submodule add https://github.com/AlexsJones/llmfit.git"
    echo "   Option 2 - Globally:     cargo install llmfit"
    echo ""
    echo "   After install, create alias:"
    echo "   LLMFIT_PATH=\$(command -v llmfit || echo '../llmfit/target/release/llmfit')"
    echo "   alias llmfit_sidekick='export LLMFIT_MODELS_DIR=\"$RESOLVED_MODELS_DIR\" && \$LLMFIT_PATH'"
fi
echo ""
echo "Continuing with direct download fallback for: $MODEL_FILE"
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
