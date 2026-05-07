阻断结论：M-S0 准入失败，不能继续细化业务流程、UNIT 或 AC。

缺少 handoff 工件；docs/{feature}/brief.json 和 docs/{feature}/phase-{N}/phase-prd.json 是准入必需输入，用于校验 director_confirmation.status、locked_fields、当前 Phase 边界与 14 天 timebox。

已验证事实：
- 当前 workspace 只有 `shared/skills/product-manager/*`，没有 `docs/` 输入目录。
- `brief.json`、`phase-1/phase-prd.json` 均不存在。
- Prompt 中“已通过 Director 确认”不能替代 Director handoff 工件；Product Manager 不能补签确认门，也不能改写 Director 锁定字段。

流程边界：
- PM 只在已冻结 WHY、范围和 Phase 边界上细化 WHAT。
- 当前不能输出 PRD / UNIT / AC 草案。
- 通过准入后仍需补齐：UNIT 闭环定义、AC 示例输入/预期结果/边界/失败模式、排除项追踪、Verification Plan、Integration Context。

下一步：补充本次 Phase 1 的 `docs/{feature}/brief.json` 与 `docs/{feature}/phase-1/phase-prd.json`，且 `director_confirmation.status=passed` 后，再运行 M-S0 preflight，然后进入 M-S1 业务流程细化。