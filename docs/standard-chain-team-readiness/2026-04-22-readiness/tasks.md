# Tasks - Standard-Chain Team Readiness
Created: 2026-04-22
Related plan: ./plan.md

## Acceptance Checklist

- [x] T1 Align the small-chain workset and evidence baseline
  - AC: `docs/standard-chain-team-readiness/worklog.md` points to `2026-04-22-readiness/design.md`, `docs/standard-chain-team-readiness/2026-04-22-readiness/design.md` exists, and `docs/standard-chain-team-readiness-20260422/design.md` no longer exists.
  - AC: `docs/standard-chain-team-readiness/2026-04-22-readiness/evidence-baseline.md` records repo commit, branch, review time, review object list, executor, and dirty-worktree note.
  - Traces: 证明试点准备度; 证明职责清晰; 证明上下文低噪音; 证明 handoff 可消费
  - Depends: -
  - Complexity: simple
- [x] T2 Collect deterministic gate evidence
  - AC: `docs/standard-chain-team-readiness/2026-04-22-readiness/deterministic-gate-evidence.md` records command, cwd, exit code, key output, and PASS/BLOCKED status for each required deterministic gate named in `design.md`.
  - AC: If a gate fails, the report names the failing command, observed output, suspected owner, and whether the failure is related to this readiness work or pre-existing worktree changes.
  - Traces: 证明试点准备度; 证明 handoff 可消费
  - Depends: T1
  - Complexity: moderate
- [x] T3 Produce skill-harness audit and noise report
  - AC: `docs/standard-chain-team-readiness/2026-04-22-readiness/skill-harness-audit.md` covers 10 main skills and 2 sidecars with structured findings using `overall_verdict`, `dimension`, `dimension_result`, `finding_severity`, `file:line`, `evidence`, `impact`, `recommendation`, `audit_proof_type`, `proof_command`, and `gate_type`.
  - AC: `docs/standard-chain-team-readiness/2026-04-22-readiness/noise-context-budget.md` classifies S1/S2/S3 noise, includes evidence lines, and states whether S1/S2 noise blocks controlled pilot readiness.
  - Traces: 证明试点准备度; 证明职责清晰; 证明上下文低噪音; 证明 handoff 可消费
  - Depends: T1
  - Complexity: complex
- [ ] T4 Produce role capability scenario report
  - AC: `docs/standard-chain-team-readiness/2026-04-22-readiness/role-capability-report.md` covers `product-director`, `product-manager`, `design`, `test-design`, `tech-lead`, `developer`, `review`, `verify`, `qa`, `delivery-owner`, `fix`, and `consistency-audit`.
  - AC: Each role has one positive scenario and one failure or overreach scenario with PASS/FAIL/COMMENT, evidence source, and reason; any scenario that requires a human to supply professional role judgment is marked FAIL.
  - Traces: 证明试点准备度; 证明职责清晰; 证明 handoff 可消费; 证明完整交付能力
  - Depends: T1,T3
  - Complexity: complex
- [ ] T5 Produce readiness summary and pilot decision
  - AC: `docs/standard-chain-team-readiness/2026-04-22-readiness/readiness-summary.md` aggregates deterministic gates, skill-harness audit, noise report, role capability results, residual risks, and a final decision of `GO for controlled pilot`, `FIX before pilot`, or `NO-GO`.
  - AC: The summary states that complete team delivery capability is not claimed until a real low-risk demand runs end-to-end from `product-director` to `delivery-owner`.
  - Traces: 证明试点准备度; 证明职责清晰; 证明上下文低噪音; 证明 handoff 可消费; 证明完整交付能力
  - Depends: T2,T3,T4
  - Complexity: moderate
- [ ] T6 Verify and close the small-chain workset
  - AC: `python3 tools/community/check_task_plan_consistency.py docs/standard-chain-team-readiness/2026-04-22-readiness/tasks.md docs/standard-chain-team-readiness/2026-04-22-readiness/plan.md` passes.
  - AC: Placeholder scan over `design.md`, `tasks.md`, `plan.md`, and readiness reports returns no unresolved placeholder tokens.
  - AC: `docs/standard-chain-team-readiness/worklog.md` has a latest entry pointing to `readiness-summary.md` and reflecting the final PASS/BLOCKED status.
  - Traces: 证明试点准备度; 证明职责清晰; 证明上下文低噪音; 证明 handoff 可消费; 证明完整交付能力
  - Depends: T5
  - Complexity: simple

## Definition of Done

All tasks checked = ready for verify-change.
