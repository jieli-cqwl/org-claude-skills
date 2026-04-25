# design skill 能力与运行时质量治理

## Why

标准链路中的 `design` skill 值得治理，不是因为当前 `design.json` 字段不够多，而是因为大需求从 WHAT 进入 DO 之前，需要一个稳定的 HOW 层来收口高成本架构决策。

这类决策包括模块边界、接口契约、数据所有权、质量属性取舍、迁移路径、验证方式和回滚策略。它们一旦留给 `test-design`、`tech-lead` 或 `dev` 自行推断，就会变成执行期猜测，导致计划漂移、测试缺口和返工。

同时，`design` skill 不能把所有确定性约束都塞给 LLM。LLM 擅长共创、提问、取舍和冲突识别；schema、字段完整性、traceability、handoff 状态、fixture 正负例和完成门禁应由工程化机制证明。本次治理的核心目标是把这两类职责拆清楚。

## First Principles

本次治理采用三分法：

| 层 | 职责 | 不应承担 |
| --- | --- | --- |
| LLM 判断 | 架构共创、方案探索、边界识别、冲突上报、用户确认 | 机械字段校验、schema 一致性、fixture 正负例验证 |
| Canonical artifact | 承载已冻结的设计事实、追踪锚点和下游约束 | 记录评审流水账、替代用户确认、承载未收敛草稿 |
| 工程化 gate | 验证形状、状态、追踪、handoff 与完成条件 | 替代架构判断、替代领域约束裁决 |

这意味着本轮不是“把 `design` skill 写短”，也不是“把架构字段写全”，而是让 `design` skill 在 LLM 判断、reference 按需加载、canonical artifact、工程化验证和下游 rollout 之间形成清晰职责分工。

## Scope

In scope:

- 重写 `design` skill 治理设计，明确需求价值、核心问题、reference 合同、工程化边界和 staged rollout。
- 将 `design` 必须回答的问题从隐式流程步骤升级为 Q1-Q9 核心问题框架。
- 定义方法论型 reference 的契约式挂载方式，避免裸路径引用制造上下文噪音。
- 定义 `design.json` 新字段的 consumer-first 准入规则。
- 将全局 `Skill质量标准` 的行数口径纳入本次治理范围：官方软上限按 500 行 / 5000 tokens 处理，250 行只作为职责和噪音审视信号。
- 定义 `test-design` 与 `tech-lead` 的 Downstream Rollout Contract，避免下游显式消费被遗忘。

Out of scope:

- 不改变标准链路阶段顺序。
- 不把 Markdown 投影视图升级为 runtime 真源。
- 不为没有明确消费者的字段扩展 canonical contract。
- P0 不重构 `test-design` / `tech-lead` 主流程；若发现兼容锚点无法维持或下游会误读新字段，则允许提前升级下游治理。

## Principles

### 1. 先证明需求价值，再扩字段

字段扩展必须服务 HOW 层高成本决策。新增字段要回答：哪个下游消费者需要它、消费后行为如何变化、缺失时由谁阻断、如何验证。

### 2. LLM 只做适合 LLM 的事

`design` skill 应引导 LLM 做判断和共创，不把 schema、traceability 和状态机完整性写成提示词自查。能脚本化的验证必须进入 schema、semantic validator、completion gate 或 contract tests。

### 3. 方法论型 reference 契约化挂载

方法论型 reference 不能只写“读取 `references/x.md`”。新增或修改这类 reference 时，必须能表达以下合同：

| 字段 | 含义 |
| --- | --- |
| Trigger | 什么场景触发读取 |
| Read | 读取哪个文件或 resource map |
| Expect | 从中获得什么判断材料 |
| Consume | 结果写入哪个步骤或 canonical 字段 |
| Evidence | 如何证明被正确消费 |
| Sync | reference 变化时要同步哪些入口、template、schema、test 或 gate |

固定 artifact、template、schema、script 路径可以直接引用。契约化要求只针对方法论、规则细则、决策依据类 reference。

### 4. 行数是信号，不是目标

Claude Skill authoring best practices 建议 `SKILL.md` body 保持在 500 行以内，并通过 progressive disclosure 把详细材料拆到独立文件。Agent Skills open specification 同时给出 500 行以内和 5000 tokens 以内的主文件目标。OpenAI Codex skills 文档强调 metadata 先加载、skill 触发后再加载正文，并支持 `references/`、`scripts/`、`assets/` 等渐进资源。

本地标准应修正为：

- 接近或超过 500 行 / 5000 tokens 时，必须拆分或给出豁免说明。
- 超过 250 行只触发职责和噪音审视，不自动判失败。
- 审视依据是职责数量、读取频率、低频内容比例、reference 合同质量和工程化替代空间。
- 不为了压行数删除必要 HARD-GATE、前置条件或完成边界。

### 5. 下游治理可以延后，但必须可追踪

P0 可以不重构 `test-design` / `tech-lead` 主流程，但必须冻结 Downstream Rollout Contract，写清后续消费字段、entry criteria、exit criteria、owner、验证方式和提前升级条件。

## Core Questions

`design` 必须回答 Q1-Q9。每个问题都拆成 LLM 判断、artifact 承载和工程化验证。

| 核心问题 | LLM 负责 | Artifact 承载 | 工程化验证 |
| --- | --- | --- | --- |
| Q1 技术现状与约束 | 扫描现状，识别真实约束 | `input_analysis`, `runtime_facts` | 必填、来源、采证命令 |
| Q2 质量属性优先级 | 提出排序草案，请用户裁决冲突 | `quality_attributes` | 有优先级、关键场景、权衡点 |
| Q3 模块边界与职责 | 判断模块边界、职责、数据所有权 | `modules`, `unit_coverage` | UNIT/AC 有设计承接 |
| Q4 接口契约 | 定义输入、输出、错误码、边界 | `interfaces`, `interface_boundary` | schema 结构与错误模式完整 |
| Q5 数据架构 | 判断数据建模、存储、流转、一致性 | `data_architecture` | 存在或显式声明无数据变更 |
| Q6 横切关注点 | 判断沿用已有还是设计新模式 | `cross_cutting_concerns` | 覆盖认证授权、错误处理、日志可观测、配置管理 |
| Q7 架构决策与替代方案 | 给 2+ 方案并收口用户确认 | `key_decisions`, `option_analysis` | 方案数、取舍、verdict 必填 |
| Q8 迁移/验证/回滚 | 设计可演进路径和验证映射 | `migration_plan`, `verification_plan`, `verification_mapping`, `rollback_plan` | 每条 Manager VP 至少一条技术验证覆盖 |
| Q9 风险与回应 | 承接 Director 风险并补技术风险 | `risks`, `risk_response` | 风险有回应、验证引用或升级路径 |

Q1-Q9 的目标不是让 `SKILL.md` 承载更多细节，而是让完成条件从“走完流程”变成“核心架构问题被回答并落到可消费合同”。

## Output Contract

新增或增强 canonical 字段必须通过 consumer-first gate。

| 字段 | 消费理由 |
| --- | --- |
| `modules` | 支撑 `tech-lead` 拆任务，并给 `test-design` 建覆盖视图 |
| `data_architecture` | 支撑一致性测试、迁移风险、回滚策略和数据影响判断 |
| `cross_cutting_concerns` | 避免认证授权、错误处理、日志可观测和配置管理在各模块重复决策 |
| `verification_mapping` | 连接 Manager 业务验证与设计层技术验证 |
| `unit_coverage` | 提供 UNIT/AC 到设计承接位置的追踪锚点 |
| `impact_scope` | 提供 scope_item_id 到计划、测试和交付证据的追踪锚点 |
| `planning_constraints` | 向 `tech-lead` 传递前置验证、不可并行项和探索边界 |
| `product_handoff` | 证明上游已确认、无未关闭 FAIL、WARN 有承接目标 |
| `risks` / `risk_response` | 统一风险模型，替代分散在 `quality_attributes.risk_assessment` 的风险写法 |

schema 证明字段形状，semantic validator 证明状态和追踪，LLM 证明设计判断过程。三者不能互相替代。

## Rollout Contract

P0/P1/P2 是同一治理的可验证 rollout，不是可遗忘 backlog。

| Phase | 目标 | Owner | Entry Criteria | Exit Criteria |
| --- | --- | --- | --- | --- |
| P0 | 冻结新版设计与全局规范口径 | design governance owner | 本设计获用户确认 | 新版 `design.md` 写入；`Skill质量标准.md` 行数口径已更新并有 fresh command 证明；Downstream Rollout Contract 冻结 |
| P1 | 让 canonical contract 和工程化 gate 闭环 | design contract owner | P0 spec 通过审阅 | template/schema/completion gate/validator/fixtures/contract tests 能证明新增字段与 handoff/traceability |
| P2 | 让下游显式消费新设计信息 | downstream skill owner | P1 字段和 gate 稳定 | `test-design` 与 `tech-lead` 对新增字段产生明确行为变化，并有正负例验证 |

### Downstream Rollout Contract

`test-design` 后续消费：

| 字段 | 行为变化 |
| --- | --- |
| `data_architecture` | 触发数据一致性、迁移、回滚测试义务，或输出 DESIGN-GAP |
| `cross_cutting_concerns` | 触发 auth/error/log/config 相关测试义务，或输出 DESIGN-GAP |
| `verification_mapping` | 校验 Manager VP 到测试用例的覆盖链 |

`tech-lead` 后续消费：

| 字段 | 行为变化 |
| --- | --- |
| `unit_coverage` | 建立 Task 与 UNIT/AC 的覆盖链 |
| `impact_scope` | 建立 scope_item_id 到 Task 的影响范围链 |
| `planning_constraints` | 形成前置验证、不可并行项、探索任务边界 |

提前升级条件：

- 新字段进入 schema/gate 后，下游仍反复报 `DESIGN-GAP`。
- `test-design` 无法判断专项测试触发源。
- `tech-lead` 无法建立 `design_ref / scope_item_ref / test_ref` 追踪链。
- 兼容锚点无法维持，或下游会误读新字段。
- 用户要求当前批次端到端闭环，不接受 staged rollout。

## Change Scope

P0 变更范围：

| Area | Change |
| --- | --- |
| `docs/design-skill-governance/2026-04-23-capability-and-structure-redesign/design.md` | 冻结本次治理设计真源 |
| `shared/reference/Skill质量标准.md` | 修正全局行数口径：500 行 / 5000 tokens 为软上限，250 行为审视信号 |
| `shared/skills/design/SKILL.md` | 后续实现中加入 Q1-Q9 总览、reference 契约入口和噪音控制原则 |
| `shared/skills/design/references/*` | 后续实现中补齐方法论型 reference 的 Trigger/Read/Expect/Consume/Evidence/Sync |

P1 变更范围：

| Area | Change |
| --- | --- |
| `contracts/canonical/templates/planning/design.template.json` | 增强 `design.json` 字段模板 |
| `contracts/canonical/schemas/planning/design.schema.json` | 增强结构化字段和 required 规则 |
| `shared/skills/design/scripts/completion_check.sh` | 增强 design-specific semantic checks |
| `tools/community/validate_canonical_rules.py` / `tools/community/validate_standard_chain_phase.py` | 优先扩展既有 semantic validator 和 phase 编排验证 |
| `contracts/standard-chain.yaml`、catalog、fixtures、contract tests | 同步 design artifact key fields、正例与负例验证 |

P2 变更范围：

| Area | Change |
| --- | --- |
| `shared/skills/test-design/SKILL.md` 与相关 reviewer / gate | 显式消费 `data_architecture`、`cross_cutting_concerns`、`verification_mapping` |
| `shared/skills/tech-lead/SKILL.md` 与 plan/task 规则 | 显式消费 `unit_coverage`、`impact_scope`、`planning_constraints` |
| 下游 fixtures 与 tests | 证明新字段带来测试义务、DESIGN-GAP、Task 追踪链或探索边界的行为变化 |

## Invariants

- 标准链路阶段顺序保持不变。
- `design.json` 继续是 phase 级 canonical 真源。
- Markdown / HTML 投影视图不得反向成为 runtime 真源。
- `design → test-design → tech-lead` 的阶段顺序保持不变。
- `test-design` / `tech-lead` 的现有消费锚点在 P0/P1 期间保持兼容，除非触发提前升级条件。
- 不为没有明确消费者和验证方式的字段扩展 canonical contract。
- 不为了压缩行数删除必要 HARD-GATE、前置条件或完成边界。

## Alternatives Considered

| Option | Pros | Cons | Verdict |
| --- | --- | --- | --- |
| A. 核心问题瘦身 + reference 契约 + 工程化门禁加厚 | 保留架构价值，降低 LLM 噪音，工程化可验证 | 需要分阶段治理，P1/P2 必须被追踪 | 选定 |
| B. 原交接方案全量扩展 | 一次性覆盖字段、流程、评审和 gate | 范围过大，`SKILL.md` 变重，迁移和下游风险高 | 不选 |
| C. 只做工程化 gate | 改动集中，短期可控 | 无法解决 LLM 架构判断遗漏和 reference 噪音 | 不选 |

## Key Decisions

- D1: 继续治理 `design` skill。Reason: 大需求需要 HOW 层收口，避免下游猜测。
- D2: 治理目标同时包含架构决策质量和 Skill 运行时质量。Reason: 只补字段会制造噪音。
- D3: 行数口径采用官方软上限 500 行 / 5000 tokens，250 行只作为审视信号。Reason: 避免误把本地经验阈值当硬规则。
- D4: 保留 Q1-Q9，但按 LLM 判断、artifact、工程化验证拆分。Reason: 保留价值，同时避免 LLM 背机械校验。
- D5: 方法论型 reference 必须契约化挂载。Reason: 让 LLM 按需加载，减少上下文噪音。
- D6: P0 不重构下游主流程，但必须定义 Downstream Rollout Contract。Reason: 控制范围，同时避免遗忘。
- D7: P1 优先扩展现有 `validate_canonical_rules.py` / `validate_standard_chain_phase.py`；若职责不合适，再新增 design-specific validator。Reason: 避免不必要的新工具。

## Success Criteria

| Goal | Success Criteria | Verification |
| --- | --- | --- |
| 需求价值成立 | `design.md` 明确说明 `design` 解决 HOW 层高成本决策，不是字段扩容 | spec self-review 检查 Why/Scope |
| LLM 职责边界清晰 | 设计明确 LLM 判断、artifact 承载、工程化验证三分法 | 文档结构检查 |
| Reference 按需加载 | 方法论型 reference 有契约字段或 resource map 要求 | 后续计划必须含 reference contract 检查 |
| 行数标准修正 | `Skill质量标准` 口径改为 500 行 / 5000 tokens 官方软上限，250 行为审视信号 | `rg "500 行|5000 tokens|250 行" shared/reference/Skill质量标准.md` |
| Q1-Q9 可落地 | 每个核心问题都有 LLM 判断、artifact 落点、工程化验证 | `design.md` 表格检查；后续 schema/gate 测试 |
| 工程化闭环 | P1 区分 schema 与 semantic validator，并有正负例 fixture | P1 contract tests |
| 下游不被遗忘 | P0 输出 Downstream Rollout Contract，含 entry/exit/owner/提前升级条件 | spec self-review 与后续 writing-plans 追踪 |
| 无噪音扩张 | 新字段和 reference 都有 consumer-first 理由 | review 检查每个新增字段的 consumer 和 Evidence |
| 保持兼容 | P0/P1 不破坏 `test-design` / `tech-lead` 现有消费锚点 | golden fixture 与负例验证 |

成功标准描述可观察结果；具体执行顺序交给后续 implementation plan。

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| 被误解成“加字段” | canonical 变胖但下游不用 | 每个字段必须有 consumer-first 理由和 Evidence |
| 被误解成“压行数” | 删除必要门禁或流程 | 行数只作信号，职责清晰才是目标 |
| reference 契约过度格式化 | 为了合同制造新噪音 | 只对方法论型 reference 契约化；固定路径可直接引用 |
| P2 被遗忘 | 下游没有显式消费新字段 | P0 写入 Downstream Rollout Contract |
| 工程化验证和 LLM 判断混淆 | 靠 LLM 自查或脚本替代架构判断 | 贯彻 LLM / artifact / gate 三分法 |
| 全局行数标准更新影响其他 skill 审计 | 后续审计口径变化 | 写清 250 是审视信号，500 是官方软上限，不自动判失败 |

## Sources

- Anthropic Claude Skill authoring best practices: `https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices`
- Agent Skills open specification: `https://agentskills.io/specification`
- OpenAI Codex Agent Skills: `https://developers.openai.com/codex/skills`
