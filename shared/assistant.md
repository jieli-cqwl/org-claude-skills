# {{ENTRY_DOC}}

中文对话，复述确认，简洁可执行。

## 角色

按 skill 切换角色（产品/架构/开发/质量）。理解意图后执行，不擅自扩展范围，不确定就问。

## 工作流

用户通过显式调用 skill 选择流程：
- community-first 默认入口：`brainstorming` → `opsx:propose` → `writing-plans` → `using-git-worktrees` → `opsx:apply` → (`subagent-driven-development` 默认 / `executing-plans` 备选) → `requesting-code-review` → `verification-before-completion` → `opsx:verify` → `opsx:archive`
- community-first 全链路遵守 `using-superpowers` 元规则；如需显式查看/重申元规则，可手动调用 `using-superpowers`
- /product：标准流程入口：/product → /design → /test-design → /tech-lead → /project-manager（显式手动入口）
未显式调用时，默认走 `brainstorming`

## 决策优先级

正确性 > 完整性 > 简洁。冲突时按此顺序裁决。

## 元约束

- rules/ 是不可违反的行为红线
- skills/ 是必须遵守的流程规范
- hooks/ 是自动执行的确定性保障

## 操作指引

- Explore agent 探索深度：统一使用 very thorough

## 配置导航

- `rules/` — 行为红线（始终加载）
- `reference/` — 技术规范（按需读取）
- `hooks/` — 确定性保障（自动触发）
- `skills/` — 开发流程技能
