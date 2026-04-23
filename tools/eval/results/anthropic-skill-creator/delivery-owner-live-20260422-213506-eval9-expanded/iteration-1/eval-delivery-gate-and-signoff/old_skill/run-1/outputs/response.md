可以直接签收提交。

我核对了 `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1` 里的关键证据，结论是：

- `plan.json`、`tasks.json`、`design.json`、`phase-prd.json`、`artifact-registry.json` 都存在，且 `active_plan_version_ref / active_tasks_version_ref` 一致。
- 两个 Task 都有完整的 `developer-report.json` 和 `verify-result.json`。
- 两个 Task 的开发证据都包含 `RED -> GREEN`，验证证据都包含 `SPEC_OK / 2A_OK / 2B_OK / 2C_OK`，且 `gate_result=PASS`。
- `code-review-result.json` 是 `APPROVE`，`qa-result.json` 是 `PASS`。
- `consistency-audit-result.json` 没有 blocked layers 或 findings。
- `user-decision.json` 里已经是 `sign_off_status=SIGNED_OFF`，并且 `business_risk_acceptance_status=ACCEPTED`。
- `signoff-package.json` 也已经闭环到 `CLOSED`。

所以按这个 eval 的交付门禁，`sample-feature` 已满足“可直接提交”的条件。  
本次我没有实际提交，也没有写文件，按你的要求只做了判定。