使用 `product-director` skill 判定。

**结论**  
必须回 `/product-director`，不能留在 `/product-manager` 继续改。

**原因**  
这次变更同时触及两个 Director 锁定边界：

- `Phase 可能应该合并`：改变 Phase 边界、`delivery_plan` Phase 级结构和 Phase 骨架。
- `范围描述也要改`：改变范围口径，属于 Director 基线字段。

`/product-manager` 只能细化 WHAT 层；不得直接改写 `director_confirmation.locked_fields`、`locked_field_digest`，也不得改 Phase 骨架或范围基线含义。

**门禁**  
当前 PM 链路暂停。只有“不改变冻结口径的术语、语病、格式润色”才可由 PM 继续；本例不是润色，是基线变更。

**下一步**  
回 `/product-director` 重开 Director 共创链路，至少回到：

- `D-S5`：重新收口范围、本期不做、约束与决策理由。
- `D-S6`：重新规划 Phase，确认合并后的价值边界、入口/出口条件、timebox。
- `D-G1`：重新等待明确 `产品总监确认`，再冻结 `locked_fields`、`locked_field_digest` 和 Phase 结构，通过门禁后再 handoff 给 `/product-manager`。