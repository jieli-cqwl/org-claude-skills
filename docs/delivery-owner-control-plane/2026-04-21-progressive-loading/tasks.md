# Tasks — Delivery Owner Progressive Loading
Created: 2026-04-21
Related plan: ./plan.md

## Acceptance Checklist

- [x] T1 Lock the new contract with RED tests
  - AC: `tests/test-delivery-owner-phase3-contract.sh` fails against current HEAD because it expects fixed full Phase 3 gates, no grade-driven trimming, no dynamic escalation section, no expert SOP in `dispatch-guide.md`, no `Edit` in `delivery-owner` frontmatter, and no `审查分级` / metadata `grade` in review or QA templates.
  - Traces: 主入口降噪; 完整流程固定; 派发合同聚焦; 专家边界清晰; 下游同步
  - Depends: -
  - Complexity: moderate

- [x] T2 Refactor delivery-owner runtime documents to control-plane contracts
  - AC: `shared/skills/delivery-owner/SKILL.md`, `references/dispatch-guide.md`, and `references/phase3-dispatch.md` express only control-plane routing, handoff contracts, fixed full gate behavior, and evidence boundaries; they do not inline grade matrices, dynamic escalation mappings, runtime field tables, or expert execution SOP.
  - Traces: 主入口降噪; 完整流程固定; 派发合同聚焦; 专家边界清晰
  - Depends: T1
  - Complexity: complex

- [x] T3 Align templates, helper, manifest, and legacy gates
  - AC: `phase3-grade-matrix.sh` keeps the old file and function names but returns fixed full gates for legacy grade inputs; manifest names it as a fixed full-gate helper; legacy completion checks no longer require grade matching; code-review and QA templates no longer expose `审查分级` or metadata `grade`; `delivery-owner` frontmatter has no `Edit`.
  - Traces: 完整流程固定; 专家边界清晰; 下游同步
  - Depends: T1
  - Complexity: complex

- [x] T4 Update downstream tests, graders, replay, rollout, and archive stale role docs
  - AC: delivery-owner phase3, replay, rollout, and standard-chain behavior tests no longer assert grade trimming or dynamic escalation wording; `tools/eval/graders/task-constraint-grader.md` checks full-gate evidence chain instead of grade fit; stale `docs/delivery-owner-role-20260411/` material is moved under `docs/archive/` or its test-critical content is copied into fixtures before removal.
  - Traces: 下游同步
  - Depends: T2, T3
  - Complexity: complex

- [x] T5 Verify the complete small-chain delivery
  - AC: fresh proving commands pass: `bash tests/test-delivery-owner-phase3-contract.sh`, `bash tests/test-delivery-owner-replay-contract.sh`, `bash tests/test-delivery-owner-rollout-gate.sh`, `bash tests/test-standard-chain-skill-structure.sh`, `bash tests/test-skill-output-and-gate-contract.sh`, and `git diff --check`.
  - Traces: 主入口降噪; 完整流程固定; 派发合同聚焦; 专家边界清晰; 下游同步
  - Depends: T1, T2, T3, T4
  - Complexity: moderate

## Definition of Done

All tasks checked = ready for final verification report.
