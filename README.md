# org-claude-skills

统一维护 Claude Code 与 Codex CLI 的 skills/rules/reference/hooks/agents。

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
- 元数据文件：
  - `~/.claude/.org-installed-manifest` / `~/.codex/.org-installed-manifest`
  - `~/.claude/.org-backup-manifest` / `~/.codex/.org-backup-manifest`
  - `~/.claude/.org-pruned-manifest` / `~/.codex/.org-pruned-manifest`

## 发布与回滚

- 发布检查清单：`docs/release-checklist.md`
- 回滚 SOP：`docs/rollback-sop.md`
- 版本发布说明：`docs/releases/1.0.1.md`
- 分支保护配置：`docs/github-branch-protection.md`
