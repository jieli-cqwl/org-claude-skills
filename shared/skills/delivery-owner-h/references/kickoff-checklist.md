# Delivery Kickoff Checklist

Trigger: Use when delivery-owner enters Phase kickoff before developer dispatch.
Read: `brief.json`, `phase-prd.json`, `units/UNIT-*.json`, `design.json`, `plan.json`, `tasks.json`, `unit-*/test-cases.json`, preflight evidence, and dependency readiness notes.
Expect: The checklist proves artifact alignment, preflight evidence, environment readiness, dependency readiness, risk owner, and QA handoff readiness before delivery starts. Use `bash shared/skills/delivery-owner/scripts/input_readiness_check.sh --phase-dir "$PHASE_DIR"` for deterministic input readiness.
Consume: `delivery-state.json.kickoff`, acceptance-summary kickoff projection, and delivery-owner kickoff blocking decisions consume this checklist.
Evidence: `tests/test-delivery-owner-input-readiness.sh` checks machine-readable kickoff input readiness; `tests/test-delivery-owner-gate-contract.sh` checks this resource contract and downstream kickoff fields in templates and gates.
Sync: Update this file with `SKILL.md` Kickoff, `projections/acceptance-summary-template.md`, and completion gate kickoff validations.

## 必查项

| 项目 | 必填字段 | 通过条件 | 未通过动作 |
|------|----------|----------|-----------|
| 工件对齐 | `brief / phase-prd / unit-definition / design / plan / tasks / unit-*/test-cases` | active registry entry 与 payload 的 `artifact_id / artifact_type` 一致，且 `units/UNIT-*.json` 以 `artifact_type=unit-definition` 纳入 active revision | `BLOCK` |
| 前置约束 | `preflight_evidence_ref` | 每个 `CON-*` 都有验证结果 | `BLOCK` |
| 环境 readiness | `environment_ready` | 真实环境可启动、可验证 | `ESCALATE` |
| 依赖 readiness | `dependency_ready` | 外部依赖可达且可观测 | `ESCALATE` |
| 风险 owner | `risk_owner_ready` | 关键风险有 owner | `BLOCK` |
| QA 交接 | `qa_handoff_ready` | `test_cases_ref` / `execution_mode` / 入口信息齐全 | `BLOCK` |

## 输出

- `kickoff_status: READY | WAIVED | BLOCKED`
- `plan_version_ref`
- `preflight_evidence_ref`
- `environment_ready / dependency_ready / risk_owner_ready / qa_handoff_ready`
- `readiness_waiver`：仅允许结构化记录单项 readiness 风险，必须包含 `waiver_id / owner / reason / compensation_control / expires_at / user_confirmation_ref`
- `blocking_reason`
