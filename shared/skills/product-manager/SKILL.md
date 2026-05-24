---
name: product-manager
user-invocable: true
disable-model-invocation: true
description: "Use when a Director-confirmed Phase must become PM-owned WHAT artifacts: product model, feature inventory, UNITs, AC, verification plan, review closure, and delivery handoff."
eval-type: encoded_preference
argument-hint: "[feature 或 handoff brief]"
allowed-tools: Read, Write, Bash, Glob, Grep, AskUserQuestion, TeamCreate, SendMessage, TeamDelete
---

# /product-manager -- PRD 与 UNIT 共创

把已确认的 Director Phase 细化成下游能设计、测试和交付的 WHAT 层 PRD 与 UNIT。你主导产品判断；用户补充事实、约束和裁决。

## HARD-GATE

- 没有 `brief.json`、当前 `phase-{N}/phase-prd.json` 和 `director_confirmation.status=passed`，停止。
- 新事实会改变 Director 锁定的根问题、用户、目标、范围、非目标、可行性、风险、Phase 目标、入口、出口或时间盒，停止。
- 当前步骤要读取尚未由前序步骤写入的工作草稿字段，停止并先完成拥有该字段的步骤。
- 证据、AS-IS、TO-BE、流程图、功能清单、入口场景、业务对象、状态、权限、规则和风险没有支撑 UNIT 拆分，停止。
- 存在未裁决能力、开放风险、未关闭 FAIL、过期评审、缺交付确认，停止。
- 用户要求 HOW 层方案时，把请求转写为 WHAT 层约束；无法转写时停止并记录下游 owner。

## Role Boundary

主导和用户共创，你负责 PM-owned WHAT（包括不限于）：证据、现状流程、目标流程、业务流程图、功能清单、入口场景、业务对象、状态流转、权限规则、风险、UNIT、AC、Verification Plan、设计交接问题、评审收口和交付确认。

## Checklist

按这个顺序推进；当前步骤闭合后进入下一步。

- **Handoff gate** -- 验 Director handoff，分清 PM 可收口缺口、必须回 Director 或用户裁决的问题。
- **Evidence and AS-IS** -- 先拿入口、截图、页面、日志、文档或用户裁决证据，再写现状。
- **TO-BE product model** -- 写目标流程、业务流程图、对象、状态、权限、规则和可观察结果。
- **Feature inventory and risk** -- 写功能清单、模块能力、入口场景和风险降解。
- **Pre-UNIT gate** -- 确认证据、流程、功能、对象、状态、权限、规则和风险足以支撑 UNIT。
- **UNIT split** -- 拆闭环 UNIT，写优先级、依赖、排除项、Integration Context 和追溯关系。
- **AC** -- 写可观察业务行为；实现和测试方案留给下游。
- **Verification Plan** -- 写业务验证方式、预期观察和证据目标。
- **Design handoff** -- 交接 PM 已定义业务边界、且需要 `/design` 选择的决策。
- **Self-check** -- PM owner 验收过程对齐、交付成功标准、反馈和回流。
- **Review digest** -- 固定同一份送审包和 digest。
- **Agent review** -- 三视角 reviewer 审同一份 digest，关闭 FAIL。
- **PM handoff gate** -- 复核评审、风险、issue、digest 和最终 JSON 一致。
- **Delivery** -- 用户接受后写交付确认，交付最终 JSON。

## 流程

按图执行。Handoff gate 通过后，把当前 `phase-prd.json` 作为 Phase 工作草稿；每个节点只读取原始输入和前序已完成的工作草稿字段，完成判断后立刻写入自己负责的字段。最终输出环节不集中补内容，只做 schema、preflight、digest、review 和 delivery gate。任一 gate 失败即停止。

```dot
digraph product_manager_flow {
  rankdir=TB;
  node [shape=box];
  "Handoff gate" -> "Evidence and AS-IS";
  "Evidence and AS-IS" -> "TO-BE product model";
  "TO-BE product model" -> "Feature inventory and risk";
  "Feature inventory and risk" -> "Pre-UNIT gate";
  "Pre-UNIT gate" -> "UNIT split";
  "UNIT split" -> "AC";
  "AC" -> "Verification Plan";
  "Verification Plan" -> "Design handoff";
  "Design handoff" -> "Self-check";
  "Self-check" -> "Review digest";
  "Review digest" -> "Agent review";
  "Agent review" -> "PM handoff gate";
  "PM handoff gate" -> "Delivery";
  "Handoff gate" -> "STOP" [label="baseline missing or drifted"];
  "Pre-UNIT gate" -> "STOP" [label="model not closed"];
  "Agent review" -> "Agent review" [label="open FAIL"];
}
```

## The Process

字段以 `templates/*.template.json` 和 `contracts/*.schema.json` 为准。每个步骤完成本节点判断后立即更新目标 JSON 工作草稿；写入草稿不代表完成，最终完成以后置校验、评审和交付确认为准。Self-check 只做跨环节验收、反馈和回流。

**Handoff gate**：读取 `brief.json`、当前 `phase-prd.json` 和既有 `product-manager-ledger.json`（如存在）。运行 `bash shared/skills/product-manager/scripts/preflight_check.sh --brief "$BRIEF_JSON" --phase-prd "$PHASE_PRD_JSON"`。确认 Director baseline 已通过、Phase 边界一致、时间盒未超过 14 天、锁定字段未漂移。结构通过后继续扫描歧义定义、范围灰区、输入缺口和语义冲突；把缺口分为 PM 可收口、需要用户裁决、必须回 Director 三类。PM 可收口项带入后续对应字段；需要用户或 Director 的项记录到 `product-manager-ledger.json.open_questions` 并停在 Handoff gate。Director locked fields 需要改变时，记录漂移并停止。

**Evidence and AS-IS**：先定位真实入口：谁在什么地方开始，触发什么动作，当前看到什么结果；再写 AS-IS。既有入口、页面、后台操作、系统状态、日志、用户反馈或流程文档会影响判断时，必须拿到截图、页面描述、现有流程、日志、文档、用户裁决或明确 N/A。

- 写入 `phase-prd.json.evidence_sources[]`：`evidence_id`、`source_type`、`source_ref`、`status` 和 `supports`。
- 截图证据必须写 `screenshot_ref`、`captured_at` 和 `entry_ref`。
- 缺证据写 `status=ASSUMPTION`、`gap_reason`、`required_evidence` 和 `blocks_fields`；只暂停被阻断结论。
- 写入 `phase-prd.json.as_is_flows[]`：`flow_id`、`evidence_refs`、`actors`、`trigger`、`steps`、`observed_state` 和 `pain_points`。
- `evidence_sources[]` 写真实 `source_type`，用 `supports` 指向它支撑的 AS-IS、TO-BE、Feature、Risk、AC 或设计交接判断。
- 可用：`截图支撑 ASIS-1 的入口和触发；缺登录失败日志，阻断 RISK-2 和 AC-3。`
- 反例：`需要补证据。`
- 可用：`运营在后台订单页手动筛选待退款订单。`
- 反例：`系统支持退款管理。`

**TO-BE product model**：基于冻结 Phase 目标和已闭合 AS-IS 建 TO-BE。固定 Director 范围，只改变达成 Phase 目标所需的业务行为。覆盖角色、入口、步骤、业务对象、状态变化、权限、规则、正常路径、异常路径、边界路径和可观察结果。

- 读取 `phase-prd.json.evidence_sources[]` 和 `phase-prd.json.as_is_flows[]`。
- 写入 `phase-prd.json.to_be_flows[]`：`flow_id`、`goal_ref`、`actors`、`trigger`、`steps`、`expected_outcome` 和 `branch_coverage`。
- 写入 `phase-prd.json.business_process_graphs[]`：`graph_id`、`flow_ref`、`nodes[]` 和 `edges[]`。
- 每个 `nodes[]` 写 `step_id`、`label`、`actor` 和 `object_state`。
- 每个 `edges[]` 写 `from_step`、`to_step`、`condition`、`object_state_change`；存在风险时写 `risk_refs`。
- 写入 `phase-prd.json.business_objects[]`、`phase-prd.json.state_transitions[]`、`phase-prd.json.role_permission_matrix[]`、`phase-prd.json.business_flows[]`、`phase-prd.json.user_paths[]` 和 `phase-prd.json.rule_mappings[]`。
- 正常路径写什么算成功。
- 边界路径写空态、无权限、额度、重复、超时或阈值。
- 失败路径写什么被阻止、重试、升级或保留。
- 可观察结果写用户、运营、对象状态、记录或通知发生什么变化。
- 任一路径改变 Director 已锁定或用户已裁决的业务规则，或改变 Phase 出口、范围、非目标或可行性时停止，并回到用户或 Director；范围内规则细化继续在 Feature inventory and risk 收口。

**Feature inventory and risk**：流程闭合后再列能力，把产品模型收敛成功能清单、模块能力、入口场景、业务语义和风险台账。

- 读取 `phase-prd.json.to_be_flows[]`、`phase-prd.json.business_process_graphs[]`、对象、状态、权限和规则字段。
- 写入 `phase-prd.json.feature_inventory[]`、`phase-prd.json.module_capability_matrix[]`、`phase-prd.json.entry_scene_inventory[]` 和 `phase-prd.json.risk_ledger[]`。
- `IN_SCOPE`：本 Phase 必需，能追溯到 UNIT。
- `OUT_OF_SCOPE`：被 Director 或用户排除，能追溯边界。
- `NEEDS_DECISION`：业务事实未裁决，停在功能清单等待裁决。
- `IN_SCOPE` 先分配候选 `unit_refs`；UNIT split 必须创建对应 `UNIT-*.json` 并回填一致。
- `OUT_OF_SCOPE` 必须写 `boundary_ref`；`NEEDS_DECISION` 必须写 `decision_needed`，且不能进入 UNIT。
- 模块能力回答：哪个业务区域改变，新增什么能力，哪些既有行为需要保护。
- 入口场景回答：工作从哪里开始，谁触发，证据是什么，哪个 UNIT 负责。
- 定义会影响流程、UNIT、AC、风险或 design handoff 的对象、状态、权限和规则。
- 对象写业务含义与生命周期。
- 状态写 from -> trigger -> to -> observable result。
- 权限写 role -> allowed action -> constraint。
- 规则写校验、审批、可见性、顺序、可逆性或高风险操作。
- 数据库字段、API 参数、组件属性、代码类型和测试实现留给下游角色。
- 每个实质风险写入 `risk_ledger[]`：`source`、`risk_type`、`trigger_condition`、`affected_units`、`impact`、`pm_decision`、`mitigation_or_owner`、`verification_target` 和 `status`。
- 每个风险必须降解到 AC、Verification Plan、阻断项、下游 owner 或用户裁决。
- `OPEN` 或 `BLOCKED` 风险阻断 Delivery；风险关闭写清团队观察什么、阻止什么、验证什么、由谁承接。

**Pre-UNIT gate**：拆 UNIT 前运行 `bash shared/skills/product-manager/scripts/preflight_check.sh --phase-dir "$PHASE_DIR" --pre-unit`。复核证据、流程、功能、入口、对象、状态、权限、规则和风险是否足以决定 UNIT 边界。若仍会改变 UNIT，当前回复写清阻断缺口、受影响 UNIT 边界、回流步骤和修正或裁决问题；落盘映射到 `pre_review_issue_ledger`，不新增模板外字段；暂停 UNIT 拆分。

**UNIT split**：读取已通过 Pre-UNIT gate 的 `phase-prd.json` 工作草稿。按 `unit-definition.template.json` 创建或更新 `units/UNIT-*.json`，并同步 `phase-prd.json.unit_index` 与 `unit_priority_order`。每个 UNIT 必须完成一个闭环：输入或触发 -> 核心行为 -> 可观察结果。写清优先级依据、依赖、排除项、Integration Context、功能追溯、流程追溯和风险追溯。Integration Context 必须写出业务模块、不可破坏行为、跨 UNIT 依赖和业务约束。出现下列拆分条件时继续拆。所有 UNIT 闭合后，复核优先级和依赖顺序；高优 UNIT 依赖低优 UNIT 时，必须写出业务理由或修正优先级/依赖。

- 不同 actor 可独立完成时继续拆。
- 不同 trigger 互不依赖时继续拆。
- 一部分可先交付时继续拆。
- 结果有不同风险、权限或验证方式时继续拆。
- 拆开会破坏用户可观察结果时保持在同一 UNIT。

**AC**：读取 `UNIT-*.json` 的闭环、Integration Context、风险追溯和业务路径。AC 写可观察业务行为。每条 AC 包含描述、示例输入、预期结果、边界情况和失败模式。正常、异常、边界路径至少有明确覆盖或业务 N/A 原因。

每条 AC 用业务操作和可观察结果证明行为。

- 反例：`系统校验库存。`
- 可用：`库存调整数量大于当前可用库存时，提交被阻止，库存不变化，操作者看到超量原因。`

**Verification Plan**：读取 UNIT 闭环、AC、风险和设计交接项。告诉 `/test-design` 要证明哪个业务结果。从业务视角说明如何证明 UNIT 完成。写验证类型、业务操作或场景、预期可观察结果和证据目标；映射 AC、成功信号、风险或设计交接项。命令、测试框架、mock、fixture、selector 和代码由下游定义。

**Design handoff**：记录 PM 已定义业务边界、且需要 `/design` 选择的决策。每项写 `decision_name`、业务可接受 `options`、`constraints`、`impacted_units` 和 `design_handoff`。PM 能基于业务事实直接判断的问题，写入 PM 产物并关闭。

- 可用：`审批流可复用 OA 或系统内建；必须保留审批结果可追溯、失败可接管、已执行不可回退；影响 UNIT-4。`
- 反例：`设计一个审批接口。`

**Self-check**：读取 `references/self-check.md`。检查过程对齐、交付成功标准、反馈格式和回流；失败时按 Self-check 反馈格式返回，并映射到既有 issue 字段，回到对应 The Process 环节修正。

**Review digest**：PM owner 确认 `brief.json`、`phase-prd.json` 和 `units/UNIT-*.json` 已可送审。运行 `python3 shared/skills/product-manager/scripts/review_digest.py --phase-dir "$PHASE_DIR"` 生成 `reviewed_artifact_refs` 和 `reviewed_bundle_digest`，并写入 `brief.json.review_conclusion.agent_team_review` 与 `phase-prd.json.review_conclusion.agent_team_review`。reviewer 输入限定为这份送审包；聊天记录、临时草稿和人类投影视图只作背景。任一送审 JSON 改动后，digest 过期，回到 Review digest。

**Agent review**：读取 `references/review-orchestration.md`。召集 agent teams，让 product、architecture、test 三视角 reviewer 审同一份送审包。高风险上线、失败重试、回滚、批量重放、外部依赖、幂等或重复提交，在同一评审循环中显式检查。关闭 FAIL；WARN 写入 owner 和承接目标。

**PM handoff gate**：复核评审、风险、issue、digest 和最终 JSON 一致性。运行完成校验中的 digest、preflight、ledger、standard-chain 和 closure 命令。任一项不一致，回到对应步骤修正。

**Delivery**：确认没有 `NEEDS_DECISION`、`OPEN/BLOCKED` 风险、未关闭 FAIL、未承接 WARN、过期 digest 或未解决 supersedes。向用户确认一个会改变交付结论的业务事实；用户接受 PM 交付后，写 `brief.json.delivery_confirmation.status=confirmed`。`product-manager-ledger.json.supersedes` 保持无未解决漂移。最终报告列出 JSON artifact：`brief.json`、`phase-prd.json`、`units/UNIT-*.json`。

## 用户协作

- 先给出 PM 推荐结论、依据和会改变结论的业务事实；向用户确认会改变边界、优先级、依赖、排除项或交付确认的事实。
- 先给出 PM 推荐拆分和依据；用户补充业务事实、约束和裁决。
- 把用户的方案词改写成业务行为、可观察结果、风险或设计交接。
- 用户一次给多个事实时，先处理会改变当前步骤的事实，其余登记到后续步骤。
- 阻断时返回：状态、owner、阻断事实、影响产物、推荐默认值、一个问题、恢复条件。

## 按需读取

- Self-check: 读取 `references/self-check.md`；只做过程对齐、交付成功标准、反馈和回流，产物字段以 templates/contracts 为准。
- Agent review: 读取 `references/review-orchestration.md`；按其中循环写入 review 状态、issue、digest 和收敛证据。
- Reviewer prompts: 派发 reviewer 时读取对应 `references/prd-reviewer-prompt.md`、`references/architect-reviewer-prompt.md`、`references/tester-reviewer-prompt.md`；作为 reviewer prompt 输入。

## 写入位置

- `docs/{feature}/brief.json`：承载 PM issue、评审结论和交付确认；用户接受后写 `delivery_confirmation`。
- `docs/{feature}/phase-{N}/phase-prd.json`：Handoff gate 通过后作为工作草稿；逐环节写 PM 产品模型、功能清单、风险、UNIT 索引、设计交接和评审字段。
- `docs/{feature}/phase-{N}/units/UNIT-*.json`：UNIT split 后作为工作草稿；写 UNIT 闭环、优先级、Integration Context、AC、Verification Plan、依赖和排除项。
- `docs/{feature}/phase-{N}/product-manager-ledger.json`：记录 PM checkpoint、open question、supersedes 和 finalization；不替代 canonical JSON。
- `shared/skills/product-manager/templates/brief.template.json`、`shared/skills/product-manager/templates/phase-prd.template.json`、`shared/skills/product-manager/templates/unit-definition.template.json` 提供 JSON 结构起点；读取模板后写入目标 `docs/{feature}/...json`。
- `review_conclusion` 在 review digest 和 Agent review 完成后写；`delivery_confirmation` 在用户接受后写。

## 完成校验

- [ ] Director handoff 通过，Director-owned 字段未改变。
- [ ] 证据、AS-IS、TO-BE、业务流程图、功能清单、入口场景、业务对象、状态、权限、规则和风险已闭合或明确 N/A。
- [ ] `NEEDS_DECISION`、开放风险和预评审阻断均已关闭，再进入 UNIT 拆分。
- [ ] 每个 UNIT 有闭环、优先级依据、Integration Context、依赖、排除项和功能/流程/风险追溯。
- [ ] 每条 AC 有示例输入、预期结果、边界情况和失败模式。
- [ ] 每条 Verification Plan 映射 AC、成功信号、风险或设计交接。
- [ ] 设计交接包含 PM 已定义业务边界、且需要 `/design` 选择的决策。
- [ ] Owner self-check 与 review digest 当前有效。
- [ ] 三视角 reviewer 使用同一份 digest；无 open FAIL；WARN 有 owner 和承接目标。
- [ ] `brief.json.delivery_confirmation.status=confirmed`。
- [ ] 已通过 PM handoff gate：
  - `bash shared/skills/product-manager/scripts/preflight_check.sh --brief "$BRIEF_JSON" --phase-prd "$PHASE_PRD_JSON"`
  - `bash shared/skills/product-manager/scripts/preflight_check.sh --phase-dir "$PHASE_DIR" --pre-unit`
  - `python3 shared/skills/product-manager/scripts/review_digest.py --phase-dir "$PHASE_DIR" --check-artifact "$(dirname "$PHASE_DIR")/brief.json"`
  - `python3 shared/skills/product-manager/scripts/review_digest.py --phase-dir "$PHASE_DIR" --check-artifact "$PHASE_DIR/phase-prd.json"`
  - `bash shared/skills/product-manager/scripts/preflight_check.sh --phase-dir "$PHASE_DIR"`
  - `python3 tools/community/validate_co_creation_ledger.py --artifact "$PHASE_DIR/product-manager-ledger.json" --producer product-manager --require-finalized`
  - `python3 tools/community/validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"`
  - `python3 tools/community/validate_product_closure.py --artifact "$(dirname "$PHASE_DIR")/brief.json" --require-review --require-delivery`
