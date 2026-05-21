---
name: memories
description: >
  List and browse the model-agnostic memory store. Displays the compact MEMORY.md
  index entries without loading full file content — a token-lean overview of what
  has been saved. Supports optional filters by scope or type. Use this skill whenever
  the user says "list memories", "show memories", "what's in memory", "/memories", or
  wants to browse what has been saved without doing a targeted search.
  Entry point: /memories [--global | --project | --type <type>]
---

# Memories Skill

Displays the memory index without loading full file content. This is a browse
operation — cheap on tokens. For targeted retrieval, use `/recall <query>`.

---

## Gotchas

- Load the index files only, not the full memory files. If the user wants content,
  they should use `/recall <query>`.
- If both global and project indices exist, show both clearly labelled.
- The `--type` filter applies to the section headers in MEMORY.md (`## user`,
  `## feedback`, `## project`, `## reference`). Show only the matching section(s).

---

## Step 1: Parse Flags

Parse optional flags from the invocation:

| Flag | Effect |
|------|--------|
| `--global` | Show only `~/.agents/memory/MEMORY.md` |
| `--project` | Show only `./.agents/memory/MEMORY.md` |
| `--type <type>` | Filter to one section: `user`, `feedback`, `project`, or `reference` |
| _(none)_ | Show both indices in full |

---

## Step 2: Load Indices

```bash
GLOBAL_MEM=~/.agents/memory/MEMORY.md
PROJECT_MEM=./.agents/memory/MEMORY.md

# Respect --global / --project flags
[ -f "$GLOBAL_MEM" ] && cat "$GLOBAL_MEM"
[ -f "$PROJECT_MEM" ] && cat "$PROJECT_MEM"
```

---

## Step 3: Apply Type Filter

If `--type` was given, extract only the matching `## <type>` section from each loaded
index. A section runs from its `## heading` to the next `## heading` or EOF.

---

## Step 4: Display

Present the content with scope labels:

```
# Memory Store

## Global  (~/.agents/memory/)
<content of global MEMORY.md, or "(empty — use /new-memory to save the first entry)">

## Project  (./.agents/memory/)
<content of project MEMORY.md, or "(empty)">

───────────────────────────────────────────────
Total: <N> memories
Use /recall <query> to load content · /new-memory to save · /forget <name> to remove
```

Count total entries across both visible indices for the footer line.
