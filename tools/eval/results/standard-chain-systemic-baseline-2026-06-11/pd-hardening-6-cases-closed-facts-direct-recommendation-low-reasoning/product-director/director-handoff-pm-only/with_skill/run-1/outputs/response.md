结论：`product-director` 的 canonical 输出通过 gates 后，直接 handoff 目标只能是 `product-manager`。

门禁与边界：
- `brief.json` 和 `phase-prd.json` 已通过 gates，表示 Director canonical 输出可进入下游。
- 下游第一接收方是 `product-manager`，由其继续细化 required artifacts。
- `tech-lead`、`design`、`test-design` 不能直接消费 `product-director` 输出启动实现规划。
- `design` 和 `test-design` 只能在 `product-manager` 细化出 required artifacts 后作为后续消费者参与。
- `tech-lead` 只能在 `design` 与 `test-design` 产出各自 required artifacts 后继续消费。

下一步：交给 `product-manager` 执行细化流程；当前不输出 UNIT、AC、design、plan 或 tasks。