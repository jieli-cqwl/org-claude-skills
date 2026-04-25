# Oh My Codex 调研报告

> 调研模式：discovery
> 呈现模式：understanding
> 调研时间：2026-04-13
> 默认主候选：`Yeachan-Heo/oh-my-codex (OMX)`

## 这是什么
- 当前对象：社区里常被简称为 `Oh My Codex` / `OMX` 的一组 Codex 增强层项目，其中默认主候选是 GitHub 上的 `Yeachan-Heo/oh-my-codex`。
- 一句话定义：它不是新的模型，也不是 OpenAI 官方 Codex 本体，而是套在 `OpenAI Codex CLI` 外面的一层工作流和运行时增强层。
- 最容易混淆的相近对象：
  - 它不等于官方 `Codex CLI`。
  - 它不等于单个 skill 或单个 prompt 包。
  - 它也不只有一个实现分支；截至 2026-04-13，至少存在一个高热度的 Node/tmux/hooks 路线和一个较小的 Python/multi-agent 路线。

## 直接结论
- 如果你朋友给你发的是现在社区里最火的那个 `Oh My Codex`，大概率指的是 `Yeachan-Heo/oh-my-codex` 这条线。
- 它的核心价值不是“替代 Codex”，而是把 Codex 变成一个更重流程、更强编排、更适合多人/多 agent/长流程任务的操作层。
- 它适合已经习惯终端、想把需求澄清、规划、并行执行、状态沉淀、hooks、tmux/team runtime 一起打包的人。
- 它不适合“我只想先把原生 Codex 用明白”的新手，也不适合不想让工具改动 `.codex/config.toml`、`.codex/hooks.json`、本地工作流的人。

## 为什么值得关注
- 关键价值：它试图解决原生 Codex 在“长任务、多人协作、并行 agent、工作流复用、状态沉淀”上的摩擦，而不是单纯再包一层命令别名。
- 为什么现在值得看：截至 2026-04-13，主线仓库已经有 `22k stars / 1.9k forks / 84 releases`，活跃度和传播度都明显高于一般实验性小项目。
- 谁最需要理解它：
  - 重度使用 `Codex CLI` 的个人开发者
  - 想把 Codex 变成“带流程的执行系统”的团队
  - 对 `hooks / AGENTS / worktrees / tmux / multi-agent orchestration` 感兴趣的人

## 如果只记住三件事
- `Oh My Codex` 的本质是“Codex 上层操作系统/工作流层”，不是另一个模型。
- 社区里至少有两条同名路线，朋友发给你的具体链接比名字本身更重要。
- 主线项目很强也很重，它会介入你的 `hooks / AGENTS / skills / config / worktree / tmux` 习惯，不是零侵入工具。

## 对象定位概览
- 原始词条：`Oh My Codex`
- 词条类型假设：repo / package / CLI workflow layer
- 需要回答的问题：
  - 它到底指哪个对象
  - 是否存在多个同名实现
  - 默认应该把哪一个视为主候选

## 当前映射与判断
- 当前命中对象：`Yeachan-Heo/oh-my-codex`，命令入口 `omx`
- 判定：命中
- 关键理由：
  - 名称、仓库名、官网文档、CLI 命令、安装命令、介绍语全部一致
  - GitHub 星标、release、文档站、Discord 社区都指向同一对象
  - 官方自述明确说明它是 `OpenAI Codex CLI` 的 workflow layer，并且命令就是 `omx`
- 结论稳健性：高
- 翻案条件：
  - 你朋友实际发来的链接是 `pip install oh-my-codex` 或 `junghwaYang/oh-my-codex`
  - 你朋友讨论的是 Python/Agents SDK 那条线，而不是 Node/tmux/hooks 主线

## 候选解析与排除理由

### 保留
| 候选 | 保留理由 | 还缺什么证据 |
|------|---------|-------------|
| `Yeachan-Heo/oh-my-codex` | GitHub 主仓、官网文档、安装命令、Discord、release 历史都闭环一致；热度远高于其他候选 | 如果要百分百定案，最好看你朋友发来的原始链接 |
| `junghwaYang/oh-my-codex` / PyPI `oh-my-codex` | 同名、同样使用 `omx` 命令、同样面向 Codex CLI，多 agent 定位明确 | 需要看朋友发的是 `npm` 还是 `pip` 路线，才能判断他到底指哪条线 |

### 排除
| 候选 | 排除理由 |
|------|---------|
| 当前工作区 `org-claude-skills` | 本地预扫描没有出现 `Oh My Codex` 命名；这是一个统一维护 `Claude Code / Codex CLI` skills、rules、hooks、agents 的仓库，不是 `Oh My Codex` 本体 |
| “官方 Codex 新功能” | `Oh My Codex` 明确自称是 `OpenAI Codex CLI` 的上层 workflow layer，不是官方产品名称 |

## 主候选深度分析：`Yeachan-Heo/oh-my-codex (OMX)`

### 核心机制
- 解决什么问题：
  - 解决“原生 Codex 可以做事，但在复杂流程、并行执行、统一套路、状态沉淀、团队协同上不够顺手”的问题。
- 怎么解决：
  - 它保留 Codex 作为底层执行引擎，在外层加上标准化的流程关键词、技能包、hooks、AGENTS、tmux 团队运行时、worktree 编排、状态目录 `.omx/`，把“澄清需求 -> 计划 -> 持续执行 -> 并行团队 -> 验证/恢复”做成一条推荐主路。
- 适用边界：
  - 在 `macOS / Linux + Codex CLI + tmux` 这条路径上最成立。
  - 官方 README 明确说 Native Windows 和 Codex App 不是默认体验，支持度更低。

### 证据分层
- A 级证据：
  - GitHub README 直接写明它是 `OpenAI Codex CLI` 的 workflow layer，并强调 “does not replace Codex”。
  - 官网 docs 直接给出核心命令、发布节奏、工作流链路、团队 worktree、hooks、wiki、MCP、skills 等能力面。
  - GitHub 仓库元数据可直接看到高活跃度：`22k stars`、`1.9k forks`、`84 releases`、`1,551 commits`。
- B 级证据：
  - 官方文档站点和 GitHub README 之间有互相印证关系。
- 证据冲突：
  - 文档站首页仍显示 `v0.12.1`，而 GitHub release 已到 `v0.12.6`（2026-04-13），说明文档存在版本滞后。

### 正反论证
- 最强支持证据：
  - README 直接说明“Codex 做实际 agent 工作，OMX 提供 roles / skills / runtime layer”。
  - 文档页列出 `33 Agent Prompts / 36 Skills / 5 MCP Servers`，并且发布记录持续更新到 2026 年 4 月。
  - 推荐主路径清晰：`deep-interview -> ralplan -> ralph/team`。
- 最强反方挑战：
  - 这类工具可能把简单事情做重，让本来能直接用原生 Codex 的任务被额外流程、tmux、worktree、hook 管理负担放大。
  - 它会修改本地 `.codex/config.toml`、`.codex/hooks.json`、安装 prompts/skills/AGENTS scaffolding，对“只想保持原生环境”的人是明显侵入。
- 反例/失败案例：
  - 官方 README 自己就提醒：如果你想要 plain Codex with no extra workflow layer，你大概率不需要 OMX。
  - 官方还明确写了 Windows 不是默认体验，并列出了 Intel Mac 启动 CPU 飙升的已知问题。

### 深层分析
- 设计哲学：
  - 它不是做“更聪明的单 agent”，而是做“更强的执行组织层”。
  - 重点不在模型本身，而在把高频动作标准化成关键词、角色、技能、协作面和状态沉淀。
- 关键取舍：
  - 为了获得更强的工作流和并行能力，它接受了更重的安装、更高的系统依赖、更强的目录/配置介入。
  - 为了让团队运行时更稳，它明显偏向 `tmux + worktree + hooks + local state`，而不是零配置纯 CLI。
- 演进方向：
  - 2026-03 到 2026-04 的版本记录显示它持续往 `autonomous research`、`team worktrees`、`native hooks`、`runtime hardening`、`quality-first defaults` 方向推进。

### 项目适配评估
- 最匹配的点：
  - 你本身就在一个 `skills / rules / hooks / agents / contracts` 导向的仓库里，理解这类“AI 运行时治理层”会比较快。
  - 如果你喜欢把 AI 工作做成可复用套路，OMX 的思路和你当前工作区的关注点有明显相邻性。
- 最不匹配的点：
  - 你现在的问题是“我不知道它干啥的”，说明你还处在认知期，不一定适合一上来就装这种重编排层。
  - 如果你还没稳定形成自己的原生 Codex 习惯，先上 OMX 容易把“Codex 原生能力”和“OMX 编排能力”混在一起。
- 采纳成本：
  - 需要理解 `omx setup` 会写什么、`tmux` 在团队模式里扮演什么角色、`.omx/` 会存什么、哪些 hooks/skills/AGENTS 会被注入。
- 退出成本：
  - 官方提供 `omx uninstall`，但你仍然需要理解它改过的 hooks/config 边界，才能放心装卸。

### 当前判断
- 判定：成立
- 结论稳健性：高
- 失效边界：
  - 如果未来原生 Codex 自己补齐了更多流程层和团队层能力，OMX 的增量价值会下降。
  - 如果你的日常任务大多是短平快单人任务，OMX 的收益会明显下降。
- 待验证项：
  - 你朋友到底分享的是哪条线
  - 你是否真的需要 team/worktree/tmux/hooks 这类增强，而不是只想先把原生 Codex 用顺

## 关键差异：两条“同名路线”不是一回事
| 维度 | `Yeachan-Heo/oh-my-codex` | `junghwaYang/oh-my-codex` |
|------|---------------------------|---------------------------|
| 技术路线 | Node + tmux/worktree/hooks 生态 | Python + OpenAI Agents SDK 生态 |
| 公开热度 | GitHub `22k stars` | GitHub `3 stars`，PyPI `0.3.0` |
| 主张 | 给 Codex 加工作流层、hooks、team runtime、状态层 | 把 Codex 变成 32 个专业 agent 的编排系统 |
| 安装方式 | `npm install -g oh-my-codex` + `omx setup` | `pip install oh-my-codex` + `omx-setup` |
| 默认适用人群 | 已经重度使用 Codex、想上更完整运行时的人 | 想要 Python 路线 multi-agent orchestration 的尝鲜者 |
| 当前判断 | 默认主候选 | 同名次候选，需看朋友具体分享内容 |

## 它具体能干什么
根据主线 README 和 docs，`OMX` 至少提供 6 类能力：

1. 统一工作流入口
   - 用 `$deep-interview` 做需求澄清
   - 用 `$ralplan` 做计划与权衡
   - 用 `$ralph` 做持续推进
   - 用 `$team` 做并行团队执行

2. team runtime
   - 支持 leader/worker 模式
   - 可在 tmux 中管理团队 session
   - 支持 team status / resume / shutdown

3. worktree orchestration
   - team worker 默认在独立 git worktree 中运行
   - 目标是减少并行 worker 写冲突

4. hooks 与运行时治理
   - `omx setup` 会安装/刷新 prompts、skills、AGENTS、`.codex/config.toml` 和 `.codex/hooks.json`
   - 对非 team session，native Codex hooks 是标准生命周期面

5. 探索与辅助工具
   - `omx explore` 做只读仓库查找
   - `omx sparkshell` 做受控 shell 检查
   - `omx wiki` 提供本地 wiki 查询与刷新

6. 状态沉淀
   - 项目 guidance、plans、logs、memory、mode state 落在 `.omx/`
   - 这意味着它不仅是命令别名，而是会持续持有运行痕迹

## 适用边界
- 适用场景：
  - 你已经喜欢 `Codex CLI`
  - 你经常做多步骤、大任务、需要计划和验证的工作
  - 你愿意接受 `tmux / hooks / AGENTS / worktrees / .omx/` 这套更强工作流
- 不适用场景：
  - 你只是想先体验原生 Codex
  - 你不想让工具改动本地配置和 hook 注册
  - 你主要在 Native Windows 或 Codex App 上工作
  - 你不想把简单任务做重
- 需要保留的前提：
  - 最好能接受 `macOS/Linux + tmux`
  - 需要理解安装和卸载边界
  - 需要区分“原生 Codex 能力”和“OMX 叠加能力”

## 如果你要判断“值不值得装”
- 值得试：
  - 你已经是终端重度用户
  - 你知道自己需要 `hooks / worktrees / team runtime / 计划-执行链`
  - 你觉得原生 Codex 在长任务组织上还不够顺手
- 建议先别装：
  - 你还没把原生 Codex 用熟
  - 你只做小任务
  - 你不清楚它会碰哪些本地配置
  - 你只想“有空看看”，还没到要重构工作流的阶段

## 给你的建议
- 第一阶段不要直接装，先把它当“工作流产品”理解，而不是当“命令增强插件”理解。
- 最值得先看的不是它能跑多少 agent，而是这 4 件事：
  - 它会改哪些本地文件
  - 它推荐的默认工作流是什么
  - 它和原生 Codex 的职责边界是什么
  - 你自己有没有真实场景需要这些增强
- 如果你后面真想试，最稳妥的顺序是：
  1. 先单独看主线 README 和 docs
  2. 确认你是 `npm` 路线还是 `pip` 路线
  3. 在非主力环境里先试装
  4. 先只体验单人工作流，再考虑 team/tmux/worktree

## 与当前工作区的关系

### 项目上下文
- 当前工作区 `org-claude-skills` 本身就是一个统一维护 `Claude Code / Codex CLI` 的 `skills / rules / reference / hooks / agents / contracts` 仓库。
- 本地预扫描未找到 `Oh My Codex` 这个名称的直接落点。
- 当前仓库更像“运行资产与流程规范仓库”，而 `Oh My Codex` 更像“面向终端用户的 Codex 运行时增强发行版”。

### 当前适配判断
- 从兴趣方向看：高度相邻，值得理解。
- 从立刻安装看：不建议盲装，先确认你真正想解决的问题是不是“我需要更重的 Codex 工作流层”。

## 独立挑战记录
| 挑战点 | challenger 质疑 | 原结论回应 | 是否调整 |
|--------|----------------|-----------|---------|
| 是否把热门度误当成价值 | 星标高不等于适合你 | 接受，所以结论没有直接给“建议安装”，而是先给“先理解、再试装” | 是 |
| 是否忽略了同名项目冲突 | 也许朋友发的不是 Yeachan 那条线 | 接受，所以把 `junghwaYang/oh-my-codex` 明确保留为次候选，并把“看原始链接”列为翻案条件 | 是 |
| 是否低估了侵入性 | setup 会写 hooks/config/AGENTS，可能影响现有环境 | 接受，所以把“非主力环境试装”作为建议动作前置 | 是 |
| 是否高估了多 agent 需求 | 很多人实际并不需要 team runtime | 接受，所以适用边界明确区分“终端重度 + 长任务”与“小任务/新手” | 是 |

## 检索路径与覆盖证明
- 名称归一化：
  - `Oh My Codex`
  - `oh-my-codex`
  - `ohmycodex`
  - `OMX`
  - `omx`
- 已查对象类型：
  - GitHub repo
  - 官网 docs
  - GitHub release/README 元数据
  - PyPI package
  - 本地工作区代码扫描
- 已查 discovery 入口：
  - GitHub 搜索/仓库主页
  - 官网文档站
  - PyPI 项目页
  - 本地仓库 README / 目录结构 / 文本搜索
- 已排除候选：
  - `org-claude-skills`：相邻项目，不是目标对象
  - 官方 Codex 本体：不是同一命名对象
- 剩余盲区：
  - 没有拿你朋友发来的原始链接做最终定案
  - 没有本地亲自安装验证两条路线的真实差异
  - 没有对主线的 hooks 写入和卸载边界做实机审计

## 证据索引
- [E1] GitHub, `Yeachan-Heo/oh-my-codex`
  https://github.com/Yeachan-Heo/oh-my-codex
- [E2] Oh My Codex Documentation
  https://yeachan-heo.github.io/oh-my-codex-website/docs.html
- [E3] GitHub, `junghwaYang/oh-my-codex`
  https://github.com/junghwaYang/oh-my-codex
- [E4] PyPI, `oh-my-codex`
  https://pypi.org/project/oh-my-codex/
- [E5] 当前工作区 [README.md](/Users/lijieli/org-claude-skills/README.md)
