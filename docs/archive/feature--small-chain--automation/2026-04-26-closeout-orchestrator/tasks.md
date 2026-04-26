# Tasks — Small-Chain Closeout Automation
Created: 2026-04-26
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 Add closeout automation contract tests
  - AC: `tests/test-small-chain-closeout-automation.sh` exists, creates isolated fixtures, proves invalid closeout states fail closed, and initially fails because `tools/community/small_chain_closeout.py` does not exist.
  - Traces: G1 Mechanical closeout route; G2 PR auto-merge gate; G3 Archive gate
  - Depends: -
  - Complexity: moderate
- [x] T2 Implement deterministic closeout helper
  - AC: `tools/community/small_chain_closeout.py` supports `status`, `create-pr`, and `archive`; emits fixed `decision` output; uses existing task-plan consistency and active scope lifecycle helpers; passes T1 tests.
  - Traces: G1 Mechanical closeout route; G2 PR auto-merge gate; G3 Archive gate
  - Depends: T1
  - Complexity: complex
- [x] T3 Document closeout automation policy
  - AC: `README.md`, `contracts/small-chain.yaml`, and `contracts/superpowers-boundary.yaml` describe PR auto-merge as the automated integration policy and preserve archive-after-integration as a hard gate.
  - Traces: G4 Contract visibility
  - Depends: T2
  - Complexity: simple
- [x] T4 Run closeout proving commands and update worklog
  - AC: Fresh commands prove targeted automation behavior and existing small-chain/hook contracts still pass; `worklog.md` points to `tasks.md` / `plan.md` as the next executable state.
  - Traces: G5 No runtime regression
  - Depends: T1, T2, T3
  - Complexity: simple

## Definition of Done
All tasks checked = ready for verify-change.
