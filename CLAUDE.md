# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make deploy          # Sync skills to ~/.claude/skills/, ~/.gemini/skills/, ~/.config/eca/skills/ + agents to ~/.claude/agents/
make deploy-dry      # Preview what deploy would change without writing
make pull            # Pull changes back from deployed locations into the repo
make list-skills     # List all deployed skills
make lint-skills     # Validate SKILL.md frontmatter before deploying
make deploy-agents   # Sync agents to ~/.claude/agents/ only
make list-agents     # List all agents
make lint-agents     # Validate agent .md frontmatter before deploying
```

## Architecture

This repo manages two types of Claude Code extensions: **skills** (slash commands loaded into the main conversation) and **agents** (isolated subagents with their own context windows).

```
skills/global/<name>/SKILL.md   ← one file per skill
agents/<name>.md                ← one file per agent
```

`make deploy` rsyncs skills to three destinations and agents to one:
- `~/.claude/skills/` — Claude Code (skills)
- `~/.gemini/skills/` — Gemini CLI (skills)
- `~/.config/eca/skills/` — ECA (skills)
- `~/.claude/agents/` — Claude Code only (agents — Gemini/ECA don't use this format)

### Skills vs Agents

| | Skills | Agents |
|---|---|---|
| **What** | Instructions loaded into your conversation | Isolated worker with its own context window |
| **Best for** | Workflows, checklists, orchestration | File-heavy tasks that shouldn't bloat main context |
| **Writes artifacts** | Yes | No — returns findings only |
| **Invocation** | `/skill-name` | Automatic (by description) or "use the X agent" |

### Artifact Chain

Skills write and read files under `.claude/artifacts/` to pass context between steps:

| Artifact | Written by | Read by |
|---|---|---|
| `<TICKET>-ticket.md` | `/refine` | `/plan` |
| `<TICKET>-plan.md` | `/plan` | `/branch`, `/review`, `/test`, `/ship`, `/experiment` |
| `<TICKET>-experiment-<RUN>.md` | `/experiment` | `/report` |
| `<TICKET>-review-impl.md` | `/review` | `/ship` |
| `<TICKET>-tests.md` | `/test` | — |

### Skills and Their Purpose

| Skill | Invocation | Use case |
|---|---|---|
| `branch` | `/branch TICKET` | Create feature branch, sync deps, show plan summary |
| `check` | `/check` | Lint + type check + tests (auto-detects stack) |
| `experiment` | `/experiment` | Capture ML experiment results into artifact for `/report` |
| `gitlab` | `/gitlab` | MRs, pipelines, issues via `glab` |
| `hotfix` | `/hotfix [TICKET] desc` | Streamlined branch → fix → check → ship for urgent changes |
| `plan` | `/plan TICKET` | Type-aware implementation plan → Jira comment |
| `refine` | `/refine [TICKET]` | Interactively refine a Jira ticket |
| `report` | `/report` | Publish ML experiment report to Confluence |
| `review` | `/review` | Severity-grouped code review vs main |
| `ship` | `/ship` | Gate on review → check → commit → push → MR |
| `standup` | `/standup [range]` | Progress summary from git, MRs, Jira |
| `status` | `/status` | Session bootstrap — show state and recommend next step |
| `test` | `/test` | Generate tests from plan AC + diff |
| `tidy` | `/tidy` | Clean up stale artifacts from completed tickets |

### Adding a New Skill
1. Create `skills/global/<name>/SKILL.md` with the skill instructions
2. Run `make lint-skills` to validate frontmatter
3. Run `make deploy` to push it to all destinations

### Agents and Their Purpose

| Agent | Use case |
|---|---|
| `code-reviewer` | Deep isolated review of own branch diff — called by `/review` or standalone |
| `experiment-analyzer` | Analyze ML experiment artifacts vs plan thresholds before `/report` |
| `ticket-analyzer` | Surface requirements gaps and risks in a Jira ticket before `/plan` |
| `pr-reviewer` | Review an incoming teammate MR via `glab` (distinct from self-review) |

### Adding a New Agent
1. Create `agents/<name>.md` with YAML frontmatter (`name`, `description`, `tools`, `model`) and a system prompt
2. Run `make lint-agents` to validate frontmatter
3. Run `make deploy-agents` to push to `~/.claude/agents/`
