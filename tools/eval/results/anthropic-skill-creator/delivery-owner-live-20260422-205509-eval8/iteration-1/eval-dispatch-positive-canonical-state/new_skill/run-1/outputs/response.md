已按 `delivery-owner` 的正向派发口径校验完成，结论是：**canonical 工件齐全，且都来自 active artifact-registry，可进入第一轮派发**。

**必需字段**
- `baseline_status`: `PASS`
- `active_plan_version_ref`: `artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
- `active_tasks_version_ref`: `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`
- `current_stage`: `TASK_EXECUTION`
- `control_action`: `CONTINUE`
- `dispatch_mode`: `batch_1`
- `batch_1_tasks`: `T1`, `T2`
- `batch_2_unlock_condition`: `T1` 和 `T2` 都具备 `developer-report.json` + `verify-result.json` 后，才解锁 `T3`

**派发合同**
- `T1`
  - `Requirement`: 只基于 active registry 解析可消费的注册表路径
  - `Goal`: 实现 registry resolver dispatch path
  - `Acceptance Criteria`: 能从 canonical registry 解析 active artifact path，覆盖 `TC-1`
  - `Scope`: `tools/community/manage_artifact_registry.py`
  - `Evidence In`: `brief.json`、`phase-prd.json`、`design.json`、`plan.json`、`tasks.json`、`unit-1/test-cases.json`、`artifact-registry.json`
  - `Evidence Out`: `developer-report.json`、`verify-result.json`、`fresh proving command` 的完整输出
  - `Control Decision`: `CONTINUE`

- `T2`
  - `Requirement`: 只基于 active runtime state 更新 delivery-state
  - `Goal`: 实现 delivery-state update path
  - `Acceptance Criteria`: 能记录 batch runtime status，覆盖 `TC-2`
  - `Scope`: `tools/community/update_delivery_state.py`
  - `Evidence In`: 同上
  - `Evidence Out`: `developer-report.json`、`verify-result.json`、`fresh proving command` 的完整输出
  - `Control Decision`: `CONTINUE`

**delivery-state 更新口径**
- 这轮只更新运行态口径，不实际写文件。
- 语义上应从 `KICKOFF_READY` / `READY` 切到：
  - `current_stage = TASK_EXECUTION`
  - `status = IN_PROGRESS`
  - `control_action = CONTINUE`
- `tasks` 视图应记录：
  - `T1`: `runtime_status=READY_TO_START`, `owner=developer`, `current_batch=batch_1`, `next_action=implement_and_prove`
  - `T2`: `runtime_status=READY_TO_START`, `owner=developer`, `current_batch=batch_1`, `next_action=implement_and_prove`
  - `T3`: `runtime_status=LOCKED`, `owner=developer`, `current_batch=batch_2`, `next_action=wait_for_batch_1_evidence`

**下一步**
- 先派发 `T1` 和 `T2` 并行执行。
- 不进入 review / QA 门禁。
- 不写文件、不启动服务、不调用 agent。
- 等待两项任务各自补齐 `developer-report.json`、`verify-result.json` 和 fresh proving evidence 后，再解锁 `T3`。