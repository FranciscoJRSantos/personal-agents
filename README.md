# personal-agents

Research-backed agent skills and subagents for software engineering and ML research workflows. Each skill is a slash command that runs inside OpenCode.

## Workflows

**Ticket-based development:**
```
/refine TICKET → /plan TICKET → /implement → /check → /review → /ship
```

**ML research cycle:**
```
/refine TICKET → /plan TICKET → /implement -> train models → /experiment → /report → /check → /review → /ship
```

**Quick fixes:**
```
/hotfix [TICKET] desc
```

**Session start:**
```
/status
```

---

## Setup

```bash
git clone <repo>
make setup    # one-time: create ~/.agents/ and ~/.config/opencode/ directories
make deploy   # sync skills and agents to OpenCode
```

`make deploy` rsyncs `skills/global/` to `~/.config/opencode/skills/` and agents to `~/.config/opencode/agents/` (plus `~/.agents/` for canonical partials and memory).

---

## Skills

| Skill                | Invocation                    | Purpose                                                                 | Workflow    |
|----------------------|-------------------------------|-------------------------------------------------------------------------|-------------|
| `/refine`            | `/refine [TICKET]`            | Refine a Jira ticket interactively                                      | Ticket / ML |
| `/plan`              | `/plan TICKET`                | Generate type-aware implementation plan → Jira comment                  | Ticket / ML |
| `/branch`            | `/branch TICKET`              | Create branch, sync deps, surface existing plan                         | Ticket      |
| `/implement`         | `/implement`                  | Staged implementation with hard gates between 5 phases                  | Ticket      |
| `/test`              | `/test`                       | Generate tests from plan acceptance criteria + diff                     | Ticket      |
| `/review`            | `/review`                     | Severity-grouped code review vs main                                    | Ticket      |
| `/check`             | `/check`                      | Lint + type check + tests (auto-detects stack)                          | Ticket      |
| `/ship`              | `/ship`                       | Gate on review → check → commit → push → MR                             | Ticket      |
| `/gitlab`            | `/gitlab`                     | MRs, pipelines, issues via `glab`                                       | Ticket      |
| `/hotfix`            | `/hotfix [TICKET] desc`       | Streamlined branch → fix → check → ship for urgent changes              | Ticket      |
| `/experiment`        | `/experiment`                 | Capture ML experiment results into artifact for `/report`               | ML          |
| `/experiment-review` | `/experiment-review [run-id]` | Pull W&B runs, display metrics, append to EXPERIMENTS.md                | ML          |
| `/report`            | `/report`                     | Publish ML experiment report to Confluence                              | ML          |
| `/learn`             | `/learn [rule]`               | Capture a session correction into AGENTS.md or .agents/conventions.md   | Any         |
| `/adr`               | `/adr [decision]`             | Record architecture decisions with context, rationale, and alternatives | Any         |
| `/standup`           | `/standup [range]`            | Progress summary from git, MRs, Jira                                    | Any         |
| `/status`            | `/status`                     | Show current state and recommend the next workflow step                 | Any         |
| `/tidy`              | `/tidy`                       | Clean up stale artifacts from completed tickets                         | Any         |

---

## Agents

Primary agents are Tab-switchable during a session. Subagents run in isolated context windows and return findings only.

| Agent                 | Trigger                                         | Purpose                                                     | Category | Mode     |
|-----------------------|-------------------------------------------------|-------------------------------------------------------------|----------|----------|
| `reviewer`            | `/review`, "check my changes", "review !123"    | Code review (own branch or incoming MR). Auto-detects mode. | deep     | all      |
| `fixer`               | "fixer", "fast implementation", "@fixer ..."    | Fast bounded implementation. Tab-switchable.                | quick    | primary  |
| `experiment-analyzer` | "analyze experiment results", before `/report`  | Validate ML metrics against plan thresholds                 | deep     | subagent |
| `explorer`            | "@explorer \<query\>", "find files matching..." | Fast read-only codebase reconnaissance                      | quick    | subagent |
| `observer`            | "@observer \<question\>", "@observer update"    | Maintain and explain codebase via codemaps                  | explore  | subagent |
| `pipeline-validator`  | "validate pipeline", "ready to ship?"           | Check artifact chain integrity before `/ship`               | quick    | subagent |
| `ticket-analyzer`     | "analyze this ticket", before `/plan`           | Surface requirements gaps and risks in a Jira ticket        | quick    | subagent |
| `verifier`            | "verify this artifact", "check plan quality"    | Check that an artifact faithfully answers its source        | quick    | subagent |

---

## Artifact Chain

Skills pass context to each other via `.agents/artifacts/`:

| Artifact                       | Written by    | Read by                                                                                 |
|--------------------------------|---------------|-----------------------------------------------------------------------------------------|
| `<TICKET>-ticket.md`           | `/refine`     | `/plan`                                                                                 |
| `<TICKET>-plan.md`             | `/plan`       | `/branch`, `/review`, `/test`, `/ship`, `/experiment`, `pipeline-validator`, `verifier` |
| `<TICKET>-impl-progress.md`    | `/implement`  | `/implement` (resume), `/status`, `pipeline-validator`                                  |
| `<TICKET>-experiment-<RUN>.md` | `/experiment` | `/report`, `experiment-analyzer`                                                        |
| `<TICKET>-review-impl.md`      | `/review`     | `/ship`, `pipeline-validator`                                                           |
| `<TICKET>-tests.md`            | `/test`       | —                                                                                       |

---

## Plugins

OpenCode plugins fire on lifecycle events. They live in `plugins/` and are registered in `~/.config/opencode/opencode.json`.

| Plugin               | Event                             | Purpose                                                |
|----------------------|-----------------------------------|--------------------------------------------------------|
| `auto-lint.ts`       | `tool.execute.after` (Write)      | Runs project linter on edited JS/TS files              |
| `compaction.ts`      | `experimental.session.compacting` | Saves TODO/impl state before context compaction        |
| `session-context.ts` | `session.created`                 | Injects impl-progress context when a session starts    |
| `write-guard.ts`     | `tool.execute.before` (Write)     | Blocks Write tool on existing files (use Edit instead) |

---

## Agent Categories

`categories.json` defines named model presets. Agents can opt into a preset via `category:` in their frontmatter; `make deploy` resolves it to a concrete `model:` before syncing.

```json
{
  "quick":  { "model": "haiku"  },
  "deep":   { "model": "sonnet" },
  "heavy":  { "model": "opus"   }
}
```

Agent frontmatter example:
```yaml
---
name: fast-reviewer
description: Quick code review
category: quick
---
```

To reroute all agents to a different model tier, update `categories.json` and re-run `make deploy`. `make lint-agents` validates that every `category:` value exists in `categories.json`.

---

## External Tools

Skills call these CLI tools when available. Install them separately.

| Tool                 | Used by                        | Purpose                               |
|----------------------|--------------------------------|---------------------------------------|
| `glab`               | `/gitlab`, `/ship`, `reviewer` | GitLab CLI for MRs and pipelines      |
| `acli`               | `/plan`, `/refine`, `/report`  | Atlassian CLI for Jira and Confluence |
| `uv` / `poetry`      | `/branch`, `/check`            | Python dependency sync                |
| `wandb` (Python SDK) | `/experiment-review`           | W&B run metrics                       |
| `yq`                 | `make deploy`                  | YAML frontmatter parsing/resolution   |

---

## Common Patterns

**Before implementing — validate the plan:**
```
/plan TICKET
use the verifier agent        # check plan covers all ticket requirements
/implement
```

**Before shipping — validate the pipeline:**
```
/review
use the pipeline-validator agent   # check no stale artifacts or TBD thresholds
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

`.agents/STATE.md` persists cross-session context (current branch, stage, decisions, blockers). Written by `/implement`, `/hotfix`, `/quick`; read by `/status`.

---

## Deployment Targets

| Command                | What it does                                                                         |
|------------------------|--------------------------------------------------------------------------------------|
| `make setup`           | One-time: create `~/.agents/` and `~/.config/opencode/` directories                  |
| `make deploy`          | Sync skills + agents to OpenCode (resolves `category:` → `model:`)                   |
| `make deploy-opencode` | Sync skills to `~/.config/opencode/skills/` + agents to `~/.config/opencode/agents/` |
| `make deploy-agents`   | Sync agents to `~/.agents/` (includes partials and memory)                           |
| `make pull`            | Pull changes from deployed locations back into the repo                              |
| `make lint-skills`     | Validate SKILL.md frontmatter                                                        |
| `make lint-agents`     | Validate agent `.md` frontmatter (warns on missing `permission:`)                    |

---

## Adding a Skill

1. Create `skills/global/<name>/SKILL.md` with YAML frontmatter (`name`, `description`) and instructions
2. Run `make lint-skills` to validate
3. Run `make deploy`

---

## Adding a New Agent

1. Create `agents/<name>.md` with YAML frontmatter (`description`, `category`, `permission`)
2. Run `make lint-agents` to validate
3. Run `make deploy`
