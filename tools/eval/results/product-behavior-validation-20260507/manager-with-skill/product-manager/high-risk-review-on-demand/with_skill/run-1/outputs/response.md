已按 `shared/skills/product-manager/SKILL.md` 读取规则。理解：本 eval 只要求说明 PM 在 `M-S8/M-G1` 怎么推进，操作对象是准备评审的高风险 Phase，预期结果是给出必需字段、门禁、阻断条件和下一步；不实际生成文件、不启动评审 agent、不跑长链路命令。

PM 推荐推进结论：三方 reviewer 目前没有 FAIL，不能直接当作 M-G1 清洁通过。因为 Phase 涉及“批量重放失败任务、外部支付通知重试、重复提交幂等”，已触发 `high-risk-launch-review.md`，PM 必须在 `M-S8` 补做高风险上线补充审查，并把结论写入 `review_conclusion / issue_ledger`，不能只用口头结论。

`M-S8` 只聚焦这些高风险项收敛：

- 批量重放：重复触发、连续重放、失败任务重入后的可观察结果是否已被 UNIT / AC / Verification Plan 覆盖。
- 外部支付通知重试：失败重试、重复回调、外部依赖不可用时的业务结果是否可验收。
- 幂等与重复提交：同一业务动作重复提交时是否有明确业务结果、失败模式和可观察状态。
- 若首轮三方全 PASS，仍要做一轮 `CONFIRMATION`，并在 `review_conclusion / issue_ledger` 记录收敛轮次，防止浅层通过。
- WARN 可以存在，但必须有承接目标；FAIL 不得残留。

`M-G1` 收口门判断：

- `verdict=PASS`：三方评审 + 高风险补充审查均无 FAIL，且无 WARN。
- `verdict=WARN`：无未关闭 FAIL，但存在已记录承接目标的 WARN。
- `verdict=FAIL/BLOCKED`：存在未关闭 FAIL、连续评审未收敛、阻断事实缺失，或高风险项暴露 AI 可执行性阻断。
- 若高风险发现会改写目标、范围、业务规则、Phase 边界或 Director 锁定内容，PM 不得继续收口，必须回退 `/product-director`。

下一步：先在 `M-S8` 完成高风险补充审查并更新 `review_conclusion / issue_ledger`；确认无未关闭 FAIL 后，进入 `M-G1` 汇总 `verdict / 未关闭 FAIL / WARN 承接目标 / 收敛轮次 / 阻断事实`。当前无输入工件，所以不能声称 PM 完成或进入实际 handoff。