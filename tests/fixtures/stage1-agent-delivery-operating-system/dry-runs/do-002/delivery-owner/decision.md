# DO-002 Decision

日期：2026-05-14

## 决策

`DO-002` 判定为 `warn`，但允许继续进入 `developer` / `verifier`。

状态：

- `judgment`: `warn`
- `chain_status`: `continue`
- `grade`: `P2`
- `input_origin`: `synthetic`

## 为什么通过

Delivery-owner 输出满足 `DO-002` 的核心能力标准：

- 明确输入是 synthetic frozen baseline，不是真实 `qft-pai` 交付证据。
- 消费 baseline audit finding `BCA-DO002-01`，没有把 advisory 留给 developer 猜。
- 把 `TL002-T1` 设为串行 gate，只释放 `TL002-T1` 的 dry-run dispatch readiness。
- 明确 `TL002-T2~T5` 在 `TL002-T1` verifier PASS 前不得释放。
- 首个 Task Packet 是 `TL002-T1` developer 包，包含 goal、scope refs、test refs、depends_on、advisory constraints、input refs、expected evidence、stop condition、forbidden actions 和 next gate。
- 明确 developer 返回后必须先进入 verifier，verifier PASS 后才考虑下游。
- 没有真实派发 developer，没有写真实 `delivery-state.json`、`signoff-package.json`、提交计划、真实 qft-pai 执行或上线声明。

## 为什么是 warn / P2

evaluator 判定的 P2 不是岗位能力失败，而是工程化外置缺口：

- `BCA-DO002-01` 是否被消费、是否只释放 `TL002-T1`、`TL002-T2~T5` 是否禁放、verifier gate 是否存在、真实 state/signoff/commit 是否被禁止，都是可枚举检查。
- 首个 Task Packet 也应该用现有 `task_packet_check.validate()` 自动校验。

该 P2 不阻断 Stage 1 dry-run 继续，但必须沉淀为 grader，防止 delivery-owner skill 退化成口头调度。

## 工程化边界

evaluator 给出的 owner action 是 `script`：

> 新增 DO-002 evaluator/grader：自动校验 input_origin=synthetic、BCA-DO002-01 同时出现在执行策略和 Task Packet、active_tasks 仅 TL002-T1、TL002-T2~T5 禁放、verifier gate 存在、禁止真实 state/signoff/commit/qft-pai 宣称，并对首包调用 task_packet_check.validate()。

该 action 已落地：

- `tools/eval/scripts/grade_do002_dry_run.py`
- `tests/test-do002-dry-run-grader.sh`

验证命令：

```bash
bash tests/test-do002-dry-run-grader.sh
```

## 下游约束

允许：

- `developer` 以 Stage 1 dry-run 方式消费 `TL002-T1` Task Packet。
- `verifier` 只在 `TL002-T1 developer-report.json` 返回后进入 dry-run 验收。

禁止：

- 真实派发 developer。
- 释放 `TL002-T2~T5`。
- 写真实 `delivery-state.json`、`signoff-package.json`、artifact registry 变更或提交计划。
- 宣称 Stage 1 全局通过。
- 进入真实 `/Users/lijieli/project/qft-pai`。
- 基于本输出做真实代码重写、提交、上线或风险接受。
