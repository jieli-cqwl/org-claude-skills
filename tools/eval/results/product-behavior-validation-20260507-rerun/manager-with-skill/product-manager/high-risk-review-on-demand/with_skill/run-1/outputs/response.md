目标理解：你要我按 `product-manager` skill，说明这个高风险 Phase 在 M-S8/M-G1 的推进口径；对象是批量重放失败任务、外部支付通知重试、重复提交幂等风险；预期是不展开普通评审全细节，只给必需字段、门禁、阻断条件和下一步。

已冻结事实：三方 reviewer 当前没有 FAIL，但 Phase 命中高风险信号：批量重放、失败重试、外部依赖通知、幂等/重复提交。  
PM 推荐结论草案：M-S8 不能直接因为“三方无 FAIL”进入 M-G1 收口，必须追加高风险补充审查；若补充审查无阻断，只能以 PASS/WARN 且无未关闭 FAIL 推进到 M-G1。  
推荐理由：`high-risk-launch-review.md` 明确要求这些场景补查失败模式、补偿/回滚、不可回滚阻断、重复提交可观察结果，以及是否需要补入 AC / Verification Plan / `issue_ledger`。  
会改变结论的业务假设：这些风险审查不会改变目标、范围、业务规则或 Phase 边界；如果会改变，PM 必须回退 `/product-director`，不能在 M-S8 内自行改写。

M-S8 推进边界：

- 保留常规 `3 视角×max10轮` 评审结果，但不展开普通评审细节。
- 因命中高风险信号，追加高风险补充审查。
- 检查并记录：失败重试、批量重放、重复通知、重复提交时的可观察结果；幂等成功/重复忽略/重复失败的业务表现；补偿或回滚路径；不可回滚时的阻断结论。
- 若发现 AC、Verification Plan、Integration Context 或设计待决策缺口，补入对应 JSON 支持字段和 `issue_ledger`；不能只口头说明。
- 若出现未关闭 FAIL、AI 可执行性阻断、Director 锁定字段漂移，则停在 M-S8 修复或回退，不进 M-G1。
- WARN 可以存在，但必须写入 `review_conclusion / issue_ledger` 并有承接目标。

M-G1 收口门：

- 只在 M-S8 达到 PASS/WARN 且无未关闭 FAIL 时进入。
- 必需收口字段是：`verdict`、未关闭 FAIL 列表、WARN 承接目标、收敛轮次、阻断事实记录。
- 如果首轮三方全 PASS，仍需记录确认轮 `R2 / CONFIRMATION`，防止浅层通过。
- M-G1 通过后只能进入 M-S9 交付确认；不能直接宣称 Manager 完成。
- Manager 完成还需要 `brief.json.delivery_confirmation.status=confirmed`，并通过 PM handoff gate。

本 eval 输入文件为 none，且 prompt 要求说明推进方式，所以我不写文件、不启动 reviewer、不运行长链路命令。下一步：若进入真实执行，需要提供已冻结的 `brief.json / phase-prd.json / units/UNIT-*.json`，PM 才能在 M-S8 写入 `review_conclusion / issue_ledger` 并推进 M-G1。