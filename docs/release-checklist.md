# 发布检查清单（Release Checklist）

适用范围：`org-claude-skills` 仓库版本发布前后的统一操作。

## A. 发布前门禁分层

### A1. 仓库发布前校验（必须通过）

1. 工作区与版本上下文一致  
执行：
```bash
git status --short
bash tools/release/validate-release-metadata.sh v{version}
```
要求：
- 工作区仅包含本次发布相关变更。
- `VERSION`、`CHANGELOG.md`、`docs/releases/{version}.md` 与 tag 一致。

2. 全量自动化校验  
执行：
```bash
bash tests/run-all.sh
```
要求：`All tests passed`。

3. 安装计划校验  
执行：
```bash
bash install.sh --target all --dry-run --force
```
要求：
- 输出包含计划写入信息。
- 若存在旧受管遗留文件，输出应明确“将清理 N 个旧版本遗留受管文件”。

说明：
- release workflow 自动阻断覆盖第 2、3 项以及 tag 触发下的发布元数据校验。
- `git status --short` 属发布前人工确认项，不在 GitHub Actions 自动阻断范围内。
- 任一失败，不得继续发布。

### A2. 本地强验证（必须留证）

1. 本机实装验证  
执行：
```bash
bash install.sh --target all --force --merge-hooks --check full
bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills
```
要求：
- Full Check 通过。
- 运行时真实探针无 `[FAIL]`。
- `~/.org-skills-state/claude/pruned-manifest` 与 `~/.org-skills-state/codex/pruned-manifest` 存在。
- `~/.claude` 与 `~/.codex` 根目录不存在 `.org-*` 与 `.org-backups/`。

2. 技能可见性验证（Codex CLI）  
执行：
```bash
cd ~/org-claude-skills
codex exec --json "List all currently available skills by exact name only, one per line, no extra text."
```
要求：
- 在 trusted git 仓库中执行，不要在 `~/.claude` 运行目录中执行。
- 默认自动入口 `brainstorming` 可见。
- `using-superpowers`、标准链与本地重叠 workflow skill 为 manual-only，不要求出现在默认自动发现面。
- 允许存在额外系统 skills，但仓库托管 skills 不得缺失，且不能与仓库技能重名冲突。

留证要求：
- 记录执行人、执行时间、版本号、关键命令与结果。
- 失败时附终端输出，不得只写“已验证通过”。

### A3. 人工抽样（发布后立即执行）

1. 在“干净 HOME”环境跑一次安装 smoke。  
2. 随机抽 1 台同事机器执行升级命令并验证技能可见。  
3. 按 `docs/runtime-acceptance-sop.md` 完成一次完整运行验收。  
4. 记录问题与处置到下一版本发布说明。

## B. 发布执行

1. 合并主分支并打版本标签（示例）
```bash
git add .
git commit -m "release: v1.2.1"
git tag v1.2.1
git push && git push --tags
```

2. 发布公告最少包含
- 版本号
- 变更摘要
- 升级命令
- 回滚入口（`docs/rollback-sop.md`）
- 本地强验证与人工抽样留证位置

## C. 特殊场景

1. 旧 `.claude` 仓库迁移完成后执行退役  
执行：
```bash
bash tools/migration/retire-dot-claude.sh --claude-dir ~/.claude
```
要求：
- `.claude/.git` 被归档并移除。
- `docs/reconciliation/dot-claude-inventory.md` 中标注为 repo-only 的旧文件不再保留在运行目录。

2. 运行时强验证未完成时
- 可以完成 CI 阻断，但不得声称“发布验收完成”。
- 必须补齐 A2 与 A3 的留证后，才能关闭本次发布验收。 

## D. 当前口径

- 第一阶段的目标是先把确定性、低噪音、可复验的发布门禁接入 release workflow。
- `install.sh --check full`、runtime probe、Codex 可见性验证仍然是发布前必须执行的强验证，但保留在本地/真实环境留证层，不强行纳入默认 CI。
- 若后续 runner、认证与 trusted repo 条件稳定，再评估是否把更多强验证提升为自动阻断。

## E. 相关文档

- `docs/runtime-acceptance-sop.md`
- `docs/runtime-validation.md`
- `docs/rollback-sop.md`
- `docs/github-branch-protection.md`
- `tools/release/validate-release-metadata.sh`
- `.github/workflows/release.yml`
