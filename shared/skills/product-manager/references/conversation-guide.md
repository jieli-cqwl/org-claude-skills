# 对话指南

## 对话目标

Manager 阶段的核心不是重开根问题，而是在 Director 已冻结的范围内，把业务流程、用户路径、UNIT、Integration Context、示例驱动 AC、Verification Plan 和结构化待设计决策共创到可执行粒度。

## 节奏要求

- 每次只收口一个主题：流程、路径、规则、UNIT 或 AC
- 先复述 Director 基线中已经确认的内容，再追问 PM 阶段新增细节
- 一旦用户修改范围、Phase 边界或约束事实，立即提示回退 `/product-director`
- 对每个 UNIT，先确认闭环与 Integration Context，再进入示例驱动 AC 和 Verification Plan
- 所有输出以 canonical JSON 为真源；人类投影视图只渲染 canonical 字段

## 共创模式

### 全共创（M-S1, M-S2, M-S3, M-S4, M-S9）

1. 先引用已冻结的 Director 基线
2. 提出一个最需要细化的问题
3. 暂停等待用户回应
4. 复述用户回应，确认是否会影响 UNIT、AC、Verification Plan 或 Integration Context
5. 直接把确认后的结果写回目标章节；不要维护固定阶段式共创摘要

### 草案修正（M-S5, M-S5.5）

1. 先输出 AC 或 Verification Plan 草案
2. 用 `[?]` 标出仍需确认的示例输入、预期结果、边界情况、失败模式、验证操作或可观察结果
3. 暂停等待用户修正
4. 将修正同步到 UNIT / AC / Verification Plan

### 条件共创（M-S6, M-S7）

1. 先自主扫描开放问题或完整性缺口
2. 无问题则继续
3. 有问题时只追问真正影响设计/执行的问题

## 关键追问模板

- M-S0 内容完整性：`这个 Phase 的用户画像、Non-goals、Appetite、可行性约束和风险项是否都来自 Director 已确认字段？缺失项需要回到 /product-director 补齐。`
- M-S4 Integration Context：`这个 UNIT 涉及哪些现有业务模块？哪些已有行为不能被破坏？它依赖哪些其他 UNIT 或业务对象？`
- M-S5 示例驱动 AC：`请给这个 AC 一个具体示例输入、预期结果、边界情况和失败模式；如果没有边界或失败模式，请确认“不适用”的业务原因。`
- M-S5.5 Verification Plan：`要证明这个 UNIT 完成，用户或系统要做什么业务操作？应该观察到什么结果？它对应哪条 AC、成功标准或风险项？`
- M-S6 结构化待设计决策：`这里需要 /design 裁决什么？可接受选项有哪些？约束是什么？影响哪些 UNIT？`
- M-S7/M-S8 AI 可执行性：`下游 AI 是否还需要猜测输入、输出、边界、失败处理、验证方式或影响面？`

## 高风险信号

- 用户要求直接改 Phase 边界或交付价值
- 约束事实、Owner、约束内容要被改写
- UNIT 标题开始退化成“梳理/建模/审计/SOP”
- AC 变成需求复述而不是示例驱动的可观察结果
- Verification Plan 写成命令、测试框架或 Mock 策略
- Integration Context 写成文件路径、接口方案或架构落点
- 待设计决策直接给技术答案，而不是给选项、约束和 design handoff
- 试图绕过 canonical `director_confirmation.locked_fields` / `locked_field_digest`
