# Phase {N}: [阶段目标]

> 项目背景、约束与设计决策见 `brief.json` active revision。

## 阶段目标

[一段话描述本阶段要交付的价值和范围边界]

## Director 基线摘要

| 字段 | 本阶段约束 | 来源 |
|------|------------|------|
| 用户画像 | [谁 / 场景 / 当前绕行方式] | `brief.json#/user_profile` |
| Appetite | [本阶段投入边界] | `brief.json#/appetite` |
| Non-goals | [本阶段不交付] | `brief.json#/non_goals` |
| 可行性约束 | [本阶段必须遵守的约束] | `brief.json#/feasibility_constraints` |
| 风险与未知项 | [影响本阶段的风险] | `brief.json#/risks_and_unknowns` |
| 决策理由 | [本阶段范围取舍原因] | `brief.json#/decision_rationale` |

## 入口与出口条件

- 入口条件: [前置 Phase 完成 / Brief 审查通过]
- 出口条件: [本阶段完成条件]

## 空 UNIT 索引

由 `/product-manager` 在下一阶段填充；Director 不写 UNIT 或 AC。

## 引用锚点合同
| 引用用途 | canonical anchor |
|---------|------------------|
| phase_goal_ref | `phase-prd.json#/phase_goal` |
| entry_condition_ref | `phase-prd.json#/entry_conditions` |
| exit_condition_ref | `phase-prd.json#/exit_conditions` |
| unit_index_ref | `phase-prd.json#/unit_index` |
