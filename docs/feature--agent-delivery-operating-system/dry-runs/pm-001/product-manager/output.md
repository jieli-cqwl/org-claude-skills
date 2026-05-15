**结论：M-S0 阻断，不能直接拆 UNIT/AC。**

当前输入是绕过 Director 的口头需求，不是 product-manager 可准入 handoff。按 M-HG-0 / M-S0，准入三件缺失：

- 缺 `brief.json`
- 缺 `phase-{N}/phase-prd.json`
- 缺当前 Director confirmation，无法证明 Director-owned 基线已冻结且与 handoff 一致

因此我不能产出 PRD、UNIT、AC、设计方案、任务计划或语言选型。继续拆会把 PM 细化建立在未确认范围上，下游会消费不可信基线。

**阻断信息**

- failure_code: `DIRECTOR_HANDOFF_MISSING`
- owner: `/product-director` + 用户确认
- reason: 缺少 Director 冻结的根问题、范围边界、非目标、成功标准、Phase 目标、入口/出口条件和确认状态
- recovery: 先由 `/product-director` 产出并确认 `brief.json` 与 `phase-{N}/phase-prd.json`，且 Director-owned 字段与当前 handoff 一致后，再进入 product-manager M-S0 preflight

**后续准入链**

1. 先收到并校验 `brief.json / phase-{N}/phase-prd.json / phase-{N}/units/UNIT-*.json`。
2. PM owner 自检通过后，计算并记录 `reviewed_bundle_digest`。
3. 三视角 reviewer 审同一份 `reviewed_bundle_digest` 绑定的 PM review bundle。
4. 三方评审 `FAIL` 必须关闭，`WARN` 必须承接。
5. 评审结论写入 `review_conclusion / issue_ledger`，交付前写入 `delivery_confirmation`。

**对下游影响**

- `/design`: 没有冻结范围、非目标和结构化 design handoff，不能判断哪些体验、页面或交互属于本期。
- `/test-design`: 没有可信 UNIT/AC/Verification Plan，不能建立验收覆盖和失败路径证明。
- `/tech-lead`: 没有冻结 Phase 边界、依赖和风险口径，无法做实现范围、影响面和 `scope_item_id / test_ref` 映射。

当前状态：M-S0 阻断；未进入 UNIT/AC 拆解；不声明 Stage 1 通过。