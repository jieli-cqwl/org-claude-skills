已按 `delivery-owner` 的前置条件核对过这套基线工件，当前可以做第一轮正向派发。

**结论**
- 可派发
- 首轮派发对象：`T1`、`T2`
- 次轮解锁条件：`T1` 和 `T2` 都产出 `developer-report.json` 与 `verify-result.json` 后，再放行 `T3`

**必需字段**
- `brief.json`
  - `goal`
  - `delivery_constraints`
- `phase-prd.json`
  - `phase_goal`
  - `entry_conditions`
  - `exit_conditions`
  - `unit_index`
  - `director_confirmation.status`
- `design.json`
  - `interface_boundary`
  - `quality_attributes`
  - `runtime_facts`
  - `interfaces`
- `plan.json`
  - `baseline_plan_version_ref`
  - `baseline_tasks_version_ref`
  - `planning_mode`
  - `plan_version`
  - `task_list`
  - `parallel_strategy`
  - `user_confirmation.status`
- `tasks.json`
  - `plan_version`
  - `tasks[*].task_id`
  - `tasks[*].batch`
  - `tasks[*].depends_on`
  - `tasks[*].scope_item_refs`
  - `tasks[*].test_refs`
  - `tasks[*].acceptance_targets`
- `unit-1/test-cases.json`
  - `test_cases`
  - `qa_handoff_contract`
  - `unit_coverage_view`
  - `design_gap_report.status`
  - `review_conclusion.verdict`
- `artifact-registry.json`
  - `scope_ref`
  - `registry_revision`
  - `active_revision_id`
  - `revisions[*].entries[*].artifact_path`
  - `revisions[*].entries[*].active_for_consumption`
- `delivery-state.json`
  - `active_plan_version_ref`
  - `active_tasks_version_ref`
  - `current_stage`
  - `status`
  - `control_action`
  - `tasks`

**第一轮派发合同**
- 派发批次：`batch_1`
- 派发任务：`T1`, `T2`
- `T1` 合同
  - `task_id`: `T1`
  - `task_title`: `build registry resolver dispatch path`
  - `scope_item_refs`: `tools/community/manage_artifact_registry.py`
  - `test_refs`: `artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#TC-1`
  - `acceptance_targets`: `registry-discovery`
  - 依赖：无
- `T2` 合同
  - `task_id`: `T2`
  - `task_title`: `build delivery-state update path`
  - `scope_item_refs`: `tools/community/update_delivery_state.py`
  - `test_refs`: `artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#TC-2`
  - `acceptance_targets`: `state-update`
  - 依赖：无
- `T3` 暂不派发
  - 解锁条件：`T1`、`T2` 同时具备完整开发证据后再进入 `batch_2`

**delivery-state 更新口径**
- 语义上从 `KICKOFF_READY` 进入“已派发第一批任务”
- `control_action` 维持 `CONTINUE`
- `status` 维持运行中口径，直到首批任务回收证据后再推进下一阶段
- `tasks` 应记录 `T1`、`T2` 的运行态占位和证据回收状态
- `active_plan_version_ref` 与 `active_tasks_version_ref` 继续指向当前冻结版本，不变

**下一步**
- 收集 `T1`、`T2` 的 `developer-report.json` 和 `verify-result.json`
- 校验两份任务证据是否满足 `RED → GREEN`、`SPEC_OK`、`2A_OK`、`2B_OK`、`2C_OK`、`fresh proving command`
- 满足后再解锁 `T3`

如果你愿意，我可以继续按这个 eval 的口径，把“第一轮派发输出模板”整理成一份更接近 canonical 记录的简版结果。