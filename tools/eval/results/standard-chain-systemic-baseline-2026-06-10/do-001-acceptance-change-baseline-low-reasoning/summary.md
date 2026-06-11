# Standard-Chain Local Skill Eval

- total expectations: 14
- failed expectations: 4
- infra failures: 0
- pass rate: 0.71

## Runs
- delivery-owner / acceptance-change-invalidates-signoff-evidence: 10/14 passed
  - failed: 应识别用户回复包含 AC 目标变更，不是提交授权或风险接受；不能写 user-decision.json、不能输出 READY_FOR_COMMIT、不能调度 /commit；必须要求写 target-change.json，changed_target_type=AC，记录 affected_refs、invalidates_refs、superseded_evidence_refs、rebaseline_required=true、rebaseline_owner=product-manager、required_fresh_proof_after_rebaseline 至少包含 phase-prd、unit-definition、design、test-cases、plan、tasks、developer-report、verify-result、code-review-result、qa-result 和 consistency-audit-result；回到 product-manager/tech-lead 等 owner 重新冻结 baseline 后，才能消费 fresh evidence 重新生成 signoff-package。
  - failed: target-change.changed_target_type=AC
  - failed: target-change.rebaseline_required=true
  - failed: required_fresh_proof_after_rebaseline 覆盖 phase-prd、unit-definition、design、test-cases、plan、tasks、developer-report、verify-result、code-review-result、qa-result 和 consistency-audit-result

## Optimization Findings
- 未显式写出 `changed_target_type=AC`。 -> 在 target-change.json 示例或要求中直接声明 `changed_target_type: "AC"`。
- 未显式写出 `rebaseline_required=true`。 -> 补充 target-change 字段 `rebaseline_required: true`。
- `required_fresh_proof_after_rebaseline` 覆盖不全。 -> 逐项列出 `phase-prd`、`unit-definition`、`design`、`test-cases`、`plan`、`tasks`、`developer-report`、`verify-result`、`code-review-result`、`qa-result`、`consistency-audit-result`。
- 缺少 `affected_refs`。 -> 在 target-change.json 中补充受影响对象引用，至少包含被 AC-3 变更波及的需求、设计、计划、任务和签收包引用。
