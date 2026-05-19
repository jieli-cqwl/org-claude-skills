# TL-002 Synthetic Planning Fixture

日期：2026-05-14

## 使用边界

本文件是 Stage 1 的 synthetic planning fixture，只用于测试 `tech-lead` 角色是否能在上游齐备但存在高风险未知项时，产出 readiness task、风险驱动批次、依赖和 stop condition。

它不是 `qft-pai` 真实证据，不代表真实 `plan.json` 或 `tasks.json` 已冻结，不允许作为语言选型、真实任务拆解、代码重写或交付依据。

## 输入形态

- `input_origin`: `synthetic`
- `case`: `TL-002`
- `role`: `tech-lead`
- `status`: `frozen_for_eval_only`

## 上游产物

- PM 输出：`docs/feature--agent-delivery-operating-system/dry-runs/pm-002/product-manager/output.md`
- Design fixture：`docs/feature--agent-delivery-operating-system/dry-runs/td-002/input.md`
- Test-design 输出：`docs/feature--agent-delivery-operating-system/dry-runs/td-002/test-design/output.md`
- Test-design evaluator：`docs/feature--agent-delivery-operating-system/dry-runs/td-002/test-design/evaluator-output.md`

## 已确认范围

Phase 目标：两周内完成一个单业务线 / 单渠道 / 单 bot / 单真实场景的端到端样板验证。

业务闭环：三方消息回调进入后，完成接收边界、前置处理、上下文取用、单 bot 调度、响应生成、可观察结果记录。

冻结设计假设：

- 阶段门控闭环。
- 每阶段输出状态、原因和证据摘要。
- 响应只生成给样板验收查看，不自动对外发送。
- 关键上下文缺失必须停止，不进入调度。
- 系统失败同阶段允许一次受控重试；仍失败则记录 `failed` 并停止后续阶段。

## Test Obligations

Tech-lead 必须消费 `TDO-01` 到 `TDO-13`：

- `TDO-01` 正向入口：`UNIT-01 AC-01 / IF-01`
- `TDO-02` 入口排除：`UNIT-01 AC-02 / IF-01 / IF-06`
- `TDO-03` 前置通过：`UNIT-02 AC-01 / IF-02`
- `TDO-04` 场景排除/阻断：`UNIT-02 AC-02 / IF-02 / IF-06`
- `TDO-05` 上下文可用：`UNIT-03 AC-01 / IF-03`
- `TDO-06` 上下文阻断：`UNIT-03 AC-02 / IF-03 / IF-06`
- `TDO-07` 单 bot 调度：`UNIT-04 AC-01 / IF-04`
- `TDO-08` 调度阻断：`UNIT-04 AC-02 / IF-04 / IF-06`
- `TDO-09` 响应生成：`UNIT-05 AC-01 / IF-05`
- `TDO-10` 生成受阻/失败：`UNIT-05 AC-02 / IF-05 / IF-06`
- `TDO-11` 成功记录：`UNIT-06 AC-01 / IF-06`
- `TDO-12` 阻断/排除/失败记录：`UNIT-06 AC-02 / IF-06`
- `TDO-13` 重试与补偿边界：`frozen design / IF-01~IF-06`

## 高风险未知项

`GAP-TD002-01`：缺真实执行数据值，例如选定 `channel_id`、`bot_id`、样板触发语、关键上下文 keys。

`GAP-TD002-02`：缺 `chain_record` 的真实落点和查询证据入口。

这两个 gap 在 TD-002 中被判定为非阻断，但 tech-lead 必须把它们转成 readiness task 或 stop condition，不得把它们埋进普通开发任务。

## TL-002 期望

必须输出：

- readiness task。
- 风险驱动批次。
- 串并行依赖。
- 每个 task 的上游追溯、test refs、证据路径和 stop condition。
- 不允许平均拆任务。
- 不允许选择语言、框架、数据库、云产品。
- 不允许写真实 `tasks.json`、真实排期、真实代码任务或宣布可交付。
