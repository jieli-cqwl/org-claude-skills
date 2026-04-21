# Architecture Decision Record 规范

> 引用者：design SKILL.md
> 适用流程：主 Agent 冻结 `design.json.key_decisions` 后，可调用 ADR Draft Agent 先产出人类投影视图草稿；最终 ADR 仍由主 Agent 从 canonical 决策派生。

ADR 只作为可选人类投影视图。运行时设计真源只在 `design.json.key_decisions`、`design.json.interface_boundary` 与 `design.json.quality_attributes`。

## 草稿 / 最终工件分层

ADR Draft Agent 只产出结构草稿：决策编号、候选状态、现状依据、备选方案和未决项；最终 ADR 仍由主 Agent 在 `design.json` 冻结后转写。

主 Agent 必须先把对应设计决策收敛并回填为 `decision_state=已冻结`，再把草稿转写成下方最终 ADR 投影视图；最终 `ADR-NNN.md` 不得原样保留 structure draft 的 shared 字段。

## 阶段补充字段

本文件只补最终 ADR 工件需要承接的字段；其中 `decision_state` 属于主 Agent 的冻结回填字段，不属于 ADR Draft Agent 可直接冻结的输出。

| 字段 | 含义 | 约束 |
|------|------|------|
| `decision_id` | 对应的设计决策编号 | 必须与 `design.json.key_decisions[*].decision_id` 一致 |
| `decision_state` | design 主记录中的冻结状态 | 仅允许主 Agent 回填为 `已冻结`；ADR Draft Agent 草稿仍只允许 `候选` / `待裁决` |
| `user_confirmation` | 用户确认记录 | 必须可回溯到共创轮次 |
| `evidence_anchor` | 现状依据锚点 | 必须指向 `design.json.input_analysis.runtime_facts` 或采证命令输出 |
| `alternative_count` | 备选方案数量 | 至少 2 个 |

## ADR 模板

```markdown
### ADR-NNN: {简短标题}
决策编号: D-xxx
状态: Proposed | Accepted | Deprecated | Superseded by ADR-NNN
背景: 问题和约束条件（1-3 句）。
决策: 选择 {方案名}。
理由: 核心论据（不超过 3 条）。
用户确认: {用户的选择偏好和核心理由} — 共创步骤 {N}
现状依据: cite design.json.input_analysis.runtime_facts 的具体 JSON Pointer 或 runtime-fact-capture 采证命令输出 key（REQUIRED，纯代码重构 feature 可写「不适用+理由」）
备选方案:
| 方案 | 优势 | 劣势 | 淘汰原因 |
|------|------|------|---------|
后果: 正面 / 负面 / 约束（后续实现必须遵守的限制）
```

## 命名规则

- 文件名格式：`ADR-NNN.md`（NNN 从 001 起，按项目全局递增）
- 文档内标题格式：`### ADR-NNN: 简短标题`（标题中文，限 15 字以内）

## 示例

```markdown
### ADR-001: 消息队列选型
状态: Accepted
背景: 订单系统需异步处理支付回调，峰值 QPS 约 5000，要求消息不丢失。
决策: 选择 RabbitMQ。
理由: 1) 已有运维经验；2) 持久化 + 手动 ACK 满足不丢失；3) QPS 在承载范围内。
备选方案:
| 方案 | 优势 | 劣势 | 淘汰原因 |
|------|------|------|---------|
| Kafka | 吞吐更高、支持回放 | 运维复杂 | 团队无经验，QPS 不需要 |
| Redis Stream | 部署简单、延迟低 | 持久化弱 | 可靠性不满足支付场景 |
后果: 正面：复用运维能力 / 负面：QPS 超 5 万需重评 / 约束：消费者必须幂等
```
