理解：本 eval 只基于 `sample-feature` 的 canonical JSON，按 `shared/skills/delivery-owner/SKILL.md` 做第一轮 delivery-owner 正向派发口径输出；不写文件、不启服务、不提交、不调用 agent、不进入 Phase 3。

**基线检查**

- 已读取并遵循 `delivery-owner` skill：当前角色只负责调度、状态同步、证据消费和控制裁决，不直接实现代码，不替代 developer/review/qa/fix。
- active registry 已确认包含并激活：`brief v1`、`phase-prd v1`、`design v1`、`plan plan-v3`、`tasks tasks-v3`、`test-cases v1`、`delivery-state v1`。
- 不阻断为缺工件：canonical 工件齐全，且来自 `artifact-registry.json.active_revision_id = rev-dispatch-ready`。
- 用户已确认进入交付，因此流程从 `KICKOFF_READY` 推进到 Phase 2 `TASK_EXECUTION`。
- 不进入 Phase 3：尚无每个 Task 的 `developer-report.json / verify-result.json`。
- 不 commit：未到签收阶段，也没有 `user-decision.json sign_off_status=SIGNED_OFF`。

**批次裁决**

- `active_plan_version_ref`: `artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version`
- `active_tasks_version_ref`: `artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry`
- `planning_mode`: `standard-chain`
- `control_action`: `CONTINUE`
- `current_stage`: `TASK_EXECUTION`
- `batch 1`: `T1` 与 `T2` 可并行派发，因为 `depends_on=[]` 且 `shared_files=[]`
- `batch 2`: `T3` 暂不派发；必须等待 `T1`、`T2` 均产出并通过 `developer-report.json` 与 `verify-result.json`

**派发合同：T1**

- Requirement: `UNIT-1 / T1 / build registry resolver dispatch path`，来源于 `phase-prd` 的 Phase 目标与 `brief` 的 active canonical registry 约束。
- Goal: 实现 registry resolver dispatch path，支撑从 active artifact registry 发现可消费工件。
- Acceptance Criteria: `TC-1 registry resolver returns active artifact path`；`acceptance_targets=["registry-discovery"]`。
- Scope: 允许范围 `tools/community/manage_artifact_registry.py`；只读 `brief/phase-prd/design/plan/tasks/test-cases/delivery-state/artifact-registry`；无共享文件；禁止触碰计划外文件。
- Evidence In: `plan-v3`、`tasks-v3`、`design interface-boundary`、`test_ref TC-1`、当前 `delivery-state KICKOFF_READY/READY`、无前置 Task。
- Evidence Out: `phase-1/unit-1/tasks/T1/developer-report.json`、`phase-1/unit-1/tasks/T1/verify-result.json`；必须包含 RED→GREEN、SPEC_OK、2A_OK、2B_OK、2C_OK、fresh proving command 的完整命令、stdout、stderr、exit code。
- Control Decision: 当前派发为 `CONTINUE`；若证据缺失或命令输出不完整则 `BLOCK`；若范围内可复现失败则 `FIX`；若需改范围、设计或 AC 则 `REPLAN`；若需用户或上游裁决则 `ESCALATE`。

**派发合同：T2**

- Requirement: `UNIT-1 / T2 / build delivery-state update path`，来源于 Phase 目标与 delivery-state 运行态记录要求。
- Goal: 实现 delivery-state update path，能记录 batch runtime status。
- Acceptance Criteria: `TC-2 delivery-state update records batch runtime status`；`acceptance_targets=["state-update"]`。
- Scope: 允许范围 `tools/community/update_delivery_state.py`；只读 canonical JSON；无共享文件；禁止触碰计划外文件。
- Evidence In: `plan-v3`、`tasks-v3`、`design interface-boundary`、`test_ref TC-2`、当前 `delivery-state KICKOFF_READY/READY`、无前置 Task。
- Evidence Out: `phase-1/unit-1/tasks/T2/developer-report.json`、`phase-1/unit-1/tasks/T2/verify-result.json`；必须包含 RED→GREEN、SPEC_OK、2A_OK、2B_OK、2C_OK、fresh proving command 的完整命令、stdout、stderr、exit code。
- Control Decision: 当前派发为 `CONTINUE`；若证据缺失或命令输出不完整则 `BLOCK`；若范围内可复现失败则 `FIX`；若需改范围、设计或 AC 则 `REPLAN`；若需用户或上游裁决则 `ESCALATE`。

**T3 解锁口径**

- `T3 / wire readiness validation` 当前不派发。
- 解锁条件：同时存在并通过 `T1 developer-report.json`、`T1 verify-result.json`、`T2 developer-report.json`、`T2 verify-result.json`。
- 解锁后才可派发 Scope `tools/community/validate_standard_chain_readiness.py`，对应 `TC-3 readiness validation consumes updated registry and state`。
- 任一前置证据缺失、stale、未包含完整 fresh proving command 输出，T3 保持等待，不得提前进入开发或验证。

**delivery-state 更新口径**

```json
{
  "active_plan_version_ref": "artifact://plan/sample-feature.phase-1.plan@plan-v3#plan-version",
  "active_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v3#task-registry",
  "current_stage": "TASK_EXECUTION",
  "status": "IN_PROGRESS",
  "control_action": "CONTINUE",
  "tasks": [
    {
      "task_id": "T1",
      "runtime_status": "DISPATCHED",
      "owner": "developer",
      "current_batch": 1,
      "next_action": "await developer-report.json and verify-result.json with full fresh proving command output"
    },
    {
      "task_id": "T2",
      "runtime_status": "DISPATCHED",
      "owner": "developer",
      "current_batch": 1,
      "next_action": "await developer-report.json and verify-result.json with full fresh proving command output"
    },
    {
      "task_id": "T3",
      "runtime_status": "WAITING_DEPENDENCIES",
      "owner": "delivery-owner",
      "current_batch": 2,
      "next_action": "unlock only after T1 and T2 both have developer-report.json and verify-result.json"
    }
  ]
}
```

**阻断条件**

- T1/T2 任一报告缺失、未含完整 proving 输出、未覆盖 RED→GREEN 或 SPEC/2A/2B/2C：阻断 T3。
- 发现计划外文件修改、未声明共享文件冲突、需要改变 Phase 目标/AC/设计边界：`REPLAN` 或 `ESCALATE`。
- 连续 Task 进入 `BLOCKED` 或修复循环超过 skill 熔断上限：暂停推进并交用户裁决。

**下一步**

并行派发 `T1`、`T2` 给 developer；delivery-owner 等待并消费两组 `developer-report.json / verify-result.json`。两者证据齐全且通过后，更新 `delivery-state` 将 T3 从 `WAITING_DEPENDENCIES` 解锁为可派发。当前不得进入 Phase 3、不得生成签收包、不得提交。