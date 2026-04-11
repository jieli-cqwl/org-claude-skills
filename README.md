# org-claude-skills

统一维护 Claude Code 与 Codex CLI 的 `skills / rules / reference / hooks / agents`，当前默认轻量链已收口为 `small-chain`。

## 当前状态

- 默认轻量链：`small-chain`
- 运行时基线：`community/superpowers`
- OpenSpec 定位：只保留概念与历史工件语义，不作为运行时依赖
- 进度真源：`tasks.md`
- 执行计划：`plan.md`（只保留 task-id 映射，不持有 checkbox 状态）

## 仓库结构

- `shared/`：first-party 真源，维护共享入口、规则、参考资料、协议与 first-party skills
- `community/superpowers/`：本地中文 runtime 与 overlay
- `community/anthropic/`：官方 `anthropics/skills` 镜像目录与 Codex 适配层
- `contracts/`：small-chain 与 superpowers 边界合同
- `docs/`：可选历史材料与非运行时文档，不参与当前活跃契约
- `claude/`：Claude 适配层
- `codex/`：Codex 适配层

## 当前真源

- 入口合同：`shared/assistant.md`
- 来源锁定：`community/SOURCES.yaml`
- 官方 skills 真源目录：`community/anthropic/skills`
- 官方 Codex adapters：`community/anthropic/codex/skills`
- small-chain 链路合同：`contracts/small-chain.yaml`
- superpowers 运行边界：`contracts/superpowers-boundary.yaml`
- 默认入口 skill：`community/superpowers/skills/using-superpowers/SKILL.md`

## 快速开始

```bash
git clone <repo-url> ~/org-claude-skills
cd ~/org-claude-skills
bash install.sh --target all
```

首次覆盖旧环境时可用：

```bash
bash install.sh --target all --force
```

Claude 安装现在默认会把托管 hooks 合并到 `~/.claude/settings.json`，并在 quick check 中校验关键 hooks 已生效。`--merge-hooks` 仅保留给旧脚本兼容场景。

Codex 安装会默认完成两件事：

- 托管启用 `~/.codex/config.toml` 中的 `features.codex_hooks = true`
- 将仓库管理的 hooks 合并到 `~/.codex/hooks.json`，保留 Claude 标准事件上的用户 hooks，并清理不在 Claude 标准事件面内的旧事件

## 常用命令

```bash
bash install.sh --target all --dry-run
bash install.sh --target all --check full
bash install.sh --uninstall --target all
bash tests/run-all.sh
bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills
```

## Small Chain

默认轻量链的正式 contract 见 `contracts/small-chain.yaml`，边界与 closeout 规则见 `contracts/superpowers-boundary.yaml`。

当前链路为：

1. `using-superpowers`（meta）
2. `brainstorming`（entry）
3. `writing-plans`（plan）
4. `using-git-worktrees`（env）
5. `subagent-driven-development`（execute）
6. `verification-before-completion`（verify-preflight）
7. `verify-change`（verify）
8. `finishing-a-development-branch`（integrate）
9. `archive`（finish）

约束：

- 执行统一收口到 `subagent-driven-development`
- 不再依赖 OpenSpec CLI
- `tasks.md` 是唯一完成状态真源
- `verify-change` 通过后才能进入 `finishing-a-development-branch` 或 `archive`

## 轻量改动路径

`small-chain` 是默认链路，但不是所有改动都必须先补齐整套工件。以下场景可以走轻量路径：

- `docs-only / script-only / config-only`
- 单文件小修或局部规则/说明更新
- 尚未建立 `tasks.md / plan.md` 等 small-chain 工件的老仓库

轻量路径仍必须满足：

- 遵守 `shared/rules/*.md` 的硬约束
- 先做影响范围判断，再控制改动边界
- 运行离改动最近的 fresh proving command，并如实汇报缺失的 build / lint / test 入口
- 如行为或约束发生变化，同步更新相关文档

## 发布与验证

- 结构与合同验证：`bash tools/validate-contracts.sh`
- 全量回归：`bash tests/run-all.sh`
- 运行能力探针：`bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills`
- Codex hooks 探针：`bash tools/dev/probe-codex-hooks.sh`

## Skills 来源与优先级

- `shared/skills/` 只承载 first-party skills
- `community/anthropic/skills/` 承载全量官方 17 个 skills，正文保持 upstream 原文
- 安装时按 `shared/skills -> community/superpowers/skills -> community/anthropic/skills` 顺序合成运行面
- 同名 skill 默认 first-party 优先；当前唯一官方接管特例是 `mcp-builder`
