# Addy Osmani《Agent Harness Engineering》精读报告

> 调研模式：analysis
> 呈现模式：decision + understanding
> 调研日期：2026-04-24
> 调研对象：[Agent Harness Engineering](https://addyosmani.com/blog/agent-harness-engineering/)，Addy Osmani，2026-04-19
> 项目对象：`/Users/lijieli/org-claude-skills`

## 结论先行

这篇文章对当前仓库有帮助，但不是“从零引入一个新概念”的帮助，而是给现有体系一个更清晰的评估框架。

当前仓库已经具备明显的 agent harness 形态：`rules / skills / contracts / hooks / tests / eval / agents` 都存在，并且 `README.md` 已经把默认流程收口到 `small-chain`。因此最值得吸收的不是再堆更多规则或更多 skill，而是把每一次 agent 失败转成可追踪的 harness 改进：规则、hook、eval、上下文预算、子 agent 边界或验证门禁。

推荐动作：轻量采纳。用这篇文章做一次“失败模式回流机制”升级，而不是新建一套大平台。

## 通俗解释

可以把 agent 想成一个会干活的新同事。模型是这个人的脑子，harness 是公司给他的工作环境。

- `AGENTS.md / rules / skills`：相当于入职手册和岗位 SOP。
- `tools / bash / browser / MCP`：相当于电脑、工位、系统权限和内部工具。
- `contracts / plan / tasks`：相当于任务拆解和交付协议。
- `hooks / tests / lint / review / qa`：相当于门禁、质检和返工机制。
- `docs / worklog / artifacts`：相当于交接班记录。
- `subagents`：相当于把一个大任务拆给不同角色的人做，最后由负责人汇总。

Addy 文章最重要的一句话可以翻译成：不要总怪模型笨，先看是不是你给它的工作环境、约束、反馈和交接机制没设计好。

## 文章核心观点

### 1. Agent 不是模型本身，而是模型加外部脚手架

文章把 harness 定义为模型之外的所有工程结构，包括提示词、工具、上下文策略、hooks、沙箱、子 agent、反馈环路和恢复路径。这个观点和 HumanLayer 的说法一致：skills、MCP、sub-agents、memory、`AGENTS.md` 都是 coding agent 的配置面。

对本仓库的含义：这个仓库本身就是一个 harness 仓库。它维护的是 Claude Code 与 Codex CLI 的运行规则、技能、参考资料、hooks、agents 和 contracts，不是普通业务应用。

### 2. 每次 agent 犯错，都应该变成系统改进

文章强调“ratchet”思路：agent 出错不是一次性事故，而是可沉淀信号。比如 agent 注释掉测试、提前宣布完成、乱跑危险命令，都不应该只靠下次提醒，而应该沉淀成规则、hook、review 检查或 eval。

对本仓库的含义：你们已经有 `shared/rules/铁律.md`、`shared/hooks/registry.json`、`tests/` 和 completion gates。下一步应补的是“失败样本 -> harness 改动”的固定入口，而不是靠记忆临时修。

### 3. 好 harness 从目标行为倒推组件

Addy 引用的思路是：先问“我希望 agent 表现出什么行为”，再问“哪个 harness 组件能稳定地产生这个行为”。如果说不清一个组件服务于哪个行为，它就可能是噪音。

对本仓库的含义：`tests/test-skill-context-budget.sh` 已经在做类似事情，它约束 skill 上下文体积，避免入口越来越重。这个方向应该继续强化。

### 4. 长任务要靠计划、交接、重置和独立评估

文章把长任务失败归因到早停、拆解差、上下文腐烂和自评偏乐观。Anthropic 的相关文章也强调，长任务需要结构化交接、context reset，以及 planner / generator / evaluator 这类职责分离。

对本仓库的含义：`contracts/small-chain.yaml` 已经有 `brainstorming -> writing-plans -> subagent-driven-development -> verification-before-completion -> verify-change -> archive` 的链路。这和文章方向高度一致。更值得补的是执行 trace 与失败回放，而不是重做流程链。

### 5. Hooks 是“系统强制”，不是“温馨提醒”

文章区分了“告诉 agent 要做什么”和“系统强制它必须做什么”。hooks 适合放那些 agent 常忘、但后果严重的事：危险命令拦截、测试失败反馈、提交前检查、静默通过和失败详报。

对本仓库的含义：`shared/hooks/registry.json` 已经包含 dangerous bash、completion gates、quality check 等机制。但 Codex 侧仍有能力边界，例如 registry 中标明 Codex hooks 目前不能拦截 Write/Edit 类工具调用。这是现实约束，需要在文档和验证设计里继续显式表达。

## 对当前仓库的帮助程度

| 维度 | 当前仓库状态 | 文章帮助 | 判断 |
|---|---|---|---|
| 规则与记忆 | 已有 `README.md`、`shared/rules`、`shared/reference`、多套 `SKILL.md` | 帮助清理规则来源，要求每条规则可追溯到失败或硬约束 | 高 |
| 渐进式披露 | 已有 skill 目录、references、context budget 测试 | 强化“少而准”，避免所有知识塞进入口 | 高 |
| 流程编排 | 已有 `small-chain` 和 standard-chain 合同 | 证明当前方向正确，但不要求重造 | 中高 |
| Hooks 门禁 | 已有 hooks registry 和 completion gates | 强化 hooks 应承担强制层职责 | 高 |
| Eval 飞轮 | 已有 `tools/eval`、graders、scenarios | 需要更贴近真实失败样本，形成回归集 | 高 |
| 可观测性/trace | 有报告和验证工件，但运行 trace 还不是主线 | 文章对这里的启发最大 | 高 |
| 多 agent 协作 | 已有 subagent 与 roles | 应更多用于上下文隔离和独立评估，不只是角色命名 | 中高 |

总体判断：有帮助，且适配度高。当前仓库已经具备 harness 基础，最该补的是“失败样本驱动的迭代闭环”。

## 最值得吸收的三件事

### P0：建立失败样本回流机制

建议新增或固化一个轻量流程：

1. 记录 agent 失败样本：输入、期望行为、实际偏差、影响范围。
2. 判断失败类型：规则缺失、上下文污染、工具描述不清、hook 缺位、eval 缺位、验证命令不足。
3. 选择最小 harness 改动：改 rule、改 skill、加 hook、加 eval、改 contract、补 docs。
4. 运行最近验证命令，证明这个失败不会重复出现。

这件事最贴合文章的 ratchet 思想。

### P0：把 eval 从“能力展示”升级成“失败回归”

仓库已有 `tools/eval/scenarios` 和 `tools/eval/graders`，但应优先服务真实失败模式。每当出现一次 agent 误判、早停、过度设计、跳验证、误改 upstream，就补一个最小场景或 grader。

这会让 eval 变成 harness 的记忆，而不是演示材料。

### P1：为长任务强化 handoff 与 trace

`small-chain` 已经有结构化工件，但可以继续明确每个阶段留下哪些 trace：

- agent 做了哪些关键判断
- 哪些文件被读作依据
- 哪个验证命令证明了哪个成功标准
- 哪些失败被观察到，如何修复
- 下一个 agent 接手时必须知道什么

这比继续增加总规则更有价值。

## 不建议吸收的做法

不要因为这篇文章就新增一堆抽象层。当前仓库已经有较强治理，盲目增加新流程会提高维护成本。

不要把所有东西都塞进 `AGENTS.md` 或根入口文档。文章和 HumanLayer 都强调上下文预算和渐进披露，入口越重，agent 越容易抓不住重点。

不要把 subagent 理解成“角色越多越专业”。HumanLayer 对 subagent 的关键解释是上下文隔离：父 agent 不吃掉子 agent 的全部中间上下文，只拿最终结论。

## 独立挑战

最强反方意见：这篇文章大部分内容并不新，你们仓库已有旧的 `docs/harness-engineering-20260411/research-report.md`，也已有 rules、hooks、eval、small-chain。继续围绕概念写文档，可能只是增加文档噪音。

回应：反方成立一半。所以本报告不建议“重建 harness”，只建议把文章压缩成一个具体改进方向：失败样本回流。只有当真实失败能进入 rule/hook/eval/contract 的闭环时，这篇文章才对仓库产生实际价值。

## 建议落地顺序

1. 先做一次失败模式盘点：从最近 5 到 10 个 hotfix、review FAIL、qa FAIL、completion gate FAIL 中提取重复失败。
2. 给每类失败指定 harness 落点：rule、skill、hook、eval、contract、docs。
3. 只挑 1 到 2 个高频失败做试点，不扩大战线。
4. 试点通过后，把流程写入 `shared/skills/skill-harness` 或相关 contract，而不是散落在临时报告里。

## 检索路径与覆盖证明

- 主文：[Addy Osmani, Agent Harness Engineering, 2026-04-19](https://addyosmani.com/blog/agent-harness-engineering/)
- 关联来源：[HumanLayer, Skill Issue: Harness Engineering for Coding Agents, 2026-03-12](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)
- 关联来源：[Martin Fowler, Harness engineering for coding agent users, 2026-04-02](https://martinfowler.com/articles/harness-engineering.html)
- 关联来源：[Anthropic, Harness design for long-running application development, 2026-03-24](https://www.anthropic.com/engineering/harness-design-long-running-apps)
- 关联来源：[Anthropic, Effective harnesses for long-running agents, 2025-11-26](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- 本地扫描：`README.md`
- 本地扫描：`contracts/small-chain.yaml`
- 本地扫描：`contracts/superpowers-boundary.yaml`
- 本地扫描：`shared/hooks/registry.json`
- 本地扫描：`tests/test-skill-context-budget.sh`
- 本地扫描：`tests/test-skill-harness-engineering-control.sh`
- 本地扫描：`tools/eval/`

## 最终判断

这篇文章值得纳入当前仓库的方法论依据，但它的正确用法是“减少重复失败”，不是“增加更多流程”。

一句话教会版：agent harness 就是给 AI 员工搭一套不会靠记忆工作的工作系统；每次它犯错，都别只骂它，应该问是哪块系统没兜住，然后把这次失败固化成下次不会再犯的规则、工具、检查或评测。
