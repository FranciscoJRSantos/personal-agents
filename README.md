# personal-agents

Research-backed agent skills and subagents for software engineering and ML research workflows. Each skill is a slash command that runs inside Claude Code or OpenCode.

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
make setup    # one-time: create ~/.agents/ and symlink Claude Code + OpenCode to it
make deploy   # sync skills, agents, and hooks to all destinations
```

`make deploy` rsyncs `skills/global/` to `~/.claude/skills/` and `~/.gemini/skills/`. Agents are synced to `~/.agents/` (symlinked from `~/.claude/agents/` and `~/.config/opencode/agents/`). Hooks are deployed to `~/.claude/hooks/` and merged into `~/.claude/settings.json`.

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
| `/learn`             | `/learn [rule]`               | Capture a session correction into CLAUDE.md or .agents/conventions.md   | Any         |
| `/adr`               | `/adr [decision]`             | Record architecture decisions with context, rationale, and alternatives | Any         |
| `/standup`           | `/standup [range]`            | Progress summary from git, MRs, Jira                                    | Any         |
| `/status`            | `/status`                     | Show current state and recommend the next workflow step                 | Any         |
| `/tidy`              | `/tidy`                       | Clean up stale artifacts from completed tickets                         | Any         |

---

## Agents

Agents run in isolated context windows and return findings only — they do not write artifacts.

| Agent                 | Trigger                                        | Purpose                                              |
|-----------------------|------------------------------------------------|------------------------------------------------------|
| `code-reviewer`       | `/review` (large diffs), "deep review"         | Isolated code review of own branch diff              |
| `experiment-analyzer` | "analyze experiment results", before `/report` | Validate ML metrics against plan thresholds          |
| `pipeline-validator`  | "validate pipeline", "ready to ship?"          | Check artifact chain integrity before `/ship`        |
| `pr-reviewer`         | "review !123", "review teammate's MR"          | Review incoming MRs from teammates via `glab`        |
| `ticket-analyzer`     | "analyze this ticket", before `/plan`          | Surface requirements gaps and risks in a Jira ticket |
| `verifier`            | "verify this artifact", "check plan quality"   | Check that an artifact faithfully answers its source |

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

## Hooks

Hooks are shell scripts that fire at Claude Code lifecycle events. They live in `hooks/scripts/` and are deployed to `~/.claude/hooks/`. Their event configuration is merged into `~/.claude/settings.json` on `make deploy-hooks`.

| Hook | Event | Purpose |
|------|-------|---------|
| `compaction-todo-preserver.sh` | `PreCompact` | Saves in-progress TODO/impl state before context compaction |
| `post-compact-todo-restore.sh` | `PostCompact` | Restores saved state after compaction so work isn't lost |
| `write-existing-file-guard.sh` | `PreToolUse` (Write) | Warns when a Write targets an already-existing file |
| `auto-lint-on-edit.sh` | `PostToolUse` (Write/Edit) | Runs project linter on edited JS/TS files |
| `session-context-loader.sh` | `SessionStart` (resume) | Injects impl-progress context when a session resumes |

```bash
make deploy-hooks   # deploy scripts + merge config into ~/.claude/settings.json
make list-hooks     # list deployed hook scripts
make pull-hooks     # pull changes back from ~/.claude/hooks/ into the repo
```

---

## Agent Categories

`categories.json` defines named model presets. Agents can opt into a preset via `category:` in their frontmatter; `make deploy-agents` resolves it to a concrete `model:` before syncing.

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

To reroute all agents to a different model tier, update `categories.json` and re-run `make deploy-agents`. `make lint-agents` validates that every `category:` value exists in `categories.json`.

---

## External Tools

Skills call these CLI tools when available. Install them separately.

| Tool                 | Used by                           | Purpose                               |
|----------------------|-----------------------------------|---------------------------------------|
| `glab`               | `/gitlab`, `/ship`, `pr-reviewer` | GitLab CLI for MRs and pipelines      |
| `acli`               | `/plan`, `/refine`, `/report`     | Atlassian CLI for Jira and Confluence |
| `uv` / `poetry`      | `/branch`, `/check`               | Python dependency sync                |
| `wandb` (Python SDK) | `/experiment-review`              | W&B run metrics                       |
| `yq`                 | `make deploy-agents`              | YAML frontmatter parsing/resolution   |

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
