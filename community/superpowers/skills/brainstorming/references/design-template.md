# Design Template

Output path: `docs/{feature}/YYYY-MM-DD-{change}/design.md`

> 结构参照：contracts/small-chain.yaml -> brainstorming -> design.md key_fields

## Why
{1-3 sentences: the problem statement, why this change is needed, and what breaks if it is not done}

## Scope
- In scope: {what will be done}
- Out of scope: {what will NOT be done}

## Approach
{Technical description of the chosen solution and how it satisfies the goals}

## Alternatives Considered
| Option | Pros | Cons | Verdict |
|--------|------|------|---------|

## Key Decisions
- D1: {decision} — Reason: {why}

## Goals & Success Criteria
| Goal | Success Criteria | Verification |
|------|------------------|--------------|
| {goal name} | {observable result} | {command, file check, or reviewable evidence} |

## Change Scope
Required for modification work. Use `N/A - {reason}` only for net-new work with no existing artifact to change.

| File or Area | Change Type | Size |
|--------------|-------------|------|
| `{path}` | {create / modify / remove} | {small / medium / large} |

## Invariants
Required for modification work. List existing behavior, contracts, file ownership, or workflow rules that must remain unchanged.

- {invariant}

## Downstream Impact
Required when downstream consumers exist. Use `N/A - {reason}` only when no consumer can observe the change.

| Consumer | Impact | Propagation Needed |
|----------|--------|--------------------|
| {consumer} | {how the consumer sees this change} | {yes / no and why} |

## Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| {risk} | {what can go wrong} | {how the design reduces or exposes it} |
