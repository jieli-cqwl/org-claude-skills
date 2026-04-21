# Standard-Chain Local Skill Eval

- total expectations: 60
- failed expectations: 5
- infra failures: 0
- pass rate: 0.92

## Runs
- product-director / director-baseline-no-prd: 4/4 passed
- product-director / phase-boundary-drift-routes-back: 4/4 passed
- product-director / legacy-brief-blocks-handoff: 4/4 passed
- product-manager / handoff-validation-first: 4/4 passed
- product-manager / director-lock-drift-blocking: 4/4 passed
- product-manager / canonical-review-required: 4/4 passed
- developer / happy-path-canonical-task: 3/4 passed
  - failed: 输出 developer-report.json 并包含 tdd_evidence_index 与 reviewable_anchor
- developer / ambiguous-missing-design: 4/4 passed
- developer / interface-tweak-out-of-scope: 4/4 passed
- qa / missing-test-cases-blocks-qa: 4/4 passed
- qa / browser-required-real-e2e: 4/4 passed
- qa / release-recommendation-with-risk: 4/4 passed
- delivery-owner / kickoff-missing-baseline-blocks: 4/4 passed
- delivery-owner / dispatch-with-canonical-state: 0/4 passed
  - failed: 读取 canonical baseline 和 artifact registry
  - failed: 按 plan 批次与并行策略派发
  - failed: 维护 delivery-state.json
  - failed: 每个 Task 要求 developer-report、verify-result 和 fresh proving command
- delivery-owner / phase3-gate-and-signoff: 4/4 passed

## Optimization Findings
- “推荐先选 A 或 B”略带引导性，可能影响根问题共创的中立性。 -> 保留选项即可，或改为“如果不确定，可先选最接近当前最大延迟来源的一项”。
- developer-report.json 关键字段遗漏 -> 在报告字段列表中明确写出 `tdd_evidence_index` 和 `reviewable_anchor`，并说明它们分别关联 RED/GREEN/REFACTOR 证据索引和可审查锚点。
