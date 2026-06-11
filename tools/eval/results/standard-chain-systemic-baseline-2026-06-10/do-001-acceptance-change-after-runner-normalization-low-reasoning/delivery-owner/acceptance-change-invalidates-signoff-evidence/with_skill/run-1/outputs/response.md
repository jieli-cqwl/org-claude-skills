```text
status: PAUSED_FOR_USER_DECISION
commit_state: NOT_READY
plan_ref: signoff-package.json 已准备完成，但当前被用户 AC 变更打断
tasks_ref: active tasks 需随 AC 重基线后重新冻结
current_step: 接收到了 AC 变更，不是提交授权
execution_mode: pause_for_rebaseline
active_batch: none
active_tasks: none
current_gap: AC-3 已从“导出明细行”变更为“导出报表必须包含按门店分组的小计”
gap_owner: product-manager
next_owner: user
dev_verify_loop_count: 0
qa_fix_loop_count: 0
progress_signal: authoritative_owner_routed
consecutive_no_progress_count: 0
completed_tasks: signoff-package.json 已有，但其前提 AC 已被用户改动，旧证据失效
evidence_refs:
  - signoff-package.json
  - runtime_evidence_matrix
stale_evidence_refs:
  - developer-report
  - verify-result
  - code-review-result
  - qa-result
  - consistency-audit-result
owner_action_consumption:
  - action_id: user-ac-change-do-s8b-1
    required_owner: product-manager
    routed_to: user
    result: REBASELINE_REQUIRED
    evidence_ref: signoff-package.json
    state_update:
      current_stage: DO-S8b
      status: PAUSED_FOR_USER_DECISION
      control_action: REQUEST_TARGET_CHANGE
      next_action: write target-change.json
      resume_condition: 重新冻结 baseline 并产出 fresh evidence 后再回到收口
    reopen_condition: 用户确认 AC 变更后，必须从 product-manager 重新冻结 AC/PRD，再刷新后续证据链
current_risk: 现有签收包与真实 AC 不一致，直接提交会错签
decision_boundary: 用户已改变 acceptance criteria，必须走 target-change.json，不可写 user-decision.json
blocker_id: ac-change
blocker_owner: product-manager
blocker_basis_refs:
  - signoff-package.json
  - runtime_evidence_matrix
resume_stage: DO-S1
next_action: 输出 target-change.json 并回到 product-manager 重冻结 baseline
resume_condition: 新 AC 被冻结，且后续 developer-report / verify-result / code-review-result / qa-result / consistency-audit-result 全链路刷新完成
```

`target-change.json` 字段投影如下：

```json
{
  "artifact_type": "target-change",
  "changed_target_type": "AC",
  "affected_refs": [
    "signoff-package.json",
    "runtime_evidence_matrix",
    "AC-3"
  ],
  "invalidates_refs": [
    "developer-report",
    "verify-result",
    "code-review-result",
    "qa-result",
    "consistency-audit-result",
    "signoff-package.json"
  ],
  "superseded_evidence_refs": [
    "developer-report",
    "verify-result",
    "code-review-result",
    "qa-result",
    "consistency-audit-result"
  ],
  "rebaseline_required": true,
  "rebaseline_owner": "product-manager",
  "required_fresh_proof_after_rebaseline": [
    "brief",
    "phase-prd",
    "unit-definition",
    "design",
    "test-cases",
    "plan",
    "tasks",
    "developer-report",
    "verify-result",
    "code-review-result",
    "qa-result",
    "consistency-audit-result"
  ]
}
```

下一步只有一个：先补 `target-change.json`，再回到 `product-manager` 重冻结 AC/PRD。当前不能进入 `user-decision.json`，也不能发 `/commit`。