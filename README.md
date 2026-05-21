# personal-agents

Research-backed agent skills and subagents for software engineering and ML research workflows. Each skill is a slash command that runs inside OpenCode.

## Workflows

**Ticket-based development:**
```
/refine → /plan → /implement → /check → /review → /ship
```

**Kickstarter path (meeting notes → shipped):**
```
/grill-me → /refine → /plan → /implement → /check → /review → /ship
```

**ML research cycle:**
```
/refine → /plan → /implement → train models → /experiment → /report → /check → /review → /ship
```

**Session start:**
```
/codemap
```

---

## Setup

```bash
git clone <repo>
make setup    # one-time: create ~/.agents/ and ~/.config/opencode/ directories
make deploy   # sync skills and agents to OpenCode
```

`make deploy` rsyncs `skills/` to `~/.config/opencode/skills/` and agents to `~/.config/opencode/agents/` (plus `~/.agents/` for canonical partials and memory).

---

## Skills

| Skill                | Invocation                                | Purpose                                                                 | Workflow    |
|----------------------|-------------------------------------------|-------------------------------------------------------------------------|-------------|
| `/refine`            | `/refine [TICKET]`                        | Refine a Jira ticket interactively                                      | Ticket / ML |
| `/plan`              | `/plan TICKET`                            | Generate type-aware implementation plan → Jira comment                  | Ticket / ML |
| `/grill-me`          | `/grill-me [topic]`                       | Stress-test a design through adversarial decision-tree conversation     | Kickstarter |
| `/implement`         | `/implement`                              | Staged implementation with hard gates between 5 phases                  | Ticket      |
| `/review`            | `/review`                                 | Severity-grouped code review vs main                                    | Ticket      |
| `/check`             | `/check`                                  | Lint + type check + tests (auto-detects stack)                          | Ticket      |
| `/ship`              | `/ship`                                   | Gate on review → check → commit → push → MR                             | Ticket      |
| `/experiment`        | `/experiment`                             | Capture ML experiment results into artifact for `/report`               | ML          |
| `/experiment-review` | `/experiment-review [run-id]`             | Pull W&B runs, display metrics, append to EXPERIMENTS.md                | ML          |
| `/report`            | `/report`                                 | Publish ML experiment report to Confluence                              | ML          |
| `/learn`             | `/learn [rule]`                           | Capture a session correction into AGENTS.md or .agents/conventions.md   | Any         |
| `/adr`               | `/adr [decision]`                         | Record architecture decisions with context, rationale, and alternatives | Any         |
| `/codemap`           | `/codemap`                                | Generate hierarchical architectural codemap of the codebase             | Any         |
| `/create-skill`      | `/create-skill [skill\|agent] [name]`     | Guide creation of new skills and agents using research-backed checklist | Any         |
| `/update-skill`      | `/update-skill`                           | Enforce skill/agent edits in source repo, not deployed locations        | Any         |
| `/new-memory`        | `/new-memory [text]`                      | Save a memory to the persistent, model-agnostic store                   | Any         |
| `/recall`            | `/recall <query>`                         | Search the memory store for relevant memories                           | Any         |
| `/forget`            | `/forget <name-or-query>`                 | Remove memories from the store                                          | Any         |
| `/memories`          | `/memories [--global\|--project\|--type]` | List and browse the memory store index                                  | Any         |

---

## Agents

Primary agents are Tab-switchable during a session. Subagents run in isolated context windows and return findings only.

| Agent                 | Trigger                                         | Purpose                                                     | Mode     |
|-----------------------|-------------------------------------------------|-------------------------------------------------------------|----------|
| `reviewer`            | `/review`, "check my changes", "review !123"    | Code review (own branch or incoming MR). Auto-detects mode. | all      |
| `experiment-analyzer` | "analyze experiment results", before `/report`  | Validate ML metrics against plan thresholds                 | subagent |
| `observer`            | "@observer \<question\>", "@observer update"    | Maintain and explain codebase via codemaps                  | subagent |

---

## Artifact Chain

Skills pass context to each other via `.agents/artifacts/`:

| Artifact                            | Written by    | Read by                                          |
|-------------------------------------|---------------|--------------------------------------------------|
| `grill-<slug>-decisions.md`         | `/grill-me`   | `/refine`, `/plan`                               |
| `<TICKET>-ticket.md`                | `/refine`     | `/plan`                                          |
| `<TICKET>-plan.md`                  | `/plan`       | `/review`, `/ship`, `/experiment`                |
| `<TICKET>-kanban-board.md`          | `/plan`       | `/implement`                                     |
| `<TICKET>-impl-progress.md`         | `/implement`  | `/implement` (resume)                            |
| `<TICKET>-experiment-<RUN>.md`      | `/experiment` | `/report`, `experiment-analyzer`                 |
| `<TICKET>-review-impl.md`           | `/review`     | `/ship`                                          |

---

## Plugins

OpenCode plugins fire on lifecycle events. They live in `plugins/` and are registered in `~/.config/opencode/opencode.json`.

| Plugin               | Event                             | Purpose                                                |
|----------------------|-----------------------------------|--------------------------------------------------------|
| `auto-lint.ts`       | `tool.execute.after` (Write)      | Runs project linter on edited JS/TS files              |
| `session-context.ts` | `session.created`                 | Injects impl-progress context when a session starts    |
| `write-guard.ts`     | `tool.execute.before` (Write)     | Blocks Write tool on existing files (use Edit instead) |

---

## External Tools

Skills call these CLI tools when available. Install them separately.

| Tool                 | Used by                        | Purpose                               |
|----------------------|--------------------------------|---------------------------------------|
| `glab`               | `/ship`, `reviewer`            | GitLab CLI for MRs and pipelines      |
| `acli`               | `/plan`, `/refine`, `/report`  | Atlassian CLI for Jira and Confluence |
| `uv` / `poetry`      | `/check`                       | Python dependency sync                |
| `wandb` (Python SDK) | `/experiment-review`           | W&B run metrics                       |

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

## Memory Store

Skills and agents can persist memories across sessions to `~/.agents/memory/` (global) or `./agents/memory/` (project). Each uses a compact `MEMORY.md` index. CRUD via `/new-memory`, `/recall`, `/forget`, `/memories`.

---

## Project State

`.agents/STATE.md` persists cross-session context (current branch, stage, decisions, blockers). Written by `/implement`; read by all skills that need cross-session context.

---

## Deployment Targets

| Command                | What it does                                                                         |
|------------------------|--------------------------------------------------------------------------------------|
| `make setup`           | One-time: create `~/.agents/` and `~/.config/opencode/` directories                  |
| `make deploy`          | Sync skills + agents to OpenCode                                                     |
| `make deploy-opencode` | Sync skills to `~/.config/opencode/skills/` + agents to `~/.config/opencode/agents/` |
| `make deploy-agents`   | Sync agents to `~/.agents/` (includes partials and memory)                           |
| `make pull`            | Pull changes from deployed locations back into the repo                              |
| `make lint-skills`     | Validate SKILL.md frontmatter                                                        |
| `make lint-agents`     | Validate agent `.md` frontmatter (warns on missing `permission:`)                    |

---

## Adding a Skill

1. Create `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`) and instructions
2. Run `make lint-skills` to validate
3. Run `make deploy`

---

## Adding a New Agent

1. Create `agents/<name>.md` with YAML frontmatter (`description`, `model`, `permission`)
2. Run `make lint-agents` to validate
3. Run `make deploy`
