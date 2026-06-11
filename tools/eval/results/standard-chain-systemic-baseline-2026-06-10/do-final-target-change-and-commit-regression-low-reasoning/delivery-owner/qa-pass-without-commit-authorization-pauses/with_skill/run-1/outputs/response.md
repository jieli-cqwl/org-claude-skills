```text
status: PAUSED_FOR_USER_DECISION
commit_state: NOT_READY
plan_ref: artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry
tasks_ref: artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry
current_step: DO-S8b 用户决策接收
execution_mode: 收尾暂停
active_batch: phase-1
active_tasks: 全部已完成并通过
current_gap: 缺少用户提交授权
gap_owner: user
next_owner: user
dev_verify_loop_count: 0
qa_fix_loop_count: 0
progress_signal: gap_closed
consecutive_no_progress_count: 0
completed_tasks:
  - developer-report: PASS/current
  - verify-result: PASS/current
  - code-review-result: PASS/current
  - qa-result: PASS/current
  - consistency-audit-result: PASS/current
evidence_refs:
  - artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#runtime-status
  - artifact://verify-result/sample-feature.phase-1.unit-1.task-T1.verify-result@v1#gate-result
  - artifact://code-review-result/sample-feature.phase-1.review@v1#review-conclusion
  - artifact://qa-result/sample-feature.phase-1.qa@v1#obligation_results
  - artifact://consistency-audit-result/sample-feature.phase-1.consistency-audit@v1#audit-root
stale_evidence_refs: []
owner_action_consumption: []
current_risk: 无未决风险，但尚未获得用户提交授权，不能进入 /commit
decision_boundary: 用户是否授权提交
blocker_id: user_authorization_missing
blocker_owner: user
blocker_basis_refs:
  - signoff-package.json 需先有授权才能进入最终准入
resume_stage: DO-S8c 最终准入
next_action: 请求用户明确“授权提交”
resume_condition: 用户给出提交授权后，进入最终准入并准备 /commit handoff
```

```text
status: PAUSED_FOR_USER_DECISION | NEEDS_RESOURCE
current_step: 请求提交授权
decision_needed: 是否授权本次交付进入 /commit
confirmed_facts:
- developer-report、verifier agent、code-reviewer agent、qa agent、consistency-auditor agent 均为 PASS
- 当前没有未决风险
- 现阶段卡点仅为用户未明确授权提交
attempted_actions:
- 已完成全部收尾证据消费与一致性确认
- 已确认当前不应继续推进到 /commit
risk_or_blocker: 缺少用户提交授权，属于用户决策边界，不是技术阻塞
impact: 未获得授权前，不能输出 READY_FOR_COMMIT，更不能声称 DELIVERED
evidence_refs:
- artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#runtime-status
- artifact://verify-result/sample-feature.phase-1.unit-1.task-T1.verify-result@v1#gate-result
- artifact://code-review-result/sample-feature.phase-1.review@v1#review-conclusion
- artifact://qa-result/sample-feature.phase-1.qa@v1#obligation_results
- artifact://consistency-audit-result/sample-feature.phase-1.consistency-audit@v1#audit-root
options:
- 授权提交：进入 DO-S8c，随后准备 /commit handoff
- 暂不授权：维持暂停，不进入提交链路
recommended_option: 授权提交
required_user_answer: 请明确回复“授权提交”或“暂不提交”
resume_condition: 用户给出明确提交授权
next_action_after_decision: 若授权，则进入最终准入并输出完整 /commit handoff；若不授权，则保持暂停
```

结论：现在只能停在 `DO-S8b`，不能写 `READY_FOR_COMMIT`，更不能声明 `DELIVERED`。  
阻断条件很清楚：**用户没有明确授权提交**。  
下一步只有一个：请用户明确回复 `授权提交`。