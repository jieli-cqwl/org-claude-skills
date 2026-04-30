# Brief Manager Projection

Trigger: 当 product-manager 需要渲染 `brief.json` 中 PM-owned 字段的人类投影视图时读取。
Read: `projections/brief-template.md`
Expect: 交付计划承接、约束与风险承接、PM 评审闭环、问题台账和交付确认展示结构。
Consume: 只读消费 canonical `brief.json`；不得作为下游控制输入。
Evidence: 每个展示字段可回指 `brief.json` canonical 字段或 JSON Pointer。
Sync: brief schema/template、output-contract 或 completion gate 变更时同步。

## 交付计划承接

| JSON Pointer | Phase | Goal |
|--------------|-------|------|
| `$.delivery_plan[]` | | |

## 约束与风险承接

| JSON Pointer | 类型 / 项目 | 影响范围 / 影响 | 承接方式 / 缓解方式 | 状态 |
|--------------|-------------|-----------------|----------------------|------|
| `$.feasibility_constraints[]` | | | | |
| `$.risks_and_unknowns[]` | | | | |

## PM 评审闭环

| 字段 | 当前值 | 证据锚点 |
|------|--------|----------|
| `$.review_conclusion.verdict` | | |
| `$.review_conclusion.summary` | | |

## 问题台账

| Issue ID | Status | Severity | Dimension | Finding | Handoff Target |
|----------|--------|----------|-----------|---------|----------------|
| `$.issue_ledger[]` | | | | | |

## 交付确认

| 字段 | 当前值 | 证据锚点 |
|------|--------|----------|
| `$.delivery_confirmation.status` | | |
| `$.delivery_confirmation.confirmed_at` | | |
