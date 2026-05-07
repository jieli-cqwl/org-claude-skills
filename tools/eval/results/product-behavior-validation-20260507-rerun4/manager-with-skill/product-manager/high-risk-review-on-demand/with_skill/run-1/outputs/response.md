已按当前工作区 `shared/skills/product-manager/SKILL.md` 执行只读 eval；不联网、不写文件、不启动 reviewer/agent。

已冻结事实：当前 Phase 命中高风险信号：批量重放失败任务、外部支付通知重试、重复提交幂等风险；三方 reviewer 目前没有 FAIL。M-S8 常规评审仍按 `产品 / 架构 / 测试 3 视角 × max10 轮` 执行；本次命中高风险信号，因此读取 `references/high-risk-launch-review.md`。若未命中这些信号，只走常规三方评审，不读取高风险补充审查。

PM 推荐推进：

1. **M-S8 先做高风险补充收敛**
   - 不因“三方 reviewer 无 FAIL”直接进 M-G1。
   - 必须补查：失败模式、补偿或回滚、不可回滚时的阻断结论、重复提交的可观察结果。
   - 若发现 AC / Verification Plan / `issue_ledger` 缺口，补入对应 JSON 字段或记录 WARN 承接目标。
   - 若补查发现会改写目标、范围、业务规则或 Phase 边界，停止 PM 推进，回退 `/product-director`。

2. **M-S8 写入/消费边界**
   - 只消费已冻结的 `brief.json / phase-prd.json / units/UNIT-*.json`。
   - 只写入 schema 支持的 `review_conclusion / issue_ledger`，最终结论只允许 PASS/WARN；运行态 FAIL 不能残留到收口。
   - WARN 不能口头带过，必须有承接目标。

3. **M-G1 收口门判断**
   - 条件：PASS/WARN 且无未关闭 FAIL，才可进入 M-S9。
   - M-G1 必需字段/事实：`verdict`、未关闭 FAIL 列表、WARN 承接目标、收敛轮次、阻断事实记录。
   - 若无 FAIL 但高风险补充未覆盖或 WARN 未承接，M-G1 不通过。
   - 若发现 PM 改写 Director 锁定内容，`verdict=FAIL`，回退 `/product-director`。

阻断条件：未关闭 FAIL、高风险补充缺口未写入 AC / Verification Plan / `issue_ledger`、WARN 无承接目标、连续评审未收敛、阻断事实缺失、Director 锁定内容漂移。

下一步：PM 应先完成 M-S8 高风险补充审查并更新 `review_conclusion / issue_ledger`；确认无未关闭 FAIL 且 WARN 有承接目标后，再进入 M-G1 收口。