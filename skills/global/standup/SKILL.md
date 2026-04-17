---
name: standup
description: >
  Generate a standup-style progress summary from git history, open MRs, pipeline
  status, and Jira tickets. Use this skill whenever the user says "standup",
  "what did I do", "progress update", "daily summary", "weekly summary",
  "end of day summary", or "what happened this week".
---

# Standup Skill

Generate a progress summary by pulling data from git, GitLab, and Jira.

---

## Step 0: Load Memory Context

Load the memory index to surface project context before gathering activity data:

```bash
GLOBAL_MEM=~/.agents/memory/MEMORY.md
PROJECT_MEM=./agents/memory/MEMORY.md

[ -f "$GLOBAL_MEM" ] && cat "$GLOBAL_MEM"
[ -f "$PROJECT_MEM" ] && cat "$PROJECT_MEM"
```

Scan for project-related entries (active goals, stakeholders, ongoing initiatives).
For each relevant entry, load its full file:

```bash
cat ~/.agents/memory/<matched-slug>.md      # global entries
cat ./agents/memory/<matched-slug>.md       # project entries
```

Use recalled context to give more meaningful summaries in Step 3. If no memory files
exist, skip silently and proceed.

---

## Step 1: Determine Time Range

Parse the user's input for a time range:

- `/standup` → since yesterday (default)
- `/standup 7d` or `/standup week` → last 7 days
- `/standup 2026-04-01` → since that date
- `/standup month` → last 30 days

```bash
# Default: yesterday
SINCE="yesterday"
```

Adjust `SINCE` based on user input.

---

## Step 2: Gather Data (run in parallel)

### 2a. Recent commits across current repo

```bash
GIT_AUTHOR=$(git config user.name)
git log --since="$SINCE" --author="$GIT_AUTHOR" --oneline --all
```

### 2b. Open and recently merged MRs

```bash
echo "=== Open MRs ==="
glab mr list --assignee=@me 2>/dev/null

echo "=== Recently merged ==="
glab mr list --assignee=@me --state=merged 2>/dev/null | head -10
```

### 2c. Pipeline status for current branch (if on a feature branch)

```bash
glab ci status 2>/dev/null
```

### 2d. Active artifacts (tickets in progress)

```bash
echo "=== Active plan artifacts ==="
ls .agents/artifacts/*-plan.md 2>/dev/null
for f in .agents/artifacts/*-plan.md; do
  [ -f "$f" ] || continue
  ticket=$(grep -m1 '^ticket:' "$f" | awk '{print $2}')
  status=$(grep -m1 '^status:' "$f" | awk '{print $2}')
  echo "  $ticket (plan status: $status)"
done
```

### 2e. Recently touched Jira tickets (optional — fail silently)

```bash
acli jira workitem search \
  --jql "assignee = currentUser() AND status != Done AND updated >= '-7d'" \
  --json 2>/dev/null | head -30
```

---

## Step 3: Format the Summary

Structure the output as:

```markdown
## Standup — <date>

### Done
- <TICKET>: <summary of what was completed> (<MR link if merged>)
- ...

### In Progress
- <TICKET>: <what the branch/artifact state indicates>
  - Branch: <name>, <N> commits ahead of main
  - Pipeline: <passing/failing/none>
  - Artifacts: <which exist and their status>
  - Next: <derived from /status logic — what should happen next>

### Blocked / Needs Attention
- <MR or ticket with problems: CI failing, review findings, stale>
- ...
```

**Formatting rules:**
- Group commits by ticket ID where possible
- If a commit doesn't match a ticket pattern, list it under "Other"
- Link MRs as `!<number>` (GitLab convention)
- Keep each item to one line plus optional sub-bullets
- If nothing happened in the time range, say so honestly: "No activity since <date>"

---

## Step 4: Offer Next Actions

After the summary, suggest actionable next steps:

```
**Actions:**
- Want this formatted as a plain bulleted list for pasting into Slack?
- Start working on <highest priority in-progress item>?
```

---

## Quality Bar

- Never produce artifacts — this skill is read-only
- Fail gracefully: if `glab` or `acli` are unavailable, use git data alone and note the limitation
- Aggregate intelligently: 5 commits on the same ticket = one "Done" line, not 5
- Keep the total output under 30 lines for daily standups
- For weekly summaries, allow more detail but still group by ticket
