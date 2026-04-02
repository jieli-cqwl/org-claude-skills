# Autoresearch 调研报告

日期：2026-04-02  
调研对象：[uditgoenka/autoresearch](https://github.com/uditgoenka/autoresearch)  
报告模式：analysis  
范围假设：按 `docs/autoresearch-analysis/` 作为本次调研 feature 目录  
decision_status: AUTO_DECISION

## 当前结论

`uditgoenka/autoresearch` 不是“研究资料抓取器”，也不是“跨运行时通用 workflow contract”。它更准确的定位是：**一个面向 Claude Code 的自治工作流插件/skill 套件**，把“目标 -> 作用域 -> 指标 -> 验证 -> 保留/回滚 -> 记录 -> 重复”包装成 `/autoresearch` 及一组子命令。

它真正解决的问题，是把原本零散、一次性的自治优化 prompt，收敛成一个可反复执行的 Claude Code 命令体系。其核心价值不在“联网调研”，而在**自治迭代、机械验证、git 记忆、结构化日志、交互式 setup**。

对当前仓库 `org-claude-skills`，**最佳实践不是直接安装或并入主链**。当前最优动作是：

1. **不**把它直接装进本仓库 canonical runtime、`small-chain` 默认链或 `community/superpowers`。
2. **只**把它当作外部方法论来源，重点学习 `reason` 的对抗式多代理评审模式，以及 `learn` 的文档 scout/validate/fix 思路。
3. 如果一定要试用，只能在**独立的 Claude-only 隔离仓库**做 bounded、低副作用试点，且优先评估 `/autoresearch:reason`，不在本仓库跑 `/autoresearch` 主循环。

不建议场景：

- 把 `autoresearch` 当作当前仓库新的默认方法论。
- 直接项目级/全局级安装到这个仓库的实际运行面。
- 把它 vendor 到 `shared/` 或 `community/superpowers/`，扩张 fork 面。
- 在当前仓库执行会自动 `git commit` / `git revert` / 改 `.gitignore` / 写 `*-results.tsv` 的自治循环。

待验证项：

- 若后续要验证其局部价值，应只验证 `reason` 风格的盲审挑战机制，或 `learn --mode check` 风格的只读文档健康检查。
- 只有在 A/B 证据证明它优于现有 `/research` 或文档链路，且不破坏 Claude/Codex 双端统一真源时，才考虑吸收其局部模式。

## 一、项目上下文画像

基于本地扫描，当前仓库不是普通应用仓库，而是 **Claude/Codex 双端统一运行资产仓库**：

- [README.md](/Users/lijieli/org-claude-skills/README.md) 明确目标是统一维护 `skills / rules / reference / hooks / agents`。
- [shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md) 把角色切换、默认入口、reference 触发映射和优先级写成统一入口合同。
- [contracts/small-chain.yaml](/Users/lijieli/org-claude-skills/contracts/small-chain.yaml) 声明默认链只有 6 步：`brainstorming -> writing-plans -> using-git-worktrees -> subagent-driven-development -> verify-change -> archive`。
- [shared/protocols/phase-selection-protocol.md](/Users/lijieli/org-claude-skills/shared/protocols/phase-selection-protocol.md) 明确 `/research` 是独立流程，走 `docs/{feature}/` 平铺路径，不属于 phase 工作区状态机。
- [contracts/superpowers-boundary.yaml](/Users/lijieli/org-claude-skills/contracts/superpowers-boundary.yaml) 和 [community/SOURCES.yaml](/Users/lijieli/org-claude-skills/community/SOURCES.yaml) 说明当前仓库强依赖 source lock、boundary contract、overlay 文件边界。
- [tests/test-install-smoke.sh](/Users/lijieli/org-claude-skills/tests/test-install-smoke.sh)、[tests/test-codex-skill-adapter.sh](/Users/lijieli/org-claude-skills/tests/test-codex-skill-adapter.sh)、[tests/test-superpowers-boundary.sh](/Users/lijieli/org-claude-skills/tests/test-superpowers-boundary.sh) 说明本仓库不是“提示词集合”，而是**带安装、适配、边界和回归门禁**的工程仓库。
- [shared/reference/Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md) 已把 skill 质量拆到 I/O 契约、验证即证据、token 效率、Codex 适配等层面。

这意味着：任何外部对象的“最佳实践”都不能只看它好不好用，必须看它是否破坏 **双端统一真源、显式状态机、source lock、测试门禁**。

## 二、检索路径与覆盖证明

### 名称归一化

本次检索对以下名称变体做了覆盖：

| 词条 | 类型判断 | 结论 |
|------|---------|------|
| `autoresearch` | 泛称 | 需要排除同名对象 |
| `Claude Autoresearch` | Claude Code 插件/skill | 命中目标对象 |
| `uditgoenka/autoresearch` | GitHub repo | 命中目标对象 |
| `karpathy/autoresearch` | 上游灵感来源 repo | 不是当前目标对象，但必须纳入排除表 |

### 对象类型覆盖

本次覆盖了以下对象类型：

| 对象类型 | 覆盖方式 | 结果 |
|---------|---------|------|
| GitHub 仓库主页 | 远程 README + 本地 clone | 命中 |
| Claude 插件分发 | `.claude-plugin/marketplace.json`、`claude-plugin/.claude-plugin/plugin.json` | 命中 |
| Claude commands/skills | `claude-plugin/commands/**`、`claude-plugin/skills/**` | 命中 |
| 运行协议 | `references/autonomous-loop-protocol.md`、`results-logging.md` 等 | 命中 |
| 手册与安装说明 | `guide/**`、`README.md` | 命中 |
| 上游灵感 repo | [karpathy/autoresearch](https://github.com/karpathy/autoresearch) | 命中，但归类为灵感源 |
| Codex 适配面 | 搜索 `openai.yaml`、`AGENTS.md`、`agents/*.toml` | **未命中** |
| CI / 测试门禁 | 搜索 `.github/workflows`、`tests/` | **未命中** |

### 候选排除表

| 候选 | 排除理由 |
|------|---------|
| [karpathy/autoresearch](https://github.com/karpathy/autoresearch) | 这是上游灵感源，定位是单 GPU、单文件、单指标的 ML 训练自治实验，不是本次要评估的 Claude Code 插件对象 |
| “它是一个通用 MCP / Codex skill 包” | 本地 clone 未发现 `openai.yaml`、`AGENTS.md`、Codex agent metadata，分发目录完全围绕 `.claude`/Claude plugin |
| “它是一个可直接纳入当前 repo runtime 的工程化上游” | 本地 clone 截至 `master@0a1b677` 未发现测试目录和 `.github/workflows`，更像分发型 skill repo，不是带双端适配与合同门禁的运行时真源 |

本地扫描对象版本：

- 目标 repo：`uditgoenka/autoresearch`
- 分支：`master`
- 提交：`0a1b677`

## 三、`autoresearch` 的业务目标和具体解决的问题

## 1. 它的业务目标是什么

从 [README](https://github.com/uditgoenka/autoresearch) 和命令/协议结构看，`autoresearch` 的核心目标是：

- 把 Claude Code 变成一个**自治改进引擎**。
- 让用户只负责给出目标、范围、指标和验证方式，剩下的由 Claude 按循环反复尝试。
- 把 Karpathy 在 ML 自治实验里使用的“约束范围 + 单指标 + 快速验证 + 自动回滚 + git 记忆”模式，泛化到更多任务。

它面向的不是“想看一份调研报告的人”，而是“愿意让 Claude 连续多轮试错并保留最优结果的人”。

## 2. 它具体解决什么问题

它解决的是 5 类问题：

1. **自治优化 prompt 每次都要重写**
   - 它把自治循环做成固定命令，不必每次重新口述“改一下、跑一下、差了就回滚”。
2. **缺少机械化 keep/discard 规则**
   - 通过 `Verify` 和可选 `Guard`，把“更好/更坏”变成可执行判据。
3. **自治试验没有历史记忆**
   - 它要求每轮读 `git log`、读结果日志，并用 `experiment(...)` 提交和 `git revert` 保留失败历史。
4. **Scope / Metric / Verify 配不好**
   - `/autoresearch:plan` 把 goal 转成作用域、指标、方向、验证命令，并要求 dry-run 验证。
5. **不同任务类型缺少专用自治 workflow**
   - 它不是只有主循环，还扩展出 `debug`、`fix`、`security`、`ship`、`scenario`、`predict`、`learn`、`reason` 等子命令。

## 3. 它不解决什么问题

它并不天然解决：

- 跨运行时治理问题
- 双端适配问题
- 严格的组织级流程合同问题
- 可追责的多工件状态机问题
- “一个 skill 应该什么时候进默认链”这种仓库架构问题

换句话说，`autoresearch` 更像一个**Claude Code 内部自治工作流套件**，不是你们这类 runtime 仓库的 authority。

## 四、核心机制拆解

## 1. 分发模型：Claude 插件优先

它的推荐安装方式是 Claude Code 插件市场：

- `/plugin marketplace add uditgoenka/autoresearch`
- `/plugin install autoresearch@autoresearch`

备用方式才是手动复制到 `.claude/commands` 和 `.claude/skills`。  
本地 clone 里存在：

- `claude-plugin/.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- `claude-plugin/commands/**`
- `claude-plugin/skills/autoresearch/**`

这说明它首先是 **Claude plugin / Claude skill 包**，不是双端 canonical。

## 2. 主循环：Goal-directed iteration

其核心协议见 [autonomous-loop-protocol.md](https://github.com/uditgoenka/autoresearch/blob/master/claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md)：

1. 读当前状态、git 历史和结果日志
2. 选一个下一步改动
3. 只做一个聚焦变更
4. 先提交
5. 跑机械验证
6. 更好则保留，更差则回滚，崩溃则修或跳过
7. 记日志
8. 重复

这套机制的前提很强：

- 目标必须足够清晰
- 指标必须机械化
- 作用域必须可控
- 验证必须快
- 用户能接受 agent 改代码、提 commit、做回滚

## 3. Git is memory

它不是把 git 当备份，而是把 git 当“实验记忆”：

- 每轮建议使用 `experiment(<scope>): ...` 提交
- 失败优先 `git revert`
- 每轮必须读最近的 `git log` / `git diff`

同时它还会写 `autoresearch-results.tsv`，并把这个文件追加进 `.gitignore`。

这在自治实验仓库里是合理的，但在当前仓库里是高冲突行为，因为当前仓库已有：

- `tasks.md` 作为进度真源
- `small-chain` 的显式工件链
- 安装与边界测试

## 4. 子命令不是附属品，而是第二层产品面

它不是一个 skill + 一堆 notes，而是一个命令簇：

| 子命令 | 真实定位 |
|------|---------|
| `/autoresearch` | 主自治优化循环 |
| `/autoresearch:plan` | 配置生成器 |
| `/autoresearch:debug` | 科学方法调试循环 |
| `/autoresearch:fix` | 错误归零循环 |
| `/autoresearch:security` | STRIDE/OWASP 安全审计 |
| `/autoresearch:ship` | 通用交付流程 |
| `/autoresearch:scenario` | 场景扩展器 |
| `/autoresearch:predict` | 多人格预分析 |
| `/autoresearch:learn` | 文档生成/更新引擎 |
| `/autoresearch:reason` | 盲审对抗式收敛 |

这意味着它本质上不是“一个小技巧”，而是**一套自己的 workflow surface**。

## 5. 强依赖 Claude 平台交互能力

本地源码中大量硬依赖：

- `AskUserQuestion`
- Claude plugin marketplace
- `.claude/commands`
- `.claude/skills`
- 某些 workflow 中提到的 `ToolSearch`

而本地 clone 没有发现：

- `openai.yaml`
- Codex agent metadata
- `AGENTS.md`
- Codex adapter 文件

因此，**直接把它称为 Claude/Codex 双端可复用对象是不成立的**。

## 五、与当前仓库的重叠、冲突和适配判断

## 1. 功能重叠不是小问题，而是架构冲突

`autoresearch` 的多个子命令与当前仓库已有能力重叠：

| `autoresearch` 命令 | 当前仓库重叠对象 | 判断 |
|--------------------|-----------------|------|
| `plan` | `research`、`product`、`design`、`tech-lead` | 语义不同，但都在做“先定义再执行” |
| `debug` / `fix` | `fix` | 明显重叠 |
| `security` | `security` | 明显重叠 |
| `ship` | `project-manager`、`commit`、`finishing-a-development-branch` | 明显重叠 |
| `learn` | `overview`、文档链路 | 部分重叠 |
| `predict` / `reason` / `scenario` | `research`、`review`、`qa`、`test-design` | 方法不同，但问题域高度重叠 |

这不是“正好多一个选择”，而是把现有 repo-native skill 拆分边界重新揉成另一套命令体系。

## 2. 直接安装到当前仓库，不是最佳实践

### 方案 A：直接项目级安装到当前仓库 `.claude/`

优点：

- 学习成本低
- 试用快

致命问题：

- 只覆盖 Claude，不覆盖 Codex
- 绕开当前仓库的 `install.sh`、adapter、boundary contract、tests
- 会形成一套未被当前安装/回归体系托管的并行运行面
- 主循环默认接受 `git commit` / `git revert` / `.gitignore` / `*-results.tsv` 副作用

结论：**不推荐**

### 方案 B：直接 vendor/import 到 `shared/` 或 `community/superpowers/`

优点：

- 表面上能纳入统一真源

致命问题：

- 需要新增大量 Claude-only 语义处理
- 需要补 Codex adapter、source lock、tests、boundary 文档、安装逻辑
- 会扩大 `community/superpowers` 的本地 fork 面
- 它本身是完整 workflow surface，不是一个容易裁剪的局部片段

结论：**更不推荐**

### 方案 C：隔离评估 + 选择性吸收模式

做法：

1. 当前仓库**不安装**
2. 若要试用，只在**独立的 Claude-only scratch repo** 做 bounded 评估
3. 只提炼模式，不导入 runtime 正文
4. 若后续证明有价值，再用本仓库既有 skill 流程重写为 repo-native 能力

结论：**推荐**

按 [shared/reference/技术选型.md](/Users/lijieli/org-claude-skills/shared/reference/技术选型.md) 的优先级 `一致性最高 > 复杂度最低 > 可逆性最高`，方案 C 明显优于 A/B。

## 六、两位挑战型 Agent 的反方结论

## 1. 产品/策略挑战

挑战型产品 agent 的核心反对点是：

- `autoresearch` 成立的典型场景是**单指标、受控编辑面、可反复试验**。
- 当前仓库的核心问题是**流程治理、双端统一、责任链、文档/工件合同**，不是“单一数值持续优化”。
- 如果把它包装成当前仓库的“最佳实践”，会把 `small-chain / research / autoresearch` 变成三套并行语义，带来认知负担和治理负担。

我认同这个反方判断。这里最危险的不是“它不好”，而是“它在错的问题上看起来很强”。

## 2. 架构/工程挑战

挑战型技术 agent 的核心反对点是：

- 当前默认活跃链路没有 `research` 节点，把带网络搜索和用户确认的研究流默认化，会破坏显式状态机。
- `/research` 当前要求 `WebSearch`、`WebFetch`、`AskUserQuestion`、`research-report.md` 落盘和用户确认；如果把研究能力偷偷变成默认前置，会制造隐藏副作用和责任链断裂。
- 当前仓库强依赖 boundary/source lock/tests；直接接入 `autoresearch` 会扩大维护面。

我认同这个反方判断。即使未来吸收 `autoresearch` 的某些模式，也必须保持：

- 显式触发
- 明确工件
- 明确用户确认
- 不污染默认链

## 七、最佳实践应用方式

### 当前推荐

**当前最佳实践应用方式 = 学习型引入，而不是安装型引入。**

具体动作：

1. 把 `autoresearch` 作为外部研究对象留在报告层，不改当前 runtime。
2. 把它拆成“可学习模式”，而不是“可直接搬运正文”。
3. 重点吸收两个局部思想：
   - `reason`：盲审、多候选、对抗式评判、避免迎合
   - `learn`：scout -> validate -> fix 的文档健康循环

### 如果一定要试用

只允许这个最小试点：

1. 新建一个**独立 scratch repo**
2. 只在该 repo 的 `.claude/` 项目级范围安装 `autoresearch`
3. 只试：
   - `/autoresearch:reason --domain software --iterations 3`
   - 或 `/autoresearch:learn --mode check`
4. 不试：
   - `/autoresearch`
   - `/autoresearch:fix`
   - `/autoresearch:ship`
   - `/autoresearch:security`
5. 试点只看两个指标：
   - 是否比当前 `/research` 或人工挑战流程更快地产出高质量反方
   - 是否引入了额外维护/副作用

### 未来若要吸收

只能走这条路径：

1. 先拿试点样本做 A/B 评估
2. 再走本仓库自己的 `research -> design -> tech-lead -> new-skills` 路径
3. 以 repo-native 方式重写成 first-party 能力
4. 补齐：
   - source lock
   - boundary contract
   - install/runtime adapter
   - tests

## 八、最终判断

`uditgoenka/autoresearch` 值得研究，但它值得研究的地方是**自治循环和对抗式收敛方法论**，不是“直接装进你们仓库”。

对当前 `org-claude-skills` 来说，最优结论是：

- **不直接安装**
- **不并入默认链**
- **不 vendor 到 canonical runtime**
- **只学习局部模式**
- **若要实践，只在隔离的 Claude-only scratch repo 做 bounded 试点**

这不是保守，而是和当前仓库目标匹配后的最佳实践。

补充反迷信证据：

- 官方项目主页截至 2026-04-02 仍展示 `v1.0.3`，而 GitHub 仓库 README / plugin manifest 已到 `v1.9.0`，说明其外部宣介与仓库现状存在版本漂移。
- 仓库还公开有 [Issue #25](https://github.com/uditgoenka/autoresearch/issues/25) 标记 `Future Consideration` 讨论 Codex 支持，进一步说明它当前不是双端成熟对象。
- 仓库在 [PR #30](https://github.com/uditgoenka/autoresearch/pull/30) 中明确承认并修补过 `git-as-memory` 机制的脆弱点，包括跳过 git 历史、使用破坏性回滚、缺少前置检查等问题。这不是“不能用”的证据，但足以说明它仍是快速演进中的对象，而非稳定 authority。

## 参考来源

外部：

- [uditgoenka/autoresearch README](https://github.com/uditgoenka/autoresearch)
- [uditgoenka/autoresearch marketplace manifest](https://github.com/uditgoenka/autoresearch/blob/master/.claude-plugin/marketplace.json)
- [uditgoenka/autoresearch plugin.json](https://github.com/uditgoenka/autoresearch/blob/master/claude-plugin/.claude-plugin/plugin.json)
- [uditgoenka/autoresearch autonomous-loop-protocol](https://github.com/uditgoenka/autoresearch/blob/master/claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md)
- [uditgoenka/autoresearch results-logging](https://github.com/uditgoenka/autoresearch/blob/master/claude-plugin/skills/autoresearch/references/results-logging.md)
- [uditgoenka/autoresearch reason-workflow](https://github.com/uditgoenka/autoresearch/blob/master/claude-plugin/skills/autoresearch/references/reason-workflow.md)
- [Autoresearch official project page](https://udit.co/projects/autoresearch)
- [Codex support issue #25](https://github.com/uditgoenka/autoresearch/issues/25)
- [git-as-memory hardening PR #30](https://github.com/uditgoenka/autoresearch/pull/30)
- [karpathy/autoresearch README](https://github.com/karpathy/autoresearch)

本地：

- [README.md](/Users/lijieli/org-claude-skills/README.md)
- [shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md)
- [contracts/small-chain.yaml](/Users/lijieli/org-claude-skills/contracts/small-chain.yaml)
- [docs/small-chain/README.md](/Users/lijieli/org-claude-skills/docs/small-chain/README.md)
- [shared/protocols/phase-selection-protocol.md](/Users/lijieli/org-claude-skills/shared/protocols/phase-selection-protocol.md)
- [shared/reference/技术选型.md](/Users/lijieli/org-claude-skills/shared/reference/技术选型.md)
- [shared/reference/Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md)
- [contracts/superpowers-boundary.yaml](/Users/lijieli/org-claude-skills/contracts/superpowers-boundary.yaml)
- [community/SOURCES.yaml](/Users/lijieli/org-claude-skills/community/SOURCES.yaml)
- [tests/test-install-smoke.sh](/Users/lijieli/org-claude-skills/tests/test-install-smoke.sh)
- [tests/test-codex-skill-adapter.sh](/Users/lijieli/org-claude-skills/tests/test-codex-skill-adapter.sh)
- [tests/test-superpowers-boundary.sh](/Users/lijieli/org-claude-skills/tests/test-superpowers-boundary.sh)
- [openspec/designs/2026-03-28-research-review-rubric-draft.md](/Users/lijieli/org-claude-skills/openspec/designs/2026-03-28-research-review-rubric-draft.md)
