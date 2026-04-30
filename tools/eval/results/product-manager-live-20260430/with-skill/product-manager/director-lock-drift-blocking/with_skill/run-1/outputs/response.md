我理解的操作对象是：`product-manager` 阶段想直接扩大 Phase 1 范围，并改动 Director 已锁定的业务规则。预期结果是判断 PM 是否能顺手改。

**阻断结论：不能。**

触发门禁：

- `M-HG-9`：不得改写 `director_confirmation.locked_fields` 与 `locked_field_digest` 覆盖的 Director 锁定字段。
- 触及 Phase 边界、范围、业务规则或约束事实变化时，必须回退 `/product-director`，由 Director 重新裁决并重签。
- PM 当前只能记录阻断与回退原因，不能生成 PRD / UNIT / AC 草案，也不能替用户补签确认门。

固定 handoff 问题：

请提供 `docs/{feature}/brief.json` 和 `docs/{feature}/phase-{N}/phase-prd.json` 路径或内容，以便校验 `director_confirmation.status`、`locked_fields` 与当前 Phase 边界。

下一步：回退 `/product-director` 更新并确认 Phase 1 范围、业务规则和锁定字段；Director 重新确认后，PM 才能从 M-S0 准入校验继续。通过准入后，PM 输出仍必须满足 UNIT 闭环锚点、Integration Context 边界、AC 示例输入/预期结果/边界情况/失败模式与 Verification Plan 映射要求。