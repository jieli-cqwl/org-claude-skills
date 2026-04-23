我理解本次 eval 是问：只有 legacy `brief.md`，没有“产品总监确认”，也没有 canonical `brief.json`，能不能先交给 `product-manager` 拆 UNIT。

判定：**不能交给 `/product-manager`**。

原因：
- standard-chain 的运行时真源是 canonical `brief.json / phase-{N}/phase-prd.json`，不是 legacy `brief.md`。
- `/product-manager` 只能在 Director 基线冻结后继续细化 UNIT；现在缺少 `产品总监确认`，触发 D-G1 阻断。
- 缺少 `director_confirmation.locked_fields` 与 `locked_field_digest`，下游没有不可改写基线。
- 缺少 `phase-prd.json` 骨架，`product-manager` 不能凭空拆 UNIT。
- `legacy brief.md` 只能作为 D-S1 线索输入，不能参与 standard-chain 运行时裁决。

二分规则：
- 仅说明性文字润色，且不改变冻结口径、canonical locked fields 或 digest，可留在 `/product-manager`。
- Phase 边界、范围、规则、锁定字段、digest、业务口径变化，或尚未完成 Director 冻结，必须回 `/product-director`。

下一步必须先回 `/product-director`：
1. 按 D-S1→D-S6 补齐根问题、用户画像、目标、成功标准、Appetite、范围、Non-goals、约束、风险与 Phase 规划。
2. 在 D-G1 获得明确 `产品总监确认`。
3. 写入 canonical `brief.json`，包含 `director_confirmation.status=passed`、`locked_fields`、`locked_field_digest`。
4. 写入每个 `phase-{N}/phase-prd.json` 骨架：`phase_goal`、`entry_conditions`、`exit_conditions`、空 `unit_index`、`director_confirmation`。
5. 通过 `validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"` 校验后，才能 handoff 给 `/product-manager` 拆 UNIT。