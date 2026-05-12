# AI Agent / Claude Skills / 架构设计助手可验证原则调研报告

> 调研模式：analysis  
> 呈现模式：audit  
> 落盘路径：`/Users/lijieli/org-claude-skills/shared/skills/skill-refiner/evals/refinements/design-architect-flow-refinement/evidence/agent-principles-research-report.md`  
> 生成日期：2026-05-11

## 当前判断

- 这次要回答的问题：官方/一手资料如何定义 AI agent、Claude Skills、软件架构设计助手在角色、输入、流程、输出、验证、人工确认上的职责边界；哪些原则可以转成 design skill 的可验证约束。
- 当前结论：现有 `/design` 的 S1-S12 owner flow 已具备基线门禁、事实采证、方案取舍、设计合成、自检、advisory review、最终冻结和可选投影的验证骨架；但本报告只作为路线辅助研究材料，不等于审计级终稿，也不是受管 standard-chain 需求工件。
- 一句话判断：design skill 的方向是对的，最大风险不是缺少架构理论，而是流程太长时 LLM 以“填字段”替代“拿证据做决策”。
- 最大风险：把 Anthropic agent loop、Skills progressive disclosure、ATAM/arc42/C4 等通用原则机械叠加，导致 design skill 更重、更难执行；应只吸收能映射到现有字段、reviewer prompt、schema、脚本或审查清单的原则。
- 后续动作边界：优化方向必须先从仓库失败信号和下游消费 gap 倒推，再用官方资料解释原则合理性；事实质量、确认摘要、review finding 可追溯性等只能先进入 reviewer WARN/checklist，dogfood 证明低误报后再考虑 validator。

## 审计范围

- 审计范围：本报告文本、报告内引用的当前项目路径、报告对官方/一手资料的原则转译、挑战回收记录和结论边界。
- 不审范围：不重跑外部 URL，不执行 validator，不重新裁决 `shared/skills/design/SKILL.md`、`design.schema.json`、reviewer prompt 或 `designer.md` 的实现设计。
- 上下文使用边界：`shared/skills/design/SKILL.md`、`design.schema.json`、`design-reviewer-prompt.md`、`designer.md` 只作为辅助上下文和当前事实来源；本报告仍是一次性研究材料，不按 active standard-chain 工件标准处理。
- 证据转译边界：每个关键建议必须能写成“证据 → 结论 → 失效条件 → 下一步验证”；不能只用官方原则直接推出门禁。

| 对象/论点 | 最强支持证据 | 最强反方挑战 | 当前判断 | 结论稳健性 |
| --- | --- | --- | --- | --- |
| AI agent 应按“采集上下文 → 行动 → 验证结果”循环运行 | Claude Code 官方说明 agentic loop 是 gather context、take action、verify results；Anthropic 也把 agent 描述为基于环境反馈使用工具的循环 | 架构设计不是代码修复，不能把“take action”误解成直接改系统；设计行动主要是形成/修正设计产物 | 成立，但需改写为“事实采证 → 决策合成 → 验证闭环” | 高 |
| 复杂 agent 工作必须有 checkpoint 和人工可介入点 | Claude Code 文档说明用户可随时 interrupt/steer；plan mode 明确支持先研究和计划再批准执行 | 过多确认会降低设计效率，使用户只机械确认 | 成立，但确认点必须绑定质量目标、关键 tradeoff、最终冻结，不做泛泛确认 | 高 |
| Skills 应用 progressive disclosure，主入口保持短、细节按需加载 | Anthropic Agent Skills overview 和 Agent Skills specification 均描述 metadata / SKILL.md / resources 分级加载 | design skill 本身是流程型 skill，过度拆分 reference 可能让关键约束被漏读 | 成立；主流程保留 hard gates，细节参考只在对应阶段加载 | 高 |
| 架构设计输出应结构化、可追溯、可被下游消费 | arc42 覆盖目标、约束、上下文、决策、质量、风险；C4 提供结构视图；ADR 记录单个决策及 rationale/tradeoff/consequence | 结构化字段可能诱导 LLM 填空，字段完整不等于设计正确 | 成立；必须用 evidence/ref/review/validator 约束字段质量 | 高 |
| 每个关键架构决策需要多方案、tradeoff、失效条件 | ADR 强调 rationale/tradeoffs/consequences；ATAM 强调 sensitivity/tradeoff points、risks/non-risks | 有些小决策只有一个合理实现，强制 2+ 方案可能造假 | 部分成立；只对关键决策强制 2+ 本质不同方案，小决策可明确降级为非关键 | 中高 |
| 架构验证应覆盖质量属性场景和风险 | SEI ATAM 以 quality attribute goals、stakeholder scenarios、utility tree、risks/tradeoff points 评估架构 | ATAM 是评估方法，不等于所有 design skill 都要完整执行 ATAM | 成立，但只能吸收“质量属性场景 + 风险/取舍可验证”最小核 | 高 |
| Reviewer 应 advisory，owner 保留最终裁决 | Claude Code agent teams 适合 research/review、challenge findings；当前 design reviewer prompt 明确 reviewer 不写入 design.json | 如果 owner 自身偏差强，advisory review 可能被忽略 | 成立；需要 finding id、证据、承接目标、digest 一致性门禁 | 高 |
| Hooks/validators 适合确定性门禁，prompt 适合推理流程 | Claude Code hooks 可在 PreToolUse/PostToolUse/PermissionRequest/UserPromptSubmit 等事件执行，能 block/deny；schema/validator 已在项目内使用 | hooks 只能验证形式和局部规则，无法替代架构判断；启发式文本检查若直接升 validator 易误杀或制造伪质量信号 | 成立；新增治理先进入 reviewer/checklist 试运行，只有稳定、低误报、可判定的规则再进入脚本/schema | 高 |

## 拆解对象概览

| 类别 | 一手/官方对象 | 对本研究的用途 | 不采用边界 |
| --- | --- | --- | --- |
| AI agent | Anthropic Building effective agents；Claude Code how Claude Code works | 定义 agent/workflow 差异、agentic loop、工具使用、验证与人工介入 | 不把 coding agent 的自动实现能力直接迁移为 design 自动签收 |
| Claude Skills | Claude Code Skills；Anthropic Agent Skills overview；Agent Skills specification | 定义 skill 的角色、输入触发、结构、progressive disclosure、资源/脚本/验证 | 不把 skill 写成百科；主入口不承载所有参考细节 |
| 协作与确认 | Claude Code subagents、agent teams、hooks、permission modes | 定义上下文隔离、并行 review、确定性门禁、plan/permission 人工确认 | 不为普通设计默认引入高成本团队，除非 review 或挑战确有价值 |
| 架构方法 | arc42、C4、C4 checklist、SEI ATAM、ADR | 定义架构输出结构、视图、质量属性、风险、决策记录和可审查项 | 不完整照搬 ATAM/arc42 模板，避免流程过重 |
| 规格驱动实践 | GitHub Spec Kit、Kiro specs | 定义 requirements/design/tasks 分层、clarify/checklist/plan/tasks/implement 链路 | Kiro approval gate 证据不足，只作为分层实践，不作为审批依据 |
| 当前项目上下文 | `/Users/lijieli/org-claude-skills/shared/skills/design/SKILL.md` 等 | 判断 design skill 已覆盖项和优化缺口 | 不脱离现有 standard-chain/schema/validator 重建流程 |

## 核心判断依据

### 1. AI agent：设计助手必须是可校正循环，不是一次性设计生成器

证据：
- Anthropic “Building effective agents” 将 workflows 定义为 LLM 和 tools 经预定义路径编排，将 agents 定义为 LLM 动态指导自身流程和工具使用；适用场景是开放问题，但存在更高成本和错误累积风险。
- 同一资料强调 agents 常见形态是基于环境反馈循环使用工具，并用 ground truth、最大迭代数等限制控制。
- Claude Code 官方文档把 agentic loop 写成三阶段：gather context、take action、verify results，并说明用户可随时 interrupt/steer。

可迁移原则：
- `/design` 的“行动”不是改业务代码，而是：采证、提出候选方案、冻结设计字段、运行 validator、按 review 修正。
- 每个关键阶段必须能回答：本阶段输入证据是什么、产物改变了什么、如何验证改变没有越界。

对当前 design skill 的判断：
- 已覆盖：S4 Current-State Evidence、S7 Option Tradeoff、S9 Owner Self-Check、S10 Advisory Review、S11 Finalize design.json 验证闭环。
- 风险：流程长时，模型可能跳过“上一轮结果如何影响下一轮决策”的显式说明，只机械填充 schema。

### 2. Claude Skills：design skill 应保持流程入口短，事实和模板按需加载

证据：
- Claude Code Skills 官方文档说明 skill 是包含 `SKILL.md` 的目录能力包，支持 supporting files、scripts、references、assets。
- Anthropic Agent Skills overview 明确 progressive disclosure：Level 1 metadata always loaded，Level 2 instructions triggered，Level 3 resources/code as needed。
- Agent Skills specification 要求 skill 至少包含 `SKILL.md`，frontmatter `name`/`description`，可选 `scripts/`、`references/`、`assets/`，并建议 `SKILL.md` under 500 lines、长内容拆到 referenced files。

可迁移原则：
- `/design` 主文件应只放 hard gates、角色边界、阶段顺序、完成校验和何时加载 reference。
- hard gates、脚本命令、字段写入边界、reviewer 只读边界和 validator 入口必须留在主流程或必读路径；reference 只能承载方法细节，不能承载完成条件。
- 具体方法论材料应放 reference，并由阶段触发加载，避免所有架构理论常驻上下文。

对当前 design skill 的判断：
- 已覆盖：当前 `/Users/lijieli/org-claude-skills/shared/skills/design/SKILL.md` 已把 quality attributes、decision templates、interface spec、risk assessment、projection 等放在 reference/projection 下按阶段读取。
- 风险：当前 `SKILL.md` 仍偏长，但流程性约束较多，不能简单删；优化应删除重复解释而不是删除 hard gates。

### 3. 架构设计助手：输出必须服务沟通、评估、实施，不是“漂亮文档”

证据：
- arc42 自称是 architecture communication and documentation template，覆盖 Introduction & Goals、Constraints、Context & Scope、Runtime View、Architecture Decisions、Quality Requirements、Risks and Technical Debt、Glossary 等。
- C4 定义 developer friendly 的 hierarchical abstractions：software systems、containers、components、code，并输出 system context、containers、components、code diagrams。
- C4 checklist 提供可验证图示检查：title、diagram type/scope、key/legend、element name/description、relationship label/direction、technology choices、notation consistency。
- ADR 社区资料将 ADR 定义为捕获单个 architecture decision 及其 rationale；AD 是 tied to functional/non-functional requirement 的 justified design choice，并包含 trade-offs and consequences。

可迁移原则：
- design skill 的 canonical 输出要同时覆盖：目标/约束、结构、接口、数据、质量、决策、风险、验证、回滚、交接。
- 人类可读投影只能展示 canonical 已冻结字段，不能新增事实或替代 JSON。

对当前 design skill 的判断：
- 已覆盖：`design.template.json` 和 `design.schema.json` 已包含 key_decisions、option_analysis、runtime_facts、interfaces、quality_attributes、modules、data_architecture、verification_mapping、risks、risk_response、migration_plan、rollback_plan、review_closure、final_confirmation。
- 已覆盖：`/Users/lijieli/org-claude-skills/shared/skills/design/projections/design-template.md` 明确投影视图只展示已冻结字段，manifest 回指 `design.json` 字段或 JSON Pointer。
- 风险：C4 的图示 checklist 没有完全映射到当前 design projection/ADR 产物；若未来生成图，应新增 diagram manifest/checklist，而不是塞进当前 `design.json`。

### 4. 架构评估：质量属性与风险必须可审查，不能只写“高可用/可维护”

证据：
- SEI ATAM 是 evaluating software architectures relative to quality attribute goals 的方法。
- ATAM 使用 stakeholder scenarios、utility tree，场景由 stakeholders elicited 并 voting；分析产生 sensitivity points、tradeoff points、risks、non-risks、risk themes。
- ATAM 把高优先级 scenarios 作为 test cases to confirm analysis。

可迁移原则：
- design skill 不必完整执行 ATAM，但必须保留最小核：stakeholder concerns、quality attribute scenarios、target metrics、tradeoff points、risk response、verification refs。
- 质量属性必须有场景和指标来源：输入基线、运行时事实、用户确认或明确工程假设。

对当前 design skill 的判断：
- 已覆盖：S2 stakeholders、S5 complexity model、S6 quality attributes、S7 option tradeoff、S8 risk/verification mapping。
- schema 已要求 `quality_attributes[*].key_scenarios / target_metrics / tradeoff_points / verification_refs` 非空。
- 风险：schema 能保证字段存在，不能保证 target metrics 不是伪指标；需要补“指标来源引用”或检查指标是否回指证据/用户确认。

### 5. 人工确认：确认点必须绑定不可自动判断的取舍

证据：
- Claude Code permission modes 说明 default/plan/acceptEdits/auto/dontAsk/bypassPermissions 是 oversight 与便利性的取舍。
- Plan mode 明确要求 Claude 先 research/propose changes，不改源文件；计划完成后用户可 approve/start in auto、approve/accept edits、manual review、keep planning with feedback。
- Claude Code how-it-works 说明用户是 loop 的一部分，可随时 steer。
- GitHub Spec Kit README 提醒 do not treat its first attempt as final，并提供 clarify/checklist/plan/tasks/implement 分层。

可迁移原则：
- design skill 的人工确认应落在：架构显著需求边界、质量属性优先级、关键 tradeoff、最终冻结确认。
- 用户确认摘要必须写入 canonical 字段，且能被 review/validator 引用。

对当前 design skill 的判断：
- 已覆盖：S2-S8 共创纪律、DES-HG-3、S11 final_confirmation。
- 风险：用户确认可能被写成“用户确认通过”这种不可审计文本；应检查确认摘要是否包含裁决内容、理由/领域事实、影响字段。

### 6. Reviewer/challenger：并行审查有价值，但不能替代 owner 决策

证据：
- Claude Code subagents 适合会污染主上下文的探索任务，独立上下文中工作并只返回 summary。
- Agent teams 官方文档称最适合 research and review、debugging with competing hypotheses，teammates 能共享 task list、直接沟通和 challenge findings；但实验性、高 token、适合并行独立工作。
- 当前 `/Users/lijieli/org-claude-skills/shared/skills/design/references/design-reviewer-prompt.md` 要求 reviewer 只输出审查报告，不写入或修改 `{phase_dir}/design.json`；finding 必须有 evidence 和承接目标。

可迁移原则：
- design owner 保留最终裁决；reviewer 只给 advisory findings。
- reviewer 输出必须包含稳定 issue id、digest、证据指针、承接位置；FAIL 修正后重审，WARN 进入 planning_constraints/risk_response/verification_mapping/product_handoff。

对当前 design skill 的判断：
- 已覆盖：S10 Advisory Review、DES-HG-5、designer agent 定义均明确 reviewer 不签收工件。
- 风险：如果 owner 可忽略 WARN 或重写 finding，review 变成仪式。应继续依赖 digest 与 resolved_failures/warn_followups 约束。

### 7. 确定性门禁：能脚本化的规则不要靠 prompt 记忆

证据：
- Claude Code hooks 可在 SessionStart/UserPromptSubmit/PreToolUse/PostToolUse/PermissionRequest 等生命周期执行；PreToolUse 可 allow/deny/ask/defer，且 deny 优先。
- Hooks 文档给出阻断破坏性 Bash、编辑后运行 lint、安全扫描、注入 additionalContext 等用法。
- 当前 design schema 已把 runtime_facts 必须包含 `evidence=` 和 `observed_at=`、option_analysis 至少 2 项、interfaces 必须含 input/output/error_codes、reviewers 必须含 architecture/product/test、final_confirmation.status 必须 confirmed 等规则门禁化。

可迁移原则：
- Prompt 负责推理和共创；schema/scripts/hooks 负责可判定门禁。
- 优化 design skill 时，先把语义质量要求放进 reviewer prompt/checklist 试运行；只有能稳定判定、误报可控且能映射到字段/引用的规则，再进入 schema/validator。

对当前 design skill 的判断：
- 已覆盖：`review_digest.py`、`check_design_reference_integrity.py`、`validate_standard_chain_phase.py`、`validate_co_creation_ledger.py` 已形成验证链。
- 风险：仍有语义质量不可脚本化，如“两个方案是否本质不同”“tradeoff 是否真实”；这部分只能用 reviewer prompt + 用户确认 + 证据引用降低风险。

## 可验证原则清单

| # | 原则 | 当前文件/字段/脚本证据 | 未覆盖缺口 | 验证方式 |
| --- | --- | --- | --- | --- |
| P1 | 基线通过后才设计 | `shared/skills/design/SKILL.md` S1 Baseline Gate；`preflight_check.sh`；输入只来自 brief/phase-prd/UNIT/确认约束 | 缺少新人入口对 blocked 回退格式的最小说明 | fixture 跑通 preflight PASS/BLOCKED；blocked 输出含 field、owner、next action、是否可继续 |
| P2 | 决策先有事实 | DES-HG-2；`design.json.input_analysis` / `runtime_facts`；S4 Current-State Evidence 要求 evidence/observed_at | schema 可查存在性，不能保证 evidence 质量 | reviewer WARN/checklist 先识别 unknown/空泛 evidence；dogfood 后再评估 validator |
| P3 | 架构显著需求先于方案 | S3 Architecture-Significant Requirements；范围变化回 `/product-manager` | quickstart 需要明确“何时不用 /design” | 新人 30 分钟 fixture 验收；误用 case 检查 |
| P4 | 关键决策必须有 2+ 本质不同方案 | DES-HG-3；S7 Option Tradeoff；`option_analysis` / `key_decisions` | “本质不同”不可完全脚本化 | reviewer 检查同义改写；FAIL/WARN 记录证据 |
| P5 | 质量属性必须有场景、指标、验证引用 | S6 Decision Discovery；`quality_attributes.key_scenarios / target_metrics / tradeoff_points / verification_refs` | 指标来源可能伪造或空泛 | reviewer WARN/checklist 要求来源回指输入、runtime_facts、用户确认或工程假设 |
| P6 | 接口边界必须可被测试和 tech-lead 消费 | DES-HG-4；S8 Design Synthesis；`interfaces.input_params / output_params / error_codes / boundary_behaviors` | boundary_behaviors、性能压测规模等下游消费质量尚未验证 | 从 `/test-design`、`/tech-lead` 实际消费 gap 倒推 reviewer-checkable 项 |
| P7 | 风险必须有响应和验证 | S8 `risk_response` / `verification_mapping`；S11 `check_design_reference_integrity.py` 与 phase validator | S1 不能提前要求完整 digest/reference integrity | S8 写作自检，S10/S11 再运行 digest/reference integrity/validator |
| P8 | 人工确认只确认不可自动判断的取舍 | S2-S8 共创纪律；DES-HG-3；S11 `final_confirmation.status=confirmed` | 确认摘要可能写成“已确认” | reviewer WARN/checklist 检查裁决内容、理由/领域事实、影响字段 |
| P9 | Reviewer 独立审查但不签收 | S10 Advisory Review；DES-HG-5；reviewer prompt 要求 advisory findings | review 噪声和轮次成本可能过高 | 记录 finding 数量、severity、证据、承接字段、digest、WARN 去向和噪声率 |
| P10 | 投影只从 canonical 派生 | S12 Optional Projection；projection manifest 回指 `design.json` JSON Pointer | C4 图示 checklist 只在生成图时需要 | 若未来生成图，再新增 diagram checklist，不默认进入 flow |
| P11 | Skill 主入口短，参考材料按需加载 | `SKILL.md` 阶段触发读取 references/projections/scripts | hard gates 过度拆分会漏读 | 精简重复解释，不移动准入、hard gates、validator 入口 |
| P12 | 确定性规则脚本化 | `review_digest.py`、`check_design_reference_integrity.py`、`validate_standard_chain_phase.py`、`validate_co_creation_ledger.py` | 启发式文本质量不适合直接脚本化 | 两阶段：reviewer WARN 试运行 → dogfood 证明低误报 → 再考虑 validator |

## 吸收建议

### 可以直接吸收

1. **事实质量检查（review prompt + eval fixture 先行；validator 只拦截明显占位）**
   - 来源：Anthropic agent loop、Claude Code verify results、当前 DES-HG-2。
   - 可验证命题：设计事实必须能回指输入基线、代码/配置/只读命令输出或用户确认；弱 evidence 会让下游无法复查决策依据。
   - 当前证据：`runtime_facts` 要求 `evidence` 和 `observed_at`；S4 只读采证；S7 决策只使用含 evidence/observed_at 的事实。
   - 失败样例：`evidence=unknown`、`observed_at=TBD`、只写“根据代码可知”但无路径/命令/用户确认。
   - 门禁形态：validator 只拦截 empty/unknown/TBD/缺字段/digest drift；“证据是否足够支撑决策”先由 reviewer advisory + eval fixture 判断。
   - 反指标：新增检查不得显著增加 S10 返工、WARN 噪声率或诱导模型写更像证据的套话。

2. **用户确认摘要质量检查（review prompt + eval fixture 先行；不直接硬门禁）**
   - 来源：Claude Code plan mode / human steering；ATAM stakeholder scenario/voting 只能支持“确认应绑定取舍和 stakeholder 关注点”，不能直接推出机器门禁。
   - 可验证命题：确认摘要必须说明确认了什么取舍、基于什么领域事实、影响哪些字段；空泛确认会让 owner 无法追溯裁决。
   - 当前证据：S2-S8 共创纪律、DES-HG-3、S11 `final_confirmation.status=confirmed`。
   - 失败样例：`user_confirmation="用户已确认"`、`final_confirmation.summary="通过"`，但没有裁决内容、理由或影响字段。
   - 门禁形态：reviewer prompt 先标 WARN/FAIL；validator 只拦截 empty/TBD/unknown 等确定性占位。
   - 反指标：确认检查不得鼓励长篇模板化确认；以 review 噪声率和 S10 首轮失败数评估。

3. **review finding 可追溯性保持硬门禁**
   - 来源：Agent teams review/challenge；当前 design-reviewer-prompt。
   - 改法：继续要求 finding id、digest、证据 JSON Pointer、承接目标；WARN 必须进入明确字段。
   - 成功标准：review_closure 中未承接 WARN 或 digest 不一致时 validator 失败。

4. **质量属性指标来源显式化（review prompt + eval fixture 先行）**
   - 来源：ATAM quality attribute goals/scenarios。
   - 可验证命题：target metric 必须来自输入基线、runtime_facts、用户确认或明确工程假设；伪指标会把质量属性变成装饰字段。
   - 当前证据：S6 Decision Discovery 约束目标指标来源；`quality_attributes.target_metrics / verification_refs` 已在 schema 中存在。
   - 失败样例：`target_metrics=["高性能"]`、`p95 < 200ms` 但无输入、事实、用户确认或工程假设来源。
   - 门禁形态：reviewer prompt 先标 WARN/FAIL；validator 只拦截 empty/TBD/unknown 和字段缺失，不判断指标合理性。
   - 反指标：指标来源检查不得诱导无依据的数字化；以误报率、review 轮次和下游测试可消费性评估。

### 改写后吸收

1. **ATAM**
   - 原始方法较重，不完整照搬。
   - 改写为：stakeholder concerns + quality scenarios + tradeoff/risk/verification refs 最小核。

2. **arc42**
   - 原始模板偏文档沟通。
   - 改写为：检查 design.json 是否覆盖目标/约束/上下文/结构/决策/质量/风险，而不是新增 arc42 文档。

3. **C4**
   - 当前 design.json 不以图为主。
   - 改写为：模块/接口/边界字段具备 C4 视图的可投影基础；只有生成图时才引入 C4 checklist。

4. **GitHub Spec Kit / Kiro specs**
   - 原始对象偏规格驱动开发全流程。
   - 改写为：保留 requirements → design → tasks 分层和 checklist 验证，不引入其完整命令结构。

### 不采纳

1. **默认完整 agent team 并行设计**
   - 反对理由：官方文档称 agent teams 实验性、高 token，适合独立并行研究/review；当前 design owner 决策流不应默认并行化。
   - 保留范围：仅 S10 三视角 advisory review 或重大不确定性挑战。

2. **把 hooks 当架构判断工具**
   - 反对理由：hooks 适合 deterministic automation，不能判断方案是否合适。
   - 保留范围：只用于阻断危险操作、验证格式、运行脚本、注入上下文。

3. **为每个设计都生成 ADR/C4 图/arc42 文档**
   - 反对理由：当前 canonical 是 `design.json`，投影只在需要时派生；默认多文档会增加同步债。
   - 保留范围：用户或交付流程要求时，从已验证 `design.json` 派生。

## 落地行动项

| 优先级 | 行动 | 目标文件/位置 | 验收标准 |
| --- | --- | --- | --- |
| P0 | 修复旧 eval / 文档漂移，并补 1 页 `/design` quickstart | eval fixtures、相关 active docs、quickstart 索引入口 | quickstart 不是 `SKILL.md` 摘要，也不能单独长成新流程入口；只能作为现有 `SKILL.md` / reference 的决策索引页，说明何时用/不用 `/design`、必须输入、blocked 回退、最小可交付字段、完成命令、review 噪声收敛，并写明 owner、更新责任、过期清理规则和退出标准；必须有负例证明不会诱导跳过 S1 preflight、S3-S10 checkpoint、S9 Owner Self-Check、S10 Advisory Review 或 S11 validators |
| P0 | 分阶段放置 canonical-ref / digest / WARN / reference integrity 规则 | `shared/skills/design/SKILL.md` S1/S8/S10/S11 | S1 只保留准入、失败 owner、最低引用红线；S8 做写作自检；S10/S11 处理修复、digest、reference integrity、validator；前移只能是自检提醒，不能替代 `review_digest.py`、`check_design_reference_integrity.py` 或 phase validator |
| P1 | 降低 `SKILL.md` 执行认知负担但不删 hard gates | `shared/skills/design/SKILL.md` | 只删重复解释；不得移走 hard gates、脚本命令、字段写入边界、reviewer 只读边界或 validator 入口 |
| P1 | 从 `/test-design`、`/tech-lead` 实际消费 gap 倒推 checklist | reviewer prompt / checklist | checklist 只能是 downstream 消费字段的最小验收表，不能长出第二套流程语义；不得新增 schema/template 未定义字段；`boundary_behaviors` 对齐 `interfaces` / `interface_boundary`；性能压测规模落 `verification_mapping.test_obligation` 或 `planning_constraints`，不要造 `quality_attributes` 新字段 |
| P1 | 控制 reviewer 收敛成本 | S10 reviewer prompt、review digest / closure 字段 | 不默认增加更多 reviewer/checklist；控制 finding 数量、证据、承接字段、严重级别、digest 和 WARN 去向；WARN 聚合只处理非阻塞问题，blocking 必须显式暴露并 fail-close；聚合不得合并掉稳定 finding id、reviewer、digest、target、承接字段；review 时间盒必须附 fail-close 条件 |
| P1 | 增加 adoption 验收指标 | eval / dogfood 记录 | 新人 30 分钟能跑通 fixture；quickstart 降低 S10 首轮失败数；review WARN 噪声率可量化；负例证明 quickstart/checklist 没有绕过真实脚本和 validator |
| P2 | 强化 `shared/agents/designer.md` 派发合同 | `/Users/lijieli/org-claude-skills/shared/agents/designer.md` | 只定义派发/角色边界、唤起条件、阻断模板，不复述 `SKILL.md` 步骤合同，也不能让 agent 绕过 skill SOP；仅在派发合同、active refs 和 required inputs 明确时承接；缺 brief/phase-prd/UNIT/确认态时 fail-close，输出 blocked field、owner、next action、是否可继续 |
| P2 | 列出 standard-chain 同步成本 | manifest / registry、closure contract、standard-chain key_fields、下游 test-design 字段 | 任一同步面漂移都可能导致恢复、closure 或下游消费失败；所有行为/字段/验证变更必须同步相关 contract、manifest、registry、key_fields 和下游字段检查 |

## 独立挑战记录

| 挑战点 | challenger 质疑原文摘要 | 处理决定 | 残余风险 |
| --- | --- | --- | --- |
| 必须修正：当前 `/design` 覆盖判断有事实漂移 | 报告多处用阶段编号/阶段名作为覆盖判断；若与当前 `shared/skills/design/SKILL.md` 不一致，会削弱可信度。本轮审计曾提出阶段数量疑点；复核 `shared/skills/design/SKILL.md` 后当前真源为 S1-S12 owner flow | 已按当前 S1-S12 owner flow 改写原则表：原则 → 当前文件/字段/脚本证据 → 未覆盖缺口 → 验证方式 | 后续若 `/design` 阶段再调整，报告需同步，否则会成为漂移源 |
| 必须修正：官方/一手资料不能直接推出本仓库门禁形态 | Progressive disclosure、agentic loop、permission/plan mode 只能支持短入口、可校正循环、人工确认，不能直接证明事实质量抽检/确认摘要检查应如何门禁化 | 已降级：官方资料只作为原则证据；门禁形态必须由本仓库字段、reviewer prompt、validator、失败信号证明 | 事实质量与确认摘要仍需 dogfood 样本证明低误报 |
| 必须修正：ATAM/arc42/C4/ADR 迁移偏宽 | 若没有证明最小核与 `design.json` 字段、reviewer prompt、validator 对应，仍是方法论贴标签 | 已改写为“可选审查透镜”：只吸收质量场景、风险/取舍、可审查视图，不新增默认产物或阶段 | ISO 42010、ADD v2.0 未纳入强证据，不能补强此结论 |
| 必须修正：启发式 validator 风险高 | 将 confirmation/evidence 启发式检查直接作为 validator 容易误杀或形成伪质量门禁 | 已调整为两阶段：reviewer WARN/checklist 试运行 → dogfood 证明低误报 → 再考虑 validator | 是否进入 validator 待验证，不能在本报告中直接承诺 |
| 必须修正：投影路径不得指向用户本地 skill | 审计质疑报告使用用户本地 skill 投影路径，会把环境资料误当项目真源 | 已复核并统一为仓库内 `/Users/lijieli/org-claude-skills/shared/skills/design/projections/design-template.md`；证据索引 E22 也指向仓库路径 | 若未来报告引用 runtime/user-local skill 文件，必须标注为环境资料而非项目真源 |
| 必须修正：事实/确认/指标检查不能过度门禁化 | 更强审计感不等于更强设计质量；新增检查可能诱导 LLM 写更像证据的套话 | 已把事实质量、确认摘要、指标来源改为“review prompt + eval fixture 先行”；validator 只拦截 obvious placeholder/unknown/empty/digest drift | 是否升级 validator 必须看失败 fixture、误报率、WARN 噪声率、S10 返工和下游消费收益 |
| 必须修正：新增检查必须有失败样例和反指标 | 若没有失败 fixture 和误报成本评估，新增门禁只是把填字段升级为填更复杂字段 | 已为 weak evidence、空泛 confirmation、伪 target metric 补可验证失败样例和反指标 | 后续实现前仍需补真实 eval fixture，而不是只改 prompt |
| 必须修正：S1 不能前移规则海 | canonical-ref、digest、WARN、reference integrity 不能一股脑前移到 S1，否则新成员入口变成规则海 | 已在行动项改为分阶段放置：S1 只保留准入、失败 owner、最低引用红线；S8 写作自检；S10/S11 处理修复、digest、reference integrity、validator | “最低引用红线”仍需在实际 quickstart/checklist 中具体化 |
| 必须修正：quickstart 不能形成新入口债 | quickstart 应是现有 `SKILL.md` / reference 的决策索引页，不能单独长成新的流程文档入口，也不能成为跳过 S1 preflight、S3-S10 checkpoint、S9 Owner Self-Check、S10 Advisory Review 或 S11 validators 的捷径 | 已在行动项收束：quickstart 不能是 `SKILL.md` 摘要，也不能成为新流程入口；必须写 owner、更新责任、过期清理规则、退出标准，并用负例证明不会诱导跳步 | 若后续 quickstart 被下游当主流程消费，应回退或归档 |
| 必须修正：清单前移不能替代真实脚本 | canonical-ref、digest、WARN、reference integrity 只能前移为自检提醒，不能替代 `review_digest.py`、`check_design_reference_integrity.py`、phase validator；避免“清单勾选=通过”的伪门禁 | 已在行动项写明 S8/S10/S11 的脚本和 validator 仍是完成证据；前移内容只做自检提醒 | 后续实现若把 checklist PASS 当 validator PASS，必须回退 |
| 必须修正：WARN 聚合不能掩盖 blocking | WARN 聚合只能聚合不阻塞的问题，不能把 blocking 问题压成待办噪音，也不能只聚合不暴露；不得合并掉稳定 finding id、reviewer、digest、target、承接字段 | 已在行动项要求 blocking 显式暴露并 fail-close；WARN 聚合只处理非阻塞问题，并保留 severity、证据、digest、target、承接字段和去向 | 仍需 dogfood 验证 WARN 噪声率与 blocking 暴露是否有效 |
| 必须修正：checklist 不能长成第二流程或新增字段 | checklist 只能是 downstream 消费字段的最小验收表，不能再长出第二套流程语义，也不能新增 schema/template 未定义字段 | 已在行动项限定 checklist 来源为 `/test-design`、`/tech-lead` 实际消费 gap；`boundary_behaviors` 对齐 `interfaces/interface_boundary`，性能压测规模落 `verification_mapping.test_obligation` 或 `planning_constraints` | 后续新增 checklist 项必须证明下游消费且字段已定义，否则应删除 |
| 必须修正：designer.md 不能复述 SKILL.md 或绕过 SOP | `designer.md` 只能定义派发/角色边界和唤起条件，不能复述 `/design` 步骤合同，也不能让 agent 绕过 skill SOP | 已在行动项限定 designer.md 只强化派发合同、active refs、required inputs、阻断模板，不复制 S1-S12 | 若后续 designer.md 出现流程步骤复述，会制造双真源 |
| 必须修正：review 时间盒必须 fail-close | review 时间盒若没有 fail-close，会变成赶进度式通过 | 已在 reviewer 收敛行动项要求时间盒附 fail-close；未关闭 blocking 不得通过 | 具体时间盒阈值需在实际 S10 dogfood 后确定 |
| 必须修正：标准链同步成本必须显式列出 | manifest/registry、closure contract、standard-chain key_fields、test-design 下游字段任一漂移都可能失败 | 已在行动项新增 standard-chain 同步成本；字段/行为/验证变更必须同步相关 contract、manifest、registry、key_fields 和下游字段检查 | 后续若改字段但未同步标准链，validator 或恢复链路会成为漂移源 |
| 必须修正：缺输入时必须 fail-close | 缺 brief/phase-prd/UNIT/确认态时不能继续，应输出固定 blocked 信息 | 已在行动项要求 blocked field、owner、next action、是否可继续；designer 派发合同也需强化该输出 | 具体 blocked schema 需在后续实现中验证与 preflight 一致 |
| 可保留边界：Agent loop | 可保留，但限定为“事实采证→设计裁决→产物验证”，不得迁移为自动签收或自动扩范围 | 已在核心判断和结论边界保留该限定 | 若后续文案再写“agent 自动完成设计”，需回滚 |
| 可保留边界：Skills progressive disclosure | 可保留，但 design 是流程型 skill，hard gates / validator 入口不能被过度拆分到 reference 后造成漏读 | 已在原则表和行动项写明只精简重复解释，不移动 hard gates / validator 入口 | 精简 `SKILL.md` 时仍需人工审查不可删约束 |
| 可保留边界：ADR/ATAM/arc42/C4 与 Spec Kit/Kiro | 这些只能作为审查视角或 requirements/design/tasks 分层思想，不应成为新增默认产物、阶段或审批强证据 | 已保留为可选透镜；不默认生成 ADR/C4/arc42，不采信 Kiro approval gates 作为强证据 | 生成图或 ADR 的 future work 仍需单独验证投影 manifest |
| 建议修改要点：下游字段与 review 收敛 | boundary_behaviors、性能压测规模、确认摘要质量先做 reviewer-checkable/WARN；review 控制 finding 数量、证据、承接字段、严重级别、digest 和 WARN 去向 | 已写入行动项：从 `/test-design`、`/tech-lead` 消费 gap 倒推 checklist；不默认增加 reviewer/checklist | reviewer WARN 噪声率和承接质量需要 dogfood 数据 |
| 最强反方挑战 | 报告最大问题不是方向错，而是容易把合理建议包装成官方原则推导结果；真正可验证优化应从 S10 lint/digest 漂移、旧 eval 漂移、`/test-design` gap、review 轮次成本、`designer.md` 入口过薄等仓库失败信号倒推 | 已把行动项改为“现有证据映射 + 仓库失败信号 + 小步试运行”，并明确本报告不能替代具体改动设计 | 后续优化计划仍必须用仓库失败信号、测试/eval 和下游消费 gap 做主证据 |

> 独立挑战来源：team-lead 于 2026-05-11 回传的 challenger 原文；本节已纳入挑战、处理决定和残余风险，当前无待回收阻断。

## 检索路径与覆盖证明

- 名称归一化：
  - AI agent：agentic systems、workflows vs agents、Claude Code agentic loop。
  - Claude Skills：Claude Code Skills、Anthropic Agent Skills、Agent Skills specification。
  - 软件架构设计助手：architecture documentation、architecture decision records、quality attribute evaluation、spec-driven development。
- 已查对象类型：
  - 官方工程文章：Anthropic Building effective agents。
  - 官方产品文档：Claude Code how-it-works、skills、subagents、agent teams、hooks、permission modes。
  - 开放标准/一手站点：agentskills.io specification、arc42、C4、C4 checklist、ADR。
  - 一手机构资料：SEI ATAM collection。
  - 一手仓库/产品文档：GitHub Spec Kit、Kiro specs。
  - 项目内真源：design skill、design schema/template、designer agent、reviewer prompt、projection template。
- 已查 discovery 入口：
  - 官方 URL 直接 WebFetch。
  - 项目文件直接 Read。
  - `/Users/lijieli/org-claude-skills/contracts/active-doc-scope.yaml` 确认当前无 managed active scope entries。
- 已排除候选：
  - ADD v2.0：未成功取得可靠一手定义，不能作为结论依据。
  - ISO/IEC/IEEE 42010：官方页面 fetch 超时，未纳入强证据。
  - Kiro approval gates：仅确认 Quick Plan 无 approval gates；未取得标准 specs 每阶段审批机制证据，不能作为人工确认依据。
- 剩余盲区：
  - ISO 42010 对 architecture description/stakeholder/viewpoint 的正式定义待补。
  - ADD v2.0 官方方法步骤待补。
  - Claude Code hooks 与当前项目 validator 的实际集成成本未评估。
  - 事实质量、确认摘要质量、指标来源检查是否适合 validator 门禁尚未验证；需先经 reviewer prompt + eval fixture + dogfood 证明低误报和真实下游收益。
  - quickstart 是否降低误用（以 quickstart 误用率、S10 首轮失败数和新人 30 分钟 fixture 通过率衡量）尚未验证。
  - WARN 聚合是否降低噪声且不吞 blocking，需用 WARN 噪声率、review 轮次和 S10 返工成本验证。
  - `/test-design` 与 `/tech-lead` 对 boundary_behaviors、性能压测规模、确认摘要质量等字段的实际消费收益尚未验证。
  - standard-chain 同步成本未评估：manifest/registry、closure contract、standard-chain key_fields、test-design 下游字段任一漂移都可能导致失败。
  - 本报告已迁入 skill-refiner refinement evidence 目录；当前定位为一次性研究证据，不是受管 standard-chain 需求工件。

## 项目上下文

- 技术栈/治理形态：本仓库以 skills、agents、contracts、schema、validator 管理 standard-chain 产物；本报告作为 refinement evidence 保存，不作为 active docs 接手入口。
- 已有相关实现：
  - `/Users/lijieli/org-claude-skills/shared/skills/design/SKILL.md`：定义 `/design` hard gates、S1-S12 流程、完成校验。
  - `/Users/lijieli/org-claude-skills/shared/skills/design/templates/design.template.json`：定义 canonical `design.json` 模板。
  - `/Users/lijieli/org-claude-skills/shared/skills/design/contracts/design.schema.json`：定义 design contract 的机器校验约束。
  - `/Users/lijieli/org-claude-skills/shared/skills/design/references/design-reviewer-prompt.md`：定义架构 reviewer advisory 审查。
  - `/Users/lijieli/org-claude-skills/shared/agents/designer.md`：定义 designer agent 只在标准流程派发合同和 active refs 存在时承接设计。
  - `/Users/lijieli/org-claude-skills/shared/skills/design/projections/design-template.md`：定义投影视图只从已验证 `design.json` 派生。
- 约束条件：
  - 文档管理规则要求未纳管的 `docs/*` 不作为接手候选；本报告已从 `docs/feature--...` 迁入 refinement evidence，避免被误认为 active standard-chain 需求。
  - 当前 `/Users/lijieli/org-claude-skills/contracts/active-doc-scope.yaml` 的 `scope_entries: []`，后续若要把本研究转成 active feature，必须另建受管 docs 入口并同步 scope registry。
  - 用户要求 research skill 流程：范围确认、候选收敛、证据深挖、独立挑战、报告落盘。

## 证据索引

| 编号 | 来源 | URL / 文件 |
| --- | --- | --- |
| E1 | Anthropic Building effective agents | https://www.anthropic.com/engineering/building-effective-agents |
| E2 | Claude Code how Claude Code works | https://code.claude.com/docs/en/how-claude-code-works |
| E3 | Claude Code Skills | https://code.claude.com/docs/en/skills |
| E4 | Anthropic Agent Skills overview | https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview |
| E5 | Agent Skills specification | https://agentskills.io/specification |
| E6 | Claude Code subagents | https://code.claude.com/docs/en/sub-agents |
| E7 | Claude Code agent teams | https://code.claude.com/docs/en/agent-teams |
| E8 | Claude Code hooks reference | https://code.claude.com/docs/en/hooks-reference |
| E9 | Claude Code permission modes | https://code.claude.com/docs/en/permission-modes |
| E10 | arc42 overview | https://arc42.org/overview |
| E11 | C4 model | https://c4model.com/ |
| E12 | C4 diagram checklist | https://c4model.com/diagrams/checklist |
| E13 | SEI ATAM collection | https://www.sei.cmu.edu/library/architecture-tradeoff-analysis-method-collection/ |
| E14 | ADR community site | https://adr.github.io/ |
| E15 | GitHub Spec Kit | https://github.com/github/spec-kit |
| E16 | Kiro specs | https://kiro.dev/docs/specs/ |
| E17 | 当前 design skill | `/Users/lijieli/org-claude-skills/shared/skills/design/SKILL.md` |
| E18 | design schema | `/Users/lijieli/org-claude-skills/shared/skills/design/contracts/design.schema.json` |
| E19 | design template | `/Users/lijieli/org-claude-skills/shared/skills/design/templates/design.template.json` |
| E20 | architecture reviewer prompt | `/Users/lijieli/org-claude-skills/shared/skills/design/references/design-reviewer-prompt.md` |
| E21 | designer agent | `/Users/lijieli/org-claude-skills/shared/agents/designer.md` |
| E22 | design projection template | `/Users/lijieli/org-claude-skills/shared/skills/design/projections/design-template.md` |

## 结论边界

- 本报告可以支持“是否以及如何优化 design skill”的方向判断，但只能作为辅助证据。
- 本报告不能替代具体改动设计，也不能作为审计级终稿；本轮已执行的 rewrite 以 `skill-refiner-result.json`、`refinement-ledger.json` 和测试结果为准。
- 本报告不是受管 standard-chain 需求工件；当前位于 skill-refiner refinement evidence 目录，只作为本轮打磨证据。若后续被 standard-chain 流程消费，必须另建受管 docs 入口并补 registry entry。
- 本报告不声称 ISO 42010、ADD v2.0、Kiro approval gates 已被充分验证。
- 本报告不声称通用 agent loop、ATAM、arc42、C4、ADR 或 Spec Kit 可直接作为 `/design` 规范来源；它们只提供经边界改写后的启发。
- 本报告不建议重建 design skill；后续建议只在当前 S1-S12 owner flow 上做最小增强，并优先用 dogfood 验证误报率、WARN 噪声率、S10 首轮失败数和下游消费收益。
- quickstart、checklist 和 `designer.md` 都不得成为第二套流程真源：quickstart 只做索引页，不能跳过 S1 preflight、S3-S10 checkpoint、S9 Owner Self-Check、S10 Advisory Review 或 S11 validators；checklist 只做下游字段最小验收且不得新增未定义字段；`designer.md` 只写派发/角色边界、唤起条件和阻断模板。
- canonical-ref、digest、WARN 和 reference integrity 的前移只能作为自检提醒；完成证据仍以 `review_digest.py`、`check_design_reference_integrity.py`、phase validator 和标准链同步结果为准。
- 剩余待验证项：ISO 42010、ADD v2.0、Claude Code hooks 集成成本、事实/确认/指标检查误报率、WARN 噪声率、S10 返工成本、quickstart 是否降低误用、下游 `/test-design` 与 `/tech-lead` 消费收益，均未由本报告证明。
- 后续若要把 reviewer/checklist 试运行升级为 schema/validator，必须先提供失败 fixture、误报成本评估、dogfood 数据和 standard-chain 同步影响评估。
