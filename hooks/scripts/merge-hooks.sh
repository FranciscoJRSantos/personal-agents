#!/bin/bash
# Hooks merge script - merges hooks into settings.json without conflicts
# Handles both format: {"hooks": {...}} and {"PreCompact": [...], ...}

SETTINGS_FILE="$1"
HOOKS_FILE="$2"

if [ ! -f "$SETTINGS_FILE" ]; then
  cat "$HOOKS_FILE"
  exit 0
fi

# Check if hooks.json has a "hooks" key or is at top level
if jq -e '.hooks' "$HOOKS_FILE" >/dev/null 2>&1; then
  NEW_HOOKS=$(jq '.hooks' "$HOOKS_FILE")
else
  NEW_HOOKS=$(jq '.' "$HOOKS_FILE")
fi

# Extract existing hooks from settings (handle both formats)
if jq -e '.hooks' "$SETTINGS_FILE" >/dev/null 2>&1; then
  EXISTING=$(jq '.hooks' "$SETTINGS_FILE")
else
  # Check if settings has hooks at top level
  EXISTING=$(jq 'keys | if map(. == "hooks") | any then . else null end' "$SETTINGS_FILE")
  if [ "$EXISTING" = "null" ]; then
    # Settings doesn't have hooks - collect all hook event keys
    EXISTING=$(jq '[to_entries | .[] | select(.key | . != "permissions" and . != "model" and . != "voiceEnabled" and . != "effortLevel")] | from_entries // {}' "$SETTINGS_FILE")
  fi
fi

# Merge hooks
MERGED=$(jq -n --argjson a "$EXISTING" --argjson b "$NEW_HOOKS" '$a * $b')

# Replace hooks in settings and output
jq --argjson hooks "$MERGED" '. * {hooks: $hooks}' "$SETTINGS_FILE"