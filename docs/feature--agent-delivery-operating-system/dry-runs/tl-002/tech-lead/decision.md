# TL-002 Decision

日期：2026-05-14

## 决策

`TL-002` 判定为 `warn`，但允许继续进入 `delivery-owner`。

状态：

- `judgment`: `warn`
- `chain_status`: `continue`
- `grade`: `P2`
- `input_origin`: `synthetic`

## 为什么通过

Tech-lead 输出满足 `TL-002` 的核心能力标准：

- 明确输入是 synthetic planning fixture，不是真实 `qft-pai` 证据。
- 未通过 readiness 前不得释放 developer，不写真实 `tasks.json/plan.json`。
- 将 `GAP-TD002-01/02` 前置为 `TL002-RDY-01`，并定义失败即停止释放后续任务。
- 按风险排序为 `B0 -> B5`，先验证最大未知项，再做链路状态、入口门控、上下文门控、单 bot 调度/响应生成，最后集成证据矩阵。
- 给出关键路径：`TL002-RDY-01 -> TL002-T1 -> TL002-T2 -> TL002-T3 -> TL002-T4 -> TL002-T5`。
- 每个 Task 合同都绑定上游 refs、test refs、证据路径、依赖和 stop condition。
- 明确串并行边界：B0/B1 串行，B2~B4 默认串行，B5 最后收口。
- 给 delivery-owner 的消费提示清楚：先看 RDY，未通过不得释放后续任务。
- 没有语言/框架/数据库/云产品选择，没有真实排期、developer 派发或 Stage 1 通过声明。

## 为什么是 warn / P2

evaluator 判定的 P2 不是岗位能力失败，而是工程化外置缺口：

- TL-002 的可枚举检查仍可由脚本自动判断，不应该长期依赖人工眼扫。
- 这类检查包括 input_origin、禁止范围、GAP readiness、批次顺序、TDO 覆盖、Task 合同、证据路径和 delivery-owner gate。

该 P2 不阻断 Stage 1 dry-run 继续，但必须沉淀为 grader，防止后续 skill 退化。

## 工程化边界

evaluator 给出的 owner action 是 `script`：

> 新增或扩展 TL-002 grader：校验 input_origin、禁止范围、GAP-TD002-01/02 是否进入 readiness/stop、批次顺序、TDO 覆盖、Task 合同字段、证据路径、Delivery-owner gate 提示。

该 action 已落地：

- `tools/eval/scripts/grade_tl002_dry_run.py`
- `tests/test-tl002-dry-run-grader.sh`

验证命令：

```bash
bash tests/test-tl002-dry-run-grader.sh
```

## 下游约束

允许：

- `delivery-owner` 以 Stage 1 dry-run 方式消费 TL-002 的 B0~B5 批次和 readiness gate。
- `delivery-owner` 基于 `TL002-RDY-01` 决定后续任务是否允许释放。
- 将 `GAP-TD002-01/02` 作为真实执行前 readiness 风险保留。

禁止：

- 把本输出当真实 `tasks.json` 或 `plan.json`。
- 派发 developer 或冻结真实排期。
- 宣称 Stage 1 全局通过。
- 进入真实 `/Users/lijieli/project/qft-pai`。
- 基于本输出做语言选型、代码重写或上线交付。
