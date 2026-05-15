结论：不允许冻结给 design。`PM-003` 必须暂停在 PM 术语一致性门，不能交付 PRD/UNIT/AC。原因很硬：同一术语“会话”承载两个业务对象，AC、状态枚举、字段绑定和测试语义都会污染下游；把它藏进 AC 或写“实现时解释”就是 P0 风险。

**冲突对象**
- `UNIT-02` 的“会话”：三方平台回调形成的客户沟通线程。字段：`conversation_id / channel_user_id / callback_message_id`。状态：`new / active / closed`。
- `UNIT-04` 的“会话”：LLM/agent 调度过程中的上下文窗口与模型交互轮次。字段：`session_id / context_snapshot_id / tool_call_id`。状态：`planning / executing / waiting_tool / completed`。

冲突影响：design 无法判断 `session_id` 绑定客户沟通线程还是 agent 执行上下文；test-design 无法判断“关闭会话”是关闭客户沟通线程，还是终止 agent 上下文。

**建议裁决**
- 推荐术语拆分：
  - `UNIT-02` 改为“客户沟通线程”，状态名改为“沟通线程状态”。
  - `UNIT-04` 改为“Agent 执行上下文”或“Agent 运行上下文”，状态名改为“Agent 执行状态”。
  - 禁止在 AC 中继续裸写“会话状态”“关闭会话”。
- 待裁决问题包：
  - `session_id` 是否只允许指 Agent 执行上下文？若不是，必须另设客户沟通线程标识。
  - “关闭”动作是否只作用于客户沟通线程？Agent 上下文是否需要单独的“完成/终止/失败”语义？
  - 客户沟通线程关闭后，是否会终止正在运行的 Agent 上下文，还是仅停止后续消息归档/路由？

**Owner 与恢复**
- `owner`: product-manager 负责识别、阻断、提出术语拆分并修正 UNIT/AC；human/product owner 负责裁决业务口径；若裁决改变 Phase 范围或退出条件，回流 product-director。
- `resume_condition`: 术语 owner/human 明确口径后，PM 更新术语表、UNIT 闭环、AC、Verification Plan、Integration Context，并完成 M-S7 C8 术语一致性复检后，才允许重新进入冻结判断。
- `downstream_guard`: 在恢复条件满足前，design/test-design/tech-lead 不消费这些草稿，不设计数据模型、不写测试义务、不拆任务。

**Stage 1 边界**
本结论只针对 `PM-003` synthetic dry-run。未进入 `/Users/lijieli/project/qft-pai`，未做设计、技术方案、语言选型、任务拆解、开发、上线，也未冻结任何 PRD/UNIT/AC 给 design。