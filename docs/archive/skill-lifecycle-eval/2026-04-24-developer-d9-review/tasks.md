# Tasks — developer D9 review
Created: 2026-04-24
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 Add RED contract for harder developer D9 evals
  - AC: `bash tests/test-developer-d9-review-evals.sh` fails before eval additions because the four required harder eval ids are absent.
  - Traces: Success criteria 1, 2; Verification 1
  - Depends: -
  - Complexity: simple
- [x] T2 Add harder developer eval cases
  - AC: `shared/skills/developer/evals/evals.json` contains the four required harder eval ids, each has `run_modes: ["with_skill", "without_skill"]`, and `bash tests/test-developer-d9-review-evals.sh` passes.
  - Traces: Success criteria 1, 2; Design
  - Depends: T1
  - Complexity: moderate
- [x] T3 Run harder empirical D9 review and update lifecycle evidence
  - AC: with-skill and without-skill summaries exist under `tools/eval/results/developer-d9-review-20260424/`, both have `infra_failures = 0`, and `shared/skills/developer/evals/lifecycle-review.json` records the measured harder-eval metrics plus retire/merge candidate evidence when uplift is below `0.5`.
  - Traces: Success criteria 3, 4, 5
  - Depends: T2
  - Complexity: moderate
- [x] T4 Verify, archive, commit, and push main
  - AC: fresh proving commands pass, docs are archived, changelog records the result, `main` is committed and pushed to `origin/main`.
  - Traces: Success criteria 5; Verification 6
  - Depends: T1, T2, T3
  - Complexity: moderate

## Definition of Done
All tasks checked = ready for commit and main push.
