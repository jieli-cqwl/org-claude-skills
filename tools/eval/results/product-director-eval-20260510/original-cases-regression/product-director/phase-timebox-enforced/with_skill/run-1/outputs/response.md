结论：**不能冻结给 product-manager。**  
当前单个 Phase 估算至少 3 周，已触发 `product-director` 的 D-S6 阻断条件：任一 Phase `iteration_timebox_days > 14`，不得进入 D-G1 总监确认门，更不得 handoff。

处理方式只能三选一或组合：

1. **缩小当前 Phase 范围**：只保留 14 天内可交付的核心价值闭环。
2. **拆出后续 Phase**：把增强、高级、低频或依赖不确定项的价值拆到 Phase 2+。
3. **后置非核心价值**：写入本期不做范围或后续 Phase，不把压力留给 PM。

D-S6 必须重新形成合规 `delivery_plan`：

- 每个 Phase 有独立业务价值，不按实现步骤拆。
- 每个 Phase 有清晰入口条件、出口条件。
- 每个 Phase 写入 `iteration_timebox_days`，且必须是 `<= 14`。
- 只给预期 UNIT 数量范围，例如 `3-7`，不能在 Director 阶段输出 UNIT 清单、AC、`scope_item_id`。

门禁状态：

- 当前状态：**D-S6 阻断**。
- 阻断原因：单 Phase 预计 3 周，超过两周 timebox。
- 不允许动作：冻结 Director 基线、写最终 `brief.json / phase-prd.json`、交给 `/product-manager`。
- 下一步：停在 D-S6，重切 Phase 或收缩范围；待所有 Phase `iteration_timebox_days <= 14` 后，才允许进入 D-G1 总监确认门。收到明确 `产品总监确认` 后，才写入锁定字段与 digest，并运行台账和 schema gate。