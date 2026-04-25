# NotebookLM Skill 调研报告

> 调研模式：discovery
> 呈现模式：understanding
> 调研时间：2026-04-13
> 默认主候选：`PleasePrompto/notebooklm-skill`

## 这是什么
- 当前对象：社区里常被简称为 `NotebookLM skill` 的默认主候选 `PleasePrompto/notebooklm-skill`
- 一句话定义：它不是“帮你搭建 NotebookLM”，而是一个本地 `Claude Code` skill，让 Claude 通过浏览器自动化去操作你已经建好的 Google NotebookLM 笔记库，并把 NotebookLM 基于你私有资料生成的回答带回 CLI。
- 最容易混淆的相近对象：
  - 它不等于 `NotebookLM` 官方产品本身。
  - 它不等于跨平台 MCP 服务；作者自己就提供了一个相邻对象 `notebooklm-mcp`。
  - 它也不等于“把任意内容上传到 NotebookLM 并生成播客/PPT”的自动化流水线，那是另一类 skill。

## 直接结论
- 这个 skill 的核心用途：让 Claude Code 直接“问”你的 NotebookLM 笔记，而不是自己在本地文档里反复 grep / read。
- 它解决的问题：减少把文档整批塞进模型上下文导致的高 token 成本、检索不准和幻觉；同时省掉“Claude 问题 -> 你切到 NotebookLM 网页 -> 复制答案回来”的手工往返。
- 它最适合的场景：
  - 你已经把产品文档、内部资料、技术规范上传到 NotebookLM
  - 你主要在 `Claude Code` 本地版里工作
  - 你想把 NotebookLM 当“基于私有资料的外部知识库”
- 它不适合的场景：
  - 你用的是 Web 版 Claude，不是本地 Claude Code
  - 你主要想支持 `Codex / Cursor / Gemini CLI` 等多 agent 共用
  - 你不想让 skill 持有浏览器登录态、cookie 和本地 library 元数据

## 它具体能干什么
根据上游 README、SKILL.md 和 skills.sh 页面，这个 skill 主要有 4 类能力：

1. 直接问 NotebookLM
   - Claude 可以把问题发给指定 notebook，拿回带来源依据的答案。
   - 每次查询是独立浏览器会话，默认问完即关。

2. 管理 notebook 库
   - 维护一个本地 `library.json`
   - 支持 `add / list / search / activate / remove / stats`
   - 支持“先问 notebook 它讲了什么，再自动生成 name/description/topics”的 smart add

3. 处理 Google 登录
   - 首次使用要人工登录 Google
   - skill 会把认证状态和浏览器状态保存在本地目录
   - 后续查询复用本地认证状态

4. 自动追问与整合答案
   - 设计上要求 Claude 在第一轮答案后继续检查“信息是否足够”
   - 如果不够，继续问 follow-up，再把多轮答案整合给用户

## 为什么它可用
最强支持证据：
- Google 官方说明，NotebookLM 的 chat 只使用你提供的 sources，并给出可跳转的 citations；这正是该 skill 想利用的能力基础。
  来源：Google NotebookLM Help
- 上游 README 明确把该 skill 定位成“让 Claude Code 直接查询你上传到 NotebookLM 的文档，并获得 source-grounded、citation-backed answers”。
  来源：上游 README / GitHub
- skills.sh 的聚合页显示，这个 skill 的定位很清楚：查询私有 NotebookLM 笔记、管理 library、持久化认证、通过 `run.py` 自动管理环境。
  来源：skills.sh

## 最强反方挑战
- 它并不是直接调用 NotebookLM 官方 API，而是依赖浏览器自动化去驱动网页，这天然更脆弱。
- 上游 README 明确写了“只支持本地 Claude Code”，这和你当前公共仓库想同时服务 `Claude Code + Codex CLI` 的目标并不完全一致。
- skills.sh 页面虽然展示了 “installed on codex”，但上游作者自己给出的兼容范围是 `Claude Code only`，存在生态目录页与上游声明不完全一致的风险。

## 当前判定
- 对“它是干什么用的”这个问题：判断明确成立。
- 对“它是否值得个人装来用”：如果你本来就重度用 NotebookLM，且主要工作环境是本地 Claude Code，价值很高。
- 对“它是否适合直接收进当前这个公共仓库，像通用 skill 一样双端分发”：当前判定是 **部分适合**，更接近 `Claude-only` 社区 skill，而不是可以直接按 `Claude + Codex` 对称分发的通用 skill。

## 名称归一化与候选排除

### 名称变体
- `NotebookLM skill`
- `notebooklm skill`
- `notebooklm`
- `notebooklm-skill`
- `NotebookLM Claude Code Skill`

### 候选表
| 候选 | 类型 | 上游来源 | 当前状态 | 结论 |
|------|------|---------|---------|------|
| `PleasePrompto/notebooklm-skill` | Claude Code skill | GitHub + skills.sh | 高热度主候选，定位清晰 | 命中 |
| `PleasePrompto/notebooklm-mcp` | MCP alternative | 主候选 README 中显式提及 | 是相邻对象，不是同一个 skill | 排除为“相邻方案” |
| `joeseesun/anything-to-notebooklm` | NotebookLM 自动化 skill | skills.sh | 重点是“多源内容上传 + 生成播客/PPT/导图”，不是“查询私有 notebook” | 排除为“不同用途” |
| `yugasun/skills/slides` | NotebookLM 相关生成 skill | skills.sh | 重点是生成 slide，不是 NotebookLM 查询接口封装 | 排除为“不同用途” |

## 工作方式拆解
| 维度 | 说明 |
|------|------|
| 运行环境 | 本地 Claude Code |
| 触发方式 | 用户提到 NotebookLM、贴 notebook URL、要求查询 notebook 或加入 library |
| 执行机制 | Claude 调用 `python scripts/run.py ...`，由 skill 内脚本负责 auth / notebook 管理 / 问答 |
| 依赖 | Python 虚拟环境、Patchright、浏览器自动化、Google 登录状态 |
| 数据落盘 | `~/.claude/skills/notebooklm/data/` 下保存 `library.json`、`auth_info.json`、`browser_state/` |
| 结果特点 | 回答来自 NotebookLM 对你 sources 的综合，理论上比直接本地 grep 更接近“带上下文总结” |

## 主要收益
- 对私有资料问答更省 token：不用反复把本地文档读进模型窗口。
- 对多文档综合更友好：NotebookLM 本身就是为多 source 汇总设计的。
- 有 citation 约束：比“让 Claude 自己总结你一堆文档”更稳。
- 对重度 NotebookLM 用户很顺手：不再需要手动在网页和 CLI 之间来回切换。

## 主要风险
- 浏览器自动化脆弱性：
  - Google 页面结构、登录流程、反自动化策略变化都可能打断 skill。
- 兼容性风险：
  - 上游明确限定 `local Claude Code only`。
  - 这意味着它不天然适合你当前这个强调 `Claude + Codex` 双端的公共仓库。
- 安全与合规风险：
  - 本地保存浏览器状态与认证信息。
  - 如果公共仓库要收编，必须非常明确哪些文件绝不能进入版本控制或同步链路。
- 成本/配额风险：
  - skills.sh 页面和 SKILL.md 都提到免费账户大约有 `50 queries/day` 级别限制。
- 前置依赖风险：
  - 你得先把资料上传进 NotebookLM；skill 不负责替你完成全部资料准备。

## 与当前仓库的适配判断

### 项目上下文
- 当前仓库是一个统一维护 `Claude Code + Codex CLI` 运行资产的公共仓库。
- 本地预扫描未发现现成 `NotebookLM` skill 接入。
- 你前一轮刚把 `find-skills`、`agent-browser` 这类 community skill 按 `vendor + source lock + Codex adapter` 模式接入。

### 适配判断
- 如果目标是“我个人在本机的 Claude Code 里装一个好用的 NotebookLM skill”：
  - 适配度：高
- 如果目标是“把它像普通 community skill 一样收进当前公共仓库，默认对 Claude/Codex 双端分发”：
  - 适配度：中低
  - 原因：
    - 上游明确 `Claude Code only`
    - 依赖浏览器自动化和本地 Google 登录态
    - 对 Codex 的体验与适配边界没有上游保证

### 更稳的收编方式
- 若你后面真要收编，优先考虑：
  1. 先把它定义为 `Claude-only community skill`
  2. 明确不自动暴露到 Codex
  3. 单独评估作者提到的 `notebooklm-mcp` 是否更适合作为跨 agent 方案

## 是否值得你装
- 值得装：
  - 你已经在用 NotebookLM 管理一批高价值资料
  - 你经常需要“让 Claude 按这些资料回答问题”
  - 你主要工作在本地 Claude Code
- 暂时不值得装：
  - 你只是偶尔用 NotebookLM
  - 你更想要跨 `Claude / Codex / Cursor` 的统一方案
  - 你不想维护浏览器登录态和网页自动化

## 独立挑战记录
| 挑战点 | challenger 质疑 | 当前回应 | 是否调整 |
|--------|----------------|---------|---------|
| popularity 是否被高估 | 高安装量不等于稳定，可能是短期热点 | 接受，所以结论没有直接给“强推荐收编”，而是区分了“个人可用”与“仓库收编” | 是 |
| source-grounded 是否足够等于可靠 | NotebookLM 也会综合生成，不等于逐字检索 | 接受，所以表述收敛为“相对更稳”，没有说成“绝对准确” | 是 |
| 目录站的 Codex 安装面是否可信 | skills.sh 显示 installed on codex，但上游 README 明说 Claude Code only | 接受，以 upstream 声明优先，视作兼容边界冲突点 | 是 |

## 检索路径与覆盖证明
- 名称归一化：
  - `NotebookLM skill`
  - `notebooklm skill`
  - `notebooklm-skill`
  - `NotebookLM Claude Code Skill`
- 对象类型覆盖：
  - GitHub repo
  - raw `README.md`
  - raw `SKILL.md`
  - skills.sh 目录页
  - Google 官方 NotebookLM 帮助与官方博客
- 已排除候选：
  - `anything-to-notebooklm`：上传/加工/生成型 skill，不是查询型主候选
  - `slides`：NotebookLM 派生输出 skill，不是 NotebookLM 查询接口封装
  - `notebooklm-mcp`：相邻方案，不是同一个 skill
- 剩余盲区：
  - 没有对其实际脚本跑通做本地验证
  - 没有验证它在 Codex 环境中的真实可用性
  - 没有审计其浏览器自动化脚本对 Google 页面变更的脆弱程度

## 证据索引
- [E1] Google NotebookLM Help, `Use chat in NotebookLM`
  https://support.google.com/notebooklm/answer/16179559
- [E2] Google Blog, `NotebookLM adds more than a dozen new features`, 2023-12-08
  https://blog.google/innovation-and-ai/products/notebooklm-new-features-availability/
- [E3] Google Blog, `New in NotebookLM: Discover sources from around the web`, 2025-04-02
  https://blog.google/innovation-and-ai/models-and-research/google-labs/notebooklm-discover-sources/
- [E4] GitHub, `PleasePrompto/notebooklm-skill`
  https://github.com/PleasePrompto/notebooklm-skill
- [E5] Raw README, `PleasePrompto/notebooklm-skill/README.md`
  https://raw.githubusercontent.com/PleasePrompto/notebooklm-skill/master/README.md
- [E6] Raw SKILL, `PleasePrompto/notebooklm-skill/SKILL.md`
  https://raw.githubusercontent.com/PleasePrompto/notebooklm-skill/master/SKILL.md
- [E7] skills.sh, `notebooklm by pleaseprompto/notebooklm-skill/notebooklm`
  https://skills.sh/pleaseprompto/notebooklm-skill/notebooklm
- [E8] skills.sh, `anything-to-notebooklm by joeseesun/anything-to-notebooklm`
  https://skills.sh/joeseesun/anything-to-notebooklm/anything-to-notebooklm
