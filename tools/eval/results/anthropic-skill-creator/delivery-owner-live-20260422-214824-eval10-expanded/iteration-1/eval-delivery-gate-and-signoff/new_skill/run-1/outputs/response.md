门禁结论：通过，当前 `sample-feature/phase-1` 的 canonical baseline、任务证据、`code-review-result.json`、`qa-result.json`、`signoff-package.json` 和 `user-decision.json` 都已就绪，按证据口径可以进入提交前状态。  
non-waivable REVIEW_A / REVIEW_B / REVIEW_C / QA_A：已消费，`code-review-result.json` 为 `PASS`，`qa-result.json` 中 `QA_A~QA_D` 全部 `PASS`。  
signoff-package.json：已消费 `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/signoff-package.json`；`user-decision.json` 也已消费，`sign_off_status=SIGNED_OFF`，`business_risk_acceptance_status=ACCEPTED`。  
提交边界：本次不实际提交、不写文件；按当前证据，若进入真实提交流程，可视为满足提交前置条件。

我核到的关键文件：
- [brief.json](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/brief.json)
- [plan.json](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/plan.json)
- [tasks.json](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/tasks.json)
- [design.json](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json)
- [test-cases.json](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/test-cases.json)
- [artifact-registry.json](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/artifact-registry.json)
- [developer-report T1](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json)
- [verify-result T1](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/verify-result.json)
- [developer-report T2](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T2/developer-report.json)
- [verify-result T2](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T2/verify-result.json)
- [review](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/code-review-result.json)
- [qa](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/qa-result.json)
- [user-decision](tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/user-decision.json)

如果你要，我可以继续按这个 eval 产出一份更像“交付裁决单”的简版结论。