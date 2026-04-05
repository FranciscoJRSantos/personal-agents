---
name: experiment
description: >
  Capture ML experiment results into a structured artifact that /report can consume.
  Use this skill whenever the user says "log experiment", "record results",
  "capture experiment", "experiment done", "training finished", or wants to document
  the outcome of an ML experiment run before writing the Confluence report.
---

# Experiment Skill

Capture the results of an ML experiment into a structured artifact that the `/report`
skill can consume directly.

---

## Step 1: Load the Plan

```bash
TICKET=$(git branch --show-current | grep -oE '[A-Z]+-[0-9]+')
cat .claude/artifacts/${TICKET}-plan.md 2>/dev/null
```

If a plan artifact exists, extract:
- **Hypothesis** (exact wording)
- **Evaluation criteria** (metric table with baselines and success thresholds)
- **Experiment design** (what changes, what's controlled)

If no plan artifact, ask the user for the hypothesis and key metrics to evaluate.

---

## Step 2: Collect Experiment Metadata

Ask the user for the following (one question at a time if not provided upfront):

1. **WandB run URL or ID** for each model variant (or other experiment tracker link)
2. **Model variant names** — e.g. note types, model configurations being compared
3. **Training/test set details** — size, date range, holdout strategy
4. **HP optimization** — what was tuned and how (grid search, Bayesian, manual)

---

## Step 3: Collect Metrics

For each model variant, collect the metrics that `/report` expects. Present a template
table and ask the user to fill it in or paste results:

### Discriminative and Calibration Metrics

| Metric | Challenger | Production | Delta |
|---|---|---|---|
| Accuracy | | | |
| AUC-ROC | | | |
| AUC-PR | | | |
| F1 Score | | | |
| Precision (at operating threshold) | | | |
| Recall | | | |
| Log Loss | | | |
| Brier Score | | | |
| Expected Calibration Error (ECE) | | | |

### Operational Throughput at Target Precision (>= 0.94)

| Metric | Challenger | Production | Delta |
|---|---|---|---|
| Decision threshold | | | |
| Touchless notes (n=sample_size) | | | |
| Touchless rate | | | |

If the user provides metrics in a different format (e.g. WandB export, CSV, JSON),
parse and map them into the tables above. Ask for clarification on any metric that
cannot be unambiguously mapped.

Also ask:
- Any **deviations from the plan** (unexpected behavior, failed runs, parameter changes)
- Any **notes on inference overhead** (latency, compute cost, new dependencies)

---

## Step 4: Determine Preliminary Recommendation

Based on the collected metrics and the plan's success criteria, propose one of:

- **Promote** — metrics meet or exceed success thresholds across all variants
- **Iterate** — partial improvement; specify what to change next
- **Abandon** — no meaningful improvement or regression; specify why

Show the reasoning: which metrics drove the decision, how they compare to the
plan's success thresholds.

---

## Step 5: Generate and Confirm Artifact

Assemble the full experiment artifact and show it to the user. The structure must
match what `/report` expects:

```markdown
---
artifact: experiment
ticket: <TICKET>
skill: experiment
created: <ISO 8601 timestamp>
status: draft
run_ids:
  - <wandb-run-id-1>
  - <wandb-run-id-2>
---

## Hypothesis

<Exact hypothesis from plan, or as stated by user>

## Experiment Configuration

**Model:** <type> | **Features:** <n> | **Train:** <n notes> (<date range>) | **Test:** <n notes> (<date range>) | **HP optimization:** <description>

<Any deviations from the plan noted here>

## <Model Variant A> Results

**WandB Run:** [<run-id>](<wandb-url>) - `<run-name>`

### Discriminative and Calibration Metrics

| Metric | Challenger | Production | Delta | |
|---|---|---|---|---|
| Accuracy | ... | ... | ... | Higher is better |
| AUC-ROC | ... | ... | ... | Higher is better |
| AUC-PR | ... | ... | ... | Higher is better |
| F1 Score | ... | ... | ... | Higher is better |
| Precision (at operating threshold) | ... | ... | ... | Higher is better |
| Recall | ... | ... | ... | Higher is better |
| Log Loss | ... | ... | ... | Lower is better |
| Brier Score | ... | ... | ... | Lower is better |
| Expected Calibration Error (ECE) | ... | ... | ... | Lower is better |

### Operational Throughput at Target Precision (>= 0.94)

| Metric | Challenger | Production | Delta | |
|---|---|---|---|---|
| Decision threshold | ... | ... | - | |
| Touchless notes (n=<sample_size>) | ... | ... | ... | Higher is better |
| Touchless rate | ... | ... | ... | Higher is better |

<1-2 paragraphs: metric movement analysis>

---

## <Model Variant B> Results

<repeat structure>

---

## Preliminary Recommendation

**Recommendation:** <Promote / Iterate / Abandon> — <rationale in one sentence>

### Success Criteria Comparison

| Criterion (from plan) | Threshold | Actual | Met? |
|---|---|---|---|
| ... | ... | ... | Yes/No |
```

Ask: *"Does this look right? Say 'save' to write the artifact."*

---

## Step 6: Write Artifact

After approval:

```bash
TICKET=$(git branch --show-current | grep -oE '[A-Z]+-[0-9]+')
RUN_ID="<primary-run-id>"
mkdir -p .claude/artifacts
```

Write to `.claude/artifacts/<TICKET>-experiment-<RUN_ID>.md`.

Then suggest:

```
**Next step:** Run `/report` to publish these results to Confluence.
```

---

## Quality Bar

- **Factual accuracy** — never fabricate, round, or interpolate metric values
- **Bold the winning value** in every table row (same convention as `/report`)
- **One question at a time** — don't overwhelm with a wall of required fields
- If the user pastes raw data (CSV, JSON, WandB export), parse it rather than asking them to reformat
- The artifact schema must be consumable by `/report` without manual editing
- Always include the success criteria comparison table from the plan
