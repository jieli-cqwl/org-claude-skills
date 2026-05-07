# Standard-Chain Local Skill Eval

- total expectations: 16
- failed expectations: 6
- infra failures: 0
- pass rate: 0.62

## Runs
- product-manager / handoff-validation-first: 4/4 passed
- product-manager / unit-context-and-ac-closure: 2/6 passed
  - failed: 先给 PM 推荐 UNIT 草案、AC 草案、推荐理由和会改变结论的未闭合业务假设
  - failed: AC 包含示例输入、预期结果、边界情况和失败模式
  - failed: Verification Plan 只写验证类型、业务操作或场景、预期可观察结果和证据目标
  - failed: 用户补充业务事实，不承担 PM 方法判断
- product-manager / high-risk-review-on-demand: 4/6 passed
  - failed: 命中批量重放、外部依赖、失败重试或幂等风险时才读取 high-risk-launch-review
  - failed: 没有高风险信号时不额外加载高风险补充审查

## Optimization Findings
- M-S0 是否已经执行的表述不够干净。 -> 把“之后我才能运行 M-S0 preflight”改为“当前 M-S0 preflight 结果为未通过；收到工件后重新执行 M-S0 深度校验”。
- 关键草案内容被放在文件中，输出正文缺少可直接评审的 UNIT/AC/Verification Plan 明细。 -> 在答复中直接列出推荐 UNIT 草案、AC 草案、Integration Context、Verification Plan、依赖、排除项和未闭合假设。
- 共创边界不清。 -> 明确写出“请用户只补充业务事实/约束，PM 负责方法判断和收口”。
- 未点名 `high-risk-launch-review`。 -> 补一句：M-S8 命中批量重放、外部依赖、失败重试、幂等/重复提交信号时，PM 读取 `high-risk-launch-review` 做补充审查。
- 缺少无高风险信号时的加载边界。 -> 补一句：若 Phase 未命中上述高风险信号，则不额外加载高风险补充审查，仅走普通 review-orchestration。
