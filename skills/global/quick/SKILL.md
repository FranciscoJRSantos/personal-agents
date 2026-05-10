---
name: quick
description: >
  Ad-hoc task execution with state tracking, no staged gates. Between /hotfix
  (urgent bugs) and /implement (full staged workflow). Best for: one-off scripts,
  config changes, feature flags, utility types, small refactors, fixing a bug
  that doesn't need a branch. Use this whenever the user says "/quick",
  "quick task", "do this one thing", "just need X done".
  Entry point: /quick <description>
---

# Quick Skill

Ad-hoc task execution with state tracking, no staged gates. Implements the
task directly, runs checks, and records it. No Jira, no plan artifact, no
branch ceremony.

---

## Gotchas

- If the task is a time-sensitive urgent fix, use `/hotfix` instead
- If the task needs multi-stage implementation, use `/implement` instead
- If the task changes more than ~200 lines across multiple files, suggest `/implement`
- Deviation rules and auth gate protocol apply (same as `/implement`)
- Analysis paralysis guard applies — if you've done 5+ read calls without
  writing anything, stop and state what's blocking you

---

## Step 1: Parse Input

Accept: `/quick <description of work>

Extract a short slug from the description for artifact naming:

```bash
SLUG=$(echo "$DESCRIPTION" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//' | cut -c1-40)
echo "Slug: $SLUG"
```

---

## Step 2: Create Progress Artifact

```bash
mkdir -p .agents/artifacts
```

Write `.agents/artifacts/quick-${SLUG}-progress.md`:

```yaml
---
artifact: quick-progress
description: <full task description>
skill: quick
status: in_progress
created: <ISO 8601 timestamp>
---
## Files
- (to be populated)

## Notes
- (any decisions or issues encountered)
```

---

## Step 3: Implement

Implement the task directly. All deviation rules apply:
- Auto-fix bugs, missing critical functionality, and blocking issues (Rules 1-3)
- Stop and ask for architectural decisions (Rule 4)
- Auth errors are gates, not bugs — stop and ask the user to authenticate

As you work, update the artifact's `## Files` section with each file touched and
`## Notes` with any decisions made or issues encountered.

Do not create branches, Jira tickets, or plan artifacts. This is scoped throwaway work.

---

## Step 4: Run Checks

```bash
make check 2>/dev/null || make test 2>/dev/null || echo "No check target found"
```

If checks fail, auto-fix if Rule 1/2/3 applies. If the fix is architectural (Rule 4),
ask the user.

---

## Step 5: Mark Complete

Update `.agents/artifacts/quick-${SLUG}-progress.md`:
- Set `status: complete` in the frontmatter
- Add `completed: <ISO 8601 timestamp>` field
- Finalize `## Files` and `## Notes` sections

Write `.agents/STATE.md` to record what was done:

```bash
mkdir -p .agents
cat > .agents/STATE.md <<'EOF'
---
last_updated: <ISO 8601 timestamp>
current_branch: <current branch name>
position: quick task done
---
## Quick Tasks
- <SLUG>: <one-line summary> (<date>)
EOF
```

Display completion summary:

```
## Quick Task Complete

**Task:** <description>
**Files changed:** <count>
**Files:**
- <file>
- <file>

**Checks:** ✅ passing  (or: ⚠️  see notes above)
```

---

## Quality Bar

- No staged gates, no branch management, no Jira — just implement, check, done
- Deviation rules still apply (bug fixes, auth gates, architectural decisions)
- State is tracked in the progress artifact and STATE.md for /status to pick up
- If it grows beyond ~200 lines or multiple files, suggest the user abort and switch to `/implement`
