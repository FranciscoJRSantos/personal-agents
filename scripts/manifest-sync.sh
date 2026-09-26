#!/usr/bin/env bash
# manifest-sync.sh — Deploy repo items into a target dir, tracked by a manifest.
#
# Usage:
#   manifest-sync.sh [--drift] <target-dir> <item>...
#
# Each item is a directory or file in the repo. A directory item is synced into
# <target-dir>/<basename>/ with `rsync -a --delete` (so --delete never spans the
# whole target). A file item is copied with `cp -p`. The manifest at
# <target-dir>/.personal-agents-manifest records the deployed basenames; on the next
# run, entries in the old manifest that are no longer items are removed. Nothing
# outside the manifest is ever touched, so harness-owned dirs (e.g.
# ~/.claude/skills/synced/), plugin skills and hand-made agents survive.
#
#   --drift     Read-only: diff each item against its deployed copy and report
#               unlisted extras as INFO. Never writes.
#
# Env:
#   DRY_RUN=1   Print every action (rsync uses --dry-run) and change nothing.
set -euo pipefail

DRIFT=false
if [ "${1:-}" = "--drift" ]; then
  DRIFT=true
  shift
fi

TARGET_DIR="${1:?usage: manifest-sync.sh [--drift] <target-dir> <item>...}"
shift

if [ "$#" -eq 0 ]; then
  echo "ERROR no items given" >&2
  exit 2
fi

DRY_RUN="${DRY_RUN:-0}"

# Refuse to write through a symlinked target (a swapped symlink would let
# --delete act on an unexpected tree). --drift is read-only, so it skips this.
if [ "$DRIFT" != true ] && [ -L "$TARGET_DIR" ]; then
  echo "ERROR target is a symlink; refusing to write through it: $TARGET_DIR" >&2
  exit 1
fi

MANIFEST="$TARGET_DIR/.personal-agents-manifest"

declare -a ITEMS=() NAMES=()
for item in "$@"; do
  if [ ! -e "$item" ]; then
    echo "ERROR item not found: $item" >&2
    exit 2
  fi
  ITEMS+=("$item")
  NAMES+=("$(basename "$item")")
done

# ── drift: read-only diff, never writes ────────────────────────────────
if [ "$DRIFT" = true ]; then
  status=0
  echo "=== drift: $TARGET_DIR ==="
  for i in "${!ITEMS[@]}"; do
    name="${NAMES[$i]}"
    if [ ! -e "$TARGET_DIR/$name" ]; then
      echo "DIFF  $name  (missing at target)"
      status=1
    elif diff -rq "${ITEMS[$i]}" "$TARGET_DIR/$name" >/dev/null 2>&1; then
      echo "OK    $name"
    else
      echo "DIFF  $name"
      status=1
    fi
  done
  # Unlisted extras (in the target dir but not in the item set, and not the
  # manifest itself). These are pre-manifest leftovers or unowned files.
  if [ -d "$TARGET_DIR" ]; then
    while IFS= read -r entry; do
      base="$(basename "$entry")"
      [ "$base" = ".personal-agents-manifest" ] && continue
      if ! printf '%s\n' "${NAMES[@]}" | grep -qxF "$base"; then
        echo "INFO  unowned: $base"
      fi
    done < <(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -print 2>/dev/null)
  fi
  exit "$status"
fi

mkdir -p "$TARGET_DIR"

# ── sync: write each item into place ───────────────────────────────────
for i in "${!ITEMS[@]}"; do
  item="${ITEMS[$i]}"
  name="${NAMES[$i]}"
  if [ -d "$item" ]; then
    echo "SYNC  dir  $name/ -> $TARGET_DIR/$name/"
    if [ "$DRY_RUN" = "1" ]; then
      rsync -a --delete --dry-run "$item/" "$TARGET_DIR/$name/"
    else
      rsync -a --delete "$item/" "$TARGET_DIR/$name/"
    fi
  else
    echo "SYNC  file $name -> $TARGET_DIR/$name"
    if [ "$DRY_RUN" = "1" ]; then
      echo "      (cp -p $item -> $TARGET_DIR/$name)"
    else
      cp -p "$item" "$TARGET_DIR/$name"
    fi
  fi
done

# ── remove previously-deployed items no longer in the item set ─────────
if [ -f "$MANIFEST" ]; then
  while IFS= read -r old_name; do
    [ -n "$old_name" ] || continue
    if ! printf '%s\n' "${NAMES[@]}" | grep -qxF "$old_name"; then
      echo "REMOVE $old_name"
      if [ "$DRY_RUN" = "1" ]; then
        echo "      (rm -rf $TARGET_DIR/$old_name)"
      else
        rm -rf "$TARGET_DIR/$old_name"
      fi
    fi
  done < "$MANIFEST"
fi

# ── write the new manifest ─────────────────────────────────────────────
if [ "$DRY_RUN" = "1" ]; then
  echo "WRITE manifest ($(printf '%s\n' "${NAMES[@]}" | wc -l | tr -d ' ') items) — dry run, not written"
else
  printf '%s\n' "${NAMES[@]}" | sort -u > "$MANIFEST"
  echo "WRITE $MANIFEST"
fi
