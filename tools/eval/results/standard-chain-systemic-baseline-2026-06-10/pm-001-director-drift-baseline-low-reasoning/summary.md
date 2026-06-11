# Standard-Chain Local Skill Eval

- total expectations: 3
- failed expectations: 0
- infra failures: 0
- pass rate: 1.00

## Runs
- product-manager / director-lock-drift-after-handoff: 3/3 passed

## Optimization Findings
- 如果要更稳，可直接写出“`reviewed_bundle_digest` 与既有 reviewer verdicts 失效”。 -> 在 impacted_artifacts 或 blocking_fact 中补一句：`brief/phase-prd/UNIT 任一改动都会使 reviewed_bundle_digest 和既有 reviewer verdicts 过期，必须回到 Review digest 后重审。`
- 未显式点名 `locked_fields` / `locked_field_digest`。 -> 补一句：`Director locked_fields 和 locked_field_digest 保持上游锁定值；当前只登记漂移，不改锁定值。`
