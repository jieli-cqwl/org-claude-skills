# Standard-chain Manual Content Readiness Evaluation Approval Record

## Approval Event

- Status: `APPROVED`
- Approved by: business owner in the current Codex task
- Approved at: `2026-07-14T07:21:01-07:00`
- Exact approval text: `批准设计`
- Source: the user message immediately following delivery of design commit `293f624455eb9570f9426b457fadfbb946351049`
- Design path: `docs/superpowers/specs/2026-07-14--standard-chain-manual-content-readiness-evaluation--design.md`
- Approved design commit: `293f624455eb9570f9426b457fadfbb946351049`
- Approved design blob: `adf392c35d01fd1d7fa9013de2e8682aecbcced9`

This record captures an approval event that already occurred. It does not infer approval from repository content and must not be rewritten to represent a later design revision.

## Approved Capability IDs

- `SC-CAP-PD-001`
- `SC-CAP-PM-001`
- `SC-CAP-DES-001`
- `SC-CAP-TD-001`
- `SC-CAP-TL-001`
- `SC-CAP-DO-001`

Each role's formal alignment must cite this record and the approved design lines defining its capability. No additional target capability may be treated as user-confirmed without a new approval event.

## Approved Business Oracle Atom IDs

- `QFT-INV-001`
- `QFT-INV-002`
- `QFT-INV-003`
- `QFT-INV-004`
- `QFT-INV-005`
- `QFT-INV-006`
- `QFT-INV-007`
- `QFT-INV-008`

The approved meaning, observable assertion, scope, exclusions, and historical-support boundary for each atom are the definitions in the approved design blob. Historical code and tests remain support evidence, not independent business authority.

## Approved Scope And Boundaries

- The first run is case-bounded to `QFT-QMI-PC-001`.
- The primary chain is `product-director -> product-manager -> design -> test-design -> tech-lead -> delivery-owner`.
- The first run may produce `CASE_REPLAY_PASS`; it cannot issue unscoped `READY_FOR_BEHAVIOR_EVAL`, team-ready, production-ready, or full-chain-ready claims.
- A broader content-coverage gate must pass before formal behavior evaluation is designed.
- Product and technical design remain human-Agent co-creation stages; the business owner retains business truth, value trade-off, external-constraint, risk-acceptance, and baseline-change authority.
- Historical implementation is comparison evidence, not a mandatory design to reproduce.
- Evaluation must not modify target Skills, active standard-chain scope or state, `qft-tenants` source, or real delivery commits.
- Evaluation mechanics are delegated to the primary agent. The business owner is interrupted only for an unresolved business truth, material value trade-off, or risk-acceptance decision.

## Confirmation Evidence Use

This file is the single approval-event source for the first run. The evaluation workspace may store a reference to it but must not duplicate or reinterpret the approval text.

If the approved design, any approved capability, or any Oracle atom changes materially, this approval record becomes stale for the affected scope. The changed design must be presented to the user and a new immutable approval event must be recorded before affected formal audits or replay continue.
