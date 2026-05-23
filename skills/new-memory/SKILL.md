---
name: new-memory
description: >
  Save a memory to the model-agnostic memory store at ~/.agents/memory/ (global) or
  ./.agents/memory/ (project). Memories persist across sessions and are readable by any
  model with access to ~/.agents/. Use this skill whenever the user says "remember this",
  "save this to memory", "add a memory", "/new-memory", or wants to persist a fact,
  preference, feedback, or project context beyond session scope.
  Entry point: /new-memory [optional text]
---

# New Memory Skill

Saves a memory to the model-agnostic store so it persists across sessions and is
accessible to any model.

Two destinations:
- `~/.agents/memory/` — global memories (user preferences, cross-project feedback)
- `./.agents/memory/` — project-scoped memories (project goals, conventions, context)

---

## Gotchas

- If a very similar memory already exists, prefer updating it over creating a duplicate.
  Duplicate memories with inconsistent content are worse than no memory at all.
- One-line hooks in MEMORY.md must keep the full line ≤120 chars (including the prefix
  `- [Name](file.md) \`#tags\` — `). If the hook is longer, trim it — full detail belongs
  in the file body.
- Slugs must be filesystem-safe: lowercase, underscores only (no spaces, no special chars).
  Pattern: `<type>_<descriptive_name>` e.g. `feedback_response_style`, `project_goals`.
- Memory capacity is soft-budgeted at 30 entries or 6KB total per MEMORY.md index.
  When exceeded, prioritize consolidation (merge related entries) over creating new ones.

---

## Step 1: Capture the Content

If the user provided text with the command (e.g. `/new-memory I prefer short responses`),
use that text as the memory content and skip to Step 2.

Otherwise ask:

> "What should I remember? Describe the fact, preference, or context you want saved."

---

## Step 2: Determine Type

Classify into one of four types. If obvious from context, choose silently. If ambiguous, ask.

| Type | What it stores |
|------|----------------|
| `user` | Who you are, your role, knowledge level, goals |
| `feedback` | How you want the model to behave — corrections and validated approaches |
| `project` | Ongoing work context, decisions, deadlines, stakeholders |
| `reference` | Where to find things — external systems, dashboards, links |

---

## Step 3: Extract Tags and Hook

From the memory content, extract:
- **Tags**: 1–4 keywords that would help a model find this memory (e.g. `ml`, `communication`, `architecture`)
- **Hook**: a one-line summary of ≤80 chars (used in the MEMORY.md index)

Show both to the user and offer to adjust before proceeding.

---

## Step 4: Determine Scope

Ask:

> "Should this be global (`~/.agents/memory/` — applies everywhere) or project-scoped
> (`./.agents/memory/` — only for this repo)?"

Guidance: user preferences and cross-project feedback → global. Project goals, decisions,
deadlines → project.

---

## Step 5: Generate Slug

Generate a slug from the type and a short descriptive name:

```
<type>_<words_from_hook_or_name>
```

Examples: `user_background`, `feedback_response_style`, `project_agents_goal`.

Check whether a file with this slug already exists:

```bash
TARGET=~/.agents/memory   # or ./.agents/memory depending on Step 4
ls "$TARGET/<slug>.md" 2>/dev/null
```

If a file exists with the same or a very similar slug, auto-merge by proceeding
to Step 6 which will handle the update.

---

## Step 5.5: Check Capacity

Load the target MEMORY.md index and count entries and size:

```bash
ENTRIES=$(grep -c '^- \[' "$TARGET/MEMORY.md" 2>/dev/null || echo 0)
SIZE=$(wc -c < "$TARGET/MEMORY.md" 2>/dev/null || echo 0)
echo "Memory: ${ENTRIES}/30 entries · $((SIZE/1024)).$(((SIZE%1024)*10/1024))KB/6KB"
```

If ≥30 entries or ≥6KB, still proceed but prioritize consolidation:
- If adding would duplicate an existing entry, update it rather than creating new
- If creating new, merge related existing entries first

---

## Step 6: Check for Duplicates (Auto-Merge)

Load the relevant MEMORY.md index if it exists:

```bash
cat "$TARGET/MEMORY.md" 2>/dev/null
```

Scan index entries for overlapping names, tags, or hooks. If a near-duplicate is found,
**auto-update** the existing entry instead of creating a new one:
- Overwrite the existing file (keep the same slug)
- Update the `updated:` date in the frontmatter
- Update the hook in the index if it changed
- Skip steps 7-8 (no new file to write)

If no near-duplicate exists, proceed to Step 7.

---

## Step 7: Write the Memory File

Create the target directory if needed:

```bash
mkdir -p "$TARGET"
```

Write `$TARGET/<slug>.md`:

```markdown
---
name: <name>
type: <type>
tags: [tag1, tag2]
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---

<memory content>

**Why:** <the reason this is worth remembering>
```

---

## Step 8: Update the Index

Check whether `$TARGET/MEMORY.md` exists:

```bash
ls "$TARGET/MEMORY.md" 2>/dev/null
```

**If MEMORY.md does not exist**, create it:

```markdown
# Memory Index
<!-- scope: <global|project> | path: <TARGET>/ -->

## <type>
- [<name>](<slug>.md) `#tag1 #tag2` — <hook>
```

**If MEMORY.md exists**, read it, locate the `## <type>` section, and append the new
entry as a bullet under it. If that section does not exist, append it at the end of
the file before EOF.

Index line format (must be a single line ≤120 chars total):
```
- [<name>](<slug>.md) `#tag1 #tag2` — <hook>
```

---

## Step 9: Confirm

Show what was saved:

```
Memory saved:
  File:   <TARGET>/<slug>.md
  Index:  <TARGET>/MEMORY.md  (entry added under ## <type>)
  Hook:   <hook>
```
