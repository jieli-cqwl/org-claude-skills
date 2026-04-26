# Active Context Handoff Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Build the Phase 1 active-context handoff protocol so a fresh window can recover managed work from scope registry to worklog to real artifacts, with validator, hook, audit, and tests proving the contract.

**Architecture:** Keep the scope registry narrow, keep `worklog.md` as a navigation entry, and put mechanical enforcement in one shared context validator used by recovery, hooks, audit, and `validate-contracts`. Reuse existing runtime helpers for YAML loading, canonical artifact ref parsing, and small-chain task/plan consistency.

**Tech Stack:** Bash contract tests, Python 3 CLI tools, repository-local YAML/JSON/Markdown artifacts, existing `tools/community/runtime_yaml.py`, existing `tools/community/canonical_ref_resolver.py`, existing `tools/community/check_task_plan_consistency.py`.

---

### Task 1: Bootstrap Scope Registry And Ownership Contracts [T1]

Context: Cutover Order step 1 must make target fields visible without breaking bootstrap compatibility. The pilot is still a design workset until registry and validator exist.

Files:
- Modify: `contracts/active-doc-scope.yaml`
- Create: `contracts/context-artifact-ownership.yaml`
- Modify: `docs/feature--doc-governance--context-recovery/worklog.md`
- Test: `tests/test-active-doc-scope-lifecycle.sh`

1. [T1] Write lifecycle test for version 2 bootstrap registry fields

Create `tests/test-active-doc-scope-lifecycle.sh` with assertions that require `version: 2`, `context_contract_phase: bootstrap`, `management_status`, `entry_ref`, `context_owner`, bootstrap compatibility fields, and a reachable pilot `worklog.md`.

Run: `bash tests/test-active-doc-scope-lifecycle.sh`
Expected: FAIL because the registry is still version 1 and ownership contract is absent.

2. [T1] Update registry and ownership contract minimally

Change `contracts/active-doc-scope.yaml` to version 2 bootstrap dual-read fields and add one pilot entry for `docs/feature--doc-governance--context-recovery`. Add `contracts/context-artifact-ownership.yaml` with the repo owner, artifact owner, trigger, check, and waiver approver fields from `design.md`.

3. [T1] Verify lifecycle test passes

Run: `bash tests/test-active-doc-scope-lifecycle.sh`
Expected: PASS.

### Task 2: Context Contract Validator [T2]

Context: The validator is the single mechanical rule entry for registry, worklog, references, ownership, and mode-specific consistency. It should fail closed for blocking checks and report clear reasons.

Files:
- Create: `tools/community/validate_context_contract.py`
- Create: `tests/test-context-contract-validator.sh`
- Create: `tests/fixtures/context-contract/`
- Reuse: `tools/community/runtime_yaml.py`
- Reuse: `tools/community/canonical_ref_resolver.py`
- Reuse: `tools/community/check_task_plan_consistency.py`

1. [T2] Write validator tests for positive and negative fixtures

Create a shell test that builds temporary fixture repos for valid small-chain, valid standard-chain, duplicate active feature, missing worklog field, unreachable ref, invalid ownership contract, supporting metadata failure, and small-chain task/plan drift.

Run: `bash tests/test-context-contract-validator.sh`
Expected: FAIL because `validate_context_contract.py` does not exist.

2. [T2] Implement minimal validator CLI

Implement `python3 tools/community/validate_context_contract.py --repo-root .` with:
- registry phase and active uniqueness checks
- active feature path and `entry_ref` checks
- latest `worklog.md` block parsing
- required field and enum checks
- small-chain repo-relative ref resolution
- standard-chain `canonical:` active artifact ref resolution
- ownership contract schema checks
- supporting document metadata checks
- YAML-like failure output for blocking errors

3. [T2] Verify validator tests pass

Run: `bash tests/test-context-contract-validator.sh`
Expected: PASS.

### Task 3: Recovery Command And Lifecycle Helper [T3]

Context: Recovery is read-only and must not scan unmanaged docs. Lifecycle writes belong in a helper so phase changes and archive transitions do not hand-edit the registry.

Files:
- Create: `tools/community/recover_context.py`
- Create: `tools/community/update_active_doc_scope.py`
- Create: `tests/test-context-recovery.sh`
- Extend: `tests/test-active-doc-scope-lifecycle.sh`
- Create: `tests/fixtures/context-contract/recovery/`

1. [T3] Write recovery and lifecycle tests

Cover list output, exact feature match, basename match, fuzzy multi-match, archived lookup, active/archive collision, fixed failure output, and no unmanaged docs scan. Cover lifecycle helper phase update and archive transition.

Run: `bash tests/test-context-recovery.sh && bash tests/test-active-doc-scope-lifecycle.sh`
Expected: FAIL because the recovery command and lifecycle helper do not exist.

2. [T3] Implement recovery command and lifecycle helper

Implement read-only candidate parsing in `recover_context.py` and controlled registry updates in `update_active_doc_scope.py`. Both should reuse the same field semantics as the validator.

3. [T3] Verify recovery and lifecycle tests pass

Run: `bash tests/test-context-recovery.sh && bash tests/test-active-doc-scope-lifecycle.sh`
Expected: PASS.

### Task 4: Validator Wiring, Hook Registry, And Audit [T4]

Context: The same validator must be called by local validation and hook rendering. Audit is report-only and must not update registry or worklog.

Files:
- Modify: `tools/dev/validate-contracts.sh`
- Modify: `tools/validate-contracts.sh`
- Modify: `shared/hooks/registry.json`
- Modify: `tools/community/render_hook_registry.py`
- Modify: `shared/hooks/managed/codex_stop_dispatch.py`
- Create: `tools/dev/run-context-contract-audit.sh`
- Create: `tests/test-context-contract-audit.sh`

1. [T4] Write wiring and audit tests

Add assertions that `validate-contracts` runs the context validator, rendered Codex hooks include the context validator hook, and audit prints risks without changing fixture files.

Run: `bash tests/test-context-contract-audit.sh && bash tools/dev/validate-contracts.sh`
Expected: FAIL before wiring is implemented.

2. [T4] Wire validator and audit entrypoint

Call `validate_context_contract.py` from `tools/dev/validate-contracts.sh`, add a `context-contract-validator` runtime hook registry entry, ensure renderer preserves it, and implement report-only audit output.

3. [T4] Verify wiring and audit tests pass

Run: `bash tests/test-context-contract-audit.sh && bash tools/dev/validate-contracts.sh`
Expected: PASS.

### Task 5: Docs, Skills, Pilot Worklog, And Final Verification [T5]

Context: Documentation and runtime vocabulary must converge so old examples do not override the Phase 1 design. The pilot worklog must point to real small-chain artifacts once `tasks.md/plan.md` exist.

Files:
- Modify: `README.md`
- Modify: `contracts/small-chain.yaml`
- Modify: `contracts/standard-chain.yaml`
- Modify: `community/superpowers/skills/brainstorming/SKILL.md`
- Modify: `community/superpowers/skills/writing-plans/SKILL.md`
- Modify: `community/superpowers/skills/using-git-worktrees/SKILL.md`
- Modify: `community/superpowers/skills/subagent-driven-development/SKILL.md`
- Modify: `community/superpowers/skills/verification-before-completion/SKILL.md`
- Modify: `community/superpowers/skills/verify-change/SKILL.md`
- Modify: `community/superpowers/skills/finishing-a-development-branch/SKILL.md`
- Modify: `community/superpowers/skills/archive/SKILL.md`
- Modify: `shared/skills/product-director/SKILL.md`
- Modify: `shared/skills/product-manager/SKILL.md`
- Modify: `shared/skills/design/SKILL.md`
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `shared/skills/test-design/SKILL.md`
- Modify: `shared/skills/developer/SKILL.md`
- Modify: `shared/skills/verify/SKILL.md`
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/fix/SKILL.md`
- Modify: `shared/skills/consistency-audit/SKILL.md`
- Modify: `docs/feature--doc-governance--context-recovery/worklog.md`

1. [T5] Write documentation consistency assertions

Extend existing boundary tests or add targeted assertions for `scope registry`, `management_status`, `handoff_status`, `context_owner`, `artifact_owner`, and `canonical:` vocabulary.

Run: `bash tests/test-small-chain-boundary.sh && bash tests/test-standard-chain-cutover.sh`
Expected: FAIL if active docs or skill references still use only legacy registry wording.

2. [T5] Sync docs and pilot worklog

Update README, contracts, and in-scope skills with short handoff sections. Append a new top `worklog.md` record with `stage: execute`, `state_ref: 2026-04-25-active-context-handoff-phase-1/tasks.md#T1`, and `next_ref: 2026-04-25-active-context-handoff-phase-1/plan.md#T1`.

3. [T5] Run final proving commands

Run:
- `python3 tools/community/check_task_plan_consistency.py docs/feature--doc-governance--context-recovery/2026-04-25-active-context-handoff-phase-1/tasks.md docs/feature--doc-governance--context-recovery/2026-04-25-active-context-handoff-phase-1/plan.md`
- `bash tests/test-active-doc-scope-lifecycle.sh`
- `bash tests/test-context-contract-validator.sh`
- `bash tests/test-context-recovery.sh`
- `bash tests/test-context-contract-audit.sh`
- `bash tools/dev/validate-contracts.sh`
- `git diff --check`

Expected: all PASS with no whitespace errors.
