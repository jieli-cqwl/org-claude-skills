理解：你要我基于已通过 Director 确认的 Phase 1，继续细化「商家入驻自动审核」的业务流程、UNIT 和 AC 到可执行粒度。

阻断结论：M-S0 准入失败，不能继续生成 PRD / UNIT / AC 草案。

缺少 handoff 工件；docs/{feature}/brief.json 和 docs/{feature}/phase-{N}/phase-prd.json 是准入必需输入，用于校验 director_confirmation.status、locked_fields、当前 Phase 边界与 14 天 timebox。

证据：当前 eval prompt 明确 `Input files available in the workspace: none`；工作区内也没有当前任务的 `docs/.../brief.json`、`phase-1/phase-prd.json` 或 `product-manager-ledger.json`。仅发现 `shared/skills/product-manager/evals/...` 下的旧 eval fixture，不能作为本次准入输入。

按 `product-manager` skill 门禁：
- M-HG-0：缺 `brief.json` / `phase-prd.json`，不得准入。
- M-HG-3：完整工件集缺失，不得 handoff。
- M-HG-5 / M-HG-7：关键事实未闭合，不能跳到 UNIT、AC、评审或交付确认。
- M-HG-10：不能脚本补签 Director 确认门。

下一步：先回到 `/product-director` 产出或恢复当前 Phase 的 `docs/商家入驻自动审核/brief.json` 与 `docs/商家入驻自动审核/phase-1/phase-prd.json`，并确保 Director confirmation 当前有效。通过准入后，PM 阶段再依次补齐 UNIT 闭环定义、AC 示例字段、排除项追踪、Verification Plan、三方评审与交付确认。