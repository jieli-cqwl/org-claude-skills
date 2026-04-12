# 复杂链路上下文治理最佳实践优化方案

## 文档定位

这份文档回答的是一个很具体的问题：

**在复杂链路 `product -> design -> test-design -> tech-lead -> delivery-owner` 中，怎样做 runtime prompt 去章节化，让 5 个主 skill 不再各自保留独立 sub agent 章节，sub agent 只在使用点出现，同时不削弱交付质量、主 Agent 裁决力和现有跨职能评审。**

这不是“更多 agent”的方案，也不是“prompt 越短越好”的方案。  
这是一个 `runtime prompt 去章节化 + central truth 保留但引用说明收缩 + Harness 加法 + Router 显式触发 + 主 Agent 保留裁决` 的优化蓝图。

## 核心目标

1. 去掉 5 个主 skill 里的独立 sub agent 章节，只保留使用点。
2. 保留主 Agent 的确认、裁决、回退、Gate、sign-off 权限。
3. 让 sub agent 只承担可回收工序，不承担最终结论。
4. 让 central truth 继续保留在 reference/contract 中，但 prompt 只保留短锚点和使用点说明。
5. 不改坏现有跨职能评审，不把 Harness 做成新的噪音源。

## 非目标

- 不是把所有阶段都改成全自动 router。
- 不是把所有规则都下沉成脚本或 hook。
- 不是取消现有 `产品 / 架构 / 测试` 的跨职能评审。
- 不是把主 Agent prompt 削成只剩流程壳。
- 不是增加新的常驻管理层或额外状态文档。

## 调研维度

本轮 Agent Team 按 6 个维度并行梳理：

1. `Prompt / Harness` 边界
2. `sub agent` 触发与路由
3. 最小 prompt surface 与工件最小上下文
4. `contract / template / check / test / router` 的下沉边界
5. Challenger 1：从 LLM 认知与 prompt 设计角度挑战
6. Challenger 2：从工程控制面与维护成本角度挑战

## 最终结论

一句话收口：

**应该从 prompt 里移走的是“格式真相”，应该留在 prompt 里的是“判断语法”；应该交给 Harness 的是“硬不变量”，不应该交给 Harness 的是“高语义裁决”。**

对应 4 条总原则：

1. `Prompt` 只保留高杠杆语义。
2. `Harness` 只承接稳定、可机检、可恢复的硬规则。
3. `Router` 只做显式触发，不做语义代裁决。
4. `sub agent` 只做候选事实、候选草稿、状态汇总，不做最终冻结。

## 最佳实践原则

### 1. Prompt 保留语义内核，不保留格式负担

每个主阶段的 prompt 只保留 5 类内容：

- 当前阶段目标
- 主 Agent 不可下放的责任边界
- 用户共创/暂停/回退触发器
- 关键反偏置提醒
- 草稿 / 候选 / 已冻结的状态语义

runtime prompt 去章节化的直接写法是：

- 不再把 `sub agent` 单独写成一章
- 只在对应使用点写一次触发条件、输入和产物
- central truth 仍然保留，但只引用必要锚点，不复述完整说明

不再保留这些内容：

- 共享 schema 全文
- 模板字段和列顺序细节
- 长篇流程图和教学说明
- 大段 reviewer 规则复述
- 用自然语言重复已经能被模板或脚本约束的格式规则

### 2. Harness 负责硬边界，不负责高语义判断

适合下沉到 `contract / template / check / test / router` 的内容：

- 文件路径和工件存在性
- 固定字段、枚举、列名、编号规则
- 主工件与草稿工件的状态边界
- fresh proof、evidence anchor、真实依赖等硬门
- 触发阈值中的可观测条件

不适合继续下沉的内容：

- 用户是否真的理解 trade-off
- 设计方案是否“真的更优”
- Task 是否“拆得对”
- 是否应当升级审查强度
- 是否继续探索、回退还是重规划

### 3. Router 只接受显式触发条件

禁止继续使用这类主观触发：

- `需要降噪时启用`
- `必要时启用`
- `复杂项目`
- `边界清晰`
- `分析充分`
- `实际复杂度更高`

这些词如果还需要保留，只能作为历史反例或复盘说明，不能出现在 runtime prompt 的触发语句里。

允许的触发必须是可观测、可复算、可被工件状态表达的条件，例如：

- 是否存在 `UNCOVERED / DESIGN-GAP / orphan`
- 是否缺少 `proving_command / evidence_target / mock_boundary_note`
- 当前批次并行 Task 数是否 `>= 4`
- 是否存在 `BLOCKED` 累积、`shared_files` 扩张、接口漂移
- 是否缺少 `design.md / test-cases.md / acceptance-summary.md`

### 4. 不新增第二套真源

这轮优化不应再增加新的“状态真源文档”。

- `tasks.md` 继续是完成状态真源
- `plan.md` 继续是执行计划真源
- 各阶段最终工件继续是下游消费真源
- sub agent 产物只能是回收件、草稿件、派生视图或 append-only 记录

### 5. 跨职能评审保留，职责更聚焦

现有跨职能评审不取消、不降级、不改成 sub agent 代审。

改造后它的边界是：

- 继续做质量门禁
- 只审最终冻结工件
- 不信任 sub agent 自报
- 不消费未冻结草稿

sub agent 的新增位置在评审前，用于降噪，不替代评审。

## Prompt / Harness / Router 分工

| 层 | 负责什么 | 不负责什么 |
|---|---|---|
| `Prompt` | 目标、裁决边界、用户交互、回退条件、反偏置、状态语义 | 格式细节、模板列名、共享 schema 全文 |
| `Harness` | 固定字段、存在性、编号、状态边界、fresh proof、runtime integrity | 设计优劣判断、用户理解质量、探索去留 |
| `Router` | 基于工件状态的显式派发 | 代替主 Agent 做语义裁决 |
| `sub agent` | 事实采集、候选草稿、结构草稿、证据汇总 | 最终冻结、Gate、sign-off、风险接受 |

## 分阶段最佳实践方案

下面每个阶段展示的都是 runtime prompt 去章节化后的目标写法：sub agent 只在使用点出现，不再独立成章。

### `product`

主 Agent 保留：

- 根问题确认
- 目标与成功标准裁决
- 范围 / 排除项收口
- Phase / UNIT 闭环确认
- 最终交付确认

sub agent 仅做：

- `Context Scan Agent`
- `Problem Hypothesis Agent`

推荐触发：

- `/product` 进入 S1 后固定触发
- 输出只作为静默线索和候选追问点

不再保留在 prompt 的内容：

- 编号规则、列顺序、`[?]` 约定、交付计划表头等格式规则

应保留在 prompt 的内容：

- 必须先问根问题
- 必须按共创节奏推进
- 不得跳过用户确认直接产出 PRD

### `design`

主 Agent 保留：

- 关键技术裁决
- 方案收敛
- 接口和边界最终确认
- 迁移 / 验证 / 回滚决策

sub agent 仅做：

- `Runtime Fact Capture Agent`
- `Option Draft Agent`
- `ADR Draft Agent`

推荐触发：

- 采事实：进入设计且上游工件齐备后触发
- 方案草稿：识别到决策点后触发
- ADR 草稿：决策已冻结后触发

不再保留在 prompt 的内容：

- 运行时采证字段表、ADR 固定结构、issue-id 格式、评审轮次细则

应保留在 prompt 的内容：

- 必须先采事实再出方案
- 候选方案不可直接进入最终设计
- 用户确认和主 Agent 裁决是冻结前置条件

### `test-design`

主 Agent 保留：

- `DESIGN-GAP(EQ)` 判定
- 是否回流 `/design`
- QA 交接契约最终版
- 审查结论收口

sub agent 仅做：

- `Coverage Draft Agent`
- `Equivalence Draft Agent`
- `QA Handoff Draft Agent`

推荐触发：

- 上游 `brief / prd / units / design` 齐备后触发
- `coverage` 与 `equivalence` 可并行
- `QA handoff` 只能在前两者收敛后生成

不再保留在 prompt 的内容：

- 矩阵章节细节、专项测试完整枚举、report 列顺序

应保留在 prompt 的内容：

- `test-cases.md` 是 QA 交接契约，不是第二份设计
- 只有真实映射不上设计时才报 `DESIGN-GAP`
- GAP 判定只能由主 Agent 做

### `tech-lead`

主 Agent 保留：

- `DESIGN_OK`
- 计划模式选择
- `Scope Freeze`
- Task 最终冻结
- 用户确认记录
- 最终 `plan.md`

sub agent 仅做：

- `Traceability Draft Agent`
- `Task Decomposition Draft Agent`
- `Evidence Field Draft Agent`

显式触发建议：

- 覆盖矩阵存在 `UNCOVERED / DESIGN-GAP / orphan` 时，触发追踪草稿
- 追踪链已闭合但 Task 边界未稳时，触发任务拆分草稿
- Task 已定但证据字段未收口时，触发证据字段草稿

不再保留在 prompt 的内容：

- “仅在主 Agent 需要降噪时启用”
- “复杂项目”这类抽象入口词
- Task 表字段全集和长篇分级解释

应保留在 prompt 的内容：

- 冻结设计翻译为可执行计划
- Task 必须能落到文件、依赖、验证和证据
- 主 Agent 独占计划模式、Task 冻结和用户确认

### `delivery-owner`

主 Agent 保留：

- kickoff readiness 确认
- 质量门禁裁决
- 升档 / 回退 / replan 决定
- 用户签收推进
- 是否提交主干

sub agent 仅做：

- `Status Synthesis Agent`
- `Evidence Synthesis Agent`

显式触发建议：

- 当前批次并行 Task 数 `>= 4`，且 `qa-report.md` 未完成时，允许状态汇总
- 当前批次并行 Task 数 `>= 4`，且 `dev-report.md / code-review-report.md / qa-report.md` 已产出、`acceptance-summary.md` 未完成时，允许证据汇总

不再保留在 prompt 的内容：

- 矩阵表头、固定 report 字段细节、重入规则全文

应保留在 prompt 的内容：

- readiness 是前门
- drift / blocked / 不收敛要暂停并升级
- 汇总代理只能汇总既有状态，不能代替放行和签收

## 与现有跨职能评审的关系

这轮改造与现有 `Agent Team` 跨职能评审不冲突，但会收紧边界：

- 不取消 `product / design / test-design / tech-lead` 的 3 reviewer 评审
- 不把 Gate 判定交给新的 sub agent
- 不增加新的 reviewer 层数
- 只在评审前增加降噪工序
- reviewer 只审最终冻结工件，不审 sub agent 自报

换句话说：

**跨职能评审继续做质量门禁，sub agent 只做评审前降噪。**

## 修改范围

### 必改 `SKILL.md`

- `/Users/lijieli/org-claude-skills/shared/skills/product/SKILL.md`
- `/Users/lijieli/org-claude-skills/shared/skills/design/SKILL.md`
- `/Users/lijieli/org-claude-skills/shared/skills/test-design/SKILL.md`
- `/Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md`
- `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/SKILL.md`

改法：

- 去掉独立 sub agent 章节，只保留使用点
- 压缩 `共享 Sub-Agent 契约` prose
- 保留本阶段最小边界说明
- 明确不可下放责任
- 把主观触发改成显式触发

### 保留 `reference / template / contract`

- `/Users/lijieli/org-claude-skills/contracts/skill-chain.yaml`
- `/Users/lijieli/org-claude-skills/shared/reference/subagent-recovery-contract.md`
- `/Users/lijieli/org-claude-skills/shared/reference/context-noise-metrics.md`
- `/Users/lijieli/org-claude-skills/shared/reference/templates/*.md`
- 各阶段已有 reference：
  - `product/references/conversation-guide.md`
  - `design/references/runtime-fact-capture.md`
  - `design/references/decision-templates.md`
- `test-design/references/methodology.md`
  - `tech-lead/references/planning-modes.md`
  - `delivery-owner/references/dispatch-guide.md`

改法：

- 共享 contract 退回工程真源，不再要求在 runtime prompt 中重复讲
- central truth 保留，但 runtime-facing 引用说明收缩为使用点锚点
- 显式触发条件优先落在阶段 reference 或 contract 中
- 模板和共享 reference 只承载稳定规则，不承载高语义判断

### 必改脚本与测试

- `/Users/lijieli/org-claude-skills/shared/skills/*/scripts/completion_check.sh`
- `/Users/lijieli/org-claude-skills/tests/test-subagent-context-contract.sh`
- `/Users/lijieli/org-claude-skills/tests/test-skill-output-and-gate-contract.sh`
- 如有必要，再补阶段级 contract test

改法：

- 不再测试“每个 skill 都必须直接提到共享 contract”
- 改为测试：
  - 5 个主 skill 是否还保留独立 sub agent 章节
  - 是否还残留主观触发表述
  - 主 Agent 裁决权是否仍保留在 tech-lead / delivery-owner
  - 草稿是否会泄漏进最终工件
  - reviewer 是否只审最终冻结工件

## 明确不做的事

- 不再新增一份“全局触发矩阵真源文档”
- 不再新增第二套状态真源
- 不把语义裁决翻译成更多模板字段
- 不把动态升档判断机械化
- 不为了统一而要求每个阶段写同样长的 sub agent 说明

## 验收标准

### Prompt 面

1. 5 个主阶段都不再保留独立 sub agent 章节，只在使用点出现。
2. 不再重复共享 schema、模板列名、长篇流程说明。
3. 不再出现 `需要降噪时启用` 这类主观触发词。
4. central truth 继续保留，但只保留最小锚点，不再作为 runtime prompt 章节正文。

### Harness 面

1. 共享 contract 只负责硬边界。
2. completion_check 只检查硬不变量，不代替语义判断。
3. tests 只测稳定规则，不测文案风格和语义优劣。
4. `tests GREEN` 只代表硬边界通过，不单独构成“可交付”结论。

### Router 面

1. 所有 sub agent 派发都能回链到显式触发条件。
2. 触发条件都能从工件状态或运行态指标复算。
3. router 不直接生成最终结论。

### 主 Agent 面

1. 主 Agent 仍独占确认、裁决、回退、Gate、sign-off。
2. 主 Agent prompt 长度下降，但判断语法不丢。
3. 跨职能评审保持质量门禁地位不变。
4. tech-lead / delivery-owner 仍保留主 Agent 裁决权。

### 系统面

1. 不新增新的维护型噪音源。
2. 不新增多处同义约束。
3. 如新增控制面，没有对应真实失败模式就不允许合入。
4. gate 继续检查草稿不泄漏与冻结收敛，不允许把草稿当最终工件。

## 两个 Challenger 带来的修正

### Challenger A：LLM 认知 / Prompt 设计

挑战结论：

- 不能把主 Agent 的判断语法一起删掉
- `优先级 / 真源边界 / 不可下放责任 / 共创护栏 / 状态语义` 必须保留
- `Prompt 减法` 不等于“只有流程壳”

因此方案修正为：

- 保留“语义内核 prompt”
- 删除低频操作说明和重复模板负担

### Challenger B：工程控制面 / 维护成本

挑战结论：

- repo 当前已经有控制面偏重的信号
- 再把更多高语义问题下沉，会把 Harness 做成新的噪音源
- `hook / gate / test` 应该防错，不该掌舵

因此方案修正为：

- 暂停继续扩大共享 contract 的 prompt 面
- 不新增第二套真源或新的总控矩阵
- 控制面只做硬不变量与 runtime integrity

## 推荐实施顺序

1. 先改 `tech-lead`
   - 原因：当前主观触发最明显，且输入输出最结构化
2. 再改 `delivery-owner`
   - 原因：显式触发已经有基础，但要防止控制面继续膨胀
3. 然后改 `test-design`
   - 原因：结构化草稿和 GAP 边界清晰
4. 再改 `design`
   - 原因：需要保留较强语义裁决，改动要更谨慎
5. 最后改 `product`
   - 原因：用户共创最重，prompt 不能过度压缩

## Kill Criteria

只要出现下面任一信号，就暂停继续下沉：

- 改造后 prompt 变短了，但返工和回退没有下降
- 新增维护工作主要在修 Harness 自己
- tests 越来越多地在校验文案，而不是校验硬规则
- 主 Agent 因为缺少判断语法而更依赖反复追问或反复回退
- 控制面新增对象超过收益，开始形成新的上下文噪音

## 最终建议

这轮最佳实践不应该继续沿着“更多共享 contract、更强 prompt 约束、更重控制面”走。  
正确方向是：

- `Prompt` 做减法，但保留判断语法
- `Harness` 做加法，但只加硬边界
- `Router` 改成显式触发
- `sub agent` 只负责可回收工序
- `review` 继续做最终质量门禁

这才是真正符合 `Harness 思维` 的复杂链路上下文治理方案。
