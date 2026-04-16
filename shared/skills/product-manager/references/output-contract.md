# Manager-Output Contract v1

## 准入依赖

- standard-chain lane：`docs/{feature}/brief.json` 已包含通过状态的 Director 确认字段，且 `docs/{feature}/phase-{N}/phase-prd.json` 的 Director-owned 字段已冻结。
- legacy markdown lane：`docs/{feature}/brief.md` 已包含通过状态的 `## 产品总监确认`，`brief.lock.json` 与每个 `phase-{N}/prd.lock.json` 均有效且无漂移。

## 产物清单

| 产物 | 职责 | 模板 / 合同 |
|------|------|-------------|
| `docs/{feature}/brief.json` | 在不得改写 Director-owned 字段的前提下，补齐 PM 负责的需求结果、执行映射、评审结论和最终确认字段 | `contracts/canonical/templates/planning/brief.template.json` |
| `docs/{feature}/phase-{N}/phase-prd.json` | 在 Director 骨架下补齐 UNIT 索引与依赖关系 | `contracts/canonical/templates/planning/phase-prd.template.json` |
| `docs/{feature}/phase-{N}/units/UNIT-*.json` | 每个 UNIT 独立定义闭环、AC、依赖与排除项 | `contracts/canonical/templates/planning/unit-definition.template.json` + `references/closed-loop-unit-spec.md` |
| `docs/{feature}/review.md` | legacy markdown lane 的三方评审结果投影视图；standard-chain lane 的当前状态必须写入 canonical review fields | `references/templates/review-template.md` + `references/review-orchestration-contract.md` + `contracts/product-artifacts.yaml#review_contract` |
| `brief.json.delivery_confirmation` | 记录最终用户确认 | `contracts/canonical/templates/planning/brief.template.json` |

## 写入边界

- 不得改写 Director 锁定字段；发现目标、范围、规则或 Phase 边界需要变化时，回退 `/product-director`。
- `前置约束` 只补执行映射字段，不能改写约束事实本身。
- `交付计划` 只补 UNIT 表、UNIT 状态和阶段状态流转，不能改写 Phase 级结构字段。
- standard-chain lane 的评审闭环当前状态写入 `brief.json.review_conclusion / issue_ledger`；legacy lane 可投影到 `review.md`，不能口头带过。
