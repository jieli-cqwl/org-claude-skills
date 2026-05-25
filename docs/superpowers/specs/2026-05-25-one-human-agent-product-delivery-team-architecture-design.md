# 1人+agent 产品研发交付团队架构设计

## 1. 设计目标

本设计定义 `1人+agent 产品研发交付团队` 的组织架构，而不是单条 skill 流程线。

目标是形成一套可冻结、可交接、可继续工程化的架构上下文，使后续 `artifact flow / freeze gate`、contracts、schema、scripts、agent packets 都能建立在清晰边界上。

本轮冻结范围：

- 五层组织系统
- 核心角色使命与边界
- 角色产出能力类别
- 冻结上下文修正
- artifact flow / freeze gate 控制矩阵
- active context、bounded loop、support interface、evidence provenance、signoff 边界

本轮不冻结：

- 仓库现有 `contracts/schema/scripts` 的可执行契约
- `standard-chain.yaml` 的 delivery-owner staged gates 实现
- `delivery-state.schema.json` 条件约束实现
- `signoff-package.schema.json` 字段增强
- validator / completion gate / runtime hook 实现

## 2. 总体架构

评审可视化入口：[`2026-05-25--one-human-agent-product-delivery-team--architecture-diagram.html`](./2026-05-25--one-human-agent-product-delivery-team--architecture-diagram.html)。

该 HTML 是产品、研发、测试和交付团队评审时的主展示材料，包含整体架构图、产物流架构图和现有流程查漏补缺矩阵。Markdown 图稿只作为可编辑源稿；普通浏览器直接打开 Markdown 时不会按预期渲染内嵌 HTML/CSS。

这套团队是五层组织系统：

1. **L0 Human Control Tower**
   用户是唯一最终 owner，掌握方向、范围、质量底线、风险接受、投入取舍和最终签收。

2. **L1 Core Definition Chain**
   `product-director → product-manager → design → test-design → tech-lead → delivery-owner` 逐层冻结 `WHAT / HOW / TEST / PLAN / RUN`。

3. **L2 Execution Agent Pool**
   `developer / verify / review / qa / fix / consistency-auditor` 被 delivery-owner 调度，负责执行、验证、审查、QA、修复和审计证据，不拥有最终决策权。

4. **L3 Assurance Spine**
   `schema / template / preflight / traceability / artifact registry / validators / deterministic gates / advisory evidence / recovery state` 贯穿全链路，不属于某个角色的外挂能力。

5. **L4 Support Interfaces**
   `research / knowledge-memory / skill production / eval / feedback / ops-growth` 是支撑接口组，不进入主链，不直接修改 canonical baseline。

定版表述：

> 1人+agent 产品研发交付团队，是以用户为最终决策塔、以 WHAT/HOW/TEST/PLAN/RUN 逐层冻结为核心链、以执行 agent 池完成交付闭环、以工程保障脊柱保证可验证可恢复、以外围支撑接口推动长期演化的组织系统。

## 3. 核心角色定义

### 3.1 product-director

**Mission**：冻结产品方向、问题空间、业务目标、Phase 边界和业务风险框架。

**Owns**：`brief.json`、`phase-prd.json`、opportunity framing、problem definition、business goals、non-goals、success metrics、phase sequencing rationale、stakeholder/risk framing、decision log。

**Consumes**：用户原始意图、业务背景、research inputs、约束材料。

**Outputs**：Director-confirmed baseline、Phase handoff、scope boundary、business risk notes、user confirmation statement。

**Cannot decide**：最终是否做、投入多少、接受哪些风险、最终签收。

**Escalation**：目标冲突、范围不清、业务风险接受不清时回用户。

### 3.2 product-manager

**Mission**：把 Director-confirmed Phase 转成可验收的 WHAT 产品模型。

**Owns**：`UNIT-*.json`、PM product model、business verification targets、acceptance trace map、PM handoff、review closure、phase-prd delta requests。

**Consumes**：Director-confirmed `brief.json` / `phase-prd.json`。

**Outputs**：UNIT、AC、scope / exclusions / dependency map、terminology alignment、business proof obligations、design handoff package、test-design inputs。

**Cannot decide**：架构方案、测试策略、执行计划、风险接受、最终签收。

**Escalation**：AC 不可判定、UNIT 边界冲突、范围与 Director baseline 漂移时回 product-director 或用户。

**Boundary correction**：PM 不拥有 `brief / phase-prd` canonical。PM 只能提出 delta request；Director locked fields 只能由 product-director 或用户确认后更新。

### 3.3 design

**Mission**：把 WHAT 基线转成可消费的 HOW 架构契约。

**Owns**：`design.json`、architecture decisions、module map、interface contracts、data ownership、error modes、migration/rollback、quality attributes、risk response、operational constraints、observability needs。

**Consumes**：UNIT、AC、business verification targets、runtime/code/data evidence。

**Outputs**：architecture review digest、projection / ADR view、integration constraints。

**Cannot decide**：产品范围、AC、发布优先级、最终验收口径。

**Escalation**：产品输入不足回 PM；关键取舍需要业务裁决时回用户。

**Boundary correction**：`design.json` 是 canonical source；ADR 和人类视图只能从 canonical projection 派生。

### 3.4 test-design

**Mission**：把 WHAT/HOW 转成 TEST contract 和 QA handoff。

**Owns**：`test-cases.json`、test obligations、acceptance evidence map、test strategy、test oracle、test level selection、negative path obligations、fixture/data contract、environment contract、regression obligations。

**Consumes**：UNIT、AC、`design.json`、risk responses。

**Outputs**：QA handoff packet、cross-unit obligations、developer/verifier testing obligations、regression obligations。

**Cannot decide**：业务是否接受风险、实现方案是否改、QA 是否签收。

**Escalation**：AC 不可测试回 PM；设计不可观测回 design；真实依赖验收路径或风险接受不清回用户。

**Boundary correction**：QA handoff 是 handoff packet，不是 canonical source of truth。TEST canonical 是 `test-cases.json / test obligations / acceptance evidence map`。

### 3.5 tech-lead

**Mission**：把 WHAT/HOW/TEST 基线设计成可调度、可验证、可收敛的执行架构。

**Owns**：`plan.json`、`tasks.json`、`plan_version`、execution strategy、WBS、dependency topology、critical path、batch/parallel strategy、worktree/isolation boundary、Task Packet system、proving command wiring、evidence target wiring。

**Consumes**：UNIT、`design.json`、`test-cases.json`、QA handoff。

**Outputs**：frozen Task Packet system、delivery-owner scheduling inputs、developer/verifier acceptance targets、integration checkpoint map。

**Cannot decide**：改产品范围、改架构决策、放宽测试义务、签收。

**Escalation**：输入未冻结、依赖不可计划、Task 无法验收或只能 Mock-only 时回对应 owner 或用户。

### 3.6 delivery-owner

**Mission**：把冻结执行架构推进成受控交付和可签收事实包。

**Owns**：`delivery-state.json`、`artifact-registry.json`、runtime scheduling、dispatch packets、risk escalation、loop convergence record、user-decision package、signoff-package。

**Consumes**：frozen `plan_version`、`tasks.json`、active refs、QA handoff、environment/dependency readiness。

**Outputs**：delivery-state、dispatch packet、batch execution log、blocked-state snapshot、risk ledger、recoverable state snapshot、handoff resume point、delivery report、commit handoff。

**Cannot decide**：重写执行架构、接受业务风险、改变验收标准、提交授权。

**Escalation**：资源/环境不可执行、证据不足、风险接受不清、循环无进展时回 tech-lead、对应 owner 或用户。

**Boundary correction**：delivery-owner 只能在 frozen `plan_version` 内选择推进节奏、runtime scheduling、dispatch order 和资源排程。改变 batch / parallel / isolation / critical path 必须回 tech-lead replan 或用户裁决。

## 4. 执行 agent 池

### developer

按单个 Task Packet 完成最小实现，产出代码变更、developer-report、proving evidence、changed files list、scope adherence note。Task Packet 不清、真实依赖不可用或证明命令不可执行时回 delivery-owner，不自行补需求。

### verify

验证单 Task 是否满足 AC、scope 和证据要求，产出 verify-result、AC-by-AC verdict、gap classification、fix routing suggestion。verify 验 task contract，不替 QA 做用户路径签收。

### review

做提测前整体代码审查，产出 review-result、blocking/non-blocking findings、architecture drift、security/maintainability risks、test gap findings。review 是 advisory evidence，PASS 不等于风险接受或签收。

### qa

从用户路径验证交付是否达到可用和可验收，产出 qa-result、user-path evidence、cross-unit acceptance、release readiness signal、defect report。QA PASS 是 signoff readiness input，不是最终签收。

### fix

对明确 FAIL 做根因分析和最小修复，产出 fix-report、root cause、minimal fix diff、fix verification、non-regression evidence。fix 不是二次开发入口，不能顺手重构或扩大范围。

### consistency-auditor

只读检查冻结工件之间的漂移、遗漏、矛盾和追踪断链，产出 consistency-audit-report、trace breaks、artifact drift、coverage gaps。auditor advisory-only，不修改 artifact，不替用户签收。

## 5. Freeze Gate Matrix

每段冻结必须回答：stage、owner、required inputs、canonical outputs、allowed mutation、PASS gate、FAIL route、escalation owner。

| Stage | Owner | Required Inputs | Canonical Outputs | Allowed Mutation | PASS Gate | FAIL Route |
|---|---|---|---|---|---|---|
| Director WHAT | product-director | 用户意图、业务背景、research inputs、约束材料 | `brief.json`, `phase-prd.json` | 方向、目标、Phase、non-goals、业务风险 | 用户确认 Director baseline | 目标/范围/风险不清 → user |
| PM WHAT | product-manager | Director-confirmed brief / phase-prd | `UNIT-*.json`, PM product model, acceptance trace map, delta requests | UNIT、AC、边界、业务证明目标 | UNIT/AC 可判定、可设计、可测试 | scope/phase conflict → product-director 或 user |
| HOW | design | UNIT、AC、business verification targets、runtime facts | `design.json` | HOW 架构契约 | 决策有 evidence、tradeoff、review closure | WHAT 缺口 → PM；业务取舍 → user |
| TEST | test-design | UNIT、AC、design.json、risk responses | `test-cases.json`, test obligations, acceptance evidence map | 证明路径、证据口径、测试义务 | AC/design/risk 有测试义务或豁免 | AC 不可测 → PM；设计不可观测 → design；风险不清 → user |
| PLAN | tech-lead | UNIT、design.json、test-cases.json、QA handoff | `plan.json`, `tasks.json`, `plan_version` | 执行结构 | tasks 可派发、可验证、依赖清楚、用户确认 plan_version | 输入缺口回 owner；执行取舍回 user |
| RUN | delivery-owner | frozen plan_version、tasks、active refs、QA handoff、readiness | `delivery-state.json`, `artifact-registry.json`, user-decision package | runtime scheduling、dispatch、state、risk escalation | 执行证据闭合，风险状态明确 | implementation → fixer；plan → tech-lead；scope/risk/auth → user |
| SIGNOFF | delivery-owner prepares; user signs | delivery-state、QA/verify/review/audit evidence、risk ledger、authorization basis | `signoff-package.json`, delivery report, commit handoff | readiness 汇总 | 用户明确签收、接受风险、授权提交 | residual risk/evidence/auth 缺失 → user |
| SUPPORT | support capability; accepted by L1 owner | research、memory、skill、eval、feedback、ops/growth materials | cited evidence/ref, decision input, backlog suggestion | 不直接改 canonical | relevant owner 接收并记录 provenance | stale/conflicting/low-confidence ignored or escalated |

## 6. Active Context Pack

每个 agent 接手必须有最小上下文包，避免 artifact 面过宽导致自选上下文或补事实。

Required fields:

- `current_stage`
- `active_refs`
- `required_inputs`
- `stale_refs`
- `conflict_precedence`
- `decision_boundary`
- `open_gaps`
- `evidence_refs`
- `resume_point`
- `next_allowed_actions`

规则：

- 只消费 active refs。
- stale / archived refs 不作为当前事实。
- artifact 冲突时按 conflict_precedence 找真源或回 owner 裁决。
- open gaps 必须有 owner。
- next_allowed_actions 之外的动作需升级。

## 7. Bounded Loop Protocol

delivery-owner 管理 RUN 阶段循环时必须有停止条件。

默认规则：

- `max_rounds`: 10 轮。
- `no_progress_rule`: 同一 gap 连续 2 轮没有新证据、新 owner 或范围缩小时暂停。
- `gap_taxonomy`: implementation / requirement / design / test / environment / dependency / risk / authorization。
- `pause_states`: BLOCKED / NEEDS_REPLAN / NEEDS_USER_DECISION / SIGNOFF_PENDING。
- `resume_contract`: resume_stage、resume_condition_ref、blocker_owner、allowed_next_stages。

回派规则：

- implementation gap → fixer，修复后回 verify/QA。
- plan gap → tech-lead。
- design gap → design。
- requirement / AC gap → product-manager 或 product-director。
- environment / dependency gap → delivery-owner 暂停并记录 owner。
- risk / scope / authorization gap → user decision。

## 8. Gate Types

L3 Assurance Spine 包含两类控制，不得混写。

**Deterministic gates**：schema、template、preflight、validator、coverage、required refs、state transition checks。失败时阻断推进。

**Advisory evidence**：review、audit、risk notes、research insight、eval signal。可阻断推进，但不能签收、不能接受风险、不能直接修改 canonical。

## 9. Support Interface Contract

L4 是 support interface groups，不是主链角色。

支持接口包括：research、knowledge/memory、skill production、eval、feedback、ops/growth。

规则：

- 默认 input-only，不阻断主链。
- 只能由 relevant L1 owner 显式接收。
- 只能作为 cited evidence/ref、decision input 或 backlog suggestion 进入主链。
- 不能直接写 canonical baseline。
- 支撑输入如果 stale、冲突、低置信度，默认 ignored 或升级到 owner，不自动改 artifact。

## 10. Evidence Provenance

所有 evidence 输出必须区分事实、假设、建议。

Required fields:

- `type`: fact / assumption / recommendation
- `source`
- `owner`
- `observed_at`
- `expires_at`
- `confidence`
- `canonical_impact`

规则：

- fact 可以进入 canonical。
- assumption 只有经 owner 或用户确认后才能进入 canonical。
- recommendation 只能作为 decision input。

## 11. Result Consumption Rule

执行 agent 的结果只能按以下方式进入 RUN / SIGNOFF。

| Result | Consumption |
|---|---|
| developer-report | task evidence；必须进入 verify |
| verify-result | task PASS/FAIL；驱动 task state |
| review-result | advisory evidence；blocking finding 可阻断 QA；PASS 不等于风险接受 |
| qa-result | user-path evidence；signoff readiness input；PASS 不等于最终签收 |
| fix-report | loop evidence；必须回 verify/QA 复验 |
| audit-report | consistency evidence；FAIL 触发 owner routing；PASS 不等于签收 |

## 12. Signoff Boundary

`signoff-package` 不是用户签收本身。

它只能表示 delivery-owner 汇总的 readiness package，可包含：

- verification evidence
- review evidence
- QA evidence
- audit evidence
- risk ledger
- authorization basis
- open residual risks
- recommended decision

最终 acceptance、risk acceptance、commit authorization 只能来自用户。

后续工程化时，`signoff-package` 语义应保留：

- `requires_user_signoff`
- `authorization_ref`
- `accepted_risks`
- `signoff_status`

## 13. 工程化 Backlog

本设计不直接修改仓库可执行契约。后续工程化至少包括：

- `standard-chain.yaml` 拆 delivery-owner staged gates。
- `delivery-state.schema.json` 增加 READY / WAIVED / BLOCKED 条件约束。
- `signoff-package.schema.json` 增加 readiness vs acceptance 字段语义。
- `artifact-registry` / `delivery-state` 增加 active context pack 或 resume packet schema。
- loop protocol 落成 validator / completion gate。
- preflight evidence、status card、delivery report、commit handoff 分类为 canonical / projection / transient handoff。
- read-only review task hook 与全仓既有质量门禁脱钩，或另开门禁修复任务。

## 14. 冻结结论

当前可以冻结：

- conceptual architecture
- clean freeze context
- freeze control matrix
- role boundary corrections
- support interface contract
- bounded loop protocol
- active context pack requirement
- signoff readiness boundary

当前不能声称冻结：

- repo executable contracts
- schema invariants
- validators
- scripts
- runtime hooks

下一步应先用评审可视化入口对齐产品、研发、测试和交付团队，基于目标架构图对比现有流程查漏补缺。评审确认缺口后，再决定进入 artifact flow / freeze gate 详细矩阵设计或工程化 implementation planning。
