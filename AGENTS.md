# Agents Guide: personal-agents

## Quick Start
```bash
git clone <repo>
make deploy   # Deploys skills and agents to OpenCode
```

## Commands

```bash
make setup           # One-time: create ~/.agents/ and ~/.config/opencode/ directories
make deploy          # Sync skills to ~/.config/opencode/skills/ + agents to ~/.config/opencode/agents/ and ~/.agents/
make pull            # Pull changes back from deployed locations into the repo
make list-skills     # List all deployed skills
make lint-skills     # Validate SKILL.md frontmatter before deploying
make deploy-agents   # Sync agents to ~/.agents/ only
make list-agents     # List all agents
make lint-agents     # Validate agent .md frontmatter before deploying (warns on missing permission:)
```

## Initial Setup

If this is a fresh clone:

```bash
# Create canonical location + opencode directories
make setup

# Deploy everything
make deploy
```

After setup, skills are available at `~/.config/opencode/skills/` and agents at `~/.config/opencode/agents/`. OpenCode discovers both automatically.

## Architecture

This repo manages two types of extensions: **skills** (slash commands loaded into the main conversation) and **agents** (isolated subagents with their own context windows).

```
skills/global/<name>/SKILL.md   ← one file per skill
agents/<name>.md                ← one file per agent
plugins/<name>.ts               ← one file per OpenCode plugin
categories.json                 ← category name → model mapping
```

`make deploy` rsyncs skills to `~/.config/opencode/skills/` and agents to `~/.config/opencode/agents/`. Agents are also synced to `~/.agents/` (canonical location for partials and memory).

When invoked, a skill runs inside OpenCode. It can call external CLI tools (`glab`, `acli`, `reviewer`, etc.) via Bash, read/write files, and chain to other skills via artifacts.

```
User → /skill → OpenCode reads SKILL.md → executes steps → writes .agents/artifacts/
```

### Skills vs Agents

| | Skills | Agents |
|---|---|---|
| **What** | Instructions loaded into your conversation | Isolated worker with its own context window |
| **Best for** | Workflows, checklists, orchestration | File-heavy tasks that shouldn't bloat main context |
| **Writes artifacts** | Yes | No — returns findings only |
| **Invocation** | `/skill-name` | Automatic (by description) or `@agent-name` |

### Model-Agnostic Memory Store

Skills and agents can save and retrieve persistent memories that survive across sessions.

Two storage locations:
- `~/.agents/memory/` — global memories (user preferences, cross-project feedback)
- `./agents/memory/` — project-scoped memories (project goals, decisions, context)

Each location has a compact `MEMORY.md` index (~50–150 tokens) that skills load to assess relevance, followed by full `.md` files loaded on-demand for matching entries. The index format is one line per entry: `- [Name](slug.md) \`#tags\` — one-line hook`.

Memory CRUD skills: `/new-memory`, `/recall`, `/forget`, `/memories`
Skills that proactively load the index: `/plan`, `/status`, `/standup`

### Artifact Chain

Skills write and read files under `.agents/artifacts/` to pass context between steps:

| Artifact                       | Written by    | Read by                                                |
|--------------------------------|---------------|--------------------------------------------------------|
| `<TICKET>-ticket.md`           | `/refine`     | `/plan`                                                |
| `<TICKET>-plan.md`             | `/plan`       | `/branch`, `/review`, `/test`, `/ship`, `/experiment`  |
| `<TICKET>-experiment-<RUN>.md` | `/experiment` | `/report`                                              |
| `<TICKET>-review-impl.md`      | `/review`     | `/ship`                                                |
| `<TICKET>-tests.md`            | `/test`       | —                                                      |
| `<TICKET>-impl-progress.md`    | `/implement`  | `/implement` (resume), `/status`, `pipeline-validator` |

## Skills

| Skill        | Invocation                                  | What it does                                                              |
|--------------|---------------------------------------------|---------------------------------------------------------------------------|
| `adr`        | `/adr [decision]`                           | Record an architecture decision with context, rationale, and alternatives |
| `branch`     | `/branch TICKET`                            | Create feature branch, sync deps, show plan summary                       |
| `check`      | `/check`                                    | Lint + type check + tests (auto-detects stack)                            |
| `codemap`    | `/codemap`                                  | Generate hierarchical codebase architecture map                           |
| `create-skill`| `/create-skill [skill\|agent] [name]`      | Guide the creation of a new skill or agent                                |
| `experiment` | `/experiment`                               | Capture ML experiment results into artifact for `/report`                 |
| `experiment-review` | `/experiment-review [run-id]`          | Pull W&B runs, display metrics, append to EXPERIMENTS.md                  |
| `forget`     | `/forget <name>`                            | Remove a memory from the model-agnostic store                             |
| `gitlab`     | `/gitlab`                                   | MRs, pipelines, issues via `glab`                                         |
| `hotfix`     | `/hotfix [TICKET] desc`                     | Streamlined branch → fix → check → ship for urgent changes                |
| `implement`  | `/implement`                                | Staged implementation with hard gates between 5 phases                    |
| `learn`      | `/learn [rule]`                             | Capture a session correction into AGENTS.md or .agents/conventions.md     |
| `memories`   | `/memories [--global\|--project\|--type t]` | Browse the memory store index without loading full content                |
| `new-memory` | `/new-memory [text]`                        | Save a memory to the model-agnostic store                                 |
| `plan`       | `/plan TICKET`                              | Type-aware implementation plan → Jira comment                             |
| `recall`     | `/recall <query>`                           | Search the memory store by keyword or tag and return full content         |
| `refine`     | `/refine [TICKET]`                          | Interactively refine a Jira ticket                                        |
| `report`     | `/report`                                   | Publish ML experiment report to Confluence                                |
| `review`     | `/review`                                   | Severity-grouped code review vs main                                      |
| `ship`       | `/ship`                                     | Gate on review → check → commit → push → MR                               |
| `standup`    | `/standup [range]`                          | Progress summary from git, MRs, Jira                                      |
| `status`     | `/status`                                   | Session bootstrap — show state and recommend next step                    |
| `test`       | `/test`                                     | Generate tests from plan AC + diff                                        |
| `tidy`       | `/tidy`                                     | Clean up stale artifacts from completed tickets                           |
| `update-skill`| `/update-skill`                            | Enforce source-repo-first editing for skills and agents                   |

## Agents

Agents run in isolated context windows and return findings only — they do not write artifacts.

| Agent | Trigger | Purpose |
|---|---|---|
| `code-reviewer` | `/review` (large diffs), "deep review" | Deep isolated review of own branch diff |
| `experiment-analyzer` | "analyze experiment results", before `/report` | Validate ML metrics against plan thresholds |
| `explorer` | "@explorer \<query\>", "find files matching..." | Fast read-only codebase reconnaissance |
| `fixer` | "@fixer \<task\>", "write tests for..." | Fast bounded implementation for scoped tasks |
| `pipeline-validator` | "validate pipeline", "ready to ship?" | Check artifact chain integrity before `/ship` |
| `pr-reviewer` | "review !123", "review teammate's MR" | Review incoming MRs from teammates via `glab` |
| `ticket-analyzer` | "analyze this ticket", before `/plan` | Surface requirements gaps and risks in a Jira ticket |
| `verifier` | "verify this artifact", "check plan quality" | Check that an artifact faithfully answers its source |

Agents are defined in `~/.config/opencode/agents/` as markdown files. `make deploy-opencode` deploys `.md` agent files there. Subagents are invoked with `@agent-name` in the TUI.

## Repository Map

A hierarchical codemap of the codebase is available at `.agents/codemap/codemap.md`.
Run `/codemap` to regenerate it after structural changes.

## Typical Workflow

```
/branch TICKET → /plan → /implement → /check → /review → /test → /ship
```

For unfamiliar codebases, start with `/codemap` to understand the structure first.

## Adding a Skill
1. Create `skills/global/<name>/SKILL.md` with the skill instructions
2. Run `make lint-skills` to validate frontmatter
3. Run `make deploy` to push to `~/.config/opencode/skills/`

## Adding a New Agent
1. Create `agents/<name>.md` with YAML frontmatter (`name`, `description`, `model`) and a system prompt
2. Add tool access fields via `permission:`:
   - `mode: subagent`
   - `permission: {edit: deny, bash: allow, webfetch: deny}` (adjust per tool access needed)
   - Do not use `tools:` — OpenCode uses `permission:` format instead
3. Optionally add `category:` to reference a model from `categories.json`
4. Run `make lint-agents` to validate frontmatter
5. Run `make deploy` to push to `~/.config/opencode/agents/` and `~/.agents/`

## Plugins

OpenCode plugins live in `plugins/` and provide lifecycle hooks:

| Plugin | Purpose |
|--------|---------|
| `auto-lint.ts` | Runs linter on edited JS/TS files via `tool.execute.after` |
| `compaction.ts` | Preserves TODO state before and after context compaction |
| `session-context.ts` | Loads implement-progress context when a session starts |
| `write-guard.ts` | Blocks Write tool on existing files (use Edit instead) |

Plugins are registered in `~/.config/opencode/opencode.json`.

## Agent Categories

Define model presets in `categories.json`. Agents can reference these via `category:` frontmatter, which resolves to a model at deploy time.

```json
{
  "quick": { "model": "haiku" },
  "deep": { "model": "sonnet" },
  "heavy": { "model": "opus" }
}
```

Agent frontmatter:
```yaml
---
name: fast-reviewer
description: Quick code review
category: quick
---
```

`make deploy` resolves `category:` → `model:` before syncing to `~/.config/opencode/agents/` and `~/.agents/`.

## Deployment Targets

| Command | What it does |
|---|---|
| `make deploy` | Sync skills + agents to OpenCode |
| `make deploy-opencode` | Sync skills to `~/.config/opencode/skills/` + agents to `~/.config/opencode/agents/` |
| `make deploy-agents` | Sync agents to `~/.agents/` (resolves categories first) |
| `make pull` | Pull changes from deployed locations back into repo |
| `make list-skills` | List all global skills |
| `make lint-skills` | Validate SKILL.md frontmatter |
| `make lint-agents` | Validate agent .md frontmatter |
