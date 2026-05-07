阻断结论：M-S0 准入失败，不能继续细化业务流程、UNIT 或 AC，也不能生成草案。

缺少 handoff 工件；docs/{feature}/brief.json 和 docs/{feature}/phase-{N}/phase-prd.json 是准入必需输入，用于校验 director_confirmation.status、locked_fields、当前 Phase 边界与 14 天 timebox。

本轮复述理解：
- 目标：把「商家入驻自动审核」Phase 1 细化到可执行 PRD、UNIT、AC 粒度。
- 操作对象：Director 已确认的 Phase 1 handoff 工件。
- 预期结果：业务流程、用户路径、规则映射、UNIT 闭环、示例驱动 AC、Verification Plan、待设计决策和交付门禁闭合。
- 当前事实：workspace 没有可消费的 `docs/{feature}/brief.json` 或 `phase-1/phase-prd.json`；扫描到的只是 `shared/skills/product-manager/evals/...` 下的 skill 自带样例，不是本 eval 输入，且主题不匹配。

按 `product-manager` skill 边界，PM 只能在 Director 已冻结的 WHY、范围和 Phase 边界上补 WHAT；缺少当前 Director confirmation 时必须回到 `/product-director` 重签，不能由 PM 补签或假设已通过。

后续通过准入后，仍要补齐每个 UNIT 的 `输入 / 触发 / 核心行为 / 可观察结果`，并完成 AC 示例输入、预期结果、边界情况、失败模式、Verification Plan 与排除项追踪后，才能进入审查和 `/design` handoff。