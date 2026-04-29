# Skill 质量标准审计调研报告

> 调研模式：analysis
> 呈现模式：audit

## 当前判断
- 这次要回答的问题：`/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md` 是否已经回答了“什么是 skill、最佳实践、什么内容能作为衡量标准、当前标准能否作为基线”这四个问题，并且能否作为本仓库 first-party Skill 的运行面质量基线。
- 当前结论：条件推荐。当前标准可以作为本仓库 first-party Skill 的 L2/L3 运行面质量基线；不能被表述为跨平台通用官方标准，也不能单独承担发布、保留、退役或真实行为增益的最终裁决。[A1][A2][A5][O1][G1][L1][L2][L3]
- 一句话判断：外部一手资料已经对 skill 的目录化封装、`description` 路由、渐进加载、脚本/权限边界、workflow、验证循环给出稳定共识；本仓库也已有 `skill-harness`、`scan`、测试脚本等真实消费者，但 D3/D7 的自动化证明与“文本合同 → 行为质量”的证据链还不够强。[A1][A2][A5][O1][G1][L1][L5][L6][L7][L8][L9][L10]
- 最大风险：把“文档与门禁口径完整”误当成“skill 的真实运行质量已经被证明”。[R2][L8][L9]
- 下一步动作：继续把当前标准作为本仓库运行面基线使用，同时补齐 JSON schema/validator、行为评估、README 真源入口、`lifecycle-review.json` 示例一致性和 D3/D4/D7 的更强证明链。[L1][L2][L3][L4][L8][L10]

## 关键论点挑战表
| 对象/论点 | 最强支持证据 | 最强反方挑战 | 当前判断 | 结论稳健性 |
|-----------|-------------|-------------|---------|-----------|
| 什么是 skill | Anthropic、OpenAI Codex、GitHub Copilot、Agent Skills open standard 都把 skill 定义为带 `SKILL.md` 的目录化能力包，按相关性渐进加载。[A1][A5][O1][G1] | `AGENTS.md`、custom instructions、MCP/plugin 也会影响 agent 行为，边界容易被混淆。[O2][G1] | 成立：skill 不是普通 prompt，而是可发现、可路由、可加载、可执行、可复核的目录化运行对象。 | 高 |
| skill 的最佳实践 | 官方共识聚焦于：清晰 `description`、单一职责、渐进加载、workflow、validation loop、脚本化确定性步骤、真实测试与 eval。[A2][A3][A5][A6][O1][G1] | 公开社区样本普遍停在 `SKILL.md + 少量 scripts/references`，很少把 eval、lifecycle、schema 做成常态，说明“最佳实践”不等于“生态平均水平”。[C1][C2][G1] | 成立：最佳实践存在，但需要区分 portable core 与 local hardening。 | 高 |
| 什么内容能作为衡量标准 | 外部资料共同支持触发、加载、边界、流程、验证这些运行面；本仓库把它们收敛为 D1-D8，并把有效性/生命周期独立出去。[A1][A2][A5][O1][G1][L1][L2][L3] | 公共资料没有直接给出 D1-D8 这样的封闭分维；D3 的 JSON 真源、D7 的 adapter/catalog 同步属于本地工程加固，不是公开生态的最低门槛。[A5][O1][G1][L1] | 部分成立：D1/D2/D4/D5/D6/D8 是强共识；D3/D7 可作为 first-party 加固；“是否值得存在”应继续留在相邻标准。 | 中高 |
| 当前标准能否作为基线 | 本仓库已有 `skill-harness`、`scan`、标准相关测试和相邻标准消费这份文档，说明它不是孤立文本。[L5][L6][L7][L9][L10] | 静态脚本当前主要覆盖 D1/D2/D5/D6/D8；文本存在性测试不能证明行为质量；行数启发缺少公开实证支撑。[L8][L9][R1][R2][R3] | 条件成立：可作为本仓库 first-party L2/L3 运行面基线，但不能单独作为 release/retain/retire 硬门禁。 | 中 |

## 覆盖证明摘要
- 已查入口摘要：Anthropic 平台文档与工程博客、Claude.ai 自定义 skill 文档、Agent Skills open standard、OpenAI Codex skills 文档、GitHub Copilot skill 文档、`anthropics/skills`、`openai/skills`、本仓库 `shared/reference` / `shared/skills` / `tests` / `README.md`、以及 3 篇针对技能生态与安全的反方研究。[A1][A2][A3][A4][A5][A6][O1][G1][C1][C2][R1][R2][R3][L1][L2][L3][L4][L5][L6][L7][L8][L9][L10]
- 最大剩余盲区：缺少一个跨 Anthropic/OpenAI/GitHub 的公开统一质量标准；缺少公开、可复跑的“行数阈值 ↔ 真实行为成功率”实证；缺少公开的 release/retain/retire 通用门禁规范。[A2][A5][O1][G1][R3]
- 为什么当前仍可判断：对“skill 是什么”和“高质量 skill 的运行面应该量什么”这两个核心问题，一手来源已经高度收敛；本仓库也已经把这些共识落到真实消费者和测试里，所以可以先对“能否作为本仓库基线”做条件判断，而不是等待不存在的通用官方总规范。[A1][A2][A5][O1][G1][L5][L6][L7][L9][L10]

## 直接回答四个问题

### 1. 什么是 skill
Skill 不是一篇普通说明文，也不是一次性的长 prompt。更准确的定义是：一个带 `SKILL.md` 的目录化能力包，至少包含 `name`、`description` 和可被 agent 按相关性加载的指令；它还可以附带 scripts、references、assets 等资源，并通过渐进加载在需要时才把详细内容带入上下文。[A1][A5][O1][G1]

### 2. 最佳实践是什么
一手资料和高质量样本共同支持的最佳实践是：让 `description` 明确触发条件；保持单一职责；把高频入口留在 `SKILL.md`，把低频细节下沉到 references/scripts；为复杂任务设计 workflow、validation loop 和可复跑测试；对 shell/bash、写入、网络和外部依赖设置权限边界；把真实任务和 with-skill / without-skill 对比作为质量证明，而不是只看文本是否工整。[A2][A3][A6][O1][G1]

### 3. 什么内容能作为衡量标准
可作为衡量标准的内容，应优先覆盖运行面合同，而不是文风偏好：何时触发、如何加载、输入输出/artifact、权限边界、流程自治、验证证据、演化兼容、表达可审计。这八类内容和本仓库的 D1-D8 基本对齐。另一方面，“这个 skill 是否仍值得存在”应继续由有效性和生命周期标准承担，而不是混入运行面质量标准。[L1][L2][L3]

### 4. 当前标准是否可作为基线
可以，但要限定语境：它可以作为 `/Users/lijieli/org-claude-skills` 的 first-party Skill 运行面质量基线，尤其适合 L2/L3 目标；不能被表述为公开生态最低标准，也不能单独代替行为 eval、生命周期评审或跨平台通用门禁。[L1][L2][L3][L5][L6][L7]

## 拆解对象概览
- 对象类型：项目方法 / 本地质量标准 / 生态定义与实践
- 原始观点：`Skill质量标准.md` 试图成为 first-party Skill 运行面质量裁决的真源，用 D1-D8 统一裁决触发、加载、artifact、权限、流程、验证、演化与表达。[L1]
- 需要回答的问题：
  1. 这个“skill”概念本身在官方与社区里是否有稳定定义？
  2. 官方和 GitHub 社区实践支持哪些最佳实践？
  3. 哪些内容可以进入“质量标准”，哪些应该放到相邻标准？
  4. 当前标准是否已经足够作为本仓库基线？

## 核心判断依据

## 什么是 Skill

### 核心机制
- 解决什么问题：把可重复的流程、领域上下文和工具使用方式打包成 agent 可复用的能力单元，避免每次对话都重新灌输同一套知识和步骤。[A1][A3][O1]
- 怎么解决：通过目录 + `SKILL.md` + 可选资源的组合，把“发现信号”放在 frontmatter，把“执行骨架”放在主文档，把“低频细节或确定性动作”放在 references/scripts/asset 中，并在运行时按需读取或执行。[A1][A5][O1][G1]
- 适用边界：它适用于可重复、可命名、可路由的工作流；不适用于一次性对话偏好、全局通用人格设定，或纯粹的外部工具协议本身。[G1][O2]

### 证据分层
- A 级证据：Anthropic overview、Agent Skills open standard、OpenAI Codex skills、GitHub Copilot 技能文档都把 skill 绑定到目录化 artifact、`SKILL.md`、`description` 与按需加载。[A1][A5][O1][G1]
- B 级证据：`anthropics/skills` 与 `openai/skills` 仓库把这些能力以目录形式公开分发，说明它不是纯文档概念，而是实际分发单元。[C1][C2]
- 证据冲突：Codex 的 `AGENTS.md`、subagents、`agents/openai.yaml`、GitHub 的 custom instructions 都会影响 agent 行为，但它们不是 skill 本体，而是相邻的环境层或分发层。[O1][O2][G1]

### 正反论证
- 最强支持证据：Anthropic 直接把 Agent Skills 定义为“modular capabilities”，由 instructions、metadata、optional resources 组成，并按 metadata → `SKILL.md` → resources/code 三层 progressive disclosure 载入。[A1]
- 最强反方挑战：如果把所有“影响 agent 行为的文件”都算 skill，那么 `AGENTS.md`、custom instructions、MCP plugins 也会被混入同一概念，导致边界失真。[O2][G1]
- 反例/失败案例：`AGENTS.md` 是分层 instruction 文件，不具备 skill 的目录化触发/分发语义；MCP/plugin 是工具协议或安装单元，不等于 skill；一次性 prompt 也不是可复用运行对象。[O1][G1]

### 深层分析
- 设计哲学：skill 的核心不是“知识库存”，而是“让 agent 在遇到某类任务时按对的流程行事”。这也是为什么 `description`、workflow 和 validation loop 比文风更重要。[A2][O1]
- 关键取舍：它在“可复用”和“上下文成本”之间取平衡：元数据常驻，主指令触发时加载，低频资源按需读取，脚本则通过执行输出而不是全文入窗来节省上下文。[A1][A2][A5]
- 演进方向：Anthropic、OpenAI 与 open standard 都在向“更稳定的发现/分发/权限控制”演进；与此同时，研究论文开始强调大规模 skill 生态的安全与检索问题，说明 skill 已从写作技巧进入工程治理阶段。[A3][A5][O1][R1][R2][R3]

### 项目适配评估
- 最匹配的点：本仓库已经用 `shared/skills/`、`community/*/skills/`、Codex adapters 和 contracts 把 skill 当成真实运行对象管理，而不是仅仅当作文档片段。[L4]
- 最不匹配的点：本仓库还要求 runtime catalog、adapter、install 暴露一致性，这比公开生态对“skill”本体的最低定义更严格。[L1][L3][L4]
- 采纳成本：低。仓库现有目录结构和治理方式已经围绕 `SKILL.md` 展开。[L4]
- 退出成本：高。如果否认 skill 的目录化本体，当前 `skill-harness`、`scan`、community mirror、install/runtime 口径都要重构。[L4][L5][L7]

### 当前判断
- 判定：成立。
- 结论稳健性：高。Anthropic、OpenAI、GitHub 和 open standard 在“skill 是可复用目录化能力包”这个层面高度一致。[A1][A5][O1][G1]
- 失效边界：如果主流平台统一废弃 `SKILL.md`、渐进加载和目录式分发，这个判断会被削弱。[A1][A5][O1]
- 待验证项：无关键缺口；后续只需继续跟踪开放标准与平台字段变化。[A5][O1]

## Skill 的最佳实践

### 核心机制
- 解决什么问题：最佳实践要保证 skill 不仅“存在”，而且能被正确触发、正确加载、正确执行、正确验证。[A2][A3][O1]
- 怎么解决：把 `description` 变成路由合同，把 `SKILL.md` 变成执行骨架，把 references/scripts 变成渐进加载和确定性操作的承载层，并通过 checklist、validation loop、eval 来证明 agent 真按预期工作。[A2][A5][A6][O1][G1]
- 适用边界：适合重复性工作流、脆弱高风险任务和领域知识注入；对极小的一次性帮助或全局通用偏好，不必一律技能化。[A2][G1]

### 证据分层
- A 级证据：Anthropic best practices、Anthropic engineering blog、Agent Skills evaluation guide、OpenAI Codex skills、GitHub Copilot 技能文档都强调 focused scope、workflow、testing、permissions、scripts。[A2][A3][A6][O1][G1]
- B 级证据：`anthropics/skills`、`openai/skills` 和本仓库镜像样本说明公开社区广泛采用 `SKILL.md + scripts/references` 这一基本形态，但并不普遍自带完整 eval/lifecycle artifact。[C1][C2]
- 证据冲突：官方 best practices 比社区平均实现更严格；社区样本更像“可用最低形态”，不是“生产级基线”。[A2][C1][C2]

### 正反论证
- 最强支持证据：Anthropic 明确建议 concise、第三人称 `description`、单一职责、渐进加载、workflow、validation loop、真实测试与跨模型测试；OpenAI 也强调 focused skill、imperative steps、explicit inputs/outputs 和 trigger testing。[A2][O1]
- 最强反方挑战：公开社区样本显示，很多 skill 只做到“可触发 + 可读”，并没有把脚本 manifest、schema、lifecycle、with/without baseline 做成常态，这说明最佳实践具有工程门槛，不等于公共生态最低标准。[C1][C2][R1]
- 反例/失败案例：过长主文档、层层嵌套 references、含糊的 `description`、把 `allowed-tools` 当默认放行、无 validation loop 的高风险脚本，都会直接削弱触发准确性或安全性。[A2][A5][G1][R2]

### 深层分析
- 设计哲学：最佳实践的核心不是“写得好看”，而是“最少的上下文 + 最强的正确执行信号”。[A2][A5]
- 关键取舍：脚本化会增加工程维护成本，但能换来确定性与低 token 开销；高自由度指令更灵活，但在高风险任务上需要用流程和校验收窄自由度。[A2][O1]
- 演进方向：公开标准正在把 tool permissions、compatibility、分发表达逐步纳入；同时安全研究已开始从“看 `SKILL.md`”升级到“看仓库上下文与依赖行为”。[A5][O1][R2][R3]

### 项目适配评估
- 最匹配的点：本仓库同时面向 Claude Code 与 Codex，且已有 contracts、hooks、scan、community mirrors，因此尤其需要 focused scope、progressive disclosure、permissions 与 proof commands 这些实践。[L4][L5][L7]
- 最不匹配的点：对极轻量 skill 来说，若把所有最佳实践都硬化为强门禁，会造成过度流程化。[A5][R1]
- 采纳成本：中。D1/D2/D4/D5/D6/D8 在仓内已经有承接；要把它们全面转成实证门禁仍需补 runner、schema 和 fixture。[L1][L5][L7][L8]
- 退出成本：中高。如果放弃这些实践，仓库会回到“只要写了 `SKILL.md` 就算完成”的早期状态，质量口径会迅速漂移。[L1][L10]

### 当前判断
- 判定：成立。
- 结论稳健性：高。官方与开源标准对“触发、渐进加载、流程、验证、脚本/权限边界”已有稳定共识。[A2][A5][O1][G1]
- 失效边界：如果未来平台完全把触发、工具授权、测试验证收进运行时而不再依赖 skill 文本，本结论会缩小到“作者侧编写建议”。[A2][O1]
- 待验证项：需持续跟踪 `allowed-tools`、adapter metadata、跨模型测试在不同平台的收敛程度。[A5][O1][G1]

## 什么内容能作为衡量标准

### 核心机制
- 解决什么问题：质量标准需要衡量“skill 会不会稳定改变 agent 的行为”，而不是只判断文档是否整洁。[L1][L6]
- 怎么解决：把质量标准绑定到运行面合同：触发、加载、输入输出、权限边界、流程自治、验证证据、演化兼容、表达可审计；同时把“效果是否值得继续维护”独立给有效性和生命周期标准。[L1][L2][L3]
- 适用边界：这个衡量框架适合 first-party 技能治理；对公开生态的 portable minimum，需要只保留较小公共核心，而不是把本地工程加固整体外推。[A5][O1][G1][L1]

### 证据分层
- A 级证据：Anthropic/OpenAI/GitHub/open standard 共同支持触发、加载、workflow、permissions、testing；本仓库标准把这些共识结构化成 D1-D8。[A1][A2][A5][A6][O1][G1][L1]
- B 级证据：社区公开仓库通常体现基本结构与脚本/资源组织，但较少提供 lifecycle、schema、validator、benchmark，这说明 D3/D7 等更强条款是工程化升级而非公开默认值。[C1][C2]
- 证据冲突：公开标准通常只定义“应该如何写/如何组织”，而本地标准还要回答“如何被 machine consumer 消费、如何进门禁、如何迁移退役”。这不是冲突，而是层级差异。[A5][L1][L2][L3]

### 正反论证
- 最强支持证据：D1-D8 把官方与工程实践拆成可审计裁决面，并通过资源合同、finding shape、L1/L2/L3 分级把质量判断落到可消费字段和验证动作上。[L1]
- 最强反方挑战：D1-D8 不是公开官方标准，且封闭分维可能在新型风险出现时制造“伪精确”；另外，JSON 真源、adapter/catalog 同步是本地工程判断，不应冒充生态共识。[R2][L1]
- 反例/失败案例：如果把“是否值得存在”也塞进 D1-D8，就会把运行面质量和生命周期决策混为一谈；本仓库已经用 `Skill能力有效性标准.md` 与 `Skill生命周期管理.md` 显式拆开，这个拆分本身就是对早期混淆的修正。[L2][L3]

### 深层分析
- 设计哲学：一个好的质量标准要先保护运行时真实风险，再谈表达风格。因此 D1-D8 的优先级顺序与工具/消费者映射，比单纯的文风 rubric 更接近工程真相。[L1][L6]
- 关键取舍：D3 的 JSON artifact 真源和 D7 的 adapter/runtime consistency 会提高治理可靠性，但也带来额外负担；把它们标成 first-party hardening，比把它们说成生态共识更诚实。[L1][O1]
- 演进方向：最佳做法不是继续加维度，而是在 D1-D8 稳定前提下补 consumer、validator、eval 和 exception path，让每个维度的证据强度逐步对齐。[L1][L5][L7][L8][L10]

### 项目适配评估
- 最匹配的点：本仓库本来就区分 first-party 真源、community mirror、runtime catalog、Codex adapter 与 lifecycle，因此需要一个运行面合同式标准来维持一致性。[L4]
- 最不匹配的点：如果把 D1-D8 原封不动拿去评价外部 skill，就会高估本地治理要求在公共生态中的普适性。[A5][G1][C1]
- 采纳成本：中。标准本身已存在，但要把所有维度变成同等强度的证明，还需要补自动化与真实 eval。[L8][L9][L10]
- 退出成本：高。没有统一衡量标准，`skill-harness`、`scan`、测试与后续 review 报告就会产生术语漂移。[L5][L6][L7][L10]

### 当前判断
- 判定：部分成立。
- 结论稳健性：中高。运行面衡量维度方向正确，但其中 D3/D7 更接近本地 hardening，需要显式限定适用语境。[L1][O1][G1]
- 失效边界：如果未来平台把 artifact/schema/adapter/catalog 统一抽象成更通用的上层规范，则当前 D3/D7 的本地表达需要重构。[O1][A5]
- 待验证项：
  - 是否为 finding JSON 建正式 schema 与 validator；
  - 是否把 D1-D8 的“封闭维度”配上 exception/proposal 通道；
  - 是否记录 token cost、latency、触发精度等行为指标，补强 D2/D6 的实证面。[L1][L8][R3]

## 当前标准是否可作为基线

### 核心机制
- 解决什么问题：回答“这份标准现在能不能拿来做本仓库 first-party Skill 的质量基线”。
- 怎么解决：看两类证据是否同时存在：一类是外部一手资料是否支持它衡量的核心对象；另一类是本仓库是否已经有真实消费者、测试和相邻标准围绕它运转。[A1][A2][A5][O1][G1][L5][L6][L7][L9][L10]
- 适用边界：它最多回答本仓库 first-party 运行面基线，不能外推成“公开生态最低标准”或“唯一发布门禁”。[L1][L2][L3]

### 证据分层
- A 级证据：
  - 外部：Anthropic/OpenAI/GitHub/open standard 对 definition、routing、loading、scripts、安全、testing 的共识。[A1][A2][A5][A6][O1][G1]
  - 本地：`skill-harness` 明确消费 `Skill质量标准.md`；`scan` 也按 D1-D8 的静态可检测子集输出信号；测试脚本直接锁定八维、资源合同、scan 规则和上下文预算的语义。[L5][L6][L7][L9][L10]
- B 级证据：`check_skill_body_quality.py` 已把 D1/D2/D5/D6/D8 落到确定性静态审计脚本中，说明标准不只是 prose；但它也显式承认自己不替代 semantic review 与 behavioral benefit，间接暴露 D3/D4/D7 的证明仍较弱。[L8]
- 证据冲突：测试与脚本证明“口径已落地”，但不能单独证明“skill 行为已提升”；这正是反方挑战的中心，也是报告最终不把结论写成“无条件通过”的原因。[L8][L9][R1][R2]

### 正反论证
- 最强支持证据：当前标准已经被真实消费者引用、被测试锁定、被 static audit 部分实现，并且和相邻的有效性/生命周期标准有清晰边界；这足以说明它可以作为本地运行基线，而不是孤立提案。[L1][L2][L3][L5][L6][L7][L9][L10]
- 最强反方挑战：
  1. 自动化覆盖不均衡，静态脚本主要覆盖 D1/D2/D5/D6/D8；
  2. 文本存在性测试能防漂移，但不能证明行为质量；
  3. 行数阈值仍主要是启发式；
  4. `lifecycle-review.json` 示例存在与合同字段不完全一致的历史痕迹；
  5. README 当前真源段未显式列出三份 Skill 标准入口。[L2][L4][L8][L9][L10][R1][R2][R3]
- 反例/失败案例：如果把它直接升级成 release/retain/retire 唯一门禁，就会越过 `Skill能力有效性标准.md` 和 `Skill生命周期管理.md` 的边界，产生职责重叠。[L2][L3]

### 深层分析
- 设计哲学：当前标准做对的一点，是把“运行面质量”和“存在合理性/生命周期”拆开。这让 D1-D8 可以专注于“会不会正确运行”，而不是一口吃掉所有治理问题。[L1][L2][L3]
- 关键取舍：它选择了比公开生态更严格的 first-party hardening，例如 JSON 事实源、runtime catalog、adapter 一致性、manual-only 双端暴露策略。这对本仓库是合理加固，但必须显式标注本地语境。[L1][L4]
- 演进方向：下一步不是继续加新维度，而是增强验证强度：schema/validator、behavior eval、with/without baseline、跨模型/跨平台证据、以及让 D3/D4/D7 的自动化证明追上 D1/D2/D5/D6/D8。[A6][L1][L8][R3]

### 项目适配评估
- 最匹配的点：
  - 仓库同时维护 `shared/` first-party 真源与多个 community mirror；
  - 需要兼顾 Claude Code 与 Codex CLI；
  - 已有 `skill-harness`、`scan`、runtime catalog、install/hook/test 这些真实消费者；
  - 规则要求 read-first、证据化、不能用 mock 伪造完成。[L4][L5][L6][L7][L9][L10]
- 最不匹配的点：公开生态的很多小型 skill 并不需要这么重的治理，因此这份标准不能拿来当对外通用 rubric。[A5][G1][C1][C2]
- 采纳成本：低到中。继续使用当前标准几乎无迁移成本；真正的成本在补齐缺失证明链。[L1][L8][L10]
- 退出成本：高。若废弃它，本仓库要重建 `skill-harness` / `scan` / tests / 相邻标准之间的共同语言。[L5][L6][L7][L10]

### 当前判断
- 判定：部分成立。
- 结论稳健性：中。它已经足够作为本仓库基线，但离“充分发布门禁”还差几块关键实证和消费者落地。[L1][L2][L3][L8][L9][L10]
- 失效边界：
  - 若平台官方废弃 `SKILL.md` / progressive disclosure；
  - 若本仓库后续验证发现 D1-D8 与真实触发/成功率/风险发现无显著关联；
  - 若 D3/D7 的本地 hardening 被实践证明维护成本高于收益。
- 待验证项：
  - finding JSON schema 与 validator；
  - D3/D4/D7 的更强 fixture/runner；
  - with-skill / without-skill 行为对比；
  - README 真源入口同步；
  - `lifecycle-review.json` 示例与合同字段一致性修补。[L2][L4][L8][L10]

## 吸收建议

### 可以直接吸收
| 论点/做法 | 适用条件 | 如何吸收 |
|-----------|---------|---------|
| skill 的本体是目录化、可路由、可渐进加载的运行对象 | 面向 Claude/Codex/GitHub 这类支持 `SKILL.md` 的 agent 生态 | 继续以 `SKILL.md + metadata + resources/scripts` 作为仓内 skill 基本单元。[A1][A5][O1][G1] |
| 运行面质量应优先衡量触发、加载、权限、流程、验证、演化、表达可审计 | 需要维护 first-party skill 质量一致性 | 继续以 D1-D8 为本仓库 first-party 运行基线。[L1] |
| 有效性/生命周期不应混入运行面质量维度 | 需要分别判断“能不能稳定运行”和“还值不值得存在” | 保持 `Skill能力有效性标准.md` 与 `Skill生命周期管理.md` 为相邻标准，不并入 D1-D8。[L2][L3] |

### 改写后吸收
| 原始说法 | 改写后的做法 | 改写原因 |
|---------|-------------|---------|
| D1-D8 就是“Skill 标准” | D1-D8 是“本仓库 first-party 运行面质量标准”；其中 D1/D2/D4/D5/D6/D8 近似官方导出共识，D3/D7 明确标注为 local hardening | 避免把本地工程加固冒充公开官方标准。[A5][O1][G1][L1] |
| 文本门禁与静态检查足以说明质量 | 文本门禁只证明合同与术语；行为质量仍需 eval、proof command、真实任务或跨模型验证补足 | 反方挑战指出文本存在性不能替代行为证明。[L8][L9][R1][R2] |
| 行数阈值可直接判质量 | 行数仅作为 warning-level signal；必须回到 active path 噪音、加载边界和消费者影响来裁决 | 官方与本地都把行数当启发式，而不是硬质量本身。[A2][L1][L10] |

### 不采纳
| 论点/做法 | 不采纳理由 |
|-----------|-----------|
| 把当前标准表述为跨平台、跨生态的通用官方标准 | 外部资料没有直接给出 D1-D8 这套封闭维度；部分条款是本地工程强化。[A5][O1][G1][L1] |
| 仅凭标准文本、grep 绿灯或静态脚本就宣称 Skill 行为质量已证明 | 这会把文档治理误当成运行质量，违背 D6 与反方研究的核心提醒。[L8][R2][R3] |
| 把 retain/retire 决策塞回 `Skill质量标准.md` | 本仓库已经明确把有效性和生命周期拆到相邻标准；混回去会破坏边界。[L2][L3] |

## 落地行动项
- [P0] 在 `README.md` 的“当前真源”补列三份 Skill 标准入口：`Skill质量标准.md`、`Skill能力有效性标准.md`、`Skill生命周期管理.md`。[L4]
- [P0] 修补 `Skill能力有效性标准.md` 中 `lifecycle-review.json` 示例与合同字段的一致性，尤其保证 `next_action` 示例和说明同步。[L2][L3]
- [P0] 为 quality finding / audit artifact 建正式 schema 与 validator，补齐 D3 的 machine-consumer 证据链。[L1]
- [P1] 为 D3/D4/D7 补更强的 fixture 或 runner，让 artifact、permissions、adapter/runtime consistency 不只停在文本规则层。[L7][L8][L10]
- [P1] 给关键 first-party skill 建 `with-skill / without-skill` 行为对比和 proof pack，把“标准存在”升级为“行为改善可证明”。[A6][L2][R3]
- [P2] 为 D1-D8 增加标准变更入口或 exception 记录方式，避免封闭维度在未来风险出现时造成伪精确。[R2]

## 独立挑战记录
| 挑战点 | challenger 质疑 | 原结论回应 | 是否调整 |
|--------|----------------|-----------|---------|
| D1-D8 封闭维度 | 封闭维度可能让新型风险被硬塞进旧标签，制造伪精确。 | 结论从“完整标准”下调为“本仓库基线”，并在行动项中加入 exception / proposal 入口。 | 是 |
| 自动化覆盖强度 | 现有自动化可能主要覆盖 D1/D2/D5/D6/D8，D3/D4/D7 更像文本承诺。 | 报告把“可作为基线”限定为条件成立，并把 D3/D4/D7 的加强列为 P0/P1 动作。 | 是 |
| 文本门禁 vs 行为质量 | 文本存在性测试能防漂移，但不能证明真实行为提升。 | 报告明确把文本门禁降级为“合同证明”，并要求 with/without eval 补行为证据。 | 是 |
| 行数启发式 | 250/500 行阈值缺少公开实证支撑。 | 报告不再把行数写成硬质量，只保留为 warning-level health signal。 | 是 |
| 资源合同负担 | 对小 skill 来说，完整资源合同可能过重。 | 报告把这点限定在 first-party L2/L3 语境，不再外推为生态最低标准。 | 是 |

## 检索路径与覆盖证明
- 名称归一化：`skill` / `skills` / `agent skill` / `agent skills` / `custom skill` / `Claude skill` / `Codex skill` / `GitHub Copilot skill` / `SKILL.md` / `allowed-tools` / `progressive disclosure`。
- 已查对象类型：官方文档、工程博客、开放标准、官方/社区仓库样本、本仓库本地标准、本仓库消费者（harness/scan/tests）、相邻但非同类对象（`AGENTS.md`、custom instructions、MCP/plugin）、反方研究论文。[A1][A2][A3][A4][A5][A6][O1][O2][G1][C1][C2][R1][R2][R3][L1][L2][L3][L5][L6][L7][L8][L9][L10]
- 已查 discovery 入口：`platform.claude.com`、`claude.com/docs`、`developers.openai.com`、`docs.github.com`、`github.com` 官方仓库、本仓库 `find/grep/read`、现有 deep-research artifacts、本地 mirrored community samples。[A1][A2][A4][O1][G1][C1][C2][L4]
- 去重策略：镜像/目录站只作样本入口；定义与最佳实践优先回到 Anthropic/OpenAI/GitHub/open standard 上游文档；社区仓库只用于验证生态实践，不拿 stars 或 README 自称替代标准本身。[A5][C1][C2]
- 已排除候选：
  - `AGENTS.md`：是分层 instruction 文件，不是 skill 本体。[O2]
  - MCP/plugin：是工具协议或安装单元，不等于 skill 的目录化运行对象。[G1]
  - `Skill能力有效性标准.md` / `Skill生命周期管理.md`：是相邻标准，不是 D1-D8 的运行面维度来源。[L2][L3]
  - arXiv 论文：只作为挑战与风险来源，不作为 primary 定义真源。[R1][R2][R3]
- 剩余盲区：
  - 缺少跨 Anthropic / OpenAI / GitHub 的统一公共质量标准；
  - 缺少公开的多模型、多平台 skill 质量基准；
  - 缺少行数阈值与真实错误率之间的公开实证数据。[A2][A5][O1][G1][R3]

## 项目上下文
- 技术栈：本仓库统一维护 Claude Code 与 Codex CLI 的 `skills / rules / reference / hooks / agents`；first-party 真源在 `shared/`，community mirror 在 `community/*`，并有 runtime contracts、install、hooks 和 tests 作为运行面消费者。[L4]
- 已有相关实现：
  - `shared/skills/skill-harness/SKILL.md`：明确声明消费 `Skill质量标准.md`，且默认 read-first；[L5]
  - `shared/skills/skill-harness/references/audit-method.md`：把 findings 映射回 D1-D8，再输出最终审计维度；[L6]
  - `shared/skills/scan/references/skills-scan-rules.md`：按 D1-D8 输出静态健康信号，不直接冒充最终评级；[L7]
  - `shared/skills/skill-harness/scripts/check_skill_body_quality.py`：把 D1/D2/D5/D6/D8 落成确定性静态审计；[L8]
  - `tests/test-skill-body-quality-static-audit.sh`、`tests/test-skill-quality-standard.sh`：锁定 finding shape、维度枚举、scan 规则、资源合同和行数信号语义。[L9][L10]
- 约束条件：
  - 规则要求 read-first、证据优先、不能用 mock 伪造验收；
  - 质量标准需要兼顾 Claude 与 Codex 的适配边界；
  - 文档管理要求相邻标准与消费者同步，不允许单文档漂移；
  - 当前标准若作为基线，必须服务 first-party 运行治理，而不是制造 runtime noise 或无消费者目录。[L1][L2][L3][L4][L5][L6][L7]

## 证据索引
- [A1] Anthropic Claude Platform: Agent Skills overview — https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
- [A2] Anthropic Claude Platform: Skill authoring best practices — https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- [A3] Anthropic Engineering: Equipping agents for the real world with Agent Skills — https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- [A4] Claude.ai Documentation: Creating custom skills — https://claude.com/docs/skills/how-to
- [A5] Agent Skills open standard: Specification — https://agentskills.io/specification
- [A6] Agent Skills open standard: Evaluating skill output quality — https://agentskills.io/skill-creation/evaluating-skills
- [O1] OpenAI Developers: Agent Skills in Codex — https://developers.openai.com/codex/skills
- [O2] OpenAI Developers: Custom instructions with AGENTS.md / Codex subagents — https://developers.openai.com/codex/guides/agents-md , https://developers.openai.com/codex/subagents
- [G1] GitHub Docs: Adding agent skills for GitHub Copilot CLI — https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/copilot-cli/customize-copilot/add-skills
- [C1] `anthropics/skills` repository — https://github.com/anthropics/skills
- [C2] `openai/skills` repository — https://github.com/openai/skills
- [R1] arXiv 2602.08004 — https://arxiv.org/abs/2602.08004
- [R2] arXiv 2603.16572 — https://arxiv.org/abs/2603.16572
- [R3] arXiv 2604.05333 — https://arxiv.org/abs/2604.05333
- [L1] `/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md`
- [L2] `/Users/lijieli/org-claude-skills/shared/reference/Skill能力有效性标准.md`
- [L3] `/Users/lijieli/org-claude-skills/shared/reference/Skill生命周期管理.md`
- [L4] `/Users/lijieli/org-claude-skills/README.md`
- [L5] `/Users/lijieli/org-claude-skills/shared/skills/skill-harness/SKILL.md`
- [L6] `/Users/lijieli/org-claude-skills/shared/skills/skill-harness/references/audit-method.md`
- [L7] `/Users/lijieli/org-claude-skills/shared/skills/scan/references/skills-scan-rules.md`
- [L8] `/Users/lijieli/org-claude-skills/shared/skills/skill-harness/scripts/check_skill_body_quality.py`
- [L9] `/Users/lijieli/org-claude-skills/tests/test-skill-body-quality-static-audit.sh`
- [L10] `/Users/lijieli/org-claude-skills/tests/test-skill-quality-standard.sh`

## 备注
完整来源索引仍保留在同目录 `sources.json`；本次报告是在既有调研资产基础上恢复并收口为符合 `/research` 合同的 `audit` 报告。