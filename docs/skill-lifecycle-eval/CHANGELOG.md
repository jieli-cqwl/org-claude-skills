# Skill Lifecycle Eval Changelog

## 2026-04-23 - Capability Eval Framework

- Added a D9 existence-rationale framework so standard-chain skills declare `eval-type`, carry lifecycle eval scenarios, and maintain evidence-backed `retain` / `optimize` / `retire` review records.
- Seeded lifecycle metadata for the 12 standard-chain skills and wired deterministic validation into `tests/run-all.sh --quick`.
- Archived the verified small-chain package at `docs/archive/skill-lifecycle-eval/2026-04-23-capability-eval-framework/`.

## 2026-04-23 - Empirical Eval Batch 2

- Raised the repository empirical-review gate from pilot sample size to batch-2 sample size, requiring `product-manager` with-skill evidence and `developer` with/without evidence to each reach 3 graded evals.
- Recorded batch-2 lifecycle review evidence for `product-manager` and `developer`, keeping `decision = optimize` while updating sample sizes, summary refs, and pilot empirical metrics.
- Captured timeout recovery for `developer/happy-path-canonical-task` and preserved the resulting empirical summaries under `tools/eval/results/skill-lifecycle-empirical-batch-2-20260423/`.

## 2026-04-23 - Empirical Eval Batch 3

- Raised the repository empirical-review gate again so `product-director` and `design` now require batch-level empirical samples before their review files pass.
- Recorded batch-3 lifecycle review evidence for `product-director` and `design`, keeping `decision = optimize` while updating sample sizes, summary refs, and pilot empirical metrics.
- Captured the first positive mixed-skill uplift in this lifecycle series: `design` recorded `with_avg = 1.0`, `without_avg = 0.9167`, `uplift = 0.0833`.

## 2026-04-23 - Skill Optimization Batch 1

- Optimized `product-manager` response contracts so blocking and canonical-review answers preserve UNIT closed-loop and AC/exclusion traceability anchors.
- Optimized `developer` explanation-mode contracts so with-skill answers expose canonical gates, per-AC RED/GREEN evidence, report skeleton fields, and BLOCKED behavior.
- Recorded optimization evidence with `product-manager` fidelity improving from `0.3333` to `1.0`, and `developer` uplift improving from `0.0` to `0.0833`.
- Archived the verified small-chain package at `docs/archive/skill-lifecycle-eval/2026-04-23-skill-optimization-batch-1/`.
