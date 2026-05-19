# TL-002 Dry Run

日期：2026-05-14

## 结论

`TL-002` 通过 Stage 1 synthetic 能力验收，但带 `P2` 级非阻断优化项。

Tech-lead 能在上游 PM / Design / Test-design 齐备、但存在高风险执行未知项时，把 `GAP-TD002-01/02` 前置为 readiness gate，并输出风险驱动批次、关键路径、串并行边界、Task 合同、证据路径和 stop condition。

本 case 不是真实 `qft-pai` 规划，不代表真实 `tasks.json` 或 `plan.json` 已冻结，不允许派发 developer、做语言选型、代码重写或交付声明。

## 输入

输入形态：`synthetic planning fixture`

输入夹具：

- `input.md`

该夹具只用于训练 `tech-lead` 的正向专业能力：把测试义务和高风险未知项转成可被 delivery-owner 消费的实施批次草案。

## 产物

- `input.md`：TL-002 synthetic planning fixture。
- `tech-lead/output.md`：Tech-lead dry-run 输出。
- `tech-lead/evaluator-output.md`：evaluator 复评输出。
- `tech-lead/decision.md`：本 case 决策记录。
- `tools/eval/scripts/grade_tl002_dry_run.py`：TL-002 可枚举 grader。
- `tests/test-tl002-dry-run-grader.sh`：grader 回归测试。

## 链路状态

- `judgment`: `warn`
- `chain_status`: `continue`
- `grade`: `P2`

下一角色：`delivery-owner`

限制：只能以 Stage 1 dry-run 方式继续。真实执行前必须通过 `TL002-RDY-01`、真实 preflight、用户确认和 canonical `plan.json/tasks.json` 冻结。

## 工程化检查

已外置 TL-002 grader，覆盖：

- synthetic 标注。
- 禁止越权范围。
- `GAP-TD002-01/02` readiness gate。
- 风险驱动批次顺序。
- 关键路径依赖。
- Task 合同字段。
- TDO 覆盖。
- Delivery-owner gate 提示。
- evaluator 的 `warn / continue / P2 / owner=script` 结论。

验证命令：

```bash
bash tests/test-tl002-dry-run-grader.sh
```
