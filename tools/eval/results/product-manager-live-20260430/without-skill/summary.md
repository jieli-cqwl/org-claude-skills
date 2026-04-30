# Standard-Chain Local Skill Eval

- total expectations: 26
- failed expectations: 1
- infra failures: 0
- pass rate: 0.96

## Runs
- product-manager / handoff-validation-first: 4/4 passed
- product-manager / director-lock-drift-blocking: 4/4 passed
- product-manager / canonical-review-required: 4/4 passed
- product-manager / unit-context-and-ac-closure: 5/6 passed
  - failed: Integration Context 只写业务模块、不可破坏行为和跨 UNIT 依赖
- product-manager / review-delivery-guided-confirmation: 8/8 passed

## Optimization Findings
- 对 locked_field_digest 的保护没有明确表达。 -> 补一句“不会改写 Director locked_fields 或 locked_field_digest，只做读取校验”。
- 未覆盖 PA-1 的 Director baseline 表述。 -> 补充说明拆 UNIT 的准入必须消费已确认的 Director baseline，而不是仅从 legacy markdown 迁移。
- 未覆盖 PA-4 的三方评审 FAIL/WARN 处理。 -> 补充说明三方评审中的 FAIL 必须关闭，WARN 必须承接到后续记录或计划。
- 未覆盖 PA-6 的 delivery_confirmation。 -> 补充说明交付前必须写入 `delivery_confirmation`。
- Integration Context 缺少明确的不可破坏行为。 -> 补充如“不得影响既有审批触发入口、既有权限边界、已生效配置的匹配稳定性”等业务不变量，并移除 design/test-design 交付流向。
