#!/bin/bash
# Post Compact Todo Restore
# Restores TODO state from ~/.claude/compaction-todos.json after context compaction

OUTPUT_FILE="$HOME/.claude/compaction-todos.json"

if [ -f "$OUTPUT_FILE" ]; then
  TIMESTAMP=$(jq -r '.timestamp' "$OUTPUT_FILE" 2>/dev/null)
  ACTIVE_IMPL=$(jq -r '.activeImplement' "$OUTPUT_FILE" 2>/dev/null)
  TODOS=$(jq -r '.todos' "$OUTPUT_FILE" 2>/dev/null)
  
  if [ "$TODOS" != "null" ] && [ "$TODOS" != "[]" ]; then
    # Add system reminder about preserved todos
    echo "Context restored from compaction at $TIMESTAMP"
    if [ -n "$ACTIVE_IMPL" ] && [ "$ACTIVE_IMPL" != "null" ]; then
      echo "Active implement session: $ACTIVE_IMPL"
    fi
  fi
fi

exit 0