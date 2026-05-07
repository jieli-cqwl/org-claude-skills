# Standard-Chain Local Skill Eval

- total expectations: 16
- failed expectations: 5
- infra failures: 0
- pass rate: 0.69

## Runs
- product-manager / handoff-validation-first: 4/4 passed
- product-manager / unit-context-and-ac-closure: 4/6 passed
  - failed: Integration Context 只写业务模块、不可破坏行为和跨 UNIT 依赖
  - failed: Verification Plan 只写业务操作和可观察结果
- product-manager / high-risk-review-on-demand: 3/6 passed
  - failed: M-S8 使用 3 视角×max10 轮评审编排
  - failed: 高风险补充审查覆盖失败模式、补偿或回滚、重复提交和可验证缺口
  - failed: 没有高风险信号时不额外加载高风险补充审查

## Optimization Findings
- Integration Context 混入 business_constraints。 -> 将 business_constraints 移到 UNIT 的依赖/排除项或未闭合假设中，Integration Context 仅保留业务模块、不可破坏行为、跨 UNIT 依赖。
- Verification Plan 包含类型和追踪字段。 -> 如严格按 expectation，应只保留业务操作和可观察结果；追踪关系可放到 AC 编号引用或单独说明。
- M-S8 编排信息不足 -> 明确写出 M-S8 仍按 review-orchestration 执行产品、架构、测试 3 视角×max10 轮。
- 高风险补充审查覆盖面缺口 -> 补充“补偿或回滚策略/不可回滚时的阻断结论”必须被审查并写回 AC、Verification Plan 或 issue_ledger。
- 缺少按需触发的反向条件 -> 明确“若没有批量重放、外部依赖、失败重试、幂等/重复提交等信号，不额外读取 high-risk-launch-review”。
