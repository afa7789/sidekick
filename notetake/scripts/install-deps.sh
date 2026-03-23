#!/usr/bin/env bash

echo "==========================================================="
echo "  Installing Sidekick Dependencies                         "
echo "==========================================================="
echo ""

# 1. llama.cpp
echo "=> [1/3] Installing llama.cpp (AI engine)..."
if command -v llama-server &> /dev/null; then
    echo "   ✅ llama.cpp already installed."
elif command -v brew >/dev/null 2>&1; then
    brew install llama.cpp
    echo "   ✅ llama.cpp installed!"
else
    echo "   ❌ Homebrew not found. Install it first:"
    echo "      /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi
echo ""

# 2. Node.js / npx (for Silverbullet)
echo "=> [2/3] Checking Node.js (required for Silverbullet)..."
if command -v npx &> /dev/null; then
    echo "   ✅ Node.js already installed ($(node --version))."
else
    echo "   Installing Node.js via Homebrew..."
    brew install node
    echo "   ✅ Node.js installed!"
fi
echo ""

# 3. jq (for agent.sh JSON parsing)
echo "=> [3/3] Checking jq (required for agent.sh)..."
if command -v jq &> /dev/null; then
    echo "   ✅ jq already installed."
else
    brew install jq
    echo "   ✅ jq installed!"
fi
echo ""

echo "==========================================================="
echo "  All dependencies are installed!                          "
echo ""
echo "  Next steps:"
echo "  1. cp .env.example .env"
echo "  2. Edit .env and set MODEL_FILE to your .gguf file"
echo "  3. Place the .gguf file in the models/ directory"
echo "  4. ./scripts/start-all.sh"
echo "==========================================================="
