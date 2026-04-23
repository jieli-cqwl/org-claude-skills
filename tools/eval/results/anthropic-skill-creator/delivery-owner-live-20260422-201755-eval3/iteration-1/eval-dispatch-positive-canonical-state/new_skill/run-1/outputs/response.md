已核对：`brief / phase-prd / design / plan / tasks / unit-1/test-cases / artifact-registry / delivery-state` 都在同一 `phase-1`，且 `artifact-registry.active_revision_id=rev-dispatch-ready`，可作为 canonical baseline 消费。

**控制结论**
- `control_action`: `CONTINUE`
- `current_stage`: `TASK_EXECUTION`
- `dispatch_mode`: `PARALLEL`
- `current_batch`: `Batch-1`
- `batch_unlock_condition`: `T1` 和 `T2` 都拿到 `developer-report.json` + `verify-result.json` 后，才解锁 `T3`
- `next_action`: `DISPATCH_TASKS_T1_T2`

**正向派发合同**

**Task T1**
- `Requirement`: 来源于 `sample-feature.phase-1.prd` 的 phase goal，任务为 `build registry resolver dispatch path`
- `Goal`: 让 registry resolver 能从 active registry 解析并返回可消费的 artifact path
- `Acceptance Criteria`: 覆盖 `TC-1`，满足 `registry-discovery`
- `Scope`: 仅允许触碰 `tools/community/manage_artifact_registry.py`
- `Evidence In`: `plan@plan-v3`、`tasks@tasks-v3`、`design@interface-boundary`、`test-cases@v1#TC-1`、`delivery-state@v1`
- `Evidence Out`: `developer-report.json`、`verify-result.json`、`fresh proving command` 完整输出
- `Control Decision`: `CONTINUE`；若出现路径解析偏差或共享文件扩展，转 `FIX` / `BLOCK`

**Task T2**
- `Requirement`: 来源于 `sample-feature.phase-1.prd` 的 phase goal，任务为 `build delivery-state update path`
- `Goal`: 让 delivery-state 更新路径能记录 batch runtime status，并保持 active plan/tasks 引用一致
- `Acceptance Criteria`: 覆盖 `TC-2`，满足 `state-update`
- `Scope`: 仅允许触碰 `tools/community/update_delivery_state.py`
- `Evidence In`: `plan@plan-v3`、`tasks@tasks-v3`、`design@interface-boundary`、`test-cases@v1#TC-2`、`delivery-state@v1`
- `Evidence Out`: `developer-report.json`、`verify-result.json`、`fresh proving command` 完整输出
- `Control Decision`: `CONTINUE`；若 runtime state 不能稳定回写，转 `FIX` / `BLOCK`

**依赖解锁**
- `T3` 依赖 `T1 + T2`
- `T3` 仅在两者都产出完整开发与验证证据后解锁
- `T3` 当前不派发

**delivery-state 更新口径**
- `active_plan_version_ref = artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
- `active_tasks_version_ref = artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`
- `current_stage = TASK_EXECUTION`
- `status = IN_PROGRESS`
- `control_action = CONTINUE`
- `tasks` 记录为：
  - `T1`: `runtime_status=DISPATCHED`, `owner=developer`, `current_batch=Batch-1`, `next_action=produce developer-report.json and verify-result.json`
  - `T2`: `runtime_status=DISPATCHED`, `owner=developer`, `current_batch=Batch-1`, `next_action=produce developer-report.json and verify-result.json`
  - `T3`: `runtime_status=BLOCKED_BY_DEPENDENCY`, `owner=developer`, `current_batch=Batch-2`, `next_action=wait for T1/T2 evidence`

**下一步**
1. 派发 `T1` 和 `T2`。
2. 等待两份 `developer-report.json` 与 `verify-result.json`。
3. 再决定是否解锁 `T3`。