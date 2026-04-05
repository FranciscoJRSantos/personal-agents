---
name: implement
description: >
  Staged implementation skill enforcing data model → pure logic → edge logic →
  UI → integration discipline. Hard gates between stages require explicit approval
  before proceeding. Reads the existing <TICKET>-plan.md artifact as source of
  truth. Use this skill whenever the user says "implement", "start coding",
  "proceed with implementation", "/implement", or wants to begin writing code
  after a plan exists.
  Entry point: /implement
---

# Implement Skill

Guides implementation stage by stage using the plan artifact as source of truth.
Each stage is strictly scoped — no stage bleeds into the next. Hard gates require
explicit approval before proceeding. This enforces the discipline of thinking first
(done in `/plan`) and pattern-mapping second (done here).

The 5 stages, in order:
1. **Data model** — types, structs, enums, schemas, interfaces
2. **Pure logic** — business rules, pure functions, module interactions (no I/O)
3. **Edge logic** — external integrations, API calls, DB queries, file I/O
4. **UI components** — presentational components in isolation (skip if no UI)
5. **Integration** — wire all stages together; verify end-to-end

---

## Gotchas

- If the plan doesn't map cleanly to all 5 stages, make a best-effort decomposition
  and show it to the user for confirmation before writing any code.
- Never mix stages — if implementing pure logic reveals a missing type, stop and
  add it to the data model stage before continuing.
- Skip inapplicable stages explicitly, never silently: always say
  "Stage 4 (UI): SKIPPED — no UI components in this plan."
- If `/check` fails at Stage 5, surface the specific failures and ask the user
  whether to fix inline or leave for `/review`.
- **Auto-update progress artifact** after each stage approval. This keeps the progress
  artifact in sync without manual edits.

---

## Helper: Update Progress Artifact

After each stage approval, automatically update the progress artifact to track progress.
Use this helper to:
1. Mark the completed stage as `complete` with current ISO 8601 timestamp
2. Mark the next stage as `in_progress`
3. Save the file

**Script** (run after each stage gate approval):

```bash
TICKET=$(git branch --show-current | grep -oE '[A-Z]+-[0-9]+')
PROGRESS_FILE=".agents/artifacts/${TICKET}-impl-progress.md"

# Read current progress artifact
CONTENT=$(cat "$PROGRESS_FILE")

# Extract frontmatter and table separately
FRONTMATTER=$(echo "$CONTENT" | sed -n '1,/^---$/p')
TABLE=$(echo "$CONTENT" | sed -n '/^---$/,/^$/p' | tail -n +3)
TABLE_AND_BEYOND=$(echo "$CONTENT" | sed -n '/^|/,$p')

# Update the specified stage and next stage in the table
# Replace "CURRENT_STAGE | ... | pending" with "CURRENT_STAGE | ... | complete | <timestamp>"
# Replace "NEXT_STAGE | ... | pending" with "NEXT_STAGE | ... | in_progress"

# Helper function to update progress (use in each stage)
# update_progress_artifact <CURRENT_STAGE_NUM> <NEXT_STAGE_NUM>
# Example: update_progress_artifact 1 2
```

For each stage gate, after user approval:
1. Call this helper with current and next stage numbers
2. Verify the artifact was updated: `cat .agents/artifacts/${TICKET}-impl-progress.md`

---

## Step 1: Load the Plan

Extract the ticket ID from the current branch name:

```bash
TICKET=$(git branch --show-current | grep -oE '[A-Z]+-[0-9]+')
echo "Ticket: ${TICKET:-<none detected>}"
```

Read the plan artifact:

```bash
cat .agents/artifacts/${TICKET}-plan.md 2>/dev/null
```

If not found, stop immediately:

> "No plan artifact found for `${TICKET}`. Run `/plan ${TICKET}` first to generate
> an implementation plan before proceeding."

If found, display a 2–3 sentence summary of what the plan intends to build.

Also check for an existing progress artifact:

```bash
cat .agents/artifacts/${TICKET}-impl-progress.md 2>/dev/null
```

If found with `status: in_progress` — display the stage table and determine the first
stage that is not `complete`. Announce:

> "Resuming implementation — Stages [completed list] are complete. Starting from Stage [N]."

Skip directly to that stage's step (Step 3 = Stage 1, Step 4 = Stage 2, etc.).
Do not re-run completed stages.

If found with `status: complete` — warn:

> "Implementation appears already complete (progress artifact status: complete).
> Run `/review` to review the changes, or continue if you're adding to the work."

---

## Step 2: Decompose into Stages

Parse the plan and map each implementation step to one of the 5 stages. Present
the full breakdown before writing any code:

```
Stage 1 — Data model:
  - [specific types/schemas from the plan]

Stage 2 — Pure logic:
  - [specific functions/modules from the plan]

Stage 3 — Edge logic:
  - [specific integrations/boundaries from the plan]

Stage 4 — UI components:
  - [specific components from the plan]
  OR: SKIPPED — no UI components in this plan

Stage 5 — Integration:
  - [wiring, E2E tests, final verification]
```

Ask: *"Does this stage breakdown look right? Say 'yes' to start Stage 1, or tell
me what to adjust."*

Do not write any code until the user confirms the breakdown.

After the user confirms, create the initial progress artifact:

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
---

| Stage | Description   | Status   | Completed |
|-------|---------------|----------|-----------|
| 1     | Data model    | pending  | —         |
| 2     | Pure logic    | pending  | —         |
| 3     | Edge logic    | pending  | —         |
| 4     | UI components | pending  | —         |
| 5     | Integration   | pending  | —         |
```

---

## Step 3: Stage 1 — Data Model

**Scope:** Only type definitions, structs, enums, schemas, and interfaces.
No logic, no functions, no I/O.

1. Announce: "**Stage 1: Data Model** — implementing [list the specific types]"
2. Write the types only.
3. Show a summary: which files were changed and what types were added.
4. Gate:

> "Stage 1 complete. Review the types above — they shape everything that follows.
> Say 'approved' (or 'next') to move to Stage 2 (Pure Logic), or tell me what
> to adjust."

Do not proceed until the user explicitly approves.

After approval:
1. Update the progress artifact automatically:
   - Mark Stage 1 row: `complete` + current ISO 8601 timestamp
   - Mark Stage 2 row: `in_progress` (no timestamp yet)
2. Read the file, update the two rows, write it back
3. Confirm: "✅ Progress updated — Stage 1 complete, Stage 2 in_progress"

---

## Step 4: Stage 2 — Pure Logic

**Scope:** Pure functions and business rules only. No side effects, no I/O,
no external calls. Functions should be fully described by their name, input
types, and output types.

1. Announce: "**Stage 2: Pure Logic** — implementing [list the specific functions/modules]"
2. Write the logic, depending only on types defined in Stage 1.
3. Show a summary: which files were changed and what functions were added.
4. Gate:

> "Stage 2 complete. Review the logic above — this is the architecture of the system.
> Say 'approved' (or 'next') to move to Stage 3 (Edge Logic), or tell me what
> to adjust."

Do not proceed until the user explicitly approves.

After approval:
1. Update the progress artifact automatically:
   - Mark Stage 2 row: `complete` + current ISO 8601 timestamp
   - Mark Stage 3 row: `in_progress` (no timestamp yet)
2. Read the file, update the two rows, write it back
3. Confirm: "✅ Progress updated — Stage 2 complete, Stage 3 in_progress"

---

## Step 5: Stage 3 — Edge Logic

**Scope:** External integrations only — API calls, DB queries, file I/O, event
handlers, network I/O. Minimize this surface. Scrutinize every boundary.

1. Announce: "**Stage 3: Edge Logic** — implementing [list the specific integrations]"
2. Write the integrations, depending on types from Stage 1 and logic from Stage 2.
3. Show a summary: which files were changed and what boundaries were introduced.
4. Gate:

> "Stage 3 complete. Review the external boundaries above — these are where tech
> debt creeps in. Say 'approved' (or 'next') to move to Stage 4 (UI), or tell
> me what to adjust."

Do not proceed until the user explicitly approves.

After approval:
1. Update the progress artifact automatically:
   - Mark Stage 3 row: `complete` + current ISO 8601 timestamp
   - Mark Stage 4 row: `in_progress` (no timestamp yet)
2. Read the file, update the two rows, write it back
3. Confirm: "✅ Progress updated — Stage 3 complete, Stage 4 in_progress"

---

## Step 6: Stage 4 — UI Components

**Scope:** Presentational components in isolation only. No wiring to business
logic or external state yet.

If no UI components are in scope, skip this stage explicitly:

> "Stage 4 (UI): SKIPPED — no UI components in this plan. Moving to Stage 5."
> Then wait for user acknowledgment before proceeding.
> 
> After acknowledgment, update the progress artifact automatically:
> - Mark Stage 4 row: `skipped` + current ISO 8601 timestamp
> - Mark Stage 5 row: `in_progress` (no timestamp yet)
> - Confirm: "✅ Progress updated — Stage 4 skipped, Stage 5 in_progress"

If applicable:
1. Announce: "**Stage 4: UI Components** — implementing [list the specific components]"
2. Write the components in isolation.
3. Show a summary: which files were changed and what components were added.
4. Gate:

> "Stage 4 complete. Review the components above.
> Say 'approved' (or 'next') to move to Stage 5 (Integration), or tell me what
> to adjust."

Do not proceed until the user explicitly approves.

After approval:
1. Update the progress artifact automatically:
   - Mark Stage 4 row: `complete` + current ISO 8601 timestamp
   - Mark Stage 5 row: `in_progress` (no timestamp yet)
2. Read the file, update the two rows, write it back
3. Confirm: "✅ Progress updated — Stage 4 complete, Stage 5 in_progress"

---

## Step 7: Stage 5 — Integration

**Scope:** Wire all previous stages together. Connect UI to logic, logic to edge
integrations, register routes, initialize services — whatever makes it run end-to-end.

1. Announce: "**Stage 5: Integration** — wiring [list the connections being made]"
2. Write the integration code.
3. Run the check suite:

```bash
# Use /check or detect the stack manually
make check 2>/dev/null || make test 2>/dev/null || echo "No check target found"
```

4. Report check results:
   - If passing: proceed to the final message
   - If failing: surface the specific failures and ask:
     > "These checks are failing: [list]. Should I fix them now, or leave them for
     > `/review` to flag?"

5. Show a summary of what was wired up.

6. After checks pass (or user accepts failures), update the progress artifact:
   - Mark Stage 5 row: `complete` + current ISO 8601 timestamp
   - Confirm: "✅ Progress updated — Stage 5 complete"

---

## Step 8: Done

Update the progress artifact to mark the implementation complete:
1. Set `status: complete` in the frontmatter
2. Mark Stage 5 as `complete` with the current ISO timestamp (if not already done)
3. Add `completed: <ISO 8601 timestamp>` field to the frontmatter
4. Read the file, update it, write it back

Display completion message:

```
## Implementation Complete

Stages completed:
  ✅ Stage 1 — Data model
  ✅ Stage 2 — Pure logic
  ✅ Stage 3 — Edge logic
  ✅ Stage 4 — UI components   (or: ⏭️  SKIPPED)
  ✅ Stage 5 — Integration

Checks: ✅ passing  (or: ⚠️  see failures above)

Next step: run /review for a severity-grouped code review against main.
```

Run `/clear` before `/review` to keep review context focused.

---

## Quality Bar

A good implementation under this skill should:
- Keep stages strictly separated — no type definitions in the logic stage, no logic in the UI stage
- Have a data model small enough to review in one glance (if it's large, the plan has a problem)
- Leave edge logic as thin as possible — just translate between external and internal representations
- Pass `/check` at the integration stage before handing off to `/review`
