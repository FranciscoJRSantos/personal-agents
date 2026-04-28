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
accessible to any model (Claude, Gemini, opencode, etc.).

Two destinations:
- `~/.agents/memory/` — global memories (user preferences, cross-project feedback)
- `./.agents/memory/` — project-scoped memories (project goals, conventions, context)

---

## Gotchas

- Never write a memory without explicit user confirmation — Step 7 is the mandatory gate.
- If a very similar memory already exists, prefer updating it over creating a duplicate.
  Duplicate memories with inconsistent content are worse than no memory at all.
- One-line hooks in MEMORY.md must keep the full line ≤120 chars (including the prefix
  `- [Name](file.md) \`#tags\` — `). If the hook is longer, trim it — full detail belongs
  in the file body.
- Slugs must be filesystem-safe: lowercase, underscores only (no spaces, no special chars).
  Pattern: `<type>_<descriptive_name>` e.g. `feedback_response_style`, `project_goals`.

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

If a file exists with the same or a very similar slug, proceed to Step 6 with the
update-or-create question. Otherwise proceed normally.

---

## Step 6: Check for Duplicates

Load the relevant MEMORY.md index if it exists:

```bash
cat "$TARGET/MEMORY.md" 2>/dev/null
```

Scan index entries for overlapping names, tags, or hooks. If a near-duplicate is found:

> "A similar memory already exists: `[name]` — [hook]
> Options: (1) update the existing entry, (2) add this as a separate memory, (3) cancel."

Wait for the user's choice before continuing. If updating, overwrite the existing file
(keep the same slug) and update the `updated:` date in the frontmatter and the hook in
the index.

---

## Step 7: Confirm Before Writing

Show the full memory that will be written:

```
Memory to save:
  File:   <TARGET>/<slug>.md
  Type:   <type>
  Tags:   #tag1 #tag2
  Hook:   <one-line hook>

  Content:
  ───────────────────────────────────
  <full memory body>
  ───────────────────────────────────

Proceed? (yes / edit / cancel)
```

Do not write anything until the user confirms with "yes", "y", "proceed", or similar.

---

## Step 8: Write the Memory File

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

## Step 9: Update the Index

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

## Step 10: Confirm

Show what was saved:

```
Memory saved:
  File:   <TARGET>/<slug>.md
  Index:  <TARGET>/MEMORY.md  (entry added under ## <type>)
  Hook:   <hook>
```
