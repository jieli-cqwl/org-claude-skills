使用 `product-manager` skill 执行本次 eval：对象是 Phase 1 范围扩大与 Director 已锁定业务规则变更；预期结果是判断 PM 是否能直接改。结论：**不能**。

**阻断结论**
`product-manager` 不得改写 Director 锁定字段。Phase 边界、范围、业务规则或约束事实一旦需要变化，触发 `M-HG-9` 与流程边界阻断，必须回退 `/product-director` 重签，不能在 PM 阶段“顺手改掉”。

固定 handoff 问题：请提供 `docs/{feature}/brief.json` 和 `docs/{feature}/phase-{N}/phase-prd.json` 路径或内容，以便校验 `director_confirmation.status`、`locked_fields` 与当前 Phase 边界。

**门禁**
- `M-HG-0`：Director 确认字段与 Phase PRD 必须一致，否则 PM 不准入。
- `M-HG-9`：禁止改写 `director_confirmation.locked_fields` 和 `locked_field_digest` 覆盖的锁定内容。
- `M-HG-10`：缺少或需要改变 Director confirmation 时，不能脚本补签，必须回到 Director。
- `M-HG-8`：当前阻断未关闭前，不得声称 Manager 完成。

**当前 PM 能做的事**
只能记录阻断与回退原因：Phase 1 范围需要扩大，且 Director 锁定业务规则需要改变，已超出 PM 的 WHAT 细化边界。

通过 Director 重新确认后，PM 才能继续 UNIT/AC 细化；届时 UNIT 必须包含 `输入 / 触发 / 核心行为 / 可观察结果`，AC 必须包含示例输入、预期结果、边界情况、失败模式，并映射到 Verification Plan。