# Changelog

## 1.2.4
- 新增 `nextlevelbuilder/ui-ux-pro-max-skill` vendor 源与安装层接入，`ui-ux-pro-max` 安装后按 manual-only 方式供 Claude / Codex 手动触发
- 修复 Codex 安装器注入的 completion gate 运行说明，避免把 `completion_check.sh` 误写成 fresh proving command 并诱导下游裸跑脚本、暴露内部 gate 细节
- 修复 `new-skills` 参考文档对 gate 脚本的错误心智模型，明确 `completion_check.sh` 只允许 runtime hook 或带 payload 的内部排查调用
- 收口 `codex_stop_dispatch.py` 的失败原因脱敏逻辑，避免将 `hook payload`、`session_id`、`transcript_path` 等内部上下文原样暴露到用户可见面
- 新增 `openspec/designs/2026-03-28-superpowers-openspec-best-practice-draft.md`，沉淀 `superpowers + OpenSpec` 最佳实践设计草稿
- 系统性修正 selected `community/superpowers` 中文 runtime 的误译、错译和术语污染，恢复 `skill id`、命令、路径、代码与术语缩写的英文保真
- 强化 `tools/community/sync_canonical_from_upstream.py` 的本地化保护边界，补齐来源头再生、`vs.` / `superpowers:*` / 大写缩写保护，以及嵌套 fenced code block 保护
- 新增 `tests/test-community-tools.sh` 回归用例，阻断来源头丢失、已知脏词回归和翻译污染再次出现
- 更新仓库规则与发布入口文档，明确 `community/superpowers` 的中文 runtime 策略和扩面约束
- 合并并清理运行边界与文档结构，收口 `superpowers` / `small-chain` / OpenSpec 的职责边界
- 强化 Codex runtime probe，修复默认暴露面与 skill 解析的误判逻辑，并补齐 `community/superpowers` 边界门禁
- 恢复安装与 full check 依赖的活跃发布/边界文档，重新打通 `install.sh --target all --force --merge-hooks --check full` 全链路验收
- 固化 `3056999` 运行时安装链路验收锚点：Claude Code / Codex 均安装 `context_contract_validator.py` 托管 hook，入口文档、hook registry 与运行时文件已同步，验收命令为 `bash tests/run-all.sh --quick` 与 `bash install.sh --target all --check quick`

## 1.2.3
- 收口 `/project-manager` Phase 3 强门禁矩阵，新增 `phase3-grade-matrix.sh` 作为唯一可执行规则源
- 修复 `project-manager` `completion_check.sh` 的 bash 3.2 兼容性问题，避免 `mapfile` 在 macOS 默认 bash 下失效
- 新增 `tests/test-project-manager-phase3-contract.sh`，机械校验技能文档、模板、脚本、运行验收文档的一致性
- 修复 `codex-doc-review` 报告 canonical 路由与 misplaced report 修复链路，补齐 `repair_misplaced_reports.py`
- 修复 `repair_misplaced_reports.py` 未遵守 `ORG_STATE_ROOT` 的归档路径问题
- 修复 `codex-doc-review` 对模板格式 `审查阶段 (stage)` 的 scope 解析兼容性
- 新增 `tests/test-codex-doc-review-routing.sh`、`tests/test-codex-doc-review-repair.sh`、`tests/test-install-runtime-audit.sh`
- 更新团队运行验收 SOP 与发布清单，明确额外系统 skills 允许存在但不得遮蔽仓库托管技能

## 1.2.2
- 将 `codex-doc-review` 与 `codex-doc-reviewer` 收口为 Claude 专属能力，不再安装到 Codex
- 修复 `~/.codex/AGENTS.md` 标题渲染错误，Codex 运行入口不再显示 `# CLAUDE.md`
- 清理共享入口文案和高频 reference 中的 Claude-only 噪音，避免 Codex 运行面误导团队
- 新增 `tests/test-platform-runtime-noise.sh`，对运行时平台噪音做回归门禁
- 新增平台噪音巡检报告与 hotfix 修复记录，补齐团队追溯证据

## 1.2.1
- Codex 运行时 skill 文档改为真实能力口径：移除误导性的 frontmatter `hooks:`，对带 `completion_check.sh` 的 skill 改为显式执行提示
- 新增 `tests/test-codex-skill-adapter.sh`，防止 Codex dead hooks 配置回归
- 新增运行时真实性验证文档 `docs/runtime-validation.md`
- 新增团队运行验收 SOP `docs/runtime-acceptance-sop.md`
- 新增本机真实探针脚本：
  - `tools/dev/probe-claude-capabilities.sh`
  - `tools/dev/probe-codex-capabilities.sh`
  - `tools/dev/probe-runtime-capabilities.sh`
- 更新 Claude / Codex 能力矩阵，明确 Codex hooks 与 skill-local completion checks 的真实边界
- 更新发布检查清单与回滚 SOP，正式纳入运行时真实探针
- Claude 探针补充唯一 token、防 mock/probe 误判、`--no-session-persistence` 隔离和代理别名前置校验
- 新增 Claude 代理兼容说明，明确 LiteLLM / OpenAI 兼容代理的 `claude-*` 模型别名要求

## 1.2.0
- 仓库重构为 `shared/` 单一真源 + `claude/` / `codex/` 薄适配层
- 删除手工维护的双份 `skills/reference/rules/agents` 源树，避免双改漂移
- 安装器改为从共享源码渲染 Claude / Codex 运行目录
- Codex 运行期不再依赖 `~/.claude` 路径，补齐 `~/.codex/hooks/lib/common.sh`
- 新增单一真源结构测试与 Claude/Codex 能力矩阵文档

## 1.1.0
- 安装状态与备份统一外置到 `~/.org-skills-state/`
- `.claude` / `.codex` 运行目录不再保留 `.org-*` 与 `.org-backups/` 元数据
- 新增 `tools/migration/retire-dot-claude.sh`，支持旧 `.claude` git 归档退役
- 新增 `claude/CLAUDE.md` 与全局 `review-iteration-protocol`，修复入口与共享协议漂移
- 新增运行期完整性测试，补齐结构/引用门禁
- 修复重复覆盖安装后的恢复基线问题，卸载可回到用户原始文件

## 1.0.1
- 安装阶段新增“旧版本遗留受管文件”自动清理，减少历史噪音
- 引入 `.org-pruned-manifest`，记录并支持卸载时恢复被清理条目
- 系统测试新增“去噪清理 + 卸载恢复”用例
- 新增发布检查清单与回滚 SOP 文档

## 1.0.0
- 初始化统一仓库结构（claude/codex 分层）
- 引入 install/uninstall 事务安装机制
- 引入 contracts 校验、安装测试与 GitHub Actions
