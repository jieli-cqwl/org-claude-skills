# Standard-Chain Local Skill Eval

- total expectations: 16
- failed expectations: 9
- infra failures: 0
- pass rate: 0.44

## Runs
- product-manager / handoff-validation-first: 4/4 passed
- product-manager / unit-context-and-ac-closure: 0/6 passed
  - failed: 先给 PM 推荐 UNIT 草案、AC 草案、推荐理由和会改变结论的未闭合业务假设
  - failed: UNIT 有输入、触发、核心行为和可观察结果
  - failed: Integration Context 只写业务模块、不可破坏行为、跨 UNIT 依赖和业务约束
  - failed: AC 包含示例输入、预期结果、边界情况和失败模式
  - failed: Verification Plan 只写验证类型、业务操作或场景、预期可观察结果和证据目标
  - failed: 用户补充业务事实，不承担 PM 方法判断
- product-manager / high-risk-review-on-demand: 3/6 passed
  - failed: M-S8 使用 3 视角×max10 轮评审编排
  - failed: 命中批量重放、外部依赖、失败重试或幂等风险时才读取 high-risk-launch-review
  - failed: 没有高风险信号时不额外加载高风险补充审查

## Optimization Findings
- PA-5 覆盖不完整。 -> 阻断说明中应显式写出不得改写 `locked_fields` 和 `locked_field_digest`，而不仅是「Director 锁定字段」。
- 把工具依赖缺失升级为完全阻断，导致没有交付 PM 推荐草案。 -> 在 handoff 输入已确认的前提下，至少先给出只读推荐 UNIT/AC 草案、推荐理由和未闭合业务假设；将 preflight 失败作为写入或最终冻结前的阻断证据。
- 缺少可追踪、可验证的业务内容。 -> 补齐 UNIT 字段、业务级 Integration Context、示例驱动 AC、Verification Plan、依赖与排除项，并明确用户只需补充业务事实。
