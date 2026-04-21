我理解：你想用现有旧版 `brief.md` 和 `prd.md`，先在 PM 阶段拆 `UNIT`，等以后再补评审材料或 `product-manager-review.md`。预期结果是先拿到 UNIT 拆解。

判定：**不能直接拆 UNIT。**

按 `shared/skills/product-manager/SKILL.md`，当前只能停在 **M-S0 工件接收与验证**，原因是：

- standard-chain 运行时真源只能是 `brief.json / phase-{N}/phase-prd.json / phase-{N}/units/UNIT-*.json`。
- 旧版 `brief.md` 和 `prd.md` 是非 canonical 工件，不能通过 PM 准入。
- 缺少 `brief.json` 和 `phase-prd.json`，无法校验 `director_confirmation.status=passed`、`locked_fields`、Phase 边界与 Director-owned 字段一致性。
- `UNIT` 拆解属于 M-S4，必须在 M-S0 准入通过，并完成 M-S1~M-S3 共创后才能进入。
- “review 后面再补”不允许。评审结论必须沉淀到 canonical `review_conclusion / issue_ledger`，不能口头确认，也不能依赖事后补的 `product-manager-review.md`。
- M-HG-7 禁止跳过 UNIT、AC、完整性扫描或三方评审；M-HG-8 要求阻断未关闭时不得声称 PM 完成。

下一步只能补齐 handoff 输入：

`请提供 docs/{feature}/brief.json 和 docs/{feature}/phase-{N}/phase-prd.json 路径或内容，以便校验 director_confirmation.status、locked_fields 与当前 Phase 边界。`

若当前确实只有旧版 Markdown，需要先回到 `/product-director` 生成并重签 canonical `brief.json` 与 `phase-prd.json`，再进入 `/product-manager` 的 M-S0 校验。