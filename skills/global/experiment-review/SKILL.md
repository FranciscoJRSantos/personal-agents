---
name: experiment-review
description: >
  Fetch W&B experiment runs via the Python SDK, display filtered metrics, and optionally
  append a dated section to EXPERIMENTS.md. Use this skill whenever the user says
  "review experiment", "pull W&B runs", "show run metrics", "log to EXPERIMENTS.md",
  or wants to inspect W&B results without going through the full /experiment → /report
  pipeline. Accepts an optional W&B run ID argument (e.g. /experiment-review b3sgztcq)
  to review a single run; with no argument, fetches all runs for the configured project.
---

# Experiment Review Skill

Fetch W&B run data using the Python SDK, display filtered metrics, and — after user
confirmation — append a dated section to `EXPERIMENTS.md`.

---

## Step 1: Detect Mode

Check `$ARGUMENTS`:

- If a run ID is present (e.g. `b3sgztcq`), enter **single-run mode**.
- If empty, enter **bulk mode**.

---

## Step 2: Load Credentials

```bash
set -a; source .env; set +a
echo "WANDB_API_KEY: ${WANDB_API_KEY:+set}"
echo "WANDB_ENTITY:  ${WANDB_ENTITY:-NOT SET}"
echo "WANDB_PROJECT: ${WANDB_PROJECT:-NOT SET}"
```

If `WANDB_API_KEY`, `WANDB_ENTITY`, or `WANDB_PROJECT` is missing, tell the user
which variable is absent and stop. Do not proceed without all three.

---

## Step 3a: Single-Run Mode — Fetch and Display

Replace `<RUN_ID>` with the value from `$ARGUMENTS`:

```bash
uv run python -c "
import wandb, json, os
api = wandb.Api()
run = api.run('{entity}/{project}/{run_id}'.format(
    entity=os.environ['WANDB_ENTITY'],
    project=os.environ['WANDB_PROJECT'],
    run_id='<RUN_ID>',
))
EXCLUDE_CONFIG = {'learner', 'categorical_mapping', 'categorical_columns'}
summary = {k: v for k, v in run.summary.items() if isinstance(v, (int, float, str, bool))}
config  = {k: v for k, v in run.config.items()  if k not in EXCLUDE_CONFIG}
print(json.dumps({
    'id': run.id,
    'name': run.name,
    'state': run.state,
    'created_at': run.created_at,
    'summary': summary,
    'config': config,
}, indent=2))
"
```

Present the metrics inline in a readable format. Include:
- Run name and state
- All summary metrics (primitives only — already filtered)
- Key config values (large nested keys excluded)

Then ask: *"Would you like to append this run to EXPERIMENTS.md?"*
Do not write anything until the user confirms.

---

## Step 3b: Bulk Mode — Fetch All Runs and Build Table

```bash
uv run python -c "
import wandb, json, os
api = wandb.Api()
runs = api.runs(
    '{entity}/{project}'.format(
        entity=os.environ['WANDB_ENTITY'],
        project=os.environ['WANDB_PROJECT'],
    ),
    order='+created_at',
)
EXCLUDE_CONFIG = {'learner', 'categorical_mapping', 'categorical_columns'}
out = []
for r in runs:
    summary = {k: v for k, v in r.summary.items() if isinstance(v, (int, float, str, bool))}
    config  = {k: v for k, v in r.config.items()  if k not in EXCLUDE_CONFIG}
    out.append({
        'id': r.id,
        'name': r.name,
        'state': r.state,
        'created_at': r.created_at,
        'summary': summary,
        'config': config,
    })
print(json.dumps(out, indent=2))
"
```

From the output, identify the set of summary keys that appear across most runs and
build a markdown comparison table:

| Run ID | Name | State | `<metric_1>` | `<metric_2>` | … |
|--------|------|-------|--------------|--------------|---|
| …      | …    | …     | …            | …            | … |

Bold the best value in each metric column (highest for accuracy/AUC/F1/recall/precision/throughput,
lowest for log loss/Brier/ECE).

Then ask: *"Would you like to append this sweep summary to EXPERIMENTS.md?"*
Do not write anything until the user confirms.

---

## Step 4: Append to EXPERIMENTS.md (Only After Confirmation)

Determine the section header based on mode:

- **Single-run:** `## Holdout Training Run: <run_id> (<YYYY-MM-DD>)`
- **Bulk:** `## Sweep: <WANDB_ENTITY>/<WANDB_PROJECT> (<YYYY-MM-DD>)`

Then:

```bash
if [ -f EXPERIMENTS.md ]; then
  echo "EXPERIMENTS.md exists — will append"
else
  echo "EXPERIMENTS.md does not exist — will create"
fi
```

- **If `EXPERIMENTS.md` does not exist:** create it with a top-level header followed by
  the new section:

  ```markdown
  # Experiments

  ## Holdout Training Run: <run_id> (<date>)

  <metrics / table>
  ```

- **If `EXPERIMENTS.md` already exists:** read the full file first, then append the new
  dated section at the end. Never overwrite or truncate existing content.

After writing, confirm: *"Appended to EXPERIMENTS.md."*

---

## Quality Bar

- **Never fabricate metrics** — only report values returned by the SDK
- **Filter before printing** — summary must contain only `int`, `float`, `str`, or `bool` values; config must exclude `learner`, `categorical_mapping`, `categorical_columns`
- **Ask before writing** — always confirm with the user before touching `EXPERIMENTS.md`
- **Append-only** — existing `EXPERIMENTS.md` content must be preserved; read it before writing
- **Bold the winner** in every metric column of the bulk table
- If the SDK call fails (bad run ID, missing project, auth error), surface the error message verbatim and stop
