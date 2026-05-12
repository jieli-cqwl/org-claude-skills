# 产品经理 Brief 投影

> 运行时真源为 `brief.json`；人类投影视图不得作为下游控制输入。

## 交付计划承接

| JSON Pointer | Phase | 目标 | 时间盒 |
|--------------|-------|------|---------|
| `$.delivery_plan[]` | | | `iteration_timebox_days <= 14` |

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
| `$.review_conclusion.agent_team_review.mode` | | |
| `$.review_conclusion.agent_team_review.round` | | |
| `$.review_conclusion.agent_team_review.reviewer_verdicts[]` | | |

## 问题台账

| Issue ID | Status | Severity | 维度 | Finding | Handoff Target |
|----------|--------|----------|-----------|---------|----------------|
| `$.issue_ledger[]` | | | | | |

## 交付确认

| 字段 | 当前值 | 证据锚点 |
|------|--------|----------|
| `$.delivery_confirmation.status` | | |
| `$.delivery_confirmation.confirmed_at` | | |
