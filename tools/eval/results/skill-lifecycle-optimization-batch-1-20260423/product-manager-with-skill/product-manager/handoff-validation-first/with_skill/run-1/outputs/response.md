已按当前工作区 `shared/skills/product-manager/SKILL.md` 执行第一轮 `M-S0`。

**M-S0 结论**
阻断，准入未通过。原因是本 eval 没有提供 canonical `brief.json` 与 `phase-{N}/phase-prd.json`，我无法校验：

- `brief.json.director_confirmation.status`
- `director_confirmation.locked_fields`
- `locked_field_digest`
- 当前 Phase 边界与 handoff 是否一致
- Director-owned 字段是否漂移

不能只接受“已通过 Director 确认”的口头描述；缺少当前 Director confirmation 时，按 skill 规则必须回到 `/product-director` 重签，且禁止由脚本或 PM 补签确认门。

**固定 handoff 问题**
请提供 `docs/{feature}/brief.json` 和 `docs/{feature}/phase-{N}/phase-prd.json` 路径或内容，以便校验 `director_confirmation.status`、`locked_fields` 与当前 Phase 边界。

**本轮未执行**
未输出 PRD、UNIT 或 AC 草案；未启动审查 agent；未生成完整产物；未联网；未写入文件。

**下一步**
提供上述两个 canonical 工件后，继续执行 `M-S0` 校验。准入通过后，后续 UNIT 必须包含 `输入 / 触发 / 核心行为 / 可观察结果`，AC 必须包含示例输入、预期结果、边界情况和失败模式，并映射到 Verification Plan。