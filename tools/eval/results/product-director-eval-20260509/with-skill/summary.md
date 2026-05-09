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

## Optimization Findings
- 未显式覆盖 locked_field_digest。 -> 补一句：PM 不得直接修改 locked_fields 或 locked_field_digest，必须由 product-director 重新确认后生成/更新。
- 未区分文案润色与冻结口径变化。 -> 补一句：若只是术语、语病、格式等不改变 Director 冻结口径的润色，PM 可继续；一旦改变 Phase、范围、目标、约束等基线含义，必须回 Director。
