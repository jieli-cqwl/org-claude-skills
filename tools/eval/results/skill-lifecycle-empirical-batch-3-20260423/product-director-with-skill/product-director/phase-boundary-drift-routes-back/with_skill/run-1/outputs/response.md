复述理解：PM 在细化会员积分项目时，发现两个 Phase 要合并，且范围描述要改。这触及 **Phase 边界** 和 **范围口径**，属于 Director 锁定字段变更。

结论：必须回 `/product-director`，重开 **D-S2 ~ D-G1**。`/product-manager` 不能直接改写 Phase 规划、范围、规则、canonical `director_confirmation.locked_fields`、`locked_field_digest` 或业务口径。

二分规则：
- 仅说明性润色，且不改变冻结语义、locked fields、digest：可留在 `/product-manager`
- 改 Phase 边界、范围、规则、锁定字段、digest、业务口径：必须回 `/product-director`

门禁：
- D-S2~D-S6 必须共创确认，不能跳步
- 未重新通过 D-G1 `产品总监确认` 前，不能 handoff 给 `/product-manager`
- 未重新冻结 canonical 字段前，PM 修改被阻断

下一步：由 `/product-director` 重新确认根问题、目标、范围、风险与 Phase 拆分，走到 D-G1 后再交回 `/product-manager` 继续细化。