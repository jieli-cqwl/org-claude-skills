# Subagent Recovery Contract

> 类型：reference（共享契约，非执行规范）。
> 用途：固定所有主阶段共用的 sub agent 回收边界、状态机、字段和机械校验规则。
> 显式触发条件由各阶段 reference 定义；本文件只定义启用后的回收边界。

## 契约原则

- 节点责任不下放，工序可下放。
- sub agent 只能产出可回收的候选事实、候选方案、结构草稿或状态汇总。
- 任何会改变最终裁决、Gate、sign-off、风险接受或编号冻结的动作，都必须留在主 Agent。

## 统一 schema

| 字段 | 类型 | 允许值 / 说明 | 必填性 |
|------|------|---------------|--------|
| `agent_kind` | enum | `fact_scan` / `hypothesis_draft` / `structure_draft` / `synthesis` | 必填 |
| `input_boundary` | list | `required_input` / `upstream_artifact` / `accepted_candidate`（其中 `accepted_candidate` 不适用于 `Synthesis`） | 必填 |
| `current_judgment_type` | enum | `fact` / `hypothesis` / `draft` / `summary` | 必填 |
| `decision_state` | enum | `候选` / `待裁决` / `已冻结` | 必填 |
| `evidence_anchor` | list | `file:line` / `table:row` / `section` | 必填 |
| `unresolved_item` | list | 每项必须包含 `owner`、`blocking_for`、`next_action` | 条件必填 |
| `forbidden_action` | list | 明确列出该 agent 不能决定的字段或 Gate | 必填 |

## 四类回收合同

| 类别 | 适用 agent | 固定输入 | 固定输出 | 回收边界 | 验收口径 |
|------|------------|----------|----------|----------|----------|
| `Fact Scan` | `Context Scan Agent`、`Runtime Fact Capture Agent` | 当前阶段 required inputs + 已存在上游工件 | `facts.md`、`constraint-list.md`、`anchor-list.md` | 只能采集事实，不能做最终判断 | 每条事实都要有证据锚点；不得包含最终裁决句 |
| `Hypothesis Draft` | `Problem Hypothesis Agent`、`Option Draft Agent` | `Fact Scan` 输出 + 当前阶段主工件 | `hypothesis-list.md`、`comparison-table.md`、`follow-up-list.md` | 只能给候选结论，不能冻结 | 候选项必须互斥、可比较、可被主 Agent 选择或否决 |
| `Structure Draft` | `Coverage Draft Agent`、`Equivalence Draft Agent`、`QA Handoff Draft Agent`、`Traceability Draft Agent`、`Task Decomposition Draft Agent`、`Evidence Field Draft Agent`、`ADR Draft Agent` | 当前阶段已冻结的上游工件 + 主 Agent 已接受的候选输入 | `*-draft.md`、矩阵草稿、字段草稿 | 只能输出结构化草稿，不能写最终编号、最终 Gate、最终签收结论 | 每一行都必须能回链到上游字段；所有未决项显式标记；禁止越权字段必须为空 |
| `Synthesis` | `Status Synthesis Agent`、`Evidence Synthesis Agent` | 已冻结 `plan.md` + 已产出的执行报告 | `delivery-status-summary.md`、`evidence-summary.md` | 只能汇总既有状态和证据，不能产生新 Gate | `input_boundary` 只允许 `required_input / upstream_artifact`；汇总结果只能引用现有报告锚点；不得新增风险接受或放行结论 |

## 状态机

| 状态 | 含义 | 允许动作 | 禁止动作 |
|------|------|----------|----------|
| `候选` | sub agent 已产出草稿或事实收集结果 | 补充证据、重排结构、继续收敛 | 写入最终工件、冻结编号、做最终裁决 |
| `待裁决` | 主 Agent 正在比较或合并多个候选 | 主 Agent 裁决、补问、重派发 | 直接下游消费为最终结论 |
| `已冻结` | 主 Agent 已将内容写入最终工件 | 下游引用、验证、签收 | 再次以草稿身份重写、回收到未冻结状态 |

## 必填 / 可空规则

| 类别 | 必填字段 | 可空字段 | 固定取值约束 | 产物合格条件 |
|------|----------|----------|--------------|--------------|
| `Fact Scan` | `agent_kind`、`input_boundary`、`current_judgment_type`、`decision_state`、`evidence_anchor`、`forbidden_action` | `unresolved_item` | `agent_kind=fact_scan`、`current_judgment_type=fact`、`decision_state=候选` | 所有事实均带锚点；无最终裁决句；`forbidden_action` 非空 |
| `Hypothesis Draft` | `agent_kind`、`input_boundary`、`current_judgment_type`、`decision_state`、`evidence_anchor`、`unresolved_item`、`forbidden_action` | 无 | `agent_kind=hypothesis_draft`、`current_judgment_type=hypothesis`、`decision_state ∈ {候选, 待裁决}` | 至少 `2` 个候选项；候选项互斥；每个候选项都有 discriminating evidence |
| `Structure Draft` | `agent_kind`、`input_boundary`、`current_judgment_type`、`decision_state`、`evidence_anchor`、`unresolved_item`、`forbidden_action` | 无 | `agent_kind=structure_draft`、`current_judgment_type=draft`、`decision_state ∈ {候选, 待裁决}` | 每一行都能回链到上游字段；禁止最终编号/最终 Gate/最终签收字段 |
| `Synthesis` | `agent_kind`、`input_boundary`、`current_judgment_type`、`decision_state`、`evidence_anchor`、`forbidden_action` | `unresolved_item` | `agent_kind=synthesis`、`input_boundary ∈ {required_input, upstream_artifact}`、`current_judgment_type=summary`、`decision_state=待裁决` | 只能引用现有报告锚点；不得新增风险接受、放行或 Gate 结论 |

## 机械校验规则

- `forbidden_action` 不能为空。
- `decision_state=已冻结` 只允许出现在主 Agent 最终工件中。
- `current_judgment_type=summary` 不得出现在 `product / design / test-design / tech-lead` 的最终主工件中。
- 所有 `unresolved_item` 必须同时包含 `owner`、`blocking_for`、`next_action`。
- 所有回收件必须使用对应模板落盘，不得用临时自由文本替代。
- 任一事实或判断缺少 `evidence_anchor`，都视为不合格。
