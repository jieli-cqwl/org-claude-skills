使用 `product-manager` skill。理解：目标是说明这个高风险 Phase 在 M-S8/M-G1 的 PM 推进口径；操作对象是批量重放失败任务、外部支付通知重试、重复提交幂等风险；预期结果是给出门禁、阻断条件和下一步，不实际生成工件或启动评审。

**已冻结事实**  
三方 reviewer 目前没有 FAIL；该 Phase 命中高风险信号：批量重放、失败重试、外部依赖/支付通知、幂等与重复提交。

**PM 推荐结论草案**  
M-S8 不能因“三方 reviewer 无 FAIL”直接跳到完成。PM 应先记录：常规三方评审仍按 `3 视角 × max10 轮`成立，但本次不展开普通评审细节；因命中高风险信号，必须追加高风险补充审查，并把结论写入 `review_conclusion / issue_ledger`。

高风险补充只查这些点：
- 批量重放失败任务：失败模式、补偿/回滚、不可回滚时的阻断结论。
- 外部支付通知重试：外部依赖不可用、重复回调、重试后的可观察结果。
- 重复提交幂等：重复提交是否产生重复业务结果，以及用户/后台可观察结果。
- 发现缺口时，必须补入 AC、Verification Plan 或 `issue_ledger`；AC 必须有示例输入、预期结果、边界情况、失败模式，并能映射 Verification Plan。
- 排除项必须进入排除项追踪字段，不能口头带过。

**M-S8 阻断条件**  
出现任一情况不得进 M-G1：
- 高风险补充审查产生未关闭 FAIL。
- 发现需要改写目标、范围、规则或 Phase 边界，必须回退 `/product-director`。
- AI 可执行性阻断未关闭。
- WARN 没有写入 `review_conclusion / issue_ledger` 的承接目标。
- 评审未收敛或同一 issue 多轮无法关闭。

**M-G1 收口门**  
只有 `PASS/WARN 且无未关闭 FAIL` 才能进入下一步。M-G1 必须汇总：
- `verdict`: `PASS` 或 `WARN`
- `open_failures`: 必须为空
- `warn_carryovers`: WARN 的承接目标
- `convergence_rounds`: 收敛轮次
- `blocking_facts`: 阻断事实，没有则明确为空

**下一步**  
若高风险补充审查无 FAIL：M-G1 以 `PASS` 或 `WARN` 收口，WARN 写承接目标，然后进入 M-S9 交付确认。若补充审查发现 FAIL：回到 M-S8 修复并只重提 FAIL 相关视角；若触及 Director 锁定边界，回退 `/product-director`。本次 eval 无输入工件，所以不能声明实际 M-S8/M-G1 已通过。