---
name: hotfix
description: >
  Streamlined path for urgent fixes that bypasses the full refine/plan pipeline.
  Use this skill whenever the user says "hotfix", "quick fix", "urgent fix",
  "emergency fix", "patch this", or wants to ship a small change fast without
  going through the full planning workflow.
---

# Hotfix Skill

Create a branch, make a fix, run checks, and ship — all in one streamlined flow.
Skips the refine/plan pipeline for urgent or trivial changes.

---

## Step 1: Parse Input

Accept one of these forms:

- `/hotfix <TICKET> <description>` — e.g. `/hotfix AIH-1234 Fix null pointer in predict endpoint`
- `/hotfix <description>` — e.g. `/hotfix Fix typo in README`

Extract ticket ID if present:

```bash
# From argument, not branch
TICKET=$(echo "$INPUT" | grep -oE '[A-Z]+-[0-9]+')
```

---

## Step 2: Create Branch

```bash
# Determine base branch
BASE=$(git branch -a | grep -qE 'develop$' && echo develop || echo main)
git fetch origin "$BASE"
git checkout -b "${BRANCH_NAME}" "origin/$BASE"
```

Branch naming:
- If ticket provided: `hotfix/<TICKET>`
- If no ticket: `hotfix/<slugified-description>` (e.g. `hotfix/fix-typo-readme`)

---

## Step 3: Wait for the Fix

Tell the user the branch is ready and ask them to describe or make the change:

```
Branch `<BRANCH_NAME>` is ready on top of `<BASE>`.

Describe the fix you need, or make your changes and tell me when you're done.
```

If the user describes the fix, implement it directly. If they say they've made changes,
proceed to Step 4.

---

## Step 4: Run Checks

Run the same verification as `/check`:

```bash
make precommit 2>/dev/null || make lint && make type_check && make test
```

If checks fail, show the errors and help fix them before proceeding.

---

## Step 5: Quick Review

Show the diff summary:

```bash
git diff --stat "$BASE"...HEAD
git diff "$BASE"...HEAD
```

Perform a focused review — **Critical items only**:
- Hardcoded secrets, API keys, tokens
- Logic bugs or off-by-one errors
- SQL/shell injection
- Debug statements left in

Skip Warning and Suggestion tiers. This is a hotfix — speed matters, but security
and correctness don't get skipped.

If any Critical issues found, flag them and ask the user to address before proceeding.
If clean, proceed.

---

## Step 6: Commit

Build a commit message:

```
<TICKET>: <concise summary>
```

Or if no ticket:

```
hotfix: <concise summary>
```

Show the proposed message and staged files. Ask user to confirm:

```bash
git status
```

Then commit:

```bash
git add -A
git commit -m "$(cat <<'EOF'
<message>

Co-Authored-By: AI Assistant <noreply@anthropic.com>
EOF
)"
```

---

## Step 7: Push and Create MR

```bash
git push -u origin "$BRANCH_NAME"
```

Create the MR:

```bash
glab mr create \
  --title "<TICKET or 'hotfix'>: <summary>" \
  --description "$(cat <<'EOF'
## Summary
Hotfix: <one-line description of what was fixed and why>

## Test plan
- [ ] Checks pass (`make precommit`)
- [ ] Quick review: no Critical issues

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)" \
  --target-branch "$BASE" \
  --assignee @me
```

Show the MR URL when done.

---

## Quality Bar

- Never skip checks — even hotfixes run lint/type/test
- Always do the Critical-level review scan — no security shortcuts
- Show the commit message before committing — user confirms
- No artifacts produced — hotfixes are ephemeral by design
- If the change is large (>100 lines changed), suggest the full `/review` + `/ship` flow instead
- Target branch defaults to the base branch (develop or main), not hardcoded
