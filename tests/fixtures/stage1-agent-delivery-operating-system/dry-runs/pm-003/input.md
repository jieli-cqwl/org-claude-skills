# PM-003 Input

日期：2026-05-14

## 输入来源

- `case_id`: `PM-003`
- `role`: `product-manager`
- `input_origin`: `synthetic`
- `stage`: Stage 1 internal training dry-run
- `scope_boundary`: 本输入只用于评估 product-manager 对术语冲突和冻结边界的处理能力，不进入真实 `qft-pai`、设计、技术方案、任务拆解、开发或上线。

## 上游 Director 边界

Phase 1 的目标是验证“单渠道客户消息进入后，一人 + agents 能按标准链路完成需求澄清、方案形成、任务交付和上线前验收的可信闭环”。

Phase 1 非目标：

- 不做全渠道平台化。
- 不承诺自动上线。
- 不把 mock 链路作为真实验收。
- 不允许角色在术语未定义时自行脑补业务含义。

## PM 草稿冲突

当前 UNIT 草稿里出现同一术语“会话”，但含义不一致：

- `UNIT-02 消息接收与会话归档`
  - “会话”指三方平台回调形成的一段客户沟通线程。
  - 示例字段：`conversation_id`、`channel_user_id`、`callback_message_id`。
  - 状态示例：`new / active / closed`。
- `UNIT-04 Agent 上下文会话构建`
  - “会话”指 LLM/agent 调度过程中的上下文窗口和模型交互轮次。
  - 示例字段：`session_id`、`context_snapshot_id`、`tool_call_id`。
  - 状态示例：`planning / executing / waiting_tool / completed`。

冲突表现：

- 两个 UNIT 都把“会话状态”写进 AC，但状态枚举不同。
- 下游 design 无法判断 `session_id` 应该绑定三方客户沟通线程，还是绑定 agent 执行上下文。
- 测试设计无法判断“关闭会话”是关闭客户沟通线程，还是终止 agent 上下文。

## 本 case 要求

Product-manager 必须识别术语漂移，暂停冻结 handoff，并把冲突路由给正确 owner 解决。

必须体现：

- 明确指出同一术语“会话”承载了两个不同业务对象。
- 不能把冲突藏进 AC 或靠“实现时解释”解决。
- 不能冻结 PRD/UNIT/AC 给 design。
- 必须给出可执行的术语拆分或待裁决问题包。
- 必须说明恢复条件：术语 owner/human 明确口径后才允许重新冻结。
