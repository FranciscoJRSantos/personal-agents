---
name: review
description: >
  Review code changes on the current branch against main. Use this skill whenever
  the user asks to "review my branch", "check my changes", "code review", "review
  this PR", "what did I change", or any variation of reviewing uncommitted or
  unmerged work. Trigger even if the user just says "can you check this branch" or
  "look at my changes" — they almost certainly want a structured code review.
---

# Review Skill

Review the current branch's changes against `main` and produce a structured, actionable report grouped by severity.

---

## Gotchas

- For very large diffs (>500 lines), delegate to the `code-reviewer` subagent instead of loading the full diff into main context — the subagent is purpose-built for this and won't bloat the conversation.
- If `main` doesn't exist as a local branch, try `origin/main`, then `master`, then ask the user what the base branch is.
- Context loading in Step 4 is capped at the changed files plus 2 additional context files. For very large diffs (>500 lines), delegate to the code-reviewer subagent instead.
- The branch name may not contain a ticket ID (e.g. on a personal or hotfix branch) — fall back to `LABEL=$BRANCH` for artifact naming, which is already handled in Step 7.

---

## Step 1: Check for Project-Level Instructions

Before doing anything else, check if a project-level review config exists:

```bash
cat .agents/review.md 2>/dev/null
```

If found, read it fully. Those instructions **extend and override** the base behavior below — treat them as additional rules layered on top. Note any:
- Extra focus areas or patterns to flag
- Things to ignore or deprioritize
- Project-specific conventions (architecture patterns, naming rules, etc.)
- Language/framework-specific rules for this project

---

## Step 2: Get the Diff

Run the following to see what's changed on the current branch vs main:

```bash
git diff main...HEAD
```

Also get a summary of which files changed:

```bash
git diff main...HEAD --stat
```

And check for any new files that were added:

```bash
git diff main...HEAD --name-status
```

If `main` doesn't exist, try `origin/main` or `master` as fallbacks.

---

## Step 3: Load Plan Artifact (if available)

Check for a plan artifact to use its acceptance criteria during review:

```bash
TICKET=$(git branch --show-current | grep -oE '[A-Z]+-[0-9]+')
cat .agents/artifacts/${TICKET}-plan.md 2>/dev/null
```

If found, extract the acceptance criteria / test plan section. Use these to check whether the implementation covers what was committed to.

---

## Step 4: Understand Context

For each changed file, read the full file (not just the diff) if it touches business logic, security, authentication, data flow, or database access. Style-only changes (renaming, formatting, comment updates) do not need full file context.

**Context loading limit:** Read at most 2 additional files beyond the changed files themselves. An "additional file" is one not in the diff that provides critical context — for example, a base class the changed file extends, or an interface it implements. Stop there. Do not load callers, siblings, or utilities unless a changed file directly imports something that makes the diff unreadable without it.

If the diff is fully readable without additional context, load zero extra files.

---

## Step 5: Perform the Review

Apply the base review rules below, **plus** any project-level rules from `.agents/review.md`.

### Base Review Rules

**Always flag (regardless of project):**
- Hardcoded secrets, API keys, tokens, or credentials
- Obvious logic bugs or off-by-one errors
- Unhandled exceptions or missing error handling in critical paths
- SQL queries or shell commands built from unsanitized user input
- Debug statements, console.log, print(), or leftover TODO/FIXME comments

**Python-specific defaults:**
- Bare `except:` clauses (should catch specific exceptions)
- Mutable default arguments (e.g. `def foo(x=[])`)
- Missing type hints on public functions (suggestion level)
- Use of `==` to compare against `None` (should use `is`)
- Resources not managed with context managers (`with` blocks)

**Ruby-specific defaults:**
- Missing guard clauses / deep nesting that could be flattened
- N+1 query patterns (ActiveRecord loops without eager loading)
- Symbols vs strings used inconsistently as hash keys
- Missing `.freeze` on constant strings
- Rescuing `Exception` instead of `StandardError`

---

## Step 6: Write the Report

Structure the output as follows. Only include sections that have findings — omit empty severity levels.

```
# Review: <branch name>

**Files changed:** X  |  **Additions:** +Y  |  **Deletions:** -Z

---

## 🔴 Critical
Issues that are likely bugs, security vulnerabilities, or will cause failures in production.

### <filename>
- **Line X:** <description of issue and why it's a problem>
  ```
  <relevant code snippet>
  ```
  💡 *Suggestion: <how to fix it>*

---

## 🟡 Warning
Code smells, error-prone patterns, missing error handling, or things that will likely cause problems later.

### <filename>
- **Line X:** <description>

---

## 🟢 Suggestion
Style improvements, minor refactors, missing type hints, readability improvements.

### <filename>
- **Line X:** <description>

---

## ✅ Summary
<2-3 sentence overall assessment. Mention what was done well, the most important things to address, and an overall impression of the change.>
```

**Formatting rules:**
- Be specific: always include the line number and a short code snippet for Critical and Warning items
- Be constructive: frame suggestions positively, explain *why* something is a problem
- Be concise: don't pad — if the branch looks good, say so
- If there are more than ~15 findings total, focus on the most important ones and note that minor issues were omitted for brevity

---

## Step 7: Write Artifact

Determine status from the findings:
- `status: clean` — no Critical or Warning findings
- `status: has-findings` — any Critical or Warning items present

```bash
TICKET=$(git branch --show-current | grep -oE '[A-Z]+-[0-9]+')
BRANCH=$(git branch --show-current)
LABEL=${TICKET:-$BRANCH}
mkdir -p .agents/artifacts
```

Write `.agents/artifacts/<LABEL>-review-impl.md`:

```yaml
---
artifact: review-impl
ticket: <TICKET>
skill: review
created: <ISO 8601 timestamp>
status: clean        # or: has-findings
---
```

Followed by the full review report.

The `/ship` skill reads this artifact and blocks commit if `status: has-findings`.

Run `/clear` before `/ship` to start the ship step in a fresh context window.

---

## Project-Level Skill Format (for `.agents/review.md`)

Users can create a `.agents/review.md` file in their repo root to customize the review for that project. Example:

```markdown
# Project Review Rules

## Focus Areas
- This project uses the Repository pattern. Flag any direct database calls outside of files in `app/repositories/`.
- All API endpoints must have input validation. Flag any controller actions that use params directly without a validator.

## Ignore
- Ignore line length warnings in `db/schema.rb`
- Don't flag missing type hints in test files

## Stack Notes
- We use Rails 7 with Hotwire. Flag any use of `render json:` in controllers (should use Turbo Streams instead).
- Python services use FastAPI. Flag any route handlers missing `response_model`.
```
