# 风险评估方法（场景方法论）

> 引用者：`design/SKILL.md`。用于补强 `design.json.risks`、`design.json.risk_response` 与 Gate 4 证据。

## Resource Contract

| 字段 | 内容 |
| --- | --- |
| Trigger | S7 需要承接 Director 风险、补充技术风险或判断风险回应策略 |
| Read | `references/risk-assessment.md` |
| Expect | 获得风险维度、优先级、缓解动作、验证引用和回滚触发条件 |
| Consume | 写入 `design.json.risks` 与 `design.json.risk_response`，支撑 Q9 |
| Evidence | 每条风险有 architecture_response、verification_refs 或 escalation_path；semantic validator 可检查 |
| Sync | 变更时同步 `design/SKILL.md`、risk 字段 schema/template、completion gate、review prompts 和 fixtures |

## 使用目标

识别会阻断实施或放大业务损失的风险，并给出可执行缓解动作。

## 风险分类

| 维度 | 示例 |
|------|------|
| 技术风险 | 性能瓶颈、迁移失败、外部依赖不稳定 |
| 交付风险 | 单点知识、跨团队阻塞、关键资源冲突 |
| 业务风险 | 合规缺口、核心流程失败、数据偏差 |

## 评估矩阵

按概率(P) x 影响(I)评估优先级：

| P\I | 高影响 | 中影响 | 低影响 |
|-----|--------|--------|--------|
| 高概率 | P0 | P1 | P2 |
| 中概率 | P1 | P2 | P3 |
| 低概率 | P2 | P3 | P3 |

## 缓解策略模板

在 `design.json.risks` 与 `design.json.risk_response` 使用：

```markdown
| 风险 | 维度 | P | I | 优先级 | 缓解动作 | 验证方式 | 触发回滚条件 |
|------|------|---|---|--------|---------|---------|-------------|
| ... | ... | ... | ... | ... | ... | ... | ... |
```

## Gate 对齐要求

- P0：必须有已定义且可执行的缓解动作与验证方式，否则 Gate 4 FAIL
- P1：必须有缓解动作和负责人，否则 Gate 4 FAIL
- 任意风险：只写“关注/监控”但无动作，视为无效风险项

## 三原则裁决

- 简单：风险控制不引入无证据复杂度
- 合适：高影响风险必须保留必要冗余与防护
- 演化：按需增长复杂度 + 可逆性优先 + 延迟不可逆决策（LRM）
  在风险缓解层面的实施证据：动作可分阶段验证且可安全回退
原则冲突时按 L1-L4 裁决（详见 `{{RUNTIME_HOME}}/reference/设计原则.md` 裁决规则）。
自检：「去掉这个，业务需求是否仍满足？」能 -> Accidental，应削减。
