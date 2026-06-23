# personal-agents

Research-backed agent skills and subagents for software engineering workflows. Each skill is a slash command that runs inside OpenCode or Claude Code.

## Workflows

**Primary (design → ship):**
```
/grill-me → [post to Jira via MCP] → /plan → /implement → /review → /ship
```

**Quick fix (no upfront design):**
```
/implement → /ship
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
make setup    # one-time: create ~/.agents/ and ~/.config/opencode/ directories
make deploy   # sync skills and agents to OpenCode and Claude Code
```

`make deploy` rsyncs `skills/` to `~/.config/opencode/skills/` and `~/.claude/skills/`, and agents to `~/.config/opencode/agents/` (plus `~/.agents/` for canonical partials).

---

## Skills

| Skill                | Invocation                                | Purpose                                                                 |
|----------------------|-------------------------------------------|-------------------------------------------------------------------------|
| `/grill-me`          | `/grill-me [topic]`                       | Stress-test a design through adversarial decision-tree conversation     |
| `/plan`              | `/plan TICKET`                            | Generate type-aware implementation plan → Jira comment                  |
| `/implement`         | `/implement`                              | Staged implementation with hard gates between vertical slices           |
| `/review`            | `/review`                                 | Severity-grouped code review vs main                                    |
| `/yagni-review`      | `/yagni-review`                           | Over-engineering-only review: find what to delete, one line per finding |
| `/debt-ledger`       | `/debt-ledger`                            | Harvest `deferred:` comments into a tracked debt ledger                 |
| `/ship`              | `/ship`                                   | Run checks → gate on review → commit → push → MR                       |
| `/codemap`           | `/codemap`                                | Generate hierarchical architectural codemap of the codebase             |
| `/learn`             | `/learn [rule]`                           | Capture a session correction into AGENTS.md or .agents/conventions.md   |
| `/adr`               | `/adr [decision]`                         | Record architecture decisions with context, rationale, and alternatives |
| `/create-skill`      | `/create-skill [skill\|agent] [name]`     | Guide creation of new skills and agents using research-backed checklist |
| `/update-skill`      | `/update-skill`                           | Enforce skill/agent edits in source repo, not deployed locations        |

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

## Plugins

OpenCode plugins fire on lifecycle events. They live in `plugins/` and are registered in `~/.config/opencode/opencode.json`.

| Plugin               | Event                             | Purpose                                                |
|----------------------|-----------------------------------|--------------------------------------------------------|
| `auto-lint.ts`       | `tool.execute.after` (Write)      | Runs project linter on edited JS/TS files              |
| `write-guard.ts`     | `tool.execute.before` (Write)     | Blocks Write tool on existing files (use Edit instead) |
| `session-context.ts` | `session.created`                 | Injects impl-progress context when a session starts    |

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

## Deployment Targets

| Command                | What it does                                                                         |
|------------------------|--------------------------------------------------------------------------------------|
| `make setup`           | One-time: create `~/.agents/` and `~/.config/opencode/` directories                  |
| `make deploy`          | Sync skills + agents to OpenCode and Claude Code                                     |
| `make deploy-opencode` | Sync skills to `~/.config/opencode/skills/` + agents to `~/.config/opencode/agents/` |
| `make deploy-claude`   | Sync skills to `~/.claude/skills/`                                                   |
| `make deploy-agents`   | Sync agents to `~/.agents/` (includes partials)                                      |
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

---

## Archived Skills

The following skills are archived in `archive/` and not deployed. They can be restored by moving them back to `skills/` or `agents/`.

| Skill                | Purpose                                                |
|----------------------|--------------------------------------------------------|
| `/experiment`        | Capture ML experiment results into artifact             |
| `/experiment-review` | Pull W&B runs, display metrics, append to EXPERIMENTS.md|
| `/report`            | Publish ML experiment report to Confluence              |
| `/insight`           | Analytics dashboard from session data                   |
| `experiment-analyzer`| ML metrics validation agent                             |
