GLOBAL_SKILLS     := skills/global
CLAUDE_DIR        ?= $(HOME)/.claude/skills
GEMINI_DIR        ?= $(HOME)/.gemini/skills
ECA_DIR           ?= $(HOME)/.config/eca/skills

AGENTS_SRC        := agents
CLAUDE_AGENTS_DIR ?= $(HOME)/.claude/agents

.PHONY: deploy deploy-claude deploy-gemini deploy-eca deploy-agents deploy-projects pull pull-claude pull-eca pull-agents pull-projects deploy-dry list-skills lint-skills list-agents lint-agents

## Deploy everything
deploy: deploy-claude deploy-gemini deploy-eca deploy-agents

## Global skills → ~/.claude/skills/
deploy-claude:
	rsync -av --delete $(GLOBAL_SKILLS)/ $(CLAUDE_DIR)/

## Global skills → ~/.gemini/skills/ (same source — unified)
deploy-gemini:
	rsync -av --delete $(GLOBAL_SKILLS)/ $(GEMINI_DIR)/

## Global skills → ~/.config/eca/skills/
deploy-eca:
	rsync -av --delete $(GLOBAL_SKILLS)/ $(ECA_DIR)/

## Agents → ~/.claude/agents/ (Claude Code only — Gemini/ECA don't use this format)
deploy-agents:
	mkdir -p $(CLAUDE_AGENTS_DIR)
	rsync -av --delete $(AGENTS_SRC)/ $(CLAUDE_AGENTS_DIR)/

## Pull local changes back into the repository
pull: pull-claude pull-eca pull-agents

## ~/.claude/skills/ → Global skills
pull-claude:
	rsync -av $(CLAUDE_DIR)/ $(GLOBAL_SKILLS)/

## ~/.config/eca/skills/ → Global skills
pull-eca:
	rsync -av $(ECA_DIR)/ $(GLOBAL_SKILLS)/

## ~/.claude/agents/ → agents/
pull-agents:
	rsync -av $(CLAUDE_AGENTS_DIR)/ $(AGENTS_SRC)/

## Dry run — shows what deploy would do without writing anything
deploy-dry:
	@echo "=== claude ===" && rsync -avn --delete $(GLOBAL_SKILLS)/ $(CLAUDE_DIR)/
	@echo "=== gemini ===" && rsync -avn --delete $(GLOBAL_SKILLS)/ $(GEMINI_DIR)/
	@echo "=== eca ===" && rsync -avn --delete $(GLOBAL_SKILLS)/ $(ECA_DIR)/

## List all skills by group
list-skills:
	@echo "Global ($(shell ls $(GLOBAL_SKILLS) | wc -l) skills):" && ls $(GLOBAL_SKILLS)/

## List all agents
list-agents:
	@echo "Agents ($(shell ls $(AGENTS_SRC) | wc -l)):" && ls $(AGENTS_SRC)/

## Validate agent .md files before deploying
lint-agents:
	@ok=true; \
	for f in $(AGENTS_SRC)/*.md; do \
		agent=$$(basename "$$f" .md); \
		if ! head -1 "$$f" | grep -q '^---$$'; then \
			echo "FAIL  $$agent: missing YAML frontmatter (no opening ---)"; \
			ok=false; \
			continue; \
		fi; \
		fm=$$(sed -n '2,/^---$$/p' "$$f"); \
		if ! echo "$$fm" | grep -q '^name:'; then \
			echo "FAIL  $$agent: frontmatter missing 'name:' field"; \
			ok=false; \
		fi; \
		if ! echo "$$fm" | grep -q '^description:'; then \
			echo "FAIL  $$agent: frontmatter missing 'description:' field"; \
			ok=false; \
		fi; \
		if echo "$$fm" | grep -q '^name:' && echo "$$fm" | grep -q '^description:'; then \
			echo "OK    $$agent"; \
		fi; \
	done; \
	$$ok

## Validate SKILL.md files before deploying
lint-skills:
	@ok=true; \
	for dir in $(GLOBAL_SKILLS)/*/; do \
		skill=$$(basename "$$dir"); \
		file="$$dir/SKILL.md"; \
		if [ ! -f "$$file" ]; then \
			echo "FAIL  $$skill: missing SKILL.md"; \
			ok=false; \
			continue; \
		fi; \
		if ! head -1 "$$file" | grep -q '^---$$'; then \
			echo "FAIL  $$skill: missing YAML frontmatter (no opening ---)"; \
			ok=false; \
			continue; \
		fi; \
		fm=$$(sed -n '2,/^---$$/p' "$$file"); \
		if ! echo "$$fm" | grep -q '^name:'; then \
			echo "FAIL  $$skill: frontmatter missing 'name:' field"; \
			ok=false; \
		fi; \
		if ! echo "$$fm" | grep -q '^description:'; then \
			echo "FAIL  $$skill: frontmatter missing 'description:' field"; \
			ok=false; \
		fi; \
		if echo "$$fm" | grep -q '^name:' && echo "$$fm" | grep -q '^description:'; then \
			echo "OK    $$skill"; \
		fi; \
	done; \
	$$ok
