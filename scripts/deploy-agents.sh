#!/usr/bin/env bash
# deploy-agents.sh — Deploy agents to a target directory
#
# Usage: deploy-agents.sh <source-dir> <target-dir> [--md-only]
#
#   --md-only   Copy only top-level *.md files (for ~/.config/opencode/agents/)
#   (no flag)   Copy everything including partials/ and memory/ (for ~/.agents/)
set -euo pipefail

SOURCE_DIR="${1:?}"
TARGET_DIR="${2:?}"
MD_ONLY=false

if [ "${3:-}" = "--md-only" ]; then
  MD_ONLY=true
fi

STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

# ── Copy source to staging ──────────────────────────────────────────
if $MD_ONLY; then
  find "$SOURCE_DIR" -maxdepth 1 -name "*.md" -exec cp {} "$STAGING_DIR/" \;
else
  cp -r "$SOURCE_DIR"/* "$STAGING_DIR/" 2>/dev/null || true
fi

# ── Deploy staging → target ─────────────────────────────────────────
mkdir -p "$TARGET_DIR"
rsync -av --delete "$STAGING_DIR"/ "$TARGET_DIR"/

echo "Deployed agents to $TARGET_DIR"
