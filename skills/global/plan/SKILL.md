---
name: plan
description: >
  Fetches a Jira ticket, detects its type, and generates a type-aware implementation
  plan with Kanban/DAG vertical slices. Presents the plan for approval before writing
  it back to Jira as a comment. Produces both a plan artifact and a kanban-board artifact.
  Use this skill whenever the user invokes /plan PROJ-123 or asks to generate an
  implementation plan for a Jira ticket.
  Entry point: /plan PROJ-123
---

# Plan Skill

Fetches a Jira ticket and produces a structured, type-aware implementation plan
with a Kanban board of vertical slices. Nothing is written to Jira until the user
explicitly approves.

---

## Gotchas

- `acli jira get` often returns sparse output for tickets with custom fields — fall back to `acli jira workitem view --json` immediately if key fields (description, type) are missing.
- Ticket type detection can fail for hybrid tickets (e.g. a Feature with ML evaluation components). When in doubt, ask the user rather than guessing — getting the type wrong produces a structurally mismatched plan.
- Never invent metric values, thresholds, or acceptance criteria — if the ticket doesn't specify them, mark them as `TBD` and flag this to the user before proceeding.
- `acli jira workitem comment create` accepts `--body-file` for ADF JSON. Always convert markdown plans to ADF before posting (Step 5 handles this).

---

## Step 1: Fetch the Ticket

First check for a local artifact from `/refine`:

```bash
TICKET=<PROJ-123>
cat .agents/artifacts/${TICKET}-ticket.md 2>/dev/null
```

If found and complete, use it directly — no need to fetch from Jira.

If not found, fetch from Jira:

```bash
acli jira get PROJ-123
```

If output is sparse, try:

```bash
acli jira workitem view PROJ-123 --json
```

Extract:
- Summary / title
- Description (full text, including any structured fields)
- Issue type
- Acceptance criteria (explicit or implied)
- Any linked tickets or context

Also load relevant memory context to inform the plan:

```bash
GLOBAL_MEM=~/.agents/memory/MEMORY.md
PROJECT_MEM=./agents/memory/MEMORY.md

[ -f "$GLOBAL_MEM" ] && cat "$GLOBAL_MEM"
[ -f "$PROJECT_MEM" ] && cat "$PROJECT_MEM"
```

Scan index entries relevant to this ticket (related project goals, past decisions, known
constraints). For each relevant entry, load its full file:

```bash
cat ~/.agents/memory/<matched-slug>.md
cat ./agents/memory/<matched-slug>.md
```

If no memory files exist, skip silently. Use recalled context in Step 3 when writing the plan.

---

## Step 2: Detect Ticket Type

Determine the type from the ticket content:

| Type | Signals |
|------|---------|
| **ML experiment** | hypothesis, model, training, metric, baseline, eval |
| **API QoL** | endpoint, response, latency, client, schema, backwards compat |
| **CI/CD** | pipeline, deploy, workflow, GitHub Actions, build, infra |
| **Feature** | user story, product behaviour, acceptance criteria |
| **Epic** | issuetype = Epic, large body of work, multiple child issues, quarter-long scope |

If the ticket is an Epic, fetch child issues before proceeding to Step 3:

```bash
acli jira workitem search --jql 'parent = PROJ-123' --json
```

Group child issues by status (Done/Cancelled vs. open) and by theme (e.g. model training,
infra, API, experiments). This becomes the input for the Epic Breakdown Plan.

If genuinely ambiguous, ask the user to clarify before proceeding.

---

## Step 3: Generate the Plan

Produce a detailed plan using the structure for the detected type. Pull specific
values (metrics, thresholds, criteria) directly from the ticket — never invent them.

---

### ML Experiment Plan

```markdown
## Hypothesis
[Exact hypothesis from ticket — falsifiable, with expected direction and magnitude]

## Experiment Design
- **What changes:** [model components, training config, data pipeline]
- **What is controlled:** [everything held constant to isolate the variable]
- **Run configuration:** [framework, hardware, seed, reproducibility notes]

## Implementation Steps
1. Data preparation — [any preprocessing, splits, or augmentation needed]
2. Model changes — [architecture or config changes]
3. Training — [run command, wandb project/group, expected duration]
4. Evaluation — [eval script, dataset, how metrics are computed]

## Evaluation Criteria
| Metric | Baseline | Success Threshold | Source |
|--------|----------|-------------------|--------|
| [metric] | [value from ticket] | [threshold from ticket] | [ticket field] |

## Failure Criteria and Next Steps
- **Failure if:** [condition that clearly indicates the hypothesis is false]
- **Next steps on failure:** [from ticket, or derived — next hypothesis, ablation, stop]
```

---

### API QoL Plan

```markdown
## Current Behaviour
[Summary of what the API does today — status codes, payloads, latency if known]

## Proposed Change
[Interface definition: endpoint, method, request/response schema]

## Backwards Compatibility Analysis
- Breaking change: [yes/no and why]
- Migration required: [which consumers, what they need to change]
- Deprecation timeline: [if applicable]

## Affected Consumers
| Consumer | Impact | Migration needed |
|----------|--------|-----------------|
| [service/team] | [what breaks or changes] | [yes/no + notes] |

## Implementation Steps
1. [ordered steps]

## Test Plan
- Schema contract tests: [what to validate]
- Status code tests: [expected codes per scenario]
- Latency regression: [threshold and measurement method]
```

---

### CI/CD Plan

```markdown
## Current State
[What the pipeline/workflow does today]

## Target State
[What it will do after — be specific]

### Definition of Done
[Exact, production-observable criteria — not "pipeline passes" but e.g.
"deploy job completes in <3 min on merge to main; canary error rate stays
below 0.1% for 10 minutes post-deploy; alert X stays silent"]

## Implementation Steps
| Step | Description | Rollback point |
|------|-------------|---------------|
| 1 | [action] | [how to revert this step alone] |
| 2 | [action] | [how to revert this step alone] |

## Verification Steps
How to confirm this is working in production:
1. [observable check — specific metric, log, dashboard, or alert]
2. [...]

## Rollback Procedure
[Ordered steps to fully revert if the change causes a production incident]
```

---

### Feature Plan

```markdown
## User Story
[As a [role] I want [capability] so that [outcome]]

## Acceptance Criteria
- [ ] [testable condition]
- [ ] [testable condition]

## Technical Approach
[Architecture decisions, key components, data flow]

## Implementation Steps
1. [ordered steps]

## Out of Scope
- [explicit list — related things this ticket does NOT cover]

## Test Plan
- Unit: [what to test at the unit level]
- Integration: [what to test end-to-end]
- Manual verification: [what to check by hand before merging]
```

---

### Epic Breakdown Plan

```markdown
## Problem Statement
[Why this epic exists — the chronic issue or gap it addresses, and why it has no end today]

## Proposed Bounded Sub-Epics

| Sub-Epic | End Condition | Open Work | Done Work |
|----------|---------------|-----------|-----------|
| [name] | [observable, specific — not "improve X"] | [ticket keys] | [ticket keys] |

## Recurring Work → Process
[List any child issues that repeat on a cycle. These should become a documented
process/runbook rather than tickets in a perpetual epic. Each cycle gets its own
short-lived versioned epic, not a backlog item in a catch-all.]

## Child Issues Reassignment
| Ticket | Summary | Proposed Destination |
|--------|---------|---------------------|
| [key] | [title] | [sub-epic name or PROCESS] |

## Definition of Done for Each Sub-Epic
[For each proposed sub-epic, state the exact observable condition that closes it.
Never accept "ongoing" or "as needed" — every epic must have an end state.]
```

---

## Step 4: Module Interface Design

This step maps the plan's implementation steps to specific modules, their public
interfaces, and test boundaries. The output feeds directly into the Kanban slice
definitions in Step 5.

For each new or modified module in the plan, define:

| Module | Public Interface | Test Boundaries | Layer |
|--------|-----------------|-----------------|-------|
| `<file path>` | `<methods/types/functions exported>` | `<what to test at the module boundary>` | `<data/pure/edge/ui/integration>` |

Derive the module list from the implementation steps. For each step:
1. Identify which file(s) need to be created or modified
2. List the public API each module will expose
3. Define what constitutes a valid test boundary (inputs → outputs, side effects, error cases)
4. Tag the layer: `data` (schemas, types), `pure` (business logic), `edge` (I/O), `ui` (presentation), `integration` (wiring)

This module map is embedded in the Kanban board artifact as `module_interfaces` per slice.

---

## Step 5: Verify Plan Completeness

Before showing the plan to the user, run an automated verification against it:

1. **AC-to-Step traceability:** Does every acceptance criterion from the ticket have at least one implementation step that addresses it?
2. **Step-to-Verification traceability:** Does every implementation step have a corresponding test/verification section?
3. **Circular dependencies:** Are any steps in the plan mutually dependent on each other?
4. **TBD metrics:** Scan for "TBD", "to be determined", "to be defined" in metrics, thresholds, and criteria — these duplicate the Step 8 scan but this is an earlier catch.

Run these checks against the generated plan text. If any issues are found, fix them in the plan before proceeding. If all checks pass, proceed.

If the plan is an Epic Breakdown, also verify: every sub-epic has an end condition, and no sub-epic is defined as "ongoing" or "as needed."

---

## Step 6: Decompose into Kanban Slices

After the plan is verified and the module interfaces are designed, decompose the work
into vertical slices. Each slice crosses all layers (data → pure → edge → UI → integration)
and delivers something testable.

Group the module interfaces from Step 4 into slices by dependency order:

1. Identify modules with no dependencies — these form the first slice(s)
2. Group remaining modules by their dependency chain
3. Assign each slice an ID, title, description, and tags

**Slice rules:**
- Each acceptance criterion → at least one slice that addresses it
- Slices with no blocking dependencies can be tagged `parallel` — they can run concurrently
- Slices needing user judgment → tag `afk` (away from keyboard)
- Slices needing human review of AI output → tag `hitl` (human in the loop)
- Slices that block others should have their `blocks` field set

**Tags:**
- `afk` — slice requires user judgment (parameter selection, design decisions)
- `hitl` — slice needs human review of AI output
- `parallel` — slice has no blocking relationships — can run in parallel

Example vertical slice decomposition:

```yaml
slices:
  - id: 1
    title: "Define types and schemas"
    description: "Core data types that all downstream modules depend on"
    blocks: [2, 3]
    blocked_by: []
    module_interfaces:
      - module: "src/models.py"
        public_interface: "Item(BaseModel), ItemCreate(Item), ItemUpdate(Item)"
        test_boundaries: "Construction, validation, serialization"
    tags: []
  - id: 2
    title: "Implement business logic"
    description: "Pure domain logic for item processing"
    blocks: [5]
    blocked_by: [1]
    module_interfaces:
      - module: "src/service.py"
        public_interface: "process_item(item: Item) -> Result, validate_schema(data: dict) -> Item"
        test_boundaries: "Happy path, edge cases, error states"
    tags: []
  - id: 3
    title: "Add API endpoints"
    description: "REST endpoints for CRUD operations"
    blocks: [5]
    blocked_by: [1]
    module_interfaces:
      - module: "src/api.py"
        public_interface: "POST /items, GET /items/{id}, DELETE /items/{id}"
        test_boundaries: "Status codes, payload validation, auth errors"
    tags: [parallel]
```

---

## Step 7: Present for Approval

Show the full plan and the Kanban board decomposition.

**Before asking for approval, scan all success metrics and thresholds for placeholder values.** Check the Evaluation Criteria table (ML plans), Definition of Done (CI/CD plans), and Acceptance Criteria (Feature plans) for:
- The literal string "TBD" or "to be determined" or "to be defined"
- Blank / empty threshold cells
- Qualitative-only descriptions with no numeric bound (e.g. "improves performance", "reduces latency", "better than baseline")

If any are found, do NOT show the approval prompt. Instead show:

```
BLOCKED: The following metrics have no numeric threshold and cannot be used to
evaluate experiment success or failure:

- [metric name]: "[current placeholder value]"

Please provide a specific numeric threshold for each before this plan can be approved
(e.g. "AUC-ROC ≥ 0.85" rather than "improves AUC-ROC").
```

Only show the approval prompt once all thresholds are concrete and numeric (or explicitly N/A with a stated reason):

*"Does this plan look right? Say 'approved' to post it as a Jira comment and write artifacts, or tell me what to adjust."*

Do not write to Jira yet.

---

## Step 8: Write to Jira and Artifacts

The user must say "approved", "yes", "lgtm", or similar. If they ask for changes,
revise the plan and show the updated version.

### 8a. Write to Jira

First check available flags:

```bash
acli jira workitem comment --help
```

Then convert the markdown plan to Atlassian Document Format (ADF) and post it:

```bash
# Save the plan markdown to a temp file
PLAN_MD=$(mktemp)
cat > "$PLAN_MD" <<'EOF'
[paste the full approved plan markdown here]
EOF

# Convert to ADF JSON
PLAN_JSON=$(mktemp)
python3 ~/.config/opencode/skills/plan/md_to_adf.py "$PLAN_MD" "$PLAN_JSON"

# Post the ADF comment
acli jira workitem comment create --key PROJ-123 --body-file "$PLAN_JSON"

# Clean up
rm "$PLAN_MD" "$PLAN_JSON"
```

Confirm the comment was posted and show the ticket URL or key.

### 8b. Write Plan Artifact

```bash
mkdir -p .agents/artifacts
```

Write `.agents/artifacts/<TICKET>-plan.md`:

```yaml
---
artifact: plan
ticket: <TICKET>
skill: plan
created: <ISO 8601 timestamp>
status: posted
---
```

Followed by the full plan content.

### 8c. Write Kanban Board Artifact

Write `.agents/artifacts/<TICKET>-kanban-board.md`:

```yaml
---
artifact: kanban-board
ticket: <TICKET>
skill: plan
created: <ISO 8601 timestamp>
status: active
slices:
  - id: 1
    title: <slice title>
    description: <what this slice delivers>
    blocks: [<slice IDs>]
    blocked_by: [<slice IDs>]
    module_interfaces:
      - module: <path>
        public_interface: <methods/types>
        test_boundaries: <boundary description>
    tags: [afk|hitl|parallel]
    status: pending
    completed: null
  - id: 2
    ...
---
```

This artifact is read by `/implement` (to know which slice to work on), `/status` (to show progress), and `pipeline-validator` (to check artifact health).

Run `/clear` before `/implement` to start implementation in a fresh context window.

---

## Quality Bar

A good plan should:
- Use exact values from the ticket (metrics, thresholds, criteria) — never invent them
- Be executable: someone unfamiliar with the ticket can follow the steps
- Be proportionate: a small QoL change doesn't need 5 pages; an ML experiment does
- Surface risks or ambiguities the ticket author may not have considered
- Leave the "out of scope" section explicit, not implied
- Decompose into vertical slices where each slice delivers something testable
- Tag slices appropriately (afk, hitl, parallel) for correct routing during implementation
