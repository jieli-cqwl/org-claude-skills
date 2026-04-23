已按 `delivery-owner` 规则完成第一轮正向派发判断，当前结论是 `CONTINUE`，且**canonical 工件齐全并来自 active artifact-registry，不以缺工件阻断**。本次**不实际写文件**，只给出派发合同、`delivery-state` 更新口径和下一步。

**控制结论**
- `current_stage`: 进入 `TASK_EXECUTION`
- `status`: `READY`
- `control_action`: `CONTINUE`
- `active_plan_version_ref`: `artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
- `active_tasks_version_ref`: `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`

**派发批次**
- 当前批次：`batch_1`
- 批次任务：`T1`, `T2`
- 并行依据：`plan.json` 明确 `batch_1` 包含 `T1` 和 `T2`，且两者 `shared_files` 为空、`depends_on` 为空
- 解锁条件：`T1` 和 `T2` 都必须回收 `developer-report.json` 和 `verify-result.json` 后，才能解锁 `T3`

**Task 派发合同 - T1**
- `Requirement`: 来自 `phase-prd` 的 `UNIT-1`，对应 `T1: build registry resolver dispatch path`
- `Goal`: 建立 registry 解析派发路径，让运行时能从 active registry 找到可消费工件
- `Acceptance Criteria`: 通过 `TC-1`，即 registry resolver 返回 active artifact path
- `Scope`: 仅允许修改 `tools/community/manage_artifact_registry.py`
- `Evidence In`: `plan-v3`、`tasks-v3`、`design.interface-boundary`、`unit-1/test-cases.json#TC-1`、当前 `delivery-state.json`
- `Evidence Out`: `developer-report.json`、`verify-result.json`、`fresh proving command` 的完整输出
- `Control Decision`: 若证明 active registry 解析成功则 `CONTINUE`；若路径解析/注册表消费失败则 `FIX`；若发现 scope 外影响则 `BLOCK`

**Task 派发合同 - T2**
- `Requirement`: 来自 `phase-prd` 的 `UNIT-1`，对应 `T2: build delivery-state update path`
- `Goal`: 建立 delivery-state 更新路径，让批次与运行态可被可靠记录
- `Acceptance Criteria`: 通过 `TC-2`，即 delivery-state update 记录 batch runtime status
- `Scope`: 仅允许修改 `tools/community/update_delivery_state.py`
- `Evidence In`: `plan-v3`、`tasks-v3`、`design.interface-boundary`、`unit-1/test-cases.json#TC-2`、当前 `delivery-state.json`
- `Evidence Out`: `developer-report.json`、`verify-result.json`、`fresh proving command` 的完整输出
- `Control Decision`: 若运行态更新符合预期则 `CONTINUE`；若状态字段/批次口径不一致则 `FIX`；若触及非授权文件则 `BLOCK`

**T3 当前状态**
- `runtime_status`: `LOCKED`
- `owner`: 下一轮开发派发
- `current_batch`: `batch_2`
- `next_action`: 等待 `T1`、`T2` 的 `developer-report.json` 和 `verify-result.json`
- `解锁条件`: 批次 1 两个任务的证据都齐后再派发 `T3`

**delivery-state 更新口径**
- 将 `current_stage` 从 `KICKOFF_READY` 更新为 `TASK_EXECUTION`
- 保持 `status=READY`、`control_action=CONTINUE`
- 记录 `active_plan_version_ref=artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
- 记录 `active_tasks_version_ref=artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`
- 在 `tasks` 中写入：
  - `T1`: `runtime_status=DISPATCHED`, `owner=developer`, `current_batch=batch_1`, `next_action=deliver developer-report.json + verify-result.json`
  - `T2`: `runtime_status=DISPATCHED`, `owner=developer`, `current_batch=batch_1`, `next_action=deliver developer-report.json + verify-result.json`
  - `T3`: `runtime_status=LOCKED`, `owner=developer`, `current_batch=batch_2`, `next_action=wait for batch_1 evidence`
- 口径要求：运行态必须消费当前 `plan_version_ref / tasks_version_ref`，不能引用旧版本结论

**下一步**
1. 先派发 `T1` 和 `T2` 的开发执行。
2. 回收两项任务的 `developer-report.json` 和 `verify-result.json`。
3. 再判断是否解锁 `T3`。