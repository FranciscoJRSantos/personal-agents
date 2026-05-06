GLOBAL_SKILLS      := skills/global

AGENTS_SRC         := agents
AGENTS_PARTIALS    := agents/partials
AGENTS_DIR         ?= $(HOME)/.agents

OPENCODE_SKILLS_DIR ?= $(HOME)/.config/opencode/skills
OPENCODE_AGENTS_DIR  ?= $(HOME)/.config/opencode/agents

CATEGORIES_FILE     := categories.json

.PHONY: deploy deploy-opencode deploy-agents pull pull-skills pull-agents setup setup-opencode list-skills lint-skills list-agents lint-agents

## Deploy everything to OpenCode
deploy: deploy-opencode deploy-agents

## Skills → ~/.config/opencode/skills/ + Agents → ~/.config/opencode/agents/
deploy-opencode: setup-opencode
	@echo "Deploying skills to $(OPENCODE_SKILLS_DIR)..."
	mkdir -p $(OPENCODE_SKILLS_DIR)
	rsync -av --delete $(GLOBAL_SKILLS)/ $(OPENCODE_SKILLS_DIR)/
	@echo "Deploying agents to $(OPENCODE_AGENTS_DIR)..."
	rsync -av --delete --include='*.md' --exclude='*' $(AGENTS_SRC)/ $(OPENCODE_AGENTS_DIR)/
	@if [ -f "$(CATEGORIES_FILE)" ]; then \
		echo "Resolving agent categories in $(OPENCODE_AGENTS_DIR)..."; \
		for f in $$(find $(OPENCODE_AGENTS_DIR) -name "*.md" 2>/dev/null); do \
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

## Agents → ~/.agents/ (canonical, includes partials and memory)
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

## Pull changes back from deployed locations
pull: pull-skills pull-agents

## ~/.config/opencode/skills/ → skills/global/
pull-skills:
	rsync -av $(OPENCODE_SKILLS_DIR)/ $(GLOBAL_SKILLS)/

## ~/.agents/ → agents/
pull-agents:
	rsync -av $(AGENTS_DIR)/ $(AGENTS_SRC)/

## One-time setup: create ~/.agents/ and ~/.config/opencode/ directories
setup:
	@echo "=== Setting up canonical agents directory ==="
	mkdir -p $(AGENTS_DIR)
	@echo "Created $(AGENTS_DIR)"
	@$(MAKE) setup-opencode
	@echo "=== Done. Run 'make deploy' to populate. ==="

## One-time setup: create ~/.config/opencode/agents/ and ~/.config/opencode/skills/
setup-opencode:
	mkdir -p $(OPENCODE_AGENTS_DIR)
	mkdir -p $(OPENCODE_SKILLS_DIR)
	@echo "Created $(OPENCODE_AGENTS_DIR)"
	@echo "Created $(OPENCODE_SKILLS_DIR)"

## List all skills
list-skills:
	@echo "Global ($(shell ls $(GLOBAL_SKILLS) 2>/dev/null | wc -l) skills):" && ls $(GLOBAL_SKILLS)/ 2>/dev/null || echo "(no skills)"

## List all agents
list-agents:
	@echo "Agents ($(shell ls $(AGENTS_SRC)/*.md 2>/dev/null | wc -l)):" && ls $(AGENTS_SRC)/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null || echo "(no agents)"

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
