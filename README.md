# personal-agents

Research-backed agent skills and subagents for software engineering workflows. Each skill is a slash command that runs inside OpenCode or Claude Code.

## Workflows

**Primary (design → ship):**
```
/grill-me → [post to Jira via MCP] → /plan → /implement → /review → /ship
```

**Quick fix (no upfront design):**
```
/implement   # ad-hoc: one goal + one acceptance criterion, one reviewed commit
/ship
```

**Ticket already exists in Jira:**
```
/plan TICKET → /implement → /review → /ship
```

**Session start:**
```
/codemap
```

---

## Setup

```bash
git clone <repo>
make deploy   # sync skills and agents to OpenCode and Claude Code
```

`make deploy` syncs `skills/` to `~/.config/opencode/skills/` and `~/.claude/skills/`, and agents to `~/.config/opencode/agents/` (the OpenCode source format). Claude Code needs different frontmatter, so the deploy also generates a Claude variant per agent into `~/.claude/agents/` (`name`, `description`, `model: inherit`, and a `tools` list derived from the OpenCode `permissions`); `~/.agents/` holds only the shared `partials/`. It also installs your local global rules (`global/AGENTS.md`, gitignored) to `~/.config/opencode/AGENTS.md` — see [Global Rules](#global-rules).

---

## Skills

| Skill           | Invocation                            | Purpose                                                                   |
|-----------------|---------------------------------------|---------------------------------------------------------------------------|
| `/grill-me`     | `/grill-me [topic]`                   | Stress-test a design through adversarial decision-tree conversation       |
| `/plan`         | `/plan TICKET`                        | Generate type-aware implementation plan → Jira comment                    |
| `/implement`    | `/implement`                          | Slice-by-slice TDD with per-slice commits (ad-hoc mode without a plan)    |
| `/review`       | `/review`                             | Severity-grouped code review vs main                                      |
| `/yagni-review` | `/yagni-review`                       | Over-engineering-only review: find what to delete, one line per finding   |
| `/debt-ledger`  | `/debt-ledger`                        | Harvest `deferred:` comments into a tracked debt ledger                   |
| `/ship`         | `/ship`                               | Checks → fresh-review gate → autosquash → push → MR; close artifacts last |
| `/codemap`      | `/codemap`                            | Generate hierarchical architectural codemap of the codebase               |
| `/learn`        | `/learn [rule]`                       | Capture a session correction into AGENTS.md or .agents/conventions.md     |
| `/adr`          | `/adr [decision]`                     | Record architecture decisions with context, rationale, and alternatives   |
| `/create-skill` | `/create-skill [skill\|agent] [name]` | Guide creation of new skills and agents using research-backed checklist   |
| `/handoff`      | `/handoff [focus]`                    | Compact the session into a handoff doc + sync STATE.md for the next agent |

---

## Agents

Primary agents are Tab-switchable during a session. Subagents run in isolated context windows and return findings only.

| Agent                 | Trigger                                         | Purpose                                                     | Mode     |
|-----------------------|-------------------------------------------------|-------------------------------------------------------------|----------|
| `reviewer`            | `/review`, "check my changes", "review !123"    | Code review (own branch or incoming MR). Auto-detects mode. | all      |
| `observer`            | "@observer \<question\>", "@observer update"    | Maintain and explain codebase via codemaps                  | subagent |

---

## Artifact Chain

Skills pass context to each other via `.agents/artifacts/`:

| Artifact                            | Written by    | Read by                                          |
|-------------------------------------|---------------|--------------------------------------------------|
| `grill-<slug>-decisions.md`         | `/grill-me`   | `/plan`                                          |
| `<TICKET>-plan.md`                  | `/plan`       | `/review`, `/ship`                               |
| `<TICKET>-kanban-board.md`          | `/plan`       | `/implement`                                     |
| `<TICKET>-impl-progress.md`         | `/implement`  | `/implement` (resume)                            |
| `<TICKET>-review-impl.md`           | `/review`     | `/ship`                                          |

---

## External Tools

Skills call these CLI tools when available. Install them separately.

| Tool                 | Used by                        | Purpose                               |
|----------------------|--------------------------------|---------------------------------------|
| `glab`               | `/ship`, `reviewer`            | GitLab CLI for MRs and pipelines      |
| `acli`               | `/plan`                        | Atlassian CLI for Jira                |
| `uv` / `poetry`      | `/ship`                        | Python dependency sync                |

---

## Common Patterns

**Before implementing — validate the plan:**
```
/plan TICKET
/implement
```

**Before shipping — validate the pipeline:**
```
/review
/ship
```

**Capture a lesson before closing a session:**
```
/learn never use bare except clauses because they hide all errors silently
```

**Record an architectural choice:**
```
/adr switched from polling to webhooks for event delivery
```

**Context hygiene between major steps:**
```
/plan TICKET   → /clear → /implement   # fresh context for implementation
/implement     → /clear → /review      # fresh context for review
/review        → /clear → /ship        # fresh context for ship
```

---

## Project State

`.agents/STATE.md` persists cross-session context (current branch, stage, decisions, blockers). Written by `/implement`; read by all skills that need cross-session context.

---

## Global Rules

Your personal global `AGENTS.md` (identity, stack, style, model routing) is tracked locally at `global/AGENTS.md`, which is **gitignored** so those details stay off this public repo.

```bash
cp global/AGENTS.md.example global/AGENTS.md   # redacted template → local real file
$EDITOR global/AGENTS.md                        # fill in your details
make deploy-global                              # install → ~/.config/opencode/AGENTS.md
```

`make deploy-global` writes to `~/.config/opencode/AGENTS.md`. Because `~/.claude/CLAUDE.md` symlinks to that file, both OpenCode and Claude Code pick it up. `make drift` diffs the deployed copy against `global/AGENTS.md`.

---

## Deployment Targets

| Command              | What it does                                                                         |
|----------------------|--------------------------------------------------------------------------------------|
| `make deploy`        | Sync skills + agents + global rules to OpenCode and Claude Code                      |
| `make deploy-skills` | Sync skills to OpenCode + Claude only — leaves live agents untouched                 |
| `make deploy-global` | Install `global/AGENTS.md` → `~/.config/opencode/AGENTS.md` (gitignored source; skips if absent) |
| `make drift`         | Read-only diff of the repo against every deployed location (never copies)            |
| `make lint-skills`   | Validate SKILL.md frontmatter                                                        |
| `make lint-agents`   | Validate agent `.md` frontmatter (warns on missing V2 `permissions:` list, validates rule shape) |

Skill and agent deploys are manifest-based: each target dir keeps a
`.personal-agents-manifest` listing what this repo deployed, and only those items are
ever updated or removed — anything else at the destination (e.g. `~/.claude/skills/synced/`,
plugin skills, hand-made agents) is left alone. Agents deploy to three locations: the
OpenCode source to `~/.config/opencode/agents/`, generated Claude variants to
`~/.claude/agents/`, and the shared `partials/` to `~/.agents/`. The global-rules deploy
writes a single file. Preview any deploy without changing anything by adding `DRY_RUN=1`,
e.g. `make deploy DRY_RUN=1`. After a deploy, `make drift` diffs the repo against each
location and reports unowned extras.

---

## Adding a Skill

1. Create `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`) and instructions
2. Run `make lint-skills` to validate
3. Run `make deploy`

---

## Adding a New Agent

1. Create `agents/<name>.md` with YAML frontmatter (`description`, `model`, `permissions`) — the agent name comes from the filename
2. Run `make lint-agents` to validate
3. Run `make deploy`

The Claude Code variant is generated at deploy time. Never hand-edit the copy in
`~/.claude/agents/` — edit the source and run `make deploy`.
