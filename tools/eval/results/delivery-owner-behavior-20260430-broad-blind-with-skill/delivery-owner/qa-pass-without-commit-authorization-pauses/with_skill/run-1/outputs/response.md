复述理解：当前所有 task 已有 developer-report、verifier agent PASS、qa agent PASS，且无未决风险；但用户未明确授权提交。按 `delivery-owner` 的 DO-S8，不能调度 `/commit`，必须暂停等待用户决策。

```text
status: PAUSED_FOR_USER_DECISION
plan_ref: unavailable
tasks_ref: unavailable
current_step: DO-S8 提交与汇报
execution_mode: closeout
active_batch: all tasks
active_tasks: none
current_gap: commit authorization unclear
gap_owner: user
next_owner: user
dev_verify_loop_count: 0
qa_fix_loop_count: 0
progress_signal: owner_changed
consecutive_no_progress_count: 0
completed_tasks: all tasks reported complete by eval prompt
evidence_refs: developer-report: PASS; verifier agent: PASS; qa agent: PASS
stale_evidence_refs: none reported
current_risk: none reported
decision_boundary: 提交授权不清，触发 DO-HG-5
next_action: 等待用户明确是否授权提交
resume_condition: 用户明确授权提交或明确不提交
```

```text
status: PAUSED_FOR_USER_DECISION
current_step: DO-S8 提交与汇报
decision_needed: 是否授权调度 /commit
confirmed_facts: 所有 task 已有 developer-report；verifier agent PASS；qa agent PASS；当前无未决风险
attempted_actions: 未调度 /commit；未启动额外 agent；未写文件
risk_or_blocker: 用户提交授权不清
impact: 无法进入提交步骤，交付停在提交前
evidence_refs: eval prompt supplied logical evidence
options: 1. 授权提交 2. 暂不提交并保持当前交付状态
recommended_option: 授权提交后再调度 /commit
required_user_answer: 明确回答“授权提交”或“暂不提交”
resume_condition: 收到提交授权决策
next_action_after_decision: 授权则调度 /commit；不授权则输出未提交收尾状态
```

```text
status: PAUSED_FOR_USER_DECISION
commit_result: not_run
open_risks: none reported
user_decision_needed: commit authorization
next_action: 等待用户授权，不越权提交
```