GLOBAL_SKILLS     := skills/global
CLAUDE_DIR        ?= $(HOME)/.claude/skills
GEMINI_DIR        ?= $(HOME)/.gemini/skills

HOOKS_SCRIPTS    := hooks/scripts
HOOKS_CONFIG     := hooks/hooks.json
CLAUDE_HOOKS_DIR ?= $(HOME)/.claude/hooks
CLAUDE_SETTINGS  ?= $(HOME)/.claude/settings.json

AGENTS_SRC           := agents
AGENTS_PARTIALS      := agents/partials
AGENTS_DIR           ?= $(HOME)/.agents
CLAUDE_AGENTS_LINK   ?= $(HOME)/.claude/agents
OPENCODE_AGENTS_LINK ?= $(HOME)/.config/opencode/agents

CATEGORIES_FILE      := categories.json

.PHONY: deploy deploy-claude deploy-gemini deploy-agents deploy-hooks deploy-projects pull pull-claude pull-agents pull-hooks pull-projects deploy-dry list-skills lint-skills list-agents lint-agents list-hooks setup

## Deploy everything
deploy: deploy-claude deploy-gemini deploy-agents deploy-hooks

## Global skills → ~/.claude/skills/
deploy-claude:
	rsync -av --delete $(GLOBAL_SKILLS)/ $(CLAUDE_DIR)/

## Global skills → ~/.gemini/skills/ (same source — unified)
deploy-gemini:
	rsync -av --delete $(GLOBAL_SKILLS)/ $(GEMINI_DIR)/

## Agents → ~/.agents/ (canonical); Claude Code + opencode read via symlinks (run 'make setup' first)
deploy-agents:
	@echo "Deploying agents to $(AGENTS_DIR)..."
	mkdir -p $(AGENTS_DIR)
	rsync -av --delete $(AGENTS_SRC)/ $(AGENTS_DIR)/
	@if [ -f "$(CATEGORIES_FILE)" ]; then \
		echo "Resolving agent categories in $(AGENTS_DIR)..."; \
		for f in $$(find $(AGENTS_DIR) -name "*.md"); do \
			[ -e "$$f" ] || continue; \
			fm=$$(sed -n '1,/^---$$/p' "$$f" 2>/dev/null); \
			[ -n "$$fm" ] || continue; \
			if ! echo "$$fm" | grep -q "^---$$"; then continue; fi; \
			agent=$$(basename "$$f" .md); \
			category=$$(echo "$$fm" | yq eval 'select(di==0) | .category // ""' | grep -v '^null$$' | head -1); \
			if [ -n "$$category" ] && [ "$$category" != '""' ]; then \
				model=$$(jq -r '.["'"$$category"'"].model // empty' "$(CATEGORIES_FILE)"); \
				if [ -n "$$model" ]; then \
					echo "  $$agent: category=$$category → model=$$model"; \
					sed -i 's|^category:.*|model: '"$$model"'|' "$$f"; \
				else \
					echo "WARN  $$agent: category '$$category' not found in categories.json"; \
				fi \
			fi \
		done; \
	fi

## Pull local changes back into the repository

pull: pull-claude pull-agents pull-hooks

## ~/.claude/skills/ → Global skills
pull-claude:
	rsync -av $(CLAUDE_DIR)/ $(GLOBAL_SKILLS)/

## ~/.agents/ → agents/
pull-agents:
	rsync -av $(AGENTS_DIR)/ $(AGENTS_SRC)/

## Dry run — shows what deploy would do without writing anything
deploy-dry:
	@echo "=== claude ===" && rsync -avn --delete $(GLOBAL_SKILLS)/ $(CLAUDE_DIR)/
	@echo "=== gemini ===" && rsync -avn --delete $(GLOBAL_SKILLS)/ $(GEMINI_DIR)/
	@echo "=== agents ===" && rsync -avn --delete $(AGENTS_SRC)/ $(AGENTS_DIR)/

## ~/.claude/hooks/ → hooks/scripts/
pull-hooks:
	rsync -av $(CLAUDE_HOOKS_DIR)/ $(HOOKS_SCRIPTS)/

## List all deployed hooks
list-hooks:
	@echo "Hook scripts ($(shell ls $(CLAUDE_HOOKS_DIR)/*.sh 2>/dev/null | wc -l)):" && ls $(CLAUDE_HOOKS_DIR)/*.sh 2>/dev/null || echo "(not deployed — run make deploy-hooks)"
list-skills:
	@echo "Global ($(shell ls $(GLOBAL_SKILLS) | wc -l) skills):" && ls $(GLOBAL_SKILLS)/

## List all agents
list-agents:
	@echo "Agents ($(shell ls $(AGENTS_DIR) 2>/dev/null | wc -l)):" && ls $(AGENTS_DIR)/ 2>/dev/null || echo "(not deployed — run make setup && make deploy-agents)"

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
		fm=$$(sed -n '1,/^---$$/p' "$$f"); \
		name=$$(echo "$$fm" | yq eval 'select(di==0) | .name // ""' | grep -v '^null$$' | head -1); \
		description=$$(echo "$$fm" | yq eval 'select(di==0) | .description // ""' | grep -v '^null$$' | head -1); \
		if [ -z "$$name" ] || [ "$$name" = '""' ]; then \
			echo "FAIL  $$agent: frontmatter missing 'name:' field"; \
			ok=false; \
		fi; \
		if [ -z "$$description" ] || [ "$$description" = '""' ]; then \
			echo "FAIL  $$agent: frontmatter missing 'description:' field"; \
			ok=false; \
		fi; \
		if ! echo "$$fm" | yq eval -e 'select(di==0) | .permission' >/dev/null 2>&1; then \
			echo "WARN  $$agent: missing 'permission:' block (needed for opencode)"; \
		fi; \
		category=$$(echo "$$fm" | yq eval 'select(di==0) | .category // ""' | grep -v '^null$$' | head -1); \
		if [ -n "$$category" ] && [ "$$category" != '""' ]; then \
			if ! jq -e '.["'"$$category"'"]' "$(CATEGORIES_FILE)" >/dev/null 2>&1; then \
				echo "WARN  $$agent: category '$$category' not defined in categories.json"; \
			fi \
		fi; \
		if [ -n "$$name" ] && [ "$$name" != '""' ] && [ -n "$$description" ] && [ "$$description" != '""' ]; then \
			echo "OK    $$agent"; \
		fi \
	done; \
	$$ok


## One-time setup: create ~/.agents/ and symlink Claude Code + opencode to it
setup:
	@echo "=== Setting up canonical agents directory ==="
	mkdir -p $(AGENTS_DIR)
	@echo "Created $(AGENTS_DIR)"
	@if [ -L $(CLAUDE_AGENTS_LINK) ] && [ "$$(readlink $(CLAUDE_AGENTS_LINK))" = "$(AGENTS_DIR)" ]; then \
		echo "OK    $(CLAUDE_AGENTS_LINK) → $(AGENTS_DIR) (already correct)"; \
	elif [ -e $(CLAUDE_AGENTS_LINK) ] && [ ! -L $(CLAUDE_AGENTS_LINK) ]; then \
		echo "WARN  $(CLAUDE_AGENTS_LINK) exists and is not a symlink — remove it first (see CLAUDE.md)"; \
	else \
		ln -sfn $(AGENTS_DIR) $(CLAUDE_AGENTS_LINK) && \
		echo "LINK  $(CLAUDE_AGENTS_LINK) → $(AGENTS_DIR)"; \
	fi
	@mkdir -p $(HOME)/.config/opencode
	@if [ -L $(OPENCODE_AGENTS_LINK) ] && [ "$$(readlink $(OPENCODE_AGENTS_LINK))" = "$(AGENTS_DIR)" ]; then \
		echo "OK    $(OPENCODE_AGENTS_LINK) → $(AGENTS_DIR) (already correct)"; \
	elif [ -e $(OPENCODE_AGENTS_LINK) ] && [ ! -L $(OPENCODE_AGENTS_LINK) ]; then \
		echo "WARN  $(OPENCODE_AGENTS_LINK) exists and is not a symlink — remove it first (see CLAUDE.md)"; \
	else \
		ln -sfn $(AGENTS_DIR) $(OPENCODE_AGENTS_LINK) && \
		echo "LINK  $(OPENCODE_AGENTS_LINK) → $(AGENTS_DIR)"; \
	fi
	@echo "=== Done. Run 'make deploy-agents' to populate ~/.agents/ ==="

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
