**状态卡**
- `current_stage`: `DO-S8b`
- `status`: `BLOCKED`
- `control_action`: `PAUSE_FOR_TARGET_CHANGE`
- `blocker_id`: `user_target_change_ac_3`
- `blocker_owner`: `user`
- `blocker_basis_refs`: `signoff-package.json`, `runtime_evidence_matrix`, `DO-S8b`
- `resume_stage`: `DO-S1`
- `next_action`: `将本次用户改动落为 target-change.json，并回到 product-manager 重新冻结 baseline`
- `resume_condition`: `新的 AC 基线、plan/tasks/test/design 与后续 evidence 全链路重基线完成`

**判定**
用户这句不是提交授权，而是**改变验收标准**：`AC-3` 从“导出明细行”改成“导出报表必须包含按门店分组的小计”。  
按 `delivery-owner` 规则，这必须走 `target-change.json`，不能写成 `user-decision.json`，也**不能直接进入最终准入或 /commit**。

**target-change.json 投影**
```json
{
  "changed_target_type": "AC",
  "affected_refs": [
    "AC-3",
    "signoff-package.json",
    "runtime_evidence_matrix",
    "qa-result",
    "code-review-result",
    "verify-result",
    "developer-report",
    "consistency-audit-result"
  ],
  "invalidates_refs": [
    "signoff-package.json",
    "runtime_evidence_matrix",
    "AC-3",
    "current plan/tasks/test references that assume detail-row-only export"
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

**下一步**
1. 回到 `product-manager` 重新冻结 AC/任务基线。
2. 重跑受影响链路的 fresh evidence。
3. 重新形成新的 `signoff-package.json` 后，再回到 `DO-S8b` 接收用户的提交授权。