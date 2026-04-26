# Brief Manager Additions

Trigger: 当 product-manager 需要渲染 `brief.json` 中 PM-owned 字段的人类投影视图时读取。
Read: `projections/brief-template.md`
Expect: MVP 最小闭环、前置约束执行映射和交付确认展示结构。
Consume: 只读消费 canonical `brief.json`；不得作为下游控制输入。
Evidence: 每个展示字段可回指 `brief.json` canonical 字段或 JSON Pointer。
Sync: brief schema/template、output-contract 或 completion gate 变更时同步。

## MVP 最小闭环说明

- 最小闭环 UNIT:
- 关键路径:
- 不可移除说明:

## 前置约束执行映射

| Constraint ID | 影响 UNIT | scope_item_id | test_ref | 执行状态 |
|---------------|-----------|---------------|----------|----------|
| CON-001 | UNIT-1 | SCOPE-P1U1-001 | N/A | [KNOWN / BLOCKED / VERIFIED] |

## 交付确认

- 确认状态: {待确认}
- 确认时间: YYYY-MM-DD HH:mm
- 确认备注: [可选]
