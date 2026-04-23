已确认这套 `sample-feature` 满足第一轮正向派发前置条件，不阻断。

**结论**
- `kickoff_status`: `READY`
- `control_action`: `CONTINUE`
- 当前可派发批次：`batch_1`，包含 `T1`、`T2`
- 下一批 `T3` 仍需等 `T1`、`T2` 都产出 `developer-report.json` 和 `verify-result.json` 后再解锁

**必需字段**
- `requirement_ref`: `artifact://brief/sample-feature.brief@v1#goal-001`
- `goal_ref`: `artifact://phase-prd/sample-feature.phase-1.prd@v1#phase-goal`
- `acceptance_criteria_ref`: `artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#TC-1`, `#TC-2`, `#TC-3`
- `scope_ref`: `tools/community/manage_artifact_registry.py`, `tools/community/update_delivery_state.py`, `tools/community/validate_standard_chain_readiness.py`
- `design_ref`: `artifact://design/sample-feature.phase-1.design@v1#interface-boundary`, `#quality-attributes`
- `runtime_ref`: `artifact://delivery-state/sample-feature.phase-1.delivery-state@v1#current-stage`
- `plan_version_ref`: `artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`

**派发合同**
- `Task T1`
  - Requirement: 交付 Phase-1 中 registry resolver 的 dispatch 路径，来源于 `UNIT-1 / TC-1`
  - Goal: 让 registry 能解析 active artifact path
  - Acceptance Criteria: 能覆盖 `registry-discovery`，验证 `manage_artifact_registry.py` 的活跃版本解析
  - Scope: 仅允许 `tools/community/manage_artifact_registry.py`
  - Evidence In: `plan-v3`、`tasks-v3`、`design#interface-boundary`、`TC-1`
  - Evidence Out: `developer-report.json`、`verify-result.json`、fresh proving command 完整输出
  - Control Decision: `CONTINUE`；若发现路径解析偏差或 scope 外变更则 `BLOCK`

- `Task T2`
  - Requirement: 交付 Phase-1 中 delivery-state 的 update 路径，来源于 `UNIT-1 / TC-2`
  - Goal: 让 runtime state 正确记录 batch 状态
  - Acceptance Criteria: 能覆盖 `state-update`，验证 `update_delivery_state.py` 的 batch/runtime 状态写入
  - Scope: 仅允许 `tools/community/update_delivery_state.py`
  - Evidence In: `plan-v3`、`tasks-v3`、`design#interface-boundary`、`TC-2`
  - Evidence Out: `developer-report.json`、`verify-result.json`、fresh proving command 完整输出
  - Control Decision: `CONTINUE`；若状态口径不一致或影响共享文件，则 `BLOCK`

**delivery-state 更新口径**
- `active_plan_version_ref` 保持 `artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
- `active_tasks_version_ref` 保持 `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`
- `current_stage` 维持 `KICKOFF_READY`
- `status` 维持 `READY`
- `control_action` 维持 `CONTINUE`
- `tasks` 先记录本轮派发对象：
  - `T1`: `DISPATCHED`
  - `T2`: `DISPATCHED`
- `batch_1` 的合并门槛：`T1` 和 `T2` 都补齐 `developer-report.json` + `verify-result.json`
- `T3` 仍保持 `LOCKED_BY_DEPENDENCY`

**下一步**
1. 按 `batch_1` 正式派发 `T1`、`T2`
2. 等待两项任务各自的 `developer-report.json` 和 `verify-result.json`
3. 再判断是否解锁 `T3` 并进入下一轮派发