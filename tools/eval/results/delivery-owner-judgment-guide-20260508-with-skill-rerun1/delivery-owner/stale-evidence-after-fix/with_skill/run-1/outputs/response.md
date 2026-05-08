```text
status: DISPATCH_READY
plan_ref: unavailable
tasks_ref: T3
current_step: DO-S7 QA/修复循环，fixer 后证据新鲜度处理
execution_mode: reverify_first
active_batch: T3 受影响验证批次
active_tasks: T3
current_gap: fixer agent 修改了 T3 相关代码，之前的 verifier PASS 和 qa PASS 已变成 stale evidence
gap_owner: delivery-owner
next_owner: verifier agent
dev_verify_loop_count: unknown
qa_fix_loop_count: unknown
progress_signal: new_risk
consecutive_no_progress_count: 0
completed_tasks: T3 曾通过 verifier/qa，但通过证据发生在 fixer 修改前
evidence_refs: pre-fix verifier PASS, pre-fix qa PASS
stale_evidence_refs: pre-fix verifier PASS, pre-fix qa PASS
current_risk: 直接 /commit 会跳过 fixer 后回归验证，违反 qa agent 通过后才调度 /commit 的门禁
decision_boundary: 不允许直接调度 /commit
next_action: 先调度 T3 受影响范围的 verifier agent；verifier PASS 后重跑受影响 qa agent；两者通过且无未决风险，再进入 DO-S8 提交准备
resume_condition: post-fix verifier PASS + post-fix qa PASS + 无 blocking gap + 提交授权明确
```

结论：不能直接调度 `/commit`。

命中的门禁是：`fixer agent` 改了 T3 代码后，旧的 verifier / QA 证据失效；按 delivery-owner 流程，fixer 后必须重跑受影响的 verifier / qa。只有 post-fix verifier PASS、post-fix qa PASS、无未决风险，并且提交授权明确后，才可以进入 DO-S8 并准备 `/commit` handoff。