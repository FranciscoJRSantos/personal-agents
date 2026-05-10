GLOBAL_SKILLS      := skills/global

AGENTS_SRC         := agents
AGENTS_PARTIALS    := agents/partials
AGENTS_DIR         ?= $(HOME)/.agents

OPENCODE_SKILLS_DIR ?= $(HOME)/.config/opencode/skills
OPENCODE_AGENTS_DIR  ?= $(HOME)/.config/opencode/agents

CATEGORIES_FILE     := categories.json

.PHONY: deploy deploy-opencode deploy-agents pull pull-skills pull-agents setup setup-opencode list-skills lint-skills list-agents lint-agents lint-docs

## Deploy everything to OpenCode
deploy: deploy-opencode deploy-agents

## Skills → ~/.config/opencode/skills/ + Agents → ~/.config/opencode/agents/
deploy-opencode: setup-opencode
	@echo "Deploying skills to $(OPENCODE_SKILLS_DIR)..."
	mkdir -p $(OPENCODE_SKILLS_DIR)
	rsync -av --delete $(GLOBAL_SKILLS)/ $(OPENCODE_SKILLS_DIR)/
	@echo "Deploying agents to $(OPENCODE_AGENTS_DIR)..."
	@scripts/deploy-agents.sh "$(AGENTS_SRC)" "$(OPENCODE_AGENTS_DIR)" "$(CATEGORIES_FILE)" --md-only

## Agents → ~/.agents/ (canonical, includes partials and memory)
deploy-agents:
	@scripts/deploy-agents.sh "$(AGENTS_SRC)" "$(AGENTS_DIR)" "$(CATEGORIES_FILE)"

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
		description=$$(echo "$$fm" | yq eval 'select(di==0) | .description // ""' | grep -v '^null$$' | head -1); \
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
		if [ -n "$$description" ] && [ "$$description" != '""' ]; then \
			echo "OK    $$agent"; \
		fi \
	done; \
	$$ok

## Check AGENTS.md references match real skills and agents
lint-docs:
	@ok=true; \
	echo "=== Checking skill references in AGENTS.md ==="; \
	for ref in $$(grep -oP '\x60/\K[^/\x60 ,]+' AGENTS.md 2>/dev/null | sort -u); do \
		case "$$ref" in skill-name|agent-name|TICKET|RUN|slug|type|query|range|name|decision|rule) continue ;; esac; \
		if [ ! -f "$(GLOBAL_SKILLS)/$$ref/SKILL.md" ]; then \
			echo "FAIL  skill '$$ref' referenced in AGENTS.md but skills/global/$$ref/SKILL.md not found"; \
			ok=false; \
		else \
			echo "OK    /$$ref"; \
		fi \
	done; \
	echo ""; \
	echo "=== Checking agent references in AGENTS.md ==="; \
	for f in $(AGENTS_SRC)/*.md; do \
		agent=$$(basename "$$f" .md); \
		if grep -qF "\`$$agent\`" AGENTS.md; then \
			echo "OK    $$agent"; \
		else \
			echo "INFO  $$agent not referenced in AGENTS.md"; \
		fi \
	done; \
	echo ""; \
	echo "=== Checking artifact chain integrity ==="; \
	grep -oP '\x60<TICKET>-[^\x60]+\x60\s*\|\s*\x60/\w+' AGENTS.md 2>/dev/null \
	| sed 's/\x60//g' \
	| while IFS='|' read -r artifact written_by; do \
		artifact=$$(echo "$$artifact" | xargs); \
		written_by=$$(echo "$$written_by" | xargs | cut -d' ' -f1 | tr -d '/'); \
		skill_file="$(GLOBAL_SKILLS)/$$written_by/SKILL.md"; \
		if [ ! -f "$$skill_file" ]; then \
			echo "FAIL  artifact '$$artifact' written by '$$written_by' but skill not found at $$skill_file"; \
			ok=false; \
		else \
			echo "OK    $$artifact ← /$$written_by"; \
		fi \
	done; \
	echo ""; \
	$$ok
