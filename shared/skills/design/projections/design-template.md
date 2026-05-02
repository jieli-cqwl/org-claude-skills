# Design 投影视图模板

## 目标

把已验证 `design.json` 渲染成人类可读设计说明。投影视图只展示已冻结字段，不新增结论，不替代 `design.json`。

## 输入与事实

- 产品基线：来自 `input_analysis`。
- 运行时事实：来自 `runtime_facts`，只展示影响设计决策的证据。
- 约束继承：来自 `constraint_inheritance_confirmation`；无继承约束时展示确认摘要，不补造约束。

## 共创收口

| 阶段 | 关键问题 | 用户回应 | 设计引用 |
| --- | --- | --- | --- |
| S3 问题拆解 |  |  |  |
| S4 决策点识别 |  |  |  |
| S5 逐项方案探索 |  |  |  |
| S6 边界与接口共识 |  |  |  |
| S7 质量与演进闭环 |  |  |  |
| S8 实施约束收口 |  |  |  |

## 关键决策

| 决策 | 冻结结论 | 已选方案 | 主要取舍 | 事实锚点 | 用户确认 |
| --- | --- | --- | --- | --- | --- |

## 边界设计

### 模块与数据

展示 `modules`、`data_architecture` 和 `cross_cutting_concerns` 的冻结结论。

### 接口契约

展示 `interfaces` 与 `interface_boundary`；每个接口说明调用方、输入、输出、错误和边界行为。

## 质量与演进

| 质量属性 | 优先级 | 目标指标 | 取舍 | 验证引用 |
| --- | --- | --- | --- | --- |

展示 `migration_plan`、`verification_plan`、`rollback_plan` 和 `verification_mapping`。

## 产品交付承接

展示 `product_handoff` 的冻结结论；只呈现已写入 `design.json` 的承接项，不补写产品评审过程。

## 风险与交接

- 风险回应：来自 `risks` 与 `risk_response`。
- 影响范围：来自 `impact_scope`。
- 待计划约束：来自 `planning_constraints`。
- 产品交接：来自 `product_handoff`。
- 最终确认：来自 `final_confirmation`。

## 投影 Manifest

生成 `views/design.projection.md` 时，同时生成 `views/design.projection-manifest.json`。manifest 必须把每个投影区块回指到 `design.json` 的具体字段或 JSON Pointer；没有来源的内容不得写入投影视图。
