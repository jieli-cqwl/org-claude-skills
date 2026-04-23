可以签收，且不执行实际提交或写文件。

我核过这组 `sample-feature` 的关键证据，当前是“可提交/可签收”状态：

- 基线齐全：[`brief.json`](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/brief.json)、[`phase-1/phase-prd.json`](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/phase-prd.json)、[`phase-1/design.json`](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json)、[`phase-1/plan.json`](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/plan.json)、[`phase-1/tasks.json`](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/tasks.json)、[`phase-1/unit-1/test-cases.json`](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/test-cases.json)、[`phase-1/artifact-registry.json`](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/artifact-registry.json)
- Task 级证据存在且闭环：`T1`、`T2` 都有 [`developer-report.json`](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json)、[`verify-result.json`](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/verify-result.json) 以及对应的 `T2` 文件，且 `verify-result.json` 都是 `PASS`
- 固定门禁已过：[`code-review-result.json`](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/code-review-result.json) 为 `PASS`，[`qa-result.json`](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/qa-result.json) 的 `QA_A` 到 `QA_D` 都是 `PASS`
- 签收已完成：[`signoff-package.json`](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/signoff-package.json) 里 `sign_off_status=SIGNED_OFF`、`business_risk_acceptance_status=ACCEPTED`
- 用户确认也已存在：[`user-decision.json`](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/user-decision.json) 为 `APPROVE`，且同样是 `SIGNED_OFF`

结论：
- `control_action`: `CONTINUE`
- 交付状态：`READY_FOR_SUBMIT`
- 本次 eval 不做真实提交，不写入任何文件