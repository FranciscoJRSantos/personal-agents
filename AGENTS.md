# Agents Guide: personal-agents

## Quick Start
```bash
git clone <repo>
make deploy   # Deploys all skills to ~/.claude/skills/, ~/.gemini/skills/, ~/.config/eca/skills/
```

## Architecture

Skills are markdown files that Claude Code interprets as slash commands. Each skill lives at:

```
skills/global/<name>/SKILL.md
```

When invoked, a skill runs inside Claude Code. It can call external CLI tools (`glab`, `acli`, `reviewer`, etc.) via Bash, read/write files, and chain to other skills via artifacts.

```
User → /skill → Claude Code reads SKILL.md → executes steps → writes .claude/artifacts/
```

## Artifact Chain

Skills pass context to each other through files in `.claude/artifacts/`:

| Artifact | Written by | Read by | Purpose |
|---|---|---|---|
| `<TICKET>-ticket.md` | `/refine` | `/plan` | Avoid re-fetching from Jira |
| `<TICKET>-plan.md` | `/plan` | `/branch`, `/review`, `/test`, `/ship` | Acceptance criteria + implementation steps |
| `<TICKET>-review-impl.md` | `/review` | `/ship` | Gate: `status: clean` or `status: has-findings` |
| `<TICKET>-tests.md` | `/test` | — | Test coverage summary |

## Skills

| Skill | Invocation | What it does |
|---|---|---|
| `branch` | `/branch TICKET` | Create feature branch, sync deps, load plan |
| `check` | `/check` | Run lint + type check + tests (stack-aware) |
| `gitlab` | `/gitlab` | MRs, pipelines, issues via `glab` |
| `plan` | `/plan TICKET` | Type-aware implementation plan → Jira comment + artifact |
| `refine` | `/refine [TICKET]` | Interactively refine a Jira ticket, one topic at a time |
| `report` | `/report` | Publish ML experiment report to Confluence |
| `review` | `/review` | Severity-grouped code review (Critical / Warning / Suggestion) |
| `ship` | `/ship` | Gate on review → check → commit → push → MR |
| `test` | `/test` | Generate tests from plan acceptance criteria + diff |

## Typical Workflow

```
/branch TICKET → implement → /check → /review → /test → /ship
```

## Adding a Skill
1. Create `skills/global/<name>/SKILL.md`
2. Run `make deploy`

## Deployment Targets

| Command | What it does |
|---|---|
| `make deploy` | Sync to Claude, Gemini, and ECA |
| `make deploy-claude` | Sync to `~/.claude/skills/` only |
| `make deploy-gemini` | Sync to `~/.gemini/skills/` only |
| `make deploy-eca` | Sync to `~/.config/eca/skills/` only |
| `make deploy-dry` | Preview changes without writing |
| `make pull` | Pull changes from deployed locations back into repo |
| `make list-skills` | List all global skills |
