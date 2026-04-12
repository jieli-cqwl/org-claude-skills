# Tasks — QA/Test v2 Best-Practice Rebuild
Created: 2026-04-11
Related plan: ./plan.md

> Scope baseline: use the approved conversation direction from 2026-04-11 as the implementation spec for this rebuild. This work is a system rewrite of the `test-design -> qa -> delivery-owner Phase 3` chain, not a patch pass.

## Acceptance Checklist
- [x] T1 Unify authority map, terminology, and artifact ownership
  - AC: `contracts/skill-chain.yaml`, `test-design`, `qa`, `delivery-owner`, and `phase3-dispatch` define one meaning for `Phase`, `UNIT`, `unit_work_dir`, `phase_dir`, `test-cases.md`, and `qa-report.md`.
  - AC: `qa-report.md` has one authoritative location and one authoritative template source.
  - AC: `test_cases_ref` is a required QA input everywhere the QA agent is dispatched.
- [x] T2 Rebuild the `test-design -> qa` handoff contract
  - AC: `test-cases.md` explicitly states which test obligations are required in QA, which are conditionally triggered, and which may be skipped only with a reason.
  - AC: handoff coverage includes smoke, AC/function, API/interface, E2E, regression, exploratory, UX, recovery, and NFR-triggered execution.
  - AC: `test-design` completion check blocks incomplete handoff contracts.
- [x] T3 Rebuild the QA execution model into explicit stage responsibilities
  - AC: `QA_A` explicitly covers smoke + AC/function + API/interface + design/MOD constraint acceptance.
  - AC: `QA_B` explicitly covers end-to-end journeys + exception recovery + UX checkpoints.
  - AC: `QA_C` explicitly covers regression and impacted-surface verification.
  - AC: `QA_D` explicitly covers exploratory testing with risk charters.
  - AC: NFR-triggered obligations from `test-cases.md` must be executed or marked with `not_executed_reason`.
- [x] T4 Rebuild the defect model and release-decision model
  - AC: `qa-report.md` records `severity`, `priority`, `impact_scope`, `user_impact`, `residual_risk`, `release_recommendation`, and `not_executed_reason` where applicable.
  - AC: every `QAR-*` issue can flow from `qa-report.md` into `acceptance-summary.md` without lossy translation.
  - AC: `waivers.md` references `QAR-*` issues and compensating controls consistently.
- [x] T5 Upgrade automation gates and contract tests from format checks to decision-quality checks
  - AC: `qa` completion check validates grade-to-stage matrix, authoritative report location, required handoff input, required defect fields, allowed release recommendation enums, and reasons for `N/A` / skipped obligations.
  - AC: `delivery-owner` completion check validates `acceptance-summary.md` against `qa-report.md` issue ledger and release recommendation.
  - AC: shell contract tests cover both passing and failing cases for the new rules.
- [x] T6 Add a quality rubric and historical replay validation set
  - AC: a rubric document scores the rebuilt chain on role boundary, single source of truth, test-type explicitness, defect model, release model, engineering consistency, and readability.
  - AC: a replay document defines 3-5 historical or representative escaped-defect scenarios and the expected QA/Test v2 outcome.
  - AC: rollout is blocked until the rebuilt chain passes the rubric target and replay checks.

## Definition of Done
All tasks checked, shell contract tests green, and the replay/rubric package shows QA/Test v2 is ready for pilot use.
