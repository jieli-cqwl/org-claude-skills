# TD-002 Synthetic Frozen Fixture

日期：2026-05-14

## 使用边界

本文件是 Stage 1 的 synthetic frozen design fixture，只用于测试 `test-design` 角色是否能建立 traceability、测试义务、证据期望和 QA handoff。

它不是 `qft-pai` 真实证据，不代表真实 `design.json` 已冻结，不允许作为语言选型、架构定版、任务拆解、代码重写或真实交付依据。

## 输入形态

- `input_origin`: `synthetic`
- `case`: `TD-002`
- `role`: `test-design`
- `status`: `frozen_for_eval_only`

## Product Baseline 摘要

Phase 目标：两周内完成一个单业务线 / 单渠道 / 单 bot / 单真实场景的端到端样板验证。

范围：三方消息回调进入后的单场景闭环：接收消息、前置处理、上下文取用、agent 调度、响应生成、可观察结果记录。

非目标：全渠道平台、通用 bot 管理、完整上下文平台、完整调度平台、观测平台、灰度平台、权限平台、计费平台、配置平台、语言选型和重写方案。

PM UNIT 来源：`docs/feature--agent-delivery-operating-system/dry-runs/pm-002/product-manager/output.md`

## UNIT 与 AC 摘要

- `UNIT-01` 消息接收边界：只允许已选渠道、已选 bot、样板场景消息进入。范围外或 bot 缺失必须记录并停止。
- `UNIT-02` 前置处理与场景确认：样板场景触发语和明确业务诉求可继续；空消息、无法判断场景、非样板诉求必须阻断或排除。
- `UNIT-03` 上下文取用：必要上下文存在则继续；关键上下文缺失或需要跨场景完整历史时停止。
- `UNIT-04` 单 bot agent 调度：只能调度本期单 bot；多 bot 诉求或目标 bot 不明必须停止。
- `UNIT-05` 响应生成：响应必须基于原消息和上下文；上下文不足或无法可靠生成时不得伪造结论。
- `UNIT-06` 可观察结果记录：每次成功、阻断或排除必须记录阶段、结果、原因和后续阶段是否执行。

## Synthetic Frozen Design

human 裁决在本 fixture 中被固定为：

- 采用方案 A：阶段门控闭环。
- 强制吸收状态证据底线：每一阶段都必须输出阶段状态、原因和证据摘要。
- 响应只生成给样板验收查看，不自动对外发送。
- 上下文不足阈值：缺少当前样板场景的关键业务上下文时必须停止，不进入调度。
- 系统失败处理：同一阶段允许一次受控重试；仍失败则记录 `failed` 并停止后续阶段。

## Design Interfaces

### `IF-01 message_callback_input`

输入：`channel_id`、`bot_id`、`message_id`、`message_text`、`received_at`。

输出：`accepted | excluded`、`reason`、`chain_id`。

错误/边界：非已选渠道、非本期 bot、缺失 bot、空 message 均不得进入后续阶段。

### `IF-02 preprocess_result`

输入：`chain_id`、`message_text`、`scenario_rule`。

输出：`passed | blocked | excluded`、`scenario_match`、`reason`。

错误/边界：非样板场景排除；无法判断场景阻断；包含样板和非样板诉求时仅保留样板处理依据。

### `IF-03 context_result`

输入：`chain_id`、`scenario_match`、`required_context_keys`。

输出：`available | blocked`、`context_snapshot_ref`、`missing_keys`、`reason`。

错误/边界：非必要上下文缺失不阻断；关键上下文缺失必须阻断；跨场景完整历史需求标记超范围。

### `IF-04 dispatch_result`

输入：`chain_id`、`bot_id`、`context_snapshot_ref`。

输出：`dispatched | blocked | failed`、`target_bot`、`reason`。

错误/边界：只能调度本期单 bot；多 bot 诉求或目标 bot 不明必须阻断。

### `IF-05 response_result`

输入：`chain_id`、`message_text`、`context_snapshot_ref`、`target_bot`。

输出：`generated | blocked | failed`、`response_preview`、`reason`。

错误/边界：不得生成与上下文冲突或无依据的答复；生成结果不自动对外发送。

### `IF-06 chain_record`

输入：各阶段输出。

输出：`recorded`、`final_status`、`stage_results`、`stop_stage`、`stop_reason`、`not_executed_stages`。

错误/边界：范围外、业务阻断、系统失败必须区分；任一阶段缺失不能作为可验收样板记录。

## Evidence Expectations

- 每个测试义务必须能追溯到 UNIT、AC 和接口。
- 每个阶段必须断言状态、原因、后续阶段是否继续。
- 成功链路必须证明 `UNIT-01` 到 `UNIT-06` 都有记录。
- 阻断链路必须证明阻断后后续阶段未执行。
- 响应生成只证明 `response_preview` 可验收查看，不证明已对外发送。

## 禁止范围

Test-design 不能执行 QA，不能批准发布，不能拆开发任务，不能补写产品或设计结论，不能基于本 fixture 宣称真实业务可交付。
