---
name: update-skill
description: >
  Enforces that all skill and agent edits happen in the source repo, not the deployed
  locations. Use this skill whenever you are asked to edit, update, modify, or create
  a skill or agent, or whenever a direct edit to ~/.claude/skills/, ~/.agents/,
  ~/.gemini/skills/, or ~/.config/eca/skills/ is requested.
  Entry point: /update-skill
---

## Rule

Never edit skills or agents in their deployed locations. Always edit in the canonical
source repo:

  /home/francisco.santos/Documents/personal-projects/active/personal-agents

Editing deployed files directly is unsafe because `make deploy` uses `rsync --delete`,
which will overwrite any changes made outside the repo on the next deploy.

---

## Workflow

**Step 1 — Edit in the repo**

Open the skill or agent file in the source repo:

- Skills: `skills/global/<name>/SKILL.md`
- Agents: `agents/<name>.md`

**Step 2 — Lint**

```bash
make lint-skills   # for skills
make lint-agents   # for agents
```

Fix any frontmatter errors before proceeding.

**Step 3 — Deploy**

```bash
make deploy
```

This syncs all skills and agents to their deployed locations atomically.

---

## Gotchas

- Never edit `~/.claude/skills/`, `~/.agents/`, `~/.gemini/skills/`, or `~/.config/eca/skills/` directly BECAUSE `make deploy` uses `rsync --delete` and will overwrite those changes.
- Always run `make lint-skills` or `make lint-agents` before deploying BECAUSE missing frontmatter fields will fail silently or cause the skill to not load.
