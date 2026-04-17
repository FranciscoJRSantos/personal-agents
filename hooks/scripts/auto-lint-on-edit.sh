#!/bin/bash
# Auto Lint on Edit
# Runs lint on edited/written files after Edit or Write tool use

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')
PROJECT_DIR="$CLAUDE_PROJECT_DIR"

# Determine file(s) affected
case "$TOOL_NAME" in
  "Edit")
    # For Edit, extract file path from tool_input
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.filePath // .tool_input.file_path // empty')
    ;;
  "Write")
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.filePath // .tool_input.path // empty')
    ;;
  *)
    exit 0
    ;;
esac

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

FULL_PATH="$PROJECT_DIR/$FILE_PATH"

if [ ! -f "$FULL_PATH" ]; then
  exit 0
fi

# Determine lint command based on project
LINT_CMD=""
if [ -f "$PROJECT_DIR/package.json" ]; then
  if grep -q '"lint"' "$PROJECT_DIR/package.json"; then
    LINT_CMD="npm run lint --"
  fi
elif [ -f "$PROJECT_DIR/Makefile" ]; then
  if grep -q 'lint:' "$PROJECT_DIR/Makefile"; then
    LINT_CMD="make lint"
  fi
fi

if [ -n "$LINT_CMD" ]; then
  # Run lint on the specific file (if supported)
  cd "$PROJECT_DIR" && $LINT_CMD 2>&1 | head -20
fi

exit 0