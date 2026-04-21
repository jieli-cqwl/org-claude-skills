流程停在 `test-design` 固定主流程第 8 步，已识别 `DESIGN-GAP`，本次不进入 QA 交接，也不输出最终 `test-cases.json`。原因不是少文件，而是当前 `UNIT` 语义和你要求的“正常提醒 / 无权限访问拒绝 / 边界阈值 / 本期不做短信通知”不一致，不能硬编成真实 AC 覆盖矩阵。

我核对的工件是：
- [brief.json](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/calibrated-case-test-design-ac/_workspaces/test-design/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/brief.json)
- [phase-prd.json](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/calibrated-case-test-design-ac/_workspaces/test-design/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/phase-prd.json)
- [design.json](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/calibrated-case-test-design-ac/_workspaces/test-design/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json)
- [UNIT-1.json](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/calibrated-case-test-design-ac/_workspaces/test-design/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/units/UNIT-1.json)

阻断点很明确：
- `UNIT-1` 的闭环目标是 `foundation registry, schema, template, and catalog are frozen`
- 它的 AC 只有 `catalog and canonical tree exist`
- 排除项只有 `legacy phase migration`
- `design.json` 的接口边界也只指向 runtime state 工具，不承接提醒/权限/短信语义

下一步有两种：
1. 你给我真正包含“提醒 / 权限拒绝 / 阈值 / 短信排除”的 `UNIT` 和对应 `design.json`，我再按 `AC 覆盖矩阵 + 正例 / 反例 / 边界 + 排除项验证` 收口。
2. 你确认就按当前 foundation `UNIT-1` 继续，我改为围绕 `catalog / canonical tree frozen` 输出测试设计。