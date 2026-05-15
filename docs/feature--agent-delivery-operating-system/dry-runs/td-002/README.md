# TD-002 Dry Run

日期：2026-05-14

## 结论

`TD-002` 通过 Stage 1 synthetic 能力验收，但带 `P2` 级非阻断优化项。

Test-design 能基于 synthetic frozen design fixture 建立 `UNIT / AC / design interface / test obligation` 追溯，覆盖正向、范围外、阻断、失败、回滚/补偿边界、证据完整性、QA handoff 和 Tech-lead 消费提示。

本 case 不是真实 `qft-pai` 验收，不代表真实 `test-cases.json` 已冻结，不允许作为真实交付证据。

## 输入

输入形态：`synthetic frozen fixture`

输入夹具：

- `input.md`

该夹具把 `DES-002` 中未闭合的人类裁决固定为 Stage 1 eval 假设，只用于训练 `test-design` 正向专业能力。

## 产物

- `input.md`：TD-002 synthetic frozen fixture。
- `test-design/output.md`：Test-design dry-run 输出。
- `test-design/evaluator-output.md`：evaluator 复评输出。
- `test-design/decision.md`：本 case 决策记录。
- `tools/eval/scripts/grade_td002_dry_run.py`：TD-002 可枚举 grader。
- `tests/test-td002-dry-run-grader.sh`：grader 回归测试。

## 链路状态

- `judgment`: `warn`
- `chain_status`: `continue`
- `grade`: `P2`

下一角色：`tech-lead`

限制：只能在 Stage 1 synthetic 语境下继续，并且必须携带 `GAP-TD002-01/02` 作为非阻断 followup。

## 工程化检查

已外置 TD-002 grader，覆盖：

- synthetic 标注。
- 禁止越权范围。
- `TDO -> UNIT/AC -> IF` 追溯。
- 正向、边界、阻断、失败、回滚/补偿和证据完整性覆盖。
- typed gap 字段。
- QA handoff。
- Tech-lead 绑定提示。
- evaluator 的 `warn / continue / P2 / owner=script` 结论。

验证命令：

```bash
bash tests/test-td002-dry-run-grader.sh
```
