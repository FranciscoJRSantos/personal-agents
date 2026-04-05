---
name: adr
description: >
  Creates Architecture Decision Records (ADRs) when significant design choices are
  made. Captures context, decision, consequences, and alternatives rejected — the
  "why" that CLAUDE.md doesn't hold. Use this skill whenever the user says "record
  this decision", "write an ADR", "document why we chose X", "capture this
  architecture decision", or wants to preserve design rationale for future reference.
  Stores under docs/decisions/ or .agents/decisions/ (whichever exists).
  Entry point: /adr [optional decision title or description]
---

# ADR Skill

Creates an Architecture Decision Record for a significant design choice. ADRs answer
"why did we build it this way?" six months later — context that code comments and
CLAUDE.md don't hold.

Stored as numbered markdown files: `docs/decisions/ADR-<NNN>-<slug>.md`
(falls back to `.agents/decisions/` if `docs/` doesn't exist).

---

## Gotchas

- Auto-number only — do not let the user pick a number manually (risk of collisions).
  Scan both `docs/decisions/` and `.agents/decisions/` before assigning the next number.
- The slug must be lowercase, hyphen-separated, max 40 characters.
- Never invent consequences — only write what the user explicitly provides.
- Ask questions one at a time to keep the conversation from feeling like a form.

---

## Step 1: Capture the Decision

If the user provided a decision description inline with the slash command, use it
directly and skip the question.

Otherwise ask:

> "What design decision was made? (e.g. 'Use PostgreSQL instead of Redis for the
> job queue', 'Switch from REST to GraphQL for the mobile API')"

---

## Step 2: Get Context and Consequences

Ask these one at a time (skip any the user already answered in Step 1):

1. *"What problem or constraints led to this decision?"*
2. *"What are the consequences — positive outcomes and any trade-offs or downsides?"*

---

## Step 3: Get Alternatives Rejected

Ask:

> "What alternatives were considered and why were they rejected? Give them one by one —
> say 'done' when you're finished."

Collect responses as rows in a table:

| Alternative | Reason rejected |
|-------------|-----------------|
| ...         | ...             |

If the user says "none" or "no alternatives", record: `No alternatives were evaluated.`

---

## Step 4: Auto-Number the ADR

Determine write destination:

```bash
# Check which decisions directory exists
ls docs/ 2>/dev/null && echo "docs exists"
ls docs/decisions/ 2>/dev/null && echo "docs/decisions exists"
ls .agents/decisions/ 2>/dev/null && echo ".agents/decisions exists"
```

Prefer `docs/decisions/` if `docs/` exists. Fall back to `.agents/decisions/`.

Scan for the highest existing ADR number:

```bash
ls docs/decisions/ADR-*.md 2>/dev/null | grep -oE 'ADR-[0-9]+' | sort -t- -k2 -n | tail -1
ls .agents/decisions/ADR-*.md 2>/dev/null | grep -oE 'ADR-[0-9]+' | sort -t- -k2 -n | tail -1
```

Next number = highest found + 1. If no ADRs exist yet, start at `001`.
Format as zero-padded 3 digits: `001`, `002`, ..., `042`.

Detect current ticket from branch name:

```bash
TICKET=$(git branch --show-current | grep -oE '[A-Z]+-[0-9]+')
echo "${TICKET:-N/A}"
```

Generate slug: lowercase the decision title, replace spaces and special characters with
hyphens, strip punctuation, truncate to 40 characters.

---

## Step 5: Show ADR for Confirmation

Assemble and display the full ADR:

```markdown
# ADR-<NNN>: <title>

**Date:** <ISO date — today>
**Status:** Accepted
**Ticket:** <TICKET or N/A>

## Context

[problem and constraints from Step 2]

## Decision

[decision text from Step 1]

## Consequences

**Positive:** [from Step 2]

**Negative / trade-offs:** [from Step 2]

## Alternatives Rejected

| Alternative | Reason rejected |
|-------------|-----------------|
| ...         | ...             |
```

Ask: *"Does this ADR look right? Say 'save' to write it, or tell me what to adjust."*

Do not write to disk yet.

---

## Step 6: Write the ADR

Create the directory if needed:

```bash
mkdir -p docs/decisions 2>/dev/null || mkdir -p .agents/decisions
```

Write to `docs/decisions/ADR-<NNN>-<slug>.md` (or `.agents/decisions/` fallback).

Confirm:

```
ADR written:
  File:   docs/decisions/ADR-042-use-postgres-for-job-queue.md
  Status: Accepted
  Ticket: PROJ-456
```
