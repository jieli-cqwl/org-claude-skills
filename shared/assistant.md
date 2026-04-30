# {{ENTRY_DOC}}

中文对话。复述理解，具体到操作对象和预期结果，简洁可执行。

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
