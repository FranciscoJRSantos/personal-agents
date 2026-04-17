---
name: status
description: >
  Show the current working state and recommend the next workflow step. Use this
  skill whenever the user says "status", "where was I", "what's next", "catch me up",
  "session start", or begins a new conversation on a feature branch. Also trigger
  when the user asks "what should I do next" or "what's the state of this branch".
---

# Status Skill

Gather the current state from git, artifacts, GitLab, and Jira, then present a
unified dashboard with a recommended next step.

---

## Step 0: Load Memory Context

Load the memory index to surface relevant user preferences and project context before
gathering state:

```bash
GLOBAL_MEM=~/.agents/memory/MEMORY.md
PROJECT_MEM=./agents/memory/MEMORY.md

[ -f "$GLOBAL_MEM" ] && cat "$GLOBAL_MEM"
[ -f "$PROJECT_MEM" ] && cat "$PROJECT_MEM"
```

Scan the index entries for anything relevant to the current session (user preferences,
active project goals, known constraints). For each relevant entry, load its full file:

```bash
cat ~/.agents/memory/<matched-slug>.md      # global entries
cat ./agents/memory/<matched-slug>.md       # project entries
```

If no memory files exist, skip silently and proceed.

---

## Step 1: Identify the Current Context

```bash
BRANCH=$(git branch --show-current)
TICKET=$(echo "$BRANCH" | grep -oE '[A-Z]+-[0-9]+')
echo "Branch: $BRANCH"
echo "Ticket: ${TICKET:-none}"
```

If not on a feature branch (e.g. on `main`), skip to Step 5 (No Active Work).

---

## Step 2: Gather State (run in parallel)

Run all of these concurrently to minimise latency:

### 2a. Artifacts

```bash
LABEL=${TICKET:-$BRANCH}
echo "=== Artifacts ==="
for f in .agents/artifacts/${LABEL}-*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  status=$(grep -m1 '^status:' "$f" | awk '{print $2}')
  echo "  $name  (status: ${status:-unknown})"
done

# Surface impl-progress stage for Step 4 routing
PROG=".agents/artifacts/${LABEL}-impl-progress.md"
if [ -f "$PROG" ]; then
  IMPL_STATUS=$(grep -m1 '^status:' "$PROG" | awk '{print $2}')
  NEXT_STAGE=$(awk -F'|' '/in_progress/{gsub(/ /,"",$2); print $2; exit}' "$PROG")
  echo "  impl-progress: status=$IMPL_STATUS  next-stage=$NEXT_STAGE"
fi
```

### 2b. Git state

```bash
echo "=== Commits ahead of main ==="
git log --oneline main..HEAD 2>/dev/null || git log --oneline origin/main..HEAD 2>/dev/null

echo "=== Uncommitted changes ==="
git status --short

echo "=== Diff summary ==="
git diff --stat main...HEAD 2>/dev/null | tail -1
```

### 2c. GitLab MR & CI

```bash
echo "=== Open MRs for this branch ==="
glab mr list --source-branch="$BRANCH" 2>/dev/null

echo "=== Pipeline status ==="
glab ci status 2>/dev/null
```

### 2d. Jira ticket status (optional — fail silently)

```bash
if [ -n "$TICKET" ]; then
  echo "=== Jira ==="
  acli jira get "$TICKET" 2>/dev/null | head -8
fi
```

---

## Step 3: Present the Dashboard

Format the gathered data as a concise table:

```
# Status: <BRANCH>

| Area        | State                                       |
|-------------|---------------------------------------------|
| Ticket      | <TICKET> — <Jira status or "n/a">           |
| Branch      | <N> commits ahead of main, <clean/dirty>    |
| Artifacts   | <list present artifacts and their statuses>  |
| MR          | <MR number + state, or "none">              |
| CI          | <passing / failing / running / none>         |
```

Keep it scannable — one line per area, no extra prose.

---

## Step 4: Recommend Next Step

Derive the recommendation from what's present and what's missing. Use the **first matching** rule:

1. **No plan artifact** and ticket exists → "Run `/plan <TICKET>` to generate an implementation plan."
2. **Plan exists, no impl-progress artifact, zero commits ahead of main** → "Plan is ready — run `/implement` to begin."
2a. **Plan exists, impl-progress artifact with `status: in_progress`** → "Implementation in progress — resume Stage [N] (from progress artifact). Run `/implement` to continue."
2b. **Plan exists, impl-progress artifact with `status: complete`, no review artifact** → (fall through to rule 3)
3. **Commits exist, no review artifact** → "Run `/review` to review your changes."
4. **Review artifact with `status: has-findings`** → "Address the review findings, then re-run `/review`."
5. **Review artifact with `status: clean`, no MR** → "Run `/ship` to commit, push, and create an MR."
6. **MR exists, CI failing** → "CI is failing — check the pipeline logs with `/gitlab`."
7. **MR exists, CI passing, not merged** → "MR is ready — request a reviewer or merge."
8. **MR merged** → "Work is shipped. Switch back to main."
9. **On main with nothing** → see Step 5.

Present the recommendation as a single bold line below the dashboard:

```
**Next step:** <recommendation>
```

---

## Step 5: No Active Work (on main)

If there is no feature branch context, show a brief summary of recent activity instead:

```bash
echo "=== Recent commits ==="
git log --oneline -5

echo "=== Open MRs assigned to me ==="
glab mr list --assignee=@me 2>/dev/null
```

And recommend:

```
**Next step:** Pick up a ticket — run `/branch <TICKET>` to start, or `/refine` to write one.
```

---

## Quality Bar

- Never produce artifacts — this skill is read-only
- Fail gracefully: if `glab` or `acli` are unavailable, skip those sections and note "GitLab/Jira status unavailable"
- Keep the dashboard under 20 lines — the user wants a glance, not a report
- Always end with exactly one **Next step** recommendation
