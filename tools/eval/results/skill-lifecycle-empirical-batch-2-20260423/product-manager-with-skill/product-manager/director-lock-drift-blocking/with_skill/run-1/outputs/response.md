你的问题是：在 `product-manager` 阶段，能不能直接把 `Phase 1` 范围扩大，并顺手改掉 Director 已锁定的业务规则。结论：**不能**。

**必需字段**
- `verdict`: `blocked`
- `can_edit_in_product_manager`: `false`
- `blocked_stage`: `M-S0 / 边界校验`
- `blocked_reason`: 触及 `Phase` 边界、范围、业务规则，且属于 Director 锁定内容，PM 无权改写
- `pm_action_now`: `只记录阻断和回退原因，不改 canonical 内容`
- `next_owner`: `/product-director`

**门禁**
- `M-HG-9`：禁止改写 `director_confirmation.locked_fields` 与 `locked_field_digest` 覆盖的 Director 锁定字段。
- 角色与边界：一旦发现 `Phase` 边界、范围、业务规则或约束事实要变，**必须回退 `/product-director`**。
- `M-HG-10`：不能在 PM 阶段补签、代签或绕过 Director 确认门。
- 本次 eval 还没有 `brief.json` 和 `phase-{N}/phase-prd.json` 输入工件，所以也**不满足 PM 准入校验**，不能继续细化。

**下一步**
- 回退到 `/product-director`，重新裁决并重签 `Phase 1` 范围和相关业务规则。
- 当前 `product-manager` 只能记录：
  - 哪些变更触及了 Director 锁定字段
  - 为什么这次变更超出 PM 边界
  - 需要 Director 重新确认的原因

这次 eval 的边界结论就是：**PM 不能直接改，必须回退 Director；当前只能记录阻断与回退原因。**