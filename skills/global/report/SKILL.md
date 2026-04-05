---
name: report
description: >
  Publish an ML experiment report to Confluence. Reads the experiment artifact produced
  by /experiment or /train, formats it as a structured proposal evaluation note, and posts
  to Confluence. Use this skill whenever the user says "write the confluence report",
  "publish results", "document the experiment", or wants to share experiment findings.
---

# Report Skill

Take an experiment artifact and publish a structured evaluation report to Confluence.

---

## Step 1: Check for Analyzer Gate

Before formatting or publishing, check whether the experiment-analyzer has already run. Look in the recent conversation context for a line beginning with `GATE:` from the analyzer output.

If the analyzer produced **GATE: BLOCKED**, stop and show:

```
BLOCKED: The experiment-analyzer flagged this recommendation as not supported by
metrics. Proceeding would publish unsupported conclusions.

To override: explicitly confirm "publish anyway" and state your reason.
```

Only continue to Step 2 if:
- The gate is **GATE: CLEARED**, OR
- The user explicitly types "publish anyway" with a stated reason, OR
- No analyzer has been run and the user confirms they want to skip it

---

## Step 2: Find the Experiment Artifact

```bash
TICKET=$(git branch --show-current | grep -oE '[A-Z]+-[0-9]+')
ls .agents/artifacts/${TICKET}-experiment-*.md 2>/dev/null | sort -r | head -5
```

If multiple artifacts exist, show the list and ask the user which run to report on.

If no ticket-based artifact, check for date-based ones:

```bash
ls .agents/artifacts/experiment-*.md 2>/dev/null | sort -r | head -5
```

Read the selected artifact fully.

---

## Step 3: Format the Report

Write the report directly from the artifact. Do not pipe through any external agent.

Use the following structure — this is the team-approved format for proposal evaluation notes:

---

### Title

```
[<Category>] <Experiment Description>
```

### Abstract

2–3 sentences covering: what was tested, the key outcome (with the most important number), and the recommendation.

### Introduction

Background: what problem this experiment addresses, the hypothesis being tested, how it relates to prior work or existing features, and how the evaluation was structured (controlled holdout, test set size, etc.).

### `<Feature / Method Name>` *(section title varies by experiment)*

#### Motivation

Why this approach was taken and what gap in the existing feature set or model it addresses.

#### `<Technical Component>` *(e.g. "Embedding Model", "Architecture")*

Technical details: model or algorithm used, key parameters, why it was chosen.

#### Feature Schema

Concrete naming schema or implementation structure. Include a code block if there is a feature naming convention:

```
<feature_name_pattern_1>
<feature_name_pattern_2>
...
```

Follow with a bullet list describing how many features are produced per model variant and any structural differences between variants.

---

### `<Model / Note Type A>` Results

**WandB Run:** [<run-id>](<wandb-url>) - `<run-name>`
**Model:** <type> | **Features:** <n> | **Train:** <n notes> (<date range>) | **Test:** <n notes> (<date range>) | **HP optimization:** <description>

#### Discriminative and Calibration Metrics

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

**Bold the winning value in every row.**

1–2 paragraphs: which metrics moved most, why (e.g. class imbalance makes AUC-PR more informative), what improved calibration means operationally.

#### Operational Throughput at Target Precision (≥ 0.94)

| Metric | Challenger | Production | Delta | |
|---|---|---|---|---|
| Decision threshold | ... | ... | — | |
| Touchless notes (n=2,500) | ... | ... | ... | Higher is better |
| Touchless rate | ... | ... | ... | Higher is better |

**Bold the winning value in every row.**

1 paragraph: how much throughput improved. Confirm the gain comes from better discrimination, not a relaxed threshold (cite the threshold values as evidence).

---

### `<Model / Note Type B>` Results *(repeat for each model variant)*

*(same structure as above)*

---

### Conclusion

Opening sentence summarising the overall finding across all variants.

| Note Type | AUC-ROC (Prod → Challenger) | Touchless Volume (Prod → Challenger) | Relative Lift |
|---|---|---|---|
| ... | ... | ... | ... |

1–2 paragraphs:
- Consistency of improvements across discriminative and calibration metrics
- Inference-time overhead (if any): compute cost, latency, whether new dependencies are already bundled

**Recommendation:** Promote / Iterate / Abandon — state which models and give the rationale in one sentence.

---

## Step 4: Confirm Before Publishing

Show the formatted report and ask: *"Does this look right? Say 'publish' to post to Confluence."*

Do not publish yet.

---

## Step 5: Publish to Confluence

After approval, publish via the Confluence REST API. Check for credentials:

```bash
echo "User: ${CONFLUENCE_USER:-not set}"
echo "Token: ${CONFLUENCE_API_TOKEN:+set}"
echo "Domain: ${CONFLUENCE_DOMAIN:-not set}"
```

If any are missing, ask the user for `CONFLUENCE_USER` (email), `CONFLUENCE_API_TOKEN`, `CONFLUENCE_DOMAIN` (e.g. `ai-h.atlassian.net`), space key, and parent page ID.

Write the report body as Confluence storage format (XHTML) and publish:

```bash
curl -s -u "${CONFLUENCE_USER}:${CONFLUENCE_API_TOKEN}" \
  -X POST \
  -H "Content-Type: application/json" \
  "https://${CONFLUENCE_DOMAIN}/wiki/rest/api/content" \
  -d '{
    "type": "page",
    "title": "<title>",
    "space": {"key": "<SPACE_KEY>"},
    "ancestors": [{"id": "<PARENT_PAGE_ID>"}],
    "body": {
      "storage": {
        "value": "<escaped html content>",
        "representation": "storage"
      }
    }
  }'
```

Extract the `_links.webui` field from the response to get the page URL.

If credentials are unavailable, output the report as markdown for manual paste.

---

## Step 6: Update Artifact

After successful publish, read the artifact and write it back with updated frontmatter:

```yaml
---
...
status: posted
confluence_url: <URL of the published page>
---
```

Show the Confluence URL to the user.

---

## Quality Bar

- Factual accuracy over prose quality — never fabricate or round metrics
- The abstract must stand alone: someone who skips the rest must know the outcome and recommendation
- Bold the winning value in every table row
- Include `---` HR dividers between model result sections
- The `**Recommendation:**` line must be bold and must be the final line of the Conclusion
- Always show the report to the user before publishing
