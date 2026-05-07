理解：目标是继续细化「商家入驻自动审核」Phase 1；操作对象应是 Director 已冻结的 `brief.json` 与 `phase-1/phase-prd.json`；预期结果是产出可执行粒度的业务流程、UNIT、AC 和后续 handoff 门禁。

**阻断结论**

缺少 handoff 工件；docs/{feature}/brief.json 和 docs/{feature}/phase-{N}/phase-prd.json 是准入必需输入，用于校验 director_confirmation.status、locked_fields、locked_field_digest、当前 Phase 边界与 14 天 timebox。

按 `shared/skills/product-manager/SKILL.md` 的 M-HG-0 / M-S0，口头说明“已通过 Director 确认”不能替代工件准入；非 `brief.json / phase-prd.json` 工件也不得通过准入。当前 workspace 的 `docs/` 下没有本 eval 的 `brief.json` 或 `phase-1/phase-prd.json`，因此不能生成 PRD、UNIT 或 AC 草案，也不能补签确认门。

后续通过准入后仍要补齐：每个 UNIT 的 `输入 / 触发 / 核心行为 / 可观察结果` 闭环定义；Integration Context 只写业务模块、不可破坏行为、跨 UNIT 依赖和业务约束，不写技术实现路径；AC 必须包含示例输入、预期结果、边界情况、失败模式，并映射 Verification Plan；排除项必须可追踪到 UNIT、AC、Verification Plan 或 design handoff。

**下一步**

请先提供或生成本 Phase 的准入工件：

- `docs/{feature}/brief.json`
- `docs/{feature}/phase-1/phase-prd.json`

且其中需要包含当前 Director 确认通过、锁定字段快照/digest、Phase 1 边界和 `iteration_timebox_days <= 14`。之后我才能运行 M-S0 preflight，并按 M-S1 → M-S9 继续收口业务流程、UNIT、AC、评审门禁和交付确认。