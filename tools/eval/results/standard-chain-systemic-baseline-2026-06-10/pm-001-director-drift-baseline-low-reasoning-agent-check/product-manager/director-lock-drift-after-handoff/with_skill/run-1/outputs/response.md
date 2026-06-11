使用 `product-manager` skill 判断：**不可以直接改 phase goal、出口和 UNIT 后继续 review。**

状态：`BLOCKED at Handoff/recovery drift gate`

原因：
- “租户自动扣费”被 Director baseline 明确放在非目标里。
- 现在用户要求把它新增为成功标准，会改变 Director-owned 的 Phase 目标、出口、范围/非目标边界。
- PM 只能细化 WHAT，不能覆盖 Director locked fields；一旦要改 locked fields，必须停止并回流 Director 或用户裁决链路重定 baseline。
- 已写完的 UNIT 草稿不能在这个漂移上直接 patch 后送审；否则 review digest 审的是被 PM 私自改过的范围，门禁无效。

影响产物：
- `phase-prd.json.phase_goal`
- `phase-prd.json.exit_criteria`
- `phase-prd.json.feature_inventory`
- `units/UNIT-*.json`
- 后续 AC / Verification Plan / Review digest / Agent review 全部受影响

推荐默认值：
- 当前 Phase 继续保持“租户自动扣费”为 `OUT_OF_SCOPE`。
- 若业务必须纳入，则回 Director 重新确认 Phase baseline，再由 PM 从 Handoff gate 恢复，重跑范围映射、Pre-UNIT gate、UNIT split、AC 和 Verification Plan。

下一步问题：
**“租户自动扣费”是要推翻当前 Director 非目标并纳入本 Phase，还是登记为后续 Phase/非目标继续排除？**

恢复条件：
- 若纳入本 Phase：Director 重新确认 baseline，更新目标、出口、范围、非目标后，PM 才能继续。
- 若不纳入本 Phase：PM 可把它作为明确 `OUT_OF_SCOPE`/后续机会项记录，然后继续当前 review。