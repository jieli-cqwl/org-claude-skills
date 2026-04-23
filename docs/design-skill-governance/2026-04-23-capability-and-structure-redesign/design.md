# design skill 能力与结构治理

## Why

标准链路中的 `design` skill 负责把已冻结的产品需求转成架构约束，但当前版本仍把关键架构问题分散在流程步骤里，没有显式回答清单，也没有把 product 层新引入的示例驱动 AC、`Integration Context`、`Verification Plan` 变成稳定的输入契约。结果是 AI 在大需求场景下容易遗漏数据架构、横切关注点和质量属性权衡，`design.json` 对下游 `test-design`、`tech-lead`、`dev` 的约束也不够清晰。

这次治理的目标不是重做标准链路，而是在保留现有 `design` skill 形态的前提下，把它补成一个对 AI 更明确、对上下游更一致、对验证更友好的 HOW 层设计节点。

## Scope

- In scope: 重定义 `design` skill 的核心问题框架、Manager → Design 输入消费契约、S1/S3/S6/S7 的增量流程调整、`design.json` 输出契约扩展、评审 prompt 与完成校验同步。
- Out of scope: 改动标准链路阶段顺序、重做 10 步 wizard 流程、改变 8 条 HARD-GATE、修改 `test-design`/`tech-lead`/`dev` 的职责定义、为简单需求引入 `design` 阶段。

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

| 输入类别 | 来源字段 | 设计阶段处理方式 |
|---|---|---|
| 直接消费 | 示例驱动 AC | 用来校验接口输入输出、错误码与边界条件是否覆盖业务验收。 |
| 直接消费 | `Integration Context` | 转译成代码扫描目标、兼容性约束和模块依赖图输入。 |
| 直接消费 | `Verification Plan` | 为每条业务验证补齐至少一条技术验证覆盖。 |
| 直接消费 | 范围、`Non-goals`、业务语义 | 约束设计边界，避免过度设计和术语漂移。 |
| 参考消费 | `Appetite`、可行性约束 | 约束方案复杂度和可选技术边界。 |
| 参考消费 | 风险/未知项、范围决策理由 | 驱动架构风险回应，帮助理解产品层的边界 WHY。 |
| 不消费 | 共创过程记录、评审流水账 | 不进入运行时裁决。 |

对 `待设计决策` 的消费方式也做了收口：`design` 必须承接决策主题和约束条件；Manager 给出的候选选项只作为业务视角参考，不绑定架构方案空间。

`Appetite` 与架构现实冲突时不得静默降级。`design` 必须把冲突显式写出来，例如“当前 Appetite 为 2 周，但满足选定质量属性的最小架构需要 6 周”，然后要求用户裁决是调大投入还是降低目标。

在过渡期内，S1 对新字段缺失发 WARN 不阻断；等 product 层增强实施完成后，再把这些字段升级为必检项。

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
| `risk_response` | 增强 | 记录 `director_risk_ref` 与 `architecture_response`（能消解/能缓解/无法缓解）。 |

与之配套的文件边界如下：

- `shared/skills/design/SKILL.md`：新增“核心问题总览”和“流程总览”，并更新 S1/S3/S6/S7/S9 的步骤描述。
- `contracts/canonical/templates/planning/design.template.json`：扩充上述字段定义与示例。
- `shared/skills/design/references/design-reviewer-prompt.md`、`design-product-reviewer-prompt.md`、`design-test-reviewer-prompt.md`：同步 DR-7、DP-4、DT-5。
- `shared/skills/design/references/quality-attributes.md`：补充轻量化质量属性结构指引。
- `shared/skills/design/scripts/completion_check.sh` 与 `tools/community/validate_standard_chain_phase.py`：同步识别新增字段，避免输出契约与完成校验脱节。

完成校验同步升级到字段级检查，至少覆盖以下事实：

- `quality_attributes` 必须包含优先级排序和关键场景。
- `modules` 中每个模块都要有职责陈述和数据所有权。
- `data_architecture` 必须存在；如果本项目没有新的数据存储或数据流变更，也要显式记录“无新增变更”。
- `cross_cutting_concerns` 至少检查认证授权、错误处理、日志可观测、配置管理四项。
- `verification_mapping` 必须证明每条 Manager `Verification Plan` 至少被一条技术验证覆盖。
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
| 让 `design` 的完成条件明确可检 | 设计文档明确给出 Q1-Q9、每题的 canonical 落点和主要文档化步骤 | 审阅 `design.md` 中“Design 必须回答的 9 个核心问题”表 |
| 让 product → design 的 handoff 可稳定执行 | 文档明确区分直接消费、参考消费、不消费，并定义 `Appetite` 冲突处理路径 | 审阅 `design.md` 中“Manager → Design 消费契约”节 |
| 补齐当前 HOW 层的真实缺口 | 文档把 Q2/Q5/Q6、S1/S3/S6/S7/S9、输出契约和 completion gate 的变更说清楚 | 审阅 `design.md` 中“流程步骤增量调整”和“输出契约与完成校验同步”节 |
| 控制治理改动的外溢范围 | 文档明确列出 change scope、invariants、downstream impact 和 risks，避免后续计划扩散 | 审阅对应四节内容，并用 completeness checklist 自审 |

## Change Scope

| File or Area | Change Type | Size |
|--------------|-------------|------|
| `shared/skills/design/SKILL.md` | modify | large |
| `contracts/canonical/templates/planning/design.template.json` | modify | medium |
| `shared/skills/design/references/design-reviewer-prompt.md` | modify | small |
| `shared/skills/design/references/design-product-reviewer-prompt.md` | modify | small |
| `shared/skills/design/references/design-test-reviewer-prompt.md` | modify | small |
| `shared/skills/design/references/quality-attributes.md` | modify | small |
| `shared/skills/design/scripts/completion_check.sh` | modify | medium |
| `tools/community/validate_standard_chain_phase.py` | modify | medium |
| `tests/` 中与 design skill、validator、标准链路结构相关的契约测试 | modify | medium |

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
| `test-design` | 可读取 `data_architecture`、`cross_cutting_concerns`、`verification_mapping` 设计更完整的测试边界 | yes，至少需要评审/测试视角理解新字段；显式消费是否改 SKILL 可后续再议 |
| `tech-lead` / `dev` | 将收到更清晰的模块边界、数据所有权、横切模式和验证映射约束 | yes，通过 `design.json` 字段扩展自然传播 |
| `completion_check.sh` | 需要把新增字段纳入 design 完成门禁 | yes，否则新增契约无法形成真实约束 |
| `validate_standard_chain_phase.py` | 需要识别新的 canonical 结构与校验要求 | yes，否则 template 和 validator 会漂移 |
| 已上线但尚未升级的 product 工件 | 在过渡期可能缺少 `Integration Context`、`Verification Plan`、示例驱动 AC | yes，S1 先 WARN 不阻断，待 product 层落地后再升级为硬检查 |

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| S6 同时承载 Q3/Q4/Q5/Q6，交互负担变重 | 用户容易疲劳，设计会话过长 | 保持一个步骤但强制分段确认；已有横切模式允许快速标记“沿用已有” |
| product 层增强尚未全部实施 | `design` 会读取到缺失字段 | S1 过渡期只发 WARN，不阻断；计划里把 upstream 落地顺序纳入依赖管理 |
| output contract 扩展后 schema / validator / completion gate 漂移 | 文档、模板、校验脚本不一致，链路出现假通过或误阻断 | 把 template、`completion_check.sh`、`validate_standard_chain_phase.py`、相关 tests 视为同一批变更 |
| 质量属性要求写得过重 | 纯前端或低复杂度需求会多出无效负担 | 采用轻量结构，只要求优先级、关键场景、权衡点；简单需求仍不进入 `design` |
| `test-design` 暂未显式更新 SKILL | 新字段短期内可能只被 reviewer 间接消费 | 先通过 DT-5 保证可测试性覆盖，后续是否扩 `test-design` 作为独立治理任务处理 |
