#!/usr/bin/env bash
# deploy-agents.sh — Deploy agent items to a target dir via the manifest sync.
#
# Usage: deploy-agents.sh [--drift] <source-dir> <target-dir> [--md-only]
#
#   --md-only   Only top-level *.md files (for ~/.config/opencode/agents/)
#   (no flag)   *.md files plus partials/ (for ~/.agents/)
#   --drift     Read-only diff (passed through to manifest-sync.sh)
set -euo pipefail

DRIFT=""
if [ "${1:-}" = "--drift" ]; then
  DRIFT="--drift"
  shift
fi

SOURCE_DIR="${1:?usage: deploy-agents.sh [--drift] <source-dir> <target-dir> [--md-only]}"
TARGET_DIR="${2:?}"
MD_ONLY=false
if [ "${3:-}" = "--md-only" ]; then
  MD_ONLY=true
fi

declare -a ITEMS=()
mapfile -t MD_FILES < <(find "$SOURCE_DIR" -maxdepth 1 -name "*.md" -print | sort)
ITEMS+=("${MD_FILES[@]}")
if ! $MD_ONLY && [ -d "$SOURCE_DIR/partials" ]; then
  ITEMS+=("$SOURCE_DIR/partials")
fi

if [ ${#ITEMS[@]} -eq 0 ]; then
  echo "ERROR no agent items found in $SOURCE_DIR" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/manifest-sync.sh" $DRIFT "$TARGET_DIR" "${ITEMS[@]}"
