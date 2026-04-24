# Tasks — skill optimization batch 1
Created: 2026-04-23
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 Add deterministic Skill optimization contract tests
  - AC: `bash tests/test-skill-optimization-contracts.sh` fails before Skill edits because the new PM and developer response-contract phrases are absent, then passes after the Skill edits.
  - Traces: Success criteria 3; Verification 1, 2
  - Depends: -
  - Complexity: simple
- [x] T2 Optimize product-manager and developer Skill contracts
  - AC: `shared/skills/product-manager/SKILL.md` contains explicit PM response-contract wording for UNIT closed-loop fields, Integration Context, dependency/exclusion traceability, AC examples, and Verification Plan; `shared/skills/developer/SKILL.md` contains explicit explanation-mode wording for canonical input gate, file-range gate, per-AC RED/GREEN, `developer-report.json`, `tdd_evidence_index`, `reviewable_anchor`, `task_scope`, self-testing, and `BLOCKED` handling.
  - Traces: Success criteria 1, 2, 3; Design
  - Depends: T1
  - Complexity: moderate
- [x] T3 Record optimization empirical evidence and lifecycle review updates
  - AC: real summaries exist under `tools/eval/results/skill-lifecycle-optimization-batch-1-20260423/`; each summary has `infra_failures = 0`; lifecycle reviews point at the optimization summaries, preserve `decision: "optimize"`, and record measured metrics.
  - Traces: Success criteria 1, 2, 4, 5; Verification 4, 5
  - Depends: T2
  - Complexity: moderate
- [x] T4 Close out, verify, archive, merge, and release worktree
  - AC: fresh proving commands pass; small-chain closeout files capture review and verification evidence; branch is committed, merged to `main`, pushed to `origin/main`, and the optimization worktree is released.
  - Traces: Success criteria 5; Verification 6
  - Depends: T1, T2, T3
  - Complexity: moderate

## Definition of Done
All tasks checked = ready for verify-change and branch closeout.
