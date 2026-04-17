# acceptance-summary.md

## 交付范围
- Feature: {名称}
- PRD: {路径}
- Plan: {路径}
- Task 数: N（完成: M，BLOCKED: K）

> 签收前必须逐 Task 回看 `proving_command` 和 `evidence_target`：确认执行阶段已经 fresh 重跑真实验证命令、保留完整输出，并把证据回填到约定位置。不得用 Mock 验收替代真实完成证据。

## Kickoff 状态
- kickoff_status: {READY, WAIVED, BLOCKED}
- plan_version_ref: {artifact://plan/{feature}.phase-{N}.plan@plan-vX#plan-version}
- preflight_evidence_ref: {artifact://design/{feature}.phase-{N}.design@vX#preflight-1 / artifact://evidence/{feature}.phase-{N}.preflight@ev-X#preflight-root}
- environment_ready: {yes, no}
- dependency_ready: {yes, no}
- risk_owner_ready: {yes, no}
- qa_handoff_ready: {yes, no}
- readiness_waiver: {无 / PMW-XXX + 原因}

## 最新状态摘要
- last_observed_at: {ISO 8601}
- runtime_snapshot: {最近一次执行状态、门禁状态与风险摘要}
- active_blocker: {无 / 当前阻塞摘要}
- blocker_owner: {无 / developer / fix / qa / tech-lead / user / delivery-owner}
- takeover_note: {无（主 Agent 持续跟进） / 最近一次接手说明}
- decision_basis: {至少包含一个当前锚点引用，如 artifact://developer-report/{feature}.phase-{N}.unit-{N}.task-{task_id}.developer-report@vX#tdd-evidence-index + artifact://qa-result/{feature}.phase-{N}.qa@vX#release}
- current_plan_version_ref: {artifact://plan/{feature}.phase-{N}.plan@plan-vX#plan-version}
- current_plan_version_value: {v1}

> `last_observed_at` 必须晚于最新的 proving / 全量测试 / fix 工件；若签收时仍复用旧观察，视为 stale。

## Task 执行进度
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Task | 预标复杂度 | 实际复杂度 | 预期轮次 | 实际轮次 | 状态 |
|------|-----------|-----------|---------|---------|------|

## AC 验收状态
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| UNIT | test_ref 来源 | 聚合来源 | AC 总数 | 通过 | 失败 | 覆盖率 |
|------|--------------|----------|---------|------|------|--------|
| UNIT-1 | artifact://test-cases/{feature}.phase-{N}.unit-1.test-cases@vX#TC-U1-001, artifact://test-cases/{feature}.phase-{N}.unit-1.test-cases@vX#TC-U1-002 | artifact://qa-result/{feature}.phase-{N}.qa@vX#ac-trace | 2 | 2 | 0 | 100% |

## 前置约束验收状态
> 逐条核对 PRD `前置约束` 与 Plan `PRD 前置约束映射`，确认 constraint 对象已按 `preflight_ref → test_ref / 验收证据` 完成闭环。
> 若 PRD 已显式声明 `无前置约束（经评估）`，本章节可不填写数据行；建议在备注或签收记录中补一句“无前置约束（经评估）”。

<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Constraint ID | 类型 | Plan 状态 | preflight_ref | test_ref | 验收结果 | 证据 | 备注 |
|---------------|------|-----------|---------------|----------|----------|------|------|
| CON-001 | [env/runtime/shared-service/compliance/rollout/preflight] | {MAPPED, VERIFIED} <!-- HOOK-CONTRACT:ENUM 填 MAPPED, VERIFIED 之一 --> | [artifact://design/{feature}.phase-{N}.design@vX#preflight-1] | [artifact://test-cases/{feature}.phase-{N}.unit-1.test-cases@vX#TC-U1-001 / N/A] | {OK, ISSUE, N/A} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> | [artifact://qa-result/{feature}.phase-{N}.qa@vX#constraint-CON-001] | [未通过时说明原因] |

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
> 仅汇总强门禁阶段；Code Review 必须包含 `REVIEW_A / REVIEW_B / REVIEW_C`。

<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| 门禁 | 状态 |
|------|------|
| TDD 证据 | {PASS, FAIL} <!-- HOOK-CONTRACT:ENUM 填 PASS, FAIL 之一 --> |
| Code Review (REVIEW_A) | {OK, ISSUE} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE 之一 --> |
| Code Review (REVIEW_B) | {OK, ISSUE} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE 之一 --> |
| Code Review (REVIEW_C) | {OK, ISSUE} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE 之一 --> |
| QA_A (AC 验收) | {OK, ISSUE} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE 之一 --> |
| QA_B (E2E 旅程) | {OK, ISSUE, N/A} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> |
| QA_C (回归验证) | {OK, ISSUE, N/A} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> |
| QA_D (探索性测试) | {OK, ISSUE, N/A} <!-- HOOK-CONTRACT:ENUM 填 OK, ISSUE, N/A 之一 --> |
| 全量测试 | {PASS, FAIL} <!-- HOOK-CONTRACT:ENUM 填 PASS, FAIL 之一 --> |

## 汇总代理引用
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Agent | 汇总文件 | 字段引用位 | 证据锚点引用位 | 重入规则 | 汇总状态 |
|------|----------|-----------|----------------|----------|----------|
| Status Synthesis Agent | `delivery-status-summary.md` | `输入边界` / `当前判断` / `未决项` / `禁止越权项` | `artifact://developer-report/...` / `artifact://qa-result/...` | `BLOCKED` 计入并行数；重试不重复计数；replan 跨批次重新计数 | {N/A, TRIGGERED, STALE} |
| Evidence Synthesis Agent | `evidence-summary.md` | `输入边界` / `当前判断` / `证据锚点` / `未决项` / `禁止越权项` | `artifact://developer-report/...` / `artifact://code-review-result/...` / `artifact://qa-result/...` / `artifact://signoff-package/...` | 仅允许在 Status Synthesis Agent 结束或停止后进入；旧 summary 可标记 `STALE`，且仅允许重跑 `1` 次 | {N/A, TRIGGERED, STALE} |

## 发布建议对齐
- qa_report_release_recommendation: {放行, 条件放行, 阻塞}
- acceptance_release_recommendation: {放行, 条件放行, 阻塞}
<a id="residual-risk"></a>
- residual_risk: {引用 qa-result.json 的残余风险摘要}
- uncovered_boundary: {仍未覆盖、未执行或只做条件承接的边界；无则写无}
- conditional_release_basis: {条件放行时必填；放行/阻塞时写无或明确理由}
- not_executed_reason: {QA 非执行项承接摘要；无则写无}
- risk_acceptance_basis: {当存在残余风险、条件放行或部分达成时，记录接受依据；无则写无}

## 目标闭环
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| 目标 | goal_source_ref | execution_basis_ref | evidence_ref | result | remaining_gap |
|------|-----------------|---------------------|--------------|--------|---------------|
| {brief 成功标准 / phase goal / delivery value} | {artifact://brief/{feature}.brief@vX#goal-001 / artifact://phase-prd/{feature}.phase-{N}.phase-prd@vX#phase-goal} | {artifact://design/{feature}.phase-{N}.design@vX#key-decisions / artifact://plan/{feature}.phase-{N}.plan@plan-vX#execution-basis-refs / artifact://test-cases/{feature}.phase-{N}.unit-1.test-cases@vX#TC-U1-001} | {artifact://developer-report/... / artifact://qa-result/... / artifact://evidence/...} | {已达成, 部分达成, 未达成} | {无 / 待补项} |

> 签收建立在目标闭环之上，不是只看门禁为绿。`qa` 只给放行建议，不替代用户接受风险。
> 每一行都必须填写 `goal_source_ref / execution_basis_ref / evidence_ref`，且三者都必须可回链到真实锚点。
> `goal_source_ref` 只允许引用 `artifact://brief/...#goal-*` 或 `artifact://phase-prd/...#phase-goal`；`execution_basis_ref` 只允许引用 `artifact://design/...`、`artifact://plan/...`、`artifact://test-cases/...` 的稳定锚点。
> 当 `execution_basis_ref` 或 `evidence_ref` 指向 UNIT 级工件时，必须写成 `unit-{N}/...#anchor` 这种 phase 可解析路径，不能依赖模糊相对路径。
> `goal` 本身可以是上游目标的同义复述或收口摘要，但不能漏掉任何 upstream goal；门禁按来源锚点和目标数量核对，不按文案相似度判断。
> `brief.json.business_goals` 与 `phase-prd.json.phase_goal` 中的每个上游目标都必须在本表出现，不允许只挑部分目标签收。

## 已知问题
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Issue ID | 来源 | 描述 | 严重度 | 处置 |
|----------|------|------|--------|------|
| QAR-001 | QA | [来自 qa-result.json 的问题摘要] | [S1/S2/S3] | [修复 / 豁免 / 条件放行控制] |

## 豁免（如有）
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Waiver ID | 检查项 | 关联 Issue | 到期时间 |
|-----------|--------|-----------|---------|

## 签收记录
- sign_off_status: {确认, 拒绝, 待签收} <!-- HOOK-CONTRACT:ENUM 填 确认, 拒绝, 待签收 之一 -->
- sign_off_by: {user}
- sign_off_at: {ISO 8601}
- business_risk_acceptance_status: {接受, 拒绝, 不适用, 待确认} <!-- HOOK-CONTRACT:ENUM 填 接受, 拒绝, 不适用, 待确认 之一 -->
- business_risk_acceptance_by: {user / 无}
- business_risk_acceptance_at: {ISO 8601 / 无}
- 备注: {如有拒绝原因或附加条件}

> `sign_off_at` 必须晚于最新的 `proving_command_executed_at`、`TEST_EXECUTED_AT`，且若本 Phase 存在 `fix-N.md`，必须晚于最近一次修复工件。
