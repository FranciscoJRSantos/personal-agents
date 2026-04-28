---
name: vmodel-gap-analysis
type: reference
tags: [vmodel, software-engineering, workflow, methodology]
created: 2026-04-19
updated: 2026-04-19
---

# V-Model Gap Analysis for personal-agents

## Context

Discussion panel on AI + software engineering. Idea: with AI, engineers can finally follow proper engineering disciplines like the V-model.

## Current Workflow Mapping to V-Model

| V-Model Phase | Missing/Gap | Current Skill |
|--------------|------------|---------------|
| Requirements Analysis | Covered | /refine |
| System Design | Partial | /plan |
| Architecture Design | Missing | — |
| Module Design | Covered | /implement (stage 1) |
| ────────────── | ──────── | ──────────────── |
| Unit Testing | Covered | /test |
| Integration Testing | Missing | — |
| System Testing | Partial | /check |
| User Acceptance Testing | Missing | — |

## Key Gaps (Prioritized by Impact)

1. **Test plans written after coding vs. during design** — biggest discipline gap. V-model says test criteria are designed in parallel with spec, not derived post-hoc.

2. **No architecture design phase** — missing module boundaries, interfaces, dependencies documentation.

3. **No integration testing distinction** — collapsed into /check with unit tests.

4. **No UAT** — no user/stakeholder acceptance testing gate.

5. **No traceability matrix** — requirement → design decision → test case mapping exists partially in /test artifact but post-hoc.

## Recommended Improvements

| Change | Effort | Impact |
|--------|--------|--------|
| Add test criteria to /plan output (write during planning) | Low | High |
| Split /plan into system + architecture design | Medium | Medium |
| Add integration test specs for /test | Medium | High |
| Differentiate test levels in /check | Low | Medium |
| Generate traceability matrix artifact | Low | Medium |

## Storage Recommendations

- **Local** (`.agents/artifacts/`): Machine-readable artifacts for skill consumption
- **Jira**: Requirements (already there), acceptance criteria in fields
- **Confluence**: Architecture specs, test plans, traceability matrix

Don't move skill-internal artifacts to external storage — adds friction and risk of workflow breakage.

## Panelist's Insight

"Writing test criteria upfront forces you to think precisely about what 'done' means at each abstraction level" — exactly the kind of work AI does well, overcoming the historical objection to V-model's "expensive" upfront phases.