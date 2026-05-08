# Tasks — Standard Chain HTML Result Views
Created: 2026-05-07
Related plan: ./plan.md

## Acceptance Checklist
- [ ] T1 Result-view registry and manifest contract
  - AC: `bash tests/test-standard-chain-result-view-contract.sh` proves `shared/runtime/result-views.json` declares the five result views, `projection-manifest.schema.json` and template require `result_view_registry_digest`, catalog metadata can represent the result-view manifest set, and `phase-operational` is not allowed as a parallel active display contract after result-view cutover.
  - Traces: Goals 1, 2, 5, 6
  - Depends: -
  - Complexity: complex
- [ ] T2 Deterministic result-view renderer and validator
  - AC: `bash tests/test-standard-chain-result-view-renderer.sh` proves a golden standard-chain phase generates `result-index.html`, `product-result.html`, `design-result.html`, `execution-result.html`, `release-result.html` and matching manifests; every section is source-mapped; dangerous HTML is escaped; missing required pointers, unknown required enum values, source-ref drift, digest drift, and registry-digest drift fail closed.
  - Traces: Goals 1, 2, 4, 5, 6
  - Depends: T1
  - Complexity: complex
- [ ] T3 Replay, readiness, and fixture cutover
  - AC: `bash tests/test-standard-chain-result-view-replay.sh` and `bash tests/test-standard-chain-readiness-gate.sh` prove replay/readiness/phase validation iterate the configured result-view manifest set, golden fixtures contain the five result views, and the old `phase-operational` projection is either absent from active fixtures or marked legacy-only in tests that explicitly exercise backward compatibility.
  - Traces: Goals 1, 2, 6
  - Depends: T2
  - Complexity: complex
- [ ] T4 UX review report contract and validator
  - AC: `bash tests/test-result-view-ux-review-contract.sh` proves `views/result-ux-review.json` accepts only `PASS` or `BLOCK`, requires all five expected view ids, binds input manifest digests to generated manifests, rejects `BLOCKER` findings, rejects missing evidence discoverability, and is treated as review evidence rather than canonical runtime truth.
  - Traces: Goals 4, 5, 6
  - Depends: T2
  - Complexity: moderate
- [ ] T5 Standard-chain Markdown projection cutover
  - AC: `bash tests/test-standard-chain-result-view-cutover.sh`, `bash tests/test-skill-output-and-gate-contract.sh`, `bash tests/test-standard-chain-cutover.sh`, and `bash tests/test-standard-chain-skill-structure.sh` prove standard-chain skills, validators, readiness, replay, and tests no longer consume the listed `.md` projection templates; deleted or rehomed standalone display paths are outside the standard-chain active projection namespace.
  - Traces: Goals 2, 3
  - Depends: T1, T2, T3, T4
  - Complexity: complex
- [ ] T6 Route, regression, and context handoff
  - AC: `python3 tools/community/check_task_plan_consistency.py docs/feature--standard-chain--result-html-views/2026-05-07-result-views/tasks.md docs/feature--standard-chain--result-html-views/2026-05-07-result-views/plan.md`, `python3 tools/community/implementation_router.py --repo-root . --feature-path docs/feature--standard-chain--result-html-views --workset 2026-05-07-result-views --force-refresh`, `python3 tools/community/validate_context_contract.py --repo-root .`, `bash tools/validate-contracts.sh`, and all T1-T5 proving commands pass; `worklog.md` latest record points to `tasks.md` and `execution-routing-input.json`.
  - Traces: Goals 1, 2, 3, 4, 5, 6
  - Depends: T1, T2, T3, T4, T5
  - Complexity: moderate

## Contract-Grade Carryover
- C1 Current Vs Target maps to T1, T3, and T5.
- C2 Source Of Truth Matrix maps to T1, T2, T3, and T5.
- C3 Closed Vocabulary And Grammar maps to T1, T2, and T4.
- C4 Ownership And Waiver maps to T1, T2, T4, and T6.
- C5 Failure Contract maps to T2, T3, T4, and T5.
- C6 Implementation Surface maps to T1 through T6.
- C7 Proving Categories maps to every task AC and T6 final verification.
- C8 Existing Contract Diff maps to T1, T3, T5, and T6.

## Failure Matrix
- Missing required artifacts or inputs: T2 rejects missing canonical artifacts, missing manifests, missing required JSON pointers, and missing HTML files; T4 rejects missing UX review inputs.
- Unreadable or malformed artifacts: T2 mutates canonical JSON and manifest files into malformed JSON and expects fail-closed output.
- Stale hashes or stale state replay: T2 rejects rendered digest drift and `result_view_registry_digest` drift; T3 rejects replay oracle drift.
- Cross-artifact ID drift, unknown references, or grammar drift: T2 rejects source refs that do not resolve through active artifact registry and invalid result-view manifest ids.
- Ambiguous active state selection: T3 requires replay/readiness to iterate configured result views instead of inferring a single hard-coded active projection.
- High-risk or contract-grade surfaces: T1 and T3 cover schema, catalog, validator, readiness, replay, and manifest cutover.
- Second-run or retry behavior after a blocked state: T2 proves the renderer/validator passes after correcting the mutated required field or digest and still rejects the stale mutated output.
- Sub-agent review boundary: T4 rejects `result-ux-review.json` with `BLOCKER` findings and never treats review text as canonical runtime truth.
- Markdown projection residue: T5 fails when listed `.md` projection paths are still consumed by standard-chain runtime or tests.

## Definition of Done
All tasks checked = ready for verify-change.
