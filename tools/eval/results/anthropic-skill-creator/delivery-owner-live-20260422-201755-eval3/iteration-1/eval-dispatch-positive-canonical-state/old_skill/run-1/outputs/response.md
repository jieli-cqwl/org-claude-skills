基线可消费，允许进入第一轮正向派发。

**判断**
- `brief / phase-prd / design / plan / tasks / unit-1/test-cases / artifact-registry / delivery-state` 都存在
- `artifact-registry.active_revision_id = rev-dispatch-ready`
- `delivery-state.active_plan_version_ref` 与 `active_tasks_version_ref` 已对齐 `plan-v3 / tasks-v3`
- `phase-prd.director_confirmation.status = passed`
- 用户已确认进入交付

**本轮派发对象**
- `T1`：`build registry resolver dispatch path`
- `T2`：`build delivery-state update path`
- `batch_1` 并行派发
- `T3` 暂不派发，等 `T1 + T2` 都产出 `developer-report.json` 和 `verify-result.json` 后再解锁

**派发合同**
- `Requirement`
  - 来源：`sample-feature.phase-1.prd`
  - 任务：`T1` / `T2`
  - 约束：只消费当前 active canonical registry，不越过专家边界
- `Goal`
  - `T1`：证明 registry resolver 能走 active revision
  - `T2`：证明 delivery-state 更新路径能记录批次运行态
- `Acceptance Criteria`
  - `T1` 对应 `TC-1`
  - `T2` 对应 `TC-2`
  - 两个任务都必须产出各自的 `developer-report.json` 和 `verify-result.json`
  - 必须带 fresh proving command 的完整输出
- `Scope`
  - `T1` 只看 `tools/community/manage_artifact_registry.py`
  - `T2` 只看 `tools/community/update_delivery_state.py`
  - 共享文件未声明交集，不允许擅自扩大范围
- `Evidence In`
  - `plan_ref`: `artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
  - `tasks_ref`: `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`
  - `design_ref`: `artifact://design/sample-feature.phase-1.design@v1#interface-boundary`
  - `test_cases_ref`: `artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1`
  - `runtime_ref`: `artifact://phase/sample-feature.phase-1.delivery-state@v1`
- `Evidence Out`
  - `T1` 输出：`developer-report.json`、`verify-result.json`
  - `T2` 输出：`developer-report.json`、`verify-result.json`
- `Control Decision`
  - 当前派发动作：`CONTINUE`
  - 若发现范围冲突、证据缺失或计划版本不一致：改为 `BLOCK`
  - 若实现可复现但可修：改为 `FIX`

**delivery-state 更新口径**
- `active_plan_version_ref`：保持 `artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
- `active_tasks_version_ref`：保持 `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`
- `current_stage`：从 `KICKOFF_READY` 推进为“batch_1 已派发 / 开发进行中”
- `status`：从 `READY` 推进为“进行中”
- `control_action`：`CONTINUE`
- `tasks`
  - 记录 `T1`、`T2` 为已派发
  - 记录并行批次 `batch_1`
  - 记录 `batch_2` 的解锁条件：`T1` 和 `T2` 都补齐 `developer-report.json` + `verify-result.json`

**下一步**
- 等待 `T1`、`T2` 的开发与验证证据回流
- 回流后先判定是否满足 `batch_2` 解锁条件，再派发 `T3`