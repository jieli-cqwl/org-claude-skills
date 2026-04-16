# Skills 技能系统课程信息沉淀

## 文档定位

本文件沉淀极客时间「Skills 技能系统」7 讲对 `skill-optimizer` 的二次方法论抽象。它不是课程原文、逐字笔记或知识库搬运，而是用于后续 `design.md` 复审、实施追踪、eval 设计和证据校验的 source map。

课程来源：https://time.geekbang.org/column/article/945937

本文件先服务 LLM 稳定执行，再服务人类阅读。写法优先满足四个目标：

- 让后续 LLM 知道每条结论来自课程、本仓库、官方工具还是本次综合推断。
- 让 `design.md` 的关键结论能追溯到具体 source marker、适用边界和验证方式。
- 防止把课程案例归纳、本地规则、官方工具约束和主线程推断混成同一类权威。
- 先把课程 source map 做扎实，再反向审查 `design.md`；在本文件验收前，不继续强化 `design.md`。

课程正文不进入本仓库。source marker 只表示课程定位和证据类别，不承载原文。

## 证据模型

| 标记 | 来源 | 可进入的规范强度 |
| --- | --- | --- |
| C09-C14 | 课程 09 至 14 讲正文、案例、思考题、作者回复、评论补充 | 可作为 E1/E2 来源 |
| C99 | 加餐总结正文、练习提示、作者回复、评论补充 | 可作为 E1/E2 来源 |
| L | 本仓库 rules/reference/既有 Skill 治理约束 | 可作为 E3 来源 |
| O | 官方 `skill-creator` 或 Skill anatomy 约束 | 可作为 E4 来源 |
| S | 本次主线程和 agent team 综合推断 | 只能作为 E5 来源，需实验支撑 |

课程证据继续细分为：

| 证据类别 | 含义 | 使用边界 |
| --- | --- | --- |
| body | 课程正文明确表达 | 可作为 E1 候选 |
| case | 课程项目或示例归纳 | 可作为 E2 模式 |
| exercise | 思考题或练习方向 | 可作为 eval/练习输入 |
| reply | 作者回复或课程互动 | 可作为补充证据，不单独硬化 |
| comment | 学员评论与讨论 | 只作为风险提示或问题来源 |

规范强度遵守以下规则：

- E3 或 E1+本仓库验证，才可写成硬门禁。
- E1/E2 可写成默认路径、审计维度或建议规则。
- E5 只写成本地假设、试点设计或实验项。
- 课程未覆盖的内容，不能用“课程支持”表达。
- 每个“必须、禁止、至少、不得”都需要绑定 E3，或绑定 E1 与本仓库验证方式。

## 七讲 Source Map

| source | 课程定位 | 核心方法论域 | 关键矩阵 |
| --- | --- | --- | --- |
| C09 | 09｜触类旁通：SKILL.md 结构与触发机制 | 触发、可操作知识、frontmatter、Skill/Tools/SubAgent/Hooks 边界 | 触发与访问矩阵、frontmatter 矩阵 |
| C10 | 10｜令行禁止：任务型 Skills（斜杠命令 /Command）实战 | manual-only、参数、`!command`、allowed-tools、hooks、失败路径 | 任务入口矩阵、权限矩阵、hook 矩阵 |
| C11 | 11｜循序渐进：渐进式披露架构设计 | 三层加载、Quick Reference、资源路由、上下文预算 | 渐进加载矩阵、资源目录矩阵、契约式引用矩阵 |
| C12 | 12｜珠联璧合：Skills 与 SubAgent 配合实战 | Skill 与 SubAgent 两种组合、`context: fork`、全量预加载、pipeline | fork 矩阵、SubAgent 组合矩阵、handoff 矩阵 |
| C13 | 13｜纲举目张：Skills 架构定位与高级能力 | 知识层、模板驱动、脚本增强、知识分层、工具隔离、成熟度 | 模式选择矩阵、成熟度矩阵、脚本/模板矩阵 |
| C14 | 14｜星火燎原：从 Claude Code 到行业开放标准 | 声明式、自包含、可迁移、分发发现、Push/Pull | 跨平台矩阵、Push/Pull 矩阵、分发矩阵 |
| C99 | 加餐｜Skills 专题总结 | 完整 Skill 包、5/10/30 可用性、复用、评估、练习 | 可用性矩阵、eval 矩阵、复用矩阵 |

## 逐讲方法论

### C09：结构、触发与可操作知识

课程明确结论：

- Skill 是语义触发的能力包，不是静态文档集合。
- `description` 是第一层运行时路由契约，承担触发判断，不是简介。
- 好的 `description` 需要表达能力、做法、适用场景和边界。
- Skill 可同时存在自动触发和手动触发形态，但要用字段和权限表达清楚。
- Tools、SubAgents、Hooks、Skills 分别对应动作、分工、流程拦截和知识路由。
- 参考型 Skill 与任务型 Skill 的交互模型不同，不能混写。
- 企业视角下，Skill 更接近可操作 SOP，而不是 Wiki 页面。

运行时规则：

- 当用户描述问题、需要方法或规范时 -> 优先参考型 Skill 自动触发。
- 当入口包含写入、部署、提交、删除、外部调用等副作用时 -> 设计成任务型或手动入口。
- 当 `description` 只写泛词时 -> 视为触发合同不足，需补能力、场景、边界和相邻 Skill 区分。
- 当多个 Skill 同时匹配时 -> 选择边界更窄、语义更贴近用户任务的 Skill；仍无法裁决时向用户确认。
- 当一个能力既要自动触发又要手动调用时 -> 明确 `disable-model-invocation`、`user-invocable` 与权限组合。
- 当只读参考无需写入时 -> 不给写工具权限。
- 当知识量增长时 -> `SKILL.md` 留入口和骨架，低频知识进入按需资源。

不可外推边界：

- 课程支持 description 作为触发器，不支持所有 Skill 写成长 description。
- 课程支持 Skill 是可操作知识，不等于所有知识都要封装为 Skill。
- 课程支持 Skill 与 Tools/SubAgent/Hooks 分工，不等于所有复杂任务都要四者齐全。

落入 `skill-optimizer`：

- 触发契约审计要覆盖能力、场景、边界、相邻冲突、正例、反例和误触发样例。
- frontmatter 审计要按字段语义，而不是只检查字段是否存在。
- source-notes 需要把课程明确结论和本地审计扩展分开标注。

### C10：任务型 Skill、Command 与运行时安全网

课程明确结论：

- 任务型 Skill 是显式动作入口，核心不是“模型自动发现”，而是用户触发后受控执行。
- 斜杠命令与 Skills 在新体系中合流，但旧 command 仍存在兼容边界。
- 参数是命令合同的一部分，包含提示、位置、默认行为、缺参和错参。
- `!command` 用于预注入稳定运行时上下文，降低多轮探查成本。
- `allowed-tools` 是权限边界，不是装饰字段。
- hooks 是执行期安全网，承担拦截、记录、校验或门禁。
- 任务入口需要同时设计动作、触发、参数、上下文、权限、输出、失败路径和安全网。

运行时规则：

- 当入口需要模型自行判断适用性时 -> 用参考型 Skill，不用任务型入口。
- 当能力必须由用户显式发起时 -> 使用 manual-only 语义，禁止模型自启。
- 当参数进入 shell、脚本或工具调用时 -> 先定义参数合同和校验边界。
- 当使用 `$ARGUMENTS`、位置参数或未消费参数追加时 -> 写清参数来源、消费方式和失败路径。
- 当需要读取分支、diff、历史、环境等稳定上下文时 -> 可使用 `!command` 预注入。
- 当任务有副作用时 -> 收紧 `allowed-tools`，并设置确认点或 hook。
- 当缺少仓库、无变更、权限不足、参数非法、依赖缺失时 -> 停止并输出明确失败原因。
- 当动作是确定性、重复性工程操作时 -> 放入 script；当动作是运行时拦截时 -> 放入 hook。

不可外推边界：

- manual-only 是任务型 Skill 的重要边界，但不是所有 Skill 的边界。
- hooks 是安全网，不替代 Skill 内的流程、判断和输出合同。
- `!command` 只适合稳定、可证明的读取型上下文，不适合重型逻辑。

落入 `skill-optimizer`：

- 任务入口审计需要参数合同、权限合同、输出合同和失败路径合同。
- 审查类入口默认只读属于本仓库治理裁决，来源标记为 L/S，不写成课程原意。
- hook 状态流转门禁属于本地工程化扩展，来源标记为 L/S。

### C11：渐进式披露、路由表与资源目录

课程明确结论：

- Skill 采用三层渐进式披露：metadata 负责发现，`SKILL.md` 负责入口与路由，资源文件按需读取。
- `description` 是第一层相关性扫描入口。
- `SKILL.md` 更像 README、TOC 和路由器，不是百科全书。
- Quick Reference 或路由表用于把用户意图映射到具体资源。
- 路由项要贴近用户语言，高频项靠前，条目过多时继续分层。
- 资源目录需要语义清晰，模型看文件名就能判断用途。
- 课程示例重点包含 `reference/`、`templates/`、`examples/`、`scripts/`、`data/`、`QUICKREF.md`、`INDEX.md` 等资源形态。
- 脚本负责确定性动作，模板负责稳定输出结构，data 承载结构化静态数据。
- 500 行是经验阈值，表示主文件进入过载风险，不是零容忍硬规则。

运行时规则：

- 当 metadata 足以判断不相关时 -> 不加载 `SKILL.md`。
- 当 `SKILL.md` 能定位子主题时 -> 只读取对应资源。
- 当用户只问一个细分概念时 -> 不展开所有 reference。
- 当资源没有被入口路由或合同引用时 -> 默认不读取。
- 当路由表超过可扫读范围时 -> 拆二级路由或建 `INDEX.md`。
- 当文件名无法表达用途时 -> 先重命名，再写引用合同。
- 当需要固定输出形态时 -> 使用 template；模板不承担判断逻辑。
- 当需要稳定计算、转换、匹配、生成时 -> 使用 script；script 需要输入输出和失败路径。
- 当需要静态数据集、词表、映射表时 -> 使用 data；不要混入 reference 解释文。
- 当 `!command` 或脚本输出受 `SLASH_COMMAND_TOOL_CHAR_BUDGET` 一类预算约束时 -> 输出摘要优先，长内容进入按需资源或结构化产物。

不可外推边界：

- 课程支持三层披露，不支持所有资源都做六字段合同。
- 课程的契约式引用核心是触发条件、路径和内容预期；证据要求、消费方式和同步义务是本地深化。
- `rules/`、`evals/`、`schemas/`、`hooks/`、`agents/` 是本仓库职责模型，不是 C11 直接结论。

落入 `skill-optimizer`：

- 需要新增 Quick Reference 路由审计：用户意图、目标资源、优先级、条目密度、二级路由。
- 资源目录审计要覆盖课程目录与本地扩展目录，并明确消费者。
- 不能把 JSON runtime artifact 当作 C11 结论。

### C12：Skill 与 SubAgent 组合

课程明确结论：

- Skill 解决 HOW，SubAgent 解决 WHO/WHAT；组合时还需要补 WHERE 与 OUTPUT。
- 先判断是否需要“另一个执行者”，再决定是否引入 SubAgent。
- 组合有两条原子路径：SubAgent 预加载 Skill；Skill 通过 `context: fork` 派生子代理。
- SubAgent 通过 `skills:` 预加载 Skill 时，是创建时全量注入，不是主会话渐进式披露。
- `context: fork` 是 Skill 触发后创建隔离子代理，适合独立完整任务。
- fork 子代理看不到主会话历史，`SKILL.md` 内容成为任务指令的一部分。
- 显式 SubAgent 角色文件适合长期角色；`context: fork` 适合临时独立执行。
- 多阶段 pipeline 用阶段输出作为下一阶段输入，需要清楚的数据接口。
- 主 Agent 负责派发、汇总、去重、证据标注和冲突裁决。

运行时规则：

- 当任务只是需要方法、标准、模板或步骤时 -> 用 Skill。
- 当任务需要独立上下文、重型探索、大输出隔离或主会话保持干净时 -> 用 SubAgent 或 `context: fork`。
- 当任务一次性、自足、执行完只需回传报告时 -> 优先 `context: fork`。
- 当任务需要持续互动、共享主会话历史或边看边改时 -> 留在主 Agent。
- 当同一套领域知识要给不同角色复用时 -> 用显式 SubAgent + `skills:` 预加载。
- 当子任务彼此独立时 -> 可并行派发，再由主 Agent 汇总。
- 当阶段存在依赖时 -> 用串行 pipeline，前一阶段输出必须可被下一阶段消费。
- 当没有输出格式、证据字段和验收点时 -> 先补 handoff 合同，再决定是否 fork。
- 当审查类角色只负责 review/audit/explain 时 -> 默认只读。
- 当子代理结论会影响后续行动时 -> 主 Agent 必须裁决，不能直接照单全收。

不可外推边界：

- SubAgent 数量不代表完整性；完整性来自覆盖矩阵和证据。
- `context: fork` 不等于预定义 SubAgent 文件。
- 对抗审查是 agent team 的一种本地用法，不是所有 SubAgent 结果都要二次挑战。
- `agents/` 平台入口不能替代 `SKILL.md` 的方法合同。

落入 `skill-optimizer`：

- 必须新增 fork 使用矩阵和 SubAgent 组合矩阵。
- handoff 合同至少包含范围、证据、不确定点、阻塞项、下一步和消费端。
- eval 要覆盖 fork 是否隔离、SubAgent 是否全量预加载、pipeline 是否可接力、冲突裁决是否有证据。

### C13：架构定位、高级能力与成熟度

课程明确结论：

- Skill 的架构位点是知识层，介于工具层和 SubAgent 层之间。
- 高级 Skill 的价值来自组织能力，而不是文件数量。
- 成熟度可描述为 SOP、专家系统、组织智能。
- 成熟度跃迁对应稳定执行、复杂变体处理、多角色协作。
- 四类工程模式包括模板驱动、脚本增强、知识分层和工具隔离。
- 模式可组合，不是互斥选项。
- 权限设计是高级 Skill 的前提，不是最后补丁。
- 质量评估看真实消费者、验证路径和复审证据，不看资源堆叠。

运行时规则：

- 当任务稳定、低变体、流程固定时 -> 按 SOP 设计。
- 当领域存在大量例外、边界和判断时 -> 引入知识分层和反例。
- 当输出结构固定且需要解析、比对或复审时 -> 用模板驱动。
- 当动作确定、重复、可测试时 -> 用脚本增强。
- 当操作涉及副作用、敏感工具或权限边界时 -> 用工具隔离。
- 当知识量压缩主上下文时 -> 高频内联，低频外置。
- 当资源没有消费者、触发点和证据链时 -> 不进入 Skill 包。
- 当成熟度评估时 -> 看执行稳定性、变体处理能力、协作复杂度和验证证据。

不可外推边界：

- 成熟度模型不替代本仓库 L1/L2/L3。
- `evals/` 必需是本地 `skill-optimizer` 策略，不是 C13 直接结论。
- 目录职责模型是本地综合，不是课程固定模板。

落入 `skill-optimizer`：

- 模式选择要变成矩阵，而非四个标签。
- 成熟度要绑定证据：入口、流程、失败路径、反例、eval、跨角色复用。
- script/template 需要边界：脚本只做确定性动作，模板只做结构，判断留给模型。

### C14：开放标准、分发与跨平台

课程明确结论：

- Skill 的长期价值来自声明式、自包含、可迁移和可组合。
- 开放标准的关键是核心知识能跨运行面被理解和复用。
- 可迁移需要分离核心知识与平台适配字段。
- Skills 生态需要发现、安装、更新和分发机制。
- Push/Pull 用于判断哪些知识常驻，哪些知识按需加载。
- 开放标准不是去平台化；平台差异需要被标注和隔离。
- 外部依赖、API key、MCP、插件等会影响自包含程度和迁移风险。

运行时规则：

- 当内容是平台无关流程、判断和知识时 -> 放入通用 Skill 核心。
- 当内容依赖 Claude Code、Codex、Copilot、Cursor 或其他运行面字段时 -> 标注消费端。
- 当能力需要跨平台分发时 -> 记录安装、更新、版本和依赖边界。
- 当迁移后需要重写大量执行逻辑时 -> 判定为平台耦合风险。
- 当高频小规则每次都用时 -> Push 到全局规则或项目入口。
- 当低频大知识只在场景触发时 -> Pull 到 Skill 或 reference。
- 当依赖外部 API、MCP 或凭据时 -> 写明依赖、失败路径和降级边界。

不可外推边界：

- 可迁移不等于零成本迁移。
- 开放标准不等于所有平台字段都已标准化。
- `agents/openai.yaml`、`allowed-tools`、`context: fork` 是平台字段，不是通用方法论本体。
- JSON runtime artifact 是本地 Harness Engineering 试点，不是 C14 结论。

落入 `skill-optimizer`：

- 需要跨平台字段矩阵、分发矩阵和自包含程度矩阵。
- 需要把核心知识、平台适配层、分发发现层分开审计。
- 可迁移验证要覆盖核心知识是否仍可执行、平台字段是否已隔离、依赖是否可替换。

### C99：专题总结、可用性与复盘

课程明确结论：

- Skill 的交付物是可触发、可加载、可执行、可验证、可演化的能力包。
- 完整 Skill 包不等于目录越多越好，而是入口、资源、脚本、模板、评估各有职责。
- 5/10/30 是可用性检验：快速看懂、快速上手、快速产出。
- 练习题强调从真实团队痛点出发，设计目录结构、决策说明、协作方式和 ROI。
- 复用和扩展需要先判断已有实现，再决定新建。
- 评估要覆盖触发准确、加载成本、输出质量、复用率和验证证据。

运行时规则：

- 当 5 分钟内无法判断 Skill 用途时 -> 触发契约不足。
- 当 10 分钟内无法按入口跑通基础流程时 -> 加载与路由不足。
- 当 30 分钟内无法产出一个小型可审计结果时 -> 输出合同或验证合同不足。
- 当已有语义一致 Skill 或脚本存在时 -> 先复用，再考虑新建。
- 当 Skill 面向团队落地时 -> 需要可交接、可复测、可复盘。
- 当只靠阅读判断质量时 -> 不能宣称优化有效。

不可外推边界：

- 5/10/30 证明可用性，不直接证明质量收益。
- eval 是证据通道，不替代真实工程验证。
- 完整 Skill 包不是固定目录模板。

落入 `skill-optimizer`：

- 复用判断要进入审计。
- 可用性门槛要和触发、加载、输出、验证绑定。
- 练习题启发可转成 eval 场景和人工复审问题。

## 横向决策矩阵

### 触发与访问矩阵

| 场景 | 默认入口 | 关键字段 | 风险 | 验证 |
| --- | --- | --- | --- | --- |
| 方法、规范、判断框架 | 自动触发参考型 Skill | `description` | 误触发或漏触发 | 正例、反例、相邻冲突样例 |
| 明确动作、低风险 | 手动任务型 Skill | `user-invocable`、`argument-hint` | 参数不清 | 参数样例、no-op 样例 |
| 副作用动作 | 手动入口 + 确认 | `disable-model-invocation`、`allowed-tools` | 越权执行 | 权限拒绝、hook 阻断 |
| 安全敏感或禁用能力 | 隐藏或 deny | deny / 权限配置 | 被模型误用 | 禁触发样例 |
| 只读审查 | 自动或手动均可 | 只读 tools | 审查越权修改 | 工具权限验证 |

### Frontmatter 兼容矩阵

| 字段 | 课程/平台语义 | 审计问题 | 来源 |
| --- | --- | --- | --- |
| `name` | 技能身份 | 是否唯一、可读、无冲突 | C09/O |
| `description` | 触发器 | 是否写能力、场景、边界、区分点 | C09/O |
| `argument-hint` | 参数提示 | 是否与真实参数消费一致 | C10 |
| `disable-model-invocation` | 禁止模型自启 | 是否用于任务型或风险入口 | C09/C10 |
| `user-invocable` | 手动调用 | 是否与触发模式一致 | C09/C10 |
| `allowed-tools` | 工具权限 | 是否命令级最小授权 | C10/L |
| `model` | 模型选择 | 是否有必要，是否有降级边界 | C10/S |
| `context` | 执行上下文 | 是否为主会话或 fork | C12 |
| `agent` | fork 子代理类型 | 是否匹配任务职责 | C12 |
| `hooks` | 执行期安全网 | 是否只做拦截、记录或门禁 | C10/L |

### 参数与上下文注入矩阵

| 机制 | 使用条件 | 失败形态 | 审计证据 |
| --- | --- | --- | --- |
| `$ARGUMENTS` | 自由文本参数 | 参数未校验、注入 shell | 缺参、错参、危险参数样例 |
| `$1/$2` | 固定位置参数 | 位置歧义、遗漏参数 | 参数表与命令调用一致 |
| 未消费参数追加 | 兼容 command 行为 | 参数被意外传入 | 输出中标明消费情况 |
| `!command` | 稳定读取型上下文 | 重型逻辑、权限扩大 | 命令白名单与输出摘要 |
| 环境变量 | 会话或工具上下文 | 泄露或跨环境漂移 | 变量来源与可空路径 |

### 渐进加载与资源目录矩阵

| 资源 | 课程角色 | 本仓库扩展角色 | 创建条件 |
| --- | --- | --- | --- |
| metadata | 第一跳触发 | 触发 eval 输入 | 能力需要自动发现 |
| `SKILL.md` | README/TOC/路由器/骨架 | 硬门槛与契约入口 | 所有 Skill 必需 |
| `reference/` 或 `references/` | 低频知识 | 方法论与背景真源 | 主文件过载或知识低频 |
| `templates/` | 输出结构 | 派生视图模板 | 输出格式稳定 |
| `examples/` | 正反例 | eval 与语义对齐 | 触发或输出易误解 |
| `data/` | 静态数据 | fixtures 或映射表 | 数据被脚本或流程消费 |
| `scripts/` | 确定性动作 | 工程能力 | 可测试、可重复、无交互 |
| `assets/` | 静态素材 | 输出资源 | 交付需要静态文件 |
| `rules/` | 本地扩展 | skill-local 规则 | 与全局 rules 不同且有消费者 |
| `evals/` | 本地扩展 | 行为验证 | 需要证明优化收益 |
| `schemas/` | 本地扩展 | runtime artifact 合同 | JSON 试点存在消费者 |
| `INDEX.md`/`QUICKREF.md` | 路由页 | 多级资源索引 | 资源超过一跳可扫读范围 |

### 契约式引用矩阵

| 层级 | 字段 | 来源 | 规范强度 |
| --- | --- | --- | --- |
| 课程核心 | 触发条件 | C11 | E1/E2 |
| 课程核心 | 读取路径 | C11 | E1/E2 |
| 课程核心 | 内容预期 | C11 | E1/E2 |
| 本地扩展 | 消费方式 | S/L | 审计建议或本地合同 |
| 本地扩展 | 证据要求 | S/L | 对关键 runtime reference 可硬化 |
| 本地扩展 | 同步义务 | S/L | 与文档同步规则绑定后可硬化 |

### fork 与 SubAgent 组合矩阵

| 模式 | 使用条件 | 加载语义 | 输出要求 | 不适用 |
| --- | --- | --- | --- | --- |
| 主会话直接使用 Skill | 需要共享对话历史、持续互动、边看边改 | 渐进式披露 | 直接响应用户 | 重型探索、大输出隔离 |
| 显式 SubAgent + `skills:` | 长期角色需要领域知识 | Skill 全量预加载 | 角色化结果 | 只需一次性报告 |
| Skill + `context: fork` | 独立完整任务、主上下文需保持干净 | fork 子代理隔离执行 | 结构化报告回传 | 需要主会话历史 |
| 并行 SubAgents | 子任务互不依赖、需要多视角 | 各自上下文 | 主 Agent 汇总去重 | 依赖链强 |
| 串行 pipeline | 阶段有依赖 | 阶段性加载 | 上一阶段输出供下一阶段消费 | 无明确接口 |
| agent team 挑战 | 需要独立审查或对抗视角 | 独立上下文 | 风险、证据、裁决建议 | 常规小任务 |

### Handoff 输出矩阵

| 字段 | 用途 | 消费端 |
| --- | --- | --- |
| scope | 子任务覆盖边界 | 主 Agent 汇总 |
| evidence | 事实依据 | 后续审查或验证 |
| uncertainty | 不确定点 | 主 Agent 裁决 |
| blockers | 阻塞项 | 用户或上游流程 |
| output_contract | 结果格式 | 下游阶段 |
| next_step | 推荐后续 | 主 Agent 编排 |

### 权限与 hooks 矩阵

| 能力 | 默认权限 | 需要确认的信号 | hook 角色 |
| --- | --- | --- | --- |
| read/review/audit/explain | 只读 | 请求修改文件 | 记录与阻断越权 |
| edit/refactor/fix | 精确写权限 | 大范围修改、跨模块 | 变更前后门禁 |
| commit/deploy/delete | 显式用户确认 | 发布、删除、不可逆动作 | 强阻断与日志 |
| script run | 命令级白名单 | 参数进入 shell | 参数校验与退出码 |
| external API/MCP | 最小凭据 | 凭据缺失、远端失败 | 超时、重试、失败停机 |

### scripts 与 templates 矩阵

| 资源 | 适用 | 禁止承担 | 验证 |
| --- | --- | --- | --- |
| script | 确定性、重复性、可测试动作 | 模糊判断、交互式决策 | 输入输出、退出码、错误路径 |
| template | 稳定输出结构 | 业务判断、事实来源 | 占位符填充、格式校验 |
| example | 语义对齐、边界说明 | 替代规则 | 正例、反例、边界例 |
| data | 静态映射、fixtures | 长解释 | 消费者存在、结构稳定 |

### 成熟度与模式矩阵

| 成熟度 | 判定依据 | 需要的证据 | 不代表 |
| --- | --- | --- | --- |
| SOP | 稳定流程可执行 | 入口、步骤、输出、完成校验 | 文件少就低级 |
| 专家系统 | 变体、例外、反模式可处理 | 分支、失败路径、反例、脚本或模板 | 目录多就高级 |
| 组织智能 | 多角色协作、可复用、可评估 | eval、benchmark、复用、迁移记录 | 替代 L1/L2/L3 |

### Push/Pull 矩阵

| 判断维度 | Push | Pull |
| --- | --- | --- |
| 使用频率 | 每次都用 | 场景触发 |
| 知识体量 | 小 | 中到大 |
| 权威层级 | 全局 rules | skill-local 知识 |
| 上下文成本 | 常驻可接受 | 常驻浪费 |
| 更新影响 | 全局同步 | 局部同步 |
| 典型位置 | AGENTS/rules | Skill/reference |

### 跨平台与分发矩阵

| 层 | 内容 | 审计问题 |
| --- | --- | --- |
| 核心知识层 | 流程、判断、输出、反例 | 离开原平台仍可理解 |
| 平台适配层 | frontmatter、tools、hooks、agent 字段 | 消费端是否标明 |
| 分发发现层 | registry、marketplace、git、plugin | 安装、更新、版本是否清楚 |
| 外部依赖层 | API、MCP、凭据、二进制 | 失败路径和降级边界 |

### eval 与反馈闭环矩阵

| 样例类型 | 证明内容 | 反馈去向 |
| --- | --- | --- |
| 正触发 | description 命中 | 触发契约 |
| 非触发 | 边界清晰 | description 排除项 |
| 相邻冲突 | Skill 区分度 | 相邻 Skill 边界 |
| 缺参/错参 | 参数合同 | 任务入口 |
| 权限不足 | 权限合同 | allowed-tools/hooks |
| 格式诱导 | 输出合同 | templates/examples |
| fork 隔离 | 上下文干净 | SubAgent/fork 矩阵 |
| pipeline 接力 | handoff 可消费 | 输出合同 |
| 真实任务 | 端到端价值 | 质量收益判断 |

### 本地 Runtime 合同边界矩阵

| 结论 | 来源 | 规范强度 | 进入 design 前条件 |
| --- | --- | --- | --- |
| JSON 作为 runtime artifact 承载 | S/Harness | E5 试点 | 有消费者、schema、semantic validator、样例 |
| Markdown/HTML 从 JSON 派生 | S | E5 试点 | 渲染器与回写边界验证 |
| `schemas/` 必需 | S/L | `skill-optimizer` 局部策略 | runtime artifact 被采用 |
| `evals/` 必需 | S/O/C99 | `skill-optimizer` 局部策略 | 明确 eval 消费者 |
| 固定 artifact 三件套 | S | 设计假设 | 样例证明字段稳定 |
| 固定状态机 | S | 设计假设 | 流转规则通过语义验证 |
| 固定触发样例数量 | S | 初始建议 | 数据集实验后再硬化 |

## 高风险遗漏登记

本登记记录原始遗漏、当前覆盖位置和剩余风险。`当前状态` 为“已覆盖”只表示 source map 已有设计输入，不表示下游实施已通过验证。

| 编号 | 来源 | 原始遗漏 | 当前状态 | 剩余风险 |
| --- | --- | --- | --- | --- |
| G01 | C09/C10 | 自动/手动/隐藏/deny/权限发现矩阵不足 | 已覆盖：触发与访问矩阵、frontmatter 字段组合合同 | 需由 `SO-FRONTMATTER-01` 绑定静态结构检查 |
| G02 | C09/C10 | Enterprise/Personal/Project、namespace、monorepo 发现范围不足 | 已覆盖：发现范围与命名空间矩阵 | 需用 install smoke 和触发冲突 eval 验证 |
| G03 | C09 | frontmatter 字段级语义不足 | 已覆盖：Frontmatter 字段组合与失败态 | 需用静态结构检查覆盖组合失败 |
| G04 | C10 | `$ARGUMENTS`、位置参数、shell 输入矩阵不足 | 已覆盖：参数与上下文注入矩阵 | 需绑定 script manifest 参数校验 |
| G05 | C10/C11 | `!command` 注入矩阵不足 | 已覆盖：参数与 command 输出预算 | 需用 manifest 白名单和输出上限验证 |
| G06 | C10 | Skill 内 hooks 生命周期矩阵不足 | 已覆盖：hooks lifecycle 审计边界 | 首轮不接 hook registry，需由 semantic validator、人工复审和 eval 承接 |
| G07 | C10/C12 | `context: fork` 使用矩阵缺失 | 已覆盖：fork 与 SubAgent 组合矩阵、fork input contract | 需在 agent prompt fixture 中验证 required/excluded context |
| G08 | C12 | SubAgent `skills:` 全量预加载缺失 | 已覆盖：fork 与 SubAgent 组合矩阵 | 需用 token/context 边界样例验证 |
| G09 | C12 | pipeline 阶段接口缺失 | 已覆盖：handoff consumer、acceptance_basis 和 stage contract | 需在 pipeline fixture 中复跑 |
| G10 | C11 | Quick Reference 路由质量缺失 | 已部分覆盖：渐进加载与资源目录矩阵 | 路由密度和二级索引需进入验证 |
| G11 | C11 | `templates/`、`data/`、`INDEX.md` 缺失 | 已覆盖：渐进加载与资源目录矩阵 | 创建条件需保持 consumer-first |
| G12 | C11/C13 | script 判定与依赖规则不足 | 已覆盖：scripts 与 templates 矩阵、script manifest、退出码合同 | 需补真实脚本准入样例 |
| G13 | C13/C99 | template 边界不足 | 已覆盖：scripts 与 templates 矩阵 | 模板验证需进入 eval 样例 |
| G14 | C14 | 跨平台字段、自包含、依赖降级不足 | 已覆盖：跨平台与分发矩阵、自包含分级、依赖可迁移性 | 需由安装检查验证路径解析和依赖边界 |
| G15 | C14/C99 | 触发日志、Test Case、反馈闭环不足 | 已覆盖：eval 与反馈闭环矩阵、可复测 dataset、benchmark 和 5/10/30 protocol | 需用固定 seed dataset 复跑 |

## Design 复核裁决清单

下列 `design.md` 章节已从草案状态进入复核裁决。`当前裁决` 标明可承接范围和仍需补充的实施前条件。

| design 章节 | 原始暂停原因 | 当前裁决 |
| --- | --- | --- |
| 任务型 Skill 契约 | 参数、`!command`、hooks、权限矩阵不足 | 可承接；设计已补 frontmatter 字段组合、权限 profile、script manifest 和危险动作确认合同 |
| Skill 与 SubAgent 组合契约 | fork、全量预加载、pipeline 接口不足 | 可承接；设计已补 fork input contract、handoff consumer 和 acceptance_basis |
| 资源目录职责模型 | 课程目录与本地扩展目录混合 | 可承接；需保持 consumer-first，禁止目录创建本身成为验收目标 |
| 平台兼容设计 | 跨平台字段和分发矩阵不足 | 可承接；设计已补 discovery scope、namespace、monorepo、自包含程度和依赖迁移矩阵 |
| 验证设计 | eval 数据集和反馈闭环不足 | 可承接；设计已补可复测 dataset、验证边界、benchmark 和 5/10/30 协议 |
| new-skills 迁移形态 | 发现范围、namespace、安装兼容不足 | 可承接；设计已补逐文件迁移映射和 legacy command compatibility |
| Runtime 信息合同 | E5 试点压过课程矩阵 | 只作为 E5 试点；设计已补字段消费者矩阵、状态流转表、回退合同和最小闭环样例 |
| Schema 合同层 | E5 试点收益待验证 | 只作为 E5 试点；设计已补 semantic invariant、validator 输出和 rendered_views 防漂移字段 |

## 术语消歧

| 术语 | 本文件限定含义 | 易混点 |
| --- | --- | --- |
| fork | `context: fork` 隔离子代理执行 | Git fork、进程 fork |
| SubAgent | 独立上下文执行者 | 显式 agent 文件、临时 fork、agent team 角色 |
| Command | 斜杠命令或任务入口 | shell command、hook command |
| Skill | 可触发知识能力包 | 本仓库流程 skill、官方 skill-creator |
| Hook | 运行时拦截或门禁 | Git hook、全局 hook、Skill 内 hook |
| reference | 低频知识资源或引用合同 | 仓库 `references/`、共享真源 |
| rules | 规则层 | 全局硬规则、skill-local rules、AGENTS |
| eval | 行为验证样例或 benchmark | 仓库测试、人工复审、课程练习题 |
| schema | runtime artifact 形状/语义/流转/消费合同 | 仅 JSON Schema |

## 反向测试问题

1. C11 的契约式引用课程核心包含哪些要素？哪些要素是本地扩展？
2. SubAgent 用 `skills:` 预加载 Skill 时，是渐进加载还是全量加载？
3. `context: fork` 和预定义 SubAgent 文件的入口差异是什么？
4. `schemas/` 必需是课程结论、本地策略还是官方约束？
5. JSON 作为 runtime fact source 的证据等级是什么？
6. 500 行是经验阈值、官方建议、本地 MUST，还是本仓库需另行验证的建议？
7. Command 合入 Skills 后，旧 `.claude/commands` 的兼容边界是什么？
8. 任务型 Skill 为何需要 manual-only？参考型 Skill 为何可自动触发？
9. Hooks 在课程里是 Skill 安全网，还是本仓库状态机门禁？
10. Push/Pull 的判定依据是频率、知识体量、上下文成本还是规则层级？
11. 自包含主要约束核心知识层，还是约束所有运行时基础设施？
12. 5/10/30 能证明可用性，还是证明质量收益？
13. 成熟度模型能否替代 L1/L2/L3？
14. `evals/` 对 `skill-optimizer` 必需是课程结论、官方工具约束还是本地试点？
15. `reference/` 与 `references/` 命名差异会不会导致跨平台误读？
16. 课程案例出现 JSON 输出，能否推出所有 runtime artifact 必须 JSON+schema？

## 验收口径

`source-notes.md` 进入可审阅状态时，需满足以下条件：

- 7/7 课程文件逐讲覆盖，每讲都有课程明确结论、运行时规则、不可外推边界和落地影响。
- 高风险遗漏 G01-G15 全部在正文或矩阵中有对应条目。
- fork、ARGUMENTS、Quick Reference、全量预加载、Push/Pull、Test Case、skills marketplace、自包含、allowed-tools、hooks、templates、data、INDEX、SLASH_COMMAND_TOOL_CHAR_BUDGET 这些关键词能被检索到。
- 本地 E5 推断均有“来源、规范强度、进入 design 前条件”。
- `design.md` 的暂停清单明确哪些章节不能继续硬化。
- 文档不包含课程长引文，不把课程正文沉淀进仓库。
- 文档不包含待办清单；所有未完成内容以“暂停清单、遗漏登记、验收口径”表达。

后续 `tasks.md`、`plan.md` 和 runtime artifact 引用课程来源时，优先引用本文件的 source marker 和矩阵名，再引用 `design.md` 的设计章节。禁止只写“参考课程”作为验收依据。
