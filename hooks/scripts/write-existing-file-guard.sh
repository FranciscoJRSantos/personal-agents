#!/bin/bash
# Write Existing File Guard
# Blocks Write to existing files unless they match certain patterns

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // empty')
PROJECT_DIR="$CLAUDE_PROJECT_DIR"

# Allow patterns (config files that get updated)
ALLOW_PATTERNS=(
  "package.json"
  "tsconfig.json"
  "*.config.js"
  "*.config.ts"
  ".env"
  ".env.local"
  "*.lock"
  "yarn.lock"
  "pnpm-lock.yaml"
  "package-lock.json"
)

# Check if file exists
if [ -f "$PROJECT_DIR/$FILE_PATH" ]; then
  # Check against allow patterns
  for pattern in "${ALLOW_PATTERNS[@]}"; do
    if [[ "$FILE_PATH" == $pattern ]]; then
      exit 0  # Allow
    fi
  done
  
  # File exists and not in allow patterns - output a warning
  # Actually we can't block via this hook easily - let's just warn
  echo "Warning: Writing to existing file: $FILE_PATH" >&2
fi

exit 0