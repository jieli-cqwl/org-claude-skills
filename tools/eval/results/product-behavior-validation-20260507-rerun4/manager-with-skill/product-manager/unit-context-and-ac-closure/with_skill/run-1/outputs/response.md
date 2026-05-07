理解：目标是在 M-S0 已通过的前提下，基于 request review flow，为 Phase 1 输出一个可闭环交付的 UNIT，并把 AC 收到 `/design`、`/test-design` 可消费的粒度。操作对象是现有 `brief.json`、`phase-prd.json`、`UNIT-1.json`；本 eval 不写文件、不改既有 UNIT、不启动评审 agent、不跑交付 gate。

**门禁与边界**

- 已采信：Director handoff 已通过，Phase 1 目标锁定为“one confirmed business scenario 的 closed-loop request review flow”。
- 本轮只输出正文草案，不声明完整 Manager 完成。
- 不改写 Director locked fields、Phase 目标、范围、验收口径或 digest。
- Integration Context 只写业务模块、不可破坏行为、跨 UNIT 依赖和业务约束，不写技术实现路径。
- 若后续正式 handoff，仍必须补齐/验证：UNIT JSON 写入、PM ledger、M-S7 完整性扫描、M-S8 三方评审、M-G1 收口、M-S9 delivery confirmation 与 handoff gate。

**已冻结事实**

Phase 1 只做一个闭环请求评审流：请求人提交完整请求，授权评审人做决定，请求人可见最终状态和下一步；需覆盖成功、缺信息、拒绝状态；不做高级路由、广泛策略自动化、分析或无关流程重设计。

**PM 推荐 UNIT 草案**

```json
{
  "unit_id": "UNIT-1",
  "closure_definition": "输入/触发：业务请求人提交一个包含必需业务信息的请求；核心行为：授权评审人对该请求给出批准、拒绝或需补充信息的业务决定；可观察结果：请求人看到明确状态、原因或下一步，且未授权或信息不完整时不会产生虚假审批结果。",
  "priority": "P1",
  "priority_basis": "Phase 1 的价值来自首个端到端闭环；提交、评审决定和请求人状态可见性必须先闭合，后续高级路由或策略自动化才有稳定基础。",
  "dependencies": [],
  "integration_context": {
    "business_modules": [
      "request intake",
      "review decision",
      "requester status visibility"
    ],
    "protected_behaviors": [
      "Director-confirmed business outcomes remain unchanged",
      "business users must receive understandable review and confirmation responses"
    ],
    "cross_unit_dependencies": [],
    "business_constraints": [
      "only one request submission path, one reviewer decision path, and requester-visible status are in scope",
      "approval outcomes must stay explicit and business-readable"
    ]
  },
  "exclusions": [
    "advanced routing",
    "broad review policy automation",
    "analytics",
    "redesign of unrelated workflows",
    "multi-step escalation or reassignment flows"
  ]
}
```

**AC 收口**

```json
[
  {
    "ac_id": "AC-U1-01",
    "description": "authorized reviewer can approve a complete request",
    "example_input": "request includes required business purpose/details; assigned reviewer has decision authority; reviewer selects approve",
    "expected_result": "request status becomes approved; requester sees approved outcome and the next business action",
    "boundary_case": "approval is attempted only after all required request information is present",
    "failure_mode": "approval must not be shown if reviewer is unauthorized or required information is missing"
  },
  {
    "ac_id": "AC-U1-02",
    "description": "request missing required information remains unresolved with a clear correction path",
    "example_input": "request is submitted without one required business detail",
    "expected_result": "request is not treated as approved or rejected; requester sees what information is missing and what to do next",
    "boundary_case": "only optional details are absent, so the request can still proceed to reviewer decision",
    "failure_mode": "requester must not see ambiguous status such as completed, approved, or silently pending without correction guidance"
  },
  {
    "ac_id": "AC-U1-03",
    "description": "authorized reviewer can reject a request with requester-visible outcome",
    "example_input": "complete request is reviewed by authorized reviewer; reviewer selects reject with business reason",
    "expected_result": "request status becomes rejected; requester sees rejected outcome and the reason or closure guidance",
    "boundary_case": "rejection reason is short but business-readable",
    "failure_mode": "requester must not see approved next action or unclear ownership after rejection"
  },
  {
    "ac_id": "AC-U1-04",
    "description": "unauthorized reviewer cannot change request outcome",
    "example_input": "complete request exists; user without reviewer authority attempts to approve or reject",
    "expected_result": "request outcome remains unchanged; requester sees no false approval or rejection",
    "boundary_case": "authorized reviewer decision made later still produces the correct final requester-visible status",
    "failure_mode": "unauthorized action must not create, overwrite, or expose a final decision"
  }
]
```

**Verification Plan**

```json
[
  {
    "verification_type": "functional",
    "business_operation": "submit a complete request, approve it as an authorized reviewer, then inspect requester-visible status",
    "expected_observation": "approved status and next action are visible to requester",
    "evidence_target": "AC-U1-01; brief acceptance criterion"
  },
  {
    "verification_type": "boundary",
    "business_operation": "submit a request with required information missing",
    "expected_observation": "request remains unresolved and requester sees a specific correction prompt",
    "evidence_target": "AC-U1-02; risk: approval edge cases under-specified"
  },
  {
    "verification_type": "functional",
    "business_operation": "reject a complete request as an authorized reviewer",
    "expected_observation": "rejected status and business-readable reason or closure guidance are visible",
    "evidence_target": "AC-U1-03"
  },
  {
    "verification_type": "permission",
    "business_operation": "attempt to decide a request as an unauthorized reviewer",
    "expected_observation": "request outcome remains unchanged and requester sees no false final state",
    "evidence_target": "AC-U1-04"
  }
]
```

**Design Handoff**

```json
[
  {
    "decision_name": "request_state_representation",
    "candidate_options": [
      "show one current status plus next action",
      "show current status plus business reason where applicable",
      "show current status with lightweight decision history"
    ],
    "constraints": [
      "must not change confirmed business outcomes",
      "must remain understandable to business users",
      "must cover approved, rejected, missing-information, and unchanged unauthorized-attempt outcomes"
    ],
    "impacted_units": ["UNIT-1"],
    "design_handoff": "decide how requester-facing and reviewer-facing state transitions are represented without changing PM-confirmed behavior"
  }
]
```

**关键假设**

默认结论：把“缺信息”和“拒绝”作为同一个 UNIT 内的评审结果/边界状态处理，而不是拆成独立 Phase 或高级路由。

会改变结论的业务假设：如果“需补充信息”会触发新的审批轮次、重新分派 reviewer 或多级升级，那么当前 UNIT 边界不再闭合，需要回到 M-S4 重拆 UNIT；若这会改变 Phase 范围，则回退 `/product-director`。

**下一步**

本 eval 到正文草案为止。若进入正式 PM 交付，下一步应将上述字段写入 `UNIT-1.json`/台账，补 M-S5.5、M-S6、M-S7、M-S8、M-G1、M-S9；无未关闭 FAIL 且 handoff gate 通过后，才能交给 `/design` 和 `/test-design`。