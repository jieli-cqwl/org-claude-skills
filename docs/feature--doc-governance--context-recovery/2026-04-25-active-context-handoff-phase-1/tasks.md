# Tasks — active-context-handoff-phase-1
Created: 2026-04-25
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 Bootstrap scope registry and ownership contracts
  - AC: `contracts/active-doc-scope.yaml` is version 2 with `context_contract_phase: bootstrap`; active entries use `management_status`, `entry_ref`, and `context_owner` while keeping bootstrap compatibility fields; `contracts/context-artifact-ownership.yaml` defines repo owners, artifact owners, update triggers, mechanical checks, and waiver approvers; the real pilot has a reachable `worklog.md`.
  - Traces: G1, G2, G4
  - Depends: -
  - Complexity: moderate
- [x] T2 Implement context contract validator with fixture coverage
  - AC: `tools/community/validate_context_contract.py` validates scope registry, worklog block fields, ref reachability, ownership contract, small-chain task/plan consistency, standard-chain active refs, archive exclusion, supporting metadata, and structured failure output; `tests/test-context-contract-validator.sh` proves positive and negative fixtures.
  - Traces: G3, G4, G5, G6
  - Depends: T1
  - Complexity: complex
- [x] T3 Implement recovery command and lifecycle helper
  - AC: `tools/community/recover_context.py` lists active candidates sorted by latest worklog, resolves exact `feature_path` and basename, returns fuzzy matches without auto-selecting, supports explicit archived recovery, emits fixed failure structures, and never scans unmanaged `docs/*`; `tools/community/update_active_doc_scope.py` updates phase/lifecycle fields through the shared contract; recovery and lifecycle tests pass.
  - Traces: G1, G2, G3, G6
  - Depends: T2
  - Complexity: complex
- [x] T4 Wire validator into contract runner, hook registry, and audit
  - AC: `tools/dev/validate-contracts.sh` and `tools/validate-contracts.sh` run the context validator; `shared/hooks/registry.json` renders a context-contract runtime hook through `tools/community/render_hook_registry.py`; `tools/dev/run-context-contract-audit.sh` reports long-blocked, expired waiver, supporting overuse, and legacy drift risks without modifying files; wiring and audit tests pass.
  - Traces: G5, G6
  - Depends: T2, T3
  - Complexity: moderate
- [x] T5 Sync docs, skill references, pilot worklog, and final proving commands
  - AC: README, small-chain contract, standard-chain contract, and in-scope skill references consistently describe scope registry, `management_status`, `handoff_status`, `context_owner`, `artifact_owner`, stage routing, and `canonical:` refs; pilot `worklog.md` points to current `tasks.md/plan.md`; all Phase 1 proving commands pass and `tasks.md` is fully checked.
  - Traces: G1, G2, G3, G4, G5, G6
  - Depends: T1, T2, T3, T4
  - Complexity: moderate

## Definition of Done
All tasks checked = ready for verify-change.
