**结论：能。** DES-003 可以在 Stage 1 synthetic 范围内补成 test-design 可消费的设计产物：接口契约、失败语义、幂等、重试、降级、回滚、观测都能定义到测试可断言级别。但这不是可冻结真实 `design.json`，因为缺真实三方协议、代码/runtime 采证、SLA、人工接管流程与 human 裁决。

**全局契约**
- 链路标识：`trace_id` 内部链路；`correlation_id = channel + conversation_id`；`message_idempotency_key = channel + provider_message_id`；`response_idempotency_key = message_idempotency_key + response_version`。
- 状态语义：`accepted / duplicate_ignored / out_of_order_blocked / business_blocked / dependency_timeout / retry_pending / manual_handoff / dispatched / record_failed / completed`。
- 成功口径：三方回调被接收、前置处理通过、上下文可用、agent 有可信结果、响应回写成功、链路记录完整。缺任一项不得宣称闭环成功。
- 重试边界：只对超时、限流、临时 5xx、临时连接异常做有界重试；参数错误、业务阻断、重复消息、乱序消息不重试。
- 降级边界：默认不自动编造兜底回复；agent 超时或上下文不足进入人工接管或安全停止，兜底话术是否允许必须 PM/human 裁决。
- 回滚边界：响应回写前可停止、重建、标记无效；三方已接受响应后不能“撤回式回滚”，只能补偿记录、人工纠偏或发送更正，具体策略需 human 裁决。

**接口契约**
| IF | owner | input | output | error |
|---|---|---|---|---|
| `IF-001 CallbackIngress` | `CallbackAdapter` | `channel, provider_message_id, conversation_id, sender_id, provider_sent_at, payload, signature/verify_context` | `accepted, trace_id, message_idempotency_key, normalized_callback_ref` | `INVALID_SIGNATURE, MISSING_REQUIRED_FIELD, DUPLICATE_CALLBACK, OUT_OF_ORDER_CALLBACK, CALLBACK_ACK_TIMEOUT` |
| `IF-002 PreprocessMessage` | `MessagePreprocessor` | `trace_id, message_idempotency_key, raw_payload, channel, provider_sent_at, optional provider_sequence` | `normalized_message, risk_flags, preprocess_state` | `UNSUPPORTED_CHANNEL, EMPTY_MESSAGE, RISK_BLOCKED, DUPLICATE_IGNORED, OUT_OF_ORDER_BLOCKED` |
| `IF-003 BuildContext` | `ContextBuilder` | `trace_id, normalized_message, conversation_id, sender_id, required_context_refs` | `agent_context, context_completeness, context_state` | `CONTEXT_NOT_FOUND, CONTEXT_INSUFFICIENT, CONTEXT_TIMEOUT, CONTEXT_CONFLICT` |
| `IF-004 ExecuteAgent` | `AgentOrchestrator` | `trace_id, agent_context, bot_scope, timeout_budget, response_policy` | `agent_result, confidence/validity_flag, response_candidate` | `AGENT_NOT_FOUND, AGENT_TIMEOUT, AGENT_FAILED, UNSAFE_RESPONSE, LOW_CONFIDENCE_BLOCKED` |
| `IF-005 DispatchResponse` | `ResponseDispatcher` | `trace_id, response_idempotency_key, channel, conversation_id, response_candidate, dispatch_policy` | `dispatch_state, provider_response_id, dispatched_at` | `DISPATCH_TIMEOUT, DISPATCH_RETRY_EXHAUSTED, PROVIDER_REJECTED, DISPATCH_UNKNOWN_STATUS, DUPLICATE_RESPONSE_SUPPRESSED` |
| `IF-006 RecordChainEvent` | `ChainRecorder` | `trace_id, stage, state_from, state_to, input_digest, output_digest, error_code, attempt, idempotency_key` | `record_state, evidence_ref, recorded_at` | `RECORD_WRITE_FAILED, RECORD_CONFLICT, RECORD_TIMEOUT, RECORD_INCOMPLETE` |

**失败语义覆盖**
- 重复回调：同 `message_idempotency_key` 已存在则输出 `DUPLICATE_CALLBACK / duplicate_ignored`；不得再次调 agent，不得再次回写；记录 duplicate metric。
- 乱序：若 `provider_sequence/provider_sent_at` 早于当前会话已处理水位，输出 `OUT_OF_ORDER_CALLBACK / out_of_order_blocked`；不进入 agent。若三方没有可靠顺序字段，阻断为待裁决事实缺口。
- 三方超时：回调确认超出协议窗口则 `CALLBACK_ACK_TIMEOUT`；响应 API 超时则 `DISPATCH_TIMEOUT`，进入同 idempotency key 有界重试，未知状态先查证/人工接管，禁止盲目重复发送。
- agent 超时：输出 `AGENT_TIMEOUT`；可重试次数用配置裁决；耗尽后进入 `manual_handoff`，默认不生成无依据回复。
- 响应回写失败：可恢复错误进入 `retry_pending`；耗尽后 `DISPATCH_RETRY_EXHAUSTED`，记录人工接管；若三方已接受但本地未知，必须先对账，禁止双发。
- 链路记录失败：外部回写前记录失败则 fail-closed，不继续回写；外部已回写后记录失败则 `record_failed`，触发 P0 告警和补偿记录，闭环验收不得通过。

**可观测性**
- 指标：`callback_received_total, callback_duplicate_total, callback_out_of_order_total, stage_duration_ms, stage_error_total{stage,error_code}, agent_timeout_total, dispatch_retry_total, dispatch_failed_total, chain_record_failed_total, manual_handoff_total`。
- 结构化日志字段：`trace_id, correlation_id, channel, provider_message_id, conversation_id, stage, state_from, state_to, idempotency_key, attempt, error_code, retryable, degraded, rollback_boundary, evidence_ref`。
- 告警：任一 `chain_record_failed`；响应回写失败持续出现；agent timeout 超阈值；重复/乱序突增；`dispatch_unknown_status` 未在裁决时限内关闭。具体阈值归 tech-lead/ops 裁决。

**待裁决**
| issue | owner | resume_condition |
|---|---|---|
| 三方协议是否提供稳定 message_id、sequence、ack SLA | PM/human | 给出协议样例、排序字段和回调确认窗口 |
| 响应是否允许自动对外发送 | PM/human | 明确“仅生成待验收 / 自动回写 / 人工审核后回写” |
| agent timeout、重试次数、最大处理时长 | tech-lead + human | 冻结 timeout budget 和 retry budget |
| 人工接管入口、SLA、责任人 | PM/human | 明确接管队列、处理人和超时升级 |
| 已发送错误响应的补偿策略 | PM/human | 明确更正、撤回、标记无效或人工联系规则 |
| 观测告警阈值和接收人 | tech-lead/ops | 冻结阈值、告警渠道、处理 owner |

**test-design 可消费边界**
test-design 可以直接生成：正向闭环、重复回调、乱序回调、三方超时、agent 超时、回写失败、链路记录失败、幂等双发抑制、重试耗尽、人工接管、回写前后回滚边界、观测字段完整性用例。

test-design 不能脑补：真实三方字段名、真实 SLA、具体重试次数、人工接管流程、自动外发策略、已发送补偿方式。这些必须等 owner 裁决后再变成断言。

**Stage 1 synthetic 边界**
本输出只用于 DES-003 内部训练验收；未进入 `/Users/lijieli/project/qft-pai`，未做语言/框架/架构落地选择，未生成真实开发任务，未声明 Stage 2 或业务交付通过。