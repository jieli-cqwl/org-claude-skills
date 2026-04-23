已确认：当前 workspace 里 `brief.json / phase-prd.json / design.json / plan.json / tasks.json / unit-1/test-cases.json / artifact-registry.json / delivery-state.json` 都在同一 Phase-1，且用户已确认进入交付，所以可以做第一轮正向派发。

**派发对象**
- `T1`：build registry resolver dispatch path
- `T2`：build delivery-state update path
- `T3`：暂不派发，等待 `T1 + T2` 都产出 `developer-report.json` 和 `verify-result.json` 后解锁

**必需字段**
- `requirement_ref`
  - `artifact://phase-prd/sample-feature.phase-1.prd@v1#phase-goal`
  - `artifact://brief/sample-feature.brief@v1#goal-001`
- `goal_ref`
  - `artifact://phase-prd/sample-feature.phase-1.prd@v1#phase-goal`
- `acceptance_criteria_ref`
  - `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-T1`
  - `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-T2`
  - `artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#TC-1`
  - `artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#TC-2`
- `scope_ref`
  - `tools/community/manage_artifact_registry.py`
  - `tools/community/update_delivery_state.py`
- `design_ref`
  - `artifact://design/sample-feature.phase-1.design@v1#interface-boundary`
  - `artifact://design/sample-feature.phase-1.design@v1#key-decisions`
- `runtime_ref`
  - `artifact://phase-prd/sample-feature.phase-1.prd@v1#phase-goal`
  - `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`
  - `artifact://phase/sample-feature.phase-1.delivery-state@v1#current-stage`
- `plan_version_ref`
  - `artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`

**派发合同**

`T1`
- Requirement：基于 active registry 解析可消费 artifact 路径，保证 dispatch 只读 canonical registry。
- Goal：让 registry resolver 能稳定返回 active artifact path。
- Acceptance Criteria：
  - 对应 `TC-1`
  - `registry-discovery` 可验证
  - 仅允许触碰 `tools/community/manage_artifact_registry.py`
- Scope：
  - 可改：`tools/community/manage_artifact_registry.py`
  - 只读：`brief.json / phase-prd.json / design.json / plan.json / tasks.json / unit-1/test-cases.json / artifact-registry.json / delivery-state.json`
- Evidence In：
  - `artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
  - `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-T1`
  - `artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#TC-1`
  - 当前 `delivery-state.json`
- Evidence Out：
  - `developer-report.json`
  - `verify-result.json`
  - fresh proving command 完整输出
- Control Decision：
  - `CONTINUE`：registry path 与 active revision 一致，且证明输出完整
  - `FIX`：实现与 `TC-1` 不一致但可局部修复
  - `BLOCK`：发现 scope 外文件依赖或 active registry 不可解析

`T2`
- Requirement：把 batch / runtime 状态写入 delivery-state，形成可追踪的交付运行态。
- Goal：让 delivery-state update path 能记录 batch runtime status。
- Acceptance Criteria：
  - 对应 `TC-2`
  - `state-update` 可验证
  - 仅允许触碰 `tools/community/update_delivery_state.py`
- Scope：
  - 可改：`tools/community/update_delivery_state.py`
  - 只读：`brief.json / phase-prd.json / design.json / plan.json / tasks.json / unit-1/test-cases.json / artifact-registry.json / delivery-state.json`
- Evidence In：
  - `artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
  - `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-T2`
  - `artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#TC-2`
  - 当前 `delivery-state.json`
- Evidence Out：
  - `developer-report.json`
  - `verify-result.json`
  - fresh proving command 完整输出
- Control Decision：
  - `CONTINUE`：状态更新路径正确写入 batch/runtime 信息
  - `FIX`：状态字段或写入时机不符合 `TC-2`
  - `BLOCK`：与 registry / state 共享边界冲突，或依赖缺失

**delivery-state 更新口径**
- 当前轮次只做“正向派发登记”，不写最终完成态。
- 运行态建议从 `KICKOFF_READY / READY / CONTINUE` 过渡到“已派发第一批任务”的阶段标记。
- 需要记录的最小口径：
  - 当前批次：`batch_1`
  - 已派发任务：`T1, T2`
  - 批次状态：`DISPATCHED` 或等价的“已派发未完成”状态
  - 下一动作：等待 `T1/T2` 的 `developer-report.json` 和 `verify-result.json`
  - `T3` 状态：`LOCKED_BY_DEPENDENCY`
- 这次 eval 不要求实际写 `delivery-state.json`，只需输出上述更新语义。

**下一步**
- 等待 `T1` 和 `T2` 的开发与验证证据。
- 两个任务都回收后，再判断是否解锁 `T3`。
