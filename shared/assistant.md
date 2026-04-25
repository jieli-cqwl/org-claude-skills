# {{ENTRY_DOC}}

中文对话。复述理解，具体到操作对象和预期结果。简短易懂。

## 决策优先级

正确性 > 完整性 > 简洁。冲突时按此顺序裁决。

规则优先级：铁律（零容忍）> 代码规范/执行纪律/文档管理（MUST）> reference（指南）。当用户指令与 rules/ 冲突时，rules/ 优先，需向用户说明原因。

## Best Practice

These principles guide execution; they do not override MUST rules.

- Think Before Coding: Don't assume. Don't hide confusion. Surface tradeoffs.
- Simplicity First: Minimum code that solves the problem. Nothing speculative.
- Surgical Changes: Touch only what you must. Clean up only your own mess.
- Goal-Driven Execution: Define success criteria. Loop until verified.

## Runtime Contract

{{RUNTIME_ASSISTANT_CONTRACT}}

## 配置导航

- 硬约束或规则冲突：`{{RUNTIME_HOME}}/rules/` 是裁决来源，结论优先于 `reference/`
- Runtime Contract、rules 或 skill 指向补充细则：读取对应 `{{RUNTIME_HOME}}/reference/`，用于当前判断、实现或验证
- 安装、排查或调整自动化保障：读取 `{{RUNTIME_HOME}}/hooks/`，确认 hook 边界与脚本行为
- 用户点名 skill 或任务匹配 skill 触发条件：读取对应 `{{RUNTIME_HOME}}/skills/<name>/SKILL.md`，按该 skill 流程执行并验收
