**状态卡**
- `current_stage`: `DO-S8b`
- `status`: `BLOCKED`
- `control_action`: `PAUSE_FOR_REBASELINE`
- `blocker_id`: `target_change.ac_changed`
- `blocker_owner`: `product-manager`
- `blocker_basis_refs`: `signoff-package.json`, `runtime_evidence_matrix`, `DO-S8b 用户决策接收`
- `resume_stage`: `DO-S1`
- `next_action`: 先做目标变更重基线，不进入 `user-decision.json`，不允许 `/commit`
- `resume_condition`: 重新冻结后的 `AC` 与新证据链完成并通过 fresh 验证，且新 `signoff-package.json` 重新形成

**结论**
用户这句“`AC-3` 改成导出报表必须包含按门店分组的小计”属于**验收标准变更**，不是提交授权，也不是风险接受。  
按 `delivery-owner` 规则，当前 `signoff-package.json` 立即失效，不能直接进入最终准入，更不能提交。

**必须输出的 target-change.json 字段投影**
```json
{
  "changed_target_type": "AC",
  "affected_refs": [
    "AC-3",
    "signoff-package.json",
    "runtime_evidence_matrix",
    "qa-result",
    "verify-result",
    "code-review-result",
    "developer-report",
    "consistency-audit-result"
  ],
  "invalidates_refs": [
    "current signoff baseline",
    "current signoff-package.json",
    "all evidence tied to old AC-3"
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
1. 回 `product-manager` 重新冻结 `AC-3`。
2. 重新跑后续 fresh 证据链。
3. 重新形成新的 `signoff-package.json` 后，再回到 `DO-S8b` 申请提交授权。