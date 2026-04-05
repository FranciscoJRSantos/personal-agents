---
name: tidy
description: >
  Clean up stale artifacts from .agents/artifacts/ for tickets that are done,
  merged, or closed. Use this skill whenever the user says "tidy", "clean up
  artifacts", "remove old artifacts", "artifact cleanup", or wants to declutter
  the artifacts directory.
---

# Tidy Skill

Identify and remove stale artifacts from `.agents/artifacts/` for completed work.

---

## Step 1: Inventory Artifacts

```bash
ls -la .agents/artifacts/*.md 2>/dev/null
```

If the directory is empty or doesn't exist, report that and stop:

```
No artifacts found — nothing to tidy.
```

Extract unique ticket IDs:

```bash
ls .agents/artifacts/*.md 2>/dev/null | grep -oE '[A-Z]+-[0-9]+' | sort -u
```

---

## Step 2: Check Status for Each Ticket

For each ticket ID, gather its current state:

### 2a. Jira status (optional — fail silently)

```bash
acli jira get "$TICKET" 2>/dev/null | grep -iE 'status|resolution'
```

### 2b. Branch status

```bash
# Is there still a local or remote branch for this ticket?
git branch -a | grep -i "$TICKET"
```

### 2c. MR status

```bash
glab mr list --search="$TICKET" --all 2>/dev/null
```

Classify each ticket as:

- **Safe to remove** — Jira status is Done/Closed/Cancelled, branch deleted, MR merged
- **Probably safe** — MR merged but branch still exists locally (suggest deleting branch too)
- **Keep** — Ticket still open or in progress

---

## Step 3: Present Candidates

Show a table:

```markdown
## Artifact Cleanup

| Ticket | Jira Status | Branch | MR | Artifacts | Action |
|--------|-------------|--------|----|-----------|--------|
| AIH-1230 | Done | deleted | !38 merged | 4 files | Safe to remove |
| AIH-1234 | In Progress | active | !42 open | 3 files | Keep |
| AIH-1235 | Done | local only | !45 merged | 2 files | Probably safe (delete branch too?) |
```

List the specific artifact files for each "safe to remove" ticket:

```bash
ls .agents/artifacts/${TICKET}-*.md
```

---

## Step 4: Confirm and Clean

Ask: *"Remove artifacts for the 'safe to remove' tickets? (yes/no/pick specific tickets)"*

On confirmation:

```bash
rm .agents/artifacts/${TICKET}-*.md
```

If the user also wants to clean up local branches:

```bash
git branch -d "$BRANCH_NAME"
```

Report what was removed:

```
Removed:
- AIH-1230: ticket.md, plan.md, review-impl.md, tests.md
- AIH-1235: experiment-abc123.md, plan.md

Kept:
- AIH-1234: 3 artifacts (ticket still in progress)
```

---

## Quality Bar

- Never delete without explicit user confirmation
- Default to keeping artifacts when status is ambiguous
- If `acli` or `glab` are unavailable, use git data alone and mark Jira/MR status as "unknown"
- Show exactly which files will be deleted before asking for confirmation
- Offer to archive instead of delete if the user prefers (`mv` to `.agents/artifacts/.archive/`)
