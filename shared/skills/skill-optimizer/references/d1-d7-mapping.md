# Quality Dimension Mapping

Trigger: Use this when converting `skill-optimizer` audit findings into local Skill quality dimensions.
Read: `skill-audit.json`, finding source markers, SO-* anchors, and `{{RUNTIME_HOME}}/reference/Skill质量标准.md`.
Expect: Every optimizer audit link maps to D1-D8 without creating a competing rating model.
Consume: `audit_skill.py`, `generate_optimization_plan.py`, coverage report, and human review consume this mapping.
Evidence: Finding includes dimension, SO anchor, evidence refs, and verification command.
Sync: Update this mapping whenever `{{RUNTIME_HOME}}/reference/Skill质量标准.md` changes.

| Optimizer audit link | Target dimension |
| --- | --- |
| Trigger contract | D1 触发与路由合同 |
| Progressive loading | D2 渐进加载与上下文预算 |
| Reference contract | D2 渐进加载与上下文预算, D3 输入输出与 artifact 合同, D7 演化与兼容性 |
| Runtime artifact | D3 输入输出与 artifact 合同, D6 验证与证据 |
| Permission and scripts | D4 执行安全与权限边界, D6 验证与证据 |
| Hook adapter | D4 执行安全与权限边界, D5 流程自治与异常控制, D7 演化与兼容性 |
| SubAgent/fork | D5 流程自治与异常控制, D6 验证与证据 |
| Eval and benchmark | D6 验证与证据, D8 人类可读与组织复用 |
| Migration and retirement | D7 演化与兼容性 |
| Rendered report | D8 人类可读与组织复用, D3 输入输出与 artifact 合同 |

## Legacy Mapping

旧 D1-D7 只用于迁移对照，不作为新的审计输出维度。当所有 first-party Skill 审计报告不再引用旧维度名时，本表可删除。

| Legacy dimension | Target dimension |
| --- | --- |
| D1 结构合规 | D1 触发与路由合同, D2 渐进加载与上下文预算, D8 人类可读与组织复用 |
| D2 闭环自治 | D5 流程自治与异常控制 |
| D3 I/O 契约 | D3 输入输出与 artifact 合同 |
| D4 角色与对抗 | D5 流程自治与异常控制, D6 验证与证据, D8 人类可读与组织复用 |
| D5 验证即证据 | D6 验证与证据 |
| D6 Token 效率 | D2 渐进加载与上下文预算, D3 输入输出与 artifact 合同, D7 演化与兼容性 |
| D7 跨模型适配 | D7 演化与兼容性 |
