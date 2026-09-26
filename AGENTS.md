# Agents Guide: personal-agents

## Architecture

Two extension types: **skills** (slash commands, run in main conversation, write artifacts) and **agents** (isolated subagents, run in own context, return findings only).

```
skills/<name>/SKILL.md   ← one skill per file
agents/<name>.md                ← one agent per file
```

`make deploy` syncs skills to `~/.config/opencode/skills/` and `~/.claude/skills/`. Agents deploy to three places: the source `.md` files to `~/.config/opencode/agents/`, generated Claude Code variants to `~/.claude/agents/`, and the shared `partials/` to `~/.agents/`. OpenCode and Claude Code discover their own automatically.

Alongside skills and agents, the repo tracks a redacted template for your personal global rules at `global/AGENTS.md.example`. The real `global/AGENTS.md` is gitignored (it holds personal identity/details) and is installed to `~/.config/opencode/AGENTS.md` by `make deploy-global`.

### Skills vs Agents

| | Skills | Agents |
|---|---|---|
| **Invocation** | `/skill-name` | `@agent-name` or auto-matched by description |
| **Writes artifacts** | Yes | No — returns findings only |
| **Best for** | Workflows, orchestration | File-heavy reading that shouldn't bloat main context |

### Artifact Chain

Skills communicate via `.agents/artifacts/` files — each reads the previous step's output:

| Artifact                            | Written by    | Read by                                                |
|-------------------------------------|---------------|--------------------------------------------------------|
| `grill-<slug>-decisions.md`         | `/grill-me`   | `/plan`                                                |
| `<TICKET>-plan.md`                  | `/plan`       | `/review`, `/ship`                                     |
| `<TICKET>-kanban-board.md`          | `/plan`       | `/implement`                                           |
| `<TICKET>-review-impl.md`           | `/review`     | `/ship`                                                |
| `<TICKET>-impl-progress.md`         | `/implement`  | `/implement` (resume)                                  |

### Kanban Board Schema

The Kanban board schema is defined once in `/plan` (`skills/plan/SKILL.md`) — not
copied here. Each slice carries `mode: afk | hitl` (default `hitl`; `/plan`
justifies every `afk`) and its blocking relationships through `blocks`/`blocked_by`.
The board is the plan; per-slice state lives in the impl-progress artifact.

### Vertical Slice impl-progress Schema

The impl-progress schema is defined once in `/implement`
(`skills/implement/SKILL.md`) — not copied here. Its frontmatter `slices:` list is
the state (`status`, `commit`); the body table is display-only.

## Execution Rules

These apply globally across all skills and agents.

**Analysis Paralysis Guard:** After 5+ consecutive read/grep/glob calls with no write/edit/bash action, stop and state in one sentence what's blocking you, then either write code or ask the user for the missing information.

**Authentication Gate Protocol:** Auth errors (401, 403, "Not authenticated") are *gates*, not bugs. Stop, tell the user exactly what credential/command is needed, provide a verification command, and wait for them to complete it. Never treat auth errors as code bugs.

**Deviation Rules:** During execution, auto-fix bugs and missing critical functionality (error handling, validation, auth) without asking. Only stop for architectural decisions (new tables, framework changes, breaking API changes).

**Deferral Convention:** Mark deliberate shortcuts with `deferred:` comments in code — format: `# deferred: <ceiling>, <upgrade path>`. Example: `# deferred: global lock, per-account locks if throughput matters`. Run `/debt-ledger` to harvest all deferrals into a tracked ledger.

## SpotMe Integration

SpotMe is a plugin that intercepts code writes and scaffolds exercises for the human. When active, `/implement` switches to gym mode during green phases. See `.agents/conventions.md` for toggle rules. SpotMe does not interfere with artifact writes or tool calls to non-code files.

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

Written by: `/implement` (slice gates)
Read by: all skills that need cross-session context

Skills should update STATE.md when making decisions or hitting blockers. Keep it lean — decisions, blockers, and position only.

## Typical Workflow

```
/grill-me → /plan → /implement → /review → /ship
```

For unfamiliar codebases, start with `/codemap` to understand the structure first.

### Inside `/implement`: Vertical Slice Loop

Each slice runs Explore → RED → GREEN → REFACTOR → checks → inner `reviewer` (slice
scope, fix Critical and Warning, at most two rounds) → gate. `hitl` slices stop for
approval and are committed once approved; `afk` slices commit themselves when green.
Every slice lands as its own commit, and corrections use `--fixup`. See
`skills/implement/SKILL.md` for the full loop.

## Review Rules Override

The `reviewer` agent (Tab-switchable primary agent, also delegatable as subagent) loads shared rules from `~/.agents/partials/review-rules.md`. Create `.agents/review.md` in the project root to add project-specific review rules — it takes precedence over the shared defaults when present. Template at `templates/review.md.example`.

## Subagent Reference

| Agent | Invocation | Purpose |
|-------|-----------|---------|
| `@observer` | `@observer <question>` or `@observer update` | Maintain and explain codebase via codemaps |
