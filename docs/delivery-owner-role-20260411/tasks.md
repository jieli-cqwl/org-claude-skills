# Tasks — Delivery Owner Best-Practice Rebuild
Created: 2026-04-11
Related plan: ./plan.md

> Scope baseline: use `role-definition-gap.md` and `design.md` in this directory as the implementation baseline. This work is a chain-level rebuild for `delivery-owner` and its upstream/downstream contracts, not a local wording cleanup.

## Acceptance Checklist
- [x] T1 Freeze the role contract and authority boundaries
  - AC: `delivery-owner`, `tech-lead`, `developer`, `qa`, and chain contracts define one authoritative meaning for “交付目标负责人”, “计划 owner”, “质量判断 owner”, and “风险接受 owner”.
  - AC: the new `delivery-owner` role explicitly includes kickoff, deviation governance, dynamic gate escalation, and goal closure, while explicitly excluding requirement definition, design invention, implementation, and unilateral business risk acceptance.
  - AC: no downstream document or skill contradicts the new authority model.

- [x] T2 Rebuild the delivery kickoff and readiness model
  - AC: execution cannot start unless `brief / prd / design / plan / test-cases` are aligned and readiness evidence is complete.
  - AC: `preflight-evidence` becomes an explicit gate with pass/fail semantics instead of a warning-only reminder.
  - AC: kickoff responsibilities include risk owner alignment, QA handoff readiness, and environment/dependency readiness.

- [x] T3 Rebuild the orchestration and deviation-governance model
  - AC: `delivery-owner` has explicit triggers for complexity drift, interface drift, shared-file expansion, repeated non-convergence, external dependency drift, and blocked-task accumulation.
  - AC: each trigger maps to a required control action: continue, escalate, replan, or block.
  - AC: execution metrics that remain in reports are all tied to concrete governance actions; pure management vanity metrics are removed or demoted.

- [x] T4 Rebuild the dynamic quality-escalation model
  - AC: `plan.md` remains the baseline gate matrix source, but execution-time risk signals can force stronger review/QA coverage.
  - AC: standard-grade execution can be escalated to run additional `QA_B / QA_D` or stronger review when risk rises.
  - AC: fix loops affecting shared logic or cross-UNIT behavior trigger impacted-stage recalculation, not only failed-stage replay.

- [x] T5 Rebuild the evidence and closure model around goal achievement
  - AC: final closure requires a goal-level evidence table mapping `brief` success criteria / phase goals / delivery value to execution and QA evidence.
  - AC: `acceptance-summary.md` records `已达成 / 部分达成 / 未达成` style goal conclusions instead of only gate status.
  - AC: one-source evidence ownership is clear; repeated copying of raw evidence across reports is reduced in favor of authoritative references and spot-checkable links.

- [x] T6 Upgrade templates, scripts, and tests into team-usable gates
  - AC: all MUST behaviors introduced above are enforced by templates, completion checks, and contract tests.
  - AC: negative fixtures exist for readiness failure, missing goal closure, missing escalation after drift, and invalid sign-off on blocked recommendations.
  - AC: the chain can detect contradiction between role definitions, gate expectations, and actual artifacts.

- [x] T7 Define rollout and team-usage readiness standards
  - AC: a quality rubric defines when the rebuilt `delivery-owner` chain is fit for pilot and for wider team rollout.
  - AC: replay scenarios cover at least 3 representative failure modes: readiness failure, execution drift, gate escalation, and goal closure mismatch.
  - AC: rollout is explicitly blocked until rubric threshold and replay expectations are met.

## Definition of Done
All tasks checked, chain contract tests green, replay/rubric gates satisfied, and the rebuilt `delivery-owner` model is ready for controlled team pilot use.
