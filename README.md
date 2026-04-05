# personal-agents

Agent skills for software engineering and ML research workflows. Each skill is a slash command that runs inside Claude Code or Open Code

## Workflows

**Ticket-based development:**
```
/branch TICKET → implement → /check → /review → /test → /ship
```

**ML research cycle:**
```
/refine TICKET → /plan TICKET → train → /report
```

---

## Setup

```bash
git clone <repo>
make deploy
```

`make deploy` rsyncs `skills/global/` to `~/.claude/skills/`, `~/.gemini/skills/`, and `~/.config/eca/skills/`. Skills are immediately available as slash commands in Claude Code.

---

## Skills

| Skill     | Invocation           | Purpose                                    | Workflow    |
|-----------|----------------------|--------------------------------------------|-------------|
| `/branch` | `/branch PROJ-123`   | Create branch, sync deps, load plan        | Ticket      |
| `/refine` | `/refine [PROJ-123]` | Refine Jira ticket interactively           | Ticket / ML |
| `/plan`   | `/plan PROJ-123`     | Generate type-aware implementation plan    | Ticket / ML |
| `/review` | `/review`            | Severity-grouped code review vs main       | Ticket      |
| `/check`  | `/check`             | Run lint, type check, and tests            | Ticket      |
| `/test`   | `/test`              | Generate tests from plan + diff            | Ticket      |
| `/ship`   | `/ship`              | Commit, push, and create GitLab MR         | Ticket      |
| `/gitlab` | `/gitlab`            | MRs, pipelines, issues via `glab`          | Ticket      |
| `/report` | `/report`            | Publish ML experiment report to Confluence | ML          |

---

## Common Patterns

**Pre-commit review hook** (`.git/hooks/pre-commit`):
```bash
#!/bin/sh
git diff --cached | reviewer
```

**CI review step:**
```bash
git diff main...HEAD | reviewer
```

**Check before shipping:**
```bash
# In Claude Code
/check
/review
/ship
```

---

## External Tools

Skills call these CLI tools when available. Install them separately.

| Tool            | Used by                       | Purpose                                   |
|-----------------|-------------------------------|-------------------------------------------|
| `glab`          | `/gitlab`, `/ship`            | GitLab CLI for MRs and pipelines          |
| `acli`          | `/plan`, `/refine`, `/report` | Atlassian CLI for Jira and Confluence     |
| `uv` / `poetry` | `/branch`, `/check`           | Python dependency sync                    |

---

## Artifact Chain

Skills pass context to each other via `.claude/artifacts/`:

| Artifact                  | Written by | Read by                                |
|---------------------------|------------|----------------------------------------|
| `<TICKET>-ticket.md`      | `/refine`  | `/plan`                                |
| `<TICKET>-plan.md`        | `/plan`    | `/branch`, `/review`, `/test`, `/ship` |
| `<TICKET>-review-impl.md` | `/review`  | `/ship`                                |
| `<TICKET>-tests.md`       | `/test`    | —                                      |
