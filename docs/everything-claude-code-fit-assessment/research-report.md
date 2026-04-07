# Everything Claude Code 适配性与最佳实践判定调研报告

日期基线：`2026-04-07`
调研对象：`affaan-m/everything-claude-code`、本地 `org-claude-skills`
报告模式：`analysis`

## 一页判断

- 当前结论：**条件推荐**
- 是否符合当前目标：`中`
- 一句话判断：`everything-claude-code` 不是可直接接管我们的“最佳实践内核”，而是一套高信号但高复杂度的 **Claude-first agent harness 样本库**；适合学习其中的能力面分层、选择性安装、分发与兼容层设计，不适合作为我们新的主真源或默认运行时。
- 最大收益：把“什么东西该放 rules / skills / MCP / 脚本 / 分发层”说清楚，并把分发安装做成独立能力，而不是继续揉在运行时真源里。
- 最大风险：被它的体量、stars、跨平台口号和“battle-tested”叙事带偏，把一个高表面积仓库误判成可直接复用的最佳实践。
- 不适用场景：需要小而稳、边界极清晰、强调单一真源和低维护负担的流程治理仓库。
- 结论翻转条件：如果 ECC 后续收敛出一层稳定、可审计、与实际 OSS surface 一致的 canonical core，并补齐对关键实践的评估证据与跨平台等价性证明，则它的“可直接复用度”会上升。

## 关键论点挑战表

| 对象/论点 | 最强支持证据 | 最强反方挑战 | 当前判断 | 结论稳健性 |
|-----------|-------------|-------------|---------|-----------|
| ECC 本身就是最佳实践 authority | 仓库热度高、更新活跃、覆盖面广、维护者持续迭代 `skills-first` 和 selective install | README、插件 manifest、release 文案与实际文件数量存在明显漂移；仓库同时承载 alpha、legacy shim、实验与广泛业务域，不能等价为稳定 canonical | **不成立** | 高 |
| ECC 的能力面分层与 surface selection 值得学习 | `docs/capability-surface-selection.md`、`docs/SKILL-PLACEMENT-POLICY.md`、`docs/SELECTIVE-INSTALL-ARCHITECTURE.md` 把放置边界、安装层和 provenance 讲清了 | 仓库执行层仍有漂移，说明“有文档”不等于“已完全治理到位” | **成立** | 中高 |
| ECC 的 continuous learning / instinct / hook observer 是最佳实践 | 它试图解决跨会话学习、项目作用域隔离和模式提炼问题 | 强依赖 Claude hooks 与 home 目录状态，复杂度高、噪音高、跨平台等价性弱，且缺少对学习质量的公开强证据 | **待验证** | 中低 |
| ECC 可以作为我们的新主真源或默认运行时 | 它确实覆盖 Claude、Codex、Cursor、OpenCode 等多个 harness，并已有 install/profile 架构 | 我们当前仓库目标是 `shared/community/contracts/tests` 约束下的跨端统一真源，不是插件产品仓；引入 ECC runtime 会冲掉现有边界合同 | **不成立** | 高 |
| 我们当前体系已接近最佳实践，无需反向修正 | 当前仓库在 source lock、boundary contract、single source of truth、community vendoring 上比 ECC 更克制也更清晰 | 我们自己的草稿已经明确指出 research 流程仍有双轨漂移和 `rigor theater` 风险；当前确认门槛和层级数量也偏高 | **部分成立** | 中 |

## 优缺点速览

| 对象/论点 | 核心优势 | 核心短板 | 适用场景 | 不适用场景 |
|-----------|---------|---------|---------|-----------|
| ECC 能力面分层 | 把 rules / skills / MCP / CLI / API 的边界讲得很清楚 | 仓库本体表面积过大，落地时容易带入多余复杂度 | 做分发层、安装层、导出层设计 | 追求极小运行面的流程仓 |
| ECC selective install / provenance | 安装模块、profile、curated vs generated 边界清楚 | 更偏产品化分发仓，不是轻量规范仓 | 想把仓库做成可发布产品 | 只需要 repo 内真源与少量安装脚本 |
| ECC skills-first + legacy shim 策略 | 清楚地区分 canonical surface 与兼容入口 | 兼容层长期存在会带来文档和计数漂移 | 正在从旧入口迁移到新入口的系统 | 不需要兼容层的纯净仓库 |
| ECC continuous learning / instinct | 对“长期复用个人经验”的问题有想象力 | 复杂、Claude-first、observer 噪音与维护成本高 | 个人长期重度使用同一 harness | 多运行时统一仓、重视可审计和低侵入 |
| 本地 org-claude-skills | source lock、community vendoring、boundary contract、small-chain 明确 | 层级多、活跃与历史资产并存，research 与确认流程仍偏重 | 需要强治理、强边界、跨端统一真源 | 需要直接产品化分发、快速自助安装的用户型仓库 |

## 独立挑战记录

| 挑战点 | challenger 质疑 | 原结论回应 | 是否调整 |
|--------|----------------|-----------|---------|
| 权威崇拜 | “高 star + hackathon winner” 只是传播强，不是方法强 | 结论里明确降级 ECC 为高信号样本库，而不是 authority | 是 |
| 治理成本低估 | 如果吸收 ECC，可能把插件产品仓的复杂度带进流程治理仓 | 只吸收能力面分层和 selective install 思路，不引入其 runtime 主体 | 是 |
| 过程偏执 | 我们批评 ECC 复杂，但本地仓库自己也有流程表演风险 | 报告增加“本地不合理/非最佳实践”专节，双向审视 | 是 |
| 跨平台口号误判 | “支持多 harness” 不等于行为等价 | 结论里把 export/adaptation 与 canonical truth 分开，拒绝把兼容层当真源 | 是 |

## 采纳速览

- 现在该做什么：`小范围试点`
- 采纳前必须补的验证：
  - 设计一份本仓库版 “能力面选择指南”，验证是否能减少新增内容时的放置争议
  - 做一轮 “selective export / install profile” 设计草案，验证能否在不破坏真源的前提下改善分发
  - 用 3 个真实任务验证：放宽 read-only research 的确认门槛后，质量是否下降，效率是否上升
- 最匹配的点：我们也在做跨端资产治理，ECC 在安装、分发、surface placement 上经验丰富
- 最不匹配的点：ECC 是大而全产品仓，我们是强调边界合同和单真源的流程治理仓

## 调研背景

- 调研触发：用户希望判断朋友分享的 `everything-claude-code` 是否适合当前体系，哪些做法可吸收，以及“最佳实践”到底是什么
- 决策目标：形成 `保留 / 优化 / 放弃 / 试点` 的行动结论，并找出本地体系中不合理或未达最佳实践的地方
- 关键约束：
  - 当前仓库的主目标是 Claude / Codex 双端统一真源，不是单一平台插件仓
  - 现行默认链路已收口为 `small-chain`
  - 不能把“官方/热门/大而全”直接当作最佳实践

## 检索路径与覆盖证明

- 名称归一化：
  - `everything-claude-code`
  - `ECC`
  - `affaan-m/everything-claude-code`
- 已查对象类型：
  - GitHub 仓库
  - README / docs / plugin manifest / adapter / command / skill 文件
  - 官方 Anthropic 文档
  - 本地既有 research / design / boundary docs
- 已查 discovery 入口：
  - GitHub 仓库主页与 tarball 快照
  - GitHub API 仓库元数据与最近提交
  - 本地仓库 `README`、`contracts`、`shared/reference`、既有 `research-report`
- 已排除候选：
  - 仓库 fork 与社交媒体宣传帖，不作为本次结论主体证据
  - 未逐个审计 181 个 skill，因此不对单个 skill 的质量做总体背书
- 剩余盲区：
  - GitHub Issues API 读取受限，未系统抽样 open issues
  - 未获取维护者口述设计动机
  - 未对 continuous learning / instinct 系统做真实长周期运行实验

## 项目上下文

- 技术栈：当前仓库是一个维护 `skills / rules / reference / hooks / agents` 的跨 Claude / Codex 运行资产仓，核心真源在 `shared/` 与 `community/`
- 已有相关实现：
  - `shared/assistant.md` 定义默认入口、优先级与 reference 触发映射
  - `docs/small-chain/README.md` 与 `docs/small-chain/boundary-contract.md` 定义默认链路与工件真源
  - `community/SOURCES.yaml` 锁定 upstream 来源
  - `shared/reference/Skill质量标准.md` 已把 skill 质量维度、token 效率和跨模型要求制度化
- 约束条件：
  - `tasks.md` 是唯一完成状态真源
  - OpenSpec 只保留概念来源，不作为运行时依赖
  - 当前仓库更像治理壳与安装壳，不是大而全插件产品仓

## 拆解对象概览

- 对象类型：`项目方法 + 插件仓 + agent harness 资产仓`
- 原始观点：ECC 自我定位为 “AI agent harness performance optimization system”，主张 skills、instincts、memory optimization、continuous learning、security scanning、research-first development 和 cross-harness support
- 需要回答的问题：
  - 它哪些论点成立
  - 它哪些做法适合当前仓库
  - 它暴露了哪些我们也该避免的误区
  - 我们当前体系哪里还没有达到最佳实践

## 什么才算这里的“最佳实践”

本次不把“最佳实践”定义成最流行、最复杂或最完整，而定义成：

1. **真实提升结果质量**
   - 能降低误判、返工、漂移、遗漏，而不只是让文档更厚
2. **证据可追溯**
   - 关键判断能回到具体文件、规则、脚本、测试或官方文档
3. **负担与收益匹配**
   - 额外增加的流程、文档、hook、适配层，必须带来能观察到的质量收益
4. **边界清楚**
   - 知道什么属于真源、什么属于 adapter、什么属于兼容层、什么只是分发层
5. **可演化而不失控**
   - 新能力加入后不会迅速演变成双重真源、计数漂移、兼容层污染
6. **绑定当前目标**
   - 对插件产品仓成立的最佳实践，不一定对治理型真源仓成立

不是最佳实践的常见伪信号：

- stars 很高
- 文档很多
- 规则更严格
- surface 更多
- 引入更多 agent / hook / memory / observer
- “battle-tested” 但缺少具体评估路径和失败边界

## 核心论点拆解

## 论点 1：ECC 最有价值的不是“大而全”，而是能力面分层

### 核心机制

- 解决什么问题：避免把规则、工作流、脚本、MCP、API 集成和分发逻辑混成一个大 prompt 包
- 怎么解决：ECC 专门写了 `docs/capability-surface-selection.md`，按“规则是否总是触发、是否需要按需加载、是否需要长生命周期 server、是否只是一次性本地脚本”来决定放到哪一层
- 适用边界：适用于正在变成多运行时、多安装面、多适配层的仓库；不适用于极小型、没有分发需求的单项目仓库

### 证据分层

- A 级证据：
  - `docs/capability-surface-selection.md`
  - `docs/SKILL-PLACEMENT-POLICY.md`
  - `docs/SELECTIVE-INSTALL-ARCHITECTURE.md`
- B 级证据：
  - README 中的 skills-first / legacy command shim 说明
  - `.claude-plugin/plugin.json`、`.codex-plugin/plugin.json`
- 证据冲突：
  - 文档表达的“surface 很清楚”与实际 repo 的高表面积、计数漂移并存，说明理念是对的，执行尚未完全收敛

### 正反论证

- 最强支持证据：ECC 已经把 `rules / skills / MCP / CLI / API` 的选择顺序写成独立文档，而不是让维护者凭感觉决定
- 最强反方挑战：仓库本体仍同时承载 legacy command shim、alpha ECC2、各类 operator skill 与多平台适配，说明清晰边界不自动等于低复杂度
- 反例/失败案例：若团队把每种能力都包装成“skill + command + hook + agent + adapter”，分层会倒退成重复表面积

### 深层分析

- 设计哲学：把“能力归位”放在“能力增量”之前，先问放在哪里，再问写什么
- 关键取舍：接受更多显式文档和模块，换取更低的长期放置歧义
- 演进方向：最近提交继续补 `capability-surface-selection`、`skill adaptation policy`、ECC2 alpha 等说明文档，表明维护者也在持续收敛边界

### 项目适配评估

- 最匹配的点：我们当前也有 `rules / reference / skills / contracts / tests / adapters` 多层结构，但缺少一份统一“放哪里”的判断指南
- 最不匹配的点：ECC 的文档是围绕插件产品仓写的，我们需要的是更偏“真源治理”的版本
- 采纳成本：中
- 退出成本：低

### 当前判断

- 判定：**成立**
- 结论稳健性：`中高`，因为理念有强文档支撑，且与本地痛点直接匹配
- 失效边界：如果我们后续决定只做极小型内部仓，不做跨平台安装和导出，这套分层收益会下降
- 待验证项：先写一份本仓库版 surface selection draft，验证是否能减少新增内容的争议与漂移

## 论点 2：ECC 在 selective install、分发层与 provenance 上比我们成熟

### 核心机制

- 解决什么问题：让“真源内容”和“安装导出内容”分离，避免一套仓库只能全量安装、难以按平台和场景裁剪
- 怎么解决：用 install manifests、profiles、module resolution、install-state 和 curated / learned / imported / evolved 的 provenance policy 把“什么可发布、什么只本地存在”区分开
- 适用边界：适用于想从 repo 演进成产品化分发面的仓库

### 证据分层

- A 级证据：
  - `docs/SELECTIVE-INSTALL-ARCHITECTURE.md`
  - `docs/SKILL-PLACEMENT-POLICY.md`
  - `manifests/`、`schemas/`、`scripts/install-*`
- B 级证据：
  - README 的 profile / install 说明
  - `.claude-plugin` / `.codex-plugin`
- 证据冲突：
  - `README` 与 plugin manifest 中的 catalog counts 不一致，说明分发层本身也有元数据同步风险

### 正反论证

- 最强支持证据：ECC 已把 selective install 当作架构问题来写，而不是 shell 脚本小技巧
- 最强反方挑战：分发层复杂度本身不低，如果主仓库目标不是对外产品化，可能会过度设计
- 反例/失败案例：若只有极少数固定安装目标，profile/module 体系可能只是增加维护负担

### 深层分析

- 设计哲学：source truth 与 install truth 分离；安装是编排与投影，不是内容本体
- 关键取舍：接受 manifest / schema / lifecycle 工程化复杂度，换取更高的可发布性和可回滚性
- 演进方向：ECC2 明显想继续把控制平面和安装生命周期做强

### 项目适配评估

- 最匹配的点：我们目前的强项是 source lock 和 boundary contract，弱项是 export / install profile / selective distribution
- 最不匹配的点：我们当前用户主要还是 repo 维护者，不是大量自助安装用户
- 采纳成本：中
- 退出成本：中

### 当前判断

- 判定：**部分成立**
- 结论稳健性：`中`
- 失效边界：如果我们不准备做产品化分发或 selective export，这套能力优先级会下降
- 待验证项：做一版只读设计，不立刻实现，先验证 `shared/community/adapter` 能否自然映射成 install profiles

## 论点 3：ECC 的 token / context / subagent 思路有真价值，但不该照搬成固定配方

### 核心机制

- 解决什么问题：长会话、多文件探索、高输出任务会污染主上下文
- 怎么解决：通过 progressive disclosure、strategic compact、subagent 隔离高输出操作、skills-first canonical surface 来控制上下文负担
- 适用边界：长 session、重探索、跨多个工具/文件的工作

### 证据分层

- A 级证据：
  - `docs/token-optimization.md`
  - `skills/strategic-compact/SKILL.md`
  - 官方 Agent Skills best practices 和 Claude Code subagents 文档
- B 级证据：
  - README 对 token optimization / parallelization 的强调
- 证据冲突：
  - 一些具体参数建议是经验值，不是官方硬标准

### 正反论证

- 最强支持证据：官方文档明确支持 progressive disclosure 和用 subagent 隔离高输出操作
- 最强反方挑战：ECC 给出的部分固定设置是经验型建议，不能未经验证地当作最佳默认值
- 反例/失败案例：如果把 context budget、compact 阈值、subagent 模型设置当万能配方，可能在不同任务形状下适得其反

### 深层分析

- 设计哲学：上下文是稀缺资源，应把“谁读大量内容”和“谁返回摘要”分开
- 关键取舍：更高的 orchestration 复杂度，换更低的主线程污染
- 演进方向：ECC 继续向 harness optimizer、context budgeting、multi-agent orchestration 收敛

### 项目适配评估

- 最匹配的点：我们当前 research、review、scan 都是高上下文任务，最适合吸收“重输出隔离”原则
- 最不匹配的点：我们不应把某个模型设置或 compact 阈值直接制度化
- 采纳成本：低
- 退出成本：低

### 当前判断

- 判定：**成立**
- 结论稳健性：`高`
- 失效边界：如果未来上下文成本不再是主要瓶颈，这条原则价值会下降，但短期内不太可能
- 待验证项：把这条原则写成本仓库的 research / review / multi-agent 使用建议，而不是参数手册

## 论点 4：ECC 的 continuous learning / instinct 体系不应被当作当前优先级最高的最佳实践

### 核心机制

- 解决什么问题：把用户纠偏、重复操作和跨 session 经验积累成可复用资产
- 怎么解决：依赖 hooks 捕获观察、后台分析、confidence scoring、project-scoped instincts，再演化为 skill / command / agent
- 适用边界：长期在同一 harness、高频个人使用、能接受额外 home 目录状态和 hook 运行面

### 证据分层

- A 级证据：
  - `skills/continuous-learning-v2/SKILL.md`
  - `docs/continuous-learning-v2-spec.md`
  - `hooks/README.md`
- B 级证据：
  - README 中关于 instinct、/evolve、/projects 等说明
- 证据冲突：
  - 仓库对“能学习什么”写得多，对“学习质量如何评估、误学如何纠偏”公开证据相对少

### 正反论证

- 最强支持证据：它很认真地处理了 project scope、global scope 和 cross-project contamination
- 最强反方挑战：这条链路高度依赖 Claude hooks、home 目录持久状态、observer 可靠性与隐私/噪音管理，不是轻量级能力
- 反例/失败案例：如果观察样本质量差、项目识别错误、用户并不长期留在同一 harness，系统会学错、学噪、学不稳

### 深层分析

- 设计哲学：把“经验”从聊天历史中抽离成结构化、渐进演化的资产
- 关键取舍：引入强状态和后台自动化，以换取长期复用收益
- 演进方向：当前仍是 v2.x 演进期，而不是已收敛的稳定范式

### 项目适配评估

- 最匹配的点：如果未来我们真的转向“个人长期使用型 agent 工作台产品”，这条线有探索价值
- 最不匹配的点：当前仓库核心任务是治理真源和运行边界，不是做持久学习系统
- 采纳成本：高
- 退出成本：高

### 当前判断

- 判定：**待验证**
- 结论稳健性：`中低`
- 失效边界：若后续出现清晰的学习效果评估、误学回滚机制和跨 harness 的等价实现，则判断可能上调
- 待验证项：不要先落地；如要验证，只做隔离 PoC，不进入默认运行面

## 论点 5：ECC 不能被直接等同为“最佳实践”，因为它自己的治理也在持续收敛

### 核心机制

- 解决什么问题：这个论点不是说 ECC 无价值，而是判断它能否充当 authority
- 怎么解决：看它是否具有稳定 canonical surface、元数据一致性、低漂移和清晰边界
- 适用边界：适用于判断“能不能直接拿来当标准”

### 证据分层

- A 级证据：
  - `README.md` 同时出现 `38/156/72` 与 `47/181/79` 两套 surface counts
  - `.claude-plugin/plugin.json` 仍写 `38 agents, 156 skills, 72 legacy command shims`
  - `WORKING-CONTEXT.md` 持续记录 overlap cleanup、legacy shim、direct-port / reject 政策
  - `commands/orchestrate.md` 仍属 legacy shim，且正文已出现明显兼容/拼接负担
- B 级证据：
  - GitHub 仓库活跃度和频繁 release/docs 提交
- 证据冲突：
  - 仓库活跃和仓库稳定不是同一件事；高活跃可能说明在持续改进，也可能说明尚未稳定

### 正反论证

- 最强支持证据：ECC 的活跃维护、丰富表面和大规模使用，说明它不是空想仓库
- 最强反方挑战：它仍在同时清理 overlap、关闭不合格 PR、同步 counts、保留 legacy shim，说明“成熟度”是分区域成立，不是整体成立；并且当前 `181` 个 skill 中按目录统计只有 `5` 个带 `scripts/`、`1` 个带 `tests/`，大多数仍是知识包而不是强实现资产
- 反例/失败案例：如果我们把这样一个仍在高频收口中的广域仓直接当标准，容易继承它的复杂性而不是它的经验

### 深层分析

- 设计哲学：ECC 更像一套不断扩张和再治理的产品体系，而不是天然克制的小真源仓
- 关键取舍：为了覆盖面、适配面和产品化能力，接受高表面积和持续治理压力
- 演进方向：维护者也在强化 “skills-first、直接移植清理、只保留 ECC-native surfaces”

### 项目适配评估

- 最匹配的点：适合作为“有哪些坑会出现”的前车之鉴
- 最不匹配的点：不适合作为当前仓库的 canonical blueprint
- 采纳成本：低
- 退出成本：低

### 当前判断

- 判定：**不成立**
- 结论稳健性：`高`
- 失效边界：如果 ECC 后续明显收敛为稳定 core + 清晰 compatibility surfaces，可重新评估
- 待验证项：后续只对其特定子系统再做专题研究，不再把整个仓库打包成“最佳实践”

## 论点挑战总表

| 论点 | 最强支持证据 | 最强反方挑战 | 当前判定 | 对我们的启示 |
|------|-------------|-------------|---------|-------------|
| 大而全仓库天然代表最佳实践 | 覆盖面广，问题域丰富 | 漂移、兼容层、alpha 面、legacy 面会一起放大 | 不成立 | 拒绝权威崇拜 |
| 能力面选择与分发层分离是好做法 | 有清晰文档与 install 架构 | 理念正确不等于 repo 已完全收敛 | 成立 | 值得直接吸收 |
| hook + instinct + memory 自动学习值得优先引入 | 解决长期经验沉淀 | 成本高、Claude-first、评估弱 | 待验证 | 不作为当前优先级 |
| 我们当前体系已经够好了 | 边界和真源比 ECC 更清楚 | research 流程、确认门槛、历史资产隔离仍未收敛 | 部分成立 | 需要反向修正本地短板 |

## 本地体系中不合理或未达最佳实践的地方

### 已证实问题

1. **~~活跃链路文档存在事实漂移。~~（已修复，2026-04-07）**
   - ~~[README](../../README.md) 当前仍把 `small-chain` 写成 6 步链路，只列到 `verify-change -> archive`。~~
   - ~~[docs/small-chain/README.md](../small-chain/README.md) 与 [docs/small-chain/boundary-contract.md](../small-chain/boundary-contract.md) 明确链路实际上包含 `verification-before-completion` 与 `finishing-a-development-branch`，总计 8 步。~~
   - ~~对一个以 contract 和运行面文档为真源的仓库，这不是”说明写法差异”，而是会直接影响代理和维护者判断的活跃缺陷。~~
   - **修复记录**：README.md 和 docs/small-chain/README.md 已更新为 9 步（含 using-superpowers），与 contracts/small-chain.yaml 一致。

2. **research 流程尚未完全收敛。**
   - 我们自己的设计草稿已明确承认 `selection / analysis` 收敛后，旧模板仍留存，存在双轨漂移和 `rigor theater` 风险。
   - 这说明当前 research 体系方向正确，但还不能自称最佳实践完成态。

3. **确认门槛对 read-only research 过重。**
   - `shared/assistant.md` 与默认 `brainstorming` 入口要求“执行前复述理解 + AskUserQuestion 确认后再动手”，适合变更性工作，但对只读研究和 challenger 线也一体适用时，容易造成吞吐下降。
   - 本次调研实测中，挑战线 agent 就被确认门槛卡住，主代理需要中断接管。

4. **first-party skill 标准与实际状态没有闭环。**
   - [shared/reference/Skill质量标准.md](../../shared/reference/Skill质量标准.md) 把 `<150 行` 设为 L1/L2 的长度基线。
   - 但当前 [shared/skills/product/SKILL.md](../../shared/skills/product/SKILL.md)、[shared/skills/design/SKILL.md](../../shared/skills/design/SKILL.md)、[shared/skills/project-manager/SKILL.md](../../shared/skills/project-manager/SKILL.md) 实测约为 `230 / 226 / 193` 行。
   - 如果这些文件应该豁免，仓库缺的是显式豁免机制；如果不该豁免，缺的是标准落地门禁。两者都说明“标准—实现—校验”还没闭环。

5. **缺少一份统一的“能力放置决策”文档。**
   - 当前仓库有 `rules / reference / skills / contracts / docs / adapters` 多层，但没有像 ECC 那样明确回答“新增一个约束/工作流/适配逻辑时，到底该放哪一层”。
   - 这会增加维护者对放置边界的解释成本。

6. **~~OpenSpec 虽已退出运行时，但历史资产仍然显眼。~~（已修复，2026-04-07）**
   - ~~README 与 boundary contract 已明确 OpenSpec 只保留概念来源，但顶层 `openspec/` 下仍有多份 draft / plan。~~
   - ~~这保留了历史价值，但也提高了新维护者误读”这是不是仍在活跃主链”的概率。~~
   - **修复记录**：`openspec/` 已整目录归档至 `docs/archive/openspec/`，boundary.yaml 中角色标记为 archived。

### 高风险假说

1. **first-party skill 标准可能对作者体验偏重。**
   - `shared/reference/Skill质量标准.md` 中的 `<150 行`、固定五大节、L2/L3 约束对于 first-party discipline 有价值，但如果被误当作所有 skill 的普适最佳实践，可能会把“结构合规”抬得高于“任务适配”。

2. **默认从 `brainstorming` 进入的策略对研究型任务可能过宽。**
   - 对需要设计的变更任务，这条链是对的；对本次这种系统研究，若仍先套完整 brainstorming 纪律，会增加额外交互成本。

### 仍需验证

1. 我们当前 small-chain 的真实效率，是否已经优于更轻的 research / review 变体
2. L3 skill 质量中的评估场景与跨模型测试，是否已在 repo 级形成统一验证机制
3. 如果放宽 read-only task 的确认门槛，是否会明显降低结果质量

## 吸收建议

### 可以直接吸收

| 论点/做法 | 适用条件 | 如何吸收 |
|-----------|---------|---------|
| 能力面选择指南 | 新增内容时经常纠结该放哪层 | 写一本 `rules vs reference vs skills vs contracts vs adapter/export` 决策文档 |
| selective export / install 思维 | 未来要提升安装与分发体验 | 先做设计，不动真源；把 export 当投影层 |
| progressive disclosure + 高输出隔离 | research / review / scan 任务上下文很重 | 强化“重输出交给 subagent / 脚本，主线程只收摘要” |
| canonical surface 与 legacy shim 分离 | 若未来出现兼容入口 | 明确 canonical lane，所有 shim 显式标注 legacy |

### 改写后吸收

| 原始说法 | 改写后的做法 | 改写原因 |
|---------|-------------|---------|
| Agent-first | 高输出、并行、独立 sidecar 任务优先 agent；不是一切都先 delegate | blanket delegation 会放大复杂度 |
| Hooks everywhere | 只在确定性、低误报、能机械执行的检查上用 hooks | 我们更重边界治理，不能让 hooks 取代判断 |
| Continuous learning / instincts | 仅保留“经验应沉淀为资产”的原则，不引入 observer runtime | 当前不适合引入高状态学习系统 |
| Cross-harness parity | 分清 canonical truth 与 platform adapter / export layer | 支持多个 harness 不等于同一真源表达 |

### 不采纳

| 论点/做法 | 不采纳理由 |
|-----------|-----------|
| 把 ECC 整套当作我们的主运行时 | 与当前单真源和 boundary contract 目标冲突 |
| 默认引入 instinct / continuous-learning 体系 | 复杂度、平台依赖和评估不足都过高 |
| 用大规模 legacy command shim 维持兼容 | 会放大漂移和文档污染 |
| 把热度、活跃度、官方色彩当结论依据 | 不符合本次“反权威、证据优先”的判断原则 |

## 落地行动项

- `P0` 写一份本仓库版“能力面选择指南”，明确 `rules / reference / skills / contracts / tests / adapter/export` 的归位规则
- ~~`P0` 修正 `README.md` 对 active `small-chain` 的描述，使其与 `docs/small-chain/README.md` 和 boundary contract 一致~~ ✓ 已修复（2026-04-07）：README 和 small-chain README 已更新为 9 步
- ~~`P0` 调整 read-only research / challenger 类任务的确认策略：预先确认范围后，允许 agent 直接并行调研，避免被重复 AskUserQuestion 卡住~~ ✓ 已修复（2026-04-07）：research SKILL.md 流程从 9 步压缩为 7 步，预扫描在等待确认期间并行启动
- ~~`P0` 决定 `shared/reference/Skill质量标准.md` 的 `<150 行` 是硬门槛还是可豁免规则；然后为超线 first-party skill 选择”拆分”或”显式豁免 + 校验”~~ ✓ 已修复（2026-04-07）：引入按 skill 类型分档的行数基线（Pipeline <=250, 独立 <=150, 工具 <=100）
- `P1` 产出一版 selective export / install profile 设计草案，只设计不落地，验证是否适合当前仓库未来分发面
- ~~`P1` 给 `openspec/` 补更强的历史/非运行时标识，或按主题继续归档，降低误读概率~~ ✓ 已修复（2026-04-07）：openspec/ 整目录归档至 docs/archive/openspec/
- `P2` 为 first-party skill 建 3 个真实评估场景模板，把“最佳实践”从文档标准推进到最小 eval 标准

## 证据索引

- `E1` 本地仓库 README：`README.md`
- `E2` 本地统一入口合同：`shared/assistant.md`
- `E3` 本地 small-chain 说明：`docs/small-chain/README.md`
- `E4` 本地 small-chain boundary：`docs/small-chain/boundary-contract.md`
- `E5` 本地 source lock：`community/SOURCES.yaml`
- `E6` 本地 skill 质量标准：`shared/reference/Skill质量标准.md`
- `E7` 本地 research rubric draft：`docs/archive/openspec/designs/2026-03-28-research-review-rubric-draft.md`（已归档）
- `E8` ECC README：`/tmp/ecc-src/README.md`
- `E9` ECC capability surface 指南：`/tmp/ecc-src/docs/capability-surface-selection.md`
- `E10` ECC skill placement/provenance：`/tmp/ecc-src/docs/SKILL-PLACEMENT-POLICY.md`
- `E11` ECC selective install：`/tmp/ecc-src/docs/SELECTIVE-INSTALL-ARCHITECTURE.md`
- `E12` ECC token / context：`/tmp/ecc-src/docs/token-optimization.md`
- `E13` ECC continuous learning：`/tmp/ecc-src/skills/continuous-learning-v2/SKILL.md`
- `E14` ECC hooks：`/tmp/ecc-src/hooks/README.md`
- `E15` ECC plugin metadata：`/tmp/ecc-src/.claude-plugin/plugin.json`
- `E16` ECC working context：`/tmp/ecc-src/WORKING-CONTEXT.md`
- `E17` ECC legacy command shim：`/tmp/ecc-src/commands/orchestrate.md`
- `E18` ECC skill 目录统计：当前 `181` 个 skill 中 `5` 个带 `scripts/`、`1` 个带 `tests/`
- `E19` 官方 Agent Skills best practices：<https://platform.claude.com/docs/zh-CN/agents-and-tools/agent-skills/best-practices>
- `E20` 官方 Claude Code subagents 文档：<https://code.claude.com/docs/en/sub-agents>
- `E21` 官方 Claude Code memory / rules 文档：<https://code.claude.com/docs/en/memory>
- `E22` 仓库主页：<https://github.com/affaan-m/everything-claude-code>
