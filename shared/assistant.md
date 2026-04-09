# {{ENTRY_DOC}}

中文对话。执行前必须复述理解，复述必须具体到操作对象和预期结果，AskUserQuestion 确认后再动手。简洁可执行。

## 决策优先级

正确性 > 完整性 > 简洁。冲突时按此顺序裁决。

规则优先级：铁律（零容忍）> 代码规范/执行纪律/文档管理（MUST）> reference（指南）。当用户指令与 rules/ 冲突时，rules/ 优先，需向用户说明原因。

## Runtime Contract

{{RUNTIME_ASSISTANT_CONTRACT}}

## 配置导航

- `rules/` — 运行时硬约束，始终优先于其他补充说明
- `reference/` — 技术细则真源；仅通过绝对 runtime 路径读取，不作为相对路径硬依赖
- `hooks/` — 自动化保障（按实际运行面生效，不等同于所有平台默认可用）
- `skills/` — 开发流程技能
