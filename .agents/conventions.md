# SpotMe Gym Mode Rules

## Default
SpotMe starts OFF. Activate with `/spotme:on [lite|medium|hard] [--every N]`.

## When to toggle ON
- `/implement` green phase — ON at `medium --every 2`
- Learning a new framework/library — ON at `hard`
- Refactoring familiar code — ON at `lite`
- First slice of a new project — ON at `hard`

## When to keep OFF
- `/implement` red phase (writing tests)
- `/review`, `/check`, `/ship`, `/hotfix` — no implementation happening
- Deadline sprints — throughput over practice

## Session pattern
```
/plan → /clear → /spotme:on medium → /implement → /spotme:off → /check → /review → /ship
```

## Memory Auto-Write Triggers

When implementing (especially inside `/implement` slice work), auto-write memories via `/new-memory` for:
- Environment discoveries (new tool, version mismatch, path quirk, dependency issue)
- User correction to the agent's approach
- Non-obvious dependency or ordering constraint discovered
- Workaround patterns that were non-trivial to find

Auto-write rules via `/learn` for:
- Corrections the user made to command syntax or workflow steps
- Project-specific conventions expressed during the session
