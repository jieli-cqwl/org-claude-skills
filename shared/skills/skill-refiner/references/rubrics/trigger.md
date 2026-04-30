# Trigger 环节标准

## Why

触发决定 Skill 是否会在正确任务中出现。触发过宽会抢占相邻能力，触发过窄会让真实需求回退到裸模型。

## 目标

description 能让 runtime 和人判断：何时使用、何时不用、相邻 Skill 如何分流。

## 裁决标准

1. 用户意图明确：能覆盖真实用户会说出的任务表达。
2. 触发对象明确：区分改造、创建、审计、验证、迁移等场景。
3. 新建分流明确：纯新建独立 Skill 交给 `skill-creator`。
4. 拆分分流明确：已有 Skill 拆分先由本 Skill 确认旧能力去留、迁移边界和 active 消费者；拆出的新 Skill 再交给 `skill-creator` 创建。
5. 相邻分流明确：不会抢只读审计、批量自动优化或普通开发 Skill。
6. 入口一致：`user-invocable`、manual-only、adapter 和安装清单与触发描述一致。
7. 反触发清楚：不该触发的高风险相邻场景有正向路由。

## 证据

- `SKILL.md` frontmatter description。
- 相邻 Skill description。
- installer、catalog、adapter 或 runtime 入口。
- 用户历史请求和 eval prompt。

## 问题信号

- description 只写“优化 Skill”“检查质量”等宽泛词。
- 创建、审计、改造、验证共用同一触发入口。
- 纯新建独立 Skill 仍进入精修流程。
- 拆分已有 Skill 时直接新建，未确认旧能力去留、迁移边界和 active 消费者。
- active runtime 入口和 manual-only 描述冲突。
- 测试或 eval 仍使用旧 Skill 名称或旧触发边界。

## 验收

触发描述能把目标任务路由到当前 Skill，把相邻任务路由到对应 Skill，并有测试或引用扫描证明 active 入口一致。
