# AI CLI 更新执行手册

## 目标

用当前运行证据更新 Claude Code 与 Codex CLI。保持用户现有安装渠道，避免把一次晨检升级变成迁移、重装或配置改造。

## 通用命令顺序

1. 读取可执行文件路径：`command -v claude`、`command -v codex`
2. 读取 CLI 版本：`claude --version`、`codex --version`
3. 识别包管理器来源：优先检查 npm/pnpm/bun/Homebrew/winget 中已存在的同名包
4. 查询远端版本：使用现有包管理器的 metadata 命令或官方 release/changelog
5. 运行更新命令：只对已确认安装来源执行
6. 再次读取路径、版本和包管理器证据

## 安全边界

- 不运行 `sudo`。
- 不卸载旧包。
- 不迁移安装渠道。
- 不编辑 `~/.claude`、`~/.codex`、shell profile、认证文件或项目文件。
- 更新命令要求交互式确认、登录或权限提升时，停止该目标并报告。

## Claude Code

官方信息源：

- 安装与检查文档：https://docs.anthropic.com/en/docs/claude-code/setup
- Changelog：https://code.claude.com/docs/en/changelog

证据命令：

```bash
command -v claude
claude --version
npm ls -g @anthropic-ai/claude-code --depth=0
pnpm ls -g @anthropic-ai/claude-code --depth=0
bun pm ls -g @anthropic-ai/claude-code
brew list --formula | rg '^claude-code$|^claude$'
brew list --cask | rg '^claude-code$|^claude$'
```

更新命令矩阵：

| 已识别来源 | 更新命令 |
| --- | --- |
| npm global | `npm install -g @anthropic-ai/claude-code@latest` |
| pnpm global | `pnpm add -g @anthropic-ai/claude-code@latest` |
| bun global | `bun add -g @anthropic-ai/claude-code@latest` |
| Homebrew formula | `brew upgrade claude-code` |
| Homebrew cask | `brew upgrade --cask claude-code` |

阻塞条件：

- `claude` 存在但无法识别安装来源。
- 包管理器显示多个来源同时安装。
- 官方文档提示当前来源需要迁移。
- 更新命令要求管理员权限。

## Codex CLI

官方信息源：

- CLI 文档：https://developers.openai.com/codex/cli
- Changelog：https://developers.openai.com/codex/changelog
- 开源仓库：https://github.com/openai/codex

证据命令：

```bash
command -v codex
codex --version
npm ls -g @openai/codex --depth=0
pnpm ls -g @openai/codex --depth=0
bun pm ls -g @openai/codex
brew list --formula | rg '^codex$|^openai-codex$'
```

更新命令矩阵：

| 已识别来源 | 更新命令 |
| --- | --- |
| npm global | `npm install -g @openai/codex@latest` |
| pnpm global | `pnpm add -g @openai/codex@latest` |
| bun global | `bun add -g @openai/codex@latest` |
| Homebrew formula | `brew upgrade codex` |

阻塞条件：

- `codex` 存在但无法识别安装来源。
- npm 与 Homebrew 同时提供 `codex`。
- 更新命令要求登录、权限提升或改写配置。

## Changelog 解读规则

- 版本变化时，只覆盖 `old exclusive -> new inclusive` 的版本区间。
- 无版本变化时，读取当前版本条目和最新条目，标注“本机无版本跃迁”。
- 官方 changelog 不可达时，使用官方 GitHub release 或包 metadata 补充，并在来源中标注。
- 不把原始条目逐字搬运；每条变化要转译成用户影响。
