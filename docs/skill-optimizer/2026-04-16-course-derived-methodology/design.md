# skill-optimizer Harness Engineering 设计

## 背景

本设计围绕 Harness Engineering 建立 `skill-optimizer`：用 feedforward 约束提升 Skill 首次执行质量，用 feedback 与 runtime artifact 让 Skill 的触发、加载、引用、权限、验证和演化可观察、可验证、可复盘。极客时间「Skills 技能系统」7 讲是重要信息来源，提供 Skill 结构、触发、渐进式披露、SubAgent 配合和开放标准等方法论；课程信息沉淀见 `source-notes.md`，该文件只记录二次抽象、证据等级和设计影响，不沉淀课程原文。官方 `skill-creator` 提供创建、评估和迭代方法；本仓库 `rules/`、`reference/` 和既有 `shared/skills/new-skills/` 提供本地治理约束。

本设计不把 Harness Engineering 术语、课程、官方工具或既有本地实现视为最终权威。裁决顺序为：本仓库硬规则与运行时契约优先，其次是用户目标与可验证证据，再其次是 Harness Engineering 诊断框架、课程方法论、官方经验和主线程推断。

## 目标

`skill-optimizer` 的定位是 Skill 质量优化器。它接管当前 `new-skills` 中更适合本地保留的质量审计、反模式识别、结构诊断、reference 契约检查和改造建议，不再与官方 `skill-creator` 竞争“从零创建 Skill”的职责。

目标结果是形成一个用于优化 Skill 的 Skill：

- 识别 Skill 触发、加载、引用、执行、验证和演化中的质量问题。
- 输出证据化诊断，而不是只给格式意见。
- 给出与本仓库规则兼容的改造方向。
- 结合官方 `skill-creator` 的 eval/benchmark 能力验证改造收益。
- 支持从 `new-skills` 平滑迁移到 `skill-optimizer`。

## 非目标

`skill-optimizer` 不负责替代官方 `skill-creator` 从零访谈、草拟 Skill、运行 with/without eval 和 description 优化。它也不负责把 Harness Engineering 文章或课程原文沉淀为知识库。外部材料只作为方法论来源，进入本仓库时必须变成抽象规则、审计维度和验收证据。

## 证据等级

| 等级 | 含义 | 可进入的规范强度 |
| --- | --- | --- |
| E1 | 课程明确表达的设计原则或机制 | 可作为强规则候选，仍需服从本仓库 rules |
| E2 | 课程案例归纳出的工程模式 | 可作为审计维度或默认路径 |
| E3 | 本仓库 rules/reference/contracts 的既有约束 | 可作为 MUST 级门禁 |
| E4 | 官方 `skill-creator` 或 Codex/Claude Skill 文档体现的工具约束 | 可作为兼容性和流程参考 |
| E5 | 本次主线程与 agent team 的设计推断 | 只能作为设计假设、SHOULD 级建议或待实验项 |

进入 `skill-optimizer` 的每个关键规则都带证据等级。只有 E3 或 E1+本仓库验证支撑的规则能写成硬门禁；E5-only 结论不能写成 MUST。

课程来源使用 `source-notes.md` 的 source map 标记追踪：C09-C14 对应课程 09 至 14 讲，C99 对应加餐总结，L 对应本仓库本地约束，O 对应官方工具约束，S 对应本次综合推断。后续 `tasks.md`、`plan.md` 和 runtime artifact 引用课程来源时，必须同时引用 source map 标记和本设计章节。

## 规则硬化原则

`skill-optimizer` 的规则分为三层：硬门禁、审计维度和待验证假设。E3 来源规则进入硬门禁。E1/E2 来源规则先进入审计维度，经本仓库样例验证后再进入硬门禁。E5 来源规则只能进入待验证假设或实验协议。

实施计划不得把待验证假设直接转成阻塞性验收。涉及 E5 的改动必须绑定实验样例和回退路径。若实验无法证明质量收益，该规则保留在 reference 或审计说明中，不进入 `SKILL.md` 的 HARD-GATE。

反方挑战提出的高风险项按此原则处理：六字段 reference 契约作为关键 reference 的完整契约模板，不作为所有 reference 的通用强制 schema；Skill 与 SubAgent 边界作为审计视角，不作为所有复杂任务的强制拆分规则；成熟度模型作为诊断输出维度，不替代现有 L1/L2/L3 评级真源。

## source-notes 对齐裁决

`source-notes.md` 是课程信息进入本设计的唯一 source map。`design.md` 不直接引用课程原文，也不把课程案例、本仓库规则和 Harness Engineering 推断混成同一权威层级。

本设计采纳 `source-notes.md` 的横向矩阵作为方法论边界：

| source-notes 矩阵 | 进入本设计的位置 | 裁决 |
| --- | --- | --- |
| 触发与访问矩阵 | 触发契约、任务型 Skill 契约、验证设计 | 自动触发、手动入口、隐藏入口和只读审查分开治理 |
| Frontmatter 兼容矩阵 | 触发契约、平台兼容设计、new-skills 迁移形态 | 字段按消费端和风险审计，不做纯存在性检查 |
| 发现范围与命名空间矩阵 | 平台兼容设计、new-skills 迁移形态 | Enterprise/Personal/Project、namespace 和 monorepo 发现范围进入审计 |
| 参数与上下文注入矩阵 | 任务型 Skill 契约、验证设计 | `$ARGUMENTS`、位置参数、`!command` 和命令输出预算进入失败路径审计 |
| 渐进加载与资源目录矩阵 | 加载契约、资源目录职责模型 | `reference/`、`templates/`、`examples/`、`scripts/`、`data/`、`INDEX.md`/`QUICKREF.md` 与本地扩展目录分层表达 |
| 契约式引用矩阵 | 契约式引用、契约式引用详细规范 | 课程核心三要素与本地扩展三要素分开标注 |
| fork 与 SubAgent 组合矩阵 | Skill 与 SubAgent 组合契约 | `skills:` 全量预加载、`context: fork` 隔离执行和 pipeline handoff 分开裁决 |
| 权限与 hooks 矩阵 | 任务型 Skill 契约、质量维度扩展 | review/audit/explain 默认只读；写入、提交、部署、删除需要显式确认与权限证据 |
| 跨平台与分发矩阵 | 平台兼容设计、new-skills 迁移形态 | 核心知识、平台适配、分发发现和外部依赖分层 |
| eval 与反馈闭环矩阵 | 验证设计、调研到实施追踪契约 | eval 不替代仓库测试；它提供触发、边界、失败路径和收益反馈 |
| 本地 Runtime 合同边界矩阵 | Runtime 信息合同、Schema 合同层、skill-optimizer 运行模型 | JSON、schema、状态机和 artifact 三件套属于 `skill-optimizer` 首轮试点，不是课程结论或全仓模板 |

## 稳定设计锚点

下游 `tasks.md`、`plan.md` 和 runtime artifact 不引用自然语言章节名作为唯一追踪键。每条可实施设计规则使用稳定锚点 ID，ID 绑定 source marker、证据等级、消费者、验证类型和落地边界。

| 锚点 ID | 设计范围 | source marker | 证据等级 | 主要消费者 | 验证类型 |
| --- | --- | --- | --- | --- | --- |
| SO-TRIGGER-01 | description、触发样例、相邻冲突 | C09/O/L | E1/E3/E4 | `SKILL.md`、eval | 行为样例验证 |
| SO-FRONTMATTER-01 | frontmatter 字段组合与失败态 | C09/C10/O/L | E1/E3/E4 | `agents/openai.yaml`、安装检查 | 静态结构验证 |
| SO-DISCOVERY-01 | Enterprise/Personal/Project、namespace、monorepo | C09/C10/C14/S | E2/E5 | 安装脚本、迁移映射、触发冲突 eval | 静态结构验证 |
| SO-LOAD-01 | 三层渐进式披露和 Quick Reference | C11/O/L | E1/E3/E4 | `SKILL.md`、resource 路由 | 静态结构验证 |
| SO-RESOURCE-01 | resource 目录职责和 consumer-first 创建 | C11/C13/C99/S | E1/E2/E5 | skill 包、安装检查 | 静态结构验证 |
| SO-REFERENCE-01 | 契约式引用和同步义务 | C11/L/S | E1/E3/E5 | `SKILL.md`、reference 审计 | 行为样例验证 |
| SO-TASK-01 | 任务型 Skill、Command、参数注入 | C10/L | E1/E3 | 任务入口、script manifest | 行为样例验证 |
| SO-PERMISSION-01 | 权限 profile、危险动作确认、hooks 边界 | C10/L/S | E1/E3/E5 | frontmatter、工具权限、人工复审 | 静态结构验证 |
| SO-SCRIPT-01 | script 准入、白名单、退出码和输出预算 | C10/C11/C13/L | E1/E3 | `scripts/manifest`、测试命令 | Runtime 合同验证 |
| SO-SUBAGENT-01 | `skills:`、`context: fork`、handoff、pipeline | C12/S | E1/E5 | 主 Agent、SubAgent、eval | 行为样例验证 |
| SO-RUNTIME-01 | runtime artifact、schema、状态机、派生视图 | S/Harness/L | E5/E3 | validator、renderer、人工复审 | Runtime 合同验证 |
| SO-VALIDATION-01 | dataset、benchmark、5/10/30、收益对比 | C99/O/L/S | E1/E4/E3/E5 | eval、benchmark、最终报告 | 行为样例验证 |
| SO-MIGRATION-01 | `new-skills` 兼容、逐文件迁移、legacy command | C10/C14/L/S | E1/E3/E5 | 安装脚本、迁移任务 | 静态结构验证 |
| SO-PORTABILITY-01 | 自包含程度、外部依赖和跨平台分发 | C14/L/S | E1/E3/E5 | 平台 adapter、安装检查 | 静态结构验证 |
| SO-TRACKING-01 | source map 到 Task/Plan/diff/proving command | L/S | E3/E5 | `tasks.md`、`plan.md`、最终报告 | 改造收益验证 |

## 方法论地图 v3

### 触发契约

`description` 是 Skill 的路由契约，不是简介。它决定模型在用户请求出现时是否加载 `SKILL.md`。优化时要判断它是否同时表达能力、触发场景、边界和相邻 Skill 区分点。

触发契约的审计对象包括：frontmatter 字段完整性、能力声明、`Use when` 场景、显式不适用边界、相邻 Skill 冲突、真实用户触发语样例和不触发样例。

Frontmatter 不是存在性清单，而是触发、访问和权限的组合合同：

| 组合场景 | 关键字段 | 失败态 | 对应锚点 |
| --- | --- | --- | --- |
| 参考型自动触发 | `description` | 泛词触发、相邻 Skill 冲突 | SO-TRIGGER-01 |
| 任务型手动入口 | `user-invocable`、`argument-hint` | 缺参、错参、参数未消费 | SO-FRONTMATTER-01 |
| 禁止模型自启 | `disable-model-invocation` | 副作用任务被自动触发 | SO-FRONTMATTER-01 |
| 工具最小权限 | `allowed-tools` | review 类入口获得写权限 | SO-PERMISSION-01 |
| fork 子代理 | `context`、`agent` | fork 缺输入、误依赖主会话历史 | SO-SUBAGENT-01 |
| 平台暴露 | `agents/openai.yaml` | Codex adapter 与 `description` 漂移 | SO-PORTABILITY-01 |

证据来源：E1 课程触发机制；E3 `Skill质量标准.md` description 约束；E4 官方 `skill-creator` 对 description 的触发强调。

### 加载契约

Skill 是三层渐进式披露系统：metadata 负责触发，`SKILL.md` 负责入口流程和资源路由，bundled resources 承载低频细节、模板、脚本和资产。优化目标不是让 `SKILL.md` 更短，而是让每一层承担正确职责。

`SKILL.md` 应承载高频骨架、硬门槛、关键分支和资源路由。长方法论、示例、模板、脚本逻辑和领域细节进入 `references/`、`templates/`、`scripts/` 或 `assets/`。

最小 Skill 只包含 `SKILL.md` 也成立。`skill-optimizer` 审计时不能因缺少 `references/`、`scripts/` 或 `assets/` 判定质量失败；只有当运行链路需要低频知识、确定性逻辑或输出资产时，才要求引入 bundled resources。

证据来源：E1 渐进式披露三层架构；E3 本仓库 D6 Token 效率；E4 官方 Skill anatomy。

### 资源目录职责模型

Skill 的 bundled resources 不再被统一视为 `references/` 附属内容。目录名本身是路由信号，用于帮助 LLM 和人类判断资源用途。目录只在承担真实职责时创建；简单 Skill 可只包含 `SKILL.md`。

| 目录或资源 | 职责 | 读取或执行方式 | 来源边界 |
| --- | --- | --- | --- |
| `SKILL.md` | 高频骨架、入口流程、硬门槛、资源路由 | metadata 命中后加载 | C11/O |
| `reference/` 或 `references/` | 方法论、背景知识、判断框架、长解释 | 由 `SKILL.md` 按场景引用 | C11；命名需兼容平台 |
| `templates/` | 稳定输出结构、派生视图模板 | 由 Agent、script 或 renderer 读取 | C11/C13 |
| `examples/` | 正例、反例、边界例、格式诱导样例 | 由 `SKILL.md` 在教学、审计或 eval 前引用 | C11/C99 |
| `scripts/` | 可重复、确定性、可机械执行的工程能力 | 由 Agent 或测试命令执行 | C11/C13 |
| `data/` | 静态词表、fixtures、映射表 | 由 script、eval 或流程读取 | C11 |
| `INDEX.md`/`QUICKREF.md` | 多级资源索引、Quick Reference 路由 | 由 `SKILL.md` 在资源超过一跳可扫读范围时引用 | C11 |
| `assets/` | 输出素材、模板文件、二进制或静态资源 | 复制、读取或作为输出资源使用 | C11/O |
| `rules/` | skill-local 规则、权限边界、职责边界、局部门禁细则 | 由 `SKILL.md` 通过契约式引用读取 | L/S，本地扩展 |
| `evals/` | 行为样例、断言、benchmark 输入、人工评审标准 | 存在 eval consumer、fixture 和复跑命令时创建 | C99/O/S，本地策略 |
| `schemas/` | runtime artifact schema、状态机、语义校验规则、schema migration | 采用 runtime artifact 且存在字段消费者时创建 | S/L，JSON 试点 |
| `hooks/` | 状态流转拦截和门禁控制 | future consumer；首轮 `skill-optimizer` 不接入 hook registry | C10/L/S，本地工程化 |
| `agents/` | Codex/Claude 暴露元数据和 UI 入口 | 只放平台 adapter；SubAgent prompt 放 `references/agent-prompts/` 或共享 agent 目录 | 平台适配层 |

该模型强调职责隔离：`SKILL.md` 承载入口和路由，`reference/` 或 `references/` 承载解释和方法，`templates/` 承载稳定结构，`examples/` 承载语义对齐，`data/` 承载静态结构化输入，`scripts/` 承载工程动作。本仓库扩展目录 `rules/`、`evals/`、`schemas/`、`hooks/` 和 `agents/` 只有在存在明确消费者、验证路径和平台边界时进入 Skill 包。目录创建本身不作为验收目标。

### Runtime 信息合同

格式本身不是目标。`skill-optimizer` 区分 runtime information 与 rendering information：凡是会被下游判断、验证、流转、拦截、统计、回放或复测的信息，都属于 runtime information；只用于解释、阅读和展示的信息属于 rendering information。该区分来自 Harness Engineering 的本地转译，属于 E5 试点，不是课程直接结论。

| 信息类型 | 定义 | 推荐承载 |
| --- | --- | --- |
| Runtime information | 状态、证据、决策、验收、阻塞、依赖、设计锚点、验证命令、流转条件、下游消费字段 | `skill-optimizer` 首轮采用 JSON artifact + schema |
| Rendering information | 背景解释、权衡叙述、长段自然语言、图表展示、给人看的报告布局 | Markdown/HTML 派生视图 |

JSON 是 `skill-optimizer` 首轮 runtime information 的试点承载格式，不是质量来源。质量来源是 schema 合同、语义校验、状态机、验证证据和下游消费契约。Markdown/HTML 不作为关键 runtime artifact 的事实源；人类需要修改事实时，修改 JSON artifact，再由 renderer 生成 Markdown/HTML 视图。

Runtime artifact 不得退化为 Markdown 字符串容器。关键判断不得只存在于 `summary`、`notes`、`analysis` 等自由文本字段。长日志、长说明和大段证据通过 `ref`、`path`、`hash`、`summary` 组合引用，避免把上下文预算消耗在不可验证文本上。

### Schema 合同层

Schema 是上下游之间的接口合同，不只是 JSON 字段格式。`skill-optimizer` 首轮 runtime artifact 的 `schemas/` 表达四层合同：

| 合同层 | 作用 | 示例 |
| --- | --- | --- |
| 形状合同 | 字段名、类型、必填、枚举、数组元素结构 | `artifact_type`、`schema_version`、`status` |
| 语义合同 | 字段含义、合法组合、不变量、证据约束 | `status=verified` 时必须存在通过状态的 proving command |
| 流转合同 | 状态能转到哪里、转移需要什么证据、失败如何表达 | `blocked --revise_design--> draft`，`approved --promote--> ready_for_plan` |
| 消费合同 | 哪个 skill、script、validator 或 eval 会读取字段 | semantic validator 读取 `transition.allowed`，eval 读取 `findings[].evidence_level` |

JSON Schema 主要覆盖形状合同。语义合同、流转合同和消费合同由 state-machine schema、semantic validator、rules 文档和 eval 共同承接。任何字段进入 schema 前都要有明确消费者；没有消费者的字段进入 rendering view 或 reference，不进入 runtime 合同。

`schema_version` 是 `skill-optimizer` runtime artifact 的必填字段。schema 演化采用显式版本，破坏性变更需要 migration 规则。下游消费者读取 artifact 时先检查 `artifact_type` 与 `schema_version`，不能靠文件名推断结构。

字段进入 schema 前需要通过字段消费矩阵。矩阵最小字段为 `field`、`artifact`、`consumer`、`read_purpose`、`validator_invariant`、`renderer_use` 和 `drop_condition`。首轮消费者限定为 semantic validator、eval、人工复审、renderer 和脚本；hook 只作为 future consumer，不支撑首轮必填字段。

首轮状态集合是候选词表，不是全仓状态标准。状态机合同用转移表表达：

| from | action | to | actor | required evidence | failure output |
| --- | --- | --- | --- | --- | --- |
| `draft` | `submit_review` | `ready_for_review` | 主 Agent | source marker、design anchor、审计范围 | `blocked` + 缺失字段 |
| `ready_for_review` | `approve` | `approved` | 人工复审或 verifier | review finding 处理记录 | `blocked` + finding 列表 |
| `approved` | `promote_plan` | `ready_for_plan` | 主 Agent | Task AC、文件边界、proving command 合同 | `blocked` + 计划缺口 |
| `implemented` | `verify` | `verified` | semantic validator + fresh command | 通过状态的 proving command | `blocked` + 失败证据 |
| `blocked` | `revise_design` | `draft` | 主 Agent | 阻塞原因和修正 diff | 保持 `blocked` |

Semantic invariant 至少覆盖三类约束：`design_anchors` 必须包含稳定 ID 与 source marker；`evidence_refs` 必须包含路径、hash、命令输出或 artifact 引用；`transition` 必须命中状态转移表。`verification-result.json` 记录 validator 名称、版本、输入 artifact、完整输出摘要和失败码。

`rendered_views` 记录派生视图路径以外，还记录 `source_artifact_id`、`source_artifact_hash`、`renderer`、`renderer_version`、`generated_at` 和 stale 判定。source artifact hash 变化后，旧视图只能作为历史快照，不作为当前事实源。

### 契约式引用

契约式引用是本设计的核心。它不是把正文拆到 `references/` 的排版技巧，而是让运行时模型知道何时读取外部材料、读取后服务哪个决策、如何证明读取有效。

课程核心契约包含三类信息：触发条件、读取对象和内容预期。本仓库在 `skill-optimizer` 中扩展三类工程字段：消费方式、证据要求和同步义务。六字段完整契约只用于关键 runtime reference，不扩展为所有 background reference 的通用强制 schema。

| 字段 | 含义 | 来源边界 | 失败表现 |
| --- | --- | --- | --- |
| 触发条件 | 哪个动作、判断或异常出现时读取 | C11 核心 | 模型不知道何时打开文件 |
| 读取对象 | 具体一层直达路径 | C11 核心 | 裸路径或深层链路导致遗漏 |
| 内容预期 | 读完必须获得的信息类型 | C11 核心 | 凭文件名猜测内容 |
| 消费方式 | 信息用于流程、输出、校验、prompt 还是脚本参数 | S/L 扩展 | 读了但没有影响决策 |
| 证据要求 | 输出中如何证明读取结果被使用 | S/L 扩展 | 只声称参考过 |
| 同步义务 | reference 变化后入口契约如何更新 | S/L 扩展 | 入口描述与文件内容漂移 |

推荐表达：

```markdown
当 {动作/判断/异常} 时：
→ 读取 `{path}` 获取 {内容预期}，用于 {消费方式}；输出需体现 {证据要求}；引用变化时同步 {同步义务}
```

模板和 Agent prompt 可使用轻量契约，但仍要包含用途和内容预期。普通背景材料无需强行扩展为完整契约；被 `SKILL.md` 路由到的关键 runtime reference 具备加载契约。

证据来源：C11/E1 课程渐进式披露与路由；E3 `Skill质量标准.md` D6；E5 本次 agent team 对 reference 机制的深化。

### 任务型 Skill 契约

任务型 Skill 或斜杠命令的核心是受控执行入口。它的质量不只看命令是否存在，还要看输入、上下文、权限、安全网和失败路径是否成组设计。

任务型 Skill 的审计对象包括：`argument-hint`、参数解析、缺参路径、错参路径、危险参数处理、动态上下文注入、`allowed-tools` 最小权限、manual-only 触发机制、hooks 边界和依赖不可用时的终止行为。

Skill 与 Command 的决策规则为：语义路由、按需知识加载、跨任务复用的能力进入 Skill；稳定、重复、参数明确、执行边界清楚的动作进入 Command 或任务型 Skill；具有副作用、权限敏感、外部写入或大范围修改风险的入口采用 manual-only；只提供方法、审计或解释的入口允许自动触发，但必须通过 description 限定场景。

参数与上下文注入按风险分层治理：`$ARGUMENTS` 适合自由文本参数，必须覆盖缺参、错参和危险参数样例；`$1/$2` 适合固定位置参数，必须有参数表与命令调用一致性证据；未消费参数追加属于兼容行为，输出中需要标明真实消费情况；`!command` 只用于稳定读取型上下文，不能承载重型逻辑或扩大权限；当 `!command` 或脚本输出受 `SLASH_COMMAND_TOOL_CHAR_BUDGET` 一类预算约束时，优先输出摘要，把长内容放进按需资源或结构化产物。

权限与 hooks 按职责收敛：read/review/audit/explain 默认只读；edit/refactor/fix 使用精确写权限；commit/deploy/delete 需要显式用户确认；script run 需要命令级白名单和参数校验；external API/MCP 需要凭据、超时和失败路径。hooks 是拦截、记录、校验或门禁，不替代 Skill 内的判断流程。

Legacy command compatibility 是 SO-MIGRATION-01 的一部分。迁移旧 `.claude/commands` 或斜杠命令时，设计需记录旧路径、触发词、参数注入方式、权限字段、兼容期行为、废弃条件和触发冲突验证。旧 command 与新 Skill 同时存在时，默认入口、手动入口和禁触发样例必须进入 eval。

权限 profile 冻结职责与工具边界：

| 模式 | 允许工具 | 禁止动作 | 确认合同 | 验证 |
| --- | --- | --- | --- | --- |
| read/review/audit/explain | 只读文件检索、只读 shell、只读浏览 | Edit/Write、写文件 shell、commit、delete、deploy、外部写 API | 用户要求修改时转入实施模式 | 工具权限静态检查 |
| edit/refactor/fix | 精确写范围、必要测试命令 | 未授权文件、无关重构、跳过验证 | 写范围和验证命令明确 | diff 边界与 fresh command |
| script run | manifest 白名单内命令 | 任意 shell、未校验参数、无超时命令 | 高风险参数需逐次确认 | manifest 校验与退出码 |
| commit/deploy/delete | 仅用户本轮授权的具体动作 | 复用历史批准、模糊目标、无回滚说明 | 动作名、目标、影响、回滚方式、用户本轮授权 | git 状态或发布前检查 |

Script manifest 是脚本准入合同。每个脚本至少记录脚本路径、允许参数、禁止参数、外部命令、超时、输出上限、退出码语义、失败消息和验证命令。参数进入 shell 前必须有 escaping 或参数数组策略；脚本输出超过预算时输出摘要和结构化引用。

Hooks lifecycle 属于后续工程化能力，首轮只作为审计维度。生命周期矩阵至少包含 `phase`、`trigger`、`input`、`allowed_action`、`output`、`failure_state` 和 `owner`。首轮发现状态流转只能由 hook 拦截时，结论为设计未闭合；替代门禁是 semantic validator、人工复审和 eval。

证据来源：E1 任务型 Skills 机制；E3 本仓库执行纪律与完成前验证；E4 官方 tool/resource 约束。

### Skill 与 SubAgent 组合契约

Skill 管 HOW：方法、规范、流程和判断框架。SubAgent 管 WHO/WHAT/WHERE/OUTPUT：由谁在独立上下文执行、执行什么、产出什么、如何回报。

引入 SubAgent 的理由不是任务复杂，而是需要独立上下文、并行分析、对抗审查、责任隔离或独立验收。组合关系必须写清主 Agent 的编排职责、子 Agent 的输入边界、输出格式、验收依据和冲突裁决方式。

Skill 与 SubAgent 有两条不同组合路径。显式 SubAgent 通过 `skills:` 预加载 Skill 时，Skill 内容在创建时全量注入，不是主会话的渐进式披露。Skill 通过 `context: fork` 派生子代理时，适合一次性、自包含、只需回传报告的独立任务；fork 子代理不能依赖主会话完整历史，`SKILL.md` 内容会成为任务指令的一部分。需要持续互动、共享历史或边看边改时，任务留在主 Agent。

Fork input contract 是隔离执行的前置合同，至少包含 `task`、`scope`、`input_refs`、`required_context`、`excluded_context`、`allowed_tools`、`expected_output` 和 `acceptance_basis`。主 Agent 负责把必要事实、约束和引用来源显式写入 input contract，不能让 fork 子代理自行推断主会话历史。

pipeline 形态使用阶段输出作为下一阶段输入。每个 handoff 至少包含 `scope`、`consumer`、`evidence`、`uncertainty`、`blockers`、`output_contract`、`acceptance_basis`、`decision_required` 和 `next_step`；pipeline 场景增加 `stage_id` 与 `input_from`。主 Agent 负责汇总、去重、证据标注和冲突裁决。agent team 挑战是高风险设计或复杂调研的本地用法，不是所有 SubAgent 输出的通用流程。

证据来源：E1 Skills 与 SubAgent 配合；E3 本仓库 agent-team-patterns 约束；E5 本次并行分析流程经验。

### 架构定位与模式选择

Skill 是 Agent 系统中的知识层，向下约束工具使用，向上服务任务执行。`skill-optimizer` 需要审计 Skill 是否选对模式，而不是只检查 Markdown 结构。

主要模式包括：

| 模式 | 适用条件 | 优化关注点 |
| --- | --- | --- |
| 模板驱动 | 输出结构稳定 | 模板字段、必填项和验收口径 |
| 脚本增强 | 确定性强、重复高、易出错 | 脚本参数、错误处理和验证命令 |
| 知识分层 | 高频骨架与低频细节混杂 | 主文件瘦身与契约式引用 |
| 工具隔离 | 有副作用、权限或安全风险 | 最小权限、确认点和失败路径 |

证据来源：E1 课程高级能力；E3 本仓库质量标准；E4 官方 bundled resources。

### Push/Pull 治理契约

全局硬规则适合 Push 到所有任务，场景化知识适合 Pull 到具体 Skill。`rules/`、`reference/` 和 `skills/` 的边界必须清楚，否则模型会在全局上下文和场景知识之间误取权威。

本仓库分层设计为：`rules/` 承载零容忍和 MUST 规则；`reference/` 承载共享技术真源；`skills/` 承载按需加载的工作方法；`contracts/` 承载跨 Skill 工作流契约。

证据来源：E1 开放标准与 Push/Pull 思想；E3 AGENTS.md 和 rules 运行时契约；E5 本仓库治理转译。

### 成熟度模型

Skill 质量不是单一合格线。`skill-optimizer` 需要识别 Skill 当前成熟度，并把优化建议约束在合适层级。

| 成熟度 | 定义 | 质量特征 |
| --- | --- | --- |
| SOP | 可按流程完成稳定任务 | 有入口、流程、输出和完成校验 |
| 专家系统 | 能处理分支、异常和反模式 | 有门禁、失败路径、证据要求和对抗机制 |
| 组织智能 | 能沉淀标准并指导其他 Skill 演化 | 有 eval、benchmark、迁移策略和跨 Skill 复用规则 |

成熟度判定不替代 L1/L2/L3。`skill-optimizer` 输出成熟度时采用证据匹配：只有入口、流程、输出、完成校验齐备时判为 SOP；在 SOP 基础上存在失败路径、反模式处理和证据化审计时判为专家系统；在专家系统基础上存在 eval、benchmark、迁移规则和跨 Skill 复用规则时判为组织智能。证据不足时输出“未判定”，不得用主观印象补齐。

证据来源：E1 课程架构定位；E3 本仓库 L1/L2/L3 质量标准；E5 成熟度映射。

## skill-creator 与 skill-optimizer 边界

| 能力 | skill-creator | skill-optimizer |
| --- | --- | --- |
| 从零创建 Skill | 主责 | 只提供质量约束输入 |
| 用户访谈与草稿 | 主责 | 审计草稿是否满足本仓库规范 |
| eval/benchmark | 主责 | 定义质量断言与解释结果 |
| description 优化 | 主责 | 检查触发契约和相邻冲突 |
| reference 组织 | 提供通用建议 | 主责，含契约式引用审计 |
| 本地 rules 对齐 | 参考 | 主责 |
| 反模式扫描 | 可辅助 | 主责 |
| 迁移既有 Skill | 辅助评估 | 主责 |

官方 `skill-creator` 是创建和验证工具，不是本仓库质量权威。`skill-optimizer` 是本地治理叠加层，不 fork 官方工具，不复制官方能力。

## new-skills 迁移形态

当前 `new-skills` 同时承担创建、改进和质量评级，职责与官方 `skill-creator` 重叠。新形态采用 `skill-optimizer` 命名，表达“优化已有或草稿 Skill”的主责。

迁移设计为：

- `shared/skills/skill-optimizer/` 承载新 Skill。
- `shared/skills/new-skills/` 保持兼容入口或转向说明，避免安装链路、文档链接和用户习惯断裂。
- `shared/reference/Skill质量标准.md` 继续作为 first-party 质量真源，并补强契约式引用、触发样例和成熟度模型。
- `new-skills/references/anti-patterns.md`、`prompt-engineering.md`、`resource-planning.md` 中仍有价值的部分迁入或被 `skill-optimizer` 契约式引用。
- `description-spec.md` 的触发规范转入触发契约审计，不再单独作为创建流程中心。

该迁移是本仓库设计决策，不是课程结论，也不是官方要求。它的依据是职责收敛、命名准确性和与官方 `skill-creator` 的边界清晰。

迁移采用并行共存策略。`skill-optimizer` 作为新的一等 Skill 新增并自动暴露给 Codex；`new-skills` 在兼容期保留为显式旧入口，语义收窄为 legacy compatibility，不再承担默认创建和优化入口。创建新 Skill 的默认入口是官方 `skill-creator`；优化已有或草稿 Skill 的默认入口是 `skill-optimizer`。

Codex 暴露模式为：`skill-optimizer` 提供 `agents/openai.yaml`，用于自动触发“优化 Skill、审计 Skill、改造 Skill 质量”类请求；`new-skills` 的 Codex adapter 在兼容期保留，但 default prompt 和描述必须指向 legacy 用途，降低与 `skill-creator`、`skill-optimizer` 的触发冲突。

文件落点为：新方法论和审计流程进入 `shared/skills/skill-optimizer/`；首轮目录以消费者为准，默认候选包括 `SKILL.md`、`agents/`、`rules/`、`references/`、`examples/`、`evals/`、`schemas/` 和 `scripts/`。`templates/`、`data/`、`INDEX.md` 或 `QUICKREF.md` 只有在存在稳定输出结构、静态数据或多级路由需求时创建。`hooks/` 只作为职责模型保留，首轮不创建 runtime hook，也不接入 `shared/hooks/registry.json`。旧 `new-skills/references/` 在兼容期不删除；被 `skill-optimizer` 复用的旧 reference 先通过契约式引用读取，只有在后续验证证明双份维护风险更低时才迁移内容。验证通过测试和 eval 完成。

安装与测试边界为：`install.sh`、Codex adapter 检查、runtime integrity、install smoke、systematic install、skill context budget 和 skill contract 测试都必须识别 `skill-optimizer` 与 legacy `new-skills` 的共存状态。任何删除旧入口、移除旧 reference 或改变 hook registry 的动作都属于后续阶段，不进入首轮实施。

JSON runtime artifact 只在 `skill-optimizer` 首轮试点，不要求 product、design、tech-lead、qa 等既有链路同步迁移。既有 Markdown templates 在首轮保持现状；`skill-optimizer` 产出的 Markdown/HTML 视图从 JSON artifact 派生。试点稳定后，再用 eval 和失败样本决定是否推广到其他链路。

逐文件迁移映射是 SO-MIGRATION-01 的实施前合同。每个候选文件记录源路径、目标路径、动作、消费端、兼容期行为、验证命令和回滚动作。

| 源路径 | 目标策略 | 动作 | 消费端 | 兼容期行为 |
| --- | --- | --- | --- | --- |
| `shared/skills/new-skills/SKILL.md` | `shared/skills/new-skills/SKILL.md` | keep + legacy 说明 | 用户旧入口 | 保留旧入口，描述收窄为 legacy |
| `shared/skills/new-skills/references/resource-planning.md` | 兼容期跨 Skill 引用 | link by contract | `skill-optimizer` resource 审计 | 首轮不复制，避免双份维护 |
| `shared/skills/new-skills/references/anti-patterns.md` | 兼容期跨 Skill 引用 | link by contract | `skill-optimizer` 反模式审计 | 首轮不复制，后续按验证决定迁移 |
| `shared/skills/new-skills/references/prompt-engineering.md` | 兼容期跨 Skill 引用 | link by contract | `skill-optimizer` prompt 审计 | 首轮不复制，标注退出条件 |
| `.claude/commands` 旧入口 | legacy command compatibility | keep or redirect | 任务型 Skill 迁移审计 | 记录触发词、参数注入、权限差异和废弃边界 |

首轮 vertical slice 只闭环只读审计链路：目标 Skill 读取、触发/加载/reference/权限诊断、证据等级输出、最小 eval 复跑、Markdown 派生报告。schema、semantic validator、renderer、benchmark、hook 集成和三件套 artifact 扩展需在最小闭环验证后进入后续批次。

## skill-optimizer 运行模型

`skill-optimizer` 读取一个目标 Skill 后，先判断输入边界和权威来源，再输出证据化诊断。诊断单位不是“章节是否齐全”，而是 Skill 运行链路中的契约是否闭合。

运行链路为：

```text
触发 → 加载 → 决策 → 执行 → 验证 → 演化
```

每个环节对应一组审计问题：

| 环节 | 核心问题 | 证据 |
| --- | --- | --- |
| 触发 | 模型何时加载此 Skill | description、触发样例、冲突 Skill |
| 加载 | 哪些内容内联，哪些按需读取 | SKILL.md 行数、resource 路由 |
| 决策 | 分支选择依据是否明确 | 流程条件、reference 契约 |
| 执行 | 工具、脚本、SubAgent 权限是否受控 | allowed-tools、scripts、agent prompt |
| 验证 | 完成结论是否基于 fresh evidence | 命令输出、文件证据、eval 结果 |
| 演化 | 改造收益如何复测 | benchmark、质量评分、迁移记录 |

输出以证据为中心：每个发现绑定目标文件、具体位置、问题类型、影响、证据等级和改造建议。没有证据的观点只能进入观察说明，不能进入 FAIL 结论。

Runtime artifact 采用决策规则而非固定三件套。首轮只实现一个最小 `skill-audit.json` 闭环，用于证明字段稳定、消费者真实、验证收益成立；`optimization-plan.json` 和 `verification-result.json` 保留为候选 profile，只有在最小闭环通过后扩展。

| artifact profile | 进入条件 | 首轮状态 |
| --- | --- | --- |
| `skill-audit.json` | 目标 Skill 审计需要结构化发现、证据等级、权限边界和 reference 契约 | 首轮最小闭环 |
| `optimization-plan.json` | 审计结果需要被 `tasks.md`/`plan.md` 机械消费 | 候选 profile |
| `verification-result.json` | schema、semantic validator、fresh command 和派生视图需要统一记录 | 候选 profile |

首轮候选字段包括 `artifact_type`、`schema_version`、`artifact_id`、`producer`、`inputs`、`status`、`design_anchors`、`evidence_refs`、`validation`、`transition` 和 `rendered_views`。字段进入 schema 的条件是字段消费矩阵通过；`rendered_views` 不反向成为事实源。

首轮候选状态词表为：`draft`、`blocked`、`ready_for_review`、`approved`、`ready_for_plan`、`implemented`、`verified`。状态词表只有通过状态转移表和 semantic invariant 验证后，才进入 runtime artifact schema。状态改变必须由 semantic validator 或人工复审记录证据；不得只改 `status` 字段表达流转。

E5 回退合同适用于 runtime artifact、状态机、renderer 和固定 dataset。若最小闭环无法证明消费者真实、语义校验稳定或质量收益成立，则 runtime fact source 回退为 Markdown 审计报告加 reference 证据表；schema HARD-GATE 撤回为审计建议；状态字段只保留观察用途；Markdown/HTML renderer 不进入下游消费链。回退后仍保留 source marker、设计锚点、验证命令和人工复审证据。

## 调研到实施追踪契约

后续实施必须保留从调研结论到代码与文档变更的可追踪链路。`design.md` 是方法论裁决源，`tasks.md` 是验收单一真源，`plan.md` 是执行路径。三者之间必须能互相追溯，防止实现阶段只完成文件改名或格式调整，而遗漏 Harness 治理目标与外部信息来源转译。

追踪链路定义为：

```text
source-notes.md source map → 证据等级 → 设计裁决 → Task AC → Plan step → 文件 diff → fresh proving command
```

`tasks.md` 中每个验收项必须绑定至少一个稳定设计锚点，格式为 `Design anchor: {SO-*} / {source marker} / {证据等级}`。若某个设计锚点不进入实施任务，`tasks.md` 必须写明不实施理由和保留位置，禁止静默遗漏。

`plan.md` 中每个 Task 必须列出对应文件边界、具体改动、验证命令和预期输出。涉及方法论转译的改动必须说明它覆盖的运行链路环节：触发、加载、决策、执行、验证或演化。

最终交付报告必须包含设计覆盖表，按设计章节列出实现文件、验证命令和结果。没有覆盖表时，不能声明本次改造贯彻了调研结果。

`tasks.md` 的每个 AC 必须包含四个字段：`Design anchor`、`Verification method`、`Fresh proving command`、`Pass/Fail condition`。`plan.md` 的每个 Task 必须包含四个字段：`Files`、`Change boundary`、`Verification command`、`Expected output`。只改名称、只改格式或只移动文件的任务不能单独通过；它必须绑定至少一个运行链路环节，并通过对应验证证明语义已承接。涉及 `rules/`、`references/`、`examples/`、`evals/`、`schemas/`、`scripts/`、`hooks/`、`assets/` 或 `agents/` 的任务必须写清目录职责边界。

运行时语义变更必须配套 contract test。无法机械验证的判断必须进入人工复审矩阵，并在最终覆盖表中标注为人工证据。人工证据不能替代已有自动化测试。

本追踪契约的硬化来源是 E3 本仓库执行纪律、文档管理和完成前验证；runtime artifact 字段链路属于 E5 试点。实施计划只能把 E3 部分写成阻塞性验收，E5 部分需要实验样例和回退合同。

首轮 proving command 集合在 `tasks.md` 前冻结。命令合同至少包含 `command_id`、命令文本、输入 fixture、预期退出码、预期输出、失败归属和替代人工证据规则。首轮命令类别包括：静态结构检查、frontmatter/adapter 检查、schema validation、semantic validation、eval runner、install smoke、skill contract 检查和文档禁止词扫描。尚不存在的命令必须成为独立 Task，不能用概念型验证替代。

## 质量维度扩展

现有 `Skill质量标准.md` 的 D1-D7 保留。`skill-optimizer` 在审计时增加以下维度，作为 D6、D7 和 L3 的扩展输入：

| 扩展维度 | 目的 |
| --- | --- |
| 触发样例矩阵 | 验证 description 路由精度 |
| 相邻 Skill 冲突 | 防止多个 Skill 同时适配同一请求 |
| 契约式引用完整性 | 防止裸路径、误读和入口漂移 |
| 失败路径覆盖 | 防止缺参、错参、权限不足时继续执行 |
| SubAgent 边界 | 防止把协作复杂度塞进单一 Skill |
| 平台特定性标注 | 区分 Claude/Codex/本仓库专用字段 |
| Push/Pull 分工 | 防止全局规则和场景知识混杂 |
| eval 与验收样例 | 防止仅凭主观阅读判断质量 |
| 成熟度评级 | 区分 SOP、专家系统和组织智能 |
| 演化记录 | 连接改造前后证据 |

这些维度不直接替代 L1/L2/L3，而是为评级提供更细的证据。硬门禁仍由 `rules/` 和 `Skill质量标准.md` 决定。

## 契约式引用详细规范

`skill-optimizer` 对 reference 引用进行四类判定：

| 判定 | 定义 | 处理 |
| --- | --- | --- |
| 完整契约 | 有触发条件、路径、内容预期、消费方式、证据要求和同步义务 | 通过 |
| 轻量契约 | 模板或 Agent prompt 有用途与字段概述 | 通过 |
| 弱契约 | 有路径和用途，但缺少内容预期或证据要求 | 输出改造建议 |
| 裸引用 | 只有路径、文件名或“详见” | 标记为质量问题 |

同步义务只对关键 runtime reference 强制。背景说明、一次性调研来源和历史注释不强制写同步义务；进入 `SKILL.md` 路由、影响判断、影响权限或影响验证的 reference 必须写明入口描述、Quick Reference、eval 样例或 schema 消费端如何同步。

完整契约示例：

```markdown
当评估 Skill 是否需要拆分 reference 时：
→ 读取 `shared/skills/new-skills/references/resource-planning.md` 获取 scripts/references/assets 判定表，用于首轮兼容期资源归属判断；输出需列出每类资源的采用或不采用理由；迁移完成后同步到 `skill-optimizer` 的 Quick Reference 路由。
```

这个示例的关键不是句式，而是运行时可检查：触发点清楚、路径直达、预期明确、消费方式明确、输出证据明确。

## 平台兼容设计

Skill 内容分为核心知识层、平台适配层、分发发现层和外部依赖层。`skill-optimizer` 审计时不把平台特定字段视为坏味道，但要求标注用途、消费端、迁移影响和失败路径。

| 层 | 示例 | 处理原则 |
| --- | --- | --- |
| 核心知识层 | 流程、方法论、质量标准、反模式 | 放在 `SKILL.md` 或 `reference/`/`references/`，离开原平台仍可理解 |
| 平台适配层 | `user-invocable`、`allowed-tools`、hooks、`context: fork`、`agents/openai.yaml` | 标注 Claude、Codex 或本仓库消费端 |
| 分发发现层 | registry、skills marketplace、git、plugin、安装脚本 | 记录安装、更新、版本、namespace 和兼容入口 |
| 外部依赖层 | API、MCP、凭据、二进制、系统命令 | 写明依赖、超时、失败路径和替换边界 |
| 本仓库运行时规则 | `rules/`、`contracts/`、AGENTS、全局 reference | 优先级高于外部指南 |

跨平台不是去除本地特化，而是把特化边界写清，避免迁移时误判。自包含优先约束核心知识层；平台适配、分发发现和外部依赖可以存在，但必须有消费者、兼容说明和失效边界。

发现范围与命名空间矩阵用于审计安装、触发和迁移冲突：

| 范围 | 审计问题 | 冲突信号 | 验证 |
| --- | --- | --- | --- |
| Personal | 用户级 Skill 是否与项目 Skill 同名或同触发 | 同名、相同 `description`、相邻触发样例冲突 | profiles/skills 列表和触发样例 |
| Project | 仓库内 Skill 是否覆盖当前任务范围 | AGENTS/rules 与 Skill-local rules 冲突 | 项目路径和 source marker |
| Enterprise | 组织级 Skill 是否覆盖本地 Skill | 全局默认入口抢占本地入口 | 安装来源和 namespace |
| Namespace | `skill-creator`、`skill-optimizer`、legacy `new-skills` 是否互相抢入口 | 名称、别名、manual entry 冲突 | adapter 描述和触发 eval |
| Monorepo | 多包、多目录 Skill 是否共享一套 rules/reference | 相对路径、安装路径、source map 断链 | install smoke 和路径解析 |

自包含程度分级用于判断迁移风险：

| 等级 | 定义 | 迁移判定 |
| --- | --- | --- |
| S0 核心知识自包含 | `SKILL.md` 和按需资源离开原平台仍可理解 | 可迁移核心方法论 |
| S1 平台适配明确 | frontmatter、adapter、hooks、agent 字段标明消费端 | 可迁移但需替换 adapter |
| S2 外部依赖受控 | API、MCP、凭据、二进制、系统命令有失败路径和替换边界 | 迁移前需依赖替代方案 |
| S3 强平台耦合 | 迁移后需要重写核心流程或执行逻辑 | 不作为通用 Skill 分发 |

依赖可迁移性矩阵记录 API、MCP、凭据、二进制和系统命令的来源、超时、错误处理、降级边界和替代实现。缺少替代边界的外部依赖只能留在平台适配层，不能写进核心知识层。

## 验证设计

设计完成后的有效性验证分为四类：

| 验证类型 | 验证对象 | 证据形式 |
| --- | --- | --- |
| 静态结构验证 | 文件存在、frontmatter、引用契约、行数、目录层级 | shell/rg 输出 |
| Runtime 合同验证 | schema validation、semantic validation、状态机、rendered view 来源 | JSON validator 输出 |
| 行为样例验证 | 触发/不触发、失败路径、输出契约 | eval prompt 与人工/脚本评分 |
| 改造收益验证 | 改造前后质量变化 | skill-creator benchmark、token、pass rate、diff |

验证设计遵守本仓库“完成 = 验证通过”的铁律。没有 fresh proving command 输出时，不声明改造完成。

`evals/` 是 `skill-optimizer` 的本地策略目录，创建条件是存在 eval consumer、fixture、复跑命令和结果 artifact。该 Skill 的价值需要通过行为样例和前后对比验证；`evals/` 不替代仓库测试。目录创建本身不作为验收目标。

`schemas/` 是 `skill-optimizer` 在采用 runtime artifact 试点时的本地策略目录，创建条件是存在 runtime artifact、字段消费者、schema validation 和 semantic validation。首轮验证同时包含 schema validation 和 semantic validation：schema validation 证明字段形状正确；semantic validation 证明状态、证据、设计锚点、fresh proving command 和流转条件一致。`status=verified` 但缺少通过状态的 proving command 属于语义失败。

Markdown/HTML 派生视图的验证只证明渲染成功，不证明 runtime artifact 有效。下游 Skill、script 和未来 hook 读取 JSON artifact，不解析 Markdown/HTML 做关键流转判断。

最小验证矩阵包含五类样例：触发、非触发、相邻 Skill 冲突、缺参/错参/权限不足、格式诱导。触发矩阵的首轮 seed dataset 采用 5 个应触发样例、5 个不触发样例和 3 个相邻 Skill 冲突样例，用于启动对比，不作为跨 Skill 统一硬门槛。reference 矩阵覆盖关键 reference 的触发条件、读取对象、内容预期、消费方式和证据要求。失败路径矩阵覆盖缺参、错参、危险参数、权限不足和依赖缺失。

Seed dataset 是可复测合同，不是样例数量口号。每条 case 至少包含 `case_id`、`category`、`input`、`expected_decision`、`target_skill_ref`、`neighbor_skill_refs`、`evaluator`、`run_command`、`baseline_result_ref`、`after_result_ref` 和 `pass_fail_condition`。target 与 neighbor 需要记录文件 hash 或版本标识，避免前后对比更换样本。

验证边界矩阵区分机械证据、人工证据和替代关系：

| 验证通道 | consumer | artifact | fresh command | 阻塞范围 | 不替代 |
| --- | --- | --- | --- | --- | --- |
| 静态结构 | install/test scripts | 文件树、frontmatter、adapter | install smoke、contract check | 安装和发现 | 行为 eval |
| schema validation | validator | runtime artifact | schema validator | 形状合同 | semantic validation |
| semantic validation | validator + 人工复审 | runtime artifact + evidence refs | semantic validator | 状态、证据、流转 | fresh proving command |
| skill-creator eval | eval runner | dataset + run artifacts | eval runner | 触发和输出行为 | install smoke、仓库测试 |
| 人工复审 | reviewer | review report | 复审记录 | 主观判断项 | 机械验证 |
| benchmark | benchmark runner | baseline/after artifacts | benchmark command | 收益对比 | correctness gate |

可用性门槛采用 5/10/30 分钟模型：5 分钟内能判断目标 Skill 是否适合使用 `skill-optimizer`；10 分钟内能产出含证据等级和设计锚点的诊断；30 分钟内能完成一个小型 Skill 的优化计划、验证命令和覆盖表。该模型是可用性验收门槛，不作为质量收益的唯一证明。

质量收益验证采用前后对比，但 token 和耗时只作为辅助信号。主要信号是触发误判减少、reference 契约证据完整、runtime artifact 字段稳定、失败路径覆盖提升、人工复审发现减少和 contract test 通过。

Benchmark protocol 使用同一目标 Skill、同一 dataset、同一模型和运行面、同一评分器、同一随机性控制和同一复跑命令。收益阈值按四类记录：触发准确、失败路径覆盖、reference 契约完整、contract test 通过。token 和耗时只进入辅助指标，不能单独证明质量收益。

5/10/30 是人工可用性 eval protocol：使用固定小型 Skill fixture、固定任务说明、固定允许资源、记录开始和结束时间、输出 artifact、失败类别和复审人。它只影响可用性结论，不单独触发质量收益通过。

## 风险与裁决

| 风险 | 裁决 |
| --- | --- |
| 把课程归纳误写成课程原意 | 每条关键规则标证据等级，E5-only 不写 MUST |
| 把 `skill-optimizer` 做成格式检查器 | 以运行链路契约为主，Markdown 结构只作为证据之一 |
| 与官方 `skill-creator` 职责重叠 | 创建和 eval 主流程归官方，本地工具负责质量治理 |
| 重命名破坏引用链 | 采用兼容入口或转向说明，安装链路验证后再收敛 |
| reference 契约过重 | 只对关键 runtime reference 强制完整契约，模板和 prompt 允许轻量契约 |
| 规则过度硬化 | E3 规则优先，E1/E2 经本仓库验证后进入硬门禁 |
| JSON 格式崇拜 | 以 runtime information 合同为核心，JSON 只是承载格式 |
| JSON 退化为长文本容器 | 关键判断进入结构化字段，长文本通过 ref/path/hash 引用 |
| schema 只校验形状 | schema validation 与 semantic validation 分层，状态与证据不一致时失败 |
| 派生视图反向污染真源 | Markdown/HTML 只从 JSON 渲染，不作为下游事实源 |

## 设计裁决

`skill-optimizer` 是本仓库 Skill 治理的质量优化层。它的核心竞争力不是创建更多 Skill，而是让已有 Skill 的触发、加载、引用、执行、验证和演化可审计、可复测、可迁移。

本次改造采用 Harness Engineering 作为系统诊断框架，采用官方 `skill-creator` 作为创建与评估工具，采用本仓库 `rules/` 与 `Skill质量标准.md` 作为质量权威，采用极客时间课程 7 讲作为 Skill 方法论来源。组合后的首要设计锚点是“契约闭环”：每个 Skill 都要说明何时触发、加载什么、如何决策、如何执行、如何证明完成、如何基于证据继续演化。

Harness 方向的设计裁决是：`skill-optimizer` 首轮采用 Runtime Info Contract 试点。凡是参与流程、状态、验证、拦截、统计、回放或下游消费的信息，进入 JSON runtime artifact 并受 schema 与 semantic validator 约束；Markdown/HTML 作为派生视图服务人类阅读。该试点不直接替换全仓 Markdown templates，先证明 LLM 稳定性和流程可验证性收益，再决定是否推广。
