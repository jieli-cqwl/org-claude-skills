# dot-claude 差异承接清单

目标：在退役旧 `~/.claude` git 前，明确哪些内容已进入公共仓库、哪些应保留为本机运行配置、哪些应归档移出运行目录。

## 已承接到公共仓库

- `CLAUDE.md` → `shared/assistant.md`
- Review 迭代协议 → `shared/protocols/review-iteration-protocol.md`
- `contracts/identifiers.yaml`、`contracts/skill-chain.yaml` 以公共仓库版本为准
- `tools/validate-contracts.sh` 稳定入口与 `tools/dev/validate-contracts.sh` 以公共仓库版本为准
- 运行期标准内容以公共仓库安装结果为准：`hooks/`、`rules/`、`reference/`、`agents/`、`skills/`、`AGENTS/CLAUDE 入口文件`

## 本机运行配置，保留在 `~/.claude`

- `settings.json`
- `settings.local.json`
- `statusline-command.sh`
- `bin/jdtls-wrapper.sh`

说明：这些文件与本机环境、代理、通知、JDK 路径相关，不纳入公共仓库标准源。

## 退役时归档移出运行目录

以下旧 `.claude` tracked 文件不再保留在运行目录，由 `tools/migration/retire-dot-claude.sh` 统一归档到 `~/.org-skills-state/archive/`：

- 旧仓库元数据：`.git/`、`.gitignore`
- 旧 repo 级文档：`docs/skill-统一仓库调研与实施方案.md`、`docs/学习笔记/*`
- 旧输出样式：`output-styles/gemini-review.md`
- 旧 repo 级契约：`contracts/*`
- 旧 repo 级测试：`tests/*`
- 旧 repo 级工具：`tools/sync-codex.sh`、`tools/test-sync-codex.sh`、`tools/generate-all-openai-yaml.sh`、`tools/validate-contracts.sh`
- 已被全局 reference 替代的 skill 局部协议副本：
  - `skills/design/references/review-iteration-protocol.md`
  - `skills/review/references/review-iteration-protocol.md`
  - `skills/test-design/references/review-iteration-protocol.md`

## 已替代的能力说明

- 旧 `sync-codex.sh` 软链接同步链路已废弃，统一改为 `install.sh` 覆盖安装。
- 旧 `.claude/tests/*` 大套件不再作为运行目录资产保留；公共仓库以以下门禁替代：
  - `tests/test-install-smoke.sh`
  - `tests/test-install-systematic.sh`
  - `tests/test-runtime-integrity.sh`
  - `tools/validate-contracts.sh`

## 退役命令

```bash
cd ~/org-claude-skills
bash tools/migration/retire-dot-claude.sh --claude-dir ~/.claude
```

如需同时将旧远端 `dot-claude` 设为 archived：

```bash
cd ~/org-claude-skills
bash tools/migration/retire-dot-claude.sh --claude-dir ~/.claude --archive-remote
```
