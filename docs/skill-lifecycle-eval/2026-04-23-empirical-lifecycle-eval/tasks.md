# Tasks — empirical skill lifecycle eval pilot
Created: 2026-04-23
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 Extend local eval runner with run mode and anchor-aware grading
  - AC: `tools/eval/scripts/run_standard_chain_local_eval.py --dry-run` remains compatible; `bash tests/test-standard-chain-local-eval-runner.sh` verifies `run_mode`, `expected_anchors`, `anchor_results`, `preference_anchor_summary`, and summary anchor fields.
  - Traces: Success criteria 1, 2; runner 扩展; 不变量
  - Depends: -
  - Complexity: moderate
- [x] T2 Add lifecycle review aggregation script
  - AC: `tests/test-skill-lifecycle-empirical-review.sh` creates fixture summaries and proves `tools/eval/scripts/update_lifecycle_review.py` calculates encoded preference fidelity, mixed capability uplift, keeps `decision: "optimize"`, and refuses unsupported/missing inputs with actionable errors.
  - Traces: Success criteria 3, 4; lifecycle 聚合器; 不变量
  - Depends: T1
  - Complexity: moderate
- [x] T3 Record pilot empirical evidence for product-manager and developer
  - AC: `shared/skills/product-manager/evals/lifecycle-review.json` and `shared/skills/developer/evals/lifecycle-review.json` include pilot empirical fields, summary refs, sample sizes, and retain `decision: "optimize"`; `bash tests/test-skill-lifecycle-empirical-review.sh` validates both review files.
  - Traces: Success criteria 4, 5; pilot evidence; 风险
  - Depends: T2
  - Complexity: moderate
- [x] T4 Wire validation and closeout evidence
  - AC: `tests/run-all.sh --quick` includes `tests/test-skill-lifecycle-empirical-review.sh`; small-chain task-plan consistency passes; targeted runner, lifecycle framework, lifecycle empirical, standard-chain eval, and whitespace checks pass with fresh output; `verify-change-report.md` records PASS evidence and empirical-run caveats.
  - Traces: Success criteria 5; 下游影响
  - Depends: T1, T2, T3
  - Complexity: moderate

## Definition of Done
All tasks checked = ready for verify-change.
