# Project Manager Best-Practice Rebuild Design

## 输入分析

本次变更不是对单个 `project-manager` skill 的局部优化，而是一次面向团队交付治理的链路级重构。现状已经证明：

- 当前 `project-manager` 具备较强的执行编排、质量门禁和签收推进能力。
- 当前链路对“流程是否跑完”有较强约束，对“阶段目标是否真正达成”约束不足。
- `project-manager` 要升级为“交付目标负责人”，不能只改一个 skill，必须同时重构与 `tech-lead`、`developer`、`qa`、`test-design`、contracts、templates、completion checks 和 contract tests 之间的契约。

因此，本次 design 的目标不是“补一个步骤”，而是定义一个可直接投入团队使用的目标态：让 `project-manager` 对当前 Phase 的交付目标负责，并且用工件、脚本和测试把这种责任落成真约束。

## 现状问题

### 当前强项

- `project-manager` 的 Phase 1-4 流程、熔断、签收、提交链路完整。
- `quality gate` 已经有较强的脚本和测试支撑。
- `qa-report`、`acceptance-summary`、`waivers`、`release_recommendation` 形成了较完整的 Phase 级交付闭环。

### 当前核心缺口

- 目标保真主要发生在 `tech-lead` 计划评审阶段，执行期缺少明确的持续目标校准责任。
- `project-manager` 可以推进计划，但缺少成熟的偏差治理与再基线能力。
- `Phase 3` 分级主要在 `plan.md` 里冻结，执行中缺少基于风险上调 review / QA 强度的机制。
- `acceptance-summary` 更擅长汇总门禁状态，不足以单独证明“阶段目标和交付价值已达成”。
- `preflight-evidence` 仍偏 warning，尚未成为 readiness 硬门。
- 调度能力更多体现为“执行上游计划”，还不是一个成熟的交付调度模型。

## 目标态

### 目标角色定义

目标态的 `project-manager` 定义为：

`当前 Phase 的交付目标负责人`

它在 `brief / prd / design / plan` 已确认的前提下，对以下结果负责：

- 当前 Phase 目标是否真正达成
- 开发、验证、QA、签收是否围绕同一目标推进
- 执行期偏差是否被及时识别、升级和再计划
- 签收是否建立在目标级证据，而不是只有门禁级证据

### 角色边界

目标态仍然保留以下边界：

- 不负责需求定义
- 不负责技术方案发明
- 不亲自替代 `developer / review / qa`
- 不单方面接受业务风险

目标态新增以下职责：

- 做正式的 `delivery kickoff`
- 维护 `Scope Freeze` 内的调度和取舍
- 监控并治理执行偏差
- 根据实际风险动态升级 `review / qa`
- 在签收前做目标闭环判断

## 关键设计决策

### D1. 将改造对象定义为“链路级重构”，而不是单 skill 优化

原因：

- 当前能力和缺口跨越 `tech-lead / project-manager / developer / qa / test-design`。
- 如果只重写 `project-manager`，它仍然拿不到动态升档、目标闭环、风险再基线所需的上游输入和下游证据。

结论：

- 本次实施范围必须覆盖 roles、contracts、templates、completion checks、tests 五层。

### D2. 用“目标级闭环”替代“流程级闭环”作为最终完成标准

原因：

- “Task 完成 + 门禁通过 + 用户签收”不等于“阶段目标达成”。
- 团队可用标准要求最终收口必须能回答：目标是否完成、证据是什么、残余风险是什么。

结论：

- 在保留现有门禁链的基础上，新增“目标/成功标准 -> 证据 -> 结果结论”的闭环模型。

### D3. 保留 plan 分级真源，但允许执行期动态升档

原因：

- `plan.md` 仍然是强门禁矩阵的真源，否则 Phase 3 会失控。
- 但实际复杂度、接口微调、shared files、环境变化、BLOCKED 累积，可能使原始分级不足。

结论：

- 保留 `plan.md` 为基线分级真源。
- 新增“执行期升级触发器”，允许 `project-manager` 在 guardrail 内提升 QA / review 强度或回退再计划。

### D4. 将 readiness 从软提醒升级为显式 gate

原因：

- 真实服务/真实环境/前置约束如果未就绪，问题往往被推迟到 QA 或签收才暴露。

结论：

- `preflight-evidence`、关键依赖状态、风险 owner、测试义务承接、环境 readiness 需要进入执行前硬门。

### D5. 保留一手证据，压缩重复汇总

原因：

- 当前 `developer-report` 与 `dev-report` 对 TDD、proving output 有重复搬运倾向，容易导致文档漂移。

结论：

- 一手证据保留在最靠近产生它的工件。
- `project-manager` 负责汇总、引用与抽查，不负责重复搬运整段原始输出。

## 目标能力模型

目标态 `project-manager` 必须具备 6 类能力：

1. `Delivery Kickoff`
   - 在开工前拉齐计划基线、前置约束、环境 readiness、风险 owner、关键里程碑、测试义务承接。
2. `Execution Orchestration`
   - 按批次和依赖组织开发、验证、QA、签收推进。
3. `Deviation Governance`
   - 监控复杂度偏差、修复收敛、BLOCKED、shared file 扩张、接口变化、风险接受变化，并决定是否暂停、升档或再计划。
4. `Dynamic Quality Escalation`
   - 在执行信号显示风险上升时，升级 review / QA 强度，不受限于最初最低分级。
5. `Goal Closure`
   - 在签收前回到 `brief` 成功标准、Phase 目标和交付价值，给出目标达成结论。
6. `Evidence Governance`
   - 维护工件之间的证据追踪关系，确保能从目标追到 plan、从 plan 追到 dev/qa/acceptance 证据。

## 工件模型

目标态下，关键工件应形成如下职责分工：

- `role-definition-gap.md`
  - 基线文档，说明当前角色与目标角色的差距。
- `design.md`
  - 目标态设计真源，定义角色边界、能力模型、工件模型、gate 模型和 rollout 标准。
- `tasks.md`
  - 团队可用的验收清单真源。
- `plan.md`
  - 实施任务与落地路径真源。

链路级运行工件继续保留：

- `plan.md`（Phase 工作区）：执行基线、初始分级真源
- `dev-report.md`：执行过程与一手证据引用
- `qa-report.md`：独立质量判断与放行建议
- `acceptance-summary.md`：签收收口与目标级结论
- `waivers.md`：豁免与补偿控制

## Gate 模型

### Gate 0: Delivery Kickoff

必须确认：

- `brief / prd / design / plan / test-cases` 可读且版本一致
- `preflight-evidence` 完整
- 风险 owner 已分配
- QA 交接契约已就绪
- 环境 / 依赖满足执行条件

### Gate 1: Task Exit

必须确认：

- `developer` 一手证据齐全
- `SPEC_OK + 2A/2B/2C_OK + fresh proving command` 完整
- 若命中复杂度、接口、shared file、不收敛等触发器，必须回到 `project-manager` 做升级或再计划

### Gate 2: Phase Quality

必须确认：

- plan 基线门禁已满足
- 如果执行期风险升高，已触发 review / QA 升档或 replan
- 修复后的回归范围按影响面重新判断，而不是只机械重跑失败阶段

### Gate 3: Sign-off

必须确认：

- `qa-report` 的 `release_recommendation`、`residual_risk`、QAR 台账被完整承接
- 目标级成功标准有结论：已达成 / 部分达成 / 未达成
- 用户签收建立在目标闭环与风险边界都清楚的前提上

## 团队可用标准

只有同时满足以下条件，才算达到“可投入团队使用”的标准：

- 角色边界无冲突，且真源唯一
- 新增能力都有 template + script + tests 支撑
- replay 场景能覆盖典型失败模式
- readiness、动态升档、目标闭环都能被 contract tests 检出
- 新人按文档执行时，不依赖作者口头补充即可理解和推进

## 风险与缓解

### 风险 1：改造范围过大，导致边界再次混乱

缓解：

- 先冻结目标态定义
- 所有修改围绕设计真源落地
- 每一项改造都绑定 contracts/templates/scripts/tests

### 风险 2：把 PM 做成全能 owner

缓解：

- 保持“不负责需求/设计/实现/单方风险接受”的边界不变
- 用职责矩阵明确禁止越权区

### 风险 3：能力升级变成形式主义报表

缓解：

- 所有新增字段必须绑定升级动作或门禁判断
- 删除重复搬运的一手证据

### 风险 4：团队难以上手

缓解：

- 为每项核心机制提供 replay 场景和 contract tests
- 用 rollout 标准做 pilot 准入

## 后续交接

本 design 的后续工作应分成两部分：

- `tasks.md`：把团队可用标准翻译成验收清单
- `plan.md`：把链路级改造拆成可执行任务、文件范围和验证命令
