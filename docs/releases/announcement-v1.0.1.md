# [发布通知] org-claude-skills v1.0.1

各位同事好，`org-claude-skills` 已发布 `v1.0.1`。

## 本次升级重点

1. 安装阶段自动清理旧版本遗留受管文件，减少历史噪音。  
2. 新增 `.org-pruned-manifest`，记录被清理条目。  
3. 卸载时可恢复被清理条目，避免误删风险。  
4. 系统测试补齐“清理 + 恢复”场景，发布基线更稳。

## 升级命令

```bash
cd ~/org-claude-skills
git pull --rebase
bash install.sh --target all --force --check quick
```

## 验证命令

```bash
cd ~/.claude
codex exec --json "List all currently available skills by exact name only, one per line, no extra text."
```

## 回滚入口

如需回滚，请按：`docs/rollback-sop.md`

## 备注

若终端会话缓存导致技能列表未刷新，请退出并重启 `codex` CLI 会话后重试。
