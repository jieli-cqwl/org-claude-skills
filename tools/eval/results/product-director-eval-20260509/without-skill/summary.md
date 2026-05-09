# Standard-Chain Local Skill Eval

- total expectations: 24
- failed expectations: 2
- infra failures: 0
- pass rate: 0.92

## Runs
- product-director / director-baseline-no-prd: 6/6 passed
- product-director / phase-boundary-drift-routes-back: 2/4 passed
  - failed: 禁止 product-manager 直接改写 locked_fields 或 locked_field_digest
  - failed: 区分不改变冻结口径的文字润色与基线变更
- product-director / clear-goal-default-judgment: 6/6 passed
- product-director / legacy-brief-blocks-handoff: 4/4 passed
- product-director / phase-timebox-enforced: 4/4 passed
