#!/bin/bash
# Compaction Todo Preserver
# Saves current TODO state to ~/.claude/compaction-todos.json before context compaction

INPUT=$(cat)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Extract current todo items from CLAUDE.md if it exists
CLAUDE_FILE="$CLAUDE_PROJECT_DIR/CLAUDE.md"
OUTPUT_FILE="$HOME/.claude/compaction-todos.json"

if [ -f "$CLAUDE_FILE" ]; then
  # Extract todo items from CLAUDE.md (lines starting with - [ ] or - [x])
  TODOS=$(grep -E '^- \[ \]|^-\[x\]' "$CLAUDE_FILE" 2>/dev/null | head -20 || echo "")
  
  # Check if there's an active implement session
  IMPLEMENT_PROGRESS_FILES=($CLAUDE_PROJECT_DIR/.agents/artifacts/*-impl-progress.md)
  ACTIVE_IMPL=""
  
  if [ -e "${IMPLEMENT_PROGRESS_FILES[0]}" ]; then
    ACTIVE_IMPL=$(basename "${IMPLEMENT_PROGRESS_FILES[0]}" | sed 's/-impl-progress.md//')
  fi
  
  # Write state to file using jq for safe escaping
  jq -n \
    --arg ts "$(date -Iseconds)" \
    --arg impl "$ACTIVE_IMPL" \
    --arg todos "$TODOS" \
    '{
      timestamp: $ts,
      activeImplement: $impl,
      todos: ($todos | split("\n") | map(select(. != "")))
    }' > "$OUTPUT_FILE"
fi

exit 0