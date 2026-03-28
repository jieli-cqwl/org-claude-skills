# community-first 集成调研报告

## 1. 调研目标

- 目标 A：确认 `opsx:propose` 在 OpenSpec 原版中的设计方式和使用方式。
- 目标 B：确认当前仓库的 `community-first` 接法，问题到底是“我们使用错了”，还是“OpenSpec 原版设计不适合当前平台”。
- 目标 C：为后续一次性改造提供可执行结论，而不是继续靠推断。

## 2. 项目上下文扫描

当前仓库的 `community-first` 默认链定义为：

- `brainstorming -> opsx:propose -> writing-plans -> using-git-worktrees -> opsx:apply -> (subagent-driven-development 默认 / executing-plans 备选) -> requesting-code-review -> verification-before-completion -> opsx:verify -> opsx:archive`

证据：

- [shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md)
- [docs/community-first/README.md](/Users/lijieli/org-claude-skills/docs/community-first/README.md)
- [contracts/community-first-chain.yaml](/Users/lijieli/org-claude-skills/contracts/community-first-chain.yaml)

当前 Codex 侧 `opsx:*` 的安装方式不是 skill，而是 prompt：

- `community-adapters/codex/prompts/opsx-*.md`
- 安装时复制到 `~/.codex/prompts/`

证据：

- [install.sh](/Users/lijieli/org-claude-skills/install.sh#L318)
- [install.sh](/Users/lijieli/org-claude-skills/install.sh#L519)
- [docs/community-first/README.md](/Users/lijieli/org-claude-skills/docs/community-first/README.md#L93)

## 3. OpenSpec 原版设计

### 3.1 `opsx:propose` 是什么

`/opsx:propose` 是 OpenSpec 默认 `core` profile 里的核心起始命令，用于：

- 创建 `openspec/changes/<change-name>/`
- 一次性生成 planning artifacts
- 在 ready for `/opsx:apply` 时停止

官方证据：

- OpenSpec Commands: https://github.com/Fission-AI/OpenSpec/blob/main/docs/commands.md
- OpenSpec README: https://github.com/Fission-AI/OpenSpec

### 3.2 OpenSpec 原版如何接入 AI 工具

OpenSpec 原版假设的是：

1. 在项目中执行 `openspec init`
2. OpenSpec 为目标 AI 工具生成对应的 slash command / skill 入口
3. 如果 profile 或模板变化，执行 `openspec update`

官方明确写到：

- `openspec init` 会创建 AI coding assistants 能自动检测的 skills / slash commands
- 若命令不识别，先检查：
  - `openspec init`
  - `openspec update`
  - AI 工具是否重启

官方证据：

- OpenSpec 官网：`Supported Tools` 中明确写了 “native support with custom slash commands built-in”
  - https://openspec.dev/
- OpenSpec README：
  - `Now tell your AI: /opsx:propose <what-you-want-to-build>`
  - `Run openspec update ... ensure the latest slash commands are active`
  - https://github.com/Fission-AI/OpenSpec
- OpenSpec Troubleshooting：
  - `Commands not recognized`
  - 解决方式包括 `openspec init` 与 `openspec update`
  - https://github.com/Fission-AI/OpenSpec/blob/main/docs/commands.md

### 3.3 OpenSpec 原版工作区结构

OpenSpec 原版默认工作区就是：

- `openspec/config.yaml`
- `openspec/specs/`
- `openspec/changes/`
- `openspec/changes/archive/`

官方证据：

- https://github.com/Fission-AI/OpenSpec/blob/main/docs/getting-started.md
- https://github.com/Fission-AI/OpenSpec/blob/main/docs/commands.md

推论：

- 如果要做物理目录统一，最稳的统一根应直接围绕 `openspec/`，而不是发明一套新的根目录再去反向适配 CLI。

## 4. superpowers 原版设计

`superpowers/brainstorming` 原版的终点是：

- 写设计稿
- 用户 review
- 进入 `writing-plans`

不是：

- `opsx:propose`

官方证据：

- https://skills.sh/obra/superpowers/brainstorming
- [third_party/community/superpowers/skills/brainstorming/SKILL.md](/Users/lijieli/org-claude-skills/third_party/community/superpowers/skills/brainstorming/SKILL.md)

关键事实：

- 原版 `brainstorming` 和 OpenSpec 原版 `opsx:propose` 没有天然的原生直连关系。
- 当前仓库的 `brainstorming -> opsx:propose -> writing-plans` 是本地融合设计，不是任一 upstream 的原生默认链。

## 5. 当前仓库和原版的偏差

### 5.1 偏差 A：把 OpenSpec 的命令入口接成了 Codex prompt

当前仓库在 Codex 侧把 `opsx:*` 放进了：

- `~/.codex/prompts/opsx-*.md`

但真实 runtime 实测结果是：

- 显式执行 `/opsx:propose add-login-flow`
- Codex 没有进入 OpenSpec proposal 流程
- 而是回到了 `using-superpowers + brainstorming`

这说明：

- `prompts/opsx-*.md` 在当前 Codex 环境里不是可靠的 `/opsx:*` 命令入口

结论：

- 这是当前 FAIL 的直接原因
- 更像是本地接入方式错位，不是 `opsx:propose` 概念本身错误

### 5.2 偏差 B：我们把两条 upstream 链合成了本地融合链

当前仓库定义：

- `brainstorming -> opsx:propose -> writing-plans`

证据：

- [docs/community-first/README.md](/Users/lijieli/org-claude-skills/docs/community-first/README.md#L20)
- [contracts/community-first-chain.yaml](/Users/lijieli/org-claude-skills/contracts/community-first-chain.yaml#L12)

但 upstream 原版分别是：

- superpowers：`brainstorming -> writing-plans`
- OpenSpec：`/opsx:propose -> /opsx:apply -> /opsx:archive`

结论：

- 当前默认链不是“照着某个上游原样使用”，而是本地融合链。
- 因此后续决策必须明确承认：这是本地产品化设计，不再适合用“上游原意”来掩盖运行缺口。

## 6. 是否是“我们使用问题”

结论：**是，而且是两层使用问题。**

### 第一层：平台接入方式问题

高概率是我们把 OpenSpec 在 Codex 的入口接错了。

原版预期：

- 工具原生支持 slash commands，或由 `openspec init/update` 生成对应入口

当前做法：

- 我们手工维护 `community-adapters/codex/prompts/opsx-*.md`
- 再希望 Codex 把它们当 `/opsx:*` 命令

这一步目前没有被 runtime 验证通过。

### 第二层：流程融合问题

我们当前不是“使用 OpenSpec 原版”，而是“把 OpenSpec 插进了 superpowers 流程中间”。

这不是错，但它意味着：

- 后续必须把融合链当成自己的产品设计来维护
- 不能继续假设 upstream 自己会保证 `brainstorming -> opsx:propose` 自动成立

## 7. 推荐结论

### 7.1 关于 upstream 英文正文是否继续整份保留

在已经决定“中文 canonical runtime”的前提下，不建议继续把整份英文 upstream 快照长期保留在主仓库里作为运行相关内容。

更稳的方式是：

- 保留来源 URL
- 保留固定 commit/tag
- 保留同步脚本
- 必要时按需再拉取

理由：

- GitHub 原文本身已经是权威证据
- 整份快照继续留在主仓库里，对中文团队的日常阅读和运行设计会增加噪音

### 7.2 关于 `opsx:propose` 怎么修

推荐方向：

1. 不再把 Codex 侧 `opsx:*` 设计成 prompt 文件
2. 改成 Codex 真正可调用的 skill / 原生命令入口
3. 显式修复：
   - `/opsx:propose`
   - `/opsx:apply`
   - `/opsx:verify`
   - `/opsx:archive`
4. 再决定 `brainstorming -> opsx:propose` 的自动 handoff 机制

理由：

- 先修显式入口，才能谈自动链
- 当前 FAIL 已经证明 prompt 形态不可靠

### 7.3 关于流程本身怎么理解

必须明确：

- OpenSpec 原版：是 change/spec 生命周期框架
- superpowers 原版：是 design/plan/execution discipline 框架
- 当前仓库：是本地融合链

所以后续要做的是：

- 把本地融合链实现成“真的能跑”
- 而不是继续假设它已经天然成立

## 8. 最终判断

1. `opsx:propose` 原版设计本身没有明显问题。
2. 当前 FAIL 更像是我们在 Codex 侧把它接错了。
3. `brainstorming -> opsx:propose` 不是原版默认链，而是本地融合设计。
4. 后续如果继续一次性彻底改造，应该把焦点放在：
   - 正确入口形态
   - 中文 canonical runtime
   - 统一到 `openspec/` 的物理工作区

## 9. 证据清单

- OpenSpec 官网： https://openspec.dev/
- OpenSpec README： https://github.com/Fission-AI/OpenSpec
- OpenSpec Commands： https://github.com/Fission-AI/OpenSpec/blob/main/docs/commands.md
- superpowers brainstorming： https://skills.sh/obra/superpowers/brainstorming
- 当前仓库默认链：
  - [shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md)
  - [docs/community-first/README.md](/Users/lijieli/org-claude-skills/docs/community-first/README.md)
  - [contracts/community-first-chain.yaml](/Users/lijieli/org-claude-skills/contracts/community-first-chain.yaml)
