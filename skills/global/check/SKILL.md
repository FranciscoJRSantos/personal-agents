---
name: check
description: >
  Auto-detect the project stack and run the full verification suite (lint, type check, tests)
  before committing or pushing. Use this skill whenever the user says "run checks", "precommit",
  "verify my changes", "ready to push?", "check before committing", "lint and test", or asks
  whether their changes are ready to commit or merge.
---

# Check Skill

Detect the project stack, run the appropriate lint → type check → test sequence, and report a structured PASS/FAIL summary.

---

## Step 1: Detect Makefile Targets

Check if a `Makefile` exists and what targets are available:

```bash
grep -E '^[a-zA-Z_-]+:' Makefile 2>/dev/null | cut -d: -f1 | sort
```

**If a `precommit` target exists**, skip to Step 3 and run that directly:

```bash
make precommit
```

---

## Step 2: Detect the Project Stack

If no `precommit` Make target, detect the stack:

| Check | Stack |
|-------|-------|
| `pyproject.toml` with `[tool.uv]` or `uv.lock` exists | uv (Python) |
| `pyproject.toml` with `[tool.poetry]` exists | Poetry (Python) |
| `Gemfile` exists | Ruby |
| `package.json` exists (no Python files) | Node.js |

For **uv** projects, further check if `ty` is configured:

```bash
grep -r 'ty' pyproject.toml 2>/dev/null | grep -E 'type.check|ty\s*='
cat Makefile 2>/dev/null | grep -E 'type_check|typecheck'
```

---

## Step 3: Run Verification

Run each step sequentially, capturing exit codes. Stop at first failure only if the failure is blocking (e.g., import errors break type checking too).

### uv + ruff + ty (aih-confidence)

```bash
make lint
make type_check
make test
```

Also run notebook check if the target exists:

```bash
make nb_check 2>/dev/null
```

### uv + ruff, no ty (aih-error-analysis, aih-nlp-autocoding)

```bash
make lint
uv run pytest tests/ -v
```

### Poetry (aiml-data-pipeline)

```bash
poetry run flake8 .
poetry run pytest
```

### Ruby (mdr-revup)

Check if tests run inside Docker:

```bash
cat Makefile | grep -E 'rspec|rubocop'
```

Then run:

```bash
make rubocop 2>/dev/null || docker compose exec web rubocop
make rspec 2>/dev/null || docker compose exec web bundle exec rspec
```

### Node.js

```bash
npm run lint
npm test
```

---

## Step 4: Report Results

Format a structured summary. Only include checks that were actually run.

```
## Check Results

| Check       | Result | Details                  |
|-------------|--------|--------------------------|
| Lint        | ✅ PASS |                          |
| Type check  | ❌ FAIL | 3 errors (see below)     |
| Tests       | ✅ PASS | 112 passed, 0 failed     |
| Notebooks   | ✅ PASS |                          |

---

### Type Check Errors (first 5)

<file>:<line>: <error message>
...
```

**On failure:** show the first 3–5 errors with file and line number. Identify if the failures are in test files, generated code, or production code — prioritize fixing production code errors.

**On full pass:** confirm the branch is clean to push/commit.

---

## Quality Bar

- Always run all checks, not just the first one that fails (unless an import error makes downstream checks meaningless)
- If a check command is not found (e.g., `make type_check` doesn't exist), note it as SKIPPED rather than FAIL
- For flaky tests, note if a test failed with a non-deterministic pattern (e.g., random seed, network timeout) and suggest a re-run
