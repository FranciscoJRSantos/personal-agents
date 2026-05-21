---
name: forget
description: >
  Remove one or more memories from the model-agnostic memory store. Searches the
  MEMORY.md index for matching entries, shows full content for confirmation, then
  deletes the file(s) and removes the index entries. Use this skill whenever the user
  says "forget", "delete memory", "remove this memory", "/forget <name-or-query>", or
  wants to prune stale or incorrect memories.
  Entry point: /forget <name-or-query>
---

# Forget Skill

Removes memories from the model-agnostic store and keeps the MEMORY.md index clean.
This action is irreversible — the human gate at Step 3 is mandatory.

---

## Gotchas

- Always show the full memory content before deleting — the one-line hook alone may
  not be enough for the user to confirm they're targeting the right entry.
- Never delete without explicit confirmation. There is no undo.
- After deletion, the MEMORY.md index entry must also be removed. An index that points
  to missing files will cause confusing errors in `/recall` and `/memories`.
- After removing entries, clean up any now-empty `## <type>` sections from MEMORY.md —
  a section header with no entries under it is dead weight.

---

## Step 1: Load Memory Indices

```bash
GLOBAL_MEM=~/.agents/memory/MEMORY.md
PROJECT_MEM=./.agents/memory/MEMORY.md

echo "=== Global Memory Index ==="
[ -f "$GLOBAL_MEM" ] && cat "$GLOBAL_MEM" || echo "(empty)"

echo "=== Project Memory Index ==="
[ -f "$PROJECT_MEM" ] && cat "$PROJECT_MEM" || echo "(empty)"
```

---

## Step 2: Find Matches

Match the query against index entry names, hooks, and tags using the same logic as
`/recall` — case-insensitive keyword match in hook or file name, or exact `#tag` match.

For each match, load the full memory file to show the user what will be deleted:

```bash
cat ~/.agents/memory/<slug>.md    # for global matches
cat ./.agents/memory/<slug>.md     # for project matches
```

If no matches found:

> "No memories matched `<query>`. Run `/memories` to browse the full index."

---

## Step 3: Confirm Deletion

List all matched entries with their full content and ask:

> "These memories will be permanently deleted:
>
>   1. `<name>` (`<path>`): <hook>
>      [full content shown above]
>
> Type 'yes' to confirm deletion, or 'cancel' to abort."

Do not delete anything until the user explicitly confirms.

---

## Step 4: Delete Files

For each confirmed entry:

```bash
rm ~/.agents/memory/<slug>.md     # global
rm ./.agents/memory/<slug>.md      # project
echo "Deleted: <path>"
```

---

## Step 5: Update the Index

For each deleted file, remove its line from the relevant MEMORY.md.

Read the MEMORY.md file, filter out the line(s) matching the deleted slugs, and write
it back. Then remove any `## <type>` section headers that now have no entries beneath
them (the next line after the header is either another `##` or EOF).

---

## Step 6: Confirm

```
Forgotten:
  <name>  (<path>) — deleted
  Index entry removed from MEMORY.md

Remaining memories: <N total across both stores>  (run /memories to review)
```
