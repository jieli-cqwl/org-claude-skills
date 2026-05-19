# E2E-RESUME-001 Chain Output

case_id: E2E-RESUME-001
input_origin: synthetic_resume_package
chain_status: pass_to_pause
terminal_owner: human/business-owner

## Role Order

1. product-director
2. product-manager
3. design
4. test-design
5. tech-lead
6. delivery-owner

## Product Director

artifact: confirmed_brief
status: continue

结论：恢复包足以从 Director 暂停点恢复到 PM。

已冻结：

- root_problem: 当前要验证一人 + agents 是否能处理“客户消息进入后生成建议回复”的端到端闭环。
- phase_1_goal: 单渠道、单文本消息类型、只生成建议回复、不自动外发。
- success_criteria: 意图识别、上下文摘要、agent 建议回复、trace id、人工确认状态、失败人工接管。
- non_goals: 不处理附件/语音/图片/复杂工单；不做真实上线；不做语言选型；不做自动外发。
- risk_boundary: 当前只有训练 eval 授权，真实执行和风险接受必须由 human/business owner 另行确认。

handoff_to: product-manager

## Product Manager

artifact: phase_prd_and_units
status: continue

Phase 拆分：

- UNIT-1 callback intake: 接收单类文本消息回调，生成 trace id，记录原始输入摘要。
- UNIT-2 context assembly: 根据客户、会话、历史摘要组装上下文；上下文不足时输出补充信息请求。
- UNIT-3 agent suggestion: 调用 agent 生成建议回复，保留决策摘要和置信说明。
- UNIT-4 human confirmation handoff: 将建议回复交给人工确认；当前禁止自动外发。
- UNIT-5 failure takeover: 外部依赖失败、上下文不足或 agent 不确定时进入人工接管。

AC 摘要：

- 每个 UNIT 都必须有成功路径、失败路径、证据字段和排除项。
- “会话”术语固定为客户沟通线程；agent 内部上下文称为 execution_context。

handoff_to: design

## Design

artifact: design_interface_contract
status: continue

接口契约：

- IF-CALLBACK-IN input: channel_message_id、customer_id、conversation_thread_id、message_text、received_at；output: trace_id、normalized_message；error_codes: INVALID_PAYLOAD、DUPLICATE_MESSAGE。
- IF-CONTEXT-BUILD input: trace_id、customer_id、conversation_thread_id；output: execution_context、context_summary；error_codes: CONTEXT_NOT_FOUND、CONTEXT_TIMEOUT。
- IF-AGENT-DISPATCH input: trace_id、execution_context、message_text；output: suggestion_text、decision_summary、confidence；error_codes: AGENT_TIMEOUT、LOW_CONFIDENCE。
- IF-HUMAN-HANDOFF input: trace_id、suggestion_text、decision_summary；output: confirmation_status、operator_id；error_codes: HANDOFF_FAILED。

工程约束：

- idempotency: channel_message_id + customer_id 去重。
- retry: 外部依赖只允许有界重试，失败进入人工接管。
- degrade: context 不足时不调用自动回复链路，只输出补充信息请求。
- rollback: 未自动外发，回滚点为停止建议生成并保留人工处理入口。
- observability: trace_id 贯穿 callback、context、agent、handoff。

handoff_to: test-design

## Test Design

artifact: test_cases_and_handoff
status: continue

coverage:

- TDO-01 callback 正常文本消息进入后生成 trace id。
- TDO-02 重复 channel_message_id 被幂等处理。
- TDO-03 context 命中时 agent 收到 execution_context。
- TDO-04 context 不足时输出补充信息请求，不生成伪建议。
- TDO-05 agent timeout 进入人工接管。
- TDO-06 low confidence 进入人工确认，不自动外发。
- TDO-07 human handoff 失败时保留待处理状态和错误码。
- TDO-08 trace_id 覆盖四个接口。

design_gap_report:

- status: NO_GAPS
- gaps: []

handoff_to: tech-lead

## Tech Lead

artifact: plan_and_tasks
status: continue

planning_strategy:

- readiness_gate: TL-RDY-01 验证 synthetic fixture、接口字段、错误码和 trace id 约定齐备。
- batch_1: T1 callback intake + idempotency，证明消息入口和 trace id。
- batch_2: T2 context assembly，证明 context_summary 和不足分支。
- batch_3: T3 agent dispatch + failure takeover，证明 timeout/low confidence。
- batch_4: T4 human handoff，证明不自动外发和人工确认状态。

task_contract:

- 每个 task 必须带 unit_refs、design_refs、test_refs、acceptance_targets、proving_command、evidence_target、mock_boundary_note。
- mock 只允许用于外部依赖替身，最终验收必须保留真实接口 evidence target。
- stop_condition: 任一 task 缺 trace evidence、错误码证据或人工确认状态，暂停给 delivery-owner。

handoff_to: delivery-owner

## Delivery Owner

artifact: delivery_decision
status: pass_to_pause

decision:

- accepted_inputs: confirmed_brief、phase_prd_and_units、design_interface_contract、test_cases_and_handoff、plan_and_tasks。
- dry_run_dispatch_ready: true。
- first_task_packet: T1 callback intake + idempotency。
- task_packet_gate: DISPATCH_READY。
- real_execution_allowed: false。
- reason: 当前只有 Stage 1 synthetic eval 授权，没有真实项目采证、执行环境、上线、提交、灰度或风险接受授权。

resume_condition: human/business owner 明确授权 Stage 2 真实样板、执行环境、风险接受边界、灰度/回滚 owner 后，才能进入真实采证和派发。
