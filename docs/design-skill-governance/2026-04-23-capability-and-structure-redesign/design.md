# design skill 能力与结构治理

## Why

标准链路中的 `design` skill 负责把已冻结的产品需求转成架构约束，但当前版本仍把关键架构问题分散在流程步骤里，没有显式回答清单，也没有把 product 层新引入的示例驱动 AC、`Integration Context`、`Verification Plan` 变成稳定的输入契约。结果是 AI 在大需求场景下容易遗漏数据架构、横切关注点和质量属性权衡，`design.json` 对下游 `test-design`、`tech-lead`、`dev` 的约束也不够清晰。

这次治理的目标不是重做标准链路，而是在保留现有 `design` skill 形态的前提下，把它补成一个对 AI 更明确、对上下游更一致、对验证更友好的 HOW 层设计节点。

## Scope

- In scope: 重定义 `design` skill 的核心问题框架、Manager → Design handoff gate 与 traceability contract、S1/S3/S6/S7 的增量流程调整、`design.json` 完整 output contract delta、schema/template/validator/standard-chain contract/golden fixture 的 must-sync 边界、评审 prompt 与完成校验同步。
- Out of scope: 改动标准链路阶段顺序、重做 10 步 wizard 流程、改变 8 条 HARD-GATE、重做 `test-design`/`tech-lead`/`dev` 的职责模型、为简单需求引入 `design` 阶段。`test-design` 对新字段的显式主流程消费本轮只定义兼容边界与后续切换条件，不在本轮直接重构。

## Approach

### 设计原则与链路定位

本次治理沿用上一轮产品层已确认的三条原则，并把它们落到 HOW 层：

- P1 每层只回答下一层自己无法回答的问题。`design` 只回答跨模块、难逆转、对实施有强约束的架构问题；类设计、算法细节、库级选型继续留给 `tech-lead` 和 `dev`。
- P2 AI 下游消费者需要的是约束，不是实现方案。`design.json` 的职责是冻结模块边界、接口、数据所有权、质量属性、迁移闭环，而不是替实现阶段写伪代码。
- P3 模糊性在哪一层就在哪一层消灭。架构层面的模糊不能继续留给实现阶段自行判断。

链路定位保持不变：`product-director` 回答 WHY，`product-manager` 回答 WHAT，`design` 回答 HOW（架构），`test-design` 回答 HOW（测试），`tech-lead → dev` 回答 DO。

### Design 必须回答的 9 个核心问题

新增显式“核心问题总览”，让 `design` 完成条件从“走完 10 步”升级为“9 个问题都被回答并落到 canonical 字段”。这里的“主要文档化步骤”指最终结果主要写入哪个步骤，并不表示思考只发生在该步骤；像 Q5 这类决策会先在 S4-S5 被识别和探索，再在 S6 冻结落文。

这组问题由 Arc42、ATAM、C4 和 Rozanski & Woods 的共同关注域提炼而来，再用 P1 过滤掉 `tech-lead` / `dev` 可以自行回答的问题。

| # | 核心问题 | canonical 落点 | 主要文档化步骤 |
|---|---|---|---|
| Q1 | 当前系统的技术现状和约束是什么？ | `input_analysis`、`runtime_facts` | S2 |
| Q2 | 关键质量属性及其优先级是什么？ | `quality_attributes` | S3 |
| Q3 | 系统拆成哪些模块，各自职责和数据所有权是什么？ | `modules` | S6 |
| Q4 | 模块间接口契约是什么？ | `interfaces`、`interface_boundary` | S6 |
| Q5 | 数据如何建模、存储和流转？ | `data_architecture` | S6 |
| Q6 | 横切关注点如何统一处理？ | `cross_cutting_concerns` | S6 |
| Q7 | 关键架构决策及其替代方案是什么？ | `key_decisions`、`option_analysis` | S4-S5 |
| Q8 | 从当前到目标的迁移、验证、回滚路径是什么？ | `migration_plan`、`verification_plan`、`verification_mapping`、`rollback_plan` | S7 |
| Q9 | 已识别的架构风险和应对策略是什么？ | `risks`、`risk_response` | S7 |

其中有三项是本次明确补齐的能力缺口：

- Q2 质量属性从“有提及”升级为“有优先级排序、关键场景、权衡点”，但不强制每项都写完整 ATAM 量化场景。
- Q5 数据架构从隐式思考升级为显式输出，要求写明存储选型理由、数据流向、以及一致性策略。
- Q6 横切关注点要求先判断“沿用已有模式”还是“必须新增模式”，并至少检查认证授权、错误处理、日志可观测、配置管理四项。

Q3 和 Q5 的边界明确区分：Q3 只声明模块拥有哪个数据域，这是分解决策；Q5 才定义这些数据如何存、如何流、如何保持一致，这是实现层架构设计。

### Manager → Design 消费契约

`design` 不再笼统读取 `brief.json + phase-prd.json + UNIT-*.json`，而是按三类输入消费：

| 输入类别 | target canonical 路径 | 设计阶段处理方式 |
|---|---|---|
| 直接消费 | `docs/{feature}/phase-{N}/units/UNIT-*.json.acceptance_criteria[*]` | 用来校验接口输入输出、错误码与边界条件是否覆盖业务验收。 |
| 直接消费 | `docs/{feature}/phase-{N}/units/UNIT-*.json.integration_context` | 转译成代码扫描目标、兼容性约束和模块依赖图输入。 |
| 直接消费 | `docs/{feature}/phase-{N}/units/UNIT-*.json.verification_plan[*]` | 为每条业务验证补齐至少一条技术验证覆盖。 |
| 直接消费 | `docs/{feature}/brief.json.scope_boundaries`、`brief.json.non_goals`、`brief.json.design_decisions` | 约束设计边界，避免过度设计和术语漂移。 |
| 参考消费 | `docs/{feature}/brief.json.appetite`、`brief.json.design_decisions` 中的可行性约束摘要 | 约束方案复杂度和可选技术边界。 |
| 参考消费 | `docs/{feature}/brief.json.issue_ledger[*]`、`phase-{N}/phase-prd.json.issue_ledger[*]` | 驱动架构风险回应，帮助理解产品层的边界 WHY。 |
| 不消费 | 共创过程记录、评审流水账 | 不进入运行时裁决。 |

对 `待设计决策` 的消费方式也做了收口：`design` 必须承接决策主题和约束条件；Manager 给出的候选选项只作为业务视角参考，不绑定架构方案空间。

`Appetite` 与架构现实冲突时不得静默降级。`design` 必须把冲突显式写出来，例如“当前 Appetite 为 2 周，但满足选定质量属性的最小架构需要 6 周”，然后要求用户裁决是调大投入还是降低目标。

#### handoff gate

`/design` 不只消费产品内容本身，也必须消费上游已经冻结的交付状态：

- `brief.json.delivery_confirmation.status=confirmed` 是进入 `/design` 的硬前置条件。
- 只消费 canonical `review_conclusion / issue_ledger` 中已经冻结的摘要、WARN 承接目标和未关闭 FAIL；不消费评审过程流水账。
- 若存在未关闭 FAIL、未确认交付、或 WARN 没有明确 handoff target，`/design` 必须阻断并回退到对应的 product 阶段，而不是带着未收敛问题继续设计。

S1 的读取与缺失处理规则也需要显式化：

- `acceptance_criteria[*]` 缺失：立即 FAIL，因为 `design` 无法证明接口与验收的对应关系。
- `integration_context` / `verification_plan[*]` 缺失：legacy handoff 下 WARN，upgraded handoff 下 FAIL。
- `brief.json.delivery_confirmation`、`review_conclusion`、`issue_ledger` 缺失或不满足门槛：立即 FAIL。

#### 最小追踪合同

仅说明“读取了上游输入”还不够，`design.json` 需要把承接关系做成可验证的 traceability contract。最小约定如下：

| 上游输入 | 最小追踪键 | design 落点 |
|---|---|---|
| UNIT | `unit_id` | `unit_coverage[*].unit_id`、`modules[*].unit_refs` |
| AC | `ac_ref` | `interfaces[*].ac_refs`、`unit_coverage[*].ac_refs` |
| Verification Plan | `verification_ref` | `verification_mapping[*].verification_ref` |
| 上游风险 / issue | `risk_ref` | `risk_response[*].risk_ref` |
| 影响范围 | `scope_item_id` | `impact_scope[*].scope_item_id` |

兼容模式下，`ac_ref` 和 `verification_ref` 允许先用 `UNIT-{N}#acceptance_criteria[{index}]`、`UNIT-{N}#verification_plan[{index}]` 这种数组索引引用；等 product 工件补齐稳定 ID 后，再切到显式 `ac_id / verification_id`。`scope_item_id` 继续保留为 `design → test-design` 的边界追踪键，不能在本轮治理中丢失。

#### 冲突裁决路径

| 冲突类型 | 裁决层 |
|---|---|
| 接口、模块、数据流方案与技术实现冲突，但不改变业务意图 | `/design` 内解决 |
| 示例驱动 AC、Verification Plan、Integration Context 需要改写业务行为或验收口径 | 回退 `/product-manager` |
| `Appetite`、范围、`Non-goals`、Phase 节奏、根问题或 Director 风险判断需要变化 | 回退 `/product-director` 或请求用户裁决 |
| 上游已确认字段与设计现实冲突，但无法明确落在哪一层 | 先阻断，再由用户裁决 |

#### 兼容与 cutover

过渡期不能只写“先 WARN 再说”，必须有明确切换信号：

- `legacy handoff`：product 工件尚未提供稳定 traceability 键或增强后的 handoff 字段时，`/design` 允许兼容读取，并对缺失项发 WARN。
- `upgraded handoff`：当以下条件同时成立时启用：
  1. `product-manager` 的 canonical 模板 / schema / gate 已发布 `brief.json.non_goals`、`brief.json.appetite`、`UNIT-*.json.integration_context`、`UNIT-*.json.verification_plan[*]`。
  2. 标准链 golden fixtures 已携带这些字段。
  3. 对应 validator / contract tests 已把这些字段纳入必检。
- cutover owner：本治理任务的实现者负责同步 template/schema/contract/tests，并在 rollout 验证中证明两种模式都可判定。
- mixed old/new phase 策略：cutover 之前创建的 phase 继续按 legacy handoff 判定；cutover 之后新建的 phase 缺少这些字段即 FAIL，不允许混用同一 phase 的 old/new handoff 规则。
- WARN 退出条件：product 侧 canonical 模板、validator 和 golden fixtures 全量升级，且 `legacy handoff` 不再出现在标准链 golden 路径里。

### 流程步骤增量调整

保留现有 S1-S10 和 8 条 HARD-GATE，不新增阶段，只做以下增量调整：

- S1 `读取输入`：从“读三个 canonical 文件”改成结构化消费清单，并增加 Manager 产出完整性检查。
- S3 `共创：问题拆解`：在进入决策识别前先收口 Q2 质量属性优先级、关键场景和权衡点；这里也是 `Appetite` 冲突的第一次升级点。
- S6 `共创：边界与接口共识`：扩展为 Q3 → Q4 → Q5 → Q6 四段式呈现。S6 仍是一个步骤，但必须分段暂停确认，避免一次性压给用户。
- S7 `共创：质量与演进闭环`：要求每条 Manager `Verification Plan` 至少被一条技术验证覆盖，同时允许新增架构级验证项；风险部分先承接 Director 风险，再补技术层新发现风险。
- S9 `跨职能评审`：保留 3 视角 × 最多 10 轮机制，但 reviewer prompt 增补新的必查项。

新增评审点如下：

- DR-7：质量属性是否有优先级与关键场景，数据架构是否说明数据所有权与一致性策略。
- DP-4：技术验证方案是否完整覆盖 Manager `Verification Plan`，映射关系是否可追溯。
- DT-5：横切关注点是否形成统一模式，数据一致性策略是否可测试。

### 输出契约与完成校验同步

`design.json` 从“能表达设计”升级为“能表达下游真正需要的架构约束”。核心字段调整如下：

| 字段 | 类型 | 变化 |
|---|---|---|
| `quality_attributes` | 增强 | 增加 `priority_ranking`、`key_scenarios`、`tradeoff_points`。 |
| `modules[*]` | 新增/加厚 | 每个模块补 `responsibility`、`data_ownership`、`interface_summary`。 |
| `data_architecture` | 新增 | 写存储决策、数据流向、一致性策略及其理由。 |
| `cross_cutting_concerns` | 新增 | 每项记录 `concern`、`strategy`（沿用已有/新设计）、`pattern`。 |
| `verification_mapping` | 新增 | 建立 Manager 业务验证到技术验证的覆盖映射。 |
| `risks` | 新增 | 统一承载设计期风险清单。 |
| `risk_response` | 增强 | 记录 `director_risk_ref` 与 `architecture_response`（能消解/能缓解/无法缓解）。 |
| `impact_scope` | 新增 | 承载 `scope_item_id` 级影响范围清单。 |
| `planning_constraints` | 新增 | 承载 `待计划约束`。 |
| `unit_coverage` | 新增 | 承载 UNIT/AC 到设计承接位置的覆盖关系。 |
| `product_handoff` | 新增 | 承载上游确认状态、WARN 承接、关键 handoff 摘要。 |

#### 完整 output contract delta

这次不是“只加几个新字段”，而是要把当前 design contract 已经要求但尚未在 canonical template/schema 中闭合的内容一起收口：

| 类别 | 处理方式 |
|---|---|
| 保留并继续 authoritative 的字段 | `input_analysis`、`key_decisions`、`option_analysis`、`runtime_facts`、`interfaces`、`interface_boundary`、`quality_attributes`、`migration_plan`、`verification_plan`、`rollback_plan` |
| 新增为 authoritative 的字段 | `modules`、`data_architecture`、`cross_cutting_concerns`、`verification_mapping`、`risks`、`risk_response`、`impact_scope`、`planning_constraints`、`unit_coverage`、`product_handoff` |
| 保留为 canonical 但不作为核心设计裁决字段的元数据 | `co_creation_summary`、`inherited_constraints_confirmation`、`delivery_confirmation_snapshot` |
| 迁移 / 收口 | 现有 reference 中分散表达的“共创摘要 / 既有约束继承确认 / 影响范围清单 / 待计划约束 / UNIT 覆盖”统一进入 canonical JSON，再由投影视图渲染 |
| 删除 / 退休 | `quality_attributes.risk_assessment` 这种分散风险写法；风险 contract 统一收口到顶层 `risks[] + risk_response[]` |

`authoritative_fields` 必须随之同步更新；如果某字段暂不升为 authoritative，需要在实现阶段显式写出原因，不能保持模糊状态。

新增字段的最小子结构也必须固定，至少达到以下粒度：

| 字段 | 最小子字段 |
|---|---|
| `verification_mapping[*]` | `verification_ref`、`unit_id`、`ac_refs`、`technical_checks` |
| `unit_coverage[*]` | `unit_id`、`ac_refs`、`design_refs`、`scope_item_ids` |
| `impact_scope[*]` | `scope_item_id`、`unit_id`、`change_type`、`evidence_ref` |
| `product_handoff` | `delivery_confirmation_status`、`review_refs`、`open_warn_targets` |
| `risks[*]` | `risk_ref`、`dimension`、`priority`、`mitigation_summary` |
| `risk_response[*]` | `risk_ref`、`architecture_response`、`verification_refs` |

与之配套的 must-sync 文件边界如下：

- `shared/skills/design/SKILL.md`：新增“核心问题总览”和“流程总览”，并更新 S1/S3/S6/S7/S9 的步骤描述。
- `contracts/canonical/templates/planning/design.template.json`：扩充上述字段定义与示例。
- `contracts/canonical/schemas/planning/design.schema.json`：同步结构化字段、required 字段与风险模型。
- `contracts/standard-chain.yaml`：同步 design artifact 的 `key_fields`。
- `shared/runtime/standard-chain-catalog.json`：当 `schema_version`、`chain_registry_digest` 或 schema/template 路径发生变化时同步 design entry。
- `shared/skills/design/references/templates/design-template.md` 与 `template-notes.md`：同步新的 canonical 字段、投影视图来源和 `scope_item_id`/UNIT 覆盖约定。
- `shared/skills/design/references/risk-assessment.md`：从旧的 `quality_attributes.risk_assessment` 收口到顶层风险模型。
- `shared/skills/design/references/design-reviewer-prompt.md`、`design-product-reviewer-prompt.md`、`design-test-reviewer-prompt.md`：同步 DR-7、DP-4、DT-5。
- `shared/skills/design/references/quality-attributes.md`：补充轻量化质量属性结构指引。
- `shared/skills/design/scripts/completion_check.sh`：同步 design-specific semantic checks。
- `tools/community/validate_canonical_schema.py`：通过 schema registry 自动感知新增字段，不单独新增私有分支逻辑。
- `tools/community/validate_canonical_rules.py`：凡是 schema 无法表达的 handoff / traceability / mixed-mode 规则，都落在这里或新增专用 rule validator。
- `tools/community/validate_standard_chain_phase.py`：继续只做编排器，但其 required field / golden fixture 契约需要同步。
- `tests/test-standard-chain-foundation-registry.sh`、`tests/test-standard-chain-closure-contract.sh`、相关 golden `design.json` fixtures：同步新的 authoritative/key fields 与 required schema fields。

完成校验同步升级到字段级检查，至少覆盖以下事实：

- `quality_attributes` 必须包含优先级排序和关键场景。
- `modules` 中每个模块都要有职责陈述和数据所有权。
- `data_architecture` 必须存在；如果本项目没有新的数据存储或数据流变更，也要显式记录“无新增变更”。
- `cross_cutting_concerns` 至少检查认证授权、错误处理、日志可观测、配置管理四项。
- `verification_mapping` 必须证明每条 Manager `Verification Plan` 至少被一条技术验证覆盖。
- `product_handoff` 必须能证明上游已确认、无未关闭 FAIL、WARN 有承接目标。
- `unit_coverage` 与 `impact_scope` 必须保留 `unit_id / ac_ref / scope_item_id` 这组最小追踪锚点。
- `risks` 与 `risk_response` 必须使用统一的顶层风险模型。
- `risk_response` 必须对已承接的 Director 风险给出架构层回应。

不新增独立的“数据架构”或“横切关注点” reference 文件。这两类要求直接内联到 S6，避免 reference 数量继续膨胀。

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| A. 核心问题框架 + 消费契约 + 能力补齐 | 与 product 层形成统一治理语言；直接补上数据架构、横切关注点、质量属性缺口；对 AI 更明确 | 需要扩模板、评审 prompt、完成校验，改动面比纯适配大 | 选定 |
| B. 仅做 product → design 管道适配 | 变更最小，短期风险低 | 核心问题仍隐式，能力缺口继续依赖 AI 自行判断，design 会成为链路瓶颈 | 不选 |

## Key Decisions

- D1: 保持 `design` 在标准链路中的阶段定位不变，只重塑 HOW 层表达。Reason: 问题在能力定义和契约清晰度，不在阶段拆分本身。
- D2: 用显式 Q1-Q9 核心问题替代“只靠流程记忆完成设计”。Reason: 让完成条件可检查、可对齐、可被下游消费。
- D3: 采用“直接消费 / 参考消费 / 不消费”的上游契约。Reason: 既承接 product 层约束，又避免把过程噪音注入运行时真源。
- D4: 不新增步骤，只增强 S1/S3/S6/S7 并调整 S9 评审项。Reason: 保持现有节奏和技能骨架，降低迁移成本。
- D5: 把数据架构、横切关注点、质量属性结构化为 canonical 字段。Reason: 这些内容是大需求 HOW 层的高价值信息，不能继续藏在自然语言里。
- D6: 完成校验必须同步升级到字段级覆盖。Reason: 如果新增字段不进 completion gate，设计扩容会停留在文档层，无法形成真实门禁。

## Goals & Success Criteria

| Goal | Success Criteria | Verification |
|------|------------------|--------------|
| 让 `design` 的完成条件明确可检 | 新增字段同时进入 template、schema、completion gate 与契约测试 | `bash tests/test-standard-chain-foundation-registry.sh`、`bash tests/test-standard-chain-closure-contract.sh` |
| 让 product → design 的 handoff 可稳定执行 | handoff gate、traceability contract、冲突裁决路径和 cutover 条件被 gate 识别 | 正例：`python3 tools/community/validate_standard_chain_phase.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1`；负例：移除 `product_handoff` 或上游 traceability 字段后必须失败 |
| 补齐当前 HOW 层的真实缺口 | Q2/Q5/Q6、S1/S3/S6/S7/S9、完整 output contract delta 和 completion gate 的变更都能落到 runtime contract | `jq`/`python` 检查 `design.template.json.authoritative_fields`、`design.schema.json.required`、`completion_check.sh` 断言已同步 |
| 让 rollout 可证明而不是停在 reviewer-only | must-sync 文件集、legacy/upgraded handoff 切换条件、WARN 退出标准和 deferred consumer 边界都有正负例验证 | 正例 phase 通过 + 至少 2 个负例分别删除 `data_architecture`、`verification_mapping` 或 mixed-mode handoff 字段后失败 |

## Change Scope

| File or Area | Change Type | Size |
|--------------|-------------|------|
| `shared/skills/design/SKILL.md` | modify | large |
| `contracts/canonical/templates/planning/design.template.json` | modify | medium |
| `contracts/canonical/schemas/planning/design.schema.json` | modify | medium |
| `contracts/standard-chain.yaml` | modify | small |
| `shared/runtime/standard-chain-catalog.json` | modify | small |
| `shared/skills/design/references/design-reviewer-prompt.md` | modify | small |
| `shared/skills/design/references/design-product-reviewer-prompt.md` | modify | small |
| `shared/skills/design/references/design-test-reviewer-prompt.md` | modify | small |
| `shared/skills/design/references/quality-attributes.md` | modify | small |
| `shared/skills/design/references/templates/design-template.md` | modify | medium |
| `shared/skills/design/references/templates/template-notes.md` | modify | medium |
| `shared/skills/design/references/risk-assessment.md` | modify | medium |
| `shared/skills/design/scripts/completion_check.sh` | modify | medium |
| `tools/community/validate_canonical_rules.py` 或新增专用 rule validator | modify | medium |
| `tools/community/validate_standard_chain_phase.py` | modify | medium |
| `tests/test-standard-chain-foundation-registry.sh`、`tests/test-standard-chain-closure-contract.sh` 与相关 golden `design.json` fixtures | modify | medium |
| `tests/` 中其他与 design skill、validator、标准链路结构相关的契约测试 | modify | medium |

## Invariants

- 10 步 wizard-style 共创流程保持不变。
- 8 条 HARD-GATE 保持不变。
- 3 个子 Agent 及其职责边界保持不变。
- `design.json` 继续是 phase 级单一 canonical 真源。
- `design → test-design` 的流程导航保持不变。
- 不为 `data_architecture`、`cross_cutting_concerns` 再新增独立 reference 文件。
- 简单需求仍走轻量链路，不通过 `design`。

## Downstream Impact

| Consumer | Impact | Propagation Needed |
|----------|--------|--------------------|
| `test-design` | 本轮先保证 compatibility contract 不断：`scope_item_id`、UNIT 覆盖、接口/质量属性继续可读；显式消费 `data_architecture`、`cross_cutting_concerns`、`verification_mapping` 延后到独立 follow-up | yes，需在 spec 中写清 deferred consumer 边界和 WARN 退出条件 |
| `tech-lead` / `dev` | 将收到更清晰的模块边界、数据所有权、横切模式和验证映射约束 | yes，通过 `design.json` 的 authoritative 字段扩展传播 |
| `completion_check.sh` | 需要把新增字段纳入 design 完成门禁 | yes，否则新增契约无法形成真实约束 |
| `validate_standard_chain_phase.py`、`contracts/standard-chain.yaml`、registry tests、golden fixtures | 需要识别新的 canonical 结构、key fields 与 fixture 基线 | yes，否则 template/schema/gate 虽更新，链路合同仍漂移 |
| 已上线但尚未升级的 product 工件 | 在过渡期可能缺少稳定 traceability 键与增强 handoff 字段 | yes，legacy/upgraded 双模式必须有明确切换条件 |

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| S6 同时承载 Q3/Q4/Q5/Q6，交互负担变重 | 用户容易疲劳，设计会话过长 | 保持一个步骤但强制分段确认；已有横切模式允许快速标记“沿用已有” |
| product 层增强尚未全部实施 | `design` 会读取到缺失字段 | S1 过渡期只发 WARN，不阻断；计划里把 upstream 落地顺序纳入依赖管理 |
| output contract 扩展后 schema / validator / completion gate / standard-chain contract 漂移 | 文档、template、schema、validator、registry tests 或 golden fixtures 不一致，链路出现假通过或误阻断 | 把 template、schema、`contracts/standard-chain.yaml`、`completion_check.sh`、`validate_standard_chain_phase.py`、registry tests、golden fixtures 视为同一批变更 |
| handoff 兼容模式长期停留在 WARN | rollout 永远无法进入 upgraded handoff，review 结论失真 | 在 spec 中定义 cutover owner、切换条件和 WARN 退出标准，并把它写进 success criteria |
| 风险 contract 继续分散在 `risks[]`、`risk_response[]`、`quality_attributes.risk_assessment` | S7/S9、projection 和 gate 无法对同一风险结构做一致验证 | 统一为顶层 `risks[] + risk_response[]`，并同步 reference/template/schema/gate |
| 质量属性要求写得过重 | 纯前端或低复杂度需求会多出无效负担 | 采用轻量结构，只要求优先级、关键场景、权衡点；简单需求仍不进入 `design` |
| `test-design` 暂未显式更新 SKILL | 新字段短期内可能只被 reviewer 或人工消费 | 本轮 success criteria 只承诺 design-side gate 与 compatibility contract 生效；`test-design` 显式消费作为后续治理任务单独推进 |
