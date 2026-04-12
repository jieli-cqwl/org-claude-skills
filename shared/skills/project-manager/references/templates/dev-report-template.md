# dev-report.md

## 输入分析
{Plan + Design + MOD 约束理解}

## 决策
{执行模式（串行/并行）+ worktree 分支信息 + 实现策略 + 测试策略}

## 产出
TEST_CMD: {命令}

### Task-1: {标题}
- design_ref / 测试先行 / 红阶段 / 实现 / 绿阶段 / 全量测试
- scope_item_ref / impact_files / rollback_ref（按 plan 原样承接）
- split_reason / atomicity_note / depends_on / shared_files（按 plan 摘要）
- proving_command: {按 plan 原样承接；执行阶段必须 fresh 重跑该命令} 
- real_dependency_note: {按 plan 原样承接；说明真实服务 / 环境 / 集成路径}
- evidence_target: {按 plan 原样承接；后续证据回填必须与该锚点一致}
- mock_boundary_note: {按 plan 原样承接；最终验收不得用 Mock 验收替代}
- developer_report_ref: {指向 developer-report-Task-N.md#reviewable-anchor；TDD 原始证据唯一真源}
- deviation_trigger: {NONE, COMPLEXITY_DRIFT, INTERFACE_TWEAK, INTERFACE_BREAK, SHARED_FILES_EXPANSION, DEPENDENCY_DRIFT, NON_CONVERGENCE, BLOCKED_ACCUMULATION}
- control_action: {CONTINUE, ESCALATE, REPLAN, BLOCK}

#### 一手证据引用
- `developer_report_ref` 指向权威 TDD 证据；`dev-report.md` 不重复粘贴 RED/GREEN 全量原文。
- 这里只保留执行期 fresh proving command 的完整输出与偏差治理结论，便于 Phase 收口抽查。

Fresh proving command:
```
{粘贴 proving_command 的完整命令输出}
```

- Spec Review: {SPEC_OK, SPEC_ISSUE}（轮次） <!-- HOOK-CONTRACT:ENUM 填 SPEC_OK, SPEC_ISSUE 之一 -->
- Phase2A: {2A_OK, 2A_ISSUE}（轮次） <!-- HOOK-CONTRACT:ENUM 填 2A_OK, 2A_ISSUE 之一 -->
- Phase2B: {2B_OK, 2B_ISSUE}（轮次） <!-- HOOK-CONTRACT:ENUM 填 2B_OK, 2B_ISSUE 之一 -->
- Phase2C: {2C_OK, 2C_ISSUE}（轮次） <!-- HOOK-CONTRACT:ENUM 填 2C_OK, 2C_ISSUE 之一 -->
- Commit: feat(Task-1): {描述}

### Task-Commit 对照表
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Task | Commit | 含测试 | Spec | 2A | 2B | 2C | 状态 |
|------|--------|--------|------|----|----|----|------|

### Task-design_ref 对照表
| Task | design_ref | 约束执行说明 | split_reason / atomicity_note 摘要 |
|------|-----------|-------------|-------------------------------|

### Task-scope 对照表
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Task | scope_item_ref | impact_files | rollback_ref | 边界校验 |
|------|----------------|--------------|--------------|----------|
| Task-1 | SCOPE-P1U1-001 | src/core.ts, tests/core.test.ts | plan.md#rollback-task-1 | OK |

### 全量测试结果
TEST_CMD: {命令}
{粘贴完整测试输出}

### 用户豁免（如有）
- PMW-001: {检查项(REVIEW_B, QA_B, QA_C, QA_D) + 关联 Issue IDs + 风险摘要 + 到期时间} <!-- HOOK-CONTRACT:FORMAT -->

### worktree 信息（并行模式）
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Task | 分支 | worktree 路径 | merge 状态 | 清理状态 |
|------|------|--------------|-----------|---------|

### BLOCKED 任务
| Task | 原因 | worktree 保留 |
|------|------|--------------|

### Task 执行进度
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Task | 预标复杂度 | 实际复杂度 | 预期轮次 | 实际轮次 | 偏差触发器 | 控制动作 | 状态 |
|------|-----------|-----------|---------|---------|-----------|----------|------|

### 偏差治理摘要
- 升级触发次数: N
- `REPLAN / BLOCK` 次数: N
- 影响面扩大记录: {无 / 摘要}

### 执行状态总结
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| 阶段 | 状态 | 修复轮次 | 关键动作 |
|------|------|---------|---------|
| Phase 2 | {DONE, BLOCKED} <!-- HOOK-CONTRACT:ENUM 填 DONE, BLOCKED 之一 --> | N | {CONTINUE / ESCALATE / REPLAN / BLOCK} |
| Phase 3 Review | {DONE, ISSUE} <!-- HOOK-CONTRACT:ENUM 填 DONE, ISSUE 之一 --> | N | M |
| Phase 3 QA | {DONE, ISSUE} <!-- HOOK-CONTRACT:ENUM 填 DONE, ISSUE 之一 --> | N | M |
| Phase 4 | {DONE, SKIP} <!-- HOOK-CONTRACT:ENUM 填 DONE, SKIP 之一 --> | - | - |

### 交接项
- commit 列表（含 hash）、测试结果摘要、遗留问题、BLOCKED 任务
- worktree 清理状态
