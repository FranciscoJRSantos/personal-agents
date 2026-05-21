---
name: refine
description: >
  Refines a Jira ticket through interactive back-and-forth conversation, then writes
  the result to Jira only after explicit user approval. Use this skill whenever the
  user invokes /refine, wants to turn rough notes into a Jira ticket, or wants to
  improve a vague existing ticket. Supports two entry points:
  - /refine            — user has local notes to turn into a new ticket
  - /refine PROJ-123   — refine an existing ticket that is vague or incomplete
---

# Refine Skill

Turns rough notes or vague tickets into well-specified Jira tickets via conversation.
Nothing is written to Jira until the user explicitly approves.

---

## Step 1: Determine Entry Point

**If a ticket ID was provided** (e.g. `/refine PROJ-123`):

Fetch the ticket first:

```bash
acli jira get PROJ-123
```

If that fails or returns sparse output, try:

```bash
acli jira workitem view PROJ-123 --json
```

Read the ticket carefully. Your job is to identify what is *missing or vague* relative
to the required fields for its type. You will only ask about the gaps — do not
re-ask for things already clearly specified.

**If no ticket ID was provided** (bare `/refine`):

Ask the user to share their notes or context:

> "What notes or context do you have? Paste them here and I'll help turn them into a ticket."

---

## Step 2: Detect Ticket Type

Determine the ticket type from the content, or ask if it's ambiguous:

| Type | Signals |
|------|---------|
| **ML experiment** | hypothesis, model, training, metric, baseline, eval |
| **API QoL** | endpoint, response, latency, client, schema, backwards compat |
| **CI/CD** | pipeline, deploy, workflow, GitHub Actions, build, infra |
| **Feature** | user story, product behaviour, acceptance criteria |
| **Epic** | large body of work, multiple child issues, team initiative, quarter-long scope |

If unclear, ask: "Is this an ML experiment, API quality-of-life improvement, CI/CD change, product feature, or an epic?"

---

## Step 3: Required Fields by Type

Ask *one topic at a time* — do not dump a list of questions. Wait for the answer,
then ask the next question. Keep going until all required fields are specific and
complete.

### ML Experiment

| Field | What you need |
|-------|--------------|
| `hypothesis` | Precise, falsifiable statement (e.g. "X will improve Y by Z%") |
| `metric_being_optimized` | Single primary metric with measurement method |
| `baseline` | Specific number + run/date reference |
| `success_criteria` | Exact threshold(s) that would make this a success |
| `failure_next_steps` | What happens if it fails — next hypothesis or decision |

### API Quality-of-Life

| Field | What you need |
|-------|--------------|
| `current_behavior` | Exact current behaviour (status codes, payloads, latency) |
| `desired_behavior` | Exact desired behaviour — interface definition if possible |
| `backwards_compatibility` | Is this a breaking change? Who needs a migration? |
| `affected_consumers` | Which services, clients, or teams call this API |

### CI/CD

| Field | What you need |
|-------|--------------|
| `current_state` | What the pipeline/workflow does today |
| `definition_of_done` | **Push hard on this.** See special rule below. |
| `rollback_plan` | How to revert if the change breaks things |

**CI/CD special rule — Definition of Done:**
Always ask: *"How will you verify this is working in production?"* before accepting
the definition of done. Do not accept answers like "the pipeline passes" — push for
observable, production-level evidence (e.g. specific metric, log line, dashboard,
alert silenced).

### Feature

| Field | What you need |
|-------|--------------|
| `user_story` | "As a [role] I want [capability] so that [outcome]" |
| `acceptance_criteria` | Bullet list of testable conditions — no vague language |
| `out_of_scope` | Explicit list of related things this ticket does NOT cover |

### Epic

| Field | What you need |
|-------|--------------|
| `problem_being_solved` | The chronic issue or gap this epic addresses — not "improve X" but *why now* |
| `end_condition` | Observable state that means this epic is DONE — push hard, see special rule below |
| `explicitly_out_of_scope` | What will NOT be addressed (prevents scope creep) |
| `child_issue_boundaries` | How work is divided — each child issue should have its own end condition |

**Epic special rule — End Condition:**
Never accept "ongoing improvement", "continuous work", or "as needed". Every epic must
have an observable, verifiable end state. Push with: *"How will you know when this epic
is complete? What would you need to see to close it?"*

If the ticket currently has child issues, fetch them to understand what work has already been done:

```bash
acli jira workitem search --jql 'parent = PROJ-123' --json
```

Group child issues by theme and use the existing done/cancelled work to inform the end condition
(what does "done" look like based on the work that has already closed?).

---

## Step 4: Draft and Present the Ticket

Once all required fields are complete, format and display the ticket:

```
**Summary:** [concise title]
**Type:** [ML Experiment | API QoL | CI/CD | Feature]
**Description:**

[type-specific structured content — all required fields clearly labelled]
```

Then ask: *"Does this look right? Say 'approved' to write it to Jira, or tell me what to change."*

Do not write anything to Jira yet.

---

## Step 5: Write to Jira (only after explicit approval)

The user must say "approved", "yes", "lgtm", or similar. If they say to edit something,
go back to Step 4 with the revised draft.

**Creating a new ticket:**

Always use `--from-json` — it supports ADF descriptions and custom fields (e.g. team)
via `additionalAttributes` in one step. Plain `--description` renders as unstyled text.

Write the full ticket to a temp file:

```bash
cat > /tmp/ticket.json << 'EOF'
{
  "projectKey": "AIH",
  "type": "Story",
  "summary": "...",
  "additionalAttributes": {
    "customfield_10001": {"id": "<team-id>"}
  },
  "description": {
    "type": "doc",
    "version": 1,
    "content": [
      {
        "type": "heading",
        "attrs": {"level": 2},
        "content": [{"type": "text", "text": "Section Title"}]
      },
      {
        "type": "paragraph",
        "content": [{"type": "text", "text": "Body text here."}]
      },
      {
        "type": "bulletList",
        "content": [
          {
            "type": "listItem",
            "content": [{"type": "paragraph", "content": [{"type": "text", "text": "Item"}]}]
          }
        ]
      },
      {
        "type": "codeBlock",
        "attrs": {},
        "content": [{"type": "text", "text": "directory/\n└── tree/"}]
      }
    ]
  }
}
EOF
acli jira workitem create --from-json /tmp/ticket.json
```

**Known AIH custom field values:**

| Field | Value | ID |
|-------|-------|----|
| Team — SotA Team | `customfield_10001` | `187df76b-cb5e-4d22-b854-7a7ac1082706` |

To find an unknown team ID, view a ticket that belongs to it:
```bash
acli jira workitem view AIH-XXXX --fields 'customfield_10001' --json
```

**Updating an existing ticket:**

Use `--description-file` with an ADF JSON file. Note: `acli workitem edit` does **not**
support `additionalAttributes` — team and other custom fields cannot be set via edit and
must be updated manually in the Jira UI if missed at creation.

```bash
acli jira workitem edit --key PROJ-123 --description-file /tmp/description.json --yes
```

Confirm the write succeeded and show the ticket URL or key.

---

## Step 6: Write Artifact

After the Jira write is confirmed, save the refined ticket locally so `/plan` can read it without re-fetching:

```bash
mkdir -p .agents/artifacts
```

Write `.agents/artifacts/<TICKET>-ticket.md`:

```yaml
---
artifact: ticket
ticket: <TICKET>
skill: refine
created: <ISO 8601 timestamp>
status: posted
---
```

Followed by the full refined ticket content (same as what was written to Jira).

---

## Quality Bar

A refined ticket should be:
- **Specific** — numbers, names, thresholds, not "improve performance" or "make it faster"
- **Falsifiable** — for ML experiments especially, it must be possible to clearly say pass/fail
- **Scoped** — what is explicitly out of scope is as important as what's in scope
- **Actionable** — someone unfamiliar with the project should be able to pick it up
