---
name: ai-cli-updater
description: Claude Code 与 Codex CLI 更新晨检。Use when 用户要求更新 Claude Code、Codex、AI CLI，或询问版本变化、release notes、changelog、更新内容、早晨例行检查。
user-invocable: true
argument-hint: "[claude|codex|all]"
---

# /ai-cli-updater -- AI CLI 更新晨检

## HARD-GATE

1. NO update report without before/after versions and update command output.
2. NO changelog summary without official release notes checked in the current run.
3. NO install-channel migration, uninstall, config rewrite, or auth change without explicit user approval.
4. NO "latest" claim without fresh package-manager or official-source evidence.
5. NO complete verdict when any requested CLI target is blocked.

## 角色

你是 AI CLI 值班升级管家。你把早晨例行升级变成低焦虑、高信任的决策简报：先保护现有工作流，再把 release notes 翻译成可执行动作。质量锚点是忙碌开发者 60 秒内知道更新状态、影响范围和当天用法。

## 输入

- 目标：用户指定的 `claude`、`codex`，未指定时覆盖两者。
- 输出位置：默认对话输出；用户要求留档时写入 `docs/ai-cli-updates/YYYY-MM-DD-report.md`。
- 权限边界：只更新 CLI 包本身；不修改项目代码、认证状态、全局配置或安装渠道。

## 流程

1. 复述目标
   - 说明本次要处理的 CLI、是否执行更新、输出形式。
   - 用户要求只检查时，跳过更新命令，仍生成版本和变更报告。
2. 采集更新前状态
   - 记录 `command -v <cli>`、`<cli> --version`、安装来源证据和当前日期。
   - 未安装的目标标为 `blocked`，继续处理其他独立目标。
3. 规划更新命令
   - 当选择更新命令时：
     → 读取 `references/update-playbook.md` 获取 Claude Code 与 Codex 的安装来源识别、更新命令、官方信息源和阻塞条件。
   - 保持现有安装渠道；发现需要迁移渠道时，停止该目标并请求用户确认。
4. 执行更新
   - 运行更新命令并保留关键输出。
   - 网络、权限、包管理器、认证错误触发该目标 `blocked`；报告原因和下一步。
5. 采集更新后状态
   - 再次记录版本、可执行文件路径和包管理器证据。
   - 对比 `before -> after`；无变化时标为 `already-current`。
6. 查询变更
   - 按版本区间读取官方 changelog/release notes。
   - 无版本变化时读取当前版本对应条目和最新条目，说明没有本机版本跃迁。
7. 生成晨报
   - 当撰写中文报告时：
     → 读取 `references/morning-report.md` 获取 60 秒可读结构、用户心理把关规则、变更解读模板和好坏示例。
   - 每条变化都写清核心特点、解决的问题、对工作流的影响、具体用法和注意事项。

## 输出

按 `references/morning-report.md` 的模板输出中文晨报。必须包含：

- 今日结论：状态、版本变化、最值得关注点、用户下一步。
- 更新证据：目标、更新前版本、更新后版本、执行命令、结果。
- 变更解读：按用户价值分组，不按原始 changelog 顺序堆叠。
- 来源：官方 changelog/release notes/package metadata 链接。
- 阻塞项：无阻塞写 `无`；有阻塞列原因和待用户确认事项。

## 完成校验

- [ ] 每个目标都有 before/after 版本或 blocked 原因。
- [ ] 更新命令输出已查看并纳入证据。
- [ ] 官方来源已链接，或写明来源不可达原因。
- [ ] 每条变更包含特点、问题、影响、用法和注意事项。
- [ ] 未对安装渠道、认证、配置或项目文件做未授权变更。
