我理解这次 eval 的目标是：在 `sample-feature` 的已冻结基线下，按 `delivery-owner` 做**第一轮正向派发**，对象是 **Phase-1 / batch_1 的 T1、T2**，并输出这次派发所需的**必需字段、派发合同、`delivery-state` 更新口径和下一步**。本次不要求实际写文件、起服务、提交或调用 agent。

**判定**
- 基线齐全且同一 Phase 对齐：`brief / phase-prd / design / plan / tasks / test-cases / artifact-registry / delivery-state`
- 用户已确认进入交付
- 当前运行态：`KICKOFF_READY`
- 结论：**可以正向派发，Control Decision = `CONTINUE`**

**必需字段**
- `requirement_ref`: `artifact://brief/sample-feature.brief@v1#goal-001`
- `goal_ref`: `artifact://phase-prd/sample-feature.phase-1.prd@v1#phase-goal`
- `acceptance_criteria_ref`: `artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#TC-1,TC-2`
- `scope_ref`: `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-T1`、`artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-T2`
- `design_ref`: `artifact://design/sample-feature.phase-1.design@v1#interface-boundary`
- `runtime_ref`: `artifact://delivery-state/sample-feature.phase-1.delivery-state@v1#current-stage`
- `plan_version_ref`: `artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
- `tasks_version_ref`: `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`

**派发合同**
- `Requirement`
  - 需求来源：`brief.goal` 与 `phase-prd.phase_goal`
  - 本轮范围：`UNIT-1` 下的 `T1`、`T2`
  - 约束：只消费 active canonical registry；保持开发/验证边界
- `Goal`
  - `T1`: 打通 artifact registry resolver 的派发路径
  - `T2`: 打通 delivery-state 更新路径
- `Acceptance Criteria`
  - `T1` 对应 `TC-1`：registry resolver 能返回 active artifact path
  - `T2` 对应 `TC-2`：delivery-state 更新能记录 batch runtime status
  - 结果必须能被后续 readiness validation 消费
- `Scope`
  - `T1` 允许范围：`tools/community/manage_artifact_registry.py`
  - `T2` 允许范围：`tools/community/update_delivery_state.py`
  - 共享文件：`shared`/`docs` 不在本轮修改范围内
  - 禁止：修改 `T3` 范围、改 plan/tasks/design/test-cases
- `Evidence In`
  - `brief.json`, `phase-prd.json`, `design.json`, `plan.json`, `tasks.json`, `unit-1/test-cases.json`, `artifact-registry.json`, `delivery-state.json`
  - 当前 `plan_version=plan-v3`，`tasks_version=tasks-v3`
- `Evidence Out`
  - 这次只要求派发合同，不要求实际生成 `developer-report.json` / `verify-result.json`
  - 下一轮回收时再消费 `developer-report.json`、`verify-result.json`
- `Control Decision`
  - 当前：`CONTINUE`
  - 若发现路径缺失、范围冲突、或证据不齐：转 `BLOCK`
  - 若后续实现偏离 AC：转 `FIX`
  - 若需要改范围/目标：转 `REPLAN`

**delivery-state 更新口径**
- 维持 active 版本不变：
  - `active_plan_version_ref = artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
  - `active_tasks_version_ref = artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`
- 阶段推进口径：
  - `current_stage` 从 `KICKOFF_READY` 进入“已派发 batch_1 / 开发中”的状态
  - `status` 记录为进行中语义
  - `control_action = CONTINUE`
- 任务态口径：
  - `T1`、`T2` 标记为已派发 / in_progress
  - `T3` 保持未解锁，等待 `T1`、`T2` 的开发与验证证据齐备
- 运行态要求：
  - 这轮只更新派发事实，不提前写完成结论
  - 不把 batch_2 打开

**下一步**
- 等待 `T1`、`T2` 的 `developer-report.json` 与 `verify-result.json`
- 回收后再判断是否进入 batch_2 的解锁条件

如果你愿意，我下一条可以继续按这个 eval 口径输出一个**结构化派发结果 JSON**，方便你直接拿去做 fixture 对照。