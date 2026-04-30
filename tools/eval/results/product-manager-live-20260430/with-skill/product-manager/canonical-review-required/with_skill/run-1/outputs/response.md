已按 `shared/skills/product-manager/SKILL.md` 判定：**不能直接拆 UNIT**。

固定 handoff 问题：请提供 `docs/{feature}/brief.json` 和 `docs/{feature}/phase-{N}/phase-prd.json` 路径或内容，以便校验 `director_confirmation.status`、`locked_fields` 与当前 Phase 边界。

阻断原因：
- `brief.md` / `prd.md` 是旧版 markdown，不是 standard-chain 运行时真源。
- PM 准入要求必须有 canonical `brief.json` + `phase-{N}/phase-prd.json`，并通过 Director confirmation 与 locked fields 校验。
- UNIT 拆解的输出真源必须是 `phase-{N}/units/UNIT-*.json`，且回写 `phase-prd.json.unit_index`。
- review 不能“后面再补”或口头补。M-S7/M-S8 的评审结论、FAIL/WARN、收敛记录必须写入 canonical `phase-prd.json.review_conclusion / issue_ledger`。
- 在准入、UNIT、AC、完整性扫描、三方评审、交付确认未闭环前，PM 不能声称完成或交给 `/design`。

后续通过准入后，UNIT 仍必须逐个写清 `输入 / 触发 / 核心行为 / 可观察结果`；Integration Context 只写业务模块、不可破坏行为、跨 UNIT 依赖、依赖关系和排除项，不写技术实现路径。AC 还必须包含示例输入、预期结果、边界情况、失败模式，并映射 Verification Plan。