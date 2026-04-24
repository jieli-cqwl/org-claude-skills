# Developer D9 Review

## Problem Statement

`developer` currently records `uplift = 0.0833` after Skill optimization. That is below the D9 retain line and below the lifecycle gate for capability uplift. The existing three evals are too easy for the without-skill baseline, so they cannot answer whether `developer` deserves to remain a standalone Skill.

This review adds harder evals that target standard-chain-specific obligations: per-AC TDD evidence indexing, strict file scope blocking, full regression failure handling, and canonical `developer-report.json` completeness.

## Goals And Success Criteria

1. Add at least four harder `developer` mixed eval cases that run in both `with_skill` and `without_skill` modes.
2. The harder eval set must cover `tdd_evidence_index`, `reviewable_anchor`, file-range conflict, regression-failure blocking, and report schema completeness.
3. Run only the harder eval set with real local eval execution and record zero infra failures.
4. Update `shared/skills/developer/evals/lifecycle-review.json` from the clean harder-eval summaries.
5. Record a D9 decision note: retain is blocked; if uplift remains below `0.5`, mark `developer` as a retire/merge candidate requiring human confirmation before any retirement operation.

## Scope

In scope:

- `shared/skills/developer/evals/evals.json`
- `shared/skills/developer/evals/lifecycle-review.json`
- `tests/test-developer-d9-review-evals.sh`
- `tests/run-all.sh`
- `tools/eval/results/developer-d9-review-20260424/`
- This small-chain document set and changelog entry.

Out of scope:

- Deleting, moving, or deprecating the `developer` Skill.
- Changing local eval runner scoring or grader prompts.
- Changing non-developer Skill evals.
- Promoting `developer` to retain.

## Design

The new eval cases intentionally stress behavior that generic engineering answers skip:

- `multi-ac-report-evidence-index`: requires one TDD evidence row per AC plus report anchors.
- `scope-conflict-shared-file`: requires hard file-range blocking.
- `regression-failure-blocks-completion`: requires full regression failure to block completion.
- `report-schema-missing-evidence-fields`: requires rejecting incomplete `developer-report.json`.

The lifecycle review remains evidence-driven. `decision` stays `optimize` unless a human confirms retirement. A `retire_candidate` block records the D9 consequence when measured uplift is below the `0.5` retire-candidate line.

## Verification

The proving chain is:

1. RED: `tests/test-developer-d9-review-evals.sh` fails before the new evals exist.
2. GREEN: the same test passes after evals are added.
3. Contract regression: standard-chain eval tests and lifecycle review tests pass.
4. Empirical: run the four harder evals in `with_skill` and `without_skill`.
5. Aggregation: update lifecycle review only when both summaries report `infra_failures = 0`.
6. Closeout: write review evidence, archive docs, run fresh verification, then commit and push `main`.
