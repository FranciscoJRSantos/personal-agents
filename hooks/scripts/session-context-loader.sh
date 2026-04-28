#!/bin/bash
# Session Context Loader
# Loads persistent context when session resumes (SessionStart with "resume" matcher)
# Enhances: shows which files were read by which subagent sessions

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

# Check for subagent session state
SUBAGENT_STATE="$PROJECT_DIR/.agents/codemap/subagent-sessions.json"
if [ -f "$SUBAGENT_STATE" ]; then
  echo "=== Subagent Sessions ==="
  cat "$SUBAGENT_STATE"
fi

# Check for codemap state
CODEMAP_DIR="$PROJECT_DIR/.agents/codemap"
if [ -d "$CODEMAP_DIR" ]; then
  echo "Codemap exists: $CODEMAP_DIR/codemap.md"
fi

exit 0