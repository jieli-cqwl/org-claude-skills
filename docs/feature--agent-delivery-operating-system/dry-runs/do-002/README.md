# DO-002 Dry Run

日期：2026-05-14

## 结论

`DO-002` 通过 Stage 1 synthetic 能力验收，但带 `P2` 级非阻断优化项。

Delivery-owner 能在冻结基线齐备且存在 baseline audit advisory owner action 时，先消费 `BCA-DO002-01`，再进入 dry-run dispatch readiness，并只释放 `TL002-T1` 首个 developer Task Packet。

本 case 不是真实 `qft-pai` 交付，不代表真实 `delivery-state.json`、`signoff-package.json`、提交授权或上线条件已存在，不允许真实派发 developer、运行真实代码、提交或上线。

## 输入

输入形态：`synthetic frozen baseline`

输入夹具：

- `input.md`

该夹具只用于训练 `delivery-owner` 的正向专业能力：消费 baseline audit advisory、保护下游、形成合格 dry-run 派发包。

## 产物

- `input.md`：DO-002 synthetic delivery fixture。
- `delivery-owner/output.md`：Delivery-owner dry-run 输出。
- `delivery-owner/evaluator-output.md`：evaluator 复评输出。
- `delivery-owner/decision.md`：本 case 决策记录。
- `tools/eval/scripts/grade_do002_dry_run.py`：DO-002 可枚举 grader。
- `tests/test-do002-dry-run-grader.sh`：grader 回归测试。

## 链路状态

- `judgment`: `warn`
- `chain_status`: `continue`
- `grade`: `P2`

下一角色：`developer` / `verifier`

限制：只能以 Stage 1 dry-run 方式继续。立即只允许 dry-run 派发 `TL002-T1`；`TL002-T1` developer-report 返回后才允许 dry-run 进入 verifier；verifier PASS 前不得释放 `TL002-T2~T5`。

## 工程化检查

已外置 DO-002 grader，覆盖：

- synthetic 标注。
- `BCA-DO002-01` advisory 消费。
- 只释放 `TL002-T1`。
- `TL002-T2~T5` 禁放。
- verifier gate。
- Task Packet 字段完整性。
- 禁止真实 state / signoff / commit / qft-pai 宣称。
- 调用 `task_packet_check.validate()` 校验首包。
- evaluator 的 `warn / continue / P2 / owner=script` 结论。

验证命令：

```bash
bash tests/test-do002-dry-run-grader.sh
```
