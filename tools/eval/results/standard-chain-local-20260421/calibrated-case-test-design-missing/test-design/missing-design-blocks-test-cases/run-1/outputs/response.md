已按 `shared/skills/test-design/SKILL.md` 核对，结论是**阻断**。

- 已存在：`brief.json`、`phase-1/phase-prd.json`、`phase-1/units/UNIT-1.json`
- 阻断原因：当前 phase 工作区缺少 `phase-1/design.json`
- 触发的流程边界：`/test-design` 只能在 `design.json` 存在后继续，缺失时必须停在前置校验，不进入测试用例设计、也不输出 QA 交接

本次**未生成**：
- `test-cases.json`
- `qa_handoff_contract`
- 任何下游测试工件

下一步：
1. 先执行 `/design` 产出 `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json`
2. 再重新执行 `/test-design`

如果你愿意，我可以在 `design.json` 出来后继续帮你做这次 test-design。