我理解：操作对象是 M-S7 缺失边界 AC、M-S8 评审结论、M-S9 `delivery_confirmation`，预期结果是先给 PM 裁决建议，把 canonical 评审字段收口后，再请求交付确认，并说明 `/design` 只消费 canonical JSON。

**PM 裁决建议**

建议继续，但必须按这个顺序：

1. 先补齐 M-S7 发现的 AC 边界案例  
   对应 `UNIT-*.json.acceptance_criteria` 需要补上：示例输入、预期结果、边界情况、失败模式，并同步映射到 `verification_plan`。补齐前不能进入 M-S9。

2. M-S8 可继续进入 M-G1  
   因为 tester 只有 `WARN`，reviewer 无 `FAIL`，满足“PASS/WARN 且无未关闭 FAIL 可进入 M-S9”。但 WARN 不能口头带过，必须写入 canonical `issue_ledger`，并指定承接目标。

3. canonical 评审结论应收口为：
   - `review_conclusion.verdict = "WARN"`
   - `review_conclusion.unclosed_fail_count = 0`
   - `review_conclusion.can_enter_m_s9 = true`
   - `issue_ledger` 记录：
     - M-S7 边界 AC 缺口：状态为已补齐/closed
     - M-S8 tester WARN：状态为 open/warn，承接目标建议为 `/design` 消费并传递给后续测试设计，作为边界验证重点

4. 完成上述 canonical 更新后，才能在 M-S9 请求用户确认：
   推荐将 `brief.json.delivery_confirmation.status` 置为 `confirmed`。  
   请用户在 M-S9 选择：确认交付 / 修正 WARN 承接目标 / 暂不确认并回到 M-S5 或 M-S8。

**阻断条件**

若边界案例未补齐、WARN 没有承接目标、存在未关闭 FAIL、或用户未确认 `delivery_confirmation.status=confirmed`，都不能声明 PM 完成，也不能交给 `/design`。

**交给 `/design` 的方式**

只交 canonical JSON：

- `brief.json`
- `phase-{N}/phase-prd.json`
- `phase-{N}/units/UNIT-*.json`

`/design` 只消费这些字段：交付状态、`review_conclusion`、`issue_ledger`、WARN 承接目标、`verification_plan`、`integration_context`、结构化 `design_decision_candidates`。不交临时草稿、口头结论或人类投影视图。  
本 eval 无输入文件，因此不实际写文件、不运行验证命令。