# anthropics/skills 调研报告

日期基线：`2026-04-01`

## 1. 当前结论

### 1.1 一句话判断

`anthropics/skills` 的本质不是“官方最佳实践大全”，而是 Anthropic 对 Agent Skills 的**参考实现 + 示例技能集合 + 插件分发入口**。它真正解决的是：通用 agent 能做很多事，但**不能稳定地按某个专业流程、组织规范和工具链去做事**。

### 1.2 对本仓库的直接结论

对 `org-claude-skills` 来说，最值得学习的是：

- `SKILL.md + scripts/ + references/ + assets/` 的分层封装方式
- 渐进式加载（progressive disclosure）
- 真实任务驱动的 skill 评测与迭代
- 作为“分发层”的 plugin / marketplace 组织方式
- 引入 skill 时的信任边界、冲突治理、权限控制

最不该直接照搬的是：

- 把 Anthropic 官方示例仓库当作你们的 canonical runtime
- 把 Claude-first 的触发与分发假设直接写进跨 Claude/Codex 的统一真源
- 把“skill 数量增长”误当成“组织能力增长”

### 1.3 当前推荐

- `can-adopt`：结构分层、评测方法、脚本设计规范、分发适配层
- `adopt-with-guardrails`：plugin / marketplace 打包、`.agents/skills/` 兼容导出
- `should-not-copy`：整仓结构、示例技能目录划分、Claude 专属分发假设

## 2. 项目上下文画像

本次判断不是脱离你们仓库做的抽象分析，而是基于当前仓库扫描结果：

- `[README.md](/Users/lijieli/org-claude-skills/README.md)` 明确定位为 Claude Code 与 Codex CLI 的统一运行资产仓库，包含 `skills / rules / reference / hooks / agents`
- `[README.md](/Users/lijieli/org-claude-skills/README.md)` 明确采用 `superpowers` 作为方法论基线，并通过 `small-chain` 做本地编排
- 当前仓库有 `23` 个 `shared/skills/*/SKILL.md`，另有 `10` 个 `community/superpowers/skills/*/SKILL.md`
- `[docs/best-practice-implementation-plan.md](/Users/lijieli/org-claude-skills/docs/best-practice-implementation-plan.md)` 已经把“工件语义、执行收口、task 真源、verify 门禁、archive 闭环”设计为你们自己的治理体系
- `[shared/skills/new-skills/references/resource-planning.md](/Users/lijieli/org-claude-skills/shared/skills/new-skills/references/resource-planning.md)` 已明确写明借鉴官方 `skill-creator` 的早期流程

因此，本仓库的核心问题不是“要不要有 skills”，而是：

1. 如何把 skill 设计得更稳、更省 token、更可验证
2. 如何把 skill 的**标准层 / 真源层 / 平台适配层 / 分发层**拆得更清楚
3. 如何避免引入一个更偏 Claude-first 的官方示例仓库后，反而冲淡你们已有的跨运行时治理结构

## 3. 调研对象拆解

### 3.1 `anthropics/skills` 仓库是什么

基于 `/tmp/anthropics-skills` 本地克隆与官方 README，可确认：

- 仓库最新提交基线：`2026-03-25`
- 顶层目录包含 `skills/`、`spec/`、`template/`、`.claude-plugin/`
- `.claude-plugin/marketplace.json` 把内容分成 `document-skills`、`example-skills`、`claude-api` 三个插件集合
- `skills/` 下共有 `17` 个技能目录
- 其中 `8` 个带 `scripts/`
- `2` 个带 `reference` / `references`
- `1` 个带 `assets/`

这说明它不是简单的“提示词样例仓库”，而是一个明确支持：

- 技能封装
- 示例展示
- 插件化安装
- 渐进式上下文加载

的实际分发仓库。

### 3.2 它解决什么问题

核心问题可以拆成 4 个层次：

1. `任务稳定性`
通用模型会写、会答、会推理，但对“组织特定流程”往往不稳定。Skills 的目标是把这些流程打包成可重复使用的能力。

2. `上下文成本`
把所有流程和知识都塞进 system prompt 或长期 memory，会造成上下文污染。Skills 通过目录化和按需读取，把大部分知识从常驻上下文中移走。

3. `可复用性`
同样的领域流程不该在每次会话里重新解释。Skills 把说明、脚本、模板、资源变成可复用单元。

4. `能力扩展`
LLM 会推理，但很多稳定动作更适合交给脚本。Skills 允许把“模型擅长判断，脚本擅长执行”的组合固化下来。

### 3.3 典型适用场景

- 高重复、步骤稳定、输入输出边界较清晰的任务
- 依赖组织规范、风格、模板、专有流程的任务
- 需要脚本增强确定性的任务
- 需要按需加载大体量参考知识的任务

Anthropic 自己在仓库中展示的场景包括：

- 文档生成与编辑：`docx` / `pdf` / `pptx` / `xlsx`
- 工程能力：`mcp-builder` / `webapp-testing`
- 组织流程：`brand-guidelines` / `internal-comms`
- 技能开发本身：`skill-creator`

## 4. 核心机制

### 4.1 渐进式加载

Agent Skills 官方文档把技能机制拆成 3 层：

1. catalog：只暴露 `name + description`
2. instructions：激活后再加载完整 `SKILL.md`
3. resources：仅在需要时加载 `scripts / references / assets`

这个机制直接解决了“技能多了以后上下文撑爆”的问题。

### 4.2 封装单元不是纯文档

技能目录里的内容可以是：

- `SKILL.md`：触发元数据 + 核心流程
- `scripts/`：确定性动作
- `references/`：按需知识
- `assets/`：模板、资源文件

也就是说，skill 不是 prompt snippet，而是一个**面向 agent 的可组合能力包**。

### 4.3 分发层与治理层分离

`anthropics/skills` 通过 `.claude-plugin/marketplace.json` 把 skill 组织成插件集合。这是分发层的设计，不等于治理层设计。这个差别很关键：

- 分发层回答“怎么装、怎么发现、怎么启用”
- 治理层回答“什么是组织真源、如何验收、如何回滚、怎么跨端适配”

## 5. 支持性判断

### 5.1 最强支持证据

`anthropics/skills` 值得认真研究，不是因为它“官方”，而是因为它把很多 agent 工程里的真实矛盾拆得很实：

- README 明确说这些 skills 是动态加载的 instructions / scripts / resources
- README 明确把仓库定位为示例与参考，而不是对 Claude 实际行为的硬保证
- `skill-creator` 不是只教“怎么写 skill”，而是直接把 baseline 对比、eval、用户反馈迭代写成流程
- `webapp-testing` 强调“先跑 `--help`，把脚本当黑盒，而不是先读大脚本源码”，这很符合 token 成本与 agent 使用习惯
- `mcp-builder`、`docx` 等技能把“模型判断 + 脚本执行 + 参考知识”组合在一起，说明这套机制并不是停留在营销层

### 5.2 为什么这对你们有帮助

你们已经有成熟的流程技能体系，但仍然存在 3 个提升点：

1. `结构进一步瘦身`
你们不少技能已经包含 `references/`、`scripts/`、`agents/`，但 Anthropic 这套模式对“主文档尽量短、资源尽量外置”的纪律要求更直接。

2. `skill 评测更系统`
官方 `skill-creator` 把“with-skill vs baseline”写成显式比较流程，这比只看主观感觉更适合长期维护。

3. `分发层可以单独抽象`
你们的 `shared/` 真源与 `claude/`、`codex/` 适配层已经有雏形。Anthropic 仓库说明：再往前走一步，可以把“安装 / 打包 / 发布”作为独立层，而不是让真源目录直接承担分发责任。

## 6. 反方挑战

本节不是“平衡观点”，而是对关键判断做对抗式拆解。

### 6.1 工程治理反方

**反方论点：`anthropics/skills` 很容易让团队把“官方示例与分发层”误当成“组织治理真源”。**

#### 成立条件

- 直接照搬官方目录和分发方式
- 没有自己的版本锁定、测试、验收、兼容层
- 让 platform-specific frontmatter 与平台触发语义上升为 canonical
- skill 数量快速增长，但没有命名边界、优先级、冲突策略

#### 为什么这个反方是强的

Agent Skills 官方实现文档自己就把这些问题列出来了：

- skills 的扫描范围要分 scope
- 同名 skill 要处理 name collision
- 要有 trust considerations
- 要做 permission allowlisting
- 激活后还要做 context protection、去重、持续管理

这说明技能体系不是“多放几个目录”就成立，而是天然会带来治理问题。

#### 失效边界

如果你们只是吸收以下模式，而不把官方仓库当真源，这个反方就会变弱：

- `SKILL.md + scripts + references`
- eval-first
- 分发层独立
- `.agents/skills/` 兼容导出
- 插件打包仅作为 adapter / distribution

### 6.2 组织 adoption 反方

**反方论点：skills 不会自动让团队更稳定，它只是把流程知识打包。**

#### 成立条件

- 任务本身不重复
- 流程经常变
- 输出质量难验证
- 没有 owner / eval / 生命周期管理
- 只追求“沉淀了文档”，不追求实际使用频率与效果回收

#### 为什么这个反方是强的

Anthropic 官方最佳实践明确强调：

- 好的 skills 要简洁、结构化、经过真实使用测试
- 要观察技能是否真的被触发、是否真正改善结果
- 如果 agent 本来就能很好完成任务，skill 可能根本没有增量价值

这直接否定了“多写 skill 就会更稳定”的乐观叙事。

#### 失效边界

以下条件越满足，skills 越可能带来真实收益：

- 高频任务
- 清晰边界
- 可验证输出
- 可脚本化流程
- 有 owner
- 有回归评测

### 6.3 安全 / 信任边界反方

**反方论点：引入 skill 不是只引入文档，而是在引入可执行行为包。**

#### 成立条件

- skill 带脚本、外部依赖、MCP 或远程资源
- 来源不可信
- 没有版本锁定
- 没有权限最小化
- 组织范围共享但无审计

#### 为什么这个反方是强的

Agent Skills 实现文档明确强调 trust considerations、permission allowlisting、cloud-hosted / sandboxed 差异处理；脚本设计文档又明确要求：

- 无交互
- 固定版本
- 结构化输出
- 可重试 / 幂等
- 有清晰 exit code

这意味着 skill 设计已经进入“受控执行链”的范畴，而不只是 prompt engineering。

#### 失效边界

如果只从可信源安装，并在内部做到：

- source pin
- 审计后启用
- 最小权限
- 小范围试点
- 失败可回滚

那这类风险是可控的。

## 7. 优点与缺点

### 7.1 优点

- 把“领域知识 + 流程 + 工具”封装成可复用能力单元
- 通过渐进式加载降低上下文成本
- 鼓励把确定性动作外置到脚本，提升稳定性
- 适合版本管理和团队共享
- 适合作为插件或 marketplace 的分发载体
- 开放标准化方向有利于跨产品复用

### 7.2 缺点

- 触发描述写得不好，会 under-trigger 或误触发
- skill 太多、边界重叠时，治理复杂度快速上升
- 真正有效需要评测、owner、回收机制，维护成本不低
- 带脚本后安全与依赖治理问题会显著上升
- 示例仓库容易被误读成“组织级最佳实践真源”
- 平台专有实现细节不适合直接做跨端 canonical

## 8. 对本仓库的帮助判断

### 8.1 `must-keep`

- 继续保持你们自己的 `shared/` 真源 + `claude/` / `codex/` 适配层架构
- 继续保持 `rules / reference / hooks / contracts / tests` 作为治理骨架
- 继续把执行方式、验收方式、工件语义放在你们自己的规范体系里

### 8.2 `can-adopt`

- 在所有新 skill 中强化“主文件短小、长文档外置、脚本黑盒化”的纪律
- 对高价值技能建立 `with-skill vs baseline` 评测
- 为分发层增加 `.agents/skills/` 或 plugin marketplace 的导出能力
- 在安装与启用链路中补充 name collision / trust / permission 规则
- 为脚本定义统一 agent-friendly 规范：无交互、版本固定、结构化输出、幂等、清晰错误码

### 8.3 `should-not-copy`

- 不把 `anthropics/skills` 的仓库结构直接作为你们的 source of truth
- 不把官方 creative / demo 型 skill 目录划分当作你们的能力分类
- 不把 Claude 专属安装方式、插件命令、frontmatter 假设直接扩散到 Codex 侧
- 不以“技能数量”作为建设成果指标

## 9. 可学习的最佳实践

### 9.1 技能结构

- `name` / `description` 只承担发现与触发责任，写得短、准、边界清晰
- `SKILL.md` 主体只放流程骨架、决策点、边界与入口
- 大块参考知识放 `references/`
- 可重复执行逻辑放 `scripts/`
- 模板与静态资源放 `assets/`

### 9.2 技能验证

- 用真实任务做测试，不靠作者主观判断
- 先跑 baseline，再跑 with-skill，对比质量、耗时、token
- 观察触发是否准确、是否过度触发、是否遗漏关键步骤
- 迭代 description，而不是只迭代正文

### 9.3 脚本设计

- 先提供 `--help`
- 不要交互式输入
- 版本固定
- stdout 输出结构化数据，stderr 输出诊断信息
- 支持幂等、dry-run、明确退出码

### 9.4 分发与治理

- skill 发现范围分 scope
- 处理同名冲突
- 激活时做权限 allowlist
- 保护 skill 上下文不被压缩丢失
- 分发层独立于真源层

## 10. 建议的下一步

### 10.1 低风险动作

1. 选 3 个高频 skill，审查是否可按 `SKILL.md / references / scripts` 再瘦身
2. 为其中 1 个 skill 建立 baseline 对比评测
3. 定义内部“agent-friendly 脚本规范”

### 10.2 中期动作

1. 设计 `shared/` 真源到 `.agents/skills/` 与平台插件目录的导出链
2. 为 skill 安装 / 启用链路补 trust、collision、scope 规则
3. 把“分发层”从“真源层”中概念上彻底拆开

### 10.3 不建议的动作

- 直接 fork `anthropics/skills` 当你们的基础仓库
- 把 Anthropic 示例 skill 当成组织级规范
- 在没有评测和 owner 的情况下批量扩 skill

## 11. 主要证据源

- Anthropic 官方仓库：<https://github.com/anthropics/skills>
- Anthropic 工程文章：<https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills>
- Claude Skills 最佳实践：<https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices>
- Claude Skills 创建与使用说明：<https://support.claude.com/en/articles/12512198-how-to-create-custom-skills>
- Agent Skills 主页：<https://agentskills.io/home>
- Agent Skills 规范：<https://agentskills.io/specification>
- Agent Skills 客户端接入指南：<https://agentskills.io/client-implementation/adding-skills-support>
- Agent Skills 脚本指南：<https://agentskills.io/skill-creation/using-scripts>

## 12. 待确认项

- 是否要把本文结论进一步收敛为一份 `must-keep / can-adopt / should-not-copy` 的实施清单
- 是否要继续做第二轮分析：把你们现有技能体系逐个映射到 Agent Skills 的结构模式，找出最值得先改的 3 个 skill
