结论：不允许进入 `tech-lead planning`。TD-003 的正确状态是 `BLOCKED / stop handoff`。证据很直接：输入明确把 `rollback_strategy`、`manual_takeover_policy`、`response_dispatch_partial_failure` 标为 `TBD`，`risk_acceptance_owner` 未定义；case 要求这些必须作为阻断型设计缺口处理，不能用 mock 或“后续补充”绕过。`test-design` hard gate 也规定任一 `blocking=true` typed gap 必须停止交给 `/tech-lead`。证据：[input.md](/Users/lijieli/org-claude-skills/docs/feature--agent-delivery-operating-system/dry-runs/td-003/input.md:24)、[input.md](/Users/lijieli/org-claude-skills/docs/feature--agent-delivery-operating-system/dry-runs/td-003/input.md:35)、[SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/test-design/SKILL.md:21)。

**Typed Blocking Gap**

| 字段 | 内容 |
|---|---|
| 缺口类型 | `DESIGN_GAP`，`blocking=true` |
| 证据 | `rollback_strategy: TBD`、`manual_takeover_policy: TBD`、`response_dispatch_partial_failure: TBD`、`risk_acceptance_owner: 未定义`；TD-003 明确要求阻断 tech-lead planning。 |
| 影响 | 无法冻结失败路径、回滚断言、人工接管入口、部分失败终态、风险签收证据。继续写完整 test plan 会让开发任务和 QA 验收建立在不可验证前提上。 |
| owner | `design owner` 主责；若风险接受 owner 属业务裁决，应由 design owner 明确路由到对应 human/product/delivery owner。 |
| next_action | 补齐设计问题包：回滚触发条件、回滚范围、状态恢复/补偿、人工接管触发与处理状态、响应回写部分失败终态、重试耗尽后的用户/系统行为、观测与审计证据、风险接受 owner。 |
| resume_condition | `design.json` 或等价 canonical design 更新完成，以上字段不再是 `TBD`，并给出可追踪 design refs、error/status semantics、verification mapping；`test-design` 重新做 gap routing 后确认无 `blocking=true` gap。 |

**可先列为草稿的非阻断测试**

| 草稿项 | 状态 |
|---|---|
| 主链路成功路径：三方回调 -> 标准化 -> 上下文 -> agent 调度 -> 响应回写 -> 链路记录 | 可列草稿，不冻结 |
| 幂等：`callback_message_id + channel_id` 重复回调只处理一次 | 可列草稿，不冻结 |
| 响应回写失败的重试次数：最多 3 次，记录尝试与结果 | 可列草稿，但“3 次后终态”必须等待设计 |
| 观测：`correlation_id`、链路耗时、agent 调度结果可追踪 | 可列草稿，不冻结 |

**必须等 Design 补齐后才能冻结**

| 测试义务 | 阻断原因 |
|---|---|
| 回滚测试 | 缺 rollback trigger、scope、state restore、compensation、audit evidence |
| 人工接管测试 | 缺 takeover trigger、owner、处理状态、SLA/队列、用户可见语义 |
| 部分失败测试 | 缺 response dispatch partial failure 的终态、恢复路径、重复/补偿语义 |
| 风险接受与交付签收测试 | `risk_acceptance_owner` 未定义 |
| 整体 `test plan`、`qa_handoff_contract`、`test_ref` freeze | 存在 blocking design gap，不能冻结 |

**下游保护边界**

`tech-lead`：只能接收 `BLOCKED` 结论和 gap 包；不得拆开发任务、不得排期、不得把缺口改写成普通 readiness task、不得用 mock-only 作为验收路径。

`delivery-owner`：不得派发 developer/QA，不得推进 mock 验收、提测、上线或风险接受；只能跟踪 owner、next_action、resume_condition，并在设计补齐后重新进入链路。

**Stage 1 Synthetic 边界**

本次仅是 Stage 1 internal training dry-run，输入来源是 `synthetic`。不进入 `/Users/lijieli/project/qft-pai`，不证明真实业务已交付，不替代 Stage 2 的真实集成、灰度、回滚和上线验收，也不允许把整体 test plan 判为可冻结。