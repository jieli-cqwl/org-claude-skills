阻断结论：当前只执行 M-S0 准入检查；因未提供 canonical `brief.json` 与 `phase-{N}/phase-prd.json` 路径或内容，无法校验 `director_confirmation.status`、`locked_fields`、`locked_field_digest` 与 Phase 1 边界，所以不得进入业务流程、UNIT 或 AC 细化，也不会接受口头“Director 已确认”。

请提供 `docs/{feature}/brief.json` 和 `docs/{feature}/phase-{N}/phase-prd.json` 路径或内容，以便校验 `director_confirmation.status`、`locked_fields` 与当前 Phase 边界。

已遵循 `shared/skills/product-manager/SKILL.md`：本轮未联网、未写文件、未运行长链路命令；`preflight_check.sh` 因缺少输入路径未执行。准入通过后，下一步才进入 M-S1，并且后续 UNIT 必须写清 `输入 / 触发 / 核心行为 / 可观察结果`；Integration Context 只写业务模块、不可破坏行为、跨 UNIT 依赖、依赖关系和排除项，不写技术实现路径。AC 需要包含示例输入、预期结果、边界情况、失败模式，并能映射 Verification Plan；排除项必须写入可追踪字段。