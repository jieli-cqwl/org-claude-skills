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
| D9 | Contract-grade preflight | contract_grade_preflight | Contract-grade design trigger exists | Clear / Partial / Missing / N/A |

## Decision Rules

- D1、D2、D3、D4、D8 不允许 Missing.
- D5、D6、D7 may be N/A only when the design states the reason.
- D9 may be N/A only when the design states no contract-grade trigger exists.
- Partial means the section exists but does not yet give enough information for writing-plans.
- Missing or Partial items must be fixed in `design.md` before handoff.

## Contract-Grade Design Trigger

Run D9 when the design affects any of these:

- source-of-truth, lifecycle state, status, or handoff recovery
- schema, ref grammar, enums, field ownership, or canonical artifact contracts
- hooks, validators, CI gates, audit, or other mechanical enforcement
- migration/cutover between current and target contracts
- multi-agent, multi-feature, or cross-window continuation boundaries

## D9 Contract-Grade Preflight

When D9 applies, the design must explicitly answer all eight checks. Clear means writing-plans can create tasks without inventing policy.

| # | Check | Required Answer |
|---|-------|-----------------|
| C1 | Current vs Target | Current HEAD contract and target Phase contract are separated; migration phase and cutover owner are explicit. |
| C2 | Source of Truth Matrix | Each status, progress, decision, and handoff fact has one authoritative artifact; conflict priority is explicit. |
| C3 | Closed Vocabulary / Grammar | Field names, enums, ref grammar, output shape, and failure shape are closed enough for a validator. |
| C4 | Ownership / Waiver | Each key artifact has owner, writer, update trigger, waiver approver, and mechanical check. |
| C5 | Failure Contract | Blocked recovery returns a fixed failure structure and forbids guessing from non-managed history. |
| C6 | Implementation Surface | Allowed file surface and cutover order are concrete; pilot artifacts are included when required. |
| C7 | Proving Categories | Each success criterion maps to a command, fixture, hook, validator, or reviewable evidence. |
| C8 | Existing Contract Diff | README, contracts, skills, hooks, and tests that already govern the area are checked for conflicts. |

If any C-check is Partial or Missing, fix `design.md` before asking for user approval or entering writing-plans.
