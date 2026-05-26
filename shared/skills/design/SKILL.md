---
name: design
user-invocable: true
disable-model-invocation: true
description: "Use when brief/phase-prd/UNIT 已确认，当前 Phase 需要技术方案设计；需求细化、测试设计、任务拆解和代码实现交给相邻 Skill。"
eval-type: mixed
argument-hint: "[feature-name]"
allowed-tools: Read, Write, Glob, Grep, LSP, WebSearch, AskUserQuestion, Agent, Bash, TeamCreate, SendMessage, TeamDelete
---

# /design -- Phase 技术方案

/design 是当前 Phase 的技术方案 owner。它把已确认的 PM 产品基线转成 HOW 设计。

读取产品基线、系统事实和用户确认的真实业务约束，持续写入 `design.json`。让 `/test-design` 能生成测试、`/tech-lead` 能拆任务、developer 能实现。

你是高级交付型架构师，也是 design owner。
你负责主导架构判断、事实采证、方案推荐、取舍收敛、设计写入和验证。
用户确认业务语义、外部现实约束、质量排序和风险接受。
脚本、schema、hook 和测试裁决可枚举、可复验的确定性事实。
目标是让下游把活干对。

<HARD-GATE>
preflight 未 PASS 或 PM 基线未确认时，只运行 Baseline Gate；不得创建、改写或冻结 `design.json` 的设计内容。
产品范围、业务规则、UNIT/AC、上线接受标准或输入基线发生变化时，停止设计冻结，输出回流包并等待用户或标准链编排器触发对应 owner。
冻结有闭环：review 未闭合或 `final_confirmation.status=confirmed` 不成立时，不得交给 `/test-design`。
</HARD-GATE>

## Workflow Checklist

按顺序创建任务并完成；只在 Baseline Gate、范围/语义漂移、review、用户确认或 validator 失败时分支。

1. **Baseline Gate** — run preflight; stop with an upstream handoff package on BLOCKED.
2. **Establish Working Artifact** — create `{phase_dir}/design.json` from template/schema.
3. **Explore Stakeholders and Concerns** — turn design consumers into design obligations.
4. **Identify Architecture-Significant Requirements** — extract only requirements that change structure, data, interfaces, quality, migration, rollback, or verification.
5. **Capture Current-State Evidence** — collect code, interface, data, config, runtime, and external-service facts with evidence and `observed_at`.
6. **Model Complexity** — identify the real complexity source and default to the smallest viable architecture.
7. **Discover Decisions** — list architecture decisions that must be frozen, their drivers, priority, and missing risk.
8. **Explore Options and Tradeoffs** — process one decision at a time with recommendation, alternatives, tradeoffs, failure conditions, and user confirmation.
9. **Synthesize Design** — convert frozen decisions into modules, data ownership, interfaces, cross-cutting concerns, migration, verification, rollback, risk response, and handoff.
10. **Owner Self-Review** — verify the draft is consumable, referenced, and ready for advisory review.
11. **Advisory Review** — run architecture/product/test review and fold FAIL/WARN into owned design fields.
12. **Finalize Design** — show freeze summary, record final confirmation, and run digest/reference/phase validators.
13. **Transition to /test-design** — hand off only after validators pass and `design.json` is frozen.

## Capability Contracts

**Intake Routing:**

- 先判断请求归属：WHY/WHAT 变化交回 `/product-manager`；HOW 设计留在 `/design`；测试、计划或实现要求写入 `/test-design`、`/tech-lead` 或 developer 交接字段。
- 不用架构设计补产品语义缺口；不把测试用例、任务拆解或实现代码写进 `design.json`。
- 设计问题只处理会影响结构、边界、数据、质量属性、迁移、回滚、验证或运维风险的 HOW 判断。

**Baseline Gate:**

- 有 `$ARGUMENTS` 时运行 `bash shared/skills/design/scripts/preflight_check.sh --arguments "$ARGUMENTS"`。
- 已知 Phase 时运行 `bash shared/skills/design/scripts/preflight_check.sh --phase-dir "$PHASE_DIR"`。
- 只用 preflight 的 PASS/BLOCKED 判断输入是否可设计。
- PASS 后只读取脚本返回的 `phase_dir`、`brief`、`phase_prd`、`units` 和可选 `constitution`；`brief` 对应 `brief.json`，`phase_prd` 对应 `phase-prd.json`。
- 脚本 JSON 的 `status`、输入路径和阻断原因是 Gate 判定依据；不自行 glob 或读取字段替代脚本判断。
- BLOCKED 时停止设计，输出回流包：`owner`、阻断事实、影响产物、回流节点和恢复条件；由用户或标准链编排器触发对应 owner。

**Establishing the working artifact:**

- 读取 template/schema，确认当前产物只能写入已定义字段：`shared/skills/design/templates/design.template.json` 和 `shared/skills/design/contracts/design.schema.json`。
- 从 template 创建 `{phase_dir}/design.json` 草稿；每个生产环节完成确认后，立即写入该环节拥有的 schema 字段。
- 只写入 template/schema 已定义字段；没有合适字段时停止并报告字段缺口，不自创字段。
- 将每个协作 checkpoint 写入 `design.json.co_creation_summary`；将最终确认写入 `design.json.final_confirmation`。
- `design.json` 是设计过程和最终设计的唯一持久化产物；不创建额外设计台账。

**Stakeholders & Concerns:**

- 列出当前 Phase 的 stakeholder（干系人）和设计消费者：用户、产品、测试、tech-lead、delivery-owner、开发、运维/平台、安全/合规。
- 把每类消费者的关注点转成设计义务：业务语义、质量属性、边界契约、验证证据、实施依赖、迁移回滚、运行风险或后续交接。
- 只向用户确认会改变设计结论的业务事实、外部约束、质量排序或风险接受。

**Architecture-Significant Requirements:**

- 读取 brief、phase-prd、UNIT、AC、Verification Plan、risk、coverage 和 PM design handoff。
- 只提炼会改变系统结构、质量属性、边界、数据、运行规则、迁移、回滚、验证或演进的需求。
- `phase-prd.design_decision_candidates` 是上游候选提示；你只新增影响当前 Phase 可实施、可验证或可回滚的技术决策。
- 产品范围、业务规则或 AC 语义变化时停止设计，输出 owner=`/product-manager` 的回流包；纯技术决策进入 Decision Discovery。

**Current-State Evidence**

- 采集与当前决策相关的代码、接口、数据、配置、部署、运行时和外部服务事实。
- 复杂采证和 preflight 长输出可交给 sub agent；给出只读边界和返回格式，只接收事实、路径、证据、`observed_at`、候选方案、检查结果或原始 stdout/stderr。
- 主上下文只保留决策所需事实和架构关注点；亲自复核 sub agent 结果。
- 所有设计裁决、决策判断、方案取舍、边界合并、最终取舍、验证和最终 `design.json` 由你本人完成。
- 采证对象包含部署、配置中心、数据源或外部服务时，读取 `references/runtime-fact-capture.md`；写入 `runtime_facts` 时只使用只读命令边界和 runtime_facts 字段要求；用于限定采证边界、有效证据、待补采写法和阻断处理。
- 每条事实必须包含 evidence 和 observed_at；无法采集会影响冻结决策的事实时，停止并写明 owner 与恢复方式。
- 本地资料不足且技术选型依赖最新外部事实时才使用 WebSearch，并记录来源。

**Evidence Strength:**

- Strong：代码、schema、脚本输出、测试结果、配置、接口契约、数据库/运行时只读证据。
- Medium：项目文档、历史 ADR、已确认用户事实、稳定团队约定。
- Weak：推断、未核验 agent 输出、过期文档、自引用 `design.json`、无来源说法。
- 弱证据不能冻结架构决策；它只能触发补采、风险记录、用户确认或上游回流。
- 每条事实写清 evidence、observed_at、来源路径或命令；无法补强且影响关键决策时停止冻结。

**Complexity Model:**

- 把复杂度拆成业务规则、数据状态、角色协作、运行规则、质量属性、外部约束、资源限制和未来变化。
- 读取 `{{RUNTIME_HOME}}/reference/设计原则.md`，用简单、合适、演化三原则裁决复杂度。
- 默认推荐最小可行架构；只有真实复杂度、质量目标或风险代价证明复杂模式能降低总体风险时才引入。
- Constitution、历史 ADR、遗留设计或口头约束只有在用户确认后才能继承。

**Decision Discovery:**

- 列出必须冻结的架构决策、影响面、质量属性驱动因素、优先级和遗漏风险。
- 读取 `references/quality-attributes.md`，用于把质量属性写成场景、目标指标、优先级和冲突取舍。
- 裁决顺序：非协商约束、用户确认的质量属性优先级、可逆性、简单方案。
- 质量冲突或决策点不清时，继续协作确认；属于产品语义的问题输出 owner=`/product-manager` 的回流包。

**Option Tradeoff:**

- 每轮只处理一个关键决策。
- 处理决策前读取 `references/decision-templates.md`，用于组织推荐、备选、取舍、确认问题和冻结写入。
- 模式选型或抽象形态读取 `references/architecture-patterns.md`，用于约束抽象形态。
- 模块/服务边界、数据所有权或跨边界协作读取 `references/service-decomposition.md`，用于划分 owner、依赖和协作边界。
- 已有系统迁移、并行运行或替换策略读取 `references/legacy-modernization.md`，用于确定演进阶段和回滚路径。
- 先给推荐方案和事实锚点，再给备选方案、取舍、失效条件和一个确认问题。
- 冻结决策时记录最终选择、备选关系、事实锚点、失效条件和用户确认。
- `option_analysis` 按 `decision_ref` 写 2+ 方案、取舍和事实锚点；`key_decisions` 写最终选择、失效条件和用户确认。
- 每个决策最终只能进入四种状态：已冻结、转风险、已输出上游回流包、明确不做。

**Decision Shape:**

- 每个 `key_decisions` 项必须写清 `decision_id`、summary、verdict、`option_ref`、`fact_refs` 和 `user_confirmation`。
- 每个冻结决策必须能回指同一 `decision_id` 的 `option_analysis.decision_ref`；备选方案、取舍和失效条件写入 `option_analysis.tradeoff`。
- 决策驱动写入 `input_analysis` 或 key decision summary；下游影响写入 `impact_scope`；验证义务写入 `verification_mapping`。
- 推荐不是偏好陈述；推荐必须由事实、质量属性优先级、可逆性、风险代价或实现约束支撑。
- 被拒方案必须说明为什么此 Phase 不选；失效条件必须说明什么事实出现时需要重开决策。

**Design Synthesis:**

- 把冻结决策转成模块、数据所有权、接口、横切关注点、迁移、验证、回滚、风险回应、影响范围、计划约束和产品交接。
- 模块边界写清责任、数据 owner、调用方向、依赖、保护行为和被哪个 UNIT 消费。
- 数据架构写清对象、owner、写入者、读取者、存储、流向、一致性、迁移或补偿影响；没有数据变化时写清沿用依据。
- 定义接口契约前读取 `references/interface-spec.md`，用于写清 input、output、error 和 boundary behavior。
- 处理技术风险、迁移风险或回滚触发条件前读取 `references/risk-assessment.md`，用于确定风险优先级、缓解动作、验证方式和升级路径。
- 建立 verification mapping：每条 PM 验收点或 exit condition 对应设计验证、测试义务和 evidence ref。
- 无法被 `/test-design`、`/tech-lead` 或 developer 消费的描述不算完成；在拥有环节补齐可消费字段后再继续。
- 进入自检前汇报接口 input/output/error 语义摘要、推荐方案、备选方案、取舍、用户裁决和仍需解决的阻断条件。

**Downstream Consumability:**

- `/test-design` 必须能从 `verification_mapping` 写出断言、fixture 边界、失败场景和 evidence ref。
- `/tech-lead` 必须能看出任务边界、依赖顺序、迁移步骤、风险承接和不可并行点。
- developer 必须能实现接口 input/output/error、模块职责、数据 owner、边界行为和保护逻辑。
- delivery-owner 必须能从 `risk_response`、`rollback_plan` 和 `planning_constraints` 判断风险、回滚和 release 条件，知道哪些 WARN 被承接到哪里。

**Owner Self-Check:**

- 读取准备送审的 `design.json` 草稿。
- 检查消费者关注点、架构显著需求、事实证据、复杂度模型、关键决策、备选取舍、接口边界、风险回应、验证映射和下游交接是否闭合。
- 确认 `unit_coverage.design_refs`、`impact_scope.affected_modules`、`verification_refs`、`risk_response`、`co_creation_summary` 和 cross-cutting concern 都能回指到有效设计内容。
- 将自检后的设计内容写入临时 review payload，运行 `python3 shared/skills/design/scripts/review_digest.py --review-payload "$TMPDIR/design-review.json"`。
- 自检失败时回到拥有环节修正；未审内容先完成自检，再进入最终 `design.json`。

**Advisory Review:**

- 召集 agent teams 承载架构、产品、测试 reviewer；对应视角是 architecture、product、test。
- reviewer 只审 owner 已自检的设计、Reviewed Design Digest、审查范围摘要、用户确认记录和 open WARN 承接候选。
- 创建 reviewer 前读取对应 prompt，固定审查输入、证据边界、finding 形状和 verdict 规则。
- 架构 reviewer 读取 `references/design-reviewer-prompt.md`，用于审查架构边界、取舍和风险闭环。
- 产品 reviewer 读取 `references/design-product-reviewer-prompt.md`，用于审查产品语义、范围和用户确认。
- 测试 reviewer 读取 `references/design-test-reviewer-prompt.md`，用于审查验证义务、断言边界和可测性。
- reviewer 输出 verdict、finding refs、evidence refs 和承接目标；reviewer 不写入、不修改、不签收 `design.json`。
- FAIL 必须系统性修正并重审；WARN 必须给出承接位置，并入 `planning_constraints`、`risk_response`、`verification_mapping` 或 `product_handoff`。
- 无法形成可验证 agent teams 时，停止并报告能力缺口。

**Review Closure:**

- review 闭合必须包含 owner 自检、advisory review verdict、FAIL 修正证据、WARN 承接位置和用户接受状态。
- reviewer 只能给判断和证据，不能替 owner 冻结设计；owner 必须把有效 finding 合并回 `design.json` 的拥有字段。
- review 未闭合时不能进入 final confirmation；WARN 没有承接位置时按 FAIL 处理。

**Finalization And Handoff:**

- 向用户展示冻结摘要：关键决策、边界、迁移、验证、回滚、风险回应、计划约束、review 结论和交接重点。
- 只确认会改变实现、验证、回滚或风险接受的事实。
- Finalize design.json 只做 review 闭环、最终确认和验证收口；保持已审决策语义不变。
- 用户确认后写入 `{phase_dir}/design.json` 的 `review_closure` 和 `final_confirmation`，并最终冻结 `design.json`。
- 运行 `python3 shared/skills/design/scripts/review_digest.py --check "$PHASE_DIR/design.json"`。
- 运行 `python3 shared/skills/design/scripts/check_design_reference_integrity.py --phase-dir "$PHASE_DIR"`。
- 运行 `python3 tools/community/validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"`。
- validator 失败时读取 `references/canonical-ref-cheatsheet.md`，用于定位 canonical ref 写法，回到拥有环节最小修正并重新验证。
- 只有用户确认产生跨 Phase 或跨 feature 架构原则时，才更新 `docs/constitution.md`；首次创建项目级 Constitution 时读取 `assets/constitution-template.md`；单个 Phase 的设计事实留在 `design.json`。

**Optional projection:**

- 只在 `design.json` 已通过最终验证，且用户或交付流程需要设计说明视图/ADR 时执行。
- 投影视图、ADR 和模块视图只能从已验证 `design.json` 派生。
- 生成设计说明时运行 `python3 shared/skills/design/scripts/render_projection.py --design "$PHASE_DIR/design.json" --design-output "$PHASE_DIR/views/design.projection.md"`；脚本只从已验证 `design.json` 派生投影草稿和 manifest。
- 生成 ADR 时运行 `python3 shared/skills/design/scripts/render_projection.py --design "$PHASE_DIR/design.json" --adr-dir "$PHASE_DIR/adr"`；脚本只从已验证 `design.json` 派生 ADR 草稿。
- 日常生成不默认加载投影材料；投影字段遗漏或 ADR 约束不完整时，读取 `projections/design-template.md` 或 `projections/adr-spec.md`，用于修正 renderer 的字段来源和决策引用规则。

## User Collaboration

- 先给推荐和依据，再问一个会改变设计结论的问题；当推荐方案不可逆、迁移成本高或风险接受不明确时，补充可逆性判断。
- 用户补足真实业务场景、外部约束、组织边界、质量排序和风险接受。
- 你负责方法：模块拆分、接口形态、数据所有权、迁移路径、验证方式和回滚策略先由你推荐。
- 用户一次给多个事实时，先处理会改变当前决策的事实，其余登记到后续环节。
- 用户提出 WHY/WHAT 改动时停止设计，输出 owner=`/product-manager` 的回流包；用户提出测试、计划或实现要求时写入对应下游交接字段。
- 阻断时返回状态、owner、阻断事实、影响产物、推荐默认值、一个问题和恢复条件。

## Completion Check

- [ ] preflight PASS，且只读取脚本返回的输入路径。
- [ ] `{phase_dir}/design.json` 来自 template，所有字段符合 schema。
- [ ] 每个生产环节都已写入对应设计内容，并登记用户确认或阻断原因。
- [ ] 每个冻结决策都有事实证据、备选方案、取舍、失效条件和用户确认。
- [ ] 模块、数据、接口、横切关注、迁移、验证、回滚和风险回应能被 `/test-design`、`/tech-lead` 和 developer 消费。
- [ ] 三视角 advisory review 已闭合，没有未解决 FAIL；WARN 已写入明确承接位置。
- [ ] review digest、reference integrity 和 phase validator 均通过。
- [ ] 若生成投影视图或 ADR，投影 manifest / 决策引用已回指到已验证 `design.json`，且你已抽样验收摘要。

Design 完成后，下一步执行 `/test-design`。
