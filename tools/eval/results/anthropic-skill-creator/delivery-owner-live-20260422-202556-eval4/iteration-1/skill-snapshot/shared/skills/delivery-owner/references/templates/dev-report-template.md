# developer-report projection

> Phase 级执行摘要模板；运行时以 `developer-report.json`、`verify-result.json`、`delivery-state.json` 为真源。

## 输入分析
{Plan + Design + MOD 约束理解}

## 决策
{执行模式（串行/并行）+ worktree 分支信息 + 实现策略 + 测试策略}

### 运行态状态感知
- last_observed_at: {ISO 8601}
- runtime_snapshot: {最新观察到的执行状态、门禁状态与风险摘要}
- active_blocker: {无 / 当前阻塞摘要}
- blocker_owner: {无 / developer / fix / qa / tech-lead / user / delivery-owner}
- takeover_note: {无（主 Agent 持续跟进） / 接手原因 + 下一动作}
- decision_basis: {至少包含一个当前锚点引用，如 artifact://plan/{feature}.phase-{N}.plan@plan-vX#plan-version + artifact://qa-result/{feature}.phase-{N}.qa@vX#release}

### 执行编排状态
- dispatch_mode: {SERIAL, PARALLEL, EXPLORE_BATCH}
- current_batch: {SERIAL / Batch-1 / Explore-Batch-1}
- batch_unlock_condition: {当前批次解锁下一步的条件；串行模式写 SERIAL}
- merge_readiness: {READY, PENDING, BLOCKED}
- next_action: {REQUEST_REVIEW, WAIT_BATCH, ESCALATE, REPLAN_REQUEST, HOLD}
- plan_version_ref: {artifact://plan/{feature}.phase-{N}.plan@plan-vX#plan-version}
- plan_version_value: {v1}
- replan_request: {无 / 指向 plan 修订记录或 replan 请求锚点}
- batch_freeze_reason: {无 / 当前 batch 冻结原因}
- unlock_resolution: {无 / replan 后新的解锁结论}

## 产出
TEST_CMD: {命令}

### Task-1: {标题}
- design_ref / 测试先行 / 红阶段 / 实现 / 绿阶段 / 全量测试
- scope_item_ref / impact_files / rollback_ref（按 plan 原样承接）
- split_reason / atomicity_note / depends_on / shared_files（按 plan 摘要）
- proving_command: {按 plan 原样承接}
- real_dependency_note: {按 plan 原样承接；说明真实服务 / 环境 / 集成路径}
- evidence_target: {按 plan 原样承接}
- mock_boundary_note: {按 plan 原样承接}
- developer_report_ref: {指向 artifact://developer-report/{feature}.phase-{N}.unit-{N}.task-{task_id}.developer-report@vX#reviewable-anchor；TDD 原始证据唯一真源}
- deviation_trigger: {NONE, COMPLEXITY_DRIFT, INTERFACE_TWEAK, INTERFACE_BREAK, SHARED_FILES_EXPANSION, DEPENDENCY_DRIFT, NON_CONVERGENCE, BLOCKED_ACCUMULATION}
- control_action: {CONTINUE, ESCALATE, REPLAN, BLOCK}

#### 一手证据引用
- `developer_report_ref` 指向权威 TDD 证据；当前模板不重复粘贴 RED/GREEN 全量原文。
- 这里只保留执行期 fresh proving command 的完整输出与偏差治理结论，便于 Phase 收口抽查。
- proving evidence 记录在下列字段，签收 freshness 规则见 `references/signoff-contract.md`。

- proving_command_executed_at: {ISO 8601}
- proving_command_exit_code: {0}
Fresh proving command:
```
{粘贴 proving_command 的完整命令输出}
```

- Spec Review: {SPEC_OK, SPEC_ISSUE}（轮次）
- Phase2A: {2A_OK, 2A_ISSUE}（轮次）
- Phase2B: {2B_OK, 2B_ISSUE}（轮次）
- Phase2C: {2C_OK, 2C_ISSUE}（轮次）

### Task-change_set 对照表
| Task | change_set_ref | reviewable_anchor | 含测试 | Spec | 2A | 2B | 2C | 状态 |
|------|----------------|-------------------|--------|------|----|----|----|------|

### Task-design_ref 对照表
| Task | design_ref | 约束执行说明 | split_reason / atomicity_note 摘要 |
|------|-----------|-------------|-------------------------------|

### Task-scope 对照表
| Task | scope_item_ref | impact_files | rollback_ref | 边界校验 |
|------|----------------|--------------|--------------|----------|
| Task-1 | SCOPE-P1U1-001 | src/core.ts, tests/core.test.ts | artifact://plan/{feature}.phase-{N}.plan@plan-vX#rollback-task-1 | OK |

### 全量测试结果
TEST_CMD: {命令}
TEST_EXECUTED_AT: {ISO 8601}
TEST_EXIT_CODE: {0}
{粘贴完整测试输出}

### 用户豁免（如有）
- PMW-001: {residual_risk:<stable_issue_id> / waiver:<single-risk-id> + 关联 Issue IDs + 风险摘要 + 到期时间}

### worktree 信息（并行模式）
| Task | 分支 | worktree 路径 | merge 状态 | 清理状态 |
|------|------|--------------|-----------|---------|

### BLOCKED 任务
| Task | 原因 | worktree 保留 |
|------|------|--------------|

### Task 执行进度
| Task | 预标复杂度 | 实际复杂度 | 预期轮次 | 实际轮次 | 偏差触发器 | 控制动作 | 状态 |
|------|-----------|-----------|---------|---------|-----------|----------|------|

### 偏差治理摘要
- 偏差触发次数: N
- `REPLAN / BLOCK` 次数: N
- 影响面扩大记录: {无 / 摘要}

### 执行状态总结
| 阶段 | 状态 | 修复轮次 | 关键动作 |
|------|------|---------|---------|
| 开发执行 | {DONE, BLOCKED} | N | {CONTINUE / ESCALATE / REPLAN / BLOCK} |
| 交付门禁 Review | {DONE, ISSUE} | N | M |
| 交付门禁 QA | {DONE, ISSUE} | N | M |
| 提交 | {DONE, SKIP} | - | - |

### 交接项
- change_set_ref、测试结果摘要、遗留问题、BLOCKED 任务
- worktree 清理状态

### 汇总代理状态
| Agent | 字段引用位 | 证据锚点引用位 | 汇总状态 |
|------|-----------|----------------|----------|
| Status Synthesis Agent | {输入边界 / 当前判断 / 未决项 / 禁止越权项} | {artifact://developer-report/... / artifact://qa-result/...} | {N/A, TRIGGERED, STALE} |
| Evidence Synthesis Agent | {输入边界 / 当前判断 / 证据锚点 / 未决项 / 禁止越权项} | {artifact://developer-report/... / artifact://code-review-result/... / artifact://qa-result/... / artifact://signoff-package/...} | {N/A, TRIGGERED, STALE} |
