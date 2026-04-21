已按当前工作区 `shared/skills/product-director/SKILL.md` 判断。

你的场景是：`product-manager` 在细化“会员积分项目”时，发现两个 Phase 要合并，且范围描述要改。结论是：**必须回 `product-director`，不能在 `product-manager` 继续直接改。**

原因很明确：

- **Phase 合并**触及 `product-director` 负责的 Phase 规划与 Phase 边界。
- **范围描述修改**触及范围/规则收口，可能改变 Director 冻结语义。
- 只要会改变 canonical `brief.json / phase-prd.json` 中的 `director_confirmation.locked_fields`、`locked_field_digest`，或改变业务口径，`product-manager` 就无权直接改写。
- `product-manager` 只能处理 UNIT、AC、细化与审查闭环；只有“不改变冻结语义、不改 locked fields/digest 的说明性润色”才可留在 `product-manager`。

**阻断条件：**当前请求已经触发“Phase 边界 + 范围字段”变更，属于 Director 锁定字段变更，因此阻断 `product-manager` 继续改。

**下一步：**退回 `/product-director`，重开 **D-S2 ~ D-G1**，重新共创确认根问题、目标、范围与 Phase 规划；通过 `产品总监确认` 后，再更新 canonical `brief.json / phase-prd.json` 的锁定字段与 digest，并验证通过后再 handoff 给 `/product-manager`。本次 eval 按要求未联网、未修改文件。