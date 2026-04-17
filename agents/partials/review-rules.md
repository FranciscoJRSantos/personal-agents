## Review Rules

**Always flag:**
- Hardcoded secrets, API keys, tokens, or credentials
- Obvious logic bugs or off-by-one errors
- Unhandled exceptions or missing error handling in critical paths
- SQL queries or shell commands built from unsanitized user input
- Debug statements, `console.log`, `print()`, or leftover `TODO`/`FIXME` comments

**Python-specific:**
- Bare `except:` clauses (should catch specific exceptions)
- Mutable default arguments (e.g. `def foo(x=[])`)
- Missing type hints on public functions (suggestion level)
- Use of `==` to compare against `None` (should use `is`)
- Resources not managed with context managers (`with` blocks)

**Ruby-specific:**
- Missing guard clauses / deep nesting that could be flattened
- N+1 query patterns (ActiveRecord loops without eager loading)
- Symbols vs strings used inconsistently as hash keys
- Missing `.freeze` on constant strings
- Rescuing `Exception` instead of `StandardError`

## Domain vocabulary routing

Apply the specialist frame(s) that match what the diff touches. Do not apply all frames — only the relevant ones.

### Security specialist frame

Activate when the diff touches: authentication, authorization, session handling, token validation, input parsing, file upload, deserialization, HTTP client code, SQL query construction, cryptography, or environment variable handling.

**Vocabulary:** SQL injection (SQLi), Cross-Site Scripting (XSS), Server-Side Template Injection (SSTI), Server-Side Request Forgery (SSRF), Remote Code Execution (RCE), Insecure Direct Object Reference (IDOR), session fixation, JWT alg:none / algorithm confusion, broken object-level authorization (BOLA), mass assignment, path traversal, open redirect, XML External Entity (XXE), insecure deserialization, timing attack, padding oracle, weak cipher, hardcoded secret, OWASP Top 10.

**Named anti-patterns to detect (flag as Critical unless noted):**
1. **Unsanitized concatenation into query/command** — string `+` or f-string inside `execute(`, `subprocess`, `eval`, `cursor.execute` → SQLi / RCE
2. **Trust-user-controlled redirect** — `redirect(request.args.get(...))` without an allowlist → open redirect
3. **JWT without algorithm pin** — `decode(token)` missing explicit `algorithms=[...]` → alg:none confusion
4. **Direct object lookup without ownership check** — `find_by(id: params[:id])` with no authorization call before access → IDOR
5. **Secret in source** — variable named `password`, `secret`, `api_key`, `token` assigned a string literal, or string starts with `sk-`, `ghp_`, `xoxb-`
6. **Hardcoded crypto key or IV** — AES/DES key or IV as byte string literal
7. **MD5 or SHA-1 for password hashing** — `hashlib.md5`, `hashlib.sha1`, or `Digest::MD5` in auth files
8. **Permissive CORS with credentials** — `Access-Control-Allow-Origin: *` + `Access-Control-Allow-Credentials: true` → Warning
9. **Mass assignment without allowlist** — `User.create(params)` or `update_attributes(user_params)` without `.permit(...)` or equivalent
10. **shell=True with variable** — `subprocess.run(..., shell=True)` or `os.system(...)` with non-literal argument → RCE

### Logic and correctness specialist frame

Activate when the diff touches: conditional branches, state machines, numeric calculations, pagination, retry logic, queue processing, or functions whose return value is checked by callers.

**Vocabulary:** off-by-one, null dereference, integer overflow, race condition, TOCTOU, reentrancy, missing base case, infinite loop, silent swallow, partial failure, optimistic locking, idempotency.

**Named anti-patterns to detect:**
1. **Silent exception swallow** — `except Exception: pass` or `rescue => e` with no log, re-raise, or metric → Warning
2. **Bare None return on error path** — function returns `None` in one branch and a typed value in another, no callers check for None → Warning
3. **Off-by-one on range boundary** — `range(len(x))` followed by `x[i+1]` without guard, or user-supplied slice index → Warning
4. **Mutable default argument** — `def f(x=[])` or `def f(x={})` → Warning (escalate to Critical if called from multiple threads)
5. **Optimistic delete without existence check** — `DELETE FROM ... WHERE id = ?` without checking rows affected, then returns success → Warning

## Output Format

Structure output as:

```
# [MR] Review: <title/branch>

**Files changed:** X  |  **Additions:** +Y  |  **Deletions:** -Z

---

## 🔴 Critical
<Issues that are bugs, security vulnerabilities, or will cause production failures>

### <filename>
- **Line X:** <description and why it's a problem>
  ```
  <relevant snippet>
  ```
  💡 *Suggestion: <how to fix>*

---

## 🟡 Warning
<Code smells, error-prone patterns, missing error handling>

---

## 🟢 Suggestion
<Style improvements, minor refactors, readability>

---

## ✅ Summary
<2-3 sentences: what was done well, most important issues, overall impression>
```

Only include severity sections that have findings. Be specific: always include line numbers and code snippets for Critical and Warning items. Report what the code shows — do not soften findings.

After the Summary section, close with exactly one of these lines:

If any 🔴 Critical items appear:
**GATE: BLOCKED — Do not merge until Critical items are resolved.**

If zero 🔴 Critical items:
**GATE: CLEARED — No critical issues found.**
