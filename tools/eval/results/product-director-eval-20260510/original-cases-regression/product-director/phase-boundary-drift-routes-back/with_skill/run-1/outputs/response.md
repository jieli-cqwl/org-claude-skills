已按 `shared/skills/product-director/SKILL.md` 判断。本 eval 不写文件、不联网、不启动服务、不调用审查 agent。

**结论**
回 `product-director`，不能让 `product-manager` 直接改。

**原因**
“两个 Phase 可能应该合并”触及 Director 的 **Phase 边界 / Phase 规划 / delivery_plan Phase 结构**。  
“范围描述也要改”触及 Director 的 **范围、本期不做、约束、决策理由**等锁定基线。

`product-manager` 只能做不改变冻结口径的文字润色、术语、语病、格式调整；不能直接改写 `director_confirmation.locked_fields`、`locked_field_digest`，也不能重切 Phase 或改范围语义。

**阻断条件**
当前停在 PM 细化链路，禁止继续修改：
- Phase 合并
- 范围语义变更
- `locked_fields`
- `locked_field_digest`
- `delivery_plan` / Phase 骨架

**下一步**
1. PM 记录变更请求：拟合并哪两个 Phase、为什么合并、范围描述变更前后、影响哪些入口/出口条件、风险、成功标准。
2. 回 `/product-director` 重开 Director 共创链路。
3. 至少回到 `D-S5 范围收口` 和 `D-S6 Phase 规划`；如果风险或约束被影响，还要经过 `D-S5.5 风险与未知项`。
4. Director 重新闭合事实后进入 `D-G1 总监确认门`。
5. 只有收到明确 `产品总监确认`，并重新生成 `locked_fields` / `locked_field_digest` 且 gate 通过后，才能再 handoff 给 `product-manager`。