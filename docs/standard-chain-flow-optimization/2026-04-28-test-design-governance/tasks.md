# Tasks — Test Design Governance
Created: 2026-04-28
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 Contract inventory and schema/template target
  - AC: `bash tests/test-test-design-governance-contract.sh` proves `test-cases.schema.json` and `test-cases.template.json` carry `test_analysis`, product refs, design refs, traceability, closed gap vocabulary, executable case fields, QA handoff fields, and cross-UNIT obligations.
  - Traces: S1 Role Boundary, S2 Product-First Traceability, S3 Executable Test Contract, S4 Typed Gaps, S5 Mechanical Enforcement
  - Depends: -
  - Complexity: complex
- [x] T2 Semantic validator for refs, gaps, and cross-UNIT obligations
  - AC: `bash tests/test-test-design-canonical-rules.sh` proves valid product/design refs resolve, unresolved refs fail closed, shallow cases fail, unknown/unowned gaps fail, blocking gaps stop completion, and invalid cross-UNIT composition rows fail.
  - Traces: S2 Product-First Traceability, S3 Executable Test Contract, S4 Typed Gaps, S5 Mechanical Enforcement
  - Depends: T1
  - Complexity: complex
- [x] T3 Completion gate fail-closed hardening
  - AC: `bash tests/test-test-design-completion-gate.sh` proves the test-design completion gate rejects missing `test_analysis`, missing product refs, missing executable assertions, malformed QA obligations, unresolved source refs, unknown gap types, and invalid cross-UNIT obligations.
  - Traces: S3 Executable Test Contract, S4 Typed Gaps, S5 Mechanical Enforcement, S6 Standard Chain Boundaries
  - Depends: T1, T2
  - Complexity: complex
- [x] T4 Active fixtures and phase validation cutover
  - AC: `python3 tools/community/validate_standard_chain_phase.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1 --catalog shared/runtime/standard-chain-catalog.json` passes after active fixtures are upgraded, and the negative probes from T2/T3 prove old shallow artifacts are rejected.
  - Traces: S2 Product-First Traceability, S3 Executable Test Contract, S5 Mechanical Enforcement
  - Depends: T1, T2, T3
  - Complexity: complex
- [x] T5 Skill SOP, projection, reviewer, and downstream consumer alignment
  - AC: `bash tests/test-design-skill-governance-redesign.sh` and `bash tests/test-standard-chain-cutover.sh` prove `test-design` describes the test analyst role, product-first inputs, seven-state SOP, typed gaps, QA obligation boundary, reviewer prompts, projection vocabulary, and downstream consumer expectations without changing QA release recommendation or delivery signoff authority.
  - Traces: S1 Role Boundary, S2 Product-First Traceability, S4 Typed Gaps, S6 Standard Chain Boundaries
  - Depends: T1, T2, T3, T4
  - Complexity: complex
- [x] T6 Behavior eval and effectiveness evidence upgrade
  - AC: `bash tests/test-standard-chain-skill-evals.sh` and `bash tests/test-skill-effectiveness-eval-framework.sh` prove `shared/skills/test-design/evals/evals.json` covers normal UNIT design, product ambiguity, design gap, scope drift, trace conflict, testability gap, browser-required handoff, and cross-UNIT composition scenarios with anchors matching the redesigned role.
  - Traces: S1 Role Boundary, S2 Product-First Traceability, S4 Typed Gaps, S5 Mechanical Enforcement
  - Depends: T5
  - Complexity: moderate
- [x] T7 Contract-grade design producer/consumer ownership guard
  - AC: `bash tests/test-contract-grade-design-preflight.sh` proves `brainstorming` owns `design.md` C1-C8 production checks, `writing-plans` carries approved preflight decisions into tasks and plans, and `Skill质量标准.md` remains focused on artifact-contract quality rather than design-document policy.
  - Traces: S5 Mechanical Enforcement, S6 Standard Chain Boundaries
  - Depends: -
  - Complexity: moderate
- [x] T8 Final route, context, and targeted verification
  - AC: `python3 tools/community/check_task_plan_consistency.py docs/standard-chain-flow-optimization/2026-04-28-test-design-governance/tasks.md docs/standard-chain-flow-optimization/2026-04-28-test-design-governance/plan.md`, `python3 tools/community/implementation_router.py --repo-root . --feature-path docs/standard-chain-flow-optimization --workset 2026-04-28-test-design-governance --force-refresh`, `python3 tools/community/validate_context_contract.py --repo-root .`, and all T1-T7 proving commands pass.
  - Traces: S1 Role Boundary, S2 Product-First Traceability, S3 Executable Test Contract, S4 Typed Gaps, S5 Mechanical Enforcement, S6 Standard Chain Boundaries
  - Depends: T1, T2, T3, T4, T5, T6, T7
  - Complexity: moderate

## Contract-Grade Carryover
- C1 Current Vs Target maps to T1, T4, and T8.
- C2 Source Of Truth Matrix maps to T2, T5, and T7.
- C3 Closed Vocabulary And Grammar maps to T1, T2, and T3.
- C4 Ownership And Waiver maps to T2, T5, and T7.
- C5 Failure Contract maps to T2, T3, and T8.
- C6 Implementation Surface maps to T1 through T7 in contract-first order.
- C7 Proving Categories maps to every task AC and T8 final verification.
- C8 Existing Contract Diff maps to T5, T7, and T8.

## Failure Matrix
- Missing required artifacts or inputs: T3 rejects missing canonical inputs and T8 validates context handoff.
- Unreadable or malformed artifacts: T2 schema/rule tests and T3 gate tests reject malformed JSON and malformed rows.
- Cross-artifact ID drift and unknown references: T2 rejects unresolved product/design refs and unknown route owners.
- Ambiguous active state selection: T8 validates active scope and routes this workset explicitly.
- High-risk contract-grade surfaces: `execution-routing-input.json` requests serial routing because schema, validators, hooks, skills, fixtures, and tests are contract-grade surfaces.
- Retry after blocked state: T3 proves the gate remains blocking until the owning artifact is corrected; T8 refreshes the route after plan artifacts are stable.

## Definition of Done
All tasks checked = ready for verify-change.
