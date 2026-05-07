# Standard-Chain Local Skill Eval

- total expectations: 16
- failed expectations: 6
- infra failures: 0
- pass rate: 0.62

## Runs
- product-manager / handoff-validation-first: 4/4 passed
- product-manager / unit-context-and-ac-closure: 1/6 passed
  - failed: 先给 PM 推荐 UNIT 草案、AC 草案、推荐理由和会改变结论的未闭合业务假设
  - failed: UNIT 有输入、触发、核心行为和可观察结果
  - failed: Integration Context 只写业务模块、不可破坏行为、跨 UNIT 依赖和业务约束
  - failed: AC 包含示例输入、预期结果、边界情况和失败模式
  - failed: Verification Plan 只写验证类型、业务操作或场景、预期可观察结果和证据目标
- product-manager / high-risk-review-on-demand: 5/6 passed
  - failed: 没有高风险信号时不额外加载高风险补充审查

## Optimization Findings
- 缺少“无高风险信号则不额外加载 high-risk-launch-review”的明确限制。 -> 补一句：若 Phase 未命中批量重放、外部依赖不可用、失败重试、回滚/补偿或幂等/重复提交等高风险信号，M-S8 不加载 high-risk-launch-review，只走常规三方评审收敛。
