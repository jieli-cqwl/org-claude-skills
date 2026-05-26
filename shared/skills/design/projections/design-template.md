# Design 投影视图模板

## 目标

把已验证 `design.json` 渲染成设计说明。投影视图回答“为什么这样设计、决定了什么、下游怎么接”，不新增结论，不替代 `design.json`。

## 阅读线索

- 背景和证据：说明产品基线、运行时事实和继承约束如何影响设计。
- 决策和取舍：说明已冻结的关键决策、备选方案、代价和失效条件。
- 边界和契约：说明模块、数据、接口、横切关注和 UNIT 覆盖如何被下游消费。
- 质量和演进：说明质量目标、迁移、验证、回滚和风险回应如何闭环。
- 交接和确认：说明计划约束、产品交接、review 结论和最终确认。

## 协作确认

| 阶段 | 本节回答 | 设计引用 |
| --- | --- | --- |
| Stakeholders & Concerns | 谁消费设计，关注什么。 | `design_stage_confirmations` |
| Architecture-Significant Requirements | 哪些需求会改变架构。 | `input_analysis` |
| Current-State Evidence | 哪些事实支撑决策。 | `runtime_facts` |
| Complexity Model | 复杂度来自哪里，为什么不加多余结构。 | `input_analysis`、`design_stage_confirmations` |
| Decision Discovery | 哪些决策必须冻结，质量属性如何排序。 | `quality_attributes` |
| Option Tradeoff | 每个决策比较过什么，为什么选当前方案。 | `option_analysis`、`key_decisions` |
| Design Synthesis | 冻结决策如何落成边界、接口、验证、风险和交接。 | `modules`、`interfaces`、`verification_mapping` |

## 关键决策

| 决策 | 冻结结论 | 已选方案 | 主要取舍 | 失效条件 | 事实锚点 |
| --- | --- | --- | --- | --- | --- |

## 边界与契约

- 模块：说明每个模块的职责、数据 owner、依赖和 UNIT 消费方。
- 数据：说明数据对象、写入者、读取者、存储、流向、一致性、迁移或补偿影响。
- 接口：说明调用方、输入、输出、错误码和边界行为。
- 横切关注：说明 auth、error、log、config 的决策和验证引用。

## 质量、迁移、验证、回滚

| 主题 | 本节回答 | 来源 |
| --- | --- | --- |
| 质量属性 | 要达到什么、怎么验证、接受什么取舍。 | `quality_attributes`、`verification_mapping` |
| 迁移 | 从当前状态到目标状态如何分阶段推进。 | `migration_plan` |
| 验证 | 哪些证据证明设计可以交给下游。 | `verification_plan`、`verification_mapping` |
| 回滚 | 什么条件触发回滚，如何恢复。 | `rollback_plan` |

## 风险与交接

- 风险回应：说明风险、缓解动作、验证引用、回滚或升级路径。
- 影响范围：说明受影响模块和验证引用。
- 待计划约束：说明 `/tech-lead` 需要承接的依赖、顺序和限制。
- 产品交接：说明产品侧需要知道的行为变化、风险接受或确认项。
- 最终确认：说明用户已确认的冻结摘要。

## 投影 Manifest

生成 `views/design.projection.md` 时，同时生成 `views/design.projection-manifest.json`。manifest 必须把每个投影区块回指到 `design.json` 的具体字段或 JSON Pointer；没有来源的内容不得写入投影视图。
