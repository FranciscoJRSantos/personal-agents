#!/bin/bash
# Session Context Loader
# Loads persistent context when session resumes (SessionStart with "resume" matcher)

INPUT=$(cat)
SESSION_START_TYPE=$(echo "$INPUT" | jq -r '.session_start_type // empty')

# Only run on resume
if [ "$SESSION_START_TYPE" != "resume" ]; then
  exit 0
fi

PROJECT_DIR="$CLAUDE_PROJECT_DIR"

# Check for implement in-progress files
if [ -d "$PROJECT_DIR/.agents/artifacts" ]; then
  LATEST_PROGRESS=$(ls -t "$PROJECT_DIR/.agents/artifacts/"*-impl-progress.md 2>/dev/null | head -1)
  if [ -n "$LATEST_PROGRESS" ]; then
    TICKET=$(basename "$LATEST_PROGRESS" | sed 's/-impl-progress.md//')
    echo "Resuming implement session for: $TICKET"
  fi
fi

# Check for saved memory
MEMORY_FILE="$HOME/.agents/memory/last-session.md"
if [ -f "$MEMORY_FILE" ]; then
  cat "$MEMORY_FILE"
fi

exit 0