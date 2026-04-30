# 闭环 UNIT 规格

本文件用于 M-S4/M-S5/M-S5.5，把一个业务能力写成 `phase-{N}/units/UNIT-*.json` 的 canonical `unit-definition`。它不生成 Markdown 版 UNIT，不新增 canonical 外事实。

## 使用方式

- 先确认 UNIT 是否是一个可独立交付的 WHAT 闭环，再写字段。
- 字段形状以 `contracts/unit-definition.schema.json` 与 `templates/unit-definition.template.json` 为真源；本文件只说明专业判断口径。
- 每个字段都要能回到用户裁决、Director baseline、Phase 目标、业务规则或已确认的 PM 共创结论。
- 不写文件路径、接口方案、代码模式、测试框架、Mock 策略或技术实现答案。

## 字段填写顺序

| JSON Pointer | 写什么 | 合格标准 | 下游消费 |
|--------------|--------|----------|----------|
| `$.unit_id` | 稳定 UNIT 编号。 | 与 `phase-prd.json.unit_index` 一致。 | `/design`、`/test-design`、`/tech-lead` 定位范围。 |
| `$.closure_definition` | 闭环定义。 | 一句话写清 `输入/触发 -> 核心行为 -> 可观察结果`。 | 判断功能是否可独立设计、测试和交付。 |
| `$.priority` | 优先级。 | 只能使用 `P0 / P1 / P2 / P3`。 | 规划、测试和交付排序。 |
| `$.priority_basis` | 优先级依据。 | 说明为什么该 UNIT 对当前 Phase 目标、风险或依赖顺序重要。 | 下游判断是否可延期或拆分。 |
| `$.integration_context` | 集成上下文。 | 写业务模块、不可破坏行为、跨 UNIT 依赖和业务约束；不写技术落点。 | `/design` 做影响范围判断。 |
| `$.acceptance_criteria[]` | 示例驱动 AC。 | 每条都有描述、示例输入、预期结果、边界情况、失败模式。 | `/test-design` 和 QA 判断验收覆盖。 |
| `$.verification_plan[]` | 验证计划。 | 写业务操作或场景、预期可观察结果、对应证据目标；不写命令或测试框架。 | `/test-design` 映射测试类型与覆盖点。 |
| `$.design_decision_candidates[]` | 待设计决策。 | 只在需要 `/design` 裁决时填写，包含候选选项、约束、影响 UNIT 和 design handoff。 | `/design` 接收开放选择。 |
| `$.dependencies[]` | 依赖。 | 写依赖 UNIT、业务对象或状态；无依赖时为空数组。 | 规划排序和影响范围判断。 |
| `$.exclusions[]` | 排除项。 | 明确本 UNIT 不处理的业务场景，且能追溯到范围或风险裁决。 | 防止下游自行扩大范围。 |

## 关键判断

### 闭环定义

`$.closure_definition` 必须让下游一眼看出这个 UNIT 如何完成一件事：

- 输入/触发：什么用户动作、业务状态、事件或数据进入本 UNIT。
- 核心行为：系统在 WHAT 层要完成什么业务行为。
- 可观察结果：用户、业务状态、记录、提示或阻断能看到什么结果。

如果一个 UNIT 有多个独立触发或多个互不依赖的可观察结果，继续拆分。

### Integration Context

`$.integration_context` 只描述业务集成语义：

- `business_modules`：涉及的现有业务模块或功能区域。
- `protected_behaviors`：不能破坏的现有流程、权限、数据口径或用户习惯。
- `cross_unit_dependencies`：依赖的 UNIT、顺序或共享业务对象。
- `business_constraints`：来自 Director 或 PM 的业务约束。

出现文件路径、接口形态、组件方案、数据库表、测试框架或部署方案时，改写为业务约束或移交 `/design`。

### 示例驱动 AC

`$.acceptance_criteria[]` 每条 AC 都要可判断业务结果：

- `description`：可观察、可验证的行为陈述。
- `example_input`：具体输入数据、用户操作或业务状态。
- `expected_result`：具体输出、状态变化、提示、记录或阻断。
- `boundary_case`：边界值、特殊条件或临界状态。
- `failure_mode`：异常输入、异常状态或不可接受失败表现。

核心链路至少覆盖正常、异常、边界三类；若某类不适用，必须在 AC 或排除项中写清业务原因。

### Verification Plan

`$.verification_plan[]` 说明如何从用户或业务视角证明 UNIT 完成：

- `verification_type`：功能、数据、流程、权限、风险等业务验证类型。
- `business_operation`：用户或系统执行什么业务动作。
- `expected_observation`：应该观察到什么页面反馈、状态变化、数据记录、通知或阻断。
- `evidence_target`：对应 AC、成功标准、风险项或设计承接项。

不要写命令、测试文件、Mock 策略或自动化框架；这些交给 `/test-design` 和后续技术阶段。

### 待设计决策

`$.design_decision_candidates[]` 只记录 WHAT 层仍需 `/design` 裁决的问题：

- 候选选项必须是业务可接受选项，不提前给技术答案。
- 约束条件必须来自 Director baseline、PM 规则、Integration Context 或风险裁决。
- `impacted_units` 必须能定位受影响 UNIT。
- `design_handoff` 写清交给 `/design` 裁决的目标。

## 完成条件

- 每个 UNIT 都有闭环定义、优先级依据、Integration Context、AC、Verification Plan、依赖和排除项。
- AC 的示例输入、预期结果、边界情况和失败模式足以支撑验收判断。
- Verification Plan 能映射 AC、成功标准或风险项。
- 待设计决策只表达待裁决问题、选项和约束，不提前给技术实现。
- UNIT 写入 canonical `UNIT-*.json`，并被 `phase-prd.json.unit_index` 引用。
