---
name: plan
description: >
  Fetches a Jira ticket, detects its type, and generates a type-aware implementation
  plan. Presents the plan for approval before writing it back to Jira as a comment.
  Use this skill whenever the user invokes /plan PROJ-123 or asks to generate an
  implementation plan for a Jira ticket.
  Entry point: /plan PROJ-123
---

# Plan Skill

Fetches a Jira ticket and produces a structured, type-aware implementation plan.
Nothing is written to Jira until the user explicitly approves.

---

## Step 1: Fetch the Ticket

First check for a local artifact from `/refine`:

```bash
TICKET=<PROJ-123>
cat .claude/artifacts/${TICKET}-ticket.md 2>/dev/null
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

## Step 4: Present for Approval

Show the full plan, then ask:

*"Does this plan look right? Say 'approved' to post it as a Jira comment, or tell me what to adjust."*

Do not write to Jira yet.

---

## Step 5: Write to Jira (only after explicit approval)

The user must say "approved", "yes", "lgtm", or similar. If they ask for changes,
revise the plan and show the updated version.

First check available flags:

```bash
acli jira workitem comment --help
```

Then post the plan as a comment:

```bash
acli jira workitem comment add PROJ-123 --body "[plan content]"
```

Confirm the comment was posted and show the ticket URL or key.

---

## Step 6: Write Artifact

After the Jira comment is confirmed, write the plan locally so downstream skills can use it:

```bash
mkdir -p .claude/artifacts
```

Write `.claude/artifacts/<TICKET>-plan.md`:

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

This artifact is read by `/branch` (plan summary on checkout), `/review` (acceptance criteria check), and `/ship` (commit message context).

---

## Quality Bar

A good plan should:
- Use exact values from the ticket (metrics, thresholds, criteria) — never invent them
- Be executable: someone unfamiliar with the ticket can follow the steps
- Be proportionate: a small QoL change doesn't need 5 pages; an ML experiment does
- Surface risks or ambiguities the ticket author may not have considered
- Leave the "out of scope" section explicit, not implied
