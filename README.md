# org-claude-skills

统一维护 Claude Code 与 Codex CLI 的 skills/rules/reference/hooks/agents。

## 仓库结构

- `shared/`：唯一真源，维护共享的 `assistant.md / skills / rules / reference / agents / hooks-lib`
- `claude/`：Claude 适配层，仅保留全局 hooks 与 settings 片段
- `codex/`：Codex 适配层，仅保留 agent `.toml`

日常维护只改 `shared/` 和平台适配层；不再维护双份 `claude/skills` / `codex/skills` 源目录。

## 快速开始

```bash
git clone <repo-url> ~/org-claude-skills
cd ~/org-claude-skills
bash install.sh --target all
```

## 常用命令

```bash
bash install.sh --target all --dry-run
bash install.sh --target all --check full
bash install.sh --uninstall --target all
bash tools/migration/retire-dot-claude.sh --claude-dir ~/.claude
```

## 首次迁移提示

旧环境通常已存在同名文件（原 `.claude/.codex` 资产）。首次覆盖安装建议：

```bash
bash install.sh --target all --force
```

如需自动把 5 个 org 管理 hooks 合并进 `~/.claude/settings.json`：

```bash
bash install.sh --target claude --merge-hooks --force
```

## 安全与去噪保障

- 安装采用事务式回滚：中途失败会自动回滚已写入内容。
- 冲突保护默认开启：检测到非 org 管理同名文件会阻断（可用 `--force` 明确覆盖）。
- 旧版本遗留受管文件会在安装时自动清理，避免长期噪音堆积。
- 被清理文件会进入备份映射，卸载时可恢复，避免误删。
- 安装状态与备份统一外置到 `~/.org-skills-state/`，默认结构：
  - `~/.org-skills-state/claude/installed-version`
  - `~/.org-skills-state/claude/installed-manifest`
  - `~/.org-skills-state/claude/backup-manifest`
  - `~/.org-skills-state/claude/pruned-manifest`
  - `~/.org-skills-state/{claude,codex}/backups/`
- `.claude` / `.codex` 运行目录不再保留 `.org-*` 与 `.org-backups/` 安装元数据噪音。
- 支持通过 `ORG_STATE_ROOT=/custom/path` 自定义状态根目录。

## 统一真源与旧仓库退役

- 公共仓库 `org-claude-skills` 是唯一真源。
- 共享入口文档统一维护在 `shared/assistant.md`，安装时分别渲染到 `~/.claude/CLAUDE.md` 与 `~/.codex/AGENTS.md`。
- Claude / Codex 能力矩阵：`docs/capability-matrix.md`
- Codex hooks 支持结论：`docs/codex-hooks-support.md`
- 旧 `.claude` 仓库退役命令：

```bash
cd ~/org-claude-skills
bash tools/migration/retire-dot-claude.sh --claude-dir ~/.claude
```

- 该脚本会：
  - 归档 `.claude/.git`
  - 归档 `.claude` 中不属于运行期的旧 repo 文件
  - 保留本机运行文件，如 `settings.json`、`statusline-command.sh`
- 差异承接清单：`docs/reconciliation/dot-claude-inventory.md`

## 发布与回滚

- 发布检查清单：`docs/release-checklist.md`
- 回滚 SOP：`docs/rollback-sop.md`
- 版本发布说明：`docs/releases/1.2.0.md`
- 分支保护配置：`docs/github-branch-protection.md`
