# Delivery Status Card

```text
status: NEEDS_BASELINE | NEEDS_INPUT | NEEDS_RESOURCE | REVIEWING | DISPATCH_READY | IN_PROGRESS | READY_FOR_QA | READY_FOR_COMMIT | DELIVERED | PAUSED_FOR_USER_DECISION
commit_state: NOT_READY | HANDOFF_PREPARED | COMMIT_RESULT_RECORDED
plan_ref:
tasks_ref:
current_step:
execution_mode:
active_batch:
active_tasks:
current_gap:
gap_owner:
next_owner: user | developer agent | verifier agent | qa agent | fixer agent | /commit
dev_verify_loop_count:
qa_fix_loop_count:
progress_signal: gap_closed | gap_narrowed | gap_judgment_changed | new_blocker | new_risk | authoritative_owner_routed | no_progress
consecutive_no_progress_count:
completed_tasks:
evidence_refs:
stale_evidence_refs:
owner_action_consumption:
  - action_id:
    required_owner:
    routed_to:
    result: ROUTED | OWNER_ACCEPTED | OWNER_RESOLVED | USER_DECISION_REQUESTED | REBASELINE_REQUIRED | BLOCKED
    evidence_ref:
    state_update:
      current_stage:
      status:
      control_action:
      next_action:
      resume_condition:
    reopen_condition:
current_risk:
decision_boundary:
blocker_id:
blocker_owner:
blocker_basis_refs:
resume_stage:
next_action:
resume_condition:
```
