# Tasks — empirical skill lifecycle eval batch 3
Created: 2026-04-23
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 Raise the empirical review gate to cover product-director and design
  - AC: `tests/test-skill-lifecycle-empirical-review.sh` first fails because `product-director` and `design` review files still lack empirical sample counts; after batch-3 evidence lands, the same test proves `product-director encoded_preference.sample_size >= 3`, `design capability_uplift.with_sample_size >= 3`, and `design capability_uplift.without_sample_size >= 3`.
  - Traces: Success criteria 1, 2, 3; 实现策略 1
  - Depends: -
  - Complexity: low
- [x] T2 Record batch-3 empirical evidence for product-director and design
  - AC: real summaries exist under `tools/eval/results/skill-lifecycle-empirical-batch-3-20260423/`; `product-director` contains 3 graded with-skill runs; `design` contains 3 graded with-skill runs and 3 graded without-skill runs; infra failures are surfaced and excluded from lifecycle updates.
  - Traces: Success criteria 1, 2, 5; 实现策略 2; 风险与处理
  - Depends: T1
  - Complexity: moderate
- [x] T3 Update lifecycle review files and batch-3 closeout documents
  - AC: `shared/skills/product-director/evals/lifecycle-review.json` and `shared/skills/design/evals/lifecycle-review.json` point at batch-3 summary refs, preserve `decision: "optimize"`, and record batch-3 sample sizes; verify/review/fix docs are written.
  - Traces: Success criteria 2, 4, 5; 实现策略 3
  - Depends: T2
  - Complexity: moderate
- [x] T4 Fresh verification, integration, and archive
  - AC: targeted lifecycle commands pass with fresh output; branch is committed, merged to `main`, pushed to `origin/main`, batch-3 worktree is released, and the verified batch-3 doc directory is archived with a changelog entry.
  - Traces: Success criteria 5; 不变量
  - Depends: T1, T2, T3
  - Complexity: moderate

## Definition of Done
All tasks checked = ready for verify-change and branch closeout.
