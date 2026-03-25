# 发布检查清单（Release Checklist）

适用范围：`org-claude-skills` 仓库版本发布前后的统一操作。

## A. 发布前（必须全通过）

1. 工作区检查  
执行：
```bash
git status --short
```
要求：仅包含本次发布相关变更。

2. 版本与变更记录一致  
检查：
- `VERSION`
- `CHANGELOG.md`
- `docs/releases/{version}.md`

3. 全量自动化校验  
执行：
```bash
bash tests/run-all.sh
```
要求：`All tests passed`。

4. 安装器去噪与可恢复能力确认  
执行：
```bash
bash install.sh --target all --dry-run --force
```
要求：
- 输出包含计划写入信息。
- 若存在旧受管遗留文件，输出应明确“将清理 N 个旧版本遗留受管文件”。

5. 本机实装验证（建议）  
执行：
```bash
bash install.sh --target all --force --check quick
```
要求：
- Quick Check 通过。
- `~/.org-skills-state/claude/pruned-manifest` 与 `~/.org-skills-state/codex/pruned-manifest` 存在。
- `~/.claude` 与 `~/.codex` 根目录不存在 `.org-*` 与 `.org-backups/`。

6. 技能可见性验证（Codex CLI）  
执行：
```bash
cd ~/.claude
codex exec --json "List all currently available skills by exact name only, one per line, no extra text."
```
要求：核心技能（如 `product/design/test-design/tech-lead/project-manager`）可见。

7. 旧 `.claude` 仓库迁移完成后执行退役  
执行：
```bash
bash tools/migration/retire-dot-claude.sh --claude-dir ~/.claude
```
要求：
- `.claude/.git` 被归档并移除。
- `docs/reconciliation/dot-claude-inventory.md` 中标注为 repo-only 的旧文件不再保留在运行目录。

## B. 发布执行

1. 合并主分支并打版本标签（示例）
```bash
git add .
git commit -m "release: v1.1.0"
git tag v1.1.0
git push && git push --tags
```

2. 发布公告最少包含
- 版本号
- 变更摘要
- 升级命令
- 回滚入口（`docs/rollback-sop.md`）

## C. 发布后验证

1. 在“干净 HOME”环境跑一次安装 smoke。  
2. 随机抽 1 台同事机器执行升级命令并验证技能可见。  
3. 记录问题与处置到下一版本发布说明。
