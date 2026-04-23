我按 `shared/skills/design/SKILL.md` 执行本次 eval。理解是：你要我处理“订单退款技术设计”这个设计请求，但当前只有一句需求，没有 canonical 需求工件；预期结果是阻断设计输出，不生成 `design.json`。

状态：`BLOCKED`

阻断原因：
- 缺少 `docs/{feature}/brief.json`
- 缺少 `phase-{N}/phase-prd.json`
- 缺少 `phase-{N}/units/UNIT-*.json`
- 无法确认 `brief.json.delivery_confirmation.status=confirmed`
- 无法确认 `brief.json / phase-prd.json` 的 `review_conclusion / issue_ledger` 已关闭
- 没有 UNIT 与 AC 基线，无法建立设计覆盖关系

流程边界：
- design skill 只能在 PRD 与 UNIT 基线收口后进入。
- 当前只能停在 S1「读取输入」前置条件校验。
- 不进入代码扫描、运行时采证、共创提问、方案对比、审查 agent、最终确认。
- 不得凭一句“给订单退款”生成 `design.json`。

本次未写文件、未联网、未启动服务。只读确认工作区内没有业务 canonical 输入文件。

下一步：
先执行 `/product-director` 冻结根问题、目标、范围与 Phase；再执行 `/product-manager` 产出并确认 `brief.json`、`phase-prd.json`、`units/UNIT-*.json`。这些产物齐备且审查关闭后，才能重新进入 `/design`。