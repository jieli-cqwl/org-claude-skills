## Eval Prompt

先判断这个 topic 值不值得开正式调研，别写报告也别建 docs。

## Codex Prompt

You are running an isolated skill evaluation.

Use only the skill source below as the procedural contract. Do not browse the web,
do not read local files, and do not rely on any other skill. Apply the skill to
the user task and produce the immediate response/action you would give.

If the skill says to route to another skill, route clearly. If the skill requires
scope confirmation or report gating, state that instead of inventing completed
research. Keep the answer concise but substantive.

Skill variant: old_skill

<skill_source>
---
name: research
user-invocable: true
description: 系统性调研、方案拆解与 community 对象识别。Use when 技术/产品选型、已有方案或技术点深度拆解、竞品分析、问题域调研、skill/MCP/plugin/package/仓库对象定位等需要研究支撑判断的场景。
argument-hint: "[调研主题]"
context: fork
allowed-tools: Read, Write, Glob, Grep, WebSearch, WebFetch, AskUserQuestion, TeamCreate, SendMessage, TeamDelete
---

# /research -- 系统性调研分析与决策支持

> ultrathink

## HARD-GATE

1. NO 深度分析 without 范围确认；用户必须确认调研范围和关注维度后才能进入深度分析（Step 3+）。只读预扫描（Glob/Grep/Read）可在等待用户确认期间并行启动，但不得在确认前产生任何工件或对外输出。纯 community 对象定位时，必须产出名称解析 + 搜索覆盖证明。
2. NO community 对象结论 without 名称归一化（空格/连字符/连写/owner/对象类型）+ 候选排除表。
3. NO 关键结论 without 可追溯证据源（代码扫描/官方文档/源码/基准/社区指标/生产案例）+ 时间标记；权威来源必须先拆成可验证论点。
4. NO 推荐或反对 without 最强支持证据 + 最强反方挑战 + 失效条件 + 待验证项。
5. NO /research 完成 without `docs/{feature}/research-report.md` 落盘且用户确认。

## 警示信号

If you catch yourself thinking:
- "列一下主流方案让用户自己选" → STOP. 列清单不是调研，收敛到 TOP 3 并逐项深入才是。
- "这个方案很流行所以推荐" → STOP. 流行度不是证据，项目适配度才是。
- "简单介绍下优缺点就够了" → STOP. 每项必须拆解核心机制 + 给出实证数据 + 写出反方挑战和失效边界。
- "调研完直接给结论" → STOP. 结论必须回绑项目约束，给出可落地的行动项。
- "这篇文章/这个人很权威所以大概率对" → STOP. 先抽出其中的具体论点，再逐条验证和挑战。
- "信息差不多够了" → STOP. 检查每个论断是否都有证据源、反证和未验证项，无源或无反方 = 未完成。
- "多个目录站都指向它，所以可以算独立证据" → STOP. 先回溯上游仓库/文档并对镜像去重。
- "这个名字看起来像，所以先按它收敛再慢慢修" → STOP. 先做名称归一化、候选并存和排除证明。

## 角色

你是对抗式研究分析师。定位：深度调研 + 实证分析 + 决策支持。驱动：每个结论都必须经得起"证据在哪"和"最强反对意见是什么"的追问。锚点：宁可只分析 3 个对象但每个透彻，也不列 10 个对象蜻蜓点水。

核心方法论：
- 第一性原理：剥离表象回到核心机制，问"这东西到底解决什么问题"
- 证据优先：每个论断必须有可追溯证据，无源论断视为未完成
- 论点挑战：每个关键判断都要写出最强支持证据、最强反方挑战和失效边界
- 上下文绑定：所有分析回绑项目具体约束，拒绝通用结论
- 决策导向：输出必须让人一眼看出优缺点、适配度、风险和下一步

能力边界：agent teams 只用于 Step 2/3/5 的多策略候选穷举、候选深挖和 challenger 挑战；必须给每个协作成员传入固定输入、证据要求、输出格式和禁止越权项。research owner 负责范围确认、结论裁决、用户确认和 `research-report.md` 写入。

## 输入

用户提出的调研需求，通常属于三种 mode：
- `selection`：技术/产品/路线等多方案调研与取舍
- `analysis`：深拆已有方案/文章/知识/技术点，判断哪些成立、哪些不成立、哪些仅在特定条件下成立
- `discovery`：定位 community 里的 skill/MCP/plugin/package/仓库对象，解决“这个名字到底指哪个实体”

同时还必须识别一组独立的 `presentation_profile`：
- `decision`：目标是帮助用户快速做决定
- `understanding`：目标是帮助用户建立清晰认知
- `audit`：目标是帮助用户审计证据链、覆盖证明与反方挑战

`presentation_profile` 的判定必须回到三个槽位：
- 调研目的：本次是为了决策、建立理解，还是审计证据链
- 目标读者：谁会读这份报告，以及他们已有的上下文水平
- 读后动作：读者看完后需要做决定、继续学习、执行试点，还是触发复审

## 首轮澄清最小化规则

- 首轮只补缺口，不重复问用户已明确给出的信息；优先用“我理解你要……默认按 X + Y 继续，如有偏差请纠正”的确认式开场。
- 若用户原话已经明确给出调研对象、关键维度，且 `presentation_profile` 可按默认路由稳定推出，则一次确认式复述即可视为范围确认；无需额外 AskUserQuestion。
- 先基于用户原话预判 `research_mode` 和 `presentation_profile`，缺口最少化：
  - `selection` 默认 `decision`
  - `analysis`：若用户在问“何时成立/失效/为什么/怎么理解/有哪些启发”，直接默认 `understanding` 并推进；若用户在问“是否采纳/怎么推进/该不该用”，默认 `decision`；只有同一请求同时出现理解与决策目标冲突时才追问
  - `discovery`：若用户明确要求“排除证明/覆盖证明/可审计结论”，默认 `audit`；否则默认 `understanding`
- 通用最小必问槽位（只有缺失才问）：
  1. 调研对象或待决策问题
  2. 最关键的 2-4 个评估维度 / 挑战焦点 / 覆盖要求
- `feature` 目录名不是首轮硬门槛；若用户未提供，允许先完成范围确认与研究推进，但在 Step 7 落盘前必须补齐。
- 模式专属补充（只有原话无法定路由时才问）：
  - `selection`：默认按项目约束画像 + 官方/源码/一手证据优先推进；只有用户明确限制候选池/证据范围，或关键候选边界不清时，才追问范围
  - `analysis`：只有同时出现“先建立理解”和“立即做采纳决策”的冲突信号时，才追问优先目标
  - `discovery`：默认先查当前仓库/community；只有仓内证据不足、命中冲突，或用户明确要求时，才升级到外部来源
- 如果用户原话已经给出了 mode、profile、维度和对象，只做一次确认式复述并直接推进；`feature` 目录名若缺失，留到落盘前补问。禁止把上述问题重新完整问一遍。

## 流程

流程产物合同：每一步都必须形成可被下一步消费的 output，并写清 consumer、acceptance、failure_state、proof。证据不足时输出待验证项和反方挑战，不得把无源判断推进到报告结论。

状态表：

| 状态 | 允许动作 | 停止/转移 |
| --- | --- | --- |
| 范围确认 | AskUserQuestion 或确认式复述，启动只读预扫描 | 范围未确认不得进入深度分析 |
| 候选收敛 | agent teams 多策略穷举候选并去重 | 候选边界不清则回到范围确认 |
| 深度分析 | agent teams 按候选/论点独立深挖证据 | 证据不足则标注待验证，不编造 |
| 独立挑战 | agent teams challenger 质疑结论和风险 | 挑战未纳入报告不得输出 |
| 报告确认 | research owner 写入报告并请求用户确认 | 用户未确认不得声明完成 |

1. 预扫描 + 范围澄清 — 先按“首轮澄清最小化规则”发起确认式提问，优先复述已知信息，只补缺失槽位。若用户原话已明确调研对象、关键维度，且 `presentation_profile` 可按默认路由稳定推出，则一次确认式复述即可视为范围确认；否则再用 AskUserQuestion 确认调研范围 + 关注维度 + `presentation_profile` ← HARD-GATE。`feature` 目录名允许延后到 Step 7 落盘前补齐。
   当执行呈现模式澄清时：
	   → 读取 `references/report-presentation-framework.md` 获取 `decision / understanding / audit` 的目标、首屏重点与默认路由规则。
	   在等待用户回应期间，利用空闲并行启动只读预扫描（Glob/Grep/Read，零副作用，不产生工件）：`selection/analysis` 扫描项目技术栈、依赖、架构模式、已有相关实现；`discovery` 扫描用户给的截图、榜单、既有报告、README、安装入口、文件结构形成对象约束画像。用户确认后，将预扫描结果融入后续步骤。
   - Output: 调研范围、模式、呈现 profile、预扫描证据；Consumer: Step 2；Acceptance: 关键对象和维度已确认或被默认路由稳定推出；Failure_state: 范围未确认则不得进入深度分析；Proof: 用户确认或确认式复述、预扫描路径。
2. 模式路由 + 候选收敛 — 基于 Step 1 的扫描结果和确认范围，识别 `selection`、`analysis` 或 `discovery` 模式（见 `references/analysis-frameworks.md`），同时确定 `presentation_profile`。若 Step 1 已明确 `research_mode + presentation_profile + 对象/维度`，则直接呈现识别结果并进入候选收敛，不再重复 AskUserQuestion；只有仍有歧义时才再次确认。同时召集 agent teams 从不同搜索策略并行穷举候选，合并去重后标记证据等级、时间和冲突点。一轮呈现给用户：识别出的 `research_mode + presentation_profile` + 候选列表。`selection` 收敛到 TOP 3（含淘汰理由）并确认评估维度；`analysis` 收敛到 1-3 个核心论点并确认挑战焦点；`discovery` 先做名称归一化（空格/连字符/连写/owner/别名）与对象类型覆盖（repo/skill/MCP/plugin/package/目录），再输出候选表、排除理由、剩余盲区。
   - Output: 候选集、淘汰表、名称归一化和对象类型覆盖；Consumer: Step 3；Acceptance: 候选边界、证据等级和冲突点可追踪；Failure_state: 候选边界不清则回到 Step 1；Proof: 搜索覆盖、排除理由和候选来源。
3. 并行深度分析 — 每个候选/论点由 agent teams 成员并行深挖，禁止先共享结论，各自独立形成判断。按 `references/deep-analysis-template.md` 对 `selection/analysis` 的每个对象执行核心机制拆解；`discovery` 对每个候选核对 owner、上游来源、安装入口、README/文件结构、镜像关系、热度口径和排除证据。
   - Output: 每个候选/论点的机制拆解、证据源、时间标记和待验证项；Consumer: Step 4；Acceptance: 关键判断有来源和反证路径；Failure_state: 证据不足则标待验证；Proof: 官方文档、源码、仓库、代码扫描或基准链接。
4. 结构化评估 — 汇总各 agent 的独立分析结果。`selection`：按维度集做对比矩阵（评分+证据+主要风险）并形成推荐/次选/不推荐。`analysis`：输出论点挑战表（支持 / 反方 / 判定 / 结论稳健性）。`discovery`：输出实体解析表（候选 / 类型 / 上游来源 / 主要证据 / 反证 / 当前状态）并形成命中 / 部分命中 / 未命中 / 待验证判断。
   - Output: 对比矩阵、论点挑战表或实体解析表；Consumer: Step 5；Acceptance: 推荐/判定同时包含支持证据、反方证据和失效条件；Failure_state: 证据链断裂则回到 Step 3；Proof: 矩阵 evidence cells 与排除记录。
5. 独立挑战 — 通过 agent teams 派发 challenger 对 Step 4 的结论进行独立挑战：质疑推荐理由是否成立、反方证据是否被充分考虑、失效边界是否被低估、是否存在权威偏见。challenger 的挑战结果必须原样纳入最终报告。
   - Output: challenger findings 与结论修正记录；Consumer: Step 6/7；Acceptance: 每个关键结论至少有反方挑战和处理结果；Failure_state: 挑战未纳入报告则不得输出；Proof: challenger 原文、处理决定和残余风险。
6. 项目适配与行动计划 — 将分析结论（含 challenger 挑战结果）回绑项目约束画像。`selection` 给出采纳/试点/放弃动作；`analysis` 给出吸收/改写后吸收/不采纳动作；`discovery` 给出后续查询、安装或验证动作。AskUserQuestion 确认结论。
   - Output: 项目适配结论、行动项和失效条件；Consumer: Step 7 和用户决策；Acceptance: 动作可执行且回绑项目约束；Failure_state: 用户不确认则修正结论；Proof: 约束 refs、行动 owner 和用户确认。
7. 输出报告 — 按以下模板输出 `docs/{feature}/research-report.md`。报告必须显式写出 `调研模式` 与 `呈现模式`，并遵循“答案层 → 判断层 → 证据层 → 审计层”的渐进披露：
   - `decision` 头部：`projections/research-decision-header-template.md`
   - `understanding` 头部：`projections/research-understanding-header-template.md`
   - `audit` 头部：`projections/research-audit-header-template.md`
   - `selection`：`projections/research-tech-selection-template.md`
   - `analysis`：`projections/research-analysis-template.md`
	   - `discovery`：`projections/research-discovery-template.md`
	   - 共享审计附录：`projections/research-shared-audit-appendix-template.md`
   - Output: `docs/{feature}/research-report.md`；Consumer: 用户决策、后续设计/实现；Acceptance: 报告包含答案层、判断层、证据层、审计层；Failure_state: feature 目录缺失或用户未确认则不得完成；Proof: 文件路径、证据源列表和用户确认。

## 输出

`docs/{feature}/research-report.md` 由“呈现模式头部 + 调研模式正文 + 共享审计附录”组成。`projections/research-shared-header-template.md` 仅保留为旧路径兼容入口，不能再作为默认模板入口。

## 异常处理

| 情况 | 处理 |
|------|------|
| WebSearch 无有效结果 | 换关键词 + 降级为代码分析和文档推理，报告标注信息局限性 |
| 候选超过 5 个 | 强制 TOP 3，淘汰项列入附录 |
| 命中很多镜像/目录站 | 去重到上游仓库/官方文档，再评估是否算独立证据 |
| 名称可能有别名或连写差异 | 强制扩展空格/连字符/连写/owner/对象类型变体，再继续收敛 |
| 调研中发现范围需扩展 | → 向用户报告并确认是否扩展 |
| 关键维度无实证数据 | 标注"无实证"，不编造，列出验证方式与结论翻转条件 |

## 完成校验

- [ ] `docs/{feature}/research-report.md` 存在且非空
- [ ] 报告显式包含 `调研模式` 与 `呈现模式`
- [ ] 报告含“项目上下文”且引用了实际扫描结果
- [ ] 报告含“独立挑战记录”，challenger 结论已原样纳入
- [ ] 报告含“检索路径与覆盖证明”，列出名称变体、对象类型覆盖、已排除候选与剩余盲区
- [ ] 报告首屏与 `presentation_profile` 一致：`decision` 优先结论与动作，`understanding` 优先概念与边界，`audit` 优先证据审计
- [ ] 每个关键判断都有最强支持证据 + 最强反方挑战 + 失效边界
- [ ] 所有权威引用已拆成可验证论点，不以来源头衔直接下结论
- [ ] 结论回绑项目约束，包含可落地的行动项

</skill_source>

<user_task>
先判断这个 topic 值不值得开正式调研，别写报告也别建 docs。
</user_task>

Return Markdown with exactly these sections:
## Response
## Self Check
- route:
- mode:
- presentation_profile:
- artifacts_required:


## Stderr

2026-05-12T16:10:10.852832Z  WARN codex_rollout::list: state db discrepancy during find_thread_path_by_id_str_in_subdir: falling_back
2026-05-12T16:10:10.878732Z  WARN codex_rollout::list: state db discrepancy during find_thread_path_by_id_str_in_subdir: falling_back
OpenAI Codex v0.130.0
--------
workdir: /Users/lijieli/org-claude-skills
model: gpt-5.5
provider: openai
approval: never
sandbox: danger-full-access
reasoning effort: none
reasoning summaries: none
session id: 019e1cf3-f608-7162-a27c-33ce5b60b865
--------
user
You are running an isolated skill evaluation.

Use only the skill source below as the procedural contract. Do not browse the web,
do not read local files, and do not rely on any other skill. Apply the skill to
the user task and produce the immediate response/action you would give.

If the skill says to route to another skill, route clearly. If the skill requires
scope confirmation or report gating, state that instead of inventing completed
research. Keep the answer concise but substantive.

Skill variant: old_skill

<skill_source>
---
name: research
user-invocable: true
description: 系统性调研、方案拆解与 community 对象识别。Use when 技术/产品选型、已有方案或技术点深度拆解、竞品分析、问题域调研、skill/MCP/plugin/package/仓库对象定位等需要研究支撑判断的场景。
argument-hint: "[调研主题]"
context: fork
allowed-tools: Read, Write, Glob, Grep, WebSearch, WebFetch, AskUserQuestion, TeamCreate, SendMessage, TeamDelete
---

# /research -- 系统性调研分析与决策支持

> ultrathink

## HARD-GATE

1. NO 深度分析 without 范围确认；用户必须确认调研范围和关注维度后才能进入深度分析（Step 3+）。只读预扫描（Glob/Grep/Read）可在等待用户确认期间并行启动，但不得在确认前产生任何工件或对外输出。纯 community 对象定位时，必须产出名称解析 + 搜索覆盖证明。
2. NO community 对象结论 without 名称归一化（空格/连字符/连写/owner/对象类型）+ 候选排除表。
3. NO 关键结论 without 可追溯证据源（代码扫描/官方文档/源码/基准/社区指标/生产案例）+ 时间标记；权威来源必须先拆成可验证论点。
4. NO 推荐或反对 without 最强支持证据 + 最强反方挑战 + 失效条件 + 待验证项。
5. NO /research 完成 without `docs/{feature}/research-report.md` 落盘且用户确认。

## 警示信号

If you catch yourself thinking:
- "列一下主流方案让用户自己选" → STOP. 列清单不是调研，收敛到 TOP 3 并逐项深入才是。
- "这个方案很流行所以推荐" → STOP. 流行度不是证据，项目适配度才是。
- "简单介绍下优缺点就够了" → STOP. 每项必须拆解核心机制 + 给出实证数据 + 写出反方挑战和失效边界。
- "调研完直接给结论" → STOP. 结论必须回绑项目约束，给出可落地的行动项。
- "这篇文章/这个人很权威所以大概率对" → STOP. 先抽出其中的具体论点，再逐条验证和挑战。
- "信息差不多够了" → STOP. 检查每个论断是否都有证据源、反证和未验证项，无源或无反方 = 未完成。
- "多个目录站都指向它，所以可以算独立证据" → STOP. 先回溯上游仓库/文档并对镜像去重。
- "这个名字看起来像，所以先按它收敛再慢慢修" → STOP. 先做名称归一化、候选并存和排除证明。

## 角色

你是对抗式研究分析师。定位：深度调研 + 实证分析 + 决策支持。驱动：每个结论都必须经得起"证据在哪"和"最强反对意见是什么"的追问。锚点：宁可只分析 3 个对象但每个透彻，也不列 10 个对象蜻蜓点水。

核心方法论：
- 第一性原理：剥离表象回到核心机制，问"这东西到底解决什么问题"
- 证据优先：每个论断必须有可追溯证据，无源论断视为未完成
- 论点挑战：每个关键判断都要写出最强支持证据、最强反方挑战和失效边界
- 上下文绑定：所有分析回绑项目具体约束，拒绝通用结论
- 决策导向：输出必须让人一眼看出优缺点、适配度、风险和下一步

能力边界：agent teams 只用于 Step 2/3/5 的多策略候选穷举、候选深挖和 challenger 挑战；必须给每个协作成员传入固定输入、证据要求、输出格式和禁止越权项。research owner 负责范围确认、结论裁决、用户确认和 `research-report.md` 写入。

## 输入

用户提出的调研需求，通常属于三种 mode：
- `selection`：技术/产品/路线等多方案调研与取舍
- `analysis`：深拆已有方案/文章/知识/技术点，判断哪些成立、哪些不成立、哪些仅在特定条件下成立
- `discovery`：定位 community 里的 skill/MCP/plugin/package/仓库对象，解决“这个名字到底指哪个实体”

同时还必须识别一组独立的 `presentation_profile`：
- `decision`：目标是帮助用户快速做决定
- `understanding`：目标是帮助用户建立清晰认知
- `audit`：目标是帮助用户审计证据链、覆盖证明与反方挑战

`presentation_profile` 的判定必须回到三个槽位：
- 调研目的：本次是为了决策、建立理解，还是审计证据链
- 目标读者：谁会读这份报告，以及他们已有的上下文水平
- 读后动作：读者看完后需要做决定、继续学习、执行试点，还是触发复审

## 首轮澄清最小化规则

- 首轮只补缺口，不重复问用户已明确给出的信息；优先用“我理解你要……默认按 X + Y 继续，如有偏差请纠正”的确认式开场。
- 若用户原话已经明确给出调研对象、关键维度，且 `presentation_profile` 可按默认路由稳定推出，则一次确认式复述即可视为范围确认；无需额外 AskUserQuestion。
- 先基于用户原话预判 `research_mode` 和 `presentation_profile`，缺口最少化：
  - `selection` 默认 `decision`
  - `analysis`：若用户在问“何时成立/失效/为什么/怎么理解/有哪些启发”，直接默认 `understanding` 并推进；若用户在问“是否采纳/怎么推进/该不该用”，默认 `decision`；只有同一请求同时出现理解与决策目标冲突时才追问
  - `discovery`：若用户明确要求“排除证明/覆盖证明/可审计结论”，默认 `audit`；否则默认 `understanding`
- 通用最小必问槽位（只有缺失才问）：
  1. 调研对象或待决策问题
  2. 最关键的 2-4 个评估维度 / 挑战焦点 / 覆盖要求
- `feature` 目录名不是首轮硬门槛；若用户未提供，允许先完成范围确认与研究推进，但在 Step 7 落盘前必须补齐。
- 模式专属补充（只有原话无法定路由时才问）：
  - `selection`：默认按项目约束画像 + 官方/源码/一手证据优先推进；只有用户明确限制候选池/证据范围，或关键候选边界不清时，才追问范围
  - `analysis`：只有同时出现“先建立理解”和“立即做采纳决策”的冲突信号时，才追问优先目标
  - `discovery`：默认先查当前仓库/community；只有仓内证据不足、命中冲突，或用户明确要求时，才升级到外部来源
- 如果用户原话已经给出了 mode、profile、维度和对象，只做一次确认式复述并直接推进；`feature` 目录名若缺失，留到落盘前补问。禁止把上述问题重新完整问一遍。

## 流程

流程产物合同：每一步都必须形成可被下一步消费的 output，并写清 consumer、acceptance、failure_state、proof。证据不足时输出待验证项和反方挑战，不得把无源判断推进到报告结论。

状态表：

| 状态 | 允许动作 | 停止/转移 |
| --- | --- | --- |
| 范围确认 | AskUserQuestion 或确认式复述，启动只读预扫描 | 范围未确认不得进入深度分析 |
| 候选收敛 | agent teams 多策略穷举候选并去重 | 候选边界不清则回到范围确认 |
| 深度分析 | agent teams 按候选/论点独立深挖证据 | 证据不足则标注待验证，不编造 |
| 独立挑战 | agent teams challenger 质疑结论和风险 | 挑战未纳入报告不得输出 |
| 报告确认 | research owner 写入报告并请求用户确认 | 用户未确认不得声明完成 |

1. 预扫描 + 范围澄清 — 先按“首轮澄清最小化规则”发起确认式提问，优先复述已知信息，只补缺失槽位。若用户原话已明确调研对象、关键维度，且 `presentation_profile` 可按默认路由稳定推出，则一次确认式复述即可视为范围确认；否则再用 AskUserQuestion 确认调研范围 + 关注维度 + `presentation_profile` ← HARD-GATE。`feature` 目录名允许延后到 Step 7 落盘前补齐。
   当执行呈现模式澄清时：
	   → 读取 `references/report-presentation-framework.md` 获取 `decision / understanding / audit` 的目标、首屏重点与默认路由规则。
	   在等待用户回应期间，利用空闲并行启动只读预扫描（Glob/Grep/Read，零副作用，不产生工件）：`selection/analysis` 扫描项目技术栈、依赖、架构模式、已有相关实现；`discovery` 扫描用户给的截图、榜单、既有报告、README、安装入口、文件结构形成对象约束画像。用户确认后，将预扫描结果融入后续步骤。
   - Output: 调研范围、模式、呈现 profile、预扫描证据；Consumer: Step 2；Acceptance: 关键对象和维度已确认或被默认路由稳定推出；Failure_state: 范围未确认则不得进入深度分析；Proof: 用户确认或确认式复述、预扫描路径。
2. 模式路由 + 候选收敛 — 基于 Step 1 的扫描结果和确认范围，识别 `selection`、`analysis` 或 `discovery` 模式（见 `references/analysis-frameworks.md`），同时确定 `presentation_profile`。若 Step 1 已明确 `research_mode + presentation_profile + 对象/维度`，则直接呈现识别结果并进入候选收敛，不再重复 AskUserQuestion；只有仍有歧义时才再次确认。同时召集 agent teams 从不同搜索策略并行穷举候选，合并去重后标记证据等级、时间和冲突点。一轮呈现给用户：识别出的 `research_mode + presentation_profile` + 候选列表。`selection` 收敛到 TOP 3（含淘汰理由）并确认评估维度；`analysis` 收敛到 1-3 个核心论点并确认挑战焦点；`discovery` 先做名称归一化（空格/连字符/连写/owner/别名）与对象类型覆盖（repo/skill/MCP/plugin/package/目录），再输出候选表、排除理由、剩余盲区。
   - Output: 候选集、淘汰表、名称归一化和对象类型覆盖；Consumer: Step 3；Acceptance: 候选边界、证据等级和冲突点可追踪；Failure_state: 候选边界不清则回到 Step 1；Proof: 搜索覆盖、排除理由和候选来源。
3. 并行深度分析 — 每个候选/论点由 agent teams 成员并行深挖，禁止先共享结论，各自独立形成判断。按 `references/deep-analysis-template.md` 对 `selection/analysis` 的每个对象执行核心机制拆解；`discovery` 对每个候选核对 owner、上游来源、安装入口、README/文件结构、镜像关系、热度口径和排除证据。
   - Output: 每个候选/论点的机制拆解、证据源、时间标记和待验证项；Consumer: Step 4；Acceptance: 关键判断有来源和反证路径；Failure_state: 证据不足则标待验证；Proof: 官方文档、源码、仓库、代码扫描或基准链接。
4. 结构化评估 — 汇总各 agent 的独立分析结果。`selection`：按维度集做对比矩阵（评分+证据+主要风险）并形成推荐/次选/不推荐。`analysis`：输出论点挑战表（支持 / 反方 / 判定 / 结论稳健性）。`discovery`：输出实体解析表（候选 / 类型 / 上游来源 / 主要证据 / 反证 / 当前状态）并形成命中 / 部分命中 / 未命中 / 待验证判断。
   - Output: 对比矩阵、论点挑战表或实体解析表；Consumer: Step 5；Acceptance: 推荐/判定同时包含支持证据、反方证据和失效条件；Failure_state: 证据链断裂则回到 Step 3；Proof: 矩阵 evidence cells 与排除记录。
5. 独立挑战 — 通过 agent teams 派发 challenger 对 Step 4 的结论进行独立挑战：质疑推荐理由是否成立、反方证据是否被充分考虑、失效边界是否被低估、是否存在权威偏见。challenger 的挑战结果必须原样纳入最终报告。
   - Output: challenger findings 与结论修正记录；Consumer: Step 6/7；Acceptance: 每个关键结论至少有反方挑战和处理结果；Failure_state: 挑战未纳入报告则不得输出；Proof: challenger 原文、处理决定和残余风险。
6. 项目适配与行动计划 — 将分析结论（含 challenger 挑战结果）回绑项目约束画像。`selection` 给出采纳/试点/放弃动作；`analysis` 给出吸收/改写后吸收/不采纳动作；`discovery` 给出后续查询、安装或验证动作。AskUserQuestion 确认结论。
   - Output: 项目适配结论、行动项和失效条件；Consumer: Step 7 和用户决策；Acceptance: 动作可执行且回绑项目约束；Failure_state: 用户不确认则修正结论；Proof: 约束 refs、行动 owner 和用户确认。
7. 输出报告 — 按以下模板输出 `docs/{feature}/research-report.md`。报告必须显式写出 `调研模式` 与 `呈现模式`，并遵循“答案层 → 判断层 → 证据层 → 审计层”的渐进披露：
   - `decision` 头部：`projections/research-decision-header-template.md`
   - `understanding` 头部：`projections/research-understanding-header-template.md`
   - `audit` 头部：`projections/research-audit-header-template.md`
   - `selection`：`projections/research-tech-selection-template.md`
   - `analysis`：`projections/research-analysis-template.md`
	   - `discovery`：`projections/research-discovery-template.md`
	   - 共享审计附录：`projections/research-shared-audit-appendix-template.md`
   - Output: `docs/{feature}/research-report.md`；Consumer: 用户决策、后续设计/实现；Acceptance: 报告包含答案层、判断层、证据层、审计层；Failure_state: feature 目录缺失或用户未确认则不得完成；Proof: 文件路径、证据源列表和用户确认。

## 输出

`docs/{feature}/research-report.md` 由“呈现模式头部 + 调研模式正文 + 共享审计附录”组成。`projections/research-shared-header-template.md` 仅保留为旧路径兼容入口，不能再作为默认模板入口。

## 异常处理

| 情况 | 处理 |
|------|------|
| WebSearch 无有效结果 | 换关键词 + 降级为代码分析和文档推理，报告标注信息局限性 |
| 候选超过 5 个 | 强制 TOP 3，淘汰项列入附录 |
| 命中很多镜像/目录站 | 去重到上游仓库/官方文档，再评估是否算独立证据 |
| 名称可能有别名或连写差异 | 强制扩展空格/连字符/连写/owner/对象类型变体，再继续收敛 |
| 调研中发现范围需扩展 | → 向用户报告并确认是否扩展 |
| 关键维度无实证数据 | 标注"无实证"，不编造，列出验证方式与结论翻转条件 |

## 完成校验

- [ ] `docs/{feature}/research-report.md` 存在且非空
- [ ] 报告显式包含 `调研模式` 与 `呈现模式`
- [ ] 报告含“项目上下文”且引用了实际扫描结果
- [ ] 报告含“独立挑战记录”，challenger 结论已原样纳入
- [ ] 报告含“检索路径与覆盖证明”，列出名称变体、对象类型覆盖、已排除候选与剩余盲区
- [ ] 报告首屏与 `presentation_profile` 一致：`decision` 优先结论与动作，`understanding` 优先概念与边界，`audit` 优先证据审计
- [ ] 每个关键判断都有最强支持证据 + 最强反方挑战 + 失效边界
- [ ] 所有权威引用已拆成可验证论点，不以来源头衔直接下结论
- [ ] 结论回绑项目约束，包含可落地的行动项

</skill_source>

<user_task>
先判断这个 topic 值不值得开正式调研，别写报告也别建 docs。
</user_task>

Return Markdown with exactly these sections:
## Response
## Self Check
- route:
- mode:
- presentation_profile:
- artifacts_required:

2026-05-12T16:10:10.907765Z  WARN codex_rollout::list: state db discrepancy during find_thread_path_by_id_str_in_subdir: falling_back
2026-05-12T16:10:10.957895Z  WARN codex_rollout::list: state db discrepancy during find_thread_path_by_id_str_in_subdir: falling_back
2026-05-12T16:10:10.980430Z  WARN codex_rollout::list: state db discrepancy during find_thread_path_by_id_str_in_subdir: falling_back
2026-05-12T16:10:11.003019Z  WARN codex_rollout::list: state db discrepancy during find_thread_path_by_id_str_in_subdir: falling_back
2026-05-12T16:10:11.029230Z  WARN codex_rollout::list: state db discrepancy during find_thread_path_by_id_str_in_subdir: falling_back
2026-05-12T16:10:11.059944Z  WARN codex_rollout::list: state db discrepancy during find_thread_path_by_id_str_in_subdir: falling_back
2026-05-12T16:10:11.084757Z  WARN codex_rollout::list: state db discrepancy during find_thread_path_by_id_str_in_subdir: falling_back
2026-05-12T16:10:11.111979Z  WARN codex_rollout::list: state db discrepancy during find_thread_path_by_id_str_in_subdir: falling_back
2026-05-12T16:10:11.137982Z  WARN codex_rollout::list: state db discrepancy during find_thread_path_by_id_str_in_subdir: falling_back
2026-05-12T16:10:11.165499Z  WARN codex_rollout::list: state db discrepancy during find_thread_path_by_id_str_in_subdir: falling_back
2026-05-12T16:10:11.188488Z  WARN codex_rollout::list: state db discrepancy during find_thread_path_by_id_str_in_subdir: falling_back
2026-05-12T16:10:11.558765Z  WARN codex_core_plugins::manager: failed to warm featured plugin ids cache error=remote plugin sync request to https://chatgpt.com/backend-api/plugins/featured failed with status 403 Forbidden: <html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style global>body{font-family:Arial,Helvetica,sans-serif}.container{align-items:center;display:flex;flex-direction:column;gap:2rem;height:100%;justify-content:center;width:100%}@keyframes enlarge-appear{0%{opacity:0;transform:scale(75%) rotate(-90deg)}to{opacity:1;transform:scale(100%) rotate(0deg)}}.logo{color:#8e8ea0}.scale-appear{animation:enlarge-appear .4s ease-out}@media (min-width:768px){.scale-appear{height:48px;width:48px}}.data:empty{display:none}.data{border-radius:5px;color:#8e8ea0;text-align:center}@media (prefers-color-scheme:dark){body{background-color:#343541}.logo{color:#acacbe}}</style>
  <meta http-equiv="refresh" content="360"></head>
  <body>
    <div class="container">
      <div class="logo">
        <svg
          width="41"
          height="41"
          viewBox="0 0 41 41"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          strokeWidth="2"
          class="scale-appear"
        >
          <path
            d="M37.5324 16.8707C37.9808 15.5241 38.1363 14.0974 37.9886 12.6859C37.8409 11.2744 37.3934 9.91076 36.676 8.68622C35.6126 6.83404 33.9882 5.3676 32.0373 4.4985C30.0864 3.62941 27.9098 3.40259 25.8215 3.85078C24.8796 2.7893 23.7219 1.94125 22.4257 1.36341C21.1295 0.785575 19.7249 0.491269 18.3058 0.500197C16.1708 0.495044 14.0893 1.16803 12.3614 2.42214C10.6335 3.67624 9.34853 5.44666 8.6917 7.47815C7.30085 7.76286 5.98686 8.3414 4.8377 9.17505C3.68854 10.0087 2.73073 11.0782 2.02839 12.312C0.956464 14.1591 0.498905 16.2988 0.721698 18.4228C0.944492 20.5467 1.83612 22.5449 3.268 24.1293C2.81966 25.4759 2.66413 26.9026 2.81182 28.3141C2.95951 29.7256 3.40701 31.0892 4.12437 32.3138C5.18791 34.1659 6.8123 35.6322 8.76321 36.5013C10.7141 37.3704 12.8907 37.5973 14.9789 37.1492C15.9208 38.2107 17.0786 39.0587 18.3747 39.6366C19.6709 40.2144 21.0755 40.5087 22.4946 40.4998C24.6307 40.5054 26.7133 39.8321 28.4418 38.5772C30.1704 37.3223 31.4556 35.5506 32.1119 33.5179C33.5027 33.2332 34.8167 32.6547 35.9659 31.821C37.115 30.9874 38.0728 29.9178 38.7752 28.684C39.8458 26.8371 40.3023 24.6979 40.0789 22.5748C39.8556 20.4517 38.9639 18.4544 37.5324 16.8707ZM22.4978 37.8849C20.7443 37.8874 19.0459 37.2733 17.6994 36.1501C17.7601 36.117 17.8666 36.0586 17.936 36.0161L25.9004 31.4156C26.1003 31.3019 26.2663 31.137 26.3813 30.9378C26.4964 30.7386 26.5563 30.5124 26.5549 30.2825V19.0542L29.9213 20.998C29.9389 21.0068 29.9541 21.0198 29.9656 21.0359C29.977 21.052 29.9842 21.0707 29.9867 21.0902V30.3889C29.9842 32.375 29.1946 34.2791 27.7909 35.6841C26.3872 37.0892 24.4838 37.8806 22.4978 37.8849ZM6.39227 31.0064C5.51397 29.4888 5.19742 27.7107 5.49804 25.9832C5.55718 26.0187 5.66048 26.0818 5.73461 26.1244L13.699 30.7248C13.8975 30.8408 14.1233 30.902 14.3532 30.902C14.583 30.902 14.8088 30.8408 15.0073 30.7248L24.731 25.1103V28.9979C24.7321 29.0177 24.7283 29.0376 24.7199 29.0556C24.7115 29.0736 24.6988 29.0893 24.6829 29.1012L16.6317 33.7497C14.9096 34.7416 12.8643 35.0097 10.9447 34.4954C9.02506 33.9811 7.38785 32.7263 6.39227 31.0064ZM4.29707 13.6194C5.17156 12.0998 6.55279 10.9364 8.19885 10.3327C8.19885 10.4013 8.19491 10.5228 8.19491 10.6071V19.808C8.19351 20.0378 8.25334 20.2638 8.36823 20.4629C8.48312 20.6619 8.64893 20.8267 8.84863 20.9404L18.5723 26.5542L15.206 28.4979C15.1894 28.5089 15.1703 28.5155 15.1505 28.5173C15.1307 28.5191 15.1107 28.516 15.0924 28.5082L7.04046 23.8557C5.32135 22.8601 4.06716 21.2235 3.55289 19.3046C3.03862 17.3858 3.30624 15.3413 4.29707 13.6194ZM31.955 20.0556L22.2312 14.4411L25.5976 12.4981C25.6142 12.4872 25.6333 12.4805 25.6531 12.4787C25.6729 12.4769 25.6928 12.4801 25.7111 12.4879L33.7631 17.1364C34.9967 17.849 36.0017 18.8982 36.6606 20.1613C37.3194 21.4244 37.6047 22.849 37.4832 24.2684C37.3617 25.6878 36.8382 27.0432 35.9743 28.1759C35.1103 29.3086 33.9415 30.1717 32.6047 30.6641C32.6047 30.5947 32.6047 30.4733 32.6047 30.3889V21.188C32.6066 20.9586 32.5474 20.7328 32.4332 20.5338C32.319 20.3348 32.154 20.1698 31.955 20.0556ZM35.3055 15.0128C35.2464 14.9765 35.1431 14.9142 35.069 14.8717L27.1045 10.2712C26.906 10.1554 26.6803 10.0943 26.4504 10.0943C26.2206 10.0943 25.9948 10.1554 25.7963 10.2712L16.0726 15.8858V11.9982C16.0715 11.9783 16.0753 11.9585 16.0837 11.9405C16.0921 11.9225 16.1048 11.9068 16.1207 11.8949L24.1719 7.25025C25.4053 6.53903 26.8158 6.19376 28.2383 6.25482C29.6608 6.31589 31.0364 6.78077 32.2044 7.59508C33.3723 8.40939 34.2842 9.53945 34.8334 10.8531C35.3826 12.1667 35.5464 13.6095 35.3055 15.0128ZM14.2424 21.9419L10.8752 19.9981C10.8576 19.9893 10.8423 19.9763 10.8309 19.9602C10.8195 19.9441 10.8122 19.9254 10.8098 19.9058V10.6071C10.8107 9.18295 11.2173 7.78848 11.9819 6.58696C12.7466 5.38544 13.8377 4.42659 15.1275 3.82264C16.4173 3.21869 17.8524 2.99464 19.2649 3.1767C20.6775 3.35876 22.0089 3.93941 23.1034 4.85067C23.0427 4.88379 22.937 4.94215 22.8668 4.98473L14.9024 9.58517C14.7025 9.69878 14.5366 9.86356 14.4215 10.0626C14.3065 10.2616 14.2466 10.4877 14.2479 10.7175L14.2424 21.9419ZM16.071 17.9991L20.4018 15.4978L24.7325 17.9975V22.9985L20.4018 25.4983L16.071 22.9985V17.9991Z"
            fill="currentColor"
          />
        </svg>
      </div>
      <div class="data"><div class="main-wrapper" role="main"><div class="main-content"><noscript><div class="h2"><span id="challenge-error-text">Enable JavaScript and cookies to continue</span></div></noscript></div></div><script>(function(){window._cf_chl_opt = {cFPWv: 'b',cH: 'HAUQokSH99LZLfmEOs2Hei6iDjzW7QVEZz0nnSwqigs-1778602211-1.2.1.1-1.kmyCs70CHAR1uUStBiAZgiJplFoqYcYM_X6j8y_nXF2hvMVjsJlbPGoi0TfXGV',cITimeS: '1778602211',cRay: '9faab12dbd3c2f74',cTplB: '0',cTplC:1,cTplO:0,cTplV:5,cType: 'managed',cUPMDTk:"/backend-api/plugins/featured?platform=codex&__cf_chl_tk=oyczFKl7qfQNZV_LYjGfC728MqMOJARn.v2_yScJWFQ-1778602211-1.0.1.1-.IjMIa4LZclNsSKFe6xqxvYj2pBgtkAVzbHo1Jt9ynw",cvId: '3',cZone: 'chatgpt.com',fa:"/backend-api/plugins/featured?platform=codex&__cf_chl_f_tk=oyczFKl7qfQNZV_LYjGfC728MqMOJARn.v2_yScJWFQ-1778602211-1.0.1.1-.IjMIa4LZclNsSKFe6xqxvYj2pBgtkAVzbHo1Jt9ynw",md: '1XYnaANC_6uuS_4ix6Ub75TrfdJK26_jm2sdYYIWy7Y-1778602211-1.2.1.1-ptFE2AZmSUCDnotAx9WtXqwVBSlQD8eFPb5bXFEEm55FhpoDHiRv4OT8x07Ibg62ZTYv.T6q3_7LdZ4qP.unBItbZeEE1Fkr11Utr1BSQLbqk97xNmsevFww4.iN59Xkva195rMwCbv9vmVg7wtGv_WsS1OUnlnvCqnaI5HOp_7ql4iH3Q5vNuyxQZomRh_xvuoVL9SBoPfHOp5CSy490ejPh2k5t9NQ2Wtyu1Depgxwm1ytAeCjtExbuNCJcr_SANcmt.uWk9nOsRCKk_8z3klkVZ2UskClrkyWX8gFVYlX9465u3EjD.uO4DRLmLw29PUvwK5WHM3UuqPGy7q40nBGUJf3xuTRoeTTuWSOr0de5b_mAVCZXDo67kQwm_wvTtQ9_xd1WUZzTQSL5yqusoH5l_ZKjK9gGKFtrbdyFflZBMrFD26QsdF1jRm5Mc4O3ZF5i.4FCmHNYynjNySE_0JkpmOE_hKvlaBnUMOel1pF7dILjUrtYJi6.g_UpBdKJB.keviTlWSY5HxGkPX490H7LYFUMYbxUHlcxgqr5gOagn_sl1CD5FujGsrYH.mdMmRXEOaYZ16Qeb2bCvf5c_lwO0xGAmCtSY7GCEoZA2p7ewfozI054BZaWfEvBhNEg77Wdscr2KpdG93qG8fRFSgGNd1m_HMYw9fGMiIHpY9J9L6QliKvOAAKcn6cTLesRfE8GbUx7WyZINh.ogHxgktd5YSTOhkkyWCWBuKy5ywDBajuchvetbFwakRx_rd2Ayfx82m1ZIbllUoYQOv6vXrXIbqg3INgh6K8XRKVsTrmEPdu.sgU5.xyO5Fxnhs2mc5YXUaS1EOWoNeO8Qfi2Fp_eamb15AGGVT9RRrU3JkSjVGWCrK34qlrvv7HRherFySNykHt.ZIh45W4cq.F8IF2.wVVXa_ZeRZzLgZUcxkVBwA8NVukp_zOFhZuCEf52fufelybUod_eqVvA9a3SDMXBmNEZFLSoLT7oGWa7JgLN3uW6ZDCuxJrFy91EPm7',mdrd: 'MRXuyDMckZIQBLdBCnNTwKK_0bMohWKpvOpEmTfiI7A-1778602211-1.2.1.1-Y1xuEYCquwEW_PGpvfWummpxEIx61ycEygRLKdytZ8QUkzQ2T9mW4.xfwuf0jRsrp7rS7lgQUzzmB2LJFeDODOB8nuxNY612jzabL5TjKErOS5_9kba8Iii4OPGUk7vZzjn_KT926BCEC0XLjzAAlvxIQnh6HggOAr5JYxtw3N3KV0YfmuAi_EOL_iDA1.EmwTPhSCb_8hMoa9qt92OHza793XLdbYJSHg069ULsClaBZIukYVI9edGh5D6IaI2LsZDrp8s.EQkqdjpOibAeOl0CUVXlUGyiljj7dvFar7hKy5GO4lI6_44uD6pe7m_R1_7RujZSneIeOe4oXhl1wBk5omiklO.cmOt0CiQduFcXJvBJelSQBOOoGcaIWSJJE7oHWCN32n9TC9GUVVy7vVR_nokQWWdLW3xrWAKtDXRe6CjZXarGZOh4zfdMjiq6RV9c2RW9LzFyoQ_6TzpGc.uO3zuAOucRBabs5uPHMsb9bCYvCaiq43_lF6Xsg90hiEPYG9BBvqf1oEhaJhK4EO3CD72jcUYDqq8F798AAjNmnV5M9enMeOp7haa2wCHOjfhTd7Tf35qkU2vaemHSBThqTKqAlRRO0iuuHPqXhy5HSjSWTTR581x431i952CiIq2RmRnGAR32zAyg9kwBsMdJimm4vCWj4eRra4hnlhBzYKWARydYT.x8lrk6H3U7_diAz0hOx9LZWixfzZ6993dcWO480c13O2r.jvvM2gNjWgbFIPIPwAZ2C6O9Tjqq89KteEo3ORxs4DYZtuzSZb.FgCy8gY0YlAKZlx9zpLBHgtowJpHbwX.CDqdY555HPRYF3.zcHij0f5PSZFpDrJQe8Q3hDu0N0dOu3xZp9kJZTJ.6sUBppEmk0Sjbn7qDktuyIcycewevWvNJj9lovEups1Nz9xmVAskJlrZj2RRq3bBSigVZzWVdaJZNM0lgm7AEYwZ0H.6_dej.I0a_6tpwgczzzmyWblBxTFS7BcQMCSY.KqeC6arAzLNVrJyf7fVywhEH8et906nudLUHgLUffIQ1NaFeT1xvLe6WFjme12bRDzyNAtPBZM2YGPmp_cUbo4c21irxdGW4ZxP.R_z6AGyL9uaPITum8DTICutDt_Btx29oNMUXDD8nDl4ixr5q5r9wzqX9vWfK5NXlCn_g5UFioxDjkSfrncs6nPdr82ItaaeSJ_rbdC9kgteoI5u3uZo7IshPhjpUv1F2TTzdESo5utBKVVXuQmS41UNXIctvVLsjQ13tJOgxNrKwt7akdvYz5q0BgqDNfYY.NZ2Wb5yKkvRfAfmvUR69w_o81vOUd1QqSGOAb.uic0.fTo29ewbnI1a7mciKYsR7hLIeAX2eLr9B7Dou0gR2_m07AGvK1ZUCHPmPKtmyUTAxC8MlVu4_rh0SV7lYoRUdJIh1Xb6tW2_tt4Jl0p.cEKfwwq8AOskisDxOCiOlNx8IrlkgwEM59ft.vUV7RjbnNzPum0J2sqnGzOrd8MBP2gFhAPuRfXpHInJUO_dYfEstsTPNYjr8E.QFDslE25bvm0txhltV7xkGTe2BTvZA9PczKWkIcmPFtW3eE.FaPxxwdTIYdLeik5_f5nnNk.L4ohkXXTIoHVSvczG05h_21oXlKYVKoopdFIk4JZqnWw2qFxwNe57Ib2g4LZT_4wDZ3T69PsdGE7EZE7XwAyS1h6aQiQP7K6ugl9J_YcAGReAdAn2HLhvKDA90fo6VThZ89ctDSKS6IOA0JTqIn6oJ9jMMybcs6jYM6OhckcwpFTOm_kPDAzUPtyq0wSrnsOCqYLuMpYP9AXX9p.mIUq9hGh8O31khlmsNUqRiXwrWKOGh9jXLmntFNyLi1AfTWx5_q5nAjRIaTyU3dDihr25sj.2BOnxcY9L.k0AJAn4PiUIyzmijLLKTGbvhmBpn6l3ViTK78JDONU.gdxgtRvpx0J6lyBFDft9cqU_czlBzw7KLaIMhC9qtGWp_OsV8J8ZViemYLd3ahK5Qptq.DrCnJFNWmFwt2WwfY5QgIjCehwuwEU846ac7H9lIu_HIvKxs.uNEWqWzrAtYr3B8M0u0H_3gvg.wppN8nXezxDpZYo50FWxhxYF0vGU0XwskAo2L18ZUcBIS_mv.19DC4CmDVczO9Ac2uHfaMiUiGoK6K7ha719efhuknY9JiJf7P0xOgbLXWxFnE8gDy9EAFj15xKe5ezSynLb9fp11s6EsjHIsxfQ2UV0XGctB_goKjwRl6errSoCIm5PLacGb9ZHM.AmpQhq2UcvS7keldutoMBBi',};var a = document.createElement('script');a.src = '/cdn-cgi/challenge-platform/h/b/orchestrate/chl_page/v1?ray=9faab12dbd3c2f74';window._cf_chl_opt.cOgUHash = location.hash === '' && location.href.indexOf('#') !== -1 ? '#' : location.hash;window._cf_chl_opt.cOgUQuery = location.search === '' && location.href.slice(0, location.href.length - window._cf_chl_opt.cOgUHash.length).indexOf('?') !== -1 ? '?' : location.search;if (window.history && window.history.replaceState) {var ogU = location.pathname + window._cf_chl_opt.cOgUQuery + window._cf_chl_opt.cOgUHash;history.replaceState(null, null,"/backend-api/plugins/featured?platform=codex&__cf_chl_rt_tk=oyczFKl7qfQNZV_LYjGfC728MqMOJARn.v2_yScJWFQ-1778602211-1.0.1.1-.IjMIa4LZclNsSKFe6xqxvYj2pBgtkAVzbHo1Jt9ynw"+ window._cf_chl_opt.cOgUHash);a.onload = function() {history.replaceState(null, null, ogU);}}document.getElementsByTagName('head')[0].appendChild(a);}());</script></div>
    </div>
  </body>
</html>

2026-05-12T16:10:12.157685Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: prompt must be at most 128 characters path=/Users/lijieli/.codex/.tmp/plugins/plugins/build-ios-apps/.codex-plugin/plugin.json
2026-05-12T16:10:12.159345Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: maximum of 3 prompts is supported path=/Users/lijieli/.codex/.tmp/plugins/plugins/plugin-eval/.codex-plugin/plugin.json
2026-05-12T16:10:12.179393Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: maximum of 3 prompts is supported path=/Users/lijieli/.codex/.tmp/plugins/plugins/twilio-developer-kit/.codex-plugin/plugin.json
2026-05-12T16:10:12.179563Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: maximum of 3 prompts is supported path=/Users/lijieli/.codex/.tmp/plugins/plugins/openai-developers/.codex-plugin/plugin.json
2026-05-12T16:10:14.766818Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: prompt must be at most 128 characters path=/Users/lijieli/.codex/.tmp/plugins/plugins/build-ios-apps/.codex-plugin/plugin.json
2026-05-12T16:10:14.767270Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: maximum of 3 prompts is supported path=/Users/lijieli/.codex/.tmp/plugins/plugins/plugin-eval/.codex-plugin/plugin.json
2026-05-12T16:10:14.770788Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: maximum of 3 prompts is supported path=/Users/lijieli/.codex/.tmp/plugins/plugins/twilio-developer-kit/.codex-plugin/plugin.json
2026-05-12T16:10:14.770839Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: maximum of 3 prompts is supported path=/Users/lijieli/.codex/.tmp/plugins/plugins/openai-developers/.codex-plugin/plugin.json
2026-05-12T16:10:14.790506Z  WARN codex_core_skills::loader: ignoring interface.icon_small: icon path must not contain '..'
2026-05-12T16:10:14.790518Z  WARN codex_core_skills::loader: ignoring interface.icon_large: icon path must not contain '..'
2026-05-12T16:10:14.791276Z  WARN codex_core_skills::loader: ignoring interface.icon_small: icon path must not contain '..'
2026-05-12T16:10:14.791281Z  WARN codex_core_skills::loader: ignoring interface.icon_large: icon path must not contain '..'
2026-05-12T16:10:14.791818Z  WARN codex_core_skills::loader: ignoring interface.icon_small: icon path must not contain '..'
2026-05-12T16:10:14.791823Z  WARN codex_core_skills::loader: ignoring interface.icon_large: icon path must not contain '..'
2026-05-12T16:10:14.792777Z  WARN codex_core_skills::loader: ignoring interface.icon_small: icon path must not contain '..'
2026-05-12T16:10:14.792780Z  WARN codex_core_skills::loader: ignoring interface.icon_large: icon path must not contain '..'
2026-05-12T16:10:14.793486Z  WARN codex_core_skills::loader: ignoring interface.icon_small: icon path must not contain '..'
2026-05-12T16:10:14.793490Z  WARN codex_core_skills::loader: ignoring interface.icon_large: icon path must not contain '..'
2026-05-12T16:10:14.794449Z  WARN codex_core_skills::loader: ignoring interface.icon_small: icon path must not contain '..'
2026-05-12T16:10:14.794451Z  WARN codex_core_skills::loader: ignoring interface.icon_large: icon path must not contain '..'
2026-05-12T16:10:14.847609Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: maximum of 3 prompts is supported path=/Users/lijieli/.codex/.tmp/plugins/plugins/openai-developers/.codex-plugin/plugin.json
2026-05-12T16:10:14.853444Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: maximum of 3 prompts is supported path=/Users/lijieli/.codex/.tmp/plugins/plugins/openai-developers/.codex-plugin/plugin.json
2026-05-12T16:10:14.853568Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: maximum of 3 prompts is supported path=/Users/lijieli/.codex/.tmp/plugins/plugins/openai-developers/.codex-plugin/plugin.json
2026-05-12T16:10:16.974799Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: prompt must be at most 128 characters path=/Users/lijieli/.codex/.tmp/plugins/plugins/build-ios-apps/.codex-plugin/plugin.json
2026-05-12T16:10:16.975177Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: maximum of 3 prompts is supported path=/Users/lijieli/.codex/.tmp/plugins/plugins/plugin-eval/.codex-plugin/plugin.json
2026-05-12T16:10:16.978239Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: maximum of 3 prompts is supported path=/Users/lijieli/.codex/.tmp/plugins/plugins/twilio-developer-kit/.codex-plugin/plugin.json
2026-05-12T16:10:16.978281Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: maximum of 3 prompts is supported path=/Users/lijieli/.codex/.tmp/plugins/plugins/openai-developers/.codex-plugin/plugin.json
2026-05-12T16:10:16.994361Z  WARN codex_core_skills::loader: ignoring interface.icon_small: icon path must not contain '..'
2026-05-12T16:10:16.994373Z  WARN codex_core_skills::loader: ignoring interface.icon_large: icon path must not contain '..'
2026-05-12T16:10:16.994830Z  WARN codex_core_skills::loader: ignoring interface.icon_small: icon path must not contain '..'
2026-05-12T16:10:16.994839Z  WARN codex_core_skills::loader: ignoring interface.icon_large: icon path must not contain '..'
2026-05-12T16:10:16.995342Z  WARN codex_core_skills::loader: ignoring interface.icon_small: icon path must not contain '..'
2026-05-12T16:10:16.995347Z  WARN codex_core_skills::loader: ignoring interface.icon_large: icon path must not contain '..'
2026-05-12T16:10:16.995717Z  WARN codex_core_skills::loader: ignoring interface.icon_small: icon path must not contain '..'
2026-05-12T16:10:16.995722Z  WARN codex_core_skills::loader: ignoring interface.icon_large: icon path must not contain '..'
2026-05-12T16:10:16.996106Z  WARN codex_core_skills::loader: ignoring interface.icon_small: icon path must not contain '..'
2026-05-12T16:10:16.996109Z  WARN codex_core_skills::loader: ignoring interface.icon_large: icon path must not contain '..'
2026-05-12T16:10:16.997051Z  WARN codex_core_skills::loader: ignoring interface.icon_small: icon path must not contain '..'
2026-05-12T16:10:16.997057Z  WARN codex_core_skills::loader: ignoring interface.icon_large: icon path must not contain '..'
2026-05-12T16:10:17.047354Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: maximum of 3 prompts is supported path=/Users/lijieli/.codex/.tmp/plugins/plugins/openai-developers/.codex-plugin/plugin.json
2026-05-12T16:10:17.051842Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: maximum of 3 prompts is supported path=/Users/lijieli/.codex/.tmp/plugins/plugins/openai-developers/.codex-plugin/plugin.json
2026-05-12T16:10:17.051953Z  WARN codex_core_plugins::manifest: ignoring interface.defaultPrompt: maximum of 3 prompts is supported path=/Users/lijieli/.codex/.tmp/plugins/plugins/openai-developers/.codex-plugin/plugin.json
codex
## Response

结论：现在不能判断“值不值得开正式调研”，因为你没有给出具体 `topic`。

按该 skill 的契约，正式调研前必须先确认范围；而你这次只要求“是否值得开正式调研”，且明确禁止写报告/建 docs，所以我会停在**调研准入判断**，不进入 Step 3+ 深度分析，不产出报告。

请补充这 3 个最小信息：

1. `topic` 是什么？
2. 你为什么怀疑它需要调研？例如：技术选型、方案采纳、对象定位、风险审计。
3. 你最关心的 2-4 个判断维度是什么？例如：项目适配度、维护成本、证据链可信度、替代方案、失败边界。

收到后我会只给一个准入结论：

- `建议开正式调研`
- `不建议开正式调研`
- `先做轻量预扫描再决定`

并说明判断依据、风险和下一步，不写报告、不建 `docs`。

## Self Check
- route: research skill, stopped at scope confirmation / triage gate
- mode: unknown until topic provided
- presentation_profile: decision
- artifacts_required: no report or docs for this user task
tokens used
25,123

