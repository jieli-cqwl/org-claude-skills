已确认：`brief / phase-prd / design / plan / tasks / test-cases / artifact-registry / delivery-state` 都齐全，且都来自同一 Phase 的 `active_revision`，可以进入第一轮正向派发。

**本轮派发结论**
- `control_action`: `CONTINUE`
- `current_stage`: 从 `KICKOFF_READY` 推进到 `TASK_EXECUTION`
- `active_plan_version_ref`: `artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
- `active_tasks_version_ref`: `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`
- 派发批次：`batch_1`
- 批次任务：`T1`, `T2`
- 解锁条件：`T3` 仅在 `T1` 和 `T2` 都产出 `developer-report.json` 与 `verify-result.json` 后解锁

**派发合同**

`T1 build registry resolver dispatch path`
- Requirement: 只实现注册表解析与派发路径，不越界到 state/update/readiness。
- Goal: 让 `tools/community/manage_artifact_registry.py` 能稳定发现 active artifact path。
- Acceptance Criteria: 覆盖 `TC-1`，结果与 active registry 一致，路径解析可复现。
- Scope: `tools/community/manage_artifact_registry.py`
- Evidence In: `plan-v3`、`tasks-v3`、`design.interface_boundary`、`unit-1/test-cases.json#TC-1`
- Evidence Out: `developer-report.json`、`verify-result.json`、`fresh proving command` 完整输出
- Control Decision: `CONTINUE`，若发现 registry 解析偏差则转 `FIX`

`T2 build delivery-state update path`
- Requirement: 只实现 delivery-state 更新，不混入 registry resolver 或 readiness 校验逻辑。
- Goal: 让 `tools/community/update_delivery_state.py` 能记录 batch runtime status。
- Acceptance Criteria: 覆盖 `TC-2`，状态写入与 batch 语义一致，可追踪。
- Scope: `tools/community/update_delivery_state.py`
- Evidence In: `plan-v3`、`tasks-v3`、`design.interface_boundary`、`unit-1/test-cases.json#TC-2`
- Evidence Out: `developer-report.json`、`verify-result.json`、`fresh proving command` 完整输出
- Control Decision: `CONTINUE`，若状态回写不稳定则转 `FIX`

**delivery-state 更新口径**
- `current_stage`: `TASK_EXECUTION`
- `status`: `IN_PROGRESS`
- `control_action`: `CONTINUE`
- `tasks`: 记录 `T1/T2` 的 `runtime_status=DISPATCHED`，`owner=developer`，`current_batch=batch_1`，`next_action=produce developer-report and verify-result`
- `T3`: 记录为 `LOCKED`，`unlock_condition=batch_1 complete`

**下一步**
1. 派发 `T1` 和 `T2` 给开发执行。
2. 等待两项任务各自的 `developer-report.json / verify-result.json / fresh proving command`。
3. 再解锁 `T3`，进入下一批次。