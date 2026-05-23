# Agents Guide: personal-agents

## Architecture

Two extension types: **skills** (slash commands, run in main conversation, write artifacts) and **agents** (isolated subagents, run in own context, return findings only).

```
skills/<name>/SKILL.md   ← one skill per file
agents/<name>.md                ← one agent per file
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

| Artifact                            | Written by    | Read by                                                |
|-------------------------------------|---------------|--------------------------------------------------------|
| `grill-<slug>-decisions.md`         | `/grill-me`   | `/refine`, `/plan`                                     |
| `<TICKET>-ticket.md`                | `/refine`     | `/plan`                                                |
| `<TICKET>-plan.md`                  | `/plan`       | `/review`, `/ship`, `/experiment`                      |
| `<TICKET>-kanban-board.md`          | `/plan`       | `/implement`                                           |
| `<TICKET>-experiment-<RUN>.md`      | `/experiment` | `/report`, `experiment-analyzer`                       |
| `<TICKET>-review-impl.md`           | `/review`     | `/ship`                                                |
| `<TICKET>-impl-progress.md`         | `/implement`  | `/implement` (resume)                                  |

### Kanban Board Schema

The Kanban board produced by `/plan` defines vertical slices with blocking relationships for parallel execution:

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
    description: <what this slice delivers, crossing all layers>
    blocks: [<slice IDs that depend on this>]
    blocked_by: [<slice IDs this depends on>]
    module_interfaces:
      - module: <file path>
        public_interface: <methods/types exported>
        test_boundaries: <what to test at the boundary>
    tags: [afk|hitl|parallel]
    status: pending
    completed: <ISO 8601 timestamp or null>
---
```

### Vertical Slice impl-progress Schema

Updated progress artifact for slice-based implementation:

```yaml
---
artifact: impl-progress
ticket: <TICKET>
skill: implement
status: in_progress
created: <ISO 8601 timestamp>
current_slice: <slice ID>
completed_slices: []
---

## Slice Progress

| Slice | Title | TDD (RGR) | Status | Completed | Checks |
|-------|-------|-----------|--------|-----------|--------|
| 1 | <title> | done | complete | <timestamp> | pass |
| 2 | <title> | done | in_progress | — | — |
| 3 | <title> | pending | pending | — | — |
```

`status` values: `pending`, `in_progress`, `complete`, `skipped`
`TDD (RGR)` values: `pending`, `done`, `skipped`
`Checks` values: `pass`, `fail`, `—`

## Kanban Board State

The Kanban board file (`<TICKET>-kanban-board.md`) tracks which slices are blockable and which can run in parallel:

- **`afk`** tag: slice requires user judgment (parameter selection, design decisions)
- **`hitl`** tag: slice needs human review of AI output
- **`parallel`** tag: slice has no blocking relationships — can run in parallel with other `parallel` slices

Slices with `blocked_by: []` (no blockers) can start immediately. Slices with `blocked_by: [N]` must wait until slice N is `complete`.

## Execution Rules

These apply globally across all skills and agents.

**Analysis Paralysis Guard:** After 5+ consecutive read/grep/glob calls with no write/edit/bash action, stop and state in one sentence what's blocking you, then either write code or ask the user for the missing information.

**Authentication Gate Protocol:** Auth errors (401, 403, "Not authenticated") are *gates*, not bugs. Stop, tell the user exactly what credential/command is needed, provide a verification command, and wait for them to complete it. Never treat auth errors as code bugs.

**Deviation Rules:** During execution, auto-fix bugs and missing critical functionality (error handling, validation, auth) without asking. Only stop for architectural decisions (new tables, framework changes, breaking API changes).

## SpotMe Integration

SpotMe is a plugin that intercepts code writes and scaffolds exercises for the human. When active, `/implement` switches to gym mode during green phases. See `.agents/conventions.md` for toggle rules. SpotMe does not interfere with artifact writes or tool calls to non-code files.

## Memory Store

Skills and agents save and retrieve persistent memories that survive across sessions.

Two storage locations:
- `~/.agents/memory/` — global memories (user preferences, cross-project feedback)
- `./agents/memory/` — project-scoped memories (project goals, decisions, context)

Each location has a compact `MEMORY.md` index (~50-150 tokens) that skills load to assess relevance, followed by full `.md` files loaded on-demand for matching entries. Index format: `- [Name](slug.md) \`#tags\` — one-line hook`

Memory capacity budget: 30 entries or 6KB total per MEMORY.md index (soft limit — warns when exceeded).

### Auto-Write Behavior

Memories and rules are written automatically without confirmation, triggered by:
- User corrections to agent's approach ("no", "wrong", "actually", "don't do that")
- Environment discoveries (OS, tool versions, paths, quirks)
- Completed multi-step workarounds
- User prescriptive statements ("always X", "never Y")
- User explicitly requesting something be remembered

Memories go to the memory store via `/new-memory`. Rules go to `AGENTS.md` or `.agents/conventions.md` via `/learn`. Both are git-tracked — review changes before committing.

Memory CRUD skills: `/new-memory` (auto-write), `/recall` (search), `/forget` (remove), `/memories` (browse)
Rule skills: `/learn` (auto-write)
Session search: `/recall-session` (search past OpenCode sessions)

Skills that proactively load the index: `/plan`, `/refine`, `/implement`

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
/refine → /plan → /implement → /check → /review → /ship
```

For unfamiliar codebases, start with `/codemap` to understand the structure first.

### Inside `/implement`: Vertical Slice Loop

Each slice follows a TDD cycle with clear-and-resume between slices:

1. **Quality gate** — verify test framework, type checking, linting exist for target module
2. **Explore** — read the relevant module files directly to understand current state before writing tests
3. **Red** — write a failing test for the slice's acceptance criterion
4. **Green** — implement the minimum code to pass the test (across all layers)
5. **Refactor** — clean up, check conventions pulled from memory/AGENTS.md
6. **Verify** — run checks (lint, types, tests)
7. **Gate** — present slice for approval, then `/clear` before next slice

## Review Rules Override

The `reviewer` agent (Tab-switchable primary agent, also delegatable as subagent) loads shared rules from `~/.agents/partials/review-rules.md`. Create `.agents/review.md` in the project root to add project-specific review rules — it takes precedence over the shared defaults when present. Template at `templates/review.md.example`.

## Subagent Reference

| Agent | Invocation | Purpose |
|-------|-----------|---------|
| `@observer` | `@observer <question>` or `@observer update` | Maintain and explain codebase via codemaps |
| `@experiment-analyzer` | Before `/report` | Validate ML metrics against plan thresholds |
