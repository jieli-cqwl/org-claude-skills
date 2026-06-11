状态卡
- current_stage: DO-S8b
- status: BLOCKED
- control_action: PAUSE_FOR_USER
- blocker_id: target-change
- blocker_owner: product-manager
- blocker_basis_refs:
  - signoff-package.json
  - runtime_evidence_matrix
  - user reply in DO-S8b
- resume_stage: DO-S1
- next_action: 先按 AC 变更重基线，再重新消费 fresh evidence
- resume_condition: 新的 AC 基线、对应验证证据、再生成的 signoff-package.json 全部完成后，才能回到用户授权/提交分支

target-change.json 投影
- changed_target_type: AC
- affected_refs:
  - AC-3
  - current signoff-package.json
  - runtime_evidence_matrix
  - developer-report
  - verify-result
  - code-review-result
  - qa-result
  - consistency-audit-result
- invalidates_refs:
  - current signoff baseline
  - 现有 AC-3 相关验收判断
  - 当前 signoff-package.json
  - 依赖旧 AC-3 的全部 runtime evidence 关联结论
- superseded_evidence_refs:
  - developer-report
  - verify-result
  - code-review-result
  - qa-result
  - consistency-audit-result
- rebaseline_required: true
- rebaseline_owner: product-manager
- required_fresh_proof_after_rebaseline:
  - 重新冻结后的 brief
  - phase-prd
  - unit-definition
  - design
  - test-cases
  - plan
  - tasks
  - developer-report
  - verify-result
  - code-review-result
  - qa-result
  - consistency-audit-result

结论
- 这不是“可以直接提交”的状态。
- 用户已经改变了验收标准，属于 `AC` 变更，不是提交授权。
- 现有 signoff package 和 runtime evidence matrix 只能视为旧基线，必须作废并重基线。
- 下一步应回到 `product-manager` 重新冻结 AC-3，再重新跑后续证据链。

阻断原因
- 旧 AC-3 只验收“导出明细行”。
- 新 AC-3 要求“导出报表必须包含按门店分组的小计”。
- 这会改变验收逻辑、测试断言和最终 signoff 结论，因此不能写 `user-decision.json`，也不能进入 `/commit`。

如果你要我继续，我下一步应按这个变更输出完整的重基线回流包，而不是提交包。