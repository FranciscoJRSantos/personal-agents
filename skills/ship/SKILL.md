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

- If MR creation fails because one already exists for the branch (`glab mr create` / `gh pr create`), view it instead of creating a duplicate (`glab mr view` / `gh pr view`) and show the URL to the user.
- Detect the forge from the `origin` remote before creating an MR — use `gh` for GitHub and `glab` for GitLab. If the matching CLI is missing, report it rather than failing the whole ship.
- Never use `--no-verify` to bypass a failing pre-commit hook. Fix the underlying issue instead.
- Do not use `git add -A`; review `git status` first and stage specific files to avoid committing `.env`, generated files, or large binaries.
- If the branch has no upstream yet, `git push -u origin <BRANCH>` sets it automatically — no separate `git push --set-upstream` needed.
- The `--target-branch` for the MR is detected from the branch's actual creation point (merge-base), falling back to git-flow naming conventions — never hardcode `main`.
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

<!-- artifact-label:begin — shared verbatim across /plan, /implement, /review, /ship and @reviewer; make lint-agents checks identity -->
```bash
TICKET=$(git branch --show-current | grep -oE '[A-Z]+-[0-9]+' | head -1)
LABEL=${TICKET:-$(git branch --show-current | tr '/' '-')}
```
<!-- artifact-label:end -->

```bash
cat .agents/artifacts/${LABEL}-review-impl.md 2>/dev/null
```

**If `status: has-findings`**: show the Critical and Warning items from the artifact and
ask the user to confirm they want to proceed anyway, or address them first.

**If `status: clean` or no artifact**: proceed.

---

## Step 3: Close Plan and Kanban Artifacts

Mark the plan and Kanban board artifacts as `closed` to prevent doc rot. This tells
downstream consumers that the ticket has shipped. Reuse the `${LABEL}` resolved in
Step 2 — do not compute it again.

```bash
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
cat .agents/artifacts/${LABEL}-plan.md 2>/dev/null | head -30
```

Format the commit message as a short story. Every change — however small — has a
reason it was made, and that reason must be recorded before shipping.

```
<TICKET>: <narrative summary — what story does this change tell?>

<Why this change was needed — the reasoning, context, or problem being solved.
Always present, even for a small change. Pull from the plan's context/rationale.>

Co-Authored-By: AI Assistant
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

<why this change was needed>

Co-Authored-By: AI Assistant
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

### 7a. Detect the Forge

```bash
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
case "$REMOTE_URL" in
  *github.com*) FORGE=github ;;
  *gitlab*)     FORGE=gitlab ;;
  *)            FORGE=unknown ;;
esac
echo "Forge: ${FORGE}"
```

### 7b. Detect the Target Branch

Detect the branch this one was actually cut from — never hardcode a default:

```bash
BRANCH=$(git branch --show-current)
TARGET_BRANCH=""

# 1. Find the actual parent branch by merge-base recency. The parent branch's
#    tip is the most recent common ancestor: the smallest number of commits
#    between the merge-base and HEAD wins.
TARGET_BRANCH=$(
  for candidate in $(git branch --format='%(refname:short)' | grep -v "^${BRANCH}$"); do
    base=$(git merge-base HEAD "$candidate" 2>/dev/null) || continue
    [ -z "$base" ] && continue
    echo "$(git rev-list --count "$base"..HEAD) $candidate"
  done | sort -n | head -1 | awk '{print $2}'
)

# 2. Fall back to git-flow naming conventions if detection failed.
if [ -z "$TARGET_BRANCH" ]; then
  if [[ "$BRANCH" =~ ^(release|hotfix)/ ]]; then
    TARGET_BRANCH="main"
  elif [[ "$BRANCH" =~ ^(feature|feat|bugfix|fix|chore)/ ]] && git show-ref --verify --quiet refs/heads/develop; then
    TARGET_BRANCH="develop"
  else
    TARGET_BRANCH=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
  fi
fi

echo "Target branch: ${TARGET_BRANCH}"
```

Show the detected target branch to the user and let them override before creating
the MR.

### 7c. Create the MR

Build the description from `templates/mr-description.md`, filling each section
from the plan, the diff, and the review artifact. Include the **Breaking changes**
section only when the change actually breaks something — omit it otherwise.

**GitHub** (`gh` — note `--body`/`--base`):

```bash
gh pr create \
  --title "<TICKET>: <narrative summary>" \
  --body "$(cat <<'EOF'
## What
<bullet points describing what changed>

## Why
<the reasoning, context, or problem being solved>

## How
<implementation approach — key decisions, patterns, files touched>

## Test plan
<how this was verified>

## Breaking changes
<only if applicable; omit this section otherwise>

🤖 AI-assisted
EOF
)" \
  --base "$TARGET_BRANCH" \
  --assignee @me
```

**GitLab** (`glab` — note `--description`/`--target-branch`):

```bash
glab mr create \
  --title "<TICKET>: <narrative summary>" \
  --description "$(cat <<'EOF'
## What
<bullet points describing what changed>

## Why
<the reasoning, context, or problem being solved>

## How
<implementation approach — key decisions, patterns, files touched>

## Test plan
<how this was verified>

## Breaking changes
<only if applicable; omit this section otherwise>

🤖 AI-assisted
EOF
)" \
  --target-branch "$TARGET_BRANCH" \
  --assignee @me
```

**If the forge is unknown or its CLI is missing:** do not fail the ship. Report
the branch and detected target branch, then tell the user to open the MR manually
against `$TARGET_BRANCH`.

Show the MR URL when done.

---

## Quality Bar

- Never commit if the verification suite (Step 1) fails
- Always include the reasoning in the commit message body — even for a small change
- Always show the commit message to the user before committing
- Always detect the MR target branch from the branch's creation point — never hardcode it
- Always detect the forge (GitHub vs GitLab) from the origin remote — never assume one
- Never force-push unless the user explicitly asks
- If the branch has no upstream yet, `-u origin <BRANCH>` sets it automatically
