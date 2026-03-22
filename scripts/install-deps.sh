#!/usr/bin/env bash

# =================================================================
# AI Stack Dependencies Installer
# =================================================================

echo "==========================================================="
echo "  Installing Local AI Stack Dependencies                   "
echo "==========================================================="
echo ""

# 1. Install llama.cpp (The engine)
echo "=> [1/2] Installing llama.cpp (Engine)..."
if command -v brew >/dev/null 2>&1; then
    brew install llama.cpp
else
    echo "❌ Error: Homebrew is not installed. Please install Homebrew first:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi
echo "=> ✅ llama.cpp installed successfully!"
echo ""

# 2. Install OpenCode CLI (The interface)
echo "=> [2/2] Installing OpenCode CLI (Interface)..."
if command -v npm >/dev/null 2>&1; then
    npm install -g opencode-ai
else
    echo "⚠️ Warning: npm is poorly configured or not installed, falling back to curl installer..."
    curl -fsSL https://opencode.ai/install | bash
fi
echo "=> ✅ OpenCode CLI installed successfully!"
echo ""

echo "==========================================================="
echo "  All dependencies are installed!                          "
echo "  You can now run: ./scripts/start-all.sh                  "
echo "==========================================================="
