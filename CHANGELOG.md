# Changelog

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
