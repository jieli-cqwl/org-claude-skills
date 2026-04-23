# 签收证据闭环合同

Trigger: Use when delivery-owner prepares sign-off readiness, builds `signoff-package.json`, renders `acceptance-summary.md`, or evaluates user sign-off and business risk acceptance.
Read: `brief.json`, `phase-prd.json`, `plan.json`, `tasks.json`, `delivery-state.json`, `artifact-registry.json`, `developer-report.json`, `verify-result.json`, `code-review-result.json`, `qa-result.json`, `consistency-auditor` advisory evidence, and `signoff-package.json`.
Expect: Sign-off uses current canonical runtime evidence, proves AC and goal closure, maps constraints from upstream source to plan and evidence, carries residual risk explicitly, and records user authority.
Consume: `delivery-owner` sign-off flow, readiness validator, `acceptance-summary.md` projection, `user-decision.json`, and delivery maintainers consume this contract.
Evidence: `tests/test-delivery-owner-source-anchor-contract.sh`, `tests/test-delivery-owner-gate-contract.sh`, `tests/test-delivery-owner-contract-closure.sh`, and `tests/test-standard-chain-readiness-gate.sh` cover the sign-off contract.
Sync: Update this file with `SKILL.md` sign-off flow, `delivery-gate-dispatch.md`, `acceptance-summary-template.md`, canonical runtime schemas, and readiness validator changes.

## Evidence Freshness

- Every Task included in sign-off must have current `developer-report.json` and `verify-result.json` evidence.
- The sign-off decision must be later than the latest proving command, full test run, fix artifact, review result, QA result, and consistency-auditor advisory report consumed by the current Phase.
- `last_observed_at` records the latest runtime observation used for sign-off; stale observations block sign-off.

## Constraint Closure

- Every PRD `CON-*` constraint in the current Phase must map from source requirement to `plan.json` and then to sign-off evidence.
- A constraint with missing source, missing plan mapping, missing `preflight_ref`, missing `test_ref`, missing evidence, or stale evidence is an `ISSUE`.
- `BLOCKED` constraints must be resolved before formal sign-off; unresolved blockers produce `BLOCK / ESCALATE`, not a signed package.
- If the upstream PRD explicitly declares no constraints after evaluation, the sign-off evidence records that evaluated empty state.

## Gate Closure

- Fixed full delivery gates are non-optional: `REVIEW_A + REVIEW_B + REVIEW_C + QA_A + QA_B + QA_C + QA_D`.
- `code-review-result.json` owns review conclusions; `qa-result.json` owns QA conclusions; `delivery-owner` only consumes those results for control decisions.
- Summary agents and consistency-auditor reports are advisory evidence. They cannot replace review, QA, user sign-off, or business risk acceptance.

## Goal Closure

- Every upstream business goal, Phase goal, and delivery value in scope must appear in `signoff-package.json.goal_closure`.
- Each goal closure row must include `goal_source_ref`, `execution_basis_ref`, `evidence_ref`, `result`, and `remaining_gap`.
- `goal_source_ref` must point to canonical brief or phase-prd anchors; `execution_basis_ref` must point to design, plan, tasks, or test-cases anchors.
- UNIT-level evidence refs must use Phase-resolvable artifact paths and stable anchors.

## Risk Acceptance

- `residual_risk / waiver` must have a stable issue id, impact scope, compensation control, expiry or review condition, and user confirmation evidence.
- Fixed full gate stages cannot be waived as a whole. Only single residual risks or waiver records can be accepted by the user.
- `qa` can recommend release status, but user authority owns sign-off and business risk acceptance.

## Projection Boundary

- `acceptance-summary.md` is a human projection of canonical sign-off evidence.
- The template carries structure, field names, enum placeholders, and evidence anchors only.
- Sign-off rules live in this contract and canonical validators, not in the template body.
