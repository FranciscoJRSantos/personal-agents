---
name: ship
description: >
  Commit, push, and create a merge request. Reads the review artifact to gate on
  unresolved critical issues. Use this skill whenever the user says "ship it",
  "commit and push", "create MR", "open a merge request", "push my branch", or
  wants to finalize and submit their work.
---

# Ship Skill

Gate on the review artifact, run a final check, commit with a well-formed message,
push the branch, and create a GitLab MR.

---

## Gotchas

- If `glab mr create` fails because an MR already exists for the branch, run `glab mr view` to get the existing MR URL and show it to the user — do not attempt to create a duplicate.
- Never use `--no-verify` to bypass a failing pre-commit hook. Fix the underlying issue instead.
- Do not use `git add -A`; review `git status` first and stage specific files to avoid committing `.env`, generated files, or large binaries.
- If the branch has no upstream yet, `git push -u origin <BRANCH>` sets it automatically — no separate `git push --set-upstream` needed.
- The `--target-branch` for the MR defaults to the base branch the feature branch was cut from — do not hardcode `main` unless that was the actual base.

---

## Step 1: Gate — Check Review Artifact

```bash
TICKET=$(git branch --show-current | grep -oE '[A-Z]+-[0-9]+')
BRANCH=$(git branch --show-current)
LABEL=${TICKET:-$BRANCH}
cat .agents/artifacts/${LABEL}-review-impl.md 2>/dev/null
```

**If `status: has-findings`**: show the Critical and Warning items from the artifact and
ask the user to confirm they want to proceed anyway, or address them first.

**If `status: clean` or no artifact**: proceed.

---

## Step 2: Run Final Check

```bash
make precommit 2>/dev/null || make lint && make type_check && make test
```

If checks fail, stop and show the errors. Do not commit broken code.

---

## Step 3: Build the Commit Message

Load the plan artifact for context:

```bash
cat .agents/artifacts/${TICKET}-plan.md 2>/dev/null | head -30
```

Format the commit message as:

```
<TICKET>: <concise summary of what changed — from the plan title or diff>

<Optional 1–2 sentence body explaining why, if not obvious from the summary>

Co-Authored-By: AI Assistant <ai@noreply.local>
```

Show the proposed commit message and ask the user to confirm or edit before committing.

---

## Step 4: Commit

Stage all changes (ask user to confirm staged files first):

```bash
git status
git diff --staged --stat
```

Then commit:

```bash
git commit -m "$(cat <<'EOF'
<TICKET>: <summary>

<body if needed>

Co-Authored-By: AI Assistant <ai@noreply.local>
EOF
)"
```

---

## Step 5: Push

```bash
git push -u origin <BRANCH>
```

---

## Step 6: Create Merge Request

```bash
glab mr create \
  --title "<TICKET>: <summary>" \
  --description "$(cat <<'EOF'
## Summary
<bullet points from the plan's implementation steps>

## Test plan
<bullet points from the plan's test plan or acceptance criteria>

🤖 AI-generated
EOF
)" \
  --target-branch main \
  --assignee @me
```

Show the MR URL when done.

---

## Quality Bar

- Never commit if `/check` fails
- Always show the commit message to the user before committing
- Never force-push unless the user explicitly asks
- If the branch has no upstream yet, `-u origin <BRANCH>` sets it automatically
