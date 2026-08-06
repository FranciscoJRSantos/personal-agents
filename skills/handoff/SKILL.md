---
name: handoff
description: >
  Compact the current conversation into a handoff document so a fresh agent
  (in Claude Code or OpenCode) can continue the work. Writes the full doc to
  the OS temp dir and syncs .agents/STATE.md for the next session. Use when
  the user says "handoff", "write a handoff", "prepare a handoff for the next
  session", or is ending a session mid-work.
  Entry point: /handoff [what the next session will focus on]
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent
can continue the work without re-reading this session.

---

## Gotchas

- Always write the full document to the OS temp dir ($TMPDIR), never the workspace
  BECAUSE polluting the repo with session debris breaks `make lint-*` and `git status`.
- Always update .agents/STATE.md (position, current_branch, decisions, blockers)
  BECAUSE that is what `/status` and `/plan` read to bootstrap the next session.
- Never duplicate content already in artifacts (.agents/artifacts/*), specs, plans,
  ADRs, commits, or diffs — reference them by relative path or URL instead BECAUSE
  duplicating causes the two copies to drift.
- Always redact API keys, passwords, tokens, and PII BECAUSE the temp file may be
  committed, shared, or left on disk.

---

## Step 1: Gather Context

Read the current position:
- `.agents/STATE.md` (branch, stage, decisions, blockers) — create on the fly if absent
- The most recent files in `.agents/artifacts/` (plan, impl-progress, review)
- Current branch and `git status`

## Step 2: Determine Next Focus

If the user passed an argument, tailor the doc to that focus. Otherwise use the
`position` in STATE.md to infer the next step (e.g. `implementing` → next is
`review`).

## Step 3: Write the Handoff (temp dir)

Write to `$TMPDIR/handoff-<timestamp>.md` with a bash heredoc, containing:

- **Current state** — branch, stage, what is done and what is not
- **Context** — references to artifacts/plans/ADRs by path, never duplicated
- **Next actions** — concrete, ordered, matching the current workflow stage
- **Suggested skills** — which repo skills to invoke next (`/grill-me`, `/plan`,
  `/implement`, `/review`, `/ship`, `/codemap`, `/status`), with the entry point
- **Redactions** — note anything deliberately omitted for secrecy

```bash
ts=$(date +%Y%m%d-%H%M%S)
cat > "$TMPDIR/handoff-$ts.md" <<'EOF'
# Handoff
...
EOF
```

## Step 4: Sync STATE.md

Update `.agents/STATE.md` (creating it if absent) with the new `position`,
`current_branch`, `last_updated`, and any decisions/blockers surfaced during the
session. Keep it lean — decisions, blockers, and position only.

## Step 5: Confirm

Show the temp file path and a 3-line summary, then ask the user to confirm before
writing STATE.md.

---

## Quality Bar

A good handoff should:
- Let a fresh agent continue with zero questions to the user
- Reference artifacts rather than duplicating them
- Be free of secrets
- Leave STATE.md consistent so `/status` shows the correct position
