# andrej-karpathy-skills 调研报告

> 调研日期：2026-04-16
> 调研对象：forrestchang/andrej-karpathy-skills
> 调研模式：analysis
> 呈现模式：decision

## 这次要回答的问题

- 这个 GitHub 仓库到底是什么，不是什么。
- 它解决的核心问题是什么，成熟度如何。
- 它和我们当前 `org-claude-skills` 的关系是互补、替代，还是只有局部可借鉴。
- 结论上我们该不该引入，应该怎么引入。

## 当前判断

- 它不是一套可替代我们现有体系的“技能平台”，而是一个非常轻量的行为准则包。
- 对我们有帮助，但帮助方式不是“拿来替换”，而是“拿来提炼和包装”。
- 推荐结论：`吸收其表达方式，不引入为运行时依赖，不替代现有 small-chain / rules / hooks / skills 体系。`

## 决定性理由

- 远端仓库去掉 `.git` 后只有 6 个文件，核心就是 `CLAUDE.md`、一个同义 `SKILL.md`、`EXAMPLES.md` 和 Claude Code plugin 清单，说明它本质上是“轻量行为约束包”，不是完整 runtime 系统。
- 它的核心只有四条原则：
  - `Think Before Coding`
  - `Simplicity First`
  - `Surgical Changes`
  - `Goal-Driven Execution`
- 这四条原则与我们已有体系高度同向：
  - “不要猜、先澄清” 对应我们的执行纪律与 `using-superpowers`
  - “保持简单” 对应我们的设计原则与 YAGNI 倾向
  - “只做必要改动” 对应我们的执行纪律“只改要求改的”
  - “可验证目标驱动” 对应我们的铁律“完成 = 验证通过”
- 它真正强的是“表达短、传播快、上手轻”：
  - 可以作为 Claude Code plugin 安装
  - 也可以直接拼接成项目级 `CLAUDE.md`
  - `EXAMPLES.md` 用“错误示例 vs 正确示例”解释原则， onboarding 友好
- 它最近仍有维护，但最近几次提交主要在 README 和 plugin packaging：
  - 2026-04-15：README 增加项目/社媒链接
  - 2026-02-16：修 plugin skill path
  - 2026-01-31：补 marketplace/plugin 结构与示例
- 这意味着它更像一个“优秀的极简前门”，不是一个持续扩张的复杂平台。

## 最大风险与保留意见

- 它没有 `rules / reference / hooks / contracts / tests` 这类强约束结构，无法替代我们当前的运行时基线。
- 它没有 Codex 原生适配，没有双运行面安装与验证设计。
- 它强调“行为倾向”，但缺少我们最看重的“可机械验证流程门禁”。
- README、`plugin.json`、`SKILL.md` 都写了 `MIT`，但 GitHub API 的 `license` 字段是 `null`，且根目录未看到独立 `LICENSE` 文件；如果未来想 vendor 或再分发，需要先确认许可证边界。

## 建议动作

1. `采纳表达，不采纳依赖`：把它作为外部参考，不把它 vendor 成运行时真源。
2. `提炼一个 lite 入口`：从我们现有 rules 里抽出 4-6 条“新用户先记住这些”的总则，做成短版 onboarding 文案。
3. `补示例层`：参考它的 `EXAMPLES.md` 结构，为我们最关键的 3-5 条规则补“反例/正例”。
4. `许可证确认前不分发`：如果想引用其原文或做外部分发的派生版本，先确认 LICENSE 文件与再分发边界。

## 独立挑战记录

- Challenger 观点：我们可能低估了它的价值。现有体系虽然强，但也更重；对轻任务或新用户来说，一套短而硬的行为基线可能比完整 runtime contract 更容易落地。
- 回应：这个挑战成立一半。它确实更像“极简前门”而不是“弱版替代品”，所以本次结论不是“不值得”，而是“值得吸收成入口层”。我不建议整仓引入，是因为它在运行时约束、跨平台适配和验证门禁上都远弱于我们；但如果目标是建设一个 `lite mode` 或 `quickstart mode`，它的参考价值会明显上升。

## 检索路径与覆盖证明

### 名称归一化

- `forrestchang/andrej-karpathy-skills`
- `andrej-karpathy-skills`
- `karpathy-skills`
- `karpathy-guidelines`
- `Karpathy-Inspired Claude Code Guidelines`

### 覆盖的对象类型

- GitHub 仓库主页
- `README.md`
- `CLAUDE.md`
- `EXAMPLES.md`
- `skills/karpathy-guidelines/SKILL.md`
- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- GitHub API 仓库元数据
- GitHub API 最近提交记录

### 候选排除表

| 候选 | 判断 | 证据 |
| --- | --- | --- |
| `forrestchang/andrej-karpathy-skills` GitHub 仓库 | 命中 | 目标 URL 直接指向该仓库；README、插件清单、skill 目录一致 |
| Andrej Karpathy 官方仓库/官方发布物 | 排除 | owner 是 `forrestchang`；README 写的是“derived from Andrej Karpathy's observations”，不是 Andrej 官方维护 |
| 多 skill/多 agent 的流程框架 | 排除 | 远端非 `.git` 文件共 6 个；不存在 rules/hooks/contracts/tests 体系 |
| Codex 原生插件/双运行面适配仓库 | 排除 | README 只覆盖 Claude Code plugin 或直接复制 `CLAUDE.md`；未提供 Codex adapter、hooks 或 install 流程 |

### 关键事实

- GitHub API 元数据（截至 2026-04-16）：
  - `created_at`: 2026-01-27
  - `pushed_at`: 2026-04-15
  - `stargazers_count`: 43140
  - `forks_count`: 3497
- 远端非 `.git` 文件只有 6 个：
  - `README.md`
  - `CLAUDE.md`
  - `EXAMPLES.md`
  - `skills/karpathy-guidelines/SKILL.md`
  - `.claude-plugin/plugin.json`
  - `.claude-plugin/marketplace.json`

### 剩余盲区

- 未发现独立 `LICENSE` 文件，许可证声明是否足以支持再分发，仍需进一步确认。
- 本次没有把外部社区二手评价纳入主证据，只以仓库一手材料和 GitHub 元数据为准。

## 项目上下文

我们当前仓库的定位是：统一维护 Claude Code 与 Codex CLI 的 `skills / rules / reference / hooks / agents`，默认轻量链收口到 `small-chain`。这不是一页提示词仓库，而是一套“运行时合同 + 执行流程 + 工具适配”的完整系统，证据见 [README.md](/Users/lijieli/org-claude-skills/README.md) 与 [shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md)。

本地扫描补充事实：

- `shared/skills/` 下有 28 个 first-party skills。
- `community/superpowers/skills/` 下有 11 个流程类 skill。
- `community/anthropic/skills/` 下有 17 个官方镜像 skill。
- `community/vercel/skills/` 下有 2 个社区镜像 skill。
- `tests/` 根目录下当前有 46 个测试脚本。

这决定了我们判断“有帮助”的标准不是“它是否火”，而是“它能否补强我们的表达层、入口层或轻量模式”。

## 证据源

外部来源：

- [GitHub 仓库主页](https://github.com/forrestchang/andrej-karpathy-skills)
- [README.md](https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/README.md)
- [CLAUDE.md](https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/CLAUDE.md)
- [EXAMPLES.md](https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/EXAMPLES.md)
- [plugin.json](https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/.claude-plugin/plugin.json)
- [marketplace.json](https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/.claude-plugin/marketplace.json)
- [GitHub API repo metadata](https://api.github.com/repos/forrestchang/andrej-karpathy-skills)
- [GitHub API commits](https://api.github.com/repos/forrestchang/andrej-karpathy-skills/commits?per_page=10)

本仓库内部来源：

- [README.md](/Users/lijieli/org-claude-skills/README.md)
- [shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md)
- [community/superpowers/skills/using-superpowers/SKILL.md](/Users/lijieli/org-claude-skills/community/superpowers/skills/using-superpowers/SKILL.md)
- [shared/rules/铁律.md](/Users/lijieli/org-claude-skills/shared/rules/铁律.md)
- [shared/rules/执行纪律.md](/Users/lijieli/org-claude-skills/shared/rules/执行纪律.md)
