# Manager-Output Contract v1

## 准入依赖

- `docs/{feature}/brief.json` 已包含通过状态的 Director 确认字段。
- `docs/{feature}/phase-{N}/phase-prd.json` 的 Director-owned 字段已冻结。

## 产物清单

| 产物 | 职责 | 模板 / 合同 |
|------|------|-------------|
| `docs/{feature}/brief.json` | 在不得改写 Director-owned 字段的前提下，补齐 PM 负责的需求结果、执行映射、评审结论和最终确认字段 | `contracts/canonical/templates/planning/brief.template.json` |
| `docs/{feature}/phase-{N}/phase-prd.json` | 在 Director 骨架下补齐 UNIT 索引、依赖关系、评审结论和 issue ledger | `contracts/canonical/templates/planning/phase-prd.template.json` |
| `docs/{feature}/phase-{N}/units/UNIT-*.json` | 每个 UNIT 独立定义闭环、AC、依赖与排除项 | `contracts/canonical/templates/planning/unit-definition.template.json` + `references/closed-loop-unit-spec.md` |
| `brief.json.delivery_confirmation` | 记录最终用户确认 | `contracts/canonical/templates/planning/brief.template.json` |

## 写入边界

- 不得改写 Director 锁定字段；发现目标、范围、规则或 Phase 边界需要变化时，回退 `/product-director`。
- `前置约束` 只补执行映射字段，不能改写约束事实本身。
- `交付计划` 只补 UNIT 表、UNIT 状态和阶段状态流转，不能改写 Phase 级结构字段。
- 评审闭环当前状态必须同时写入 `brief.json.review_conclusion / brief.json.issue_ledger` 与 `phase-prd.json.review_conclusion / phase-prd.json.issue_ledger`；人类投影视图不能作为下游控制输入。
