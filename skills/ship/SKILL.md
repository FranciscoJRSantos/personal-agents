---
name: ship
description: >
  Run the full verification suite (lint, type check, tests), gate on the review
  artifact, commit, push, and create a merge request. Use this skill whenever the
  user says "ship it", "commit and push", "create MR", "open a merge request",
  "push my branch", or wants to finalize and submit their work.
---

# Ship Skill

Run the full check suite, gate on the review artifact, commit with a well-formed
message, push the branch, and create a GitLab MR.

---

## Gotchas

- If `glab mr create` fails because an MR already exists for the branch, run `glab mr view` to get the existing MR URL and show it to the user — do not attempt to create a duplicate.
- Never use `--no-verify` to bypass a failing pre-commit hook. Fix the underlying issue instead.
- Do not use `git add -A`; review `git status` first and stage specific files to avoid committing `.env`, generated files, or large binaries.
- If the branch has no upstream yet, `git push -u origin <BRANCH>` sets it automatically — no separate `git push --set-upstream` needed.
- The `--target-branch` for the MR defaults to the base branch the feature branch was cut from — do not hardcode `main` unless that was the actual base.
- If `make type_check` exits 0 but printed type errors to stderr, the Makefile may be suppressing the exit code — check the output text for error patterns, not just the exit code.
- If a check command is missing (e.g. `make type_check` target not defined), report it as SKIPPED rather than FAIL — the target may simply not exist for this project.

---

## Step 1: Run Verification Suite

Detect the project stack and run lint → type check → tests before anything else.

### 1a. Detect Makefile Targets

```bash
grep -E '^[a-zA-Z_-]+:' Makefile 2>/dev/null | cut -d: -f1 | sort
```

**If a `precommit` target exists**, run it directly and skip to Step 1c:

```bash
make precommit
```

### 1b. Detect Stack and Run Checks

If no `precommit` Make target, detect the stack:

| Check                                                 | Stack           |
|-------------------------------------------------------|-----------------|
| `pyproject.toml` with `[tool.uv]` or `uv.lock` exists | uv (Python)     |
| `pyproject.toml` with `[tool.poetry]` exists          | Poetry (Python) |
| `Gemfile` exists                                      | Ruby            |
| `package.json` exists (no Python files)               | Node.js         |

Run each step sequentially. Stop at first failure only if the failure is blocking
(e.g., import errors break type checking too).

**uv + ruff + ty:**
```bash
make lint
make type_check
make test
make nb_check 2>/dev/null
```

**uv + ruff, no ty:**
```bash
make lint
uv run pytest tests/ -v
```

**Poetry:**
```bash
poetry run flake8 .
poetry run pytest
```

**Ruby:**
```bash
make rubocop 2>/dev/null || docker compose exec web rubocop
make rspec 2>/dev/null || docker compose exec web bundle exec rspec
```

**Node.js:**
```bash
npm run lint
npm test
```

### 1c. Report Check Results

```
## Check Results

| Check       | Result | Details                  |
|-------------|--------|--------------------------|
| Lint        | PASS   |                          |
| Type check  | FAIL   | 3 errors (see below)     |
| Tests       | PASS   | 112 passed, 0 failed     |
```

**On failure:** show the first 3-5 errors with file and line number. Stop and let
the user fix before proceeding. Do not commit broken code.

**On full pass:** proceed to Step 2.

---

## Step 2: Gate — Check Review Artifact

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

## Step 3: Close Plan and Kanban Artifacts

Mark the plan and Kanban board artifacts as `closed` to prevent doc rot. This tells
downstream consumers that the ticket has shipped.

```bash
TICKET=$(git branch --show-current | grep -oE '[A-Z]+-[0-9]+')
LABEL=${TICKET:-$BRANCH}
CLOSED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

for f in ".agents/artifacts/${LABEL}-plan.md" ".agents/artifacts/${LABEL}-kanban-board.md"; do
  if [ -f "$f" ]; then
    sed -i "s/^status: .*/status: closed/" "$f"
    # Add closed timestamp after the status line if not present
    grep -q '^closed:' "$f" || sed -i "/^status: /a closed: $CLOSED" "$f"
    echo "Closed: $f"
  fi
done
```

Also close the impl-progress artifact if it exists:

```bash
[ -f ".agents/artifacts/${LABEL}-impl-progress.md" ] && sed -i "s/^status: .*/status: closed/" ".agents/artifacts/${LABEL}-impl-progress.md"
```

---

## Step 4: Build the Commit Message

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

## Step 5: Commit

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

## Step 6: Push

```bash
git push -u origin <BRANCH>
```

---

## Step 7: Create Merge Request

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

- Never commit if the verification suite (Step 1) fails
- Always show the commit message to the user before committing
- Never force-push unless the user explicitly asks
- If the branch has no upstream yet, `-u origin <BRANCH>` sets it automatically
