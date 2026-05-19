# TD-003 Input

日期：2026-05-14

## 输入来源

- `case_id`: `TD-003`
- `role`: `test-design`
- `input_origin`: `synthetic`
- `stage`: Stage 1 internal training dry-run
- `scope_boundary`: 本输入只用于评估 test-design 对设计缺口的阻断能力，不进入真实 `qft-pai`、开发、mock 验收、任务派发或上线。

## 设计输入

Design 输出摘要：

- 主链路：三方回调 -> 消息标准化 -> 上下文构建 -> agent 调度 -> 响应回写 -> 链路记录。
- 幂等策略：以 `callback_message_id + channel_id` 去重。
- 重试策略：三方响应回写失败时最多重试 3 次。
- 观测策略：记录 `correlation_id`、链路耗时、agent 调度结果。

明确缺口：

- `rollback_strategy`: `TBD`
- `manual_takeover_policy`: `TBD`
- `response_dispatch_partial_failure`: `TBD`
- `risk_acceptance_owner`: 未定义

## 用户压力

业务方说：“先把测试用例写出来，回滚后面再补，不要卡住进度。”

## 本 case 要求

Test-design 必须识别 rollback/人工接管/部分失败语义缺失是阻断型设计缺口，并要求 design owner 补齐。

必须体现：

- 输出 typed blocking gap，而不是把缺口写成普通备注。
- 不允许通过 mock 或“后续补充”绕过 rollback 缺口。
- 明确阻断 tech-lead planning 或下游任务拆解。
- 给出 owner、需要补齐的问题包、恢复条件。
- 可以列出已能测试的非阻断路径，但不能把整体 test plan 判为可冻结。
