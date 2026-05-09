使用 `product-director` skill 判断：这是 **D-S6 Phase 规划阻断**，不能进入 D-G1，也不能先冻结给 `/product-manager`。

结论很简单：**单个 Phase 预估至少 3 周，已超过 14 天 timebox，Director 不得冻结。**

必须先在 D-S6 做范围重切，三选一或组合：

1. 缩小当前 Phase，只保留能在 `<= 14` 天交付的核心价值闭环。
2. 按独立业务价值拆出后续 Phase，不能按实现步骤硬拆。
3. 将非核心价值、增强能力或高风险不确定项后置。

进入总监确认门前，`delivery_plan` 必须满足：

```json
{
  "delivery_plan": [
    {
      "phase": "phase-1",
      "value_boundary": "核心价值闭环",
      "iteration_timebox_days": 14,
      "entry_conditions": ["已闭合的入口条件"],
      "exit_conditions": ["可验证的出口条件"],
      "expected_unit_count_range": "3-7"
    }
  ]
}
```

门禁状态：

- `iteration_timebox_days > 14`：阻断
- Phase 入口/出口条件不清：阻断
- 当前 Phase 仍混入非核心价值导致 3 周交付：阻断
- 未完成 D-S6 业务草案确认：阻断
- 未满足上述条件前：不得请求 `产品总监确认`，不得 handoff 给 `/product-manager`

下一步：回到 **D-S6 Phase 规划**，把这个 3 周范围切成 `phase-1 <= 14 天` 的核心价值交付，以及后续 Phase；修正 `delivery_plan` 后，才允许进入 D-G1 总监确认门。