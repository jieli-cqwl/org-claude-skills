# 设计共创模板

> 引用者：design SKILL.md S3-S7。核心参考：`../../product-manager/references/conversation-guide.md`。

## Resource Contract

| 字段 | 内容 |
| --- | --- |
| Trigger | S3-S7 需要把未冻结架构问题拆成候选方案、用户确认和最终设计决策 |
| Read | `references/decision-templates.md` |
| Expect | 共创节奏、决策草稿字段、方案对比维度和冻结回填格式 |
| Consume | `design.json.input_analysis`、`option_analysis`、`key_decisions` |
| Evidence | 冻结决策含 decision_id、fact_anchor、tradeoff、user_confirmation 与 ADR 引用或豁免 |
| Sync | 同步 `design/SKILL.md`、ADR projection、design schema/gate 和 reviewer prompts |

## 最小字段

| 字段 | 约束 |
| --- | --- |
| `decision_id` | 与 `design.json.key_decisions[*].decision_id` 一致 |
| `decision_state` | 草稿只允许 `候选` / `待裁决`；最终只允许 `已冻结` |
| `fact_anchor` | 指向 runtime fact 维度或采证命令 |
| `option_id` | 候选方案编号，仅用于草稿对比 |
| `tradeoff` | 写清收益、代价和适用条件 |
| `user_confirmation` | 可回溯到共创轮次 |
| `adr_ref` | 冻结后才可填写；ADR 只是 projection |

## 共创规则

- 一次只推进一个决策点；先给事实，再给选项。
- 优先选择题，必要时再开放题；用户回应后先复述确认。
- 深度路由：约束已冻结且决策点少则快速收敛；存在未冻结决策则标准探索；跨模块/外部依赖/隐含假设多则深度探索。
- 用户催促时可压缩非关键解释，但不跳过影响正确性的追问。

## 提问与呈现

问题拆解优先问：
- 约束根源是什么：业务规则、合规、技术限制还是历史选择？
- 性能、可靠性、安全、可维护性哪个优先，是否有量化目标？
- 一致性和可用性不能兼得时优先哪个？
- 核心业务概念和限界上下文如何划分？

决策点清单格式：
```text
1. [决策点] - [为什么需要决定，用业务语言]
```

方案探索格式：
```text
[决策点]
背景: [...]
方案 A: [...] / 好处: [...] / 代价: [...]
方案 B: [...] / 好处: [...] / 代价: [...]
推荐: [...]，前提: [...]
```

Option Draft Agent 只输出候选对比，不给最终冻结结论；写回 `design.json.key_decisions` 时必须由主 Agent 转成 `decision_state=已冻结`。

ADR Draft Agent 若被启用，只能先产出结构草稿；`ADR-NNN.md` 的最终正文必须由主 Agent 在冻结后转写，不能把 draft 直接落为最终工件。

方案对比必评：实现复杂度、运行时性能、可维护性、迁移成本、演进弹性、Constitution 合规。

裁决顺序：L1 非协商约束 > L2 质量属性优先级（须用户确认） > L3 可逆性优先 > L4 默认选简单。
