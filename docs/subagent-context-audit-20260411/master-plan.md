# 复杂链路 sub agent 最佳实践 Master Plan

## 文档定位

这份文档回答的是“**一步到位把完整最佳实践梳理清楚**”。

它描述的是最终目标态和完整改造蓝图，不等于要求一次性同时改完整条链。

- [rollout-plan.md](/Users/lijieli/org-claude-skills/docs/subagent-context-audit-20260411/rollout-plan.md:1) 负责回答“先做什么、后做什么”
- 本文负责回答“最终应该改成什么样、每一层到底要补什么”

一句话原则：`蓝图一次梳理完整，落地仍按 Gate 分波次推进`。

## 北极星目标

把复杂链路从“主 Agent 既要共创、又要读大量原始材料、还要维护多份结构化字段”改造成：

- 主 Agent 负责确认、裁决、Gate、回退、sign-off
- sub agent 负责只读采集、竞争假设、结构化草稿、单 Task 执行与独立验证
- 工件链负责压缩和传递上下文，而不是把长对话直接堆给下游

最终要达到的结果只有 3 条：

1. 主 Agent 不再长期背负高读写、低裁决的噪音
2. 复杂链路交付质量不下降，Gate 不弱化
3. sub agent 的引入不会把噪音搬家成“更多草稿待合并”

## 顶层设计原则

1. 节点责任不下放
`product / design / test-design / tech-lead / delivery-owner` 都保持 `position: main`。

2. 只下放可回收工序
只允许下放“候选事实、候选方案、候选矩阵、候选字段、单 Task 执行/验证”。

3. 每个 sub agent 都必须有回收合同
没有固定输入、固定输出、固定禁止越权项的 sub agent，不允许进入主链。

4. 一阶段只允许一种主模式
每个阶段只能明确采用一组 agent team 模式，不能把“竞争假设 + 并行评审 + 模块化执行”混成隐式实现细节。

5. 共享指标必须统一
降噪判断不能每个阶段各讲一套，至少要共享 `输入边界`、`证据锚点`、`未决项`、`禁止越权项` 和主 Agent 噪音度量。

## 最终目标态

### 1. `product`

主 Agent 保留：

- 根问题确认
- 成功标准裁决
- 范围与排除项收口
- Phase / UNIT 闭环确认
- 最终交付确认

允许的 sub agent：

- `Context Scan Agent`
  - 只读已有文档、历史产物、约束和影响范围
- `Problem Hypothesis Agent`
  - 产出 `2-3` 个候选根问题和待追问点

必须回收的工件：

- `problem-context-scan.md`
- `root-problem-candidates.md`
- `follow-up-question-list.md`

绝对禁止：

- 代替主 Agent 向用户做关键提问
- 代替主 Agent 决定范围和成功标准
- 直接输出最终 `brief.md / prd.md / UNIT-*.md` 结论

推荐模式：

- `Competing Hypotheses`
- `Parallel Review` 保持现状

### 2. `design`

主 Agent 保留：

- 关键技术裁决
- 方案收敛
- 接口/边界最终确认
- 迁移/验证/回滚决策

允许的 sub agent：

- `Runtime Fact Capture Agent`
  - 只读采集代码、依赖、运行时事实
- `Option Draft Agent`
  - 输出候选方案和 trade-off 草稿
- `ADR Draft Agent`
  - 为已收敛决策生成 ADR 初稿

必须回收的工件：

- `runtime-facts.md`
- `option-comparison.md`
- `adr-draft.md`
- `constraint-checklist.md`

绝对禁止：

- 代替主 Agent 做最终技术裁决
- 代替主 Agent 确定接口边界
- 让多个方案草稿并存进入最终 `design.md`

推荐模式：

- `Competing Hypotheses`
- `Plan Approval`

### 3. `test-design`

主 Agent 保留：

- `DESIGN-GAP(EQ)` 判定
- 是否回流 `/design`
- QA 交接契约最终版
- 审查结论收口

允许的 sub agent：

- `Coverage Draft Agent`
  - `AC -> 用例` 映射草稿
- `Equivalence Draft Agent`
  - 等价性矩阵草稿
- `QA Handoff Draft Agent`
  - QA 交接契约草案

必须回收的工件：

- `ac-coverage-draft.md`
- `equivalence-draft.md`
- `qa-handoff-draft.md`

绝对禁止：

- 代替主 Agent 判定 `DESIGN-GAP(EQ)`
- 代替主 Agent 决定是否回流 `/design`
- 把草稿矩阵直接视为最终 `test-cases.md`

推荐模式：

- `结构化草稿`
- `Parallel Review` 保持现状

### 4. `tech-lead`

主 Agent 保留：

- `DESIGN_OK`
- 计划模式选择
- `Scope Freeze`
- Task 最终编号与依赖
- 用户确认记录
- 最终 `plan.md`

允许的 sub agent：

- `Traceability Draft Agent`
- `Task Decomposition Draft Agent`
- `Evidence Field Draft Agent`

必须回收的工件：

- `traceability-draft.md`
- `task-draft.md`
- `dependency-draft.md`
- `parallel-strategy-draft.md`
- `evidence-pack-draft.md`

绝对禁止：

- 代签 `DESIGN_OK`
- 代替主 Agent 冻结 Task
- 代替主 Agent 决定 `标准实施 / 探索优先`

推荐模式：

- `结构化草稿`
- `Plan Approval`

### 5. `delivery-owner`

主 Agent 保留：

- Phase 1 readiness 确认
- 质量门禁裁决
- Phase 结束时的用户签收推进
- 是否提交主干

允许的 sub agent：

- 现有 developer / verifier / review / qa / fixer 链保持
- 仅允许条件触发的汇总代理，且采用唯一状态机：
  - `Status Synthesis Agent`
    - 触发时机：developer / verifier / review / qa 正在并行执行、但 `qa-report.md` 尚未完成前
    - 作用：汇总 Task 状态、BLOCKED、升级信号、批次顺序
  - `Evidence Synthesis Agent`
    - 触发时机：`dev-report.md`、`code-review-report.md`、`qa-report.md` 已产出，且 `acceptance-summary.md` 尚未完成前
    - 作用：汇总证据锚点、风险承接、签收前缺口

规则：

- 若当前 `plan.md` 并行 Task 数 `< 4`，两个汇总代理都不允许触发
- 同一时刻只允许启用其中 `1` 个
- `Status Synthesis Agent` 结束后，才允许切换到 `Evidence Synthesis Agent`
- 两者都不能替代 readiness、门禁裁决、用户签收推进

必须回收的工件：

- `delivery-status-summary.md`
- `evidence-summary.md`

绝对禁止：

- 新增“管理管理者”型常驻角色
- 用汇总代理替门禁裁决
- 让汇总代理替用户签收或业务风险接受

推荐模式：

- `Module Ownership`
- `Parallel Review`

## 阶段触发矩阵与执行顺序

| 阶段 | sub agent | 触发条件 | 执行顺序 | 是否可并行 | 回收到哪里 |
|------|-----------|----------|----------|------------|------------|
| `product` | `Context Scan Agent` | 已存在上游文档、历史工件或多来源输入 | 第一步 | 否 | `problem-context-scan.md` |
| `product` | `Problem Hypothesis Agent` | 主 Agent 初读后仍存在 `2` 个及以上 plausible root problem | 第二步 | 否 | `root-problem-candidates.md` |
| `design` | `Runtime Fact Capture Agent` | 当前需求依赖现有代码、运行时、外部依赖或迁移约束 | 第一步 | 否 | `runtime-facts.md` |
| `design` | `Option Draft Agent` | 在事实表完成后，仍存在 `2` 个及以上可行方案 | 第二步 | 否 | `option-comparison.md` |
| `design` | `ADR Draft Agent` | 主 Agent 已完成方案收敛 | 第三步 | 否 | `adr-draft.md` |
| `test-design` | `Coverage Draft Agent` | `design.md` 已冻结且进入 AC 覆盖设计 | 第一步 | 是 | `ac-coverage-draft.md` |
| `test-design` | `Equivalence Draft Agent` | `design.md` 已冻结且进入等价性设计 | 第一步 | 是 | `equivalence-draft.md` |
| `test-design` | `QA Handoff Draft Agent` | 主 Agent 已收敛 coverage / equivalence 草稿，且无待处理 `DESIGN-GAP(EQ)` | 第二步 | 否 | `qa-handoff-draft.md` |
| `tech-lead` | `Traceability Draft Agent` | `design.md + test-cases.md` 已齐备 | 第一步 | 是 | `traceability-draft.md` |
| `tech-lead` | `Task Decomposition Draft Agent` | `design.md + test-cases.md` 已齐备 | 第一步 | 是 | `task-draft.md`、`dependency-draft.md` |
| `tech-lead` | `Evidence Field Draft Agent` | 主 Agent 已接受 Task 草稿并确定当前 Task 集 | 第二步 | 否 | `evidence-pack-draft.md` |
| `delivery-owner` | `Status Synthesis Agent` | `plan.md` 并行 Task 数 `>= 4`，且 `qa-report.md` 尚未完成 | 第一阶段 | 否 | `delivery-status-summary.md` |
| `delivery-owner` | `Evidence Synthesis Agent` | `plan.md` 并行 Task 数 `>= 4`，且 `dev-report.md`、`code-review-report.md`、`qa-report.md` 已产出、`acceptance-summary.md` 尚未完成 | 第二阶段 | 否 | `evidence-summary.md` |

补充规则：

- `product / design` 默认串行，不并行启动多个草稿 agent
- `test-design / tech-lead` 允许先并行草稿，再由主 Agent 单点收敛
- `delivery-owner` 的两个汇总代理不能并行运行
- 任一阶段只允许在主 Agent 完成当前轮收敛后，才进入下一轮局部重派发

## 可执行回收合同

为让不同阶段可以直接照着实施，建议把 sub agent 统一抽象成 4 类，并固定输入、输出、回收边界与验收口径。

| 类别 | 适用 agent | 固定输入 | 固定输出 | 回收边界 | 验收口径 |
|------|------------|----------|----------|----------|----------|
| `Fact Scan` | `Context Scan Agent`、`Runtime Fact Capture Agent` | 当前阶段 required inputs + 已存在上游工件 | `facts.md`、`constraint-list.md`、`anchor-list.md` | 只能采集事实，不能做最终判断 | 每条事实都要有证据锚点；不得包含最终裁决句 |
| `Hypothesis Draft` | `Problem Hypothesis Agent`、`Option Draft Agent` | `Fact Scan` 输出 + 当前阶段主工件 | `hypothesis-list.md`、`comparison-table.md`、`follow-up-list.md` | 只能给候选结论，不能冻结 | 候选项必须互斥、可比较、可被主 Agent 选择或否决 |
| `Structure Draft` | `Coverage Draft Agent`、`Equivalence Draft Agent`、`QA Handoff Draft Agent`、`Traceability Draft Agent`、`Task Decomposition Draft Agent`、`Evidence Field Draft Agent`、`ADR Draft Agent` | 当前阶段已冻结的上游工件 + 主 Agent 已接受的候选输入 | `*-draft.md`、矩阵草稿、字段草稿 | 只能输出结构化草稿，不能写最终编号、最终 Gate、最终签收结论 | 每一行都必须能回链到上游字段；所有未决项显式标记；禁止越权字段必须为空 |
| `Synthesis` | `Status Synthesis Agent`、`Evidence Synthesis Agent` | 已冻结 `plan.md` + 已产出的执行报告 | `delivery-status-summary.md`、`evidence-summary.md` | 只能汇总既有状态和证据，不能产生新 Gate | 汇总结果只能引用现有报告锚点；不得新增风险接受或放行结论 |

统一要求：

- 所有输出都必须包含：`输入边界`、`当前判断`、`证据锚点`、`未决项`、`禁止越权项`
- 所有 `*-draft.md` 都不能被下游直接当最终工件消费
- 只有主 Agent 把内容写入最终工件后，才视为 `已冻结`

### 建议 schema

为避免 `shared/reference/subagent-recovery-contract.md` 未来出现阶段间漂移，建议直接固定下面这组字段和枚举：

| 字段 | 类型 | 允许值 / 说明 |
|------|------|---------------|
| `agent_kind` | enum | `fact_scan` / `hypothesis_draft` / `structure_draft` / `synthesis` |
| `input_boundary` | list | `required_input` / `upstream_artifact` / `accepted_candidate` |
| `current_judgment_type` | enum | `fact` / `hypothesis` / `draft` / `summary` |
| `decision_state` | enum | `候选` / `待裁决` / `已冻结` |
| `evidence_anchor` | list | `file:line`、`table:row`、`section` 三种锚点格式之一 |
| `unresolved_item` | list | 必须包含 `owner`、`blocking_for`、`next_action` |
| `forbidden_action` | list | 明确列出该 agent 不能决定的字段或 Gate |

附加约束：

- `decision_state=已冻结` 只允许出现在主 Agent 最终工件中
- `current_judgment_type=summary` 不得出现在 `product / design / test-design / tech-lead`
- `forbidden_action` 不能为空

### 各类回收合同的必填/可空规则

| 类别 | 必填字段 | 可空字段 | 固定取值约束 | 产物合格条件 |
|------|----------|----------|--------------|--------------|
| `Fact Scan` | `agent_kind`、`input_boundary`、`current_judgment_type`、`decision_state`、`evidence_anchor`、`forbidden_action` | `unresolved_item` | `agent_kind=fact_scan`、`current_judgment_type=fact`、`decision_state=候选` | 所有事实均带锚点；无最终裁决句；`forbidden_action` 非空 |
| `Hypothesis Draft` | `agent_kind`、`input_boundary`、`current_judgment_type`、`decision_state`、`evidence_anchor`、`unresolved_item`、`forbidden_action` | 无 | `agent_kind=hypothesis_draft`、`current_judgment_type=hypothesis`、`decision_state ∈ {候选, 待裁决}` | 至少 `2` 个候选项；候选项互斥；每个候选项都有 discriminating evidence |
| `Structure Draft` | `agent_kind`、`input_boundary`、`current_judgment_type`、`decision_state`、`evidence_anchor`、`unresolved_item`、`forbidden_action` | 无 | `agent_kind=structure_draft`、`current_judgment_type=draft`、`decision_state ∈ {候选, 待裁决}` | 每一行都能回链到上游字段；禁止最终编号/最终 Gate/最终签收字段 |
| `Synthesis` | `agent_kind`、`input_boundary`、`current_judgment_type`、`decision_state`、`evidence_anchor`、`forbidden_action` | `unresolved_item` | `agent_kind=synthesis`、`current_judgment_type=summary`、`decision_state=待裁决` | 只能引用现有报告锚点；不得新增风险接受、放行或 Gate 结论 |

## 全局 sub agent 合同

所有阶段共用同一份回收合同，建议新增为共享 reference。

### 必填字段

- `输入边界`
- `当前判断`
- `证据锚点`
- `未决项`
- `禁止越权项`

### 状态机

- `候选`
- `待裁决`
- `已冻结`

规则：

- 只有主 Agent 写入最终工件后，状态才能变成 `已冻结`
- 多版候选不得并存进入最终工件
- 同一字段冲突时，先收敛成冲突清单，再决定是否重派发

### 统一度量

建议新增共享度量 reference，至少统一：

- `M1` 主 Agent 手工维护字段数
- `M2` 同一事实重复回写次数
- `M3` 首轮稳定问题数
- `M4` 收敛轮次
- `M5` 草稿冲突回退数
- `M6` 草稿采用字段数

### 统一度量口径

为避免不同阶段各自定义 `PASS / FAIL / INCONCLUSIVE`，建议共享如下统计合同：

- `样本边界`
  - 一个样本 = 某一主阶段的一次完整运行
  - 起点 = 主 Agent 第一次读取该阶段 required inputs
  - 终点 = 该阶段最终工件冻结，或 terminal report 写完
- `基线样本`
  - 必须是同一阶段、未启用该阶段 sub agent 改造的历史样本
  - `tech-lead / delivery-owner` 还必须满足 Task 数量差异 `<= 3` 或相对差异 `<= 30%`
  - `product / design / test-design` 以 scope item / AC 数量差异 `<= 30%` 为可比边界
- `计数责任人`
  - 样本主 Agent 负责首计
  - 该阶段独立 reviewer 负责抽查
  - 试点负责人负责汇总

各指标统一定义为：

- `M1`
  - 主 Agent 在最终工件中亲自编写或重写的有效字段数
- `M2`
  - 同一事实被主 Agent 重复手工回写到多个草稿或最终工件的次数
- `M3`
  - 首轮完整独立审查中的稳定问题数
- `M4`
  - 从第一版完整工件到 `PASS / FAIL 已修正` 的收敛轮次
- `M5`
  - 由草稿冲突直接触发的上游回退、整包重做或整版废弃次数
- `M6`
  - 最终工件中被直接采用或仅做轻微修正后采用的草稿字段数

统一判定规则：

- `PASS`
  - 阶段 Gate 与 completion check 全部通过
  - `M1 / M2` 相比基线下降
  - `M3 / M4` 不高于基线
  - `M5 = 0`
- `FAIL`
  - 命中任何 fail-fast
  - 或 Gate / completion check 被破坏
- `INCONCLUSIVE`
  - 未命中 fail-fast，但样本不足、基线不足或指标没有形成明确结论

阶段级门槛：

- 任一阶段要宣布 `PASS` 并写回主 skill，至少需要 `3` 个正式样本
- `3` 个样本都必须有可比基线
- 任一样本命中 fail-fast，阶段直接判定 `FAIL`
- 少于 `3` 个样本、缺基线、或指标分布没有形成方向性，只能判定 `INCONCLUSIVE`

### `delivery-owner` 状态机细则

为避免汇总代理在执行期制造新的歧义，建议把状态机再收紧成下面规则：

- `并行 Task 数`
  - 统计 `plan.md` 中当前批次里状态未终态的 Task 数
  - 终态只允许：`DONE`、`CANCELED`
- `当前批次`
  - 指当前 `plan.md` 已派发、且尚未进入终态的同一批次 Task 集
- `最新版本报告`
  - 指 canonical 路径下当前存在的唯一报告文件内容；若文件被覆盖，以覆盖后的文件为准
- `Status Synthesis Agent`
  - 触发前提：并行 Task 数 `>= 4`
  - 退出条件：当前轮汇总完成，或并行 Task 数降到 `< 4`
  - 若并行 Task 数在运行中降到 `< 4`，允许完成本轮汇总，但禁止再次触发
- `Evidence Synthesis Agent`
  - 触发前提：并行 Task 数 `>= 4`，且最新版本的 `dev-report.md`、`code-review-report.md`、`qa-report.md` 已全部存在
  - 若三类报告乱序到达，必须等待缺失报告出现，禁止先汇总部分证据
  - 退出条件：`acceptance-summary.md` 冻结，或并行 Task 数降到 `< 4`
- 切换规则
  - 同一时刻只能有一个汇总代理
  - 只有 `Status Synthesis Agent` 完成或被停止后，才允许进入 `Evidence Synthesis Agent`
  - 若 `Evidence Synthesis Agent` 已运行，之后报告内容再次变化，则旧 summary 记为 `STALE`，允许重跑 `1` 次；超过 `1` 次必须升级给主 Agent 裁决

## 仓库改造面

### A. 全局合同层

建议修改或新增：

- `contracts/skill-chain.yaml`
- `contracts/identifiers.yaml`
- `shared/reference/agent-team-patterns.md`
- `shared/reference/subagent-recovery-contract.md` 新增
- `shared/reference/context-noise-metrics.md` 新增

目标：

- 把“节点责任不下放、工序可下放”写成合同
- 把阶段推荐模式、最大 agent 数、禁止越权项写成共享规则
- 把度量口径沉淀成共享 reference

强制项：

- `contracts/skill-chain.yaml`
- `shared/reference/subagent-recovery-contract.md`
- `shared/reference/context-noise-metrics.md`

建议项：

- `contracts/identifiers.yaml`
- `shared/reference/agent-team-patterns.md`

改动顺序：

1. 先改 `contracts/skill-chain.yaml`
2. 再落 `shared/reference/subagent-recovery-contract.md` 与 `shared/reference/context-noise-metrics.md`
3. 最后再改各阶段 `SKILL.md`

## 最小闭环集合

为避免“文件列了一堆，但不知道做到哪里算完成”，完整蓝图再定义一套最小必改集合：

| 集合 | 必须包含 | 说明 |
|------|----------|------|
| `G0 全局合同` | `contracts/skill-chain.yaml`、`shared/reference/subagent-recovery-contract.md`、`shared/reference/context-noise-metrics.md` | 不完成 `G0`，任何阶段都不得进入正式改造 |
| `G1 阶段主合同` | 某阶段 `SKILL.md` + 该阶段所有强制项 prompt/reference | 不完成 `G1`，该阶段不得试点 |
| `G2 阶段门禁` | 该阶段 `completion_check.sh` + 直接消费新字段的模板 | 不完成 `G2`，该阶段不得宣布回写完成 |

跨面依赖顺序：

1. 先完成 `G0`
2. 再完成目标阶段的 `G1`
3. 最后完成目标阶段的 `G2`

完成标准：

- 某阶段“试点完成” = `G0 + 该阶段 G1` 完成，且样本验证通过
- 某阶段“回写完成” = `G0 + 该阶段 G1 + 该阶段 G2` 完成
- 建议项默认不计入“是否完成”的硬门槛，但若被采用，必须与强制项同步一致

### B. `product` 改造面

- `shared/skills/product/SKILL.md`
- `shared/skills/product/references/conversation-guide.md`
- `shared/skills/product/references/completeness-checklist.md`
- `shared/skills/product/references/prd-reviewer-prompt.md`
- `shared/skills/product/references/architect-reviewer-prompt.md`
- `shared/skills/product/references/tester-reviewer-prompt.md`
- `shared/skills/product/scripts/completion_check.sh`

目标：

- 显式引入 `Context Scan Agent` 与 `Problem Hypothesis Agent`
- 规定触发条件、最大 agent 数、回收件和越权边界

强制项：

- `shared/skills/product/SKILL.md`
- `shared/skills/product/references/completeness-checklist.md`
- `shared/skills/product/references/prd-reviewer-prompt.md`
- `shared/skills/product/references/architect-reviewer-prompt.md`
- `shared/skills/product/references/tester-reviewer-prompt.md`
- `shared/skills/product/scripts/completion_check.sh`

建议项：

- `shared/skills/product/references/conversation-guide.md`

改动顺序：

1. 先改 `shared/skills/product/SKILL.md`
2. 再改 reviewer prompt 与 checklist
3. 最后改 `conversation-guide.md` 与 completion check

### C. `design` 改造面

- `shared/skills/design/SKILL.md`
- `shared/skills/design/references/runtime-fact-capture.md`
- `shared/skills/design/references/decision-templates.md`
- `shared/skills/design/references/adr-spec.md`
- `shared/skills/design/references/design-reviewer-prompt.md`
- `shared/skills/design/references/design-product-reviewer-prompt.md`
- `shared/skills/design/references/design-test-reviewer-prompt.md`
- `shared/skills/design/scripts/completion_check.sh`

目标：

- 引入事实采集与方案草稿
- 保持技术裁决单点负责

强制项：

- `shared/skills/design/SKILL.md`
- `shared/skills/design/references/runtime-fact-capture.md`
- `shared/skills/design/references/design-reviewer-prompt.md`
- `shared/skills/design/references/design-product-reviewer-prompt.md`
- `shared/skills/design/references/design-test-reviewer-prompt.md`
- `shared/skills/design/scripts/completion_check.sh`

建议项：

- `shared/skills/design/references/decision-templates.md`
- `shared/skills/design/references/adr-spec.md`

改动顺序：

1. 先改 `shared/skills/design/SKILL.md`
2. 再改 `runtime-fact-capture.md`
3. 再改 3 份 reviewer prompt
4. 最后改 supporting reference 与 completion check

### D. `test-design` 改造面

- `shared/skills/test-design/SKILL.md`
- `shared/skills/test-design/references/methodology.md`
- `shared/skills/test-design/references/testdesign-reviewer-prompt.md`
- `shared/skills/test-design/references/testdesign-product-reviewer-prompt.md`
- `shared/skills/test-design/references/testdesign-arch-reviewer-prompt.md`
- `shared/skills/test-design/scripts/completion_check.sh`

目标：

- 引入覆盖矩阵、等价性矩阵、QA handoff 草稿
- 保持 `DESIGN-GAP(EQ)` 裁决单点负责

强制项：

- `shared/skills/test-design/SKILL.md`
- `shared/skills/test-design/references/methodology.md`
- `shared/skills/test-design/references/testdesign-reviewer-prompt.md`
- `shared/skills/test-design/references/testdesign-product-reviewer-prompt.md`
- `shared/skills/test-design/references/testdesign-arch-reviewer-prompt.md`
- `shared/skills/test-design/scripts/completion_check.sh`

改动顺序：

1. 先改 `shared/skills/test-design/SKILL.md`
2. 再改 `methodology.md`
3. 再改 3 份 reviewer prompt
4. 最后改 completion check

### E. `tech-lead` 改造面

- `shared/skills/tech-lead/SKILL.md`
- `shared/skills/tech-lead/references/planning-modes.md`
- `shared/skills/tech-lead/references/decomposition-patterns.md`
- `shared/skills/tech-lead/references/plan-reviewer-prompt.md`
- `shared/skills/tech-lead/references/plan-product-reviewer-prompt.md`
- `shared/skills/tech-lead/references/plan-test-reviewer-prompt.md`
- `shared/skills/tech-lead/references/templates/plan-template.md`
- `shared/skills/tech-lead/scripts/completion_check.sh`

目标：

- 把 `Traceability / Task / Evidence` 三类草稿正式纳入合同
- 保持 `plan.md` 仍是单一真源

强制项：

- `shared/skills/tech-lead/SKILL.md`
- `shared/skills/tech-lead/references/planning-modes.md`
- `shared/skills/tech-lead/references/plan-reviewer-prompt.md`
- `shared/skills/tech-lead/references/plan-product-reviewer-prompt.md`
- `shared/skills/tech-lead/references/plan-test-reviewer-prompt.md`
- `shared/skills/tech-lead/references/templates/plan-template.md`
- `shared/skills/tech-lead/scripts/completion_check.sh`

建议项：

- `shared/skills/tech-lead/references/decomposition-patterns.md`

改动顺序：

1. 先改 `shared/skills/tech-lead/SKILL.md`
2. 再改 `planning-modes.md`
3. 再改 `plan-template.md`
4. 再改 3 份 reviewer prompt
5. 最后改 completion check 与 supporting reference

### F. `delivery-owner` 改造面

- `shared/skills/delivery-owner/SKILL.md`
- `shared/skills/delivery-owner/references/dispatch-guide.md`
- `shared/skills/delivery-owner/references/phase3-dispatch.md`
- `shared/skills/delivery-owner/references/kickoff-checklist.md`
- `shared/skills/delivery-owner/references/templates/dev-report-template.md`
- `shared/skills/delivery-owner/references/templates/code-review-report-template.md`
- `shared/skills/delivery-owner/references/templates/acceptance-summary-template.md`
- `shared/skills/delivery-owner/scripts/completion_check.sh`

目标：

- 不新增常驻协调层
- 只在满足并行 Task 与多报告双条件时增加汇总工序
- 保持 `delivery-owner` 的 readiness、门禁、sign-off 推进职责不变

强制项：

- `shared/skills/delivery-owner/SKILL.md`
- `shared/skills/delivery-owner/references/dispatch-guide.md`
- `shared/skills/delivery-owner/references/phase3-dispatch.md`
- `shared/skills/delivery-owner/scripts/completion_check.sh`

建议项：

- `shared/skills/delivery-owner/references/kickoff-checklist.md`
- `shared/skills/delivery-owner/references/templates/dev-report-template.md`
- `shared/skills/delivery-owner/references/templates/code-review-report-template.md`
- `shared/skills/delivery-owner/references/templates/acceptance-summary-template.md`

改动顺序：

1. 先改 `shared/skills/delivery-owner/SKILL.md`
2. 再改 `dispatch-guide.md` 与 `phase3-dispatch.md`
3. 再改 3 个模板
4. 最后改 completion check 与 kickoff checklist

## 最大 agent 数建议

为防止“用更多 agent 制造更多噪音”，建议显式写入上限：

| 阶段 | 推荐最大 sub agent 数 |
|------|----------------------|
| `product` | `2` |
| `design` | `3` |
| `test-design` | `3` |
| `tech-lead` | `3` |
| `delivery-owner` | 满足双条件时最多 `1` 个汇总代理，且不常驻 |

## 最佳实施顺序

完整蓝图虽然一次性梳理完，但实际实施仍建议按下面顺序：

1. 先完成全局合同层
2. 先落 `tech-lead`
3. 再落 `test-design`
4. 再评估 `design`
5. 最后才讨论 `product`
6. `delivery-owner` 只做条件式补强，不单独开主改造波次

原因：

- `tech-lead` 已有最完整的试点合同、度量口径和强 Gate 兜底
- `test-design` 可直接复用覆盖矩阵、等价性矩阵、handoff 草稿这一类结构化回收合同
- `design` 和 `product` 都直接绑定关键裁决或用户共创
- `delivery-owner` 已有成熟的执行 agent 链，不适合再增加常驻协调层

## Gate 与治理

### 进入主 skill 的统一门槛

任一阶段想把试点逻辑写回主 skill，必须同时满足：

- 真实复杂样本已验证
- 有配对基线
- `M1 / M2` 下降
- `M3 / M4` 不高于基线
- `M5 = 0`
- 既有 completion check 未被削弱

### 全链路停机线

出现任一项，停止扩圈：

- 主 Agent 需要阅读更多草稿才能完成裁决
- Gate、completion check、sign-off 被绕开
- 某阶段开始通过“增加 reviewer 层数”而不是“改进回收工序”来解决噪音
- 某阶段的 sub agent 没有固定回收件和越权边界

### 不允许做的事

- 不允许把完整阶段整体下放
- 不允许把 `DESIGN_OK`、`DESIGN-GAP(EQ)`、sign-off 交给 sub agent
- 不允许把“什么时候触发多 agent”藏在补充说明里
- 不允许在 `delivery-owner` 继续叠加管理者

## 你这次真正要的一句话版本

如果要把“合理利用 sub agent 来解决上下文问题”做彻底，最佳实践不是只挑一个点试试看，而是一次性把：

- 全链路目标态
- 每阶段的主/sub 边界
- 共享回收合同
- 度量口径
- 仓库改造面
- rollout 治理规则

全部定义完整，然后再按 `tech-lead → test-design → design → product` 的顺序落地。
