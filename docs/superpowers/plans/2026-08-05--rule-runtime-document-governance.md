# Rule Runtime Document Governance Implementation Plan

**Goal:** Separate active machine contracts, test fixtures, and historical rollout evidence so tests do not revive obsolete project documents.

**Architecture:** Give the evaluator a stable contract under `tools/eval/contracts`, move test-only artifacts under `tests/fixtures`, preserve only referenced historical evidence, and mark old design decisions as superseded without rewriting history.

**Tech Stack:** JSON contracts, Markdown governance records, Python/shell path consumers.

---

### Task 1: Establish the active contract owner

**Files:**
- Create: `tools/eval/contracts/rule-runtime-eval.json`
- Modify: evaluator defaults and tests that consume the active contract

1. Copy only active runtime sources, scene ownership, case packs, and diagnostic profiles.
2. Point the evaluator and its tests at the new owner.
3. Keep rollout promotion records out of the execution contract.

### Task 2: Move fixtures and retire false active documents

**Files:**
- Create: `tests/fixtures/rule-runtime-team-readiness/` as needed
- Modify: `tests/test-rule-runtime-team-readiness-pack.sh`
- Modify/Delete: unused files under `docs/rule-runtime--team-readiness/`

1. Inventory inbound references before every move or deletion.
2. Move test-only samples to fixtures and update consumers atomically.
3. Delete unreferenced obsolete records under the repository governance rule; do not create an informal archive.

### Task 3: Preserve decision provenance

**Files:**
- Modify: `docs/superpowers/specs/2026-07-29--rule-runtime-effectiveness--design.md`
- Modify: `docs/superpowers/plans/2026-07-29--rule-runtime-effectiveness.md`
- Create: correction design if required by the governance checker

1. Mark the prior design and plan as superseded where their ownership or scope changed.
2. Link to the correction plans and current contract owner.
3. Run reference reachability, targeted document tests, installation dry-run, and quick regression.
