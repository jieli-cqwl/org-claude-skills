# Manager-Output Contract v1

## 准入依赖

- `docs/{feature}/brief.md` 已包含通过状态的 `## 产品总监确认`。
- `docs/{feature}/brief.lock.json` 存在，且与当前 Director 锁定字段一致。
- 每个 `docs/{feature}/phase-{N}/prd.lock.json` 存在，且与当前阶段骨架字段一致。

## 产物清单

| 产物 | 职责 | 模板 / 合同 |
|------|------|-------------|
| `docs/{feature}/brief.md` | 在不得改写 Director 锁定字段的前提下，补齐 PM 负责的需求结果、执行映射和最终确认字段 | `references/templates/brief-template.md` + `contracts/product-artifacts.yaml#brief_lock` |
| `docs/{feature}/phase-{N}/prd.md` | 在 Director 骨架下补齐 UNIT 索引与依赖关系 | `references/templates/phase-prd-template.md` + `contracts/product-artifacts.yaml#prd_lock` |
| `docs/{feature}/phase-{N}/units/UNIT-*.md` | 每个 UNIT 独立定义闭环、AC、依赖与排除项 | `references/closed-loop-unit-spec.md` |
| `docs/{feature}/review.md` | 合并三方评审结果、收敛轮次与必要的用户裁决记录 | `references/templates/review-template.md` + `references/review-orchestration-contract.md` + `contracts/product-artifacts.yaml#review_contract` |
| `brief.md#交付确认` | 记录最终用户确认 | `references/templates/brief-template.md` |

## 写入边界

- 不得改写 Director 锁定字段；发现目标、范围、规则或 Phase 边界需要变化时，回退 `/product-director`。
- `前置约束` 只补执行映射字段，不能改写约束事实本身。
- `交付计划` 只补 UNIT 表、UNIT 状态和阶段状态流转，不能改写 Phase 级结构字段。
- `review.md` 是评审闭环证据载体，不能把 review 状态机塞回 `brief.md`。
