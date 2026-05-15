**结论：TD-S1 Preflight BLOCKED。**
本轮输入标记为 `synthetic/missing`，缺少可读取的 canonical `design.json`；按 `test-design` 准入规则，必须阻断 handoff，不能硬写测试用例，也不能进入 `/tech-lead`。

**canonical 输入准入边界**

`test-design` 只接受以下 canonical JSON 作为事实源：`brief.json`、`phase-prd.json`、`units/UNIT-*.json`、`design.json`。
PM 口头说明“PRD/UNIT 已经有”不能替代 canonical artifact；“设计后补”不能作为测试义务设计依据。

**typed gap**

- `typed_gap`: `DESIGN_GAP`
- `blocking`: `true`
- `evidence_refs`: `input_source=synthetic/missing`；用户明确说明本轮没有可读取的 `design.json`
- `owner`: `/design`
- `next_action`: 补齐对应 Phase/UNIT 的 `design.json`，至少提供接口、数据、cross-cutting、quality attributes、risk response、`verification_mapping` 后，再重新执行 `test-design` 准入
- `handoff`: blocked，禁止交给 `/tech-lead`

**影响**

缺 `design.json` 会导致 `/tech-lead` 无法基于设计引用拆解可验证任务，任务边界和验收证据会漂移。
`developer` 无法得到可追踪的 assertion target、执行方式和证据期望，只能测试猜测出来的实现。
`qa` 无法消费 `qa_handoff_contract`、冒烟/深测范围和设计风险映射，后续验收口径不可复验。

可选下一步是由用户裁决是否先执行 `/design` 补齐 `design.json`，或提供已有 `design.json` 的 canonical 路径。等待用户裁决。
