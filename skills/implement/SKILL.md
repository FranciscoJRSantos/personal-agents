---
name: implement
description: >
  Vertical-slice implementation with TDD inside each slice. Reads the plan and
  kanban-board artifacts to determine which slice to implement. Each slice
  crosses all layers (data → pure → edge → UI → integration) and follows
  Red-Green-Refactor. Clear context between slices. Use this skill whenever the
  user says "implement", "start coding", "proceed with implementation",
  "/implement", or wants to begin implementation after a plan exists.
  Entry point: /implement
---

# Implement Skill

Guides implementation one vertical slice at a time using the Kanban board artifact
as the source of truth. Each slice delivers something testable and crosses all layers.
TDD is built into the loop (Red → Green → Refactor). Context is cleared between slices
(Ralph Loop) to keep the main context lean.

---

## Gotchas

- Never skip the quality gate (Step 4). If the target language has no test framework or
  type checker, install or configure one before writing any production code.
- When exploring the module before the Red phase, read the relevant files directly. One focused exploration pass per slice.
- After each slice completes, run `/clear` before starting the next slice. This keeps the
  main context in the "smart zone" and avoids context bloat.
- Pull coding conventions from project AGENTS.md at the start of each slice (Step 4).
  Do NOT load them in Step 1 — only the slice's own conventions are needed.
- If a slice is tagged `afk`, stop at the gate and wait for user input before proceeding.
- If the last slice completes, mark the artifact as complete and recommend `/review`.

---

## Step 1: Load Artifacts

Extract the ticket ID from the current branch name:

```bash
TICKET=$(git branch --show-current | grep -oE '[A-Z]+-[0-9]+')
echo "Ticket: ${TICKET:-<none detected>}"
```

Read the plan artifact for full context:

```bash
cat .agents/artifacts/${TICKET}-plan.md 2>/dev/null
```

If not found, stop immediately:

> "No plan artifact found for `${TICKET}`. Run `/plan ${TICKET}` first to generate
> an implementation plan before proceeding."

Read the Kanban board artifact for slice definitions:

```bash
cat .agents/artifacts/${TICKET}-kanban-board.md 2>/dev/null
```

If not found, stop immediately:

> "No kanban-board artifact found for `${TICKET}`. Run `/plan ${TICKET}` first to
> generate a plan with slice decomposition."

Also check for an existing progress artifact:

```bash
cat .agents/artifacts/${TICKET}-impl-progress.md 2>/dev/null
```

If found with `status: in_progress` — display the slice table and determine the first
slice with `status: pending`. Announce:

> "Resuming implementation — Slices [N, M] are complete. Starting from Slice [K]."

Skip directly to the resume point at Step 4 (Quality Gate).

If found with `status: complete` — warn:

> "Implementation appears already complete. Run `/review` to review the changes,
> or run `/status` for a full overview."

---

## Step 2: Display the Kanban Board

Show the slice dependency graph to the user:

```
## Kanban Board: <TICKET>

| Slice | Title | Blocks | Blocked By | Tags | Status |
|-------|-------|--------|------------|------|--------|
| 1     | ...   | [2]    | []         | —    | pending |
| 2     | ...   | [3]    | [1]        | —    | pending |
| 3     | ...   | []     | [2]        | afk  | pending |
```

Identify which slice(s) are unblocked (no blockers, or all blockers complete):

- **First unblocked slice:** Slice [N]
- **Parallel candidates:** Slices [M, O] can run in parallel if tagged `parallel`

Ask the user which slice to start with:

> "The first unblocked slice is Slice [N]: [title]. Shall I start there, or skip to
> a different unblocked slice?"

---

## Step 3: Create Progress Artifact (first slice only)

If no progress artifact exists yet:

```bash
mkdir -p .agents/artifacts
```

Write `.agents/artifacts/<TICKET>-impl-progress.md`:

```yaml
---
artifact: impl-progress
ticket: <TICKET>
skill: implement
status: in_progress
created: <ISO 8601 timestamp>
current_slice: <SLICE_ID>
completed_slices: []
---

## Slice Progress

| Slice | Title | TDD (RGR) | Status | Completed | Checks |
|-------|-------|-----------|--------|-----------|--------|
| 1 | <title> | pending | pending | — | — |
| 2 | <title> | pending | pending | — | — |
| 3 | <title> | pending | pending | — | — |
```

---

## Step 4: Quality Gate — Verify Test Infrastructure

Before writing any code for the current slice, verify the feedback loop infrastructure
for the target module's language and framework:

```bash
# Detect stack
FILES_CHANGED=<module files for this slice>

# Python
if echo "$FILES_CHANGED" | grep -q '\.py$'; then
  echo "=== Python checks ==="
  uv run pytest --collect-only -q 2>&1 | tail -5
  uv run ruff check . 2>&1 | tail -5
  uv run mypy . 2>&1 | tail -5
fi

# TypeScript/JavaScript
if echo "$FILES_CHANGED" | grep -qE '\.ts$|\.tsx$|\.js$'; then
  echo "=== TS/JS checks ==="
  npm test -- --passWithNoTests 2>&1 | tail -5
  npm run typecheck 2>&1 | tail -5
  npm run lint 2>&1 | tail -5
fi

# Ruby
if echo "$FILES_CHANGED" | grep -q '\.rb$'; then
  echo "=== Ruby checks ==="
  bundle exec rspec --dry-run 2>&1 | tail -5
  bundle exec rubocop 2>&1 | tail -5
fi
```

If any check fails because the tool is missing or not configured, install/configure it.
If any check fails for pre-existing reasons (not related to the current slice), note
them as deferred items and proceed.

**If tests exist for the module** — note the test framework and conventions:
```bash
# Show a sample test file for conventions
TEST_FILE=$(find . -path '*/test*' -name "*$(basename $(echo $FILES_CHANGED | head -1 | sed 's/\.py$//' | sed 's/\.ts$//'))*" 2>/dev/null | head -1)
[ -n "$TEST_FILE" ] && head -30 "$TEST_FILE"
```

**If no tests exist for the module** — this is the first TDD cycle for this area. Plan
to write the first test in Step 5.

### Pull Conventions

Load project-specific conventions that apply to this slice:

```bash
echo "=== Project conventions ==="
cat AGENTS.md 2>/dev/null | head -50
cat .agents/conventions.md 2>/dev/null
```

Extract only the rules relevant to the current slice's language and module type.

---

## Step 5: Explore the Module (before Red phase)

Before writing tests or code, read the relevant module files directly (see Gotchas —
one focused exploration pass per slice). Use the slice's `module_interfaces` list from
the Kanban board:

- Read each file listed under `module: <file path>`
- Search for existing test files that cover the module
- Note existing type definitions, function signatures, and conventions

---

## Step 6: RED — Write a Failing Test

Write a test that captures the slice's acceptance criterion. The test should fail
because the production code doesn't exist yet (or doesn't implement the behavior).

Rules:
- Write exactly one test (or a small group if the slice has multiple facets)
- The test must be runnable and deterministically fail
- Do NOT write any production code in this step
- Follow existing test conventions discovered in Step 4

After writing the test, run it to confirm it fails:

```bash
# Python
uv run pytest <test_file> -k <test_name> -v 2>&1 | tail -15

# TypeScript/JavaScript
npx jest <test_file> --testNamePattern <test_name> 2>&1 | tail -15

# Ruby
bundle exec rspec <test_file> -e <test_name> 2>&1 | tail -15
```

Show the failing test output and confirm: *"Test fails as expected (RED). Proceed to GREEN phase?"*

---

## Step 7: GREEN — Implement Minimum Code

Write the minimum production code to pass the test. This crosses all layers relevant
to the slice — types, logic, edge code, and wiring — but only what's needed to make
the test pass.

Rules:
- Write the minimum code — no gold plating, no future-proofing
- Cross all layers for this slice (not just one stage)
- Integrate existing modules rather than rewriting them
- If the plan prescribes a specific implementation, follow it — but only implement
  enough to pass the test

After writing production code, run the test again to confirm it passes:

```bash
# Python
uv run pytest <test_file> -k <test_name> -v 2>&1 | tail -15

# TypeScript/JavaScript
npx jest <test_file> --testNamePattern <test_name> 2>&1 | tail -15

# Ruby
bundle exec rspec <test_file> -e <test_name> 2>&1 | tail -15
```

If the test fails, iterate: fix the production code and re-run. If 3+ attempts fail,
stop and ask the user for guidance.

Show the passing test: *"Test passes (GREEN). Ready to refactor?"*

---

## Step 8: REFACTOR — Clean Up

With the test passing, refactor both test and production code:

1. Remove duplication
2. Improve naming
3. Align with project conventions from Step 4
4. Check for edge cases that should be tested

After refactoring, run the test again to confirm it still passes:

```bash
# Run all tests (not just the new one) to check for regressions
# Python
uv run pytest 2>&1 | tail -10

# TypeScript/JavaScript
npx jest --passWithNoTests 2>&1 | tail -10

# Ruby
bundle exec rspec 2>&1 | tail -10
```

If any tests fail, revert the refactoring changes and try a more conservative approach.

---

## Step 9: Verify — Run Full Check Suite

Run the full verification suite for the project:

```bash
# Detect and run verification
make check 2>/dev/null || make test 2>/dev/null || echo "No check target found"
```

Report results:
- **All passing** — proceed to gate
- **Failures in new code** — fix and re-run
- **Pre-existing failures** — note as deferred items, proceed

---

## Step 10: GATE — Slice Approval

Present the slice summary:

```
## Slice <N>: <title> Complete

### What was built
- [file 1]: <what was added/changed>
- [file 2]: <what was added/changed>

### Tests
- <test file>: <what was tested>
- Test count: <N> test(s)

### TDD Cycle
- RED: <test name> — failed as expected ✅
- GREEN: <N> iterations — passed ✅
- REFACTOR: <changes made> ✅

### Verification
- Lint: ✅/⚠️
- Types: ✅/⚠️
- Tests: ✅/⚠️

### Deviations
- [none / list of Rule N auto-fixes applied]
```

Gate conditions:
- **`afk` tag** — stop and wait for user judgment:
  > "This slice is tagged `afk` — please review and confirm before proceeding."
- **`hitl` tag** — stop and request human review:
  > "This slice is tagged `hitl` — please review the AI output and approve or request changes."
- **No special tags** — standard gate:
  > "Slice <N> complete. Say 'approved' to continue to the next slice, or tell me what to adjust."

**Do not proceed until the user approves.**

---

## Step 11: Update Progress Artifact

After approval, update the progress artifact:

```bash
TICKET=$(git branch --show-current | grep -oE '[A-Z]+-[0-9]+')
PROGRESS_FILE=".agents/artifacts/${TICKET}-impl-progress.md"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Read current content
CONTENT=$(cat "$PROGRESS_FILE")

# Update the current slice row: TDD=RGR → done, Status → complete, Completed → now, Checks → pass
# Find the slice by ID and update its row
# Set current_slice to the next unblocked slice ID
# Append slice ID to completed_slices list
```

Write the updated artifact back and verify:

```bash
cat .agents/artifacts/${TICKET}-impl-progress.md
```

Also update `.agents/STATE.md`:

```yaml
---
last_updated: <NOW>
current_branch: <BRANCH>
position: implement — slice <N> complete
---
## Decisions
- <decisions made during this slice>

## Blockers
- <if any>
```

---

## Step 12: Clear and Resume

If there are more slices to implement:

> "Slice <N> is done. Run `/clear` to start fresh, then `/implement` to continue with Slice <M>."

The progress artifact carries state between cleared contexts — `/implement` reads it in Step 1
and resumes at the correct slice.

---

## Step 13: All Slices Complete

When the last slice is done:

1. Set `status: complete` in the progress artifact frontmatter
2. Run the full verification suite one final time:

```bash
make check 2>/dev/null || make test 2>/dev/null
```

3. Update `.agents/STATE.md` with `position: complete`

Display completion message:

```
## Implementation Complete

Slices completed:
  ✅ Slice 1 — <title>
  ✅ Slice 2 — <title>
  ✅ Slice 3 — <title>

Checks: ✅ passing  (or: ⚠️  see failures above)

Next step: run /review for a severity-grouped code review against main.
```

Run `/clear` before `/review` to keep review context focused.

---

## Helper: Quality Gate Script

Reusable check for test infrastructure (Step 4). Run this at the start of each slice:

```bash
quality_gate() {
  local lang=$1
  case "$lang" in
    python)
      uv run pytest --collect-only -q 2>/dev/null && echo "pytest: available"
      uv run ruff check . 2>/dev/null && echo "ruff: available"
      uv run mypy . 2>/dev/null && echo "mypy: available"
      ;;
    typescript)
      npx jest --passWithNoTests 2>/dev/null && echo "jest: available"
      npx tsc --noEmit 2>/dev/null && echo "tsc: available"
      npx eslint . 2>/dev/null && echo "eslint: available"
      ;;
    ruby)
      bundle exec rspec --dry-run 2>/dev/null && echo "rspec: available"
      bundle exec rubocop 2>/dev/null && echo "rubocop: available"
      ;;
  esac
}
```

---

## Helper: Pull Conventions Script

Reusable convention puller (Step 4). Run this at the start of each slice:

```bash
pull_conventions() {
  local lang=$1
  echo "=== AGENTS.md ==="
  grep -A5 "$lang" AGENTS.md 2>/dev/null || true
  echo "=== Conventions ==="
  cat .agents/conventions.md 2>/dev/null || echo "(no project conventions)"
}
```

---

## Authentication Gate Protocol

Auth errors during execution are *gates*, not bugs. Indicators: "Not authenticated", "Not logged in", "Unauthorized", "401", "403", "Please run {tool} login", "Set {ENV_VAR}".

When encountered during any slice:
1. Recognize it's an auth gate, not a Rule 1 bug
2. STOP the current task immediately
3. Show the user exactly what command to run or credential to provide (e.g. `glab auth login`, `huggingface-cli login`, API key name)
4. Provide a verification command to confirm auth is working
5. Wait for user to complete the auth step before continuing

Document auth gates as "normal flow" in the slice gate summary, not as deviations.

---

## Deviation Rules

While executing a slice, you may discover work not explicitly in the plan. Apply these rules automatically. Track all deviations in the slice summary when presenting for gate approval.

**Auto-fix** (no permission needed):

| Rule | What | Examples |
|------|------|----------|
| 1 | Bugs in code you just wrote | Wrong queries, logic errors, type errors, null pointer exceptions, broken validation, security vulnerabilities, race conditions |
| 2 | Missing critical functionality | Error handling, input validation, null checks, auth on protected routes, missing DB indexes, no error logging |
| 3 | Blocking issues | Missing dependency, wrong types, broken imports, missing env var, circular dependency |

**Ask** (stop and get user decision):

| Rule | What | Examples |
|------|------|----------|
| 4 | Architectural changes | New DB table (not column), major schema changes, new service layer, switching libraries/frameworks, changing auth approach, new infrastructure, breaking API changes |

Fix inline → add/update tests if applicable → verify fix works → continue task. Document deviations in the slice gate summary using format: `[Rule N - Type] description`.

**Scope boundary:** Only auto-fix issues DIRECTLY caused by the current slice's changes. Pre-existing linting errors or failures in unrelated files are out of scope — log them to .agents/STATE.md as deferred items.

**Fix attempt limit:** After 3 auto-fix attempts on a single issue, stop fixing, document remaining issues in the summary as "Deferred Issues", and continue to the next slice.

---

## Quality Bar

A good implementation under this skill should:
- Follow TDD: RED → GREEN → REFACTOR, never write production code before a failing test
- Deliver each slice as a vertical cross-section — types, logic, edge, and wiring in one pass
- Keep slices small enough to review in one glance
- Pass the quality gate before writing code
- Pass full verification before presenting for gate approval
- Pull conventions (don't push them) — keep implementer context lean
- Hand off to `/clear` between slices
