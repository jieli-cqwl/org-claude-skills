# Install Test Scenario Migration Map

Created: 2026-04-22

旧安装测试迁移验收等式：

```text
旧场景总数 = 已迁移场景数 + 有明确理由删除场景数
21 = 21 + 0
```

| 旧脚本 | 旧 case / pass 文案 | 新测试文件 | 环境类型 | quick/full | 保留的质量断言 | 处理状态 |
|---|---|---|---|---|---|---|
| `tests/test-install-systematic.sh` | 无 openspec CLI 依赖 | `tests/test-install-core.sh` | `fresh-home` | quick + full | 缺少 openspec CLI 时安装成功，且不输出 openspec 缺失警告 | migrated |
| `tests/test-install-systematic.sh` | dry-run 无副作用 | `tests/test-install-core.sh` | `fresh-home` | quick + full | dry-run 不写 claude/codex installed-version 元数据 | migrated |
| `tests/test-install-systematic.sh` | 冲突阻断生效 | `tests/test-install-core.sh` | `fresh-home` | quick + full | 非 force 安装遇到本地文件冲突时失败，并保留原文件内容 | migrated |
| `tests/test-install-systematic.sh` | 幂等安装生效 | `tests/test-install-core.sh` | `baseline-clone` | quick + full | 真实 baseline 产生 runtime 控制面文件；同版本重装修复缺失依赖并保持版本不变 | migrated |
| `tests/test-install-systematic.sh` | 同版本安装会修复 product split skill 缺失 | `tests/test-install-core.sh` | `baseline-clone` | quick + full | 删除 product-director/product-manager 后，同版本安装恢复文件并输出运行面不完整提示 | migrated |
| `tests/test-install-systematic.sh` | 卸载安全保护生效 | `tests/test-install-safety.sh` | `fresh-home` | full | backup-manifest 缺失时拒绝卸载，并保留 managed 文件 | migrated |
| `tests/test-install-systematic.sh` | 安装失败回滚生效 | `tests/test-install-safety.sh` | `fresh-home` | full | 安装失败时删除已写 managed agent，并不留下 installed-version | migrated |
| `tests/test-install-systematic.sh` | Claude hooks 默认合并并可恢复 baseline | `tests/test-install-runtime.sh` | `fresh-home` | full | 缺少 settings.json 时安装创建 hooks；PostCompact 输出保留状态锚点；卸载移除托管生成的 settings.json | migrated |
| `tests/test-install-systematic.sh` | codex toml 占位符替换生效 | `tests/test-install-runtime-smoke.sh` | `fresh-home` | quick + full | developer.toml 包含具体 HOME 路径且不含 `{{HOME}}`；codex config 启用 hooks | merged-stronger |
| `tests/test-install-systematic.sh` | codex 同版本重装不覆盖 developer skill 本地修改 | `tests/test-install-core.sh` | `baseline-clone` | quick + full | 本地追加 developer SKILL.md 内容后，同版本重装保留本地修改并输出已是最新版本 | migrated |
| `tests/test-install-systematic.sh` | codex hooks.json 失效临时探针清理生效 | `tests/test-install-runtime.sh` | `baseline-clone` | full | 清理 stale probe hook，保留有效用户 hook，安装 managed hooks，移除非标准 SessionStart | migrated |
| `tests/test-install-systematic.sh` | codex 卸载保留用户 hooks 并恢复 config baseline | `tests/test-install-safety.sh` | `fresh-home` | full | 卸载保留用户 hooks.json，移除 managed hooks，并恢复 codex_hooks baseline | migrated |
| `tests/test-install-systematic.sh` | codex 卸载恢复非标准 hooks 基线 | `tests/test-install-safety.sh` | `fresh-home` | full | 卸载后恢复原始非标准 SessionStart hooks，并不保留 managed hooks | migrated |
| `tests/test-install-systematic.sh` | 退役 product 软链接技能清理生效 | `tests/test-install-migration.sh` | `constructed-legacy-home` | full | 旧 product 软链接 skill 安装后被清理 | migrated |
| `tests/test-install-systematic.sh` | 旧版本遗留受管文件清理与恢复生效 | `tests/test-install-migration.sh` | `constructed-legacy-home` | full | stale managed file 被 prune，写入 pruned-manifest，并可在卸载后恢复 | migrated |
| `tests/test-install-systematic.sh` | 运行目录旧元数据迁移生效 | `tests/test-install-migration.sh` | `constructed-legacy-home` | full | `.org-*` 旧元数据迁出 runtime dir，state backup manifest 指向外部 state backups | migrated |
| `tests/test-install-systematic.sh` | 卸载后状态目录清理生效 | `tests/test-install-safety.sh` | `fresh-home` | full | all target 卸载后 claude/codex state dirs 被删除 | migrated |
| `tests/test-install-systematic.sh` | 旧 .claude git 退役生效 | `tests/test-install-migration.sh` | `constructed-legacy-home` | full | 移除 `.git`，保留 runtime 文件，归档 repo-only 文件和未跟踪噪音文件 | migrated |
| `tests/test-install-systematic.sh` | 重复覆盖安装仍保留原始恢复基线 | `tests/test-install-safety.sh` | `fresh-home` | full | 重复 force 安装后卸载仍恢复用户原始 hook 文件 | migrated |
| `tests/test-install-systematic.sh` | 退役 skill 残留清理生效 | `tests/test-install-runtime.sh` | `baseline-clone` | full | codex 退役 `project-agents-init` 残留安装后被删除 | migrated |
| `tests/test-install-runtime-audit.sh` | install runtime audit | `tests/test-install-runtime.sh` | `baseline-clone` | full | 同版本 codex audit 移除 legacy symlink residue，保留 default.rules，归档 unexpected artifact，版本不变 | migrated |

## Existing Smoke Absorption

`tests/test-install-smoke.sh` was an active smoke entrypoint before this refactor. It was not part of the 21-row systematic/runtime-audit migration equation above, so its runtime-shape responsibilities were absorbed separately into `tests/test-install-runtime-smoke.sh` before deleting the old file.

| 旧 smoke 责任 | 新测试文件 | quick/full | 保留的质量断言 | 处理状态 |
|---|---|---|---|---|
| Claude skill and runtime asset presence | `tests/test-install-runtime-smoke.sh` | quick + full | core/product/manual-only skills, hooks, settings, commands, and protocol migration are present after install | absorbed |
| Codex skill, adapter, and agent presence | `tests/test-install-runtime-smoke.sh` | quick + full | AGENTS, adapters, manual-only skills, agent TOML files, generic/code-reviewer content, and github-repo-radar adapter are present after install | absorbed |
| Hook/config registration | `tests/test-install-runtime-smoke.sh` | quick + full | Codex hooks.json contains managed commands; developer.toml has concrete HOME paths and no `{{HOME}}` placeholders; Claude hooks execute | absorbed |
| External state and legacy metadata shape | `tests/test-install-runtime-smoke.sh` | quick + full | external state directories exist and runtime dirs do not contain legacy `.org-*` metadata | absorbed |
| Uninstall cleanup shape | `tests/test-install-runtime-smoke.sh` | quick + full | all-target uninstall removes managed skills, agents, hooks, external state, Codex hooks.json, and restores Claude settings baseline | absorbed |
