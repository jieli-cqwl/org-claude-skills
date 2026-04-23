理解：这次不是实际派发执行，而是基于 `sample-feature/phase-1` 里已冻结的 canonical 工件，给出第一轮正向派发所需的合同、`delivery-state` 更新口径和下一步；不写文件、不启动服务、不调用 agent。

**结论**
- 可以正向派发。
- canonical 基线齐全，且都指向同一 `phase-1`，`artifact-registry.json` 的 `active_revision_id=rev-dispatch-ready` 可消费。
- 当前应进入 `current_stage=TASK_EXECUTION`，消费 `plan-v3 / tasks-v3`。
- 本次只做派发口径输出，不实际改写 `delivery-state.json`。

**已核对的 canonical 证据**
- [brief.json](/private/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-_s9uihjq/tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature/brief.json)
- [phase-prd.json](/private/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-_s9uihjq/tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature/phase-1/phase-prd.json)
- [design.json](/private/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-_s9uihjq/tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature/phase-1/design.json)
- [plan.json](/private/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-_s9uihjq/tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature/phase-1/plan.json)
- [tasks.json](/private/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-_s9uihjq/tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature/phase-1/tasks.json)
- [unit-1/test-cases.json](/private/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-_s9uihjq/tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature/phase-1/unit-1/test-cases.json)
- [artifact-registry.json](/private/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-_s9uihjq/tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature/phase-1/artifact-registry.json)
- [delivery-state.json](/private/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-_s9uihjq/tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature/phase-1/delivery-state.json)

**第一轮正向派发合同**
- `Requirement`
  - 来源：`sample-feature.phase-1`
  - 约束：只从 active canonical registry 派发，保持 developer / review / qa 专家边界
  - Task：`T1`、`T2`
- `Goal`
  - `T1`：打通 registry resolver dispatch path
  - `T2`：打通 delivery-state update path
- `Acceptance Criteria`
  - `T1` 对齐 `TC-1`
  - `T2` 对齐 `TC-2`
  - 两个 Task 都要交付 `developer-report.json`、`verify-result.json`、`fresh proving command` 完整输出
- `Scope`
  - `T1` 允许修改：`tools/community/manage_artifact_registry.py`
  - `T2` 允许修改：`tools/community/update_delivery_state.py`
  - 禁止触碰：`tools/community/validate_standard_chain_readiness.py`、`plan.json`、`tasks.json`、`design.json`、`test-cases.json`、`brief.json`
  - 共享文件：无
- `Evidence In`
  - `plan_version_ref = artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
  - `tasks_version_ref = artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`
  - `design_ref = artifact://design/sample-feature.phase-1.design@v1`
  - `runtime_ref = 当前 delivery-state.json`
  - `test_cases_ref = artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1`
- `Evidence Out`
  - `developer-report.json`
  - `verify-result.json`
  - `fresh proving command` 完整输出
  - 变更文件列表
- `Control Decision`
  - `CONTINUE`：证据齐全且任务验收满足
  - `FIX`：可定位、可回归的问题
  - `BLOCK`：证据缺失、边界冲突、或当前批次未解锁

**批次与并行口径**
- `current_batch = batch_1`
- `batch_1 = [T1, T2]`
- 并行依据：`T1` 与 `T2` 文件范围互不重叠，均无 `depends_on`
- 解锁条件：`batch_2` 仅在 `T1` 和 `T2` 都产出 `developer-report.json` 与 `verify-result.json` 后解锁
- `batch_2 = [T3]`，当前不派发

**任务运行态口径**
- `T1`
  - `runtime_status = READY_TO_DISPATCH`
  - `owner = developer`
  - `current_batch = 1`
  - `next_action = 派发开发执行并要求回传 developer-report / verify-result / fresh proving evidence`
- `T2`
  - `runtime_status = READY_TO_DISPATCH`
  - `owner = developer`
  - `current_batch = 1`
  - `next_action = 派发开发执行并要求回传 developer-report / verify-result / fresh proving evidence`
- `T3`
  - `runtime_status = LOCKED_BY_DEPENDENCY`
  - `owner = developer`
  - `current_batch = 2`
  - `next_action = 等待 T1、T2 完成后再派发`

**delivery-state 更新口径**
- `active_plan_version_ref = artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
- `active_tasks_version_ref = artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`
- `current_stage = TASK_EXECUTION`
- `status = READY`
- `control_action = CONTINUE`
- `tasks`
  - 写入 `T1`、`T2` 为 `IN_FLIGHT` 前的派发态或等价 runtime 态
  - `T3` 标记为 `WAITING_DEPENDENCIES`
- `delivery-state.json` 的判定口径
  - 只消费当前 active registry 和当前 plan/tasks 版本
  - 不允许用口头确认替代 canonical 运行态
  - 不进入 review / QA 门禁阶段

**下一步**
1. 按上述合同派发 `T1` 和 `T2`
2. 等待两项任务各自返回 `developer-report.json / verify-result.json / fresh proving command` 完整证据
3. 再决定是否解锁 `T3`

如果你要，我下一条可以继续把这份“第一轮派发”整理成更接近 delivery-owner 投影视图的结构化 JSON 草案。