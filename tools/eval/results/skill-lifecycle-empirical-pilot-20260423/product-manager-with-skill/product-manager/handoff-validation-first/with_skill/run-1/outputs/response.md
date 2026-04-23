已按当前工作区 `shared/skills/product-manager/SKILL.md` 执行到 **M-S0 内容完整性检查与准入验证**。

我的理解是：你要继续细化「商家入驻自动审核」这个 Director 已确认的 Phase 1，目标是把业务流程、UNIT 和 AC 收到可执行粒度；但按 skill 的 HARD-GATE，Manager 不能接受口头“已通过 Director 确认”，必须先校验 canonical `brief.json` 与 `phase-1/phase-prd.json`。

**M-S0 结论：阻断，未准入**

阻断原因：

- 当前 eval prompt 未提供 `brief.json` 路径或内容。
- 当前 eval prompt 未提供 `phase-1/phase-prd.json` 路径或内容。
- 因此无法校验：
  - `director_confirmation.status`
  - `director_confirmation.locked_fields`
  - `locked_field_digest`
  - Phase 1 边界
  - Director-owned 字段是否与当前 handoff 一致
- 按 `M-HG-0`、`M-HG-9`、`M-HG-10`，缺少当前 Director canonical 确认时，不得进入 M-S1，也不得输出 PRD、UNIT 或 AC 草案。

**固定 handoff 问题**

请提供 `docs/{feature}/brief.json` 和 `docs/{feature}/phase-{N}/phase-prd.json` 路径或内容，以便校验 `director_confirmation.status`、`locked_fields` 与当前 Phase 边界。

本轮未写文件、未启动服务、未生成 PRD/UNIT/AC、未发起审查 agent。下一步只能在你提供上述 canonical Director 产物后，继续执行 M-S0 准入校验；通过后才进入 M-S1 业务流程共创。