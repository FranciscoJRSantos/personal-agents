#!/usr/bin/env bash
# deploy-agents.sh — Deploy agents to a target directory, resolving category: → model:
#
# Usage: deploy-agents.sh <source-dir> <target-dir> <categories-file> [--md-only]
#
#   --md-only   Copy only top-level *.md files (for ~/.config/opencode/agents/)
#   (no flag)   Copy everything including partials/ and memory/ (for ~/.agents/)
#
# Uses a staging directory to avoid modifying source files, so pull remains safe.
set -euo pipefail

SOURCE_DIR="${1:?}"
TARGET_DIR="${2:?}"
CATEGORIES_FILE="${3:?}"
MD_ONLY=false

if [ "${4:-}" = "--md-only" ]; then
  MD_ONLY=true
fi

STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

# ── Copy source to staging ──────────────────────────────────────────
if $MD_ONLY; then
  # Copy only top-level .md files
  find "$SOURCE_DIR" -maxdepth 1 -name "*.md" -exec cp {} "$STAGING_DIR/" \;
else
  # Copy everything
  cp -r "$SOURCE_DIR"/* "$STAGING_DIR/" 2>/dev/null || true
fi

# ── Resolve category: → model: in staging ───────────────────────────
if [ -f "$CATEGORIES_FILE" ]; then
  echo "Resolving agent categories..."
  for f in "$STAGING_DIR"/*.md; do
    [ -e "$f" ] || continue

    # Extract YAML frontmatter (lines between first and second ---)
    fm=$(sed -n '1,/^---$/p' "$f" 2>/dev/null)
    [ -n "$fm" ] || continue
    if ! echo "$fm" | grep -q "^---$"; then continue; fi

    agent=$(basename "$f" .md)

    category=$(echo "$fm" | yq eval 'select(di==0) | .category // ""' | grep -v '^null$' | head -1)
    if [ -z "$category" ] || [ "$category" = '""' ]; then
      continue
    fi

    model=$(jq -r '.["'"$category"'"].model // empty' "$CATEGORIES_FILE")
    if [ -n "$model" ]; then
      echo "  $agent: category=$category → model=$model"
      sed -i 's|^category:.*|model: '"$model"'|' "$f"
    else
      echo "WARN  $agent: category '$category' not found in categories.json"
    fi
  done
fi

# ── Deploy staging → target ─────────────────────────────────────────
mkdir -p "$TARGET_DIR"
rsync -av --delete "$STAGING_DIR"/ "$TARGET_DIR"/

echo "Deployed agents to $TARGET_DIR"
