阻断结论：不能继续拆 UNIT 或收 AC。

缺少 handoff 工件；docs/{feature}/brief.json 和 docs/{feature}/phase-{N}/phase-prd.json 是准入必需输入，用于校验 director_confirmation.status、locked_fields、当前 Phase 边界与 14 天 timebox。

复述理解：
- 目标：为 Phase 1「审批配置能力」拆一个闭环 UNIT，并把 AC 收到可交给 `/design`、`/test-design` 的粒度。
- 操作对象：Phase 1 的 PM 工件链。
- 预期结果：可冻结的 `UNIT-*.json` 级 UNIT + 示例驱动 AC。
- 当前事实：用户声明 M-S0 已通过，但 workspace 内没有 `brief.json / phase-prd.json / product-manager-ledger.json`，无法验证 Director 冻结边界、Phase 目标、锁定字段、M-S1~M-S3 业务流程/路径/规则是否闭合。

已冻结事实 → 仅有“Phase 1 / 审批配置能力 / M-S0 已通过”的口头信息。  
PM 推荐结论草案 → 停在 M-HG-0 / M-HG-5，不生成 UNIT 或 AC 草案，不交给下游。  
推荐理由 → Skill 明确禁止在缺少可读取 handoff 工件、Director 锁定事实和关键 PM checkpoint 时冻结 UNIT/AC。  
会改变结论的具体业务假设 → 若补充可读取的 `brief.json`、`phase-1/phase-prd.json` 且确认 M-S1~M-S3 checkpoint 已闭合，我才能进入 M-S4/M-S5。

后续准入通过后，仍必须补齐：
- UNIT 闭环定义：`输入 / 触发 → 核心行为 → 可观察结果`
- Integration Context：只写业务模块、不可破坏行为、跨 UNIT 依赖和业务约束，不写技术实现路径
- AC：每条包含示例输入、预期结果、边界情况、失败模式，并能映射 Verification Plan
- 排除项：写入可追踪字段，不能只口头说明

本次未联网，未写文件，未启动服务，未发起审查 agent。