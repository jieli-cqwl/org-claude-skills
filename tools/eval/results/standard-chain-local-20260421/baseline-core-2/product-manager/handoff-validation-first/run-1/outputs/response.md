按 `shared/skills/product-manager/SKILL.md` 执行，本轮只进入 **M-S0 工件接收与验证**。

我理解你的目标是：在 Director 已确认的 Phase 1「商家入驻自动审核」基础上，继续细化业务流程、UNIT 和 AC，预期产出可执行粒度的 PM 工件。操作对象必须是 canonical 工件：`docs/{feature}/brief.json` 与 `docs/{feature}/phase-1/phase-prd.json`。

**M-S0 准入结论：阻断**

原因：当前 prompt 只提供了“已通过 Director 确认”的口头描述，没有提供 `brief.json` 与 `phase-prd.json` 的路径或内容，因此无法校验：

- `brief.json.director_confirmation.status`
- `phase-prd.json.director_confirmation.status`
- `director_confirmation.locked_fields`
- `locked_field_digest`
- Director-owned 字段与当前 Phase 1 边界是否一致

根据 skill 规则，不能接受口头确认；非 canonical 工件不得通过准入。准入未通过时，不得输出 PRD、UNIT 或 AC 草案，也不得用“review 后补”继续推进。

**下一步**

请提供 `docs/{feature}/brief.json` 和 `docs/{feature}/phase-1/phase-prd.json` 路径或内容，以便校验 `director_confirmation.status`、`locked_fields` 与当前 Phase 边界。校验通过后才进入 M-S1；若缺少当前 Director confirmation 或锁定内容漂移，必须回退 `/product-director` 重签。

本次未联网，未修改文件。