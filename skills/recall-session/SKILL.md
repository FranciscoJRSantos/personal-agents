---
name: recall-session
description: >
  Search past OpenCode sessions for relevant conversation content. Queries the
  opencode.db SQLite database for matches in session titles and message content.
  Use this skill to recall past decisions, debugging paths, or architecture
  discussions that weren't explicitly saved to the memory store.
  Entry point: /recall-session <query> [--limit N] [--scope project|global]
  [--from DATE] [--to DATE] [--content <session-id>]
---

# Recall-Session Skill

Searches past OpenCode conversation sessions using SQLite. Defaults to the current
project only. Supports two-phase search (title match first, then content match)
and deep content retrieval for specific sessions.

---

## Gotchas

- Database location: `~/.local/share/opencode/opencode.db`. If it doesn't exist,
  the user hasn't used OpenCode yet.
- All timestamps are epoch milliseconds (multiply Unix seconds by 1000).
- Content lives in `part.data` JSON — extract with `JSON_EXTRACT()`.
- Content queries use `LIKE '%query%'` which is slow on large datasets but simple
  (no FTS5 virtual table available). For large DBs, use `--title-only` for speed.
- Default scope is `project` — only sessions in the current repo.
- Results are limited to 10 by default. Adjust with `--limit N`.
- This searches raw conversation history. For structured saved facts, use `/recall`.

---

## SQL Escape Helper

Define this before running any queries:

```bash
# Escapes single quotes for SQLite string literals
sq_escape() { printf '%s' "$1" | sed "s/'/''/g"; }
```

---

## Step 1: Parse Arguments

Parse from the invocation:

| Argument | Description |
|----------|-------------|
| `<query>` | Search term (required unless `--content` is used) |
| `--limit N` | Max sessions to return (default 10, max 50) |
| `--scope project\|global` | Scope to current project (default: project) |
| `--from DATE` | Start date (e.g., `2025-01-01`, inclusive) |
| `--to DATE` | End date (e.g., `2025-06-01`, exclusive) |
| `--title-only` | Search only session titles, not message content |
| `--content <session-id>` | Deep-retrieve full content for a specific session (skips search) |

---

## Step 2: Resolve Database and Project

```bash
DB=~/.local/share/opencode/opencode.db

if [ ! -f "$DB" ]; then
  echo "Database not found at $DB — no OpenCode sessions recorded yet."
  exit 1
fi
```

If `--scope project` (default), resolve the current project ID from the working tree:

```bash
CWD=$(pwd)
ESCAPED_CWD=$(sq_escape "$CWD")
PROJECT_ID=$(sqlite3 "$DB" "SELECT id FROM project WHERE worktree = '$ESCAPED_CWD' OR worktree LIKE '$ESCAPED_CWD/%' LIMIT 1")
echo "Project: ${PROJECT_ID:-none}"
```

---

## Step 3: Deep Content Retrieval Mode

If `--content <session-id>` is provided, skip search and retrieve the full session:

```bash
sqlite3 -json "$DB" "
  SELECT p.id,
         m.time_created,
         JSON_EXTRACT(m.data, '$.role') as role,
         JSON_EXTRACT(p.data, '$.type') as type,
         CASE
           WHEN JSON_EXTRACT(p.data, '$.type') = 'text' THEN JSON_EXTRACT(p.data, '$.text')
           WHEN JSON_EXTRACT(p.data, '$.type') = 'tool' THEN JSON_EXTRACT(p.data, '$.tool')
           WHEN JSON_EXTRACT(p.data, '$.type') = 'reasoning' THEN JSON_EXTRACT(p.data, '$.text')
           ELSE ''
         END as content
  FROM part p
  JOIN message m ON p.message_id = m.id
  WHERE m.session_id = '$(sq_escape "$SESSION_ID")'
    AND JSON_EXTRACT(p.data, '$.type') IN ('text', 'tool', 'reasoning')
  ORDER BY m.time_created, p.id
  LIMIT 200
"
```

Summarize the key points from the output — focus on decisions, architecture choices,
errors and resolutions, and user preferences. Do not dump raw content.

After summarising, offer: "Any durable facts here should be saved to memory via `/new-memory`."

---

## Step 4: Search by Title (fast path)

Always run title search first — it's cheap and often sufficient:

```bash
# Ensure LIMIT is numeric
case "$LIMIT" in ''|*[!0-9]*) LIMIT=10 ;; esac

SCOPE_CLAUSE=""
[ -n "$PROJECT_ID" ] && SCOPE_CLAUSE="AND s.project_id = '$PROJECT_ID'"

FROM_CLAUSE=""
TO_CLAUSE=""
if [ -n "$FROM" ]; then
  FROM_EPOCH=$(python3 -c "from datetime import datetime; print(int(datetime.strptime('$FROM', '%Y-%m-%d').timestamp() * 1000))" 2>/dev/null)
  [ -n "$FROM_EPOCH" ] && FROM_CLAUSE="AND s.time_created >= $FROM_EPOCH"
fi
if [ -n "$TO" ]; then
  TO_EPOCH=$(python3 -c "from datetime import datetime; print(int(datetime.strptime('$TO', '%Y-%m-%d').timestamp() * 1000))" 2>/dev/null)
  [ -n "$TO_EPOCH" ] && TO_CLAUSE="AND s.time_created < $TO_EPOCH"
fi

sqlite3 -json "$DB" "
  SELECT s.id, s.title,
         DATE(s.time_created/1000, 'unixepoch', 'localtime') as date,
         JSON_EXTRACT(s.model, '$.id') as model,
         ROUND(s.cost, 4) as cost
  FROM session s
  WHERE s.title LIKE '%$(sq_escape "$QUERY")%'
    $SCOPE_CLAUSE
    $FROM_CLAUSE
    $TO_CLAUSE
  ORDER BY s.time_created DESC
  LIMIT $LIMIT
"
```

Capture the result count. If sufficient results (≥3 or `--title-only` is set),
skip to Step 6.

---

## Step 5: Search by Content (slow path, when title results are sparse)

If title search returned < 3 results and `--title-only` is not set, also search
message content:

```bash
# Ensure LIMIT is numeric
case "$LIMIT" in ''|*[!0-9]*) LIMIT=10 ;; esac

sqlite3 -json "$DB" "
  SELECT DISTINCT s.id, s.title,
         DATE(s.time_created/1000, 'unixepoch', 'localtime') as date,
         JSON_EXTRACT(s.model, '$.id') as model,
         ROUND(s.cost, 4) as cost,
         SUBSTR(
           GROUP_CONCAT(
             CASE WHEN JSON_EXTRACT(p.data, '$.type') = 'text'
                  THEN JSON_EXTRACT(p.data, '$.text')
                  ELSE '' END, ' '
           ), 1, 300
         ) as preview
  FROM session s
  JOIN message m ON m.session_id = s.id
  JOIN part p ON p.message_id = m.id
  WHERE (JSON_EXTRACT(p.data, '$.type') = 'text'
    AND JSON_EXTRACT(p.data, '$.text') LIKE '%$(sq_escape "$QUERY")%')
    $SCOPE_CLAUSE
    $FROM_CLAUSE
    $TO_CLAUSE
  GROUP BY s.id
  ORDER BY s.time_created DESC
  LIMIT $LIMIT
"
```

---

## Step 6: Display Results

For each matched session, present:

```
## [<date>] <title>
  Session: <id>
  Model: <model>
  Cost: $<cost>
  [preview: <first 300 chars of matching content, if content search>]
```

After all results:

- *"Search complete. Use `/recall-session --content <session-id>` to view full conversation content."*
- *"Use `/new-memory` to save important facts into durable memory."*

If no matches: *"No sessions matched `<query>` in the current project. Try `--scope global` to search across all projects."*

If database is empty: *"No OpenCode sessions found yet — start a conversation first."*

---

## Quality Bar

A good recall-session session should:
- Default to project scope to avoid irrelevant cross-project noise
- Prefer title search for speed, fall back to content search for recall
- Never dump raw SQL output — always present results in readable format
- Offer `/new-memory` for any durable facts discovered
- Keep results to 10 by default (use `--limit` to tune)
