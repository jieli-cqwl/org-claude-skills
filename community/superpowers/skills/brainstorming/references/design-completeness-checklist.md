# Design Completeness Checklist

Contract source: `contracts/small-chain.yaml -> brainstorming -> design.md key_fields`

## Usage

Run this checklist during brainstorming spec self-review. Mark each item Clear, Partial, Missing, or N/A. Partial and Missing items must be fixed inline before writing-plans. D5, D6, and D7 may be N/A only with a concrete reason.

## Checks

| # | Dimension | key_field | Required when | Status |
|---|-----------|-----------|---------------|--------|
| D1 | Problem statement | problem_statement | Always | Clear / Partial / Missing |
| D2 | Goals and success criteria | goals_success_criteria | Always | Clear / Partial / Missing |
| D3 | Approach | approach | Always | Clear / Partial / Missing |
| D4 | Alternatives considered | alternatives_considered | Always | Clear / Partial / Missing |
| D5 | Change scope | change_scope | Modification work | Clear / Partial / Missing / N/A |
| D6 | Invariants | invariants | Modification work | Clear / Partial / Missing / N/A |
| D7 | Downstream impact | downstream_impact | Downstream consumers exist | Clear / Partial / Missing / N/A |
| D8 | Risks | risks | Always | Clear / Partial / Missing |

## Decision Rules

- D1、D2、D3、D4、D8 不允许 Missing.
- D5、D6、D7 may be N/A only when the design states the reason.
- Partial means the section exists but does not yet give enough information for writing-plans.
- Missing or Partial items must be fixed in `design.md` before handoff.
