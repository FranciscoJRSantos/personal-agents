---
name: insight
description: >
  Query the opencode.db SQLite database to generate a usage analytics report —
  cost/token usage, tool frequency, model distribution, session patterns, agent/skill
  habits, todo completion rates, and week-over-week trends. Outputs an HTML dashboard
  file and a markdown summary. Use this skill whenever the user says "insight",
  "how am I using opencode", "usage stats", "analytics", "show my usage", or wants
  to understand their OpenCode usage patterns.
  Entry point: /insight [time-window] [--global|--project]
---

# Insight Skill

Query `~/.local/share/opencode/opencode.db` to produce an HTML usage analytics
dashboard with cost breakdowns, tool/model/agent frequency, session patterns, and
period-over-period comparisons.

---

## Gotchas

- Always filter by `time_created` (epoch ms) BECAUSE opencode stores timestamps as
  epoch milliseconds in the `time_created` column.
- Always compute the "previous period" window of equal length BECAUSE trend
  comparisons need a baseline — without it, "change" columns are meaningless.
- Never include the HTML output in the conversation BECAUSE it can be thousands of
  lines; only show the markdown summary and file path.
- Always write the HTML with a bash heredoc (not the Write tool) BECAUSE using Write
  for large HTML is error-prone and doesn't support variable interpolation; bash
  heredocs allow embedding sqlite3 output directly.
- Always use `/tmp/opencode/` as the output directory BECAUSE it's pre-approved for
  external file access.

---

## SQL Escape Helper

Define this once before running any queries:

```bash
# Escapes single quotes for SQLite string literals
sq_escape() { printf '%s' "$1" | sed "s/'/''/g"; }
```

---

## Step 1: Parse Arguments

Extract from `$ARGUMENTS`:

| Argument | Default | Examples |
| -------- | ------- | -------- |
| Time window | `7d` | `7d`, `30d`, `90d`, `all` |
| Scope | `--global` (all projects) | `--global`, `--project` |

Convert time window to epoch timestamps:

```bash
NOW_MS=$(date +%s)000
case "$WINDOW" in
  7d)  INTERVAL_MS=$((7 * 86400 * 1000)) ;;
  30d) INTERVAL_MS=$((30 * 86400 * 1000)) ;;
  90d) INTERVAL_MS=$((90 * 86400 * 1000)) ;;
  all) INTERVAL_MS=0 ;;
  *)   echo "Unknown window: $WINDOW. Use 7d, 30d, 90d, or all."; exit 1 ;;
esac
START_MS=$((NOW_MS - INTERVAL_MS))
PREV_START_MS=$((START_MS - INTERVAL_MS))
```

For `--project` scope, detect the current project:

```bash
PROJECT_FILTER=""
if [ "$SCOPE" = "--project" ]; then
  CURRENT_DIR=$(pwd)
  ESCAPED_DIR=$(sq_escape "$CURRENT_DIR")
  PROJECT_ID=$(sqlite3 ~/.local/share/opencode/opencode.db \
    "SELECT id FROM project WHERE worktree = '$ESCAPED_DIR' OR worktree LIKE '$ESCAPED_DIR/%' LIMIT 1")
  if [ -n "$PROJECT_ID" ]; then
    PROJECT_FILTER="AND project_id = '$PROJECT_ID'"
    echo "Scope: project ($PROJECT_ID)"
  else
    echo "No project found for $CURRENT_DIR, falling back to --global"
    PROJECT_FILTER=""
  fi
fi
```

---

## Step 2: Run Query Batch 1 — Session & Cost Metrics

Run each query in its own `sqlite3 -json` invocation so every
result set is valid JSON:

```bash
# S1: Current period aggregate
S1_JSON=$(sqlite3 -json ~/.local/share/opencode/opencode.db <<SQL
SELECT
  COUNT(*) AS sessions,
  ROUND(SUM(cost), 4) AS total_cost,
  ROUND(AVG(cost), 6) AS avg_cost,
  COALESCE(SUM(tokens_input), 0) AS total_input,
  COALESCE(SUM(tokens_output), 0) AS total_output,
  COALESCE(SUM(tokens_reasoning), 0) AS total_reasoning,
  COALESCE(SUM(tokens_cache_read), 0) AS total_cache_read,
  COALESCE(SUM(tokens_cache_write), 0) AS total_cache_write,
  ROUND(AVG(COALESCE(tokens_input, 0) + COALESCE(tokens_output, 0)), 0) AS avg_tokens
FROM session
WHERE time_created >= $START_MS AND time_created < $NOW_MS
  $PROJECT_FILTER
SQL
)

# S2: Previous period aggregate (for trends)
S2_JSON=$(sqlite3 -json ~/.local/share/opencode/opencode.db <<SQL
SELECT
  COUNT(*) AS sessions,
  ROUND(SUM(cost), 4) AS total_cost,
  COALESCE(SUM(tokens_input), 0) AS total_input,
  COALESCE(SUM(tokens_output), 0) AS total_output
FROM session
WHERE $PREV_START_MS > 0
  AND time_created >= $PREV_START_MS AND time_created < $START_MS
  $PROJECT_FILTER
SQL
)

# S3: Daily session activity (last 60 days max)
S3_JSON=$(sqlite3 -json ~/.local/share/opencode/opencode.db <<SQL
SELECT
  DATE(time_created / 1000, 'unixepoch', 'localtime') AS day,
  COUNT(*) AS sessions,
  ROUND(SUM(COALESCE(cost, 0)), 4) AS cost
FROM session
WHERE time_created >= $START_MS AND time_created < $NOW_MS
  $PROJECT_FILTER
GROUP BY day
ORDER BY day DESC
SQL
)

# S4: Top 10 most expensive sessions
S4_JSON=$(sqlite3 -json ~/.local/share/opencode/opencode.db <<SQL
SELECT
  SUBSTR(COALESCE(title, 'untitled'), 1, 80) AS title,
  ROUND(COALESCE(cost, 0), 4) AS cost,
  COALESCE(tokens_input, 0) AS tokens_in,
  COALESCE(tokens_output, 0) AS tokens_out,
  DATETIME(time_created / 1000, 'unixepoch', 'localtime') AS started
FROM session
WHERE time_created >= $START_MS AND time_created < $NOW_MS
  $PROJECT_FILTER
ORDER BY cost DESC
LIMIT 10
SQL
)
```

---

## Step 3: Run Query Batch 2 — Tools, Models, Agents & Todos

Each query runs in its own `sqlite3 -json` invocation:

```bash
# T1: Tool frequency (top 20)
T1_JSON=$(sqlite3 -json ~/.local/share/opencode/opencode.db <<SQL
SELECT
  CAST(JSON_EXTRACT(p.data, '$.tool') AS TEXT) AS tool,
  COUNT(*) AS calls
FROM part p
JOIN message m ON p.message_id = m.id
WHERE JSON_EXTRACT(p.data, '$.type') = 'tool'
  AND m.time_created >= $START_MS
  AND m.time_created < $NOW_MS
  $PROJECT_FILTER
GROUP BY tool
ORDER BY calls DESC
LIMIT 20
SQL
)

# T2: Model usage
T2_JSON=$(sqlite3 -json ~/.local/share/opencode/opencode.db <<SQL
SELECT
  JSON_EXTRACT(model, '$.id') AS model_id,
  JSON_EXTRACT(model, '$.providerID') AS provider,
  COUNT(*) AS sessions,
  ROUND(SUM(COALESCE(cost, 0)), 4) AS cost
FROM session
WHERE time_created >= $START_MS AND time_created < $NOW_MS
  $PROJECT_FILTER
GROUP BY model_id, provider
ORDER BY sessions DESC
LIMIT 15
SQL
)

# T3: Agent/skill frequency (top 15)
T3_JSON=$(sqlite3 -json ~/.local/share/opencode/opencode.db <<SQL
SELECT
  CAST(JSON_EXTRACT(m.data, '$.agent') AS TEXT) AS agent,
  COUNT(*) AS messages
FROM message m
JOIN session s ON m.session_id = s.id
WHERE m.time_created >= $START_MS
  AND m.time_created < $NOW_MS
  $PROJECT_FILTER
GROUP BY agent
ORDER BY messages DESC
LIMIT 15
SQL
)

# T4: Todo completion rates
T4_JSON=$(sqlite3 -json ~/.local/share/opencode/opencode.db <<SQL
SELECT
  t.status,
  COUNT(*) AS cnt
FROM todo t
JOIN session s ON t.session_id = s.id
WHERE s.time_created >= $START_MS
  AND s.time_created < $NOW_MS
  $PROJECT_FILTER
GROUP BY t.status
SQL
)

# T5: Session-level agent switches
T5_SWITCHES=$(sqlite3 -json ~/.local/share/opencode/opencode.db <<SQL
SELECT COUNT(*) AS switches
FROM session_message sm
JOIN session s ON sm.session_id = s.id
WHERE sm.type = 'agent-switched'
  AND s.time_created >= $START_MS
  AND s.time_created < $NOW_MS
  $PROJECT_FILTER
SQL
)

# T6: Total tool calls count (for summary)
T6_TOOLS=$(sqlite3 -json ~/.local/share/opencode/opencode.db <<SQL
SELECT COUNT(*) AS total_tool_calls
FROM part p
JOIN message m ON p.message_id = m.id
WHERE JSON_EXTRACT(p.data, '$.type') = 'tool'
  AND m.time_created >= $START_MS
  AND m.time_created < $NOW_MS
  $PROJECT_FILTER
SQL
)
```

---

## Step 4: Generate HTML Report

Build the HTML with a bash heredoc, embedding query results inline. The HTML must
be self-contained with inline CSS only — no external dependencies. Use the
following structure and colour palette:

**Palette:**
- Background: `#0f172a` (slate-900)
- Cards: `#1e293b` (slate-800)
- Text primary: `#f1f5f9` (slate-100)
- Text muted: `#94a3b8` (slate-400)
- Accent: `#3b82f6` (blue-500)
- Accent green: `#10b981` (emerald-500)
- Accent amber: `#f59e0b` (amber-500)
- Accent red: `#ef4444` (red-500)

**Sections (in order):**

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>OpenCode Insight</title>
<style>
  /* Reset + layout */
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
         background: #0f172a; color: #f1f5f9; padding: 2rem; }
  .container { max-width: 1100px; margin: 0 auto; }

  /* Header */
  .header { margin-bottom: 2rem; }
  .header h1 { font-size: 2rem; font-weight: 700; color: #f1f5f9; }
  .header .subtitle { color: #94a3b8; font-size: 0.9rem; margin-top: 0.25rem; }

  /* Cards grid */
  .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
           gap: 1rem; margin-bottom: 2rem; }
  .card { background: #1e293b; border-radius: 0.75rem; padding: 1.25rem; }
  .card .label { color: #94a3b8; font-size: 0.8rem; text-transform: uppercase;
                 letter-spacing: 0.05em; }
  .card .value { font-size: 1.75rem; font-weight: 700; margin-top: 0.25rem; }
  .card .change { font-size: 0.8rem; margin-top: 0.25rem; }
  .card .change.up { color: #10b981; }
  .card .change.down { color: #ef4444; }

  /* Sections */
  .section { background: #1e293b; border-radius: 0.75rem; padding: 1.5rem;
             margin-bottom: 1.5rem; }
  .section h2 { font-size: 1.25rem; font-weight: 600; margin-bottom: 1rem;
                 color: #f1f5f9; }

  /* Tables */
  table { width: 100%; border-collapse: collapse; }
  th, td { text-align: left; padding: 0.6rem 0.75rem; border-bottom: 1px solid #334155;
           font-size: 0.875rem; }
  th { color: #94a3b8; font-weight: 500; font-size: 0.75rem; text-transform: uppercase;
       letter-spacing: 0.05em; border-bottom: 2px solid #334155; }
  td { color: #e2e8f0; }
  .num { text-align: right; font-variant-numeric: tabular-nums; }

  /* Bar chart */
  .bar-chart { margin-top: 0.5rem; }
  .bar-row { display: flex; align-items: center; margin-bottom: 0.5rem; gap: 0.75rem; }
  .bar-label { width: 120px; font-size: 0.8rem; color: #94a3b8; text-align: right;
                flex-shrink: 0; overflow: hidden; text-overflow: ellipsis;
                white-space: nowrap; }
  .bar-track { flex: 1; height: 1.5rem; background: #334155; border-radius: 0.25rem;
                overflow: hidden; }
  .bar-fill { height: 100%; border-radius: 0.25rem; display: flex; align-items: center;
               padding-left: 0.5rem; font-size: 0.75rem; color: #fff;
               transition: width 0.3s; min-width: fit-content; }
  .bar-count { margin-left: auto; padding-right: 0.5rem; font-size: 0.75rem;
               color: #94a3b8; flex-shrink: 0; width: 48px; text-align: right; }

  /* Activity calendar */
  .activity-grid { display: flex; flex-wrap: wrap; gap: 0.25rem; }
  .activity-day { width: 2rem; height: 2rem; border-radius: 0.25rem;
                  display: flex; align-items: center; justify-content: center;
                  font-size: 0.65rem; color: #94a3b8; position: relative; }
  .activity-day.has-sessions { cursor: pointer; }
  .activity-day .tooltip { display: none; position: absolute; bottom: 110%;
                           left: 50%; transform: translateX(-50%);
                           background: #000; color: #fff; padding: 0.25rem 0.5rem;
                           border-radius: 0.25rem; font-size: 0.7rem;
                           white-space: nowrap; z-index: 10; }
  .activity-day:hover .tooltip { display: block; }

  /* Tags */
  .tag { display: inline-block; padding: 0.15rem 0.5rem; border-radius: 0.25rem;
         font-size: 0.75rem; font-weight: 500; }
  .tag-blue { background: #1e3a5f; color: #60a5fa; }
  .tag-green { background: #064e3b; color: #34d399; }
  .tag-amber { background: #451a03; color: #fbbf24; }
  .tag-red { background: #450a0a; color: #f87171; }

  /* Footer */
  .footer { text-align: center; color: #475569; font-size: 0.75rem;
            margin-top: 2rem; padding-top: 1rem; border-top: 1px solid #1e293b; }

  /* Responsive */
  @media (max-width: 640px) {
    body { padding: 1rem; }
    .cards { grid-template-columns: 1fr 1fr; }
  }
</style>
</head>
<body>
<div class="container">

  <!-- Header -->
  <div class="header">
    <h1>OpenCode Insight</h1>
    <div class="subtitle">
      {{TIME_RANGE}} | {{SCOPE_LABEL}} | {{TOTAL_SESSIONS}} sessions |
      Generated {{GENERATED_AT}}
    </div>
  </div>

  <!-- Summary Cards -->
  <div class="cards">
    <div class="card">
      <div class="label">Sessions</div>
      <div class="value">{{CURRENT_SESSIONS}}</div>
      <div class="change {{SESSIONS_CHANGE_CLASS}}">{{SESSIONS_CHANGE}} vs prev</div>
    </div>
    <div class="card">
      <div class="label">Total Cost</div>
      <div class="value">${{CURRENT_COST}}</div>
      <div class="change {{COST_CHANGE_CLASS}}">{{COST_CHANGE}} vs prev</div>
    </div>
    <div class="card">
      <div class="label">Input Tokens</div>
      <div class="value">{{CURRENT_INPUT_K}}K</div>
    </div>
    <div class="card">
      <div class="label">Output Tokens</div>
      <div class="value">{{CURRENT_OUTPUT_K}}K</div>
    </div>
    <div class="card">
      <div class="label">Reasoning Tokens</div>
      <div class="value">{{CURRENT_REASONING_K}}K</div>
    </div>
    <div class="card">
      <div class="label">Avg Cost / Session</div>
      <div class="value">${{AVG_COST}}</div>
    </div>
  </div>

  <!-- Trends Table -->
  <div class="section">
    <h2>Trends — Current vs Previous Period</h2>
    <table>
      <thead>
        <tr><th>Metric</th><th class="num">Current</th><th class="num">Previous</th>
            <th class="num">Change</th></tr>
      </thead>
      <tbody>
        <tr><td>Sessions</td>
            <td class="num">{{CURRENT_SESSIONS}}</td>
            <td class="num">{{PREV_SESSIONS}}</td>
            <td class="num"><span class="tag {{SESSIONS_TAG}}">{{SESSIONS_PCT}}</span></td></tr>
        <tr><td>Cost</td>
            <td class="num">${{CURRENT_COST}}</td>
            <td class="num">${{PREV_COST}}</td>
            <td class="num"><span class="tag {{COST_TAG}}">{{COST_PCT}}</span></td></tr>
        <tr><td>Input Tokens</td>
            <td class="num">{{CURRENT_INPUT_K}}K</td>
            <td class="num">{{PREV_INPUT_K}}K</td>
            <td class="num"><span class="tag {{INPUT_TAG}}">{{INPUT_PCT}}</span></td></tr>
        <tr><td>Output Tokens</td>
            <td class="num">{{CURRENT_OUTPUT_K}}K</td>
            <td class="num">{{PREV_OUTPUT_K}}K</td>
            <td class="num"><span class="tag {{OUTPUT_TAG}}">{{OUTPUT_PCT}}</span></td></tr>
      </tbody>
    </table>
  </div>

  <!-- Tool Usage -->
  <div class="section">
    <h2>Tool Usage — Top {{N_TOOLS}}</h2>
    <div class="bar-chart">
      {{TOOL_BARS}}
    </div>
  </div>

  <!-- Model Distribution -->
  <div class="section">
    <h2>Model Distribution — Top {{N_MODELS}}</h2>
    <div class="bar-chart">
      {{MODEL_BARS}}
    </div>
  </div>

  <!-- Agent Frequency -->
  <div class="section">
    <h2>Agent / Skill Usage — Top {{N_AGENTS}}</h2>
    <div class="bar-chart">
      {{AGENT_BARS}}
    </div>
  </div>

  <!-- Daily Activity -->
  <div class="section">
    <h2>Daily Activity</h2>
    <div class="activity-grid">
      {{ACTIVITY_GRID}}
    </div>
  </div>

  <!-- Most Expensive Sessions -->
  <div class="section">
    <h2>Most Expensive Sessions</h2>
    <table>
      <thead>
        <tr><th>Title</th><th class="num">Cost</th><th class="num">In</th>
            <th class="num">Out</th><th>Date</th></tr>
      </thead>
      <tbody>
        {{TOP_SESSION_ROWS}}
      </tbody>
    </table>
  </div>

  <!-- Todo Stats -->
  <div class="section">
    <h2>Todo Completion</h2>
    {{TODO_STATS}}
  </div>

  <!-- Footer -->
  <div class="footer">
    Generated from ~/.local/share/opencode/opencode.db · {{GENERATED_AT}}
  </div>

</div>
</body>
</html>
```

Write the file with a bash heredoc:

```bash
cat > /tmp/opencode/insight-$(date +%Y-%m-%d).html << 'HTML'
... (full HTML with values substituted) ...
HTML
```

> Do NOT use `cat` with quoted heredoc markers — instead, use `cat` with **unquoted**
> markers so that shell variables (`$VAR`) are expanded inline. Build all computed
> values as shell variables before the heredoc, then reference them directly.

---

## Step 5: Compute Derived Values

Before writing the HTML, compute all the display values as shell variables:

```bash
# Parse JSON results using python3 (each variable holds valid JSON)
# S1: Current period aggregate
S1=$(echo "$S1_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin)[0]; print(d['sessions'])" 2>/dev/null || echo 0)
S1_COST=$(echo "$S1_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin)[0]; print(d['total_cost'])" 2>/dev/null || echo 0)
S1_AVG=$(echo "$S1_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin)[0]; print(d['avg_cost'])" 2>/dev/null || echo 0)
S1_INPUT=$(echo "$S1_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin)[0]; print(d['total_input'])" 2>/dev/null || echo 0)
S1_OUTPUT=$(echo "$S1_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin)[0]; print(d['total_output'])" 2>/dev/null || echo 0)
S1_REASONING=$(echo "$S1_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin)[0]; print(d['total_reasoning'])" 2>/dev/null || echo 0)

# S2: Previous period aggregate
S2=$(echo "$S2_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin)[0]; print(d['sessions'])" 2>/dev/null || echo 0)
S2_COST=$(echo "$S2_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin)[0]; print(d['total_cost'])" 2>/dev/null || echo 0)

# Assign display variables
CURRENT_SESSIONS=$S1
CURRENT_COST=$S1_COST
AVG_COST=$S1_AVG
CURRENT_INPUT_K=$((S1_INPUT / 1000))
CURRENT_OUTPUT_K=$((S1_OUTPUT / 1000))
CURRENT_REASONING_K=$((S1_REASONING / 1000))
PREV_SESSIONS=${S2:-0}
PREV_COST=${S2_COST:-0}
```

If `python3` is available (check: `command -v python3`), use it for JSON parsing.
If not, fall back to `sqlite3 -json` with individual queries or parse with `grep`/`sed`.
Each of `S1_JSON`, `S2_JSON`, `S3_JSON`, `S4_JSON`, `T1_JSON`…`T6_JSON` holds a valid JSON
array from a single query — parse each independently.

When computing percentages:

```bash
calc_pct() {
  local current=$1 prev=$2
  if [ "$prev" = "0" ] || [ -z "$prev" ] || [ -z "$current" ]; then
    echo "—"
    return
  fi
  awk "BEGIN { printf \"%+.1f%%\", (($current - $prev) / $prev) * 100 }"
}

pct_change() {
  local cur=$1 prev=$2
  if [ "$prev" = "0" ] || [ -z "$prev" ] || [ -z "$cur" ]; then
    return
  fi
  awk "BEGIN { printf \"%.0f\", (($cur - $prev) / $prev) * 100 }"
}
```

Trend colours:
- Cost increase > 20% → red (`tag-red`)
- Sessions/tokens increase > 20% → green (`tag-green`)
- Changes within ±20% → blue (`tag-blue`)
- Decrease → opposite colour

---

## Step 6: Open and Print Summary

Open in browser:

```bash
xdg-open /tmp/opencode/insight-$(date +%Y-%m-%d).html
```

Print a concise markdown summary to the conversation:

```markdown
## OpenCode Insight — <start> to <end> (<scope>)

| Metric | Current | Previous | Change |
| ------ | ------- | -------- | ------ |
| Sessions | N | N | +X% |
| Cost | $X.XX | $X.XX | +X% |
| Input tokens | Nk | Nk | +X% |
| Output tokens | Nk | Nk | +X% |

**Top tools:** read (N), grep (N), bash (N), edit (N), glob (N)
**Top agents:** build (N), explore (N), general (N)
**Tool calls:** N total · Agent switches: N

Full report: `/tmp/opencode/insight-<date>.html`
```

---

## Quality Bar

A good insight report should:
- Execute in < 10 seconds (all queries batched into 2–3 sqlite3 calls)
- Produce valid, self-contained HTML that renders in any browser without internet
- Show meaningful trends (not just raw numbers — always include % change)
- Respect the scope filter in all queries
- Open automatically in the user's browser
- Use the dark slate colour palette consistently throughout
