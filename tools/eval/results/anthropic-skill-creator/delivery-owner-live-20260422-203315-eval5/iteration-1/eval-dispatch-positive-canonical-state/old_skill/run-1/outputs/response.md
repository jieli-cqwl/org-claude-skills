前置条件通过：这套 `sample-feature` 已同时具备 `brief.json / phase-prd.json / design.json / plan.json / tasks.json / unit-1/test-cases.json / artifact-registry.json / delivery-state.json`，且都指向同一 `phase-1`；当前运行态是 `READY`，`plan_version=plan-v3`，`active_revision_id=rev-dispatch-ready`。

**必需字段**
- `requirement_ref`: `artifact://phase-prd/sample-feature.phase-1.prd@v1#phase-goal`
- `goal_ref`: `artifact://brief/sample-feature.brief@v1#goal`
- `acceptance_criteria_ref`: `artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#ac_coverage_matrix` + `artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#test_cases`
- `scope_ref`: `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task_list`
- `design_ref`: `artifact://design/sample-feature.phase-1.design@v1#interface-boundary`
- `runtime_ref`: `artifact://delivery-state/sample-feature.phase-1.delivery-state@v1#current_stage`
- `plan_version_ref`: `artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`

**第一轮正向派发合同**
- `dispatch_batch`: `Batch-1`
- `tasks`: `T1`, `T2`
- `control_decision`: `CONTINUE`
- `batch_unlock_condition`: `T1` 和 `T2` 都产出 `developer-report.json` 与 `verify-result.json`，且验证结果满足各自 `test_ref`
- `batch_2_handoff`: 只有在上述条件满足后，才允许派发 `T3`

**Task T1 合同**
- `Requirement`: `sample-feature.phase-1` 的交付目标下，按 `T1` 构建 registry resolver dispatch path
- `Goal`: 让 delivery-owner 能从 active registry 解析到当前可消费的 artifact 路径
- `Acceptance Criteria`: 覆盖 `TC-1`，验证 registry resolver 返回 active artifact path
- `Scope`: 仅允许修改 `tools/community/manage_artifact_registry.py`
- `Evidence In`: `phase_ref`、`design_ref`、`test_ref=artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#TC-1`、`plan_version_ref`
- `Evidence Out`: `developer-report.json`、`verify-result.json`、fresh proving command 的完整输出
- `Control Decision`: `CONTINUE`；若解析结果与 active revision 不一致则 `FIX`

**Task T2 合同**
- `Requirement`: `sample-feature.phase-1` 的交付目标下，按 `T2` 构建 delivery-state update path
- `Goal`: 让运行态可以记录 batch 的状态更新，并保持当前阶段可追踪
- `Acceptance Criteria`: 覆盖 `TC-2`，验证 delivery-state update records batch runtime status
- `Scope`: 仅允许修改 `tools/community/update_delivery_state.py`
- `Evidence In`: `phase_ref`、`design_ref`、`test_ref=artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#TC-2`、`plan_version_ref`
- `Evidence Out`: `developer-report.json`、`verify-result.json`、fresh proving command 的完整输出
- `Control Decision`: `CONTINUE`；若状态更新不能落到当前运行态则 `FIX`

**delivery-state 更新口径**
- `current_stage`: `DEVELOPMENT_BATCH_1_DISPATCHED`
- `status`: `IN_PROGRESS`
- `control_action`: `CONTINUE`
- `tasks`: 记录 `T1`、`T2` 已派发，状态为 `DISPATCHED`
- `active_plan_version_ref`: 保持 `artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
- `active_tasks_version_ref`: 保持 `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`
- `batch_unlock_condition`: 明确写入“`T1`、`T2` 的 developer-report.json 与 verify-result.json 均到位后，才解锁 `T3`”

**下一步**
- 先派发 `T1` 与 `T2`
- 回收两份 `developer-report.json / verify-result.json`
- 再根据 batch 解锁条件决定是否放行 `T3`