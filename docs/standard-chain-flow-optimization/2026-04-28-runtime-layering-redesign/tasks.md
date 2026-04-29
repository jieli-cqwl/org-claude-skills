# Tasks — Runtime Layering Redesign
Created: 2026-04-28
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 Runtime layering standard and migration audit contract
  - Traces: 读对, 信对, 做对, 停对, 证对
  - Depends: -
  - Complexity: moderate
- [x] T2 Developer report failure and fresh-proof contract
  - AC: `bash tests/test-developer-runtime-proof-contract.sh` and `bash tests/test-developer-contract-alignment.sh` prove `developer-report.schema.json`, `developer-report.template.json`, developer-report fixtures, and existing developer gate tests require the fixed `failure_contract` object for blocked or partial runtime outcomes, use closed status/failure/owner vocabularies, reject command strings without current output/log/test evidence, and accept a report only when fresh proof is backed by current reviewable evidence.
  - Traces: 停对, 证对
  - Depends: T1
  - Complexity: complex
- [x] T3 Developer deterministic validator and failure matrix
  - AC: `bash tests/test-developer-runtime-failure-matrix.sh` proves the developer runtime validator and completion gate fail closed for missing input, unreadable or malformed artifacts, ambiguous scope, unresolved refs, owner mismatch, schema failure, gate failure, out-of-scope changes, stale state replay, and fresh proof authenticity gaps; the same test proves a corrected retry passes without using archive/history or projection as runtime truth.
  - Traces: 信对, 做对, 停对, 证对
  - Depends: T2
  - Complexity: complex
- [x] T4 Developer Skill runtime layering refactor
  - AC: `bash tests/test-developer-contract-alignment.sh` proves `shared/skills/developer/SKILL.md` keeps hard gates, inputs/outputs, stop/routing behavior, completion boundary, and reference trigger conditions in the main runtime path; developer references contain methodology only, no hidden unconditional MUST or runtime truth; the projection remains display-only.
  - Traces: 读对, 信对, 做对, 停对
  - Depends: T1, T2, T3
  - Complexity: complex
- [x] T5 Developer eval and lifecycle evidence upgrade
  - AC: `bash tests/test-developer-process-compliance-contract.sh` and `bash tests/test-standard-chain-skill-evals.sh` prove developer evals cover triggered and untriggered references, missing input, unresolved refs, owner mismatch, out-of-scope changes, stale replay, and fresh proof gaps, and that lifecycle evidence points to the runtime-layering verification commands instead of narrative confidence.
  - Traces: 读对, 信对, 停对, 证对
  - Depends: T4
  - Complexity: moderate
- [x] T6 Route, regression, and context closeout
  - AC: `python3 tools/community/check_task_plan_consistency.py docs/standard-chain-flow-optimization/2026-04-28-runtime-layering-redesign/tasks.md docs/standard-chain-flow-optimization/2026-04-28-runtime-layering-redesign/plan.md`, `python3 tools/community/implementation_router.py --repo-root . --feature-path docs/standard-chain-flow-optimization --workset 2026-04-28-runtime-layering-redesign --force-refresh`, `python3 tools/community/validate_context_contract.py --repo-root .`, `bash tools/dev/validate-contracts.sh`, `bash tests/test-standard-chain-login-homepage-pilot.sh`, and all T1-T5 proving commands pass without changing `contracts/active-doc-scope.yaml` or `test-design` mainline files.
  - Traces: 读对, 信对, 做对, 停对, 证对
  - Depends: T1, T2, T3, T4, T5
  - Complexity: moderate

## Contract-Grade Carryover
- C1 Current Vs Target maps to T1, T3, and T6.
- C2 Source Of Truth Matrix maps to T1, T3, and T4.
- C3 Closed Vocabulary And Grammar maps to T2 and T3.
- C4 Ownership And Waiver maps to T1, T3, and T4.
- C5 Failure Contract maps to T2 and T3.
- C6 Implementation Surface maps to T1 through T6, with `test-design` mainline and `contracts/active-doc-scope.yaml` excluded.
- C7 Proving Categories maps to every task AC and T6 final verification.
- C8 Existing Contract Diff maps to T1, T4, and T6.

## Failure Matrix
- Missing required artifacts or inputs: T2 requires `failure_contract`; T3 rejects missing `work_dir`, `design.json`, `tasks.json`, AC, file range, and evidence fields.
- Unreadable or malformed artifacts: T3 mutates developer fixtures into invalid JSON and unreadable targets and expects fail-closed output.
- Stale hashes or stale state replay: T3 rejects historical green evidence and stale `active_plan_version_ref` / `active_tasks_version_ref`; T6 refreshes `execution-route.json` after plan artifacts stabilize.
- Cross-artifact ID drift, unknown references, or grammar drift: T3 rejects unresolved `design_refs`, missing AC refs, invalid artifact refs, and owner mismatch.
- Ambiguous active state selection: T3 blocks ambiguous developer task scope; T6 routes this workset explicitly and does not infer from `contracts/active-doc-scope.yaml`.
- High-risk or contract-grade surfaces: `execution-routing-input.json` requests serial routing because schemas, gates, skill runtime text, evals, and shared references are contract-grade.
- Second-run or retry behavior after a blocked state: T3 proves the same validator passes after the owning input is corrected and still rejects replayed historical evidence.

## Definition of Done
All tasks checked = ready for verify-change.
