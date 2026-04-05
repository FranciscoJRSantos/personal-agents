---
name: test
description: >
  Generate tests for the current implementation by reading the plan artifact for acceptance
  criteria and the code diff for what was actually implemented. Use this skill whenever the
  user says "write tests", "generate tests", "add tests", "test coverage", or wants a test
  suite written for their current branch changes.
---

# Test Skill

Generate a test suite from the plan's acceptance criteria and the current implementation diff.
Uses the `test_writer` personal agent for mechanical code generation.

---

## Step 1: Load Context

Get the ticket ID and load relevant artifacts:

```bash
TICKET=$(git branch --show-current | grep -oE '[A-Z]+-[0-9]+')
```

Read the plan artifact for acceptance criteria:

```bash
cat .agents/artifacts/${TICKET}-plan.md 2>/dev/null
```

Get the implementation diff:

```bash
git diff main...HEAD
```

If there is no plan artifact, proceed with the diff alone — generate tests to cover the
observable behaviour of everything that was added or modified.

---

## Step 2: Identify What to Test

From the plan's acceptance criteria and the diff, derive the test cases:

- Each acceptance criterion → at least one test
- Each new function/method → unit test covering happy path + edge cases
- Each changed integration point → integration test
- Each bug fix → regression test (test the broken behaviour before fix)

List the planned test cases before generating code. Ask the user if the coverage looks right.

---

## Step 3: Generate Tests

Using the plan's acceptance criteria and the diff, write the test code directly.
Follow the project's existing test conventions — look at one or two existing test files
to confirm the fixture style, import patterns, and assertion conventions before writing.

Rules for generated tests:
- No stubs, no `pass` bodies, no empty test functions — every test must assert something
- No fabricated implementation details — mock at the system boundary, not at internal functions
- Imports must match actual module paths visible in the diff
- Reuse existing fixtures and factories — do not reinvent them

If there are multiple logical groups (unit, integration, regression), generate each group
separately and confirm the file layout with the user before writing.

---

## Step 4: Write Test Files

Write the generated tests to the appropriate test file(s). Follow the project's test layout:

- **Python (pytest)**: `tests/path/matching/source/test_<module>.py`
- **Ruby (RSpec)**: `spec/path/matching/source/<module>_spec.rb`
- **Node.js (Jest)**: `<module>.test.ts` co-located or in `__tests__/`

Run the tests to confirm they are syntactically valid and at least discoverable:

```bash
# Python
uv run pytest tests/ --collect-only 2>&1 | tail -20

# Ruby
bundle exec rspec --dry-run spec/

# Node
npm test -- --listTests
```

---

## Step 5: Write Artifact

```bash
mkdir -p .agents/artifacts
```

Write `.agents/artifacts/<TICKET>-tests.md`:

```yaml
---
artifact: tests
ticket: <TICKET>
skill: test
created: <ISO 8601 timestamp>
status: draft
---
```

List each test file written and the acceptance criteria it covers:

```
## Test Coverage

| Test file | Acceptance criteria covered |
|-----------|---------------------------|
| tests/api/test_predict.py | AC1, AC3 |
| tests/ml/test_features.py | AC2 |
```

---

## Step 6: Next Steps

After tests pass locally, run `/check` to verify the full suite, then `/ship` to commit and push.

---

## Quality Bar

- Tests must be runnable — no stubs, no `pass`, no empty test bodies
- Each acceptance criterion from the plan must have at least one test
- Tests should assert on outputs, not on implementation details (no mocking internals)
- Use the project's existing fixtures and factories — do not reinvent them
