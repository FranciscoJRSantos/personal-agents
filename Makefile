GLOBAL_SKILLS      := skills

AGENTS_SRC         := agents
AGENTS_DIR         ?= $(HOME)/.agents

OPENCODE_SKILLS_DIR ?= $(HOME)/.config/opencode/skills
OPENCODE_AGENTS_DIR  ?= $(HOME)/.config/opencode/agents

CLAUDE_SKILLS_DIR  ?= $(HOME)/.claude/skills

## Local global rules (gitignored). Template: global/AGENTS.md.example
GLOBAL_AGENTS_SRC   := global/AGENTS.md
GLOBAL_AGENTS_DEST  ?= $(HOME)/.config/opencode/AGENTS.md

## Set DRY_RUN=1 to preview what deploy/drift would change (rsync --dry-run).
DRY_RUN ?=
ifeq ($(DRY_RUN),1)
RSYNC_DRY := --dry-run
else
RSYNC_DRY :=
endif

.PHONY: deploy deploy-skills deploy-agents deploy-global drift lint lint-skills lint-agents lint-docs test list-skills list-agents

## Deploy everything to OpenCode and Claude Code (skills, agents, global rules).
## Each target dir keeps a .personal-agents-manifest; only listed items are touched.
deploy: deploy-skills deploy-agents deploy-global

## Skills → ~/.config/opencode/skills/ and ~/.claude/skills/ (agents untouched).
## Use this to ship skill changes without clobbering live agents with a stale repo.
deploy-skills:
	@echo "Deploying skills to $(OPENCODE_SKILLS_DIR)..."
	@DRY_RUN=$(DRY_RUN) scripts/manifest-sync.sh "$(OPENCODE_SKILLS_DIR)" $(GLOBAL_SKILLS)/*/
	@echo "Deploying skills to $(CLAUDE_SKILLS_DIR)..."
	@DRY_RUN=$(DRY_RUN) scripts/manifest-sync.sh "$(CLAUDE_SKILLS_DIR)" $(GLOBAL_SKILLS)/*/

## Agents → ~/.config/opencode/agents/ (md only) and ~/.agents/ (md + partials/).
deploy-agents:
	@echo "Deploying agents to $(OPENCODE_AGENTS_DIR)..."
	@DRY_RUN=$(DRY_RUN) scripts/deploy-agents.sh "$(AGENTS_SRC)" "$(OPENCODE_AGENTS_DIR)" --md-only
	@echo "Deploying agents to $(AGENTS_DIR)..."
	@DRY_RUN=$(DRY_RUN) scripts/deploy-agents.sh "$(AGENTS_SRC)" "$(AGENTS_DIR)"

## Global rules → ~/.config/opencode/AGENTS.md
## The source file is gitignored; skips with a warning when it is absent.
deploy-global:
	@if [ ! -f "$(GLOBAL_AGENTS_SRC)" ]; then \
		echo "WARN  $(GLOBAL_AGENTS_SRC) not found — skipping (create it from global/AGENTS.md.example)"; \
	else \
		echo "Deploying global rules to $(GLOBAL_AGENTS_DEST)..."; \
		mkdir -p "$$(dirname "$(GLOBAL_AGENTS_DEST)")"; \
		rsync -av $(RSYNC_DRY) "$(GLOBAL_AGENTS_SRC)" "$(GLOBAL_AGENTS_DEST)"; \
	fi

## Read-only check: diff the repo against every deployed location. Never copies.
drift:
	@status=0; \
	DRY_RUN=$(DRY_RUN) scripts/manifest-sync.sh --drift "$(OPENCODE_SKILLS_DIR)" $(GLOBAL_SKILLS)/*/ || status=1; \
	DRY_RUN=$(DRY_RUN) scripts/manifest-sync.sh --drift "$(CLAUDE_SKILLS_DIR)" $(GLOBAL_SKILLS)/*/ || status=1; \
	DRY_RUN=$(DRY_RUN) scripts/deploy-agents.sh --drift "$(AGENTS_SRC)" "$(OPENCODE_AGENTS_DIR)" --md-only || status=1; \
	DRY_RUN=$(DRY_RUN) scripts/deploy-agents.sh --drift "$(AGENTS_SRC)" "$(AGENTS_DIR)" || status=1; \
	if [ ! -f "$(GLOBAL_AGENTS_SRC)" ]; then \
		echo "INFO  $(GLOBAL_AGENTS_SRC) not found — skipping global rules drift"; \
	elif [ ! -f "$(GLOBAL_AGENTS_DEST)" ]; then \
		echo "DIFF  global rules: $(GLOBAL_AGENTS_DEST) not found"; \
		status=1; \
	elif diff -q "$(GLOBAL_AGENTS_SRC)" "$(GLOBAL_AGENTS_DEST)" >/dev/null; then \
		echo "OK    global rules"; \
	else \
		echo "DIFF  global rules"; \
		status=1; \
	fi; \
	exit $$status

## List all skills
list-skills:
	@echo "Custom ($(shell ls $(GLOBAL_SKILLS) 2>/dev/null | wc -l) skills):" && ls $(GLOBAL_SKILLS)/ 2>/dev/null || echo "(no skills)"

## List all agents
list-agents:
	@echo "Agents ($(shell ls $(AGENTS_SRC)/*.md 2>/dev/null | wc -l)):" && ls $(AGENTS_SRC)/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null || echo "(no agents)"

## Run the converter unit tests (pytest from mise python)
test:
	python3 -m pytest -q tests/

## Validate skills, agents and docs, then run the tests
lint: lint-skills lint-agents lint-docs test

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
	echo ""; \
	echo "=== Checking shared codemap state-hash snippet ==="; \
	tmp=$$(mktemp -d); \
	sed -n '/codemap-state-hash:begin/,/codemap-state-hash:end/p' "$(GLOBAL_SKILLS)/codemap/SKILL.md" > "$$tmp/skill"; \
	sed -n '/codemap-state-hash:begin/,/codemap-state-hash:end/p' "$(AGENTS_SRC)/observer.md" > "$$tmp/agent"; \
	if [ ! -s "$$tmp/skill" ] || [ ! -s "$$tmp/agent" ]; then \
		echo "FAIL  codemap state-hash snippet missing in /codemap or @observer"; \
		ok=false; \
	elif diff -q "$$tmp/skill" "$$tmp/agent" >/dev/null; then \
		echo "OK    codemap state-hash snippet identical"; \
	else \
		echo "FAIL  codemap state-hash snippet differs between /codemap and @observer"; \
		ok=false; \
	fi; \
	rm -rf "$$tmp"; \
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
