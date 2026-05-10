# Agents Guide: personal-agents

## Architecture

Two extension types: **skills** (slash commands, run in main conversation, write artifacts) and **agents** (isolated subagents, run in own context, return findings only).

```
skills/global/<name>/SKILL.md   ← one skill per file
agents/<name>.md                ← one agent per file
categories.json                 ← category name → model mapping
```

`make deploy` syncs skills to `~/.config/opencode/skills/` and agents to `~/.config/opencode/agents/` and `~/.agents/`. OpenCode discovers both automatically.

### Skills vs Agents

| | Skills | Agents |
|---|---|---|
| **Invocation** | `/skill-name` | `@agent-name` or auto-matched by description |
| **Writes artifacts** | Yes | No — returns findings only |
| **Best for** | Workflows, orchestration | File-heavy reading that shouldn't bloat main context |

### Artifact Chain

Skills communicate via `.agents/artifacts/` files — each reads the previous step's output:

| Artifact                       | Written by    | Read by                                                |
|--------------------------------|---------------|--------------------------------------------------------|
| `<TICKET>-ticket.md`           | `/refine`     | `/plan`                                                |
| `<TICKET>-plan.md`             | `/plan`       | `/branch`, `/review`, `/test`, `/ship`, `/experiment`  |
| `<TICKET>-experiment-<RUN>.md` | `/experiment` | `/report`                                              |
| `<TICKET>-review-impl.md`      | `/review`     | `/ship`                                                |
| `<TICKET>-tests.md`            | `/test`       | —                                                      |
| `<TICKET>-impl-progress.md`    | `/implement`  | `/implement` (resume), `/status`, `pipeline-validator` |
| `quick-<slug>-progress.md`     | `/quick`      | `/status`                                              |

## Execution Rules

These apply globally across all skills and agents.

**Analysis Paralysis Guard:** After 5+ consecutive read/grep/glob calls with no write/edit/bash action, stop and state in one sentence what's blocking you, then either write code or ask the user for the missing information.

**Authentication Gate Protocol:** Auth errors (401, 403, "Not authenticated") are *gates*, not bugs. Stop, tell the user exactly what credential/command is needed, provide a verification command, and wait for them to complete it. Never treat auth errors as code bugs.

**Deviation Rules:** During execution, auto-fix bugs and missing critical functionality (error handling, validation, auth) without asking. Only stop for architectural decisions (new tables, framework changes, breaking API changes).

## Memory Store

Skills and agents can save and retrieve persistent memories that survive across sessions.

Two storage locations:
- `~/.agents/memory/` — global memories (user preferences, cross-project feedback)
- `./agents/memory/` — project-scoped memories (project goals, decisions, context)

Each location has a compact `MEMORY.md` index (~50-150 tokens) that skills load to assess relevance, followed by full `.md` files loaded on-demand for matching entries. Index format: `- [Name](slug.md) \`#tags\` — one-line hook`

Memory CRUD skills: `/new-memory`, `/recall`, `/forget`, `/memories`
Skills that proactively load the index: `/plan`, `/status`, `/standup`

## Project State

A lightweight state file at `.agents/STATE.md` persists cross-session context:

```yaml
---
last_updated: <ISO 8601 timestamp>
current_branch: <branch name>
position: <what stage of what workflow>
---
## Decisions
- <decision> (<date>)

## Blockers
- <blocker>

## Deferred Items
- <items logged during deviation handling>
```

Written by: `/implement` (stage gates), `/hotfix` (on completion), `/quick` (on completion)
Read by: `/status` (displays in dashboard)

Skills should update STATE.md when making decisions or hitting blockers. Keep it lean — decisions, blockers, and position only.

## Typical Workflow

```
/branch TICKET → /plan → /implement → /check → /review → /test → /ship
```

For unfamiliar codebases, start with `/codemap` to understand the structure first.

## Review Rules Override

The `reviewer` agent (Tab-switchable primary agent, also delegatable as subagent) loads shared rules from `~/.agents/partials/review-rules.md`. Create `.agents/review.md` in the project root to add project-specific review rules — it takes precedence over the shared defaults when present. Template at `templates/review.md.example`.
