---
name: yagni-review
description: >
  Review diffs for over-engineering only. Finds what to delete: reinvented
  standard library, unneeded dependencies, speculative abstractions, dead
  flexibility. One line per finding with tag and replacement. Use when the
  user says "review for over-engineering", "what can we delete", "is this
  over-engineered", "simplify review", "yagni review", or invokes
  /yagni-review. Complements correctness-focused /review — this one only
  hunts complexity.
---

# YAGNI Review

Review the current branch's diff against `main` for unnecessary complexity.
One line per finding: location, what to cut, what replaces it. The diff's
best outcome is getting shorter.

---

## Scope

Over-engineering and complexity **only**. Correctness bugs, security holes,
and performance are explicitly out of scope — route them to `/review`.

---

## Step 1: Get the Diff

```bash
git diff main...HEAD
```

If `main` doesn't exist locally, try `origin/main`, then `master`.

---

## Step 2: Classify Findings

For each finding, assign one tag:

| Tag       | What to cut                                          | Replacement                              |
|-----------|------------------------------------------------------|------------------------------------------|
| `delete:`   | Dead code, unused flexibility, speculative feature   | Nothing — remove it                      |
| `stdlib:`   | Hand-rolled thing the standard library ships         | Name the function/class                  |
| `native:`   | Dependency or code doing what the platform already does | Name the native feature               |
| `yagni:`    | Abstraction with one implementation, config nobody sets, layer with one caller | Inline until a second use exists |
| `shrink:`   | Same logic, fewer lines                              | Show the shorter form                    |

---

## Step 3: Format Output

One line per finding:

```
L<line>: <tag> <what>. <replacement>.
```

For multi-file diffs: `<file>:L<line>: <tag> <what>. <replacement>.`

### Examples

```
L12-38: stdlib: 27-line email validator class. "@" check + confirmation email, 1 line.
L4: native: moment.js imported for one format call. Intl.DateTimeFormat, 0 deps.
repo.py:L88: yagni: AbstractRepository with one implementation. Inline it.
L52-71: delete: retry wrapper around an idempotent local call. Nothing replaces it.
L30-44: shrink: manual loop builds dict. dict(zip(keys, values)), 1 line.
```

---

## Step 4: Score

End with the only metric that matters:

```
net: -<N> lines possible.
```

If there is nothing to cut, say `Lean already. Ship.` and stop.

---

## Boundaries

- Scope: over-engineering and complexity only.
- Correctness bugs, security holes, performance are out of scope — route to `/review`.
- A single smoke test or `assert`-based self-check is the minimum, not bloat — never flag it.
- Does not apply the fixes, only lists them.

---

## Optional: Persist Findings

If the user wants to track deferred findings, mark them with `deferred:` comments
in the code (format: `# deferred: <ceiling>, <upgrade path>`). Then run
`/debt-ledger` to harvest them into a ledger.
