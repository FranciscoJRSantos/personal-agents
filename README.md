# personal-agents

Research-backed agent skills and subagents for software engineering and ML research workflows. Each skill is a slash command that runs inside Claude Code or OpenCode.

## Workflows

**Ticket-based development:**
```
/refine TICKET → /plan TICKET → /branch TICKET → /implement → /check → /review → /ship
```

**ML research cycle:**
```
/refine TICKET → /plan TICKET → train → /experiment → /report
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
make deploy   # sync skills and agents to all destinations
```

`make deploy` rsyncs `skills/global/` to `~/.claude/skills/`, `~/.gemini/skills/`, and `~/.config/eca/skills/`. Agents are synced to `~/.agents/` (symlinked from `~/.claude/agents/` and `~/.config/opencode/agents/`).

---

## Skills

| Skill                | Invocation                    | Purpose                                                                 | Workflow    |
|----------------------|-------------------------------|-------------------------------------------------------------------------|-------------|
| `/adr`               | `/adr [decision]`             | Record architecture decisions with context, rationale, and alternatives | Any         |
| `/branch`            | `/branch TICKET`              | Create branch, sync deps, surface existing plan                         | Ticket      |
| `/check`             | `/check`                      | Lint + type check + tests (auto-detects stack)                          | Ticket      |
| `/experiment`        | `/experiment`                 | Capture ML experiment results into artifact for `/report`               | ML          |
| `/experiment-review` | `/experiment-review [run-id]` | Pull W&B runs, display metrics, append to EXPERIMENTS.md                | ML          |
| `/gitlab`            | `/gitlab`                     | MRs, pipelines, issues via `glab`                                       | Ticket      |
| `/hotfix`            | `/hotfix [TICKET] desc`       | Streamlined branch → fix → check → ship for urgent changes              | Ticket      |
| `/implement`         | `/implement`                  | Staged implementation with hard gates between 5 phases                  | Ticket      |
| `/learn`             | `/learn [rule]`               | Capture a session correction into CLAUDE.md or .agents/conventions.md   | Any         |
| `/plan`              | `/plan TICKET`                | Generate type-aware implementation plan → Jira comment                  | Ticket / ML |
| `/refine`            | `/refine [TICKET]`            | Refine a Jira ticket interactively                                      | Ticket / ML |
| `/report`            | `/report`                     | Publish ML experiment report to Confluence                              | ML          |
| `/review`            | `/review`                     | Severity-grouped code review vs main                                    | Ticket      |
| `/ship`              | `/ship`                       | Gate on review → check → commit → push → MR                             | Ticket      |
| `/standup`           | `/standup [range]`            | Progress summary from git, MRs, Jira                                    | Any         |
| `/status`            | `/status`                     | Show current state and recommend the next workflow step                 | Any         |
| `/test`              | `/test`                       | Generate tests from plan acceptance criteria + diff                     | Ticket      |
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

## External Tools

Skills call these CLI tools when available. Install them separately.

| Tool                 | Used by                           | Purpose                               |
|----------------------|-----------------------------------|---------------------------------------|
| `glab`               | `/gitlab`, `/ship`, `pr-reviewer` | GitLab CLI for MRs and pipelines      |
| `acli`               | `/plan`, `/refine`, `/report`     | Atlassian CLI for Jira and Confluence |
| `uv` / `poetry`      | `/branch`, `/check`               | Python dependency sync                |
| `wandb` (Python SDK) | `/experiment-review`              | W&B run metrics                       |

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
