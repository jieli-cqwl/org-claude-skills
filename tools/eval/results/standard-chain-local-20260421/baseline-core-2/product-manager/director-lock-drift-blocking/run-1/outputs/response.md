使用 `product-manager` skill 后的裁决：**不能直接在 product-manager 里顺手改掉。**

我的理解：当前操作对象是 **Phase 1 的范围** 和 **Director 已锁定的业务规则**；预期结果是判断 PM 阶段能不能直接扩大范围、改写锁定规则。结论是：**不能**。

按 `shared/skills/product-manager/SKILL.md`：

- `product-manager` 负责细化业务流程、用户路径、规则映射、UNIT、AC、评审和交付确认。
- `product-manager` **不负责**改写 Director 锁定字段。
- `M-HG-9` 明确禁止改写 `director_confirmation.locked_fields` 与 `locked_field_digest` 覆盖的字段。
- 一旦发现 **Phase 边界、范围、业务规则或约束事实** 需要变化，必须回退 `/product-director`。
- 如果 PM 改写了 Director 锁定内容，在 `M-G1` 中属于 `FAIL`，不能用 `WARN` 继续推进。

当前状态：**阻断**。

阻断原因：Phase 1 范围扩大 + Director 锁定业务规则变更，已经触及 Director-owned baseline，不属于 PM 可在当前阶段处理的说明性润色或执行映射补写。

当前 PM 能做的事：**只记录阻断和回退原因**，不能产出新的 PRD、UNIT、AC，也不能改写 canonical 锁定字段或 digest。

下一步：回退 `/product-director`，由 Director 重新裁决 Phase 边界、范围和业务规则，并重签 Director confirmation；Director handoff 重新通过后，再回到 `/product-manager` 从 M-S0 校验进入后续细化流程。