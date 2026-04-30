# 对话指南

## 对话目标

Manager 阶段的核心不是重开根问题，而是在 Director 已冻结的范围内，把业务流程、用户路径、UNIT、Integration Context、示例驱动 AC、Verification Plan 和结构化待设计决策共创到可执行粒度。

## 主导共创

共创不是把问题抛给用户。先给出最佳实践草案、推荐选项和裁决理由，用户只需要选择、修正或补充业务事实。

- 每轮先引用 Director 基线和已确认事实，再给出 PM 侧推荐草案。
- 对流程、路径、规则和 UNIT 边界，优先给 2-3 个可选收口方式并标出推荐。
- 对 AC 和 Verification Plan，先生成示例输入、预期结果、边界情况、失败模式和可观察结果，再用 `[?]` 要用户修正不确定事实。
- 开放问题只在缺失事实会影响 UNIT 闭环、AC 可验收性、Verification Plan 或 design handoff 时使用。

## 节奏要求

- 每次只收口一个主题：流程、路径、规则、UNIT 或 AC
- 先复述 Director 基线中已经确认的内容，再提出 AI 草案和一个待裁决点
- 一旦用户修改范围、Phase 边界或约束事实，立即提示回退 `/product-director`
- 对每个 UNIT，先确认闭环与 Integration Context，再进入示例驱动 AC 和 Verification Plan
- 所有输出以 canonical JSON 为真源；人类投影视图只渲染 canonical 字段

## 共创模式

### 全共创（M-S1, M-S2, M-S3, M-S4, M-S9）

1. 先引用已冻结的 Director 基线
2. 给出推荐草案或 2-3 个收口选项，标明推荐、理由和不确定假设
3. 提出一个裁决问题，要求用户确认、选择或修正
4. 暂停等待用户回应
5. 复述用户回应，确认是否会影响 UNIT、AC、Verification Plan 或 Integration Context
6. 直接把确认后的结果写回目标章节；不要维护固定阶段式共创摘要

### 草案修正（M-S5, M-S5.5）

1. 先输出 AC 或 Verification Plan 的最佳实践草案
2. 用 `[?]` 标出仍需确认的示例输入、预期结果、边界情况、失败模式、验证操作或可观察结果，并附推荐判断
3. 暂停等待用户修正
4. 将修正同步到 UNIT / AC / Verification Plan

### 条件共创（M-S6, M-S7）

1. 先自主扫描开放问题或完整性缺口
2. 无问题则继续
3. 有问题时先给推荐处理方式，再只追问真正影响设计/执行的裁决点

## 回复骨架

每轮回复用同一个骨架，避免变成开放式采访。

1. 已冻结事实：用一句话引用 Director 基线、当前 UNIT/AC 或已验证结论。
2. PM 推荐：给一个推荐草案，必要时给 2-3 个选项并标出推荐。
3. 理由与假设：说明为什么推荐，以及仍不确定的业务假设。
4. 请确认、选择或修正：只问一个问题；问题必须能让用户确认、选择或修正，不问“你想怎么做”。

## 步骤引导卡

每张卡都按同一顺序组织：事实锚点、推荐输出、裁决问题、写入目标。不要问“你想怎么做”；先给 PM 推荐，让用户确认、选择或修正。

| 步骤 | 事实锚点 | 推荐输出 | 裁决问题 | 写入目标 |
| --- | --- | --- | --- | --- |
| M-S0 | 用户目标、brief/phase-prd 路径或缺失状态、preflight 结果 | 阻断结论或准入通过摘要；失败时只给固定 handoff 问题 | “请提供 canonical brief.json 和 phase-prd.json，或回到 /product-director 重签。” | 准入状态，不写 PRD/UNIT/AC 草案 |
| M-S1 | Phase goal、scope_boundaries、non_goals、entry/exit conditions | 端到端业务流程草案，含对象状态和关键分支 | “这个流程顺序是否符合真实业务？是否有一个必须补充或删除的分支？” | `phase-prd.json.business_flows` |
| M-S2 | 用户画像、成功标准、M-S1 流程草案 | 用户路径草案，含成功、空态、无权限、错误和反馈结果 | “这些路径里哪一个最可能不符合真实使用？请确认或修正。” | `phase-prd.json.user_paths` |
| M-S3 | Director 锁定规则、风险、约束、M-S1/M-S2 已确认事实 | 角色、字段、状态流转和高风险操作规则映射 | “推荐按这个规则收口；是否有会改变业务口径的例外？” | `phase-prd.json.rule_mappings` |
| M-S4 | 已确认流程、路径、规则和 Phase 出口条件 | 3-7 个闭环 UNIT，含输入/触发、核心行为、可观察结果、依赖和排除项 | “推荐先按这些 UNIT 交付；哪个 UNIT 边界需要合并、拆分或改名？” | `phase-prd.json.unit_index` 与 `units/UNIT-*.json` |
| M-S5 | 单个 UNIT 的闭环、依赖、排除项和 Integration Context | 示例驱动 AC 草案，覆盖正常、异常、边界和失败模式 | “这些示例是否能代表真实验收？请修正最不准确的一条。” | `units/UNIT-*.json.acceptance_criteria` |
| M-S5.5 | UNIT AC、成功标准、风险与可观察结果 | Verification Plan 草案，只写业务操作和预期观察 | “按这个操作能否证明 AC 完成？如果不能，缺哪个观察点？” | `units/UNIT-*.json.verification_plan` |
| M-S6 | 已确认 UNIT、AC、Verification Plan 和开放问题 | 待 `/design` 裁决的问题清单，含选项、约束和影响 UNIT | “这些问题哪些必须交给 design，哪些已经可在 PM 层收口？” | `phase-prd.json.design_decision_candidates` |
| M-S7 | 当前 canonical 工件、C1-C12 扫描结果、AI 可执行性缺口 | 缺口清单，先给推荐修复或不适用理由 | “这些缺口里哪个必须现在补？哪个可以带 WARN 交给 design？” | `phase-prd.json.review_conclusion / issue_ledger` |
| M-S8 | canonical 工件、三视角 reviewer 结论、M-S7 缺口 | FAIL/WARN 收敛建议和用户裁决草案 | “我建议先修复这些 FAIL、接受这些 WARN 承接；是否确认？” | `phase-prd.json.review_conclusion / issue_ledger` |
| M-G1 | M-S8 收敛轮次、未关闭 FAIL、WARN 承接目标 | PASS/WARN/FAIL 裁决建议和下一跳 | “是否按此裁决进入交付确认，或回到指定步骤修复？” | `phase-prd.json.review_conclusion` |
| M-S9 | 最终 canonical 工件、PM 当前验证命令结果、下游消费边界 | 交付摘要和确认请求，列出 `/design` 会消费什么 | “请确认这些 canonical 工件可以交给 /design；若不确认，请指出要回到哪一步。” | `brief.json.delivery_confirmation` |

## 裁决式追问模板

- M-S0 内容完整性：`推荐：当前只能先验证 canonical handoff；缺 brief.json 或 phase-prd.json 时回到 /product-director 重签。请确认是否提供这两个 JSON 路径。`
- M-S4 Integration Context：`推荐：这个 UNIT 的 Integration Context 先按业务模块、不可破坏行为、跨 UNIT 依赖和排除项收口。请确认这些项是否正确，或只修正不准确的一项。`
- M-S5 示例驱动 AC：`推荐：这条 AC 先按一个正常示例、一个边界示例和一个失败模式收口；缺失项标为 [?]。请确认示例是否可验收，或修正最不准确的一条。`
- M-S5.5 Verification Plan：`推荐：验证计划只写业务操作和预期观察，不写测试命令或 Mock。请确认该操作能证明 AC，或指出缺哪个观察点。`
- M-S6 结构化待设计决策：`推荐：只把 PM 无法裁决且影响实现路径的问题交给 /design。请确认这些候选是否都需要 design 裁决，或删掉可在 PM 层收口的项。`
- M-S7/M-S8 AI 可执行性：`推荐：先修复会让下游猜测输入、输出、边界、失败处理、验证方式或影响面的 FAIL；可明确承接的风险记 WARN。请确认此裁决。`

## 高风险信号

- 用户要求直接改 Phase 边界或交付价值
- 约束事实、Owner、约束内容要被改写
- UNIT 标题开始退化成“梳理/建模/审计/SOP”
- AC 变成需求复述而不是示例驱动的可观察结果
- Verification Plan 写成命令、测试框架或 Mock 策略
- Integration Context 写成文件路径、接口方案或架构落点
- 待设计决策直接给技术答案，而不是给选项、约束和 design handoff
- 试图绕过 canonical `director_confirmation.locked_fields` / `locked_field_digest`
