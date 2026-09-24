GLOBAL_SKILLS      := skills

AGENTS_SRC         := agents
AGENTS_PARTIALS    := agents/partials
AGENTS_DIR         ?= $(HOME)/.agents

OPENCODE_SKILLS_DIR ?= $(HOME)/.config/opencode/skills
OPENCODE_AGENTS_DIR  ?= $(HOME)/.config/opencode/agents

CLAUDE_SKILLS_DIR  ?= $(HOME)/.claude/skills

## Set DRY_RUN=1 to preview what deploy/pull would change (rsync --dry-run).
DRY_RUN ?=
ifeq ($(DRY_RUN),1)
RSYNC_DRY := --dry-run
else
RSYNC_DRY :=
endif

.PHONY: deploy deploy-opencode deploy-claude deploy-agents deploy-skills deploy-skills-opencode pull pull-skills pull-agents pull-claude setup setup-opencode setup-claude list-skills lint-skills list-agents lint-agents lint-docs

## Deploy everything to OpenCode and Claude Code
deploy: deploy-opencode deploy-claude deploy-agents

## Skills → ~/.config/opencode/skills/ + Agents → ~/.config/opencode/agents/
## Reuses deploy-skills-opencode so skill-only changes can ship without touching agents.
deploy-opencode: deploy-skills-opencode
	@echo "Deploying agents to $(OPENCODE_AGENTS_DIR)..."
	@DRY_RUN=$(DRY_RUN) scripts/deploy-agents.sh "$(AGENTS_SRC)" "$(OPENCODE_AGENTS_DIR)" --md-only

## Skills → OpenCode + Claude Code (agents untouched)
## Use this to ship skill changes without clobbering live agents with a stale repo.
deploy-skills: deploy-skills-opencode deploy-claude

## Skills → ~/.config/opencode/skills/ only (agents untouched)
deploy-skills-opencode: setup-opencode
	@echo "Deploying skills to $(OPENCODE_SKILLS_DIR)..."
	mkdir -p $(OPENCODE_SKILLS_DIR)
	rsync -av --delete $(RSYNC_DRY) $(GLOBAL_SKILLS)/ $(OPENCODE_SKILLS_DIR)/

## Skills → ~/.claude/skills/ (Claude Code)
## --delete: mirrors the repo exactly so both harnesses expose identical skills
deploy-claude: setup-claude
	@echo "Deploying skills to $(CLAUDE_SKILLS_DIR)..."
	rsync -av --delete $(RSYNC_DRY) $(GLOBAL_SKILLS)/ $(CLAUDE_SKILLS_DIR)/

## Agents → ~/.agents/ (canonical, includes partials and memory)
deploy-agents:
	@DRY_RUN=$(DRY_RUN) scripts/deploy-agents.sh "$(AGENTS_SRC)" "$(AGENTS_DIR)"

## Pull changes back from deployed locations
pull: pull-skills pull-agents pull-claude

## ~/.config/opencode/skills/ → skills/
pull-skills:
	rsync -av $(RSYNC_DRY) $(OPENCODE_SKILLS_DIR)/ $(GLOBAL_SKILLS)/

## ~/.agents/ → agents/
pull-agents:
	rsync -av $(RSYNC_DRY) $(AGENTS_DIR)/ $(AGENTS_SRC)/

## ~/.claude/skills/ → skills/ (Claude Code edits back to source)
pull-claude:
	rsync -av $(RSYNC_DRY) --exclude='branch' --exclude='gitlab' --exclude='hotfix' \
	          --exclude='standup' --exclude='status' --exclude='test' --exclude='tidy' \
	          $(CLAUDE_SKILLS_DIR)/ $(GLOBAL_SKILLS)/

## One-time setup: create ~/.agents/, ~/.config/opencode/, and ~/.claude/skills/
setup:
	@echo "=== Setting up canonical agents directory ==="
	mkdir -p $(AGENTS_DIR)
	@echo "Created $(AGENTS_DIR)"
	@$(MAKE) setup-opencode
	@$(MAKE) setup-claude
	@echo "=== Done. Run 'make deploy' to populate. ==="

## One-time setup: create ~/.config/opencode/agents/ and ~/.config/opencode/skills/
setup-opencode:
	mkdir -p $(OPENCODE_AGENTS_DIR)
	mkdir -p $(OPENCODE_SKILLS_DIR)
	@echo "Created $(OPENCODE_AGENTS_DIR)"
	@echo "Created $(OPENCODE_SKILLS_DIR)"

## One-time setup: create ~/.claude/skills/
setup-claude:
	mkdir -p $(CLAUDE_SKILLS_DIR)
	@echo "Created $(CLAUDE_SKILLS_DIR)"

## List all skills
list-skills:
	@echo "Custom ($(shell ls $(GLOBAL_SKILLS) 2>/dev/null | wc -l) skills):" && ls $(GLOBAL_SKILLS)/ 2>/dev/null || echo "(no skills)"

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
		perm_count=$$(echo "$$fm" | yq eval 'select(di==0) | .permissions | length' 2>/dev/null | grep -E '^[0-9]+$$' | grep -v '^0$$' | head -1); \
		if [ -z "$$perm_count" ]; then \
			echo "WARN  $$agent: missing 'permissions:' list (needed for opencode v2)"; \
		else \
			bad=$$(echo "$$fm" | yq eval 'select(di==0) | [.permissions[] | select((has("action") | not) or (has("resource") | not) or (has("effect") | not))] | length' 2>/dev/null | grep -E '^[1-9][0-9]*$$' | head -1); \
			if [ -n "$$bad" ]; then \
				echo "FAIL  $$agent: 'permissions' entry missing action/resource/effect"; \
				ok=false; \
			fi; \
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
		case "$$ref" in skill-name|agent-name|TICKET|RUN|slug|type|query|range|name|decision|rule|clear) continue ;; esac; \
		if [ ! -f "$(GLOBAL_SKILLS)/$$ref/SKILL.md" ]; then \
			echo "FAIL  skill '$$ref' referenced in AGENTS.md but $(GLOBAL_SKILLS)/$$ref/SKILL.md not found"; \
			ok=false; \
		else \
			echo "OK    /$$ref"; \
		fi \
	done; \
	echo ""; \
	echo "=== Checking agent references in AGENTS.md ==="; \
	for f in $(AGENTS_SRC)/*.md; do \
		agent=$$(basename "$$f" .md); \
		if grep -qE "\`@?$$agent\`" AGENTS.md; then \
			echo "OK    $$agent"; \
		else \
			echo "INFO  $$agent not referenced in AGENTS.md"; \
		fi \
	done; \
	echo ""; \
	echo "=== Checking skill references in AGENTS.md (strict) ==="; \
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
