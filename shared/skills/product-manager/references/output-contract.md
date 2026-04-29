# Manager-Output Contract v1

## 准入依赖

- `docs/{feature}/brief.json` 已包含通过状态的 Director 确认字段。
- `docs/{feature}/phase-{N}/phase-prd.json` 的 Director-owned 字段已冻结。
- M-S0 内容完整性检查已通过：根问题、用户画像、成功标准、Non-goals、Appetite、可行性约束、风险与未知项、Phase 目标、入口条件和出口条件均有 canonical 字段或显式空值说明。

## 产物清单

| 产物 | 职责 | 模板 / 合同 |
|------|------|-------------|
| `docs/{feature}/brief.json` | 在不得改写 Director-owned 字段的前提下，补齐 PM 负责的需求结果、执行映射、评审结论和最终确认字段 | `shared/skills/product-manager/templates/brief.template.json` |
| `docs/{feature}/phase-{N}/phase-prd.json` | 在 Director 骨架下补齐 `business_flows / user_paths / rule_mappings / unit_index / design_decision_candidates / review_conclusion / issue_ledger` | `shared/skills/product-manager/templates/phase-prd.template.json` |
| `docs/{feature}/phase-{N}/units/UNIT-*.json` | 每个 UNIT 独立定义闭环、`integration_context`、结构化 `acceptance_criteria`、`verification_plan`、依赖、排除项与 `design_decision_candidates` | `shared/skills/product-manager/templates/unit-definition.template.json` + `references/closed-loop-unit-spec.md` |
| `brief.json.delivery_confirmation` | 记录最终用户确认 | `shared/skills/product-manager/templates/brief.template.json` |

## Canonical envelope

PM 补齐 `brief.json / phase-prd.json / UNIT-*.json` 时必须保留模板里的 canonical envelope。`producer` 表示 canonical 产品域产物生产者，不表示具体 skill 名；`brief / phase-prd / unit-definition` 固定使用 `product`，不得改成 `product-manager` 或 `product-director`。PM 的评审与交付确认权威写入 `review_conclusion / issue_ledger / delivery_confirmation`。

## Manager-Owned 字段

- Integration Context / 集成上下文：业务模块、不可破坏行为、跨 UNIT 依赖和业务约束说明。
- 示例驱动 AC：AC 描述、示例输入、预期结果、边界情况、失败模式。
- Verification Plan / 验证计划：验证类型、业务操作或场景、预期可观察结果、对应 AC / 成功标准 / 风险项。
- 结构化待设计决策：决策名称、候选选项、约束条件、影响 UNIT、Design handoff。
- AI 可执行性结论：规格是否无需猜测、示例是否足够、边界/失败模式是否枚举、验证计划是否可观察。

## 写入边界

- 不得改写 Director 锁定字段；发现目标、范围、规则或 Phase 边界需要变化时，回退 `/product-director`。
- `前置约束` 只补执行映射字段，不能改写约束事实本身。
- `交付计划` 只补 UNIT 表、UNIT 状态和阶段状态流转，不能改写 Phase 级结构字段。
- 评审闭环当前状态必须同时写入 `brief.json.review_conclusion / brief.json.issue_ledger` 与 `phase-prd.json.review_conclusion / phase-prd.json.issue_ledger`；人类投影视图不能作为下游控制输入。
- 人类投影视图只能渲染 canonical 字段，不能新增 canonical 中没有的结论、issue 或确认状态。
- Manager 输出保持 WHAT 层边界；技术落点、命令、框架、文件路径和实现模式留给 `/design` 及后续阶段。
