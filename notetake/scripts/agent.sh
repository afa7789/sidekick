#!/usr/bin/env bash
#
# agent.sh — Sends a note to llama.cpp and saves the improved version.
#
# Usage:
#   ./scripts/agent.sh <note-path> [instruction]
#
# Examples:
#   ./scripts/agent.sh notes/roadmap.md
#   ./scripts/agent.sh notes/roadmap.md "add estimated timelines to each item"
#   ./scripts/agent.sh notes/idea.md "expand this into a detailed technical spec"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load central configurations (.env)
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    source "$PROJECT_ROOT/.env.example"
fi

# ── Argument parsing ────────────────────────────────────────────────────────────

NOTE_PATH="$1"
INSTRUCTION="${2:-improve this roadmap: make it clearer, more structured, and actionable. Keep markdown format.}"

if [ -z "$NOTE_PATH" ]; then
    echo "Usage: $0 <note-path> [instruction]"
    echo ""
    echo "Examples:"
    echo "  $0 notes/roadmap.md"
    echo "  $0 notes/roadmap.md \"add estimated timelines to each item\""
    exit 1
fi

# Resolve path relative to project root if not absolute
if [[ "$NOTE_PATH" != /* ]]; then
    NOTE_PATH="$PROJECT_ROOT/$NOTE_PATH"
fi

if [ ! -f "$NOTE_PATH" ]; then
    echo "❌ Error: file not found: $NOTE_PATH"
    exit 1
fi

# ── Pre-flight check ────────────────────────────────────────────────────────────

if ! curl -sf "http://127.0.0.1:$LLAMA_PORT/health" > /dev/null 2>&1; then
    echo "❌ llama.cpp is not running. Start it first:"
    echo "   ./scripts/start-all.sh"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is required. Install it with: brew install jq"
    exit 1
fi

# ── Build output path ───────────────────────────────────────────────────────────

NOTE_DIR="$(dirname "$NOTE_PATH")"
NOTE_NAME="$(basename "$NOTE_PATH" .md)"
OUTPUT_PATH="$NOTE_DIR/${NOTE_NAME}-improved.md"

# ── Send to llama.cpp ───────────────────────────────────────────────────────────

NOTE_CONTENT="$(cat "$NOTE_PATH")"

echo "🤖 Sending to llama.cpp..."
echo "   Note      : $NOTE_PATH"
echo "   Instruction: $INSTRUCTION"
echo "   Output    : $OUTPUT_PATH"
echo ""

PAYLOAD=$(jq -n \
    --arg system "You are a technical writing assistant. When given a markdown note, you apply the user's instruction and return only the improved markdown — no explanations, no preamble, no code blocks wrapping the output." \
    --arg instruction "$INSTRUCTION" \
    --arg note "$NOTE_CONTENT" \
    '{
        model: "local",
        messages: [
            { role: "system", content: $system },
            { role: "user", content: ("Instruction: " + $instruction + "\n\n---\n\n" + $note) }
        ],
        temperature: 0.7,
        stream: false
    }')

RESPONSE=$(curl -sf \
    -X POST "http://127.0.0.1:$LLAMA_PORT/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
    echo "❌ llama.cpp returned an error. Check logs: logs/llama.log"
    exit 1
fi

# Extract the assistant message content
RESULT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

if [ -z "$RESULT" ] || [ "$RESULT" = "null" ]; then
    echo "❌ Empty response from model. Check logs: logs/llama.log"
    exit 1
fi

# ── Save result ─────────────────────────────────────────────────────────────────

echo "$RESULT" > "$OUTPUT_PATH"

echo "✅ Done! Improved note saved to:"
echo "   $OUTPUT_PATH"
