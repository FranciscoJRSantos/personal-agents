# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make setup           # One-time: create ~/.agents/ and symlink Claude Code + opencode to it
make deploy          # Sync skills to ~/.claude/skills/, ~/.gemini/skills/, ~/.config/eca/skills/ + agents to ~/.agents/ + hooks to ~/.claude/
make deploy-dry      # Preview what deploy would change without writing
make pull            # Pull changes back from deployed locations into the repo
make list-skills     # List all deployed skills
make lint-skills     # Validate SKILL.md frontmatter before deploying
make deploy-agents   # Sync agents to ~/.agents/ only
make list-agents     # List all agents
make lint-agents     # Validate agent .md frontmatter before deploying (warns on missing permission:)
make deploy-hooks    # Deploy hooks scripts + merge hooks.json into ~/.claude/settings.json
make list-hooks      # List deployed hook scripts
```

## Initial Setup

If this is a fresh clone, or you're migrating from the old `~/.claude/agents/` layout:

```bash
# If ~/.claude/agents/ is a real directory (not a symlink), remove it first:
rm -rf ~/.claude/agents

# Create canonical location + symlinks for Claude Code and opencode
make setup

# Deploy everything
make deploy
```

After setup, `~/.claude/agents` and `~/.config/opencode/agents` are both symlinks to `~/.agents/`. Running `make deploy-agents` updates both tools at once.

## Architecture

This repo manages two types of Claude Code extensions: **skills** (slash commands loaded into the main conversation) and **agents** (isolated subagents with their own context windows).

```
skills/global/<name>/SKILL.md   ← one file per skill
agents/<name>.md                ← one file per agent
hooks/scripts/<name>.sh         ← one file per hook script
hooks/hooks.json                ← hook event → handler definitions
categories.json                 ← category name → model mapping
```

`make deploy` rsyncs skills to three destinations, agents to one canonical location, and hooks to `~/.claude/`:
- `~/.claude/skills/` — Claude Code (skills)
- `~/.gemini/skills/` — Gemini CLI (skills)
- `~/.config/eca/skills/` — ECA (skills)
- `~/.agents/` — canonical agents location (symlinked from `~/.claude/agents/` and `~/.config/opencode/agents/`)
- `~/.claude/hooks/` — hook scripts; `hooks.json` merged into `~/.claude/settings.json`

Run `make setup` once after cloning to create the symlinks.

### Skills vs Agents

| | Skills | Agents |
|---|---|---|
| **What** | Instructions loaded into your conversation | Isolated worker with its own context window |
| **Best for** | Workflows, checklists, orchestration | File-heavy tasks that shouldn't bloat main context |
| **Writes artifacts** | Yes | No — returns findings only |
| **Invocation** | `/skill-name` | Automatic (by description) or "use the X agent" |

### Model-Agnostic Memory Store

Skills and agents can save and retrieve persistent memories that survive across sessions
and work with any model (Claude, Gemini, opencode, etc.).

Two storage locations:
- `~/.agents/memory/` — global memories (user preferences, cross-project feedback)
- `./agents/memory/` — project-scoped memories (project goals, decisions, context)

Each location has a compact `MEMORY.md` index (~50–150 tokens) that skills load to assess
relevance, followed by full `.md` files loaded on-demand for matching entries. The index
format is one line per entry: `- [Name](slug.md) \`#tags\` — one-line hook`.

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

### Skills and Their Purpose

| Skill        | Invocation                                  | Use case                                                                  |
|--------------|---------------------------------------------|---------------------------------------------------------------------------|
| `adr`        | `/adr [decision]`                           | Record an architecture decision with context, rationale, and alternatives |
| `branch`     | `/branch TICKET`                            | Create feature branch, sync deps, show plan summary                       |
| `check`      | `/check`                                    | Lint + type check + tests (auto-detects stack)                            |
| `experiment` | `/experiment`                               | Capture ML experiment results into artifact for `/report`                 |
| `gitlab`     | `/gitlab`                                   | MRs, pipelines, issues via `glab`                                         |
| `hotfix`     | `/hotfix [TICKET] desc`                     | Streamlined branch → fix → check → ship for urgent changes                |
| `forget`     | `/forget <name>`                            | Remove a memory from the model-agnostic store (global or project)         |
| `learn`      | `/learn [rule]`                             | Capture a session correction into CLAUDE.md or .agents/conventions.md     |
| `memories`   | `/memories [--global\|--project\|--type t]` | Browse the memory store index without loading full content                |
| `new-memory` | `/new-memory [text]`                        | Save a memory to the model-agnostic store (global or project)             |
| `recall`     | `/recall <query>`                           | Search the memory store by keyword or tag and return full content         |
| `plan`       | `/plan TICKET`                              | Type-aware implementation plan → Jira comment                             |
| `refine`     | `/refine [TICKET]`                          | Interactively refine a Jira ticket                                        |
| `report`     | `/report`                                   | Publish ML experiment report to Confluence                                |
| `review`     | `/review`                                   | Severity-grouped code review vs main                                      |
| `ship`       | `/ship`                                     | Gate on review → check → commit → push → MR                               |
| `standup`    | `/standup [range]`                          | Progress summary from git, MRs, Jira                                      |
| `status`     | `/status`                                   | Session bootstrap — show state and recommend next step                    |
| `test`       | `/test`                                     | Generate tests from plan AC + diff                                        |
| `tidy`       | `/tidy`                                     | Clean up stale artifacts from completed tickets                           |

### Adding a New Skill
1. Create `skills/global/<name>/SKILL.md` with the skill instructions
2. Run `make lint-skills` to validate frontmatter
3. Run `make deploy` to push it to all destinations

### Agents and Their Purpose

| Agent | Use case |
|---|---|
| `code-reviewer` | Deep isolated review of own branch diff — called by `/review` or standalone |
| `explorer` | Fast read-only codebase reconnaissance — where is X, find files, trace data flow |
| `experiment-analyzer` | Analyze ML experiment artifacts vs plan thresholds before `/report` |
| `fixer` | Fast bounded implementation for scoped tasks — tests, stub implementations, diffs |
| `pipeline-validator` | Check artifact chain integrity (staleness, TBDs, missing artifacts) before /ship |
| `pr-reviewer` | Review an incoming teammate MR via `glab` (distinct from self-review) |
| `ticket-analyzer` | Surface requirements gaps and risks in a Jira ticket before `/plan` |
| `verifier` | Check that a produced artifact faithfully answers its source document |

### Adding a New Agent
1. Create `agents/<name>.md` with YAML frontmatter (`name`, `description`, `model`) and a system prompt
2. Add tool access fields (shared by Claude Code and opencode via `permission:`):
   - `mode: subagent`
   - `permission: {edit: deny, bash: allow, webfetch: deny}` (adjust per tool access needed)
   - Do not use `tools:` — opencode rejects the Claude Code string format for that field
3. Optionally add `category:` to reference a model from `categories.json`
4. Run `make lint-agents` to validate frontmatter
5. Run `make deploy-agents` to push to `~/.agents/` (both Claude Code and opencode pick it up via symlinks)

### Hooks

Hooks are shell scripts that fire at Claude Code lifecycle events. This repo deploys hooks to `~/.claude/hooks/` and merges their config into `~/.claude/settings.json`.

| Hook Script | Event | Purpose |
|-------------|-------|---------|
| `compaction-todo-preserver.sh` | `PreCompact` | Saves TODO state before context compaction |
| `post-compact-todo-restore.sh` | `PostCompact` | Restores TODO state after compaction |
| `write-existing-file-guard.sh` | `PreToolUse` (Write) | Warns when writing to existing files |
| `auto-lint-on-edit.sh` | `PostToolUse` (Write/Edit) | Runs lint on edited JS/TS files |
| `session-context-loader.sh` | `SessionStart` (resume) | Loads session context on resume (impl-progress, memory, codemap state) |

Deploy: `make deploy-hooks`. List: `make list-hooks`. Pull: `make pull-hooks`.

### Agent Categories

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

The `make deploy-agents` target runs `resolve-agents` first to swap `category:` for the resolved `model:`.
