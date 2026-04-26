# Tasks — active-context-handoff-phase-1
Created: 2026-04-26
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 Bootstrap the scope registry contract and public contract wording.
  - AC: `contracts/active-doc-scope.yaml` exposes `version: 2`, `context_contract_phase: bootstrap`, target fields, and bootstrap compatibility rules; `README.md`, `contracts/small-chain.yaml`, and `contracts/standard-chain.yaml` describe the same scope registry, worklog, small-chain stage, and standard-chain `canonical:` ref vocabulary.
  - Verify: `bash tests/test-active-doc-scope-lifecycle.sh` includes and passes bootstrap contract cases; `bash tools/dev/validate-contracts.sh` includes the context contract validator entry once T5 wires it.
  - Traces: G1, G2, G3, G5, G6
  - Depends: -
  - Complexity: moderate
- [x] T2 Implement the context contract validator with closed-loop fixtures.
  - AC: `tools/community/validate_context_contract.py` validates registry entries, root `worklog.md` blocks, refs, active uniqueness, small-chain task/plan consistency, standard-chain active artifact refs, ownership contract shape, blocked/unblock rules, and deterministic failure output; `tests/fixtures/context-contract/` covers passing and failing cases.
  - Verify: `bash tests/test-context-contract-validator.sh` passes and proves failures for missing entry, missing fields, unreachable refs, duplicate active feature, illegal `canonical:` refs, small-chain task/plan drift, standard-chain active revision drift, blocked field omissions, and ownership contract omissions.
  - Traces: G1, G2, G3, G4, G5, G6
  - Depends: T1
  - Complexity: complex
- [x] T3 Implement recovery and lifecycle commands.
  - AC: `tools/community/recover_context.py` lists active candidates, resolves exact `feature_path` and basename inputs, reports fuzzy matches without choosing, supports archived recovery only through registry entries, and emits the fixed recovery or block structure; `tools/community/update_active_doc_scope.py` performs bootstrap/adopt/archive/phase updates without hand-edit drift.
  - Verify: `bash tests/test-context-recovery.sh` and `bash tests/test-active-doc-scope-lifecycle.sh` pass, including new-window recovery, archived lookup, active plus archived ambiguity, active miss with legacy basename, and lifecycle archive exclusion.
  - Traces: G1, G2, G3, G4, G5, G6
  - Depends: T1, T2
  - Complexity: complex
- [x] T4 Add the ownership contract and report-only audit path.
  - AC: `contracts/context-artifact-ownership.yaml` declares repo owners, artifact owners, update triggers, mechanical checks, and waiver namespace constraints; `tools/dev/run-context-contract-audit.sh` runs report-only audit for long-blocked, stale, expired waiver, supporting material, and legacy drift signals without modifying files.
  - Verify: `bash tests/test-context-contract-audit.sh` passes and proves the audit produces findings while `git diff --exit-code -- tests/fixtures/context-contract` stays clean after the audit command.
  - Traces: G4, G5, G6
  - Depends: T2
  - Complexity: moderate
- [x] T5 Wire the validator into contract and hook gates.
  - AC: `tools/dev/validate-contracts.sh`, `tools/validate-contracts.sh`, `shared/hooks/registry.json`, hook rendering, and runtime dispatch call the same context validator entry without duplicate rule implementations; failures are fail-closed in blocking gate paths and report-only in audit.
  - Verify: `bash tests/test-context-contract-validator.sh`, `bash tests/test-active-doc-scope-lifecycle.sh`, `bash tests/test-context-contract-audit.sh`, and the existing hook registry rendering tests pass; `bash tools/dev/validate-contracts.sh` fails on a fixture break and passes on the repository state.
  - Traces: G5, G6
  - Depends: T2, T4
  - Complexity: complex
- [x] T6 Sync consumers and register the real pilot.
  - AC: small-chain and standard-chain skill references use the scope registry, root `worklog.md`, `management_status`, `handoff_status`, `context_owner`, and `canonical:` active ref vocabulary; the real `docs/feature--doc-governance--context-recovery` pilot is registered with target fields plus bootstrap compatibility fields, and `worklog.md` points to this `tasks.md` and `plan.md` after plan generation.
  - Verify: `bash tests/test-context-recovery.sh docs/feature--doc-governance--context-recovery` or the repository equivalent proves the real pilot recovers to `state_ref` and `next_ref`; `bash tests/run-all.sh --quick --profile` passes after implementation.
  - Traces: G1, G2, G3, G4, G5, G6
  - Depends: T1, T2, T3, T5
  - Complexity: moderate

## Definition of Done
All tasks checked = ready for verify-change.
