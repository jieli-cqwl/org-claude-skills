# darwin skill 调研报告

> 调研日期：2026-04-18
> 调研对象：`darwin skill` / `达尔文.skill`
> 调研模式：discovery
> 呈现模式：decision

## 这次要回答的问题

- 朋友口中的 `darwin skill` 最可能对应哪个 GitHub 地址。
- 同名或近似候选分别是做什么的，不能混淆在哪里。
- 它是否适合像 `superpowers` 一样 vendor 到当前公共仓库。
- 如果后续要纳入本地运行面，需要先处理哪些边界。

## 当前判断

最强命中是 `alchaincyf/darwin-skill`。

- GitHub 地址：<https://github.com/alchaincyf/darwin-skill>
- 安装命令：`npx skills add alchaincyf/darwin-skill`
- 用途：把 Karpathy `autoresearch` 的“实验、评分、只保留改进”模式迁移到 `SKILL.md` 优化上，用 8 维度评分、测试 prompt、git commit/revert 和人类确认来持续提升 skill 质量。

另一个同名候选是 `simota/agent-skills/darwin`。

- GitHub 地址：<https://github.com/simota/agent-skills/tree/main/darwin>
- 安装命令：`npx playbooks add skill simota/agent-skills --skill darwin`
- 用途：multi-agent 生态的健康度与演化提案层，评估项目生命周期、agent relevance、EFS/RS 分数，并写入 `.agents/ECOSYSTEM.md`。它不是用来直接优化 `SKILL.md` 的。

## 推荐结论

如果你的目标是“找到朋友分享的 Darwin/达尔文 skill，并考虑维护到当前 `org-claude-skills` 公共仓库”，推荐把 `alchaincyf/darwin-skill` 作为主候选。

## 实施状态

2026-04-18 已接受该建议，按隔离 community 源接入当前项目：

- upstream 原文落点：`community/alchaincyf/skills/darwin-skill/`
- Codex 适配层落点：`community/alchaincyf/codex/skills/darwin-skill/`
- 来源锁：`community/SOURCES.yaml` 的 `alchaincyf_darwin_skill`
- 同步脚本：`tools/community/sync_alchaincyf_skills_from_upstream.py`

但不建议直接设为默认运行时 skill。更稳妥的方式是：

1. 先按外部 community 源 vendor 到隔离目录，例如 `community/alchaincyf/skills/darwin-skill/`。
2. 保持 upstream 原文，另写 Codex/Claude 本地 adapter，把路径从 `.claude/skills/*` 调整到本仓库的 `shared/skills`、`community/*/skills` 与安装合成规则。
3. 默认只启用“评估/报告模式”，不要默认让它自动 commit、自动改多个 skill 或自动跑子 agent。
4. 在公开再分发前，先确认许可证边界：仓库 README 写了 MIT，但 GitHub API 的 `license` 字段是 `null`，根目录内容清单里没有独立 `LICENSE` 文件。

## 候选对比

| 候选 | 判断 | 用途 | 对当前仓库的适配度 |
| --- | --- | --- | --- |
| `alchaincyf/darwin-skill` | 主命中 | 自动评估和优化 `SKILL.md`，带 8 维评分、测试 prompt、git 棘轮、人类确认 | 高，但需要本地 adapter 和默认安全降级 |
| `simota/agent-skills/darwin` | 次候选 | multi-agent 生态健康检查、生命周期检测、EFS/RS、演化提案 | 中低，依赖 simota 生态概念与 `.agents/*` 运行结构 |
| `plurigrid/asi` 的 `skill-evolution` | 排除为主目标 | 也提 Darwin-Godel/skill evolution，但名字不是 `darwin` | 相关参考，不是朋友口中的最可能地址 |
| macOS/Darwin 相关 skills | 排除 | `darwin` 是系统名或 OS metadata，例如 macOS 自动化依赖 | 与“Darwin skill”命名不一致 |

## `alchaincyf/darwin-skill` 做什么

它是一个 meta-skill，优化对象是其他 `SKILL.md` 文件。

核心流程：

1. 选择优化范围：全部 skills 或指定 skills。
2. 为每个 skill 生成 2-3 个测试 prompt。
3. 用 8 个维度打基线分：结构 60 分，效果 40 分。
4. 按低分维度提出单点改进。
5. 修改 `SKILL.md` 后 commit。
6. 重新评估，如果分数严格上升就保留，否则用 `git revert` 回滚。
7. 每个 skill 优化完成后展示 diff、分数变化和测试输出，等用户确认。
8. 输出汇总报告和结果记录。

它和普通“review skill”的差别在于：不是只给意见，而是把“可测量改进”当作保留条件，把失败尝试从 git 历史上隔离成可回滚实验。

## 为什么它更像朋友分享的那个

- 名称精确：仓库名就是 `darwin-skill`，README 标题是“达尔文.skill”。
- 中文社区信号强：Jimo Studio 和 53AI 都在 2026-04-14 发布了相关介绍，并直接给出 `https://github.com/alchaincyf/darwin-skill` 与 `npx skills add alchaincyf/darwin-skill`。
- 功能描述吻合“skill”：它明确以 `SKILL.md` 为优化对象，而不是泛化的 agent 生态治理。
- 市场索引命中：mdgrok 页面把它索引为 `darwin-skill`，并显示 GitHub repo 为 `alchaincyf/darwin-skill`。
- 仓库热度更高：GitHub API 截至本次调研显示 `1088` stars、`132` forks；而 `simota/agent-skills` 父仓库为 `24` stars、`4` forks。

## 主要风险

- 许可证边界：`alchaincyf/darwin-skill` README 写 MIT，但 GitHub API `license` 字段为 `null`，根目录内容清单没有独立 `LICENSE` 文件。公开 vendor 前建议开 issue 或 PR 请求补 LICENSE。
- 自动修改风险：它会编辑 `SKILL.md`、创建分支、commit、revert。当前仓库有严格 rules 与 AGENTS 约束，不能让外部 skill 绕过本地执行纪律。
- 子 agent 规则冲突：原 skill 要用子 agent 独立评分；当前 Codex 环境只有用户明确授权 sub-agent/parallel agent work 时才能 `spawn_agent`。本地 adapter 需要把“子 agent”降级为 dry-run 或要求用户确认。
- 路径不匹配：原文默认扫描 `.claude/skills/*/SKILL.md`，当前仓库的真源分布在 `shared/skills`、`community/superpowers/skills`、`community/anthropic/skills`、`community/vercel/skills`，安装合成规则也不同。
- commit 语义不匹配：原 skill 每轮优化都会 commit；当前仓库默认不能替用户提交，除非用户明确要求走提交流程。

## 纳入当前仓库的建议方案

建议采用“隔离 vendor + 本地 adapter + 默认只评估”的方式。

推荐落点：

| 内容 | 建议路径 | 说明 |
| --- | --- | --- |
| upstream 原文 | `community/alchaincyf/skills/darwin-skill/SKILL.md` | 保持上游内容，不直接改写 |
| Codex 适配层 | `community/alchaincyf/codex/skills/darwin-skill/` | 把触发、路径、sub-agent、commit 策略适配到本仓库规则 |
| 来源锁 | `community/SOURCES.yaml` | 记录 repo、commit ref、captured_at、scope、许可证备注 |
| 调研/风险说明 | `docs/darwin-skill-20260418/` | 保留本报告作为引入依据 |

默认行为建议：

- 默认只跑 `评估所有 skills` 或 `评估指定 skill`。
- 修改前必须展示测试 prompt、目标 skill 列表与预期改动范围。
- commit、revert、批量修改、子 agent 评分都必须单独确认。
- 结果文件不要写入 `.claude/skills/darwin-skill/results.tsv`，而应写到本仓库受控文档目录，例如 `docs/skill-quality-audit/<date>/results.tsv`。

## 最强支持、最强挑战、失效边界

最强支持：

`alchaincyf/darwin-skill` 有精确名称、明确 GitHub 地址、中文发布文章、marketplace 索引和高热度，功能上也直接面向 `SKILL.md` 优化，和当前仓库维护大量 skills 的诉求高度一致。

最强挑战：

它的运行方式偏主动，会修改、提交、回滚 skill 文件。当前仓库的价值在于 rules/hooks/contracts/small-chain 的强约束；如果直接照搬，Darwin 可能绕开本地的验证、提交和 sub-agent 授权规则。

失效边界：

如果朋友分享的是“multi-agent 生态健康检查 / agent relevance / `.agents/ECOSYSTEM.md`”这类能力，而不是“优化 SKILL.md”，那目标就应切换为 `simota/agent-skills/darwin`，不是 `alchaincyf/darwin-skill`。

## 检索路径与覆盖证明

### 名称归一化

- `darwin skill`
- `Darwin Skill`
- `darwin-skill`
- `达尔文.skill`
- `达尔文 skill`
- `Ecosystem self-evolution orchestrator`
- `autonomous skill optimizer`

### 覆盖的对象类型

- GitHub 仓库主页
- GitHub raw `SKILL.md`
- GitHub API repo metadata
- GitHub API contents metadata
- 技能市场索引页面
- 中文发布文章
- 当前仓库本地全文搜索

### 本地扫描结果

当前仓库没有独立 `darwin` skill。本地 `rg -n "darwin|Darwin|DARWIN" .` 只命中 macOS/Darwin 系统判断：

| 路径 | 命中含义 |
| --- | --- |
| `community/anthropic/skills/web-artifacts-builder/scripts/init-artifact.sh` | `OSTYPE == darwin*` |
| `community/anthropic/skills/xlsx/scripts/recalc.py` | `platform.system() == "Darwin"` |

### 关键事实

`alchaincyf/darwin-skill`：

- `created_at`: 2026-04-13T08:57:49Z
- `pushed_at`: 2026-04-14T15:37:16Z
- `updated_at`: 2026-04-17T23:17:56Z
- `default_branch`: `master`
- `stargazers_count`: 1088
- `forks_count`: 132
- `license`: `null`
- 根目录包含 `README.md`、`README_EN.md`、`SKILL.md`、`assets/`、`docs/`、`scripts/`、`templates/`、`showcase.html`
- `SKILL.md`: 368 行，14777 字节

`simota/agent-skills`：

- `created_at`: 2026-01-07T04:26:40Z
- `pushed_at`: 2026-04-17T13:48:22Z
- `updated_at`: 2026-04-17T13:48:28Z
- `default_branch`: `main`
- `stargazers_count`: 24
- `forks_count`: 4
- `license`: MIT
- Darwin 路径包含 `darwin/SKILL.md` 与 `darwin/references/`
- `darwin/SKILL.md`: 236 行，18938 字节

## 证据源

外部来源：

- [alchaincyf/darwin-skill GitHub 仓库](https://github.com/alchaincyf/darwin-skill)
- [alchaincyf/darwin-skill SKILL.md](https://raw.githubusercontent.com/alchaincyf/darwin-skill/master/SKILL.md)
- [alchaincyf/darwin-skill README.md](https://raw.githubusercontent.com/alchaincyf/darwin-skill/master/README.md)
- [alchaincyf/darwin-skill GitHub API metadata](https://api.github.com/repos/alchaincyf/darwin-skill)
- [alchaincyf/darwin-skill GitHub API contents](https://api.github.com/repos/alchaincyf/darwin-skill/contents?ref=master)
- [mdgrok darwin-skill 索引](https://mdgrok.com/skills/318713)
- [Jimo Studio 达尔文.skill 发布文章](https://jimo.studio/blog/darwin-skill-released-a-revolutionary-self-evolving-skill-system/)
- [53AI 达尔文.skill 发布文章](https://www.53ai.com/news/tishicijiqiao/2026041447532.html)
- [simota/agent-skills GitHub 仓库](https://github.com/simota/agent-skills)
- [simota/agent-skills Darwin SKILL.md](https://raw.githubusercontent.com/simota/agent-skills/main/darwin/SKILL.md)
- [simota/agent-skills Darwin GitHub 目录](https://github.com/simota/agent-skills/tree/main/darwin)
- [Playbooks simota Darwin 页面](https://playbooks.com/skills/simota/agent-skills/darwin)
- [Skills Playground simota Darwin 页面](https://skillsplayground.com/skills/simota-agent-skills-darwin/)

本仓库内部来源：

- [README.md](/Users/lijieli/org-claude-skills/README.md)
- [community/SOURCES.yaml](/Users/lijieli/org-claude-skills/community/SOURCES.yaml)
- 本地命令：`rg -n "darwin|Darwin|DARWIN" .`
