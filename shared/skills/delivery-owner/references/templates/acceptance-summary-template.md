# acceptance-summary.md

## 交付范围
- Feature: {名称}
- PRD: {路径}
- Plan: {路径}
- Task 数: N（完成: M，BLOCKED: K）

> 签收前必须逐 Task 回看 `proving_command` 和 `evidence_target`：确认执行阶段已经 fresh 重跑真实验证命令、保留完整输出，并把证据回填到约定位置。不得用 Mock 验收替代真实完成证据。

## Kickoff 状态
- kickoff_status: {READY, WAIVED, BLOCKED}
- preflight_evidence_ref: {phase_dir/preflight-evidence.md#...}
- environment_ready: {yes, no}
- dependency_ready: {yes, no}
- risk_owner_ready: {yes, no}
- qa_handoff_ready: {yes, no}
- readiness_waiver: {无 / PMW-XXX + 原因}

## Task 执行进度
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Task | 预标复杂度 | 实际复杂度 | 预期轮次 | 实际轮次 | 状态 |
|------|-----------|-----------|---------|---------|------|

## AC 验收状态
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| UNIT | test_ref 来源 | 聚合来源 | AC 总数 | 通过 | 失败 | 覆盖率 |
|------|--------------|----------|---------|------|------|--------|
| UNIT-1 | TC-U1-001, TC-U1-002 | qa-report.md#qa_a-unit-1 | 2 | 2 | 0 | 100% |

## 前置约束验收状态
> 逐条核对 PRD `前置约束` 与 Plan `PRD 前置约束映射`，确认 constraint 对象已按 `preflight_ref → test_ref / 验收证据` 完成闭环。
> 若 PRD 已显式声明 `无前置约束（经评估）`，本章节可不填写数据行；建议在备注或签收记录中补一句“无前置约束（经评估）”。

<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Constraint ID | 类型 | Plan 状态 | preflight_ref | test_ref | 验收结果 | 证据 | 备注 |
|---------------|------|-----------|---------------|----------|----------|------|------|
| CON-001 | [env/runtime/shared-service/compliance/rollout/preflight] | {MAPPED, VERIFIED} <!-- HOOK-CONTRACT:ENUM 填 MAPPED, VERIFIED 之一 --> | [PF-001 / design.md#preflight-1] | [TC-U1-001 / N/A] | {OK, ISSUE, N/A} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> | [QA_A / qa-report.md#constraint-CON-001] | [未通过时说明原因] |

Plan 状态枚举：
- MAPPED: plan 已建立 Task / preflight / 验收证据映射，但 acceptance 仍需核对结果
- VERIFIED: plan 阶段已标记存在可复用证据，acceptance 需核对证据是否仍成立

> `BLOCKED` 必须在 plan / 执行阶段先被消解，禁止进入 acceptance-summary 的正式签收表。

验收结果枚举：
- OK: 已按计划验证通过
- ISSUE: 未满足、证据不足或前提未满足，阻断签收
- N/A: 本次交付范围不涉及，需在备注说明原因

> 签收前必须确认：每个 Constraint ID 都能从 PRD 行项追溯到 Plan 映射，再追溯到本表证据。任何断链都按 ISSUE 处理。

## 质量门禁
> 仅汇总强门禁阶段；可选增强 `REVIEW_C` 不进入此表。

<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| 门禁 | 状态 |
|------|------|
| TDD 证据 | {PASS, FAIL} <!-- HOOK-CONTRACT:ENUM 填 PASS, FAIL 之一 --> |
| Code Review (REVIEW_A) | {OK, ISSUE} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE 之一 --> |
| Code Review (REVIEW_B) | {OK, ISSUE, N/A} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> |
| QA_A (AC 验收) | {OK, ISSUE} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE 之一 --> |
| QA_B (E2E 旅程) | {OK, ISSUE, N/A} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> |
| QA_C (回归验证) | {OK, ISSUE, N/A} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> |
| QA_D (探索性测试) | {OK, ISSUE, N/A} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> |
| 全量测试 | {PASS, FAIL} <!-- HOOK-CONTRACT:ENUM 填 PASS, FAIL 之一 --> |

## 汇总代理引用
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Agent | 汇总文件 | 字段引用位 | 证据锚点引用位 | 重入规则 | 汇总状态 |
|------|----------|-----------|----------------|----------|----------|
| Status Synthesis Agent | `delivery-status-summary.md` | `输入边界` / `当前判断` / `未决项` / `禁止越权项` | `dev-report.md#...` / `qa-report.md#...` | `BLOCKED` 计入并行数；重试不重复计数；replan 跨批次重新计数 | {N/A, TRIGGERED, STALE} |
| Evidence Synthesis Agent | `evidence-summary.md` | `输入边界` / `当前判断` / `证据锚点` / `未决项` / `禁止越权项` | `dev-report.md#...` / `code-review-report.md#...` / `qa-report.md#...` / `acceptance-summary.md#...` | 仅允许在 Status Synthesis Agent 结束或停止后进入；旧 summary 可标记 `STALE`，且仅允许重跑 `1` 次 | {N/A, TRIGGERED, STALE} |

## 发布建议对齐
- qa_report_release_recommendation: {放行, 条件放行, 阻塞}
- acceptance_release_recommendation: {放行, 条件放行, 阻塞}
- residual_risk: {引用 qa-report.md 的残余风险摘要}

## 目标闭环
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| 目标 | success_standard | evidence | result | remaining_gap |
|------|------------------|----------|--------|---------------|
| {brief 成功标准 / phase goal / delivery value} | {什么算达成} | {dev/qa/constraint evidence} | {已达成, 部分达成, 未达成} | {无 / 待补项} |

> 签收建立在目标闭环之上，不是只看门禁为绿。`qa` 只给放行建议，不替代用户接受风险。
> 每一行必须能回链到 `brief.md#目标与成功标准` 或 `phase-{N}/prd.md#阶段目标`，且 `evidence` 必须引用带锚点的证据来源。
> `brief.md` 与 `phase-{N}/prd.md` 中的每个上游目标都必须在本表出现，不允许只挑部分目标签收。

## 已知问题
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Issue ID | 来源 | 描述 | 严重度 | 处置 |
|----------|------|------|--------|------|
| QAR-001 | QA | [来自 qa-report.md 的问题摘要] | [S1/S2/S3] | [修复 / 豁免 / 条件放行控制] |

## 豁免（如有）
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Waiver ID | 检查项 | 关联 Issue | 到期时间 |
|-----------|--------|-----------|---------|

## 签收记录
- 签收状态: {确认, 拒绝, 待签收} <!-- HOOK-CONTRACT:ENUM 填 确认, 拒绝, 待签收 之一 -->
- 签收人: {user}
- 签收时间: {ISO 8601}
- 备注: {如有拒绝原因或附加条件}

> `签收时间` 必须晚于最新的 `proving_command_executed_at`、`TEST_EXECUTED_AT`，且若本 Phase 存在 `fix-N.md`，必须晚于最近一次修复工件。
