---
name: learn
description: >
  Codify a correction or convention from the current session into CLAUDE.md (global)
  or .agents/conventions.md (project-specific) in "Always/Never [action] BECAUSE
  [reason]" format. Use this skill whenever the user says "remember this", "add a
  rule", "don't do that again", "learn this", "/learn", or wants to capture a lesson
  from the session before the conversation ends.
  Entry point: /learn [optional rule text]
---

# Learn Skill

Captures a rule or correction from the current session and writes it to a durable
location in "Always/Never [action] BECAUSE [reason]" format — before the conversation
ends and the lesson is lost.

Two destinations:
- `CLAUDE.md` — global rules that apply in all projects (Claude's behavior)
- `.agents/conventions.md` — project-specific patterns for this repo only

---

## Gotchas

- If the user invokes `/learn <rule text>`, skip Step 1 and use that text directly.
- Choose "Always" for positive behaviors, "Never" for prohibitions — match how the rule is naturally expressed.
- The `## Always / Never` section must be a top-level heading. If it doesn't exist, append it at the end of the file — never insert it mid-document.
- A rule without a BECAUSE clause is a bare directive. Bare directives lose their meaning out of context and get ignored over time. Always get the reason.

---

## Step 1: Capture the Rule

If the user provided rule text inline with the slash command, use it directly and skip
to Step 2.

Otherwise ask:

> "What's the rule you want to capture? (e.g. 'never use bare except clauses' or
> 'always validate input before calling external APIs')"

---

## Step 2: Get the "Why"

If the text does not include a causal phrase ("because", "so that", "since", or similar):

> "Why should this rule exist? This becomes the BECAUSE clause — the reason is what makes
> the rule durable and applicable to new situations."

Format the final rule:
- `Always [action] BECAUSE [reason]`
- `Never [action] BECAUSE [reason]`

Show the formatted rule and confirm before writing:

> "Formatted rule: `[rule]` — does this look right, or should I adjust the wording?"

---

## Step 3: Check for Duplicates

Extract the 2–3 most distinctive terms from the rule and search both target files:

```bash
grep -i "[key term 1]" CLAUDE.md .agents/conventions.md 2>/dev/null
```

If a similar rule is found, show it:

> "A similar rule already exists: `[existing rule]`
> Options: (1) add this as a separate rule, (2) replace the existing one, (3) cancel."

If no similar rule, proceed.

---

## Step 4: Determine Scope

Ask:

> "Is this rule global (applies in all projects → CLAUDE.md) or project-specific
> (only for this repo → .agents/conventions.md)?"

Target file:
- Global → `CLAUDE.md` in the project root
- Project-specific → `.agents/conventions.md` (create if it doesn't exist)

---

## Step 5: Write the Rule

Check whether the target file has an `## Always / Never` section:

```bash
grep -n "^## Always" CLAUDE.md 2>/dev/null        # or .agents/conventions.md
```

**If the section exists:** Read the file, find the `## Always / Never` heading, and
append `- [formatted rule]` as the next bullet point under it (before the next `##`
heading or EOF). Write the file back.

**If the section does not exist:** Append the following block to the end of the file:

```markdown

## Always / Never

- [formatted rule]
```

Use read → modify in memory → write back. Do not use sed with complex in-place edits.

---

## Step 6: Confirm

Show what was written:

```
Rule captured:
  File:  CLAUDE.md  (or .agents/conventions.md)
  Rule:  Never use bare except clauses BECAUSE they silently swallow all errors,
         making debugging impossible and hiding production failures.
```
