# Tasks — empirical skill lifecycle eval batch 2
Created: 2026-04-23
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 Raise the empirical review gate to batch-2 sample thresholds
  - AC: `tests/test-skill-lifecycle-empirical-review.sh` first fails on current repository review files because `product-manager` and `developer` still have sample size `1`; after batch-2 evidence lands, the same test passes and proves `product-manager encoded_preference.sample_size >= 3`, `developer capability_uplift.with_sample_size >= 3`, and `developer capability_uplift.without_sample_size >= 3`.
  - Traces: Success criteria 1, 2, 3; 实现策略 1
  - Depends: -
  - Complexity: low
- [x] T2 Record batch-2 empirical evidence for product-manager and developer
  - AC: real summaries exist under `tools/eval/results/skill-lifecycle-empirical-batch-2-20260423/`; `product-manager` contains 3 graded with-skill runs; `developer` contains 3 graded with-skill runs and 3 graded without-skill runs; any infra failure is surfaced and not written into lifecycle metrics.
  - Traces: Success criteria 1, 2, 5; 实现策略 2; 风险与处理
  - Depends: T1
  - Complexity: moderate
- [x] T3 Update lifecycle review files and batch-2 closeout documents
  - AC: `shared/skills/product-manager/evals/lifecycle-review.json` and `shared/skills/developer/evals/lifecycle-review.json` point at batch-2 summary refs, preserve `decision: "optimize"`, and record batch-2 sample sizes; `verify-change-report.md`, `code-review-result.json`, and `fix-result.json` capture the batch-2 outcome.
  - Traces: Success criteria 2, 4, 5; 实现策略 3
  - Depends: T2
  - Complexity: moderate
- [x] T4 Fresh verification, integration, and archive
  - AC: targeted lifecycle commands pass with fresh output; branch is committed, merged to `main`, pushed to `origin/main`, batch-2 worktree is released, and the verified batch-2 doc directory is archived with a changelog entry.
  - Traces: Success criteria 5; 不变量
  - Depends: T1, T2, T3
  - Complexity: moderate

## Definition of Done
All tasks checked = ready for verify-change and branch closeout.
