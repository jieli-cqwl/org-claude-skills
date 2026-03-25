# 回滚 SOP（安装异常 / 发布后回退）

目标：在不误删用户本地资产的前提下，快速回到稳定状态。

## 1. 触发条件

满足任一条件即可触发回滚：
- 安装后技能不可用或行为异常。
- 团队机器出现一致性故障（同版本广泛复现）。
- `tests/run-all.sh` 在发布后基线失败。

## 2. 一键回滚（首选）

在目标机器执行：
```bash
cd ~/org-claude-skills
bash install.sh --uninstall --target all
```

说明：
- 会依据 `.org-installed-manifest` 删除本次受管文件。
- 会依据 `.org-backup-manifest` 恢复被覆盖文件。
- 会依据 `.org-pruned-manifest` 恢复安装时清理的历史受管条目。

## 3. 回到上一稳定版本

1. 切回稳定标签（示例 `v1.0.0`）：
```bash
git fetch --tags
git checkout v1.0.0
```

2. 重新安装：
```bash
bash install.sh --target all --force --check quick
```

## 4. 回滚后校验（必须）

执行：
```bash
cd ~/.claude
codex exec --json "List all currently available skills by exact name only, one per line, no extra text."
```

检查项：
- 核心技能可见。
- `install.sh --check quick` 可通过。
- 关键配置文件（如 `~/.codex/config.toml`）未被异常改写。

## 5. 故障归档

回滚完成后应补充：
- 故障版本、触发场景、影响范围。
- 回滚时间线与执行命令。
- 根因与后续修复计划（进入下一版本 `CHANGELOG`）。
