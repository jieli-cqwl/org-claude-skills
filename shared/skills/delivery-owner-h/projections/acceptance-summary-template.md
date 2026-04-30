# acceptance-summary.md

## 交付范围
- Feature: {名称}
- PRD: {路径}
- Plan: {路径}
- Task 数: N（完成: M，BLOCKED: K）

## Kickoff 状态
- kickoff_status: {derived from delivery-state.kickoff.status}
- plan_version_ref: {artifact://plan/{feature}.phase-{N}.plan@plan-vX#plan-version}
- preflight_evidence_ref: {artifact://design/{feature}.phase-{N}.design@vX#preflight-1 / artifact://evidence/{feature}.phase-{N}.preflight@ev-X#preflight-root}
- environment_ready: {yes, no}
- dependency_ready: {yes, no}
- risk_owner_ready: {yes, no}
- qa_handoff_ready: {yes, no}
- readiness_waiver: {无 / waiver_id=PMW-XXX; owner=user; reason=...; compensation_control=...; expires_at=YYYY-MM-DD; user_confirmation_ref=artifact://user-decision/...#readiness-waiver}

## 最新状态摘要
- last_observed_at: {ISO 8601}
- runtime_snapshot: {最近一次执行状态、门禁状态与风险摘要}
- active_blocker: {无 / 当前阻塞摘要}
- blocker_owner: {无 / developer / fix / qa / tech-lead / user / delivery-owner}
- takeover_note: {无（主 Agent 持续跟进） / 最近一次接手说明}
- decision_basis: {至少包含一个当前锚点引用，如 artifact://developer-report/{feature}.phase-{N}.unit-{N}.task-{task_id}.developer-report@vX#tdd-evidence-index + artifact://qa-result/{feature}.phase-{N}.qa@vX#release}
- current_plan_version_ref: {artifact://plan/{feature}.phase-{N}.plan@plan-vX#plan-version}
- current_plan_version_value: {v1}
- current_tasks_version_ref: {artifact://tasks/{feature}.phase-{N}.tasks@tasks-vX#tasks-version}
- current_tasks_version_value: {v1}

## Task 执行进度
| Task | 预标复杂度 | 实际复杂度 | 预期轮次 | 实际轮次 | 状态 |
|------|-----------|-----------|---------|---------|------|

## AC 验收状态
| UNIT | test_ref 来源 | 聚合来源 | AC 总数 | 通过 | 失败 | 覆盖率 |
|------|--------------|----------|---------|------|------|--------|
| UNIT-1 | artifact://test-cases/{feature}.phase-{N}.unit-1.test-cases@vX#TC-U1-001, artifact://test-cases/{feature}.phase-{N}.unit-1.test-cases@vX#TC-U1-002 | artifact://qa-result/{feature}.phase-{N}.qa@vX#ac-trace | 2 | 2 | 0 | 100% |

## 前置约束验收状态
| Constraint ID | 类型 | Plan 状态 | preflight_ref | test_ref | 验收结果 | 证据 | 备注 |
|---------------|------|-----------|---------------|----------|----------|------|------|
| CON-001 | [env/runtime/shared-service/compliance/rollout/preflight] | {MAPPED, VERIFIED} | [artifact://design/{feature}.phase-{N}.design@vX#preflight-1] | [artifact://test-cases/{feature}.phase-{N}.unit-1.test-cases@vX#TC-U1-001 / N/A] | {OK, ISSUE, N/A} | [artifact://qa-result/{feature}.phase-{N}.qa@vX#constraint-CON-001] | [未通过时说明原因] |

## 质量门禁
| 门禁 | 状态 |
|------|------|
| TDD 证据 | {PASS, FAIL} |
| Code Review (REVIEW_A) | {OK, ISSUE} |
| Code Review (REVIEW_B) | {OK, ISSUE} |
| Code Review (REVIEW_C) | {OK, ISSUE} |
| QA_A (AC 验收) | {OK, ISSUE} |
| QA_B (E2E 旅程) | {OK, ISSUE} |
| QA_C (回归验证) | {OK, ISSUE} |
| QA_D (探索性测试) | {OK, ISSUE} |
| 全量测试 | {PASS, FAIL} |

## 发布建议对齐
- qa_report_release_recommendation: {ALLOW, CONDITIONAL_ALLOW, BLOCK, DEFER}
- qa_report_release_recommendation_label: {放行, 条件放行, 阻塞, 延后}
- acceptance_release_recommendation: {ALLOW, CONDITIONAL_ALLOW, BLOCK, DEFER}
- acceptance_release_recommendation_label: {放行, 条件放行, 阻塞, 延后}
<a id="residual-risk"></a>
- residual_risk: {引用 qa-result.json 的残余风险摘要}
- uncovered_boundary: {仍未覆盖、未执行或只做条件承接的边界；无则写无}
- conditional_release_basis: {条件放行时必填；放行/阻塞时写无或明确理由}
- not_executed_reason: {QA 非执行项承接摘要；无则写无}
- risk_acceptance_basis: {当存在残余风险、条件放行或部分达成时，记录接受依据；无则写无}

## 目标闭环
| 目标 | goal_source_ref | execution_basis_ref | evidence_ref | result | remaining_gap_text |
|------|-----------------|---------------------|--------------|--------|--------------------|
| {brief 成功标准 / phase goal / delivery value} | {artifact://brief/{feature}.brief@vX#goal-001 / artifact://phase-prd/{feature}.phase-{N}.phase-prd@vX#phase-goal} | {artifact://design/{feature}.phase-{N}.design@vX#key-decisions / artifact://plan/{feature}.phase-{N}.plan@plan-vX#execution-basis-refs / artifact://test-cases/{feature}.phase-{N}.unit-1.test-cases@vX#TC-U1-001} | {artifact://developer-report/... / artifact://qa-result/... / artifact://evidence/...} | {已达成, 部分达成, 未达成} | {无 / 待补项} |

## 已知问题
| Issue ID | 来源 | 描述 | 严重度 | 处置 |
|----------|------|------|--------|------|
| QAR-001 | QA | [来自 qa-result.json 的问题摘要] | [S1/S2/S3] | [修复 / 豁免 / 条件放行控制] |

## 豁免（如有）
| Waiver ID | 检查项 | 关联 Issue | 风险 | 补偿控制 | 批准人 | 到期时间 |
|-----------|--------|-----------|------|----------|--------|---------|

## 签收记录
- sign_off_status: {确认, 拒绝, 待签收}
- sign_off_by: {user}
- sign_off_at: {ISO 8601}
- business_risk_acceptance_status: {接受, 拒绝, 不适用, 待确认}
- business_risk_acceptance_by: {user / 无}
- business_risk_acceptance_at: {ISO 8601 / 无}
- 备注: {如有拒绝原因或附加条件}
