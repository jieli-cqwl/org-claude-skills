使用 `shared/skills/product-manager/SKILL.md` 执行。目标：说明该高风险 Phase 在 **M-S8/M-G1** 的 PM 推进方式；对象：批量重放失败任务、外部支付通知重试、重复提交幂等风险；预期结果：不展开普通评审全流程，只给门禁、必需字段、阻断条件和下一步。

已冻结事实：题设说明三方 reviewer 当前没有 FAIL，但命中 **高风险补充审查** 信号：批量重放、失败重试、外部依赖、幂等/重复提交。PM 推荐结论草案：M-S8 不能只按“无 FAIL”放行，必须在常规三方评审主结论之外，补做高风险检查，并把结果写入 `review_conclusion / issue_ledger`。推荐理由：skill 明确规定这些风险只作为 M-S8 补充审查，常规三方结论仍是主结论，补充发现以 WARN/承接记录进入收口门。

**M-S8 推进口径**
- 先确认常规三方评审状态：产品 / 架构 / 测试 reviewer 当前无未关闭 FAIL。
- 如果这是首轮全 PASS，仍必须做一轮 `R2 / CONFIRMATION`，不能直接进 M-G1。
- 因命中高风险信号，补充检查必须覆盖：失败模式、补偿或回滚、不可回滚时的阻断结论、重复提交的可观察结果、是否需要补入 AC / Verification Plan / `issue_ledger`。
- 补充审查不替代常规三方评审；最终只通过 schema 支持的 `PASS/WARN` 写入，WARN 必须有承接目标。
- 如果补充审查发现需要改写目标、范围、业务规则或 Phase 边界，PM 必须回退 `/product-director`，不得在 M-S8 内自行改 Director 锁定内容。

**M-G1 收口门**
- 可进入 M-G1 的条件：常规三方评审无未关闭 FAIL，确认轮无新增 FAIL，高风险补充项已写入 `review_conclusion / issue_ledger`。
- M-G1 verdict 只能是：`PASS` 或 `WARN` 且无未关闭 FAIL。
- 对本题更合理的收口结果通常是 `WARN`：不是因为 reviewer FAIL，而是高风险上线项需要下游承接。
- WARN 承接目标应指向对应 UNIT 的 AC、Verification Plan、design handoff 或后续交付风险记录，不能口头带过。

**阻断条件**
- 任何未关闭 FAIL：回到 M-S8 修复并只重提 FAIL 视角。
- 连续评审不收敛、同一 issue 连续 3 轮未关闭：`BLOCKED`。
- 高风险补充项显示不可回滚且无业务阻断结论：阻断。
- 发现目标、范围、规则、Phase 边界需要变化：回退 `/product-director`。
- 若真实执行而非本 eval 说明，还必须先具备 `brief.json / phase-prd.json / units/UNIT-*.json`，否则准入阻断。

一个会改变结论的具体业务假设：默认把“批量重放、支付通知重试、重复提交幂等”作为 **WARN 承接** 推进到 M-G1；除非其中任一场景要求改变 Phase 范围、业务规则或成功标准，那就不能 M-G1 收口，必须回退 `/product-director`。