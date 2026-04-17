---
name: recall
description: >
  Search the model-agnostic memory store for relevant memories. Loads the compact
  MEMORY.md index first, filters by keyword or tag, then retrieves full content for
  matches only. Use this skill whenever the user says "recall", "what do you know
  about X", "search memory for X", "/recall <query>", or wants to retrieve previously
  saved context.
  Entry point: /recall <query>
---

# Recall Skill

Searches the model-agnostic memory store using a two-step approach: load the compact
index (~50–150 tokens) to assess relevance, then fetch only the matching full files.

---

## Gotchas

- Match the query against both the one-line hooks *and* the `#tags` in MEMORY.md.
  A match on either counts.
- Treat words prefixed with `#` in the query as tag filters: `/recall #ml` should
  match entries tagged `#ml`, not just entries that mention "ml" in the hook.
- If the query is very broad ("everything", "all", or empty), return the full index
  content rather than loading all file bodies — let the user narrow the search or use
  `/memories` instead.

---

## Step 1: Load Memory Indices

```bash
GLOBAL_MEM=~/.agents/memory/MEMORY.md
PROJECT_MEM=./agents/memory/MEMORY.md

echo "=== Global Memory Index ==="
[ -f "$GLOBAL_MEM" ] && cat "$GLOBAL_MEM" || echo "(no global memory index found)"

echo "=== Project Memory Index ==="
[ -f "$PROJECT_MEM" ] && cat "$PROJECT_MEM" || echo "(no project memory index found)"
```

---

## Step 2: Filter by Query

From the loaded index content, identify entries where:
- Any keyword from the query appears in the entry's hook or file name (case-insensitive)
- Any `#tag` in the query exactly matches a tag listed in the entry

Build two lists: global matches (path `~/.agents/memory/<slug>.md`) and project matches
(path `./agents/memory/<slug>.md`).

If the query is empty or matches everything, skip to Step 4 and display the index
summaries only — do not load all files.

---

## Step 3: Load Full Content for Matches

For each matched entry, read the full memory file:

```bash
# Global match
cat ~/.agents/memory/<slug>.md

# Project match
cat ./agents/memory/<slug>.md
```

---

## Step 4: Return Results

Present each match with clear separation:

```
## <name>  [<type>] (<scope>: global|project)
File: <full-path>
Tags: #tag1 #tag2

<full memory content>

---
```

After all results:
- If no matches: *"No memories matched `<query>`. Run `/memories` to browse the full index."*
- If memory store is empty: *"Memory store is empty. Use `/new-memory` to save the first entry."*
- If query was broad: show index summaries only and suggest `/recall <specific-term>` to load content.
