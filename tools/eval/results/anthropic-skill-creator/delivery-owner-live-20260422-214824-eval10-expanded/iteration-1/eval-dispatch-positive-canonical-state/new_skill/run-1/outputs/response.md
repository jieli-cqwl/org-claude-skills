已确认：这套样例的 canonical 工件齐全，且都来自 `artifact-registry` 的 `active_revision_id=rev-dispatch-ready`；用户也已确认进入交付。当前不阻断，进入第一轮正向派发口径。

**派发结论**
- `control_action`: `CONTINUE`
- `current_stage`: `TASK_EXECUTION`
- `active_plan_version_ref`: `artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
- `active_tasks_version_ref`: `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`

**批次与任务状态**
- `batch_1`: `T1`, `T2` 并行
- `batch_2`: `T3`，仅在 `T1` 和 `T2` 都回收 `developer-report.json` 与 `verify-result.json` 后解锁
- `T1`:
  - `runtime_status`: `READY_TO_DISPATCH`
  - `owner`: `developer`
  - `current_batch`: `1`
  - `next_action`: 产出 `developer-report.json` 与 `verify-result.json`
- `T2`:
  - `runtime_status`: `READY_TO_DISPATCH`
  - `owner`: `developer`
  - `current_batch`: `1`
  - `next_action`: 产出 `developer-report.json` 与 `verify-result.json`
- `T3`:
  - `runtime_status`: `BLOCKED_BY_DEPENDENCIES`
  - `owner`: `developer`
  - `current_batch`: `2`
  - `next_action`: 等待 `T1/T2` 全部 VERIFIED 后再派发

**派发合同**
- `T1`
  - `Requirement`: `phase-prd` `sample-feature.phase-1.prd@v1#phase-goal`；`UNIT-1`；目标是证明 delivery-owner 可按 canonical runtime state 派发
  - `Goal`: 建立 artifact registry 的 dispatch 解析路径
  - `Acceptance Criteria`: 覆盖 `artifact://test-cases/...#TC-1`，满足 `registry-discovery`
  - `Scope`: 只允许 `tools/community/manage_artifact_registry.py`
  - `Evidence In`: `phase-prd` / `design` / `plan` / `tasks` / `test-cases` / `delivery-state` / `artifact-registry` 的 active refs
  - `Evidence Out`: `developer-report.json`、`verify-result.json`、`fresh proving command` 完整输出
  - `Control Decision`: `CONTINUE`；若 proving 不完整或 SPEC 不通过则 `FIX`
- `T2`
  - `Requirement`: 同一 `phase-prd` / `UNIT-1`
  - `Goal`: 建立 delivery-state 更新路径
  - `Acceptance Criteria`: 覆盖 `artifact://test-cases/...#TC-2`，满足 `state-update`
  - `Scope`: 只允许 `tools/community/update_delivery_state.py`
  - `Evidence In`: 同上，消费 active plan/task 版本
  - `Evidence Out`: `developer-report.json`、`verify-result.json`、`fresh proving command` 完整输出
  - `Control Decision`: `CONTINUE`；若状态写入证据缺失则 `FIX`
- `T3`
  - `Requirement`: 同一 `phase-prd` / `UNIT-1`
  - `Goal`: 接通 readiness validation
  - `Acceptance Criteria`: 覆盖 `artifact://test-cases/...#TC-3`，满足 `readiness`
  - `Scope`: 只允许 `tools/community/validate_standard_chain_readiness.py`
  - `Evidence In`: 仅在 `T1/T2` 双完成后消费
  - `Evidence Out`: `developer-report.json`、`verify-result.json`、`fresh proving command` 完整输出
  - `Control Decision`: 依赖未解锁前保持 `BLOCK`，解锁后 `CONTINUE`

**delivery-state 更新口径**
- `status`: `READY`
- `control_action`: `CONTINUE`
- `current_stage`: 从 `KICKOFF_READY` 更新为 `TASK_EXECUTION`
- `tasks`:
  - 写入 `T1/T2/T3` 的 `runtime_status`
  - 标记 `T1/T2` 为本轮可派发
  - 标记 `T3` 为依赖锁定
- 记录当前消费的 `active_plan_version_ref` 与 `active_tasks_version_ref`
- 不写入交付门禁、review、qa 或 signoff 结果

**下一步**
- 先派发 `T1` 和 `T2` 并行执行
- 等待两项都回收 `developer-report.json` + `verify-result.json` 后，再解锁并派发 `T3`

本次按你的约束，不实际写文件、不启动服务、不提交、不调用 agent。