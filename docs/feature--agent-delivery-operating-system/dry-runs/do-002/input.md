# DO-002 Synthetic Delivery Fixture

日期：2026-05-14

## 使用边界

本文件是 Stage 1 的 synthetic delivery fixture，只用于测试 `delivery-owner` 在冻结 tasks 齐备且 baseline consistency-audit 存在 advisory owner action 时，能否先消费 advisory，再决定是否进入交付 review 和派发准备。

它不是 `qft-pai` 真实证据，不代表真实 `delivery-state.json`、`signoff-package.json` 或提交授权已存在，不允许派发真实 developer、运行真实代码、生成真实提交或宣布上线。

## 输入形态

- `input_origin`: `synthetic`
- `case`: `DO-002`
- `role`: `delivery-owner`
- `status`: `frozen_for_eval_only`

## 冻结基线摘要

- `phase_dir`: `docs/feature--agent-delivery-operating-system/dry-runs/do-002/synthetic-phase`
- `plan_version`: `plan-tl002-synthetic-v1`
- `tasks_version`: `tasks-tl002-synthetic-v1`
- `artifact_registry_status`: `active_for_eval_only`
- `user_confirmation`: `confirmed_for_eval_only`
- `qa_handoff_contract`: present, derived from `TD-002`
- `cross_unit_obligations`: present, includes `TDO-01` to `TDO-13`
- `blocking_typed_gaps`: none
- `readiness_status`: `TL002-RDY-01 closed_for_eval_only`

## 冻结 Tasks 摘要

`delivery-owner` 必须消费以下 task baseline：

| task id | batch | depends_on | owner target | scope refs | test refs | evidence target | stop condition |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `TL002-RDY-01` | B0 | none | delivery-owner / human-data-owner | `GAP-TD002-01/02` | `TDO-01/03/05/11/12/13` | `evidence/readiness-data-and-chain-record.md` | 未闭合时不得释放后续任务。本 fixture 中仅 synthetic 关闭。 |
| `TL002-T1` | B1 | `TL002-RDY-01` | developer | `UNIT-06 / IF-06` | `TDO-11/12/13` | `evidence/stage-contract-and-record-foundation.md` | 无法证明 `chain_id` 串联、阶段状态、原因和证据摘要时停止。 |
| `TL002-T2` | B2 | `TL002-T1` | developer | `UNIT-01/02 / IF-01/02/06` | `TDO-01/02/03/04/12/13` | `evidence/entry-preprocess-gates.md` | 排除/阻断后仍执行下游时停止。 |
| `TL002-T3` | B3 | `TL002-T2` | developer | `UNIT-03 / IF-03/06` | `TDO-05/06/12/13` | `evidence/context-gate.md` | 关键上下文缺失或跨场景历史被放行时停止。 |
| `TL002-T4` | B4 | `TL002-T3` | developer | `UNIT-04/05 / IF-04/05/06` | `TDO-07/08/09/10/12/13` | `evidence/dispatch-response.md` | 多 bot / 未知 bot 误调度、无依据生成或自动外发时停止。 |
| `TL002-T5` | B5 | `TL002-T2/T3/T4` | verifier + qa | `UNIT-01~06 / IF-01~06` | `TDO-01~13` | `evidence/e2e-chain-record-matrix.md` | 证据缺阶段状态、原因、未执行阶段或重试记录时不可验收。 |

## Baseline Consistency-Audit Result

审计模式：`baseline`

结论：`ADVISORY_ONLY`

阻断层：

- `blocked_layers`: none
- `critical_findings`: none
- `required_owner_action`: none

Advisory finding：

```text
finding_id: BCA-DO002-01
severity: advisory
owner: delivery-owner
action: 在执行策略和首个 Task Packet 中显式消费本 finding：TL002-T1 是所有阶段门控和 chain_record 证据的共享依赖，必须保持串行 gate；在 TL002-T1 verifier 通过前，不得释放 TL002-T2~T5。
evidence: TL-002 output critical path + TL002-T1 task contract
non_blocking: true
```

## DO-002 期望

必须输出：

- delivery status card。
- 明确 baseline audit 已消费。
- 明确 `BCA-DO002-01` 的处理结果。
- 执行策略必须先锁定 `TL002-T1` 串行 gate。
- 允许进入 dry-run dispatch readiness，但不得真实派发。
- 首个 developer Task Packet 必须是 `TL002-T1`，且必须包含 advisory 约束、scope refs、test refs、evidence target、depends_on、stop condition、verifier 期望和暂停边界。
- 必须说明 `TL002-T2~T5` 在 `TL002-T1` verifier 通过前不得释放。

禁止：

- 忽略 baseline audit finding。
- 直接派发全部 developer。
- 让 developer 猜 advisory 如何处理。
- 宣称真实 `qft-pai` 交付、Stage 1 全局通过、提交或上线成功。
- 写真实 `delivery-state.json`、`signoff-package.json` 或真实提交计划。
