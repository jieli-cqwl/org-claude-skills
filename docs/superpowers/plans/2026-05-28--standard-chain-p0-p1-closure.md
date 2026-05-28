# Standard-chain P0/P1 Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the current delivery-owner packet red light and every accepted P0/P1 from the 2026-05-28 full review so the `product-director -> delivery-owner` chain can support one human owner plus an agent team without fake completion, stale evidence, or ambiguous handoff state.

**Architecture:** Treat the full review report as the repair contract. Repair deterministic control points first: packet schema, state enums, artifact registry, QA/verify gates, evidence freshness, then instruction text. Every issue must have a red test before implementation, a green target test after implementation, and final follow-up review showing no new P0/P1 in scope.

**Tech Stack:** Bash contract tests, Python validators, JSON Schema artifacts, YAML standard-chain contracts, Markdown skill instructions.

---

## Source Of Truth

- Primary repair contract: `docs/reports/standard-chain-flow-instruction-control-full-review-2026-05-28.md`
- Calibration source, already superseded by the full review: `docs/reports/standard-chain-flow-instruction-control-calibration-2026-05-28.md`
- Current known red light not captured as a full-review issue: `tests/test-delivery-owner-source-anchor-contract.sh` fails because `task_packet_check.py` still reads `"scope"`.

## Completion Definition

This work is complete only when all of these are true:

- Task 0 packet field migration is closed.
- Full-review accepted P0 issues `FLOW-001`, `FLOW-002`, `SKILL-001`, `SKILL-002` are closed.
- Full-review accepted P1 issues `FLOW-003` through `FLOW-012` and `SKILL-003` through `SKILL-005` are closed.
- Each closed issue has a direct test or script evidence path.
- `bash tests/run-all.sh --quick` passes.
- If any full-gate contract or cross-chain validator changes, `bash tests/run-all.sh` is run and passes, or a specific blocker is reported.
- Follow-up review from full-review lines 470-476 finds no new P0/P1 in the same scope.

P2/P3 are tracked but do not block this closure unless the human owner expands scope.

## Non-Goals

- Do not repair unrelated dirty files under `shared/rules/*`, `shared/reference/*`, `shared/assistant.md`, or runtime install tests unless a target test proves they block this scope.
- Do not decide dogfood readiness or homepage acceptance.
- Do not rewrite skill prose for style without a P0/P1 behavior-control reason.
- Do not collapse QA, review, and delivery-owner authorities into one role.

## Issue-To-Task Map

| Issue | Task |
| --- | --- |
| Current packet `scope` red light | Task 0 |
| `FLOW-006` verify final gate enum / QA admission | Task 1 |
| `FLOW-009` artifact registry runtime coverage | Task 2 |
| `FLOW-001` QA per-task verify coverage | Task 3 |
| `FLOW-008` QA obligation results consumption | Task 4 |
| `SKILL-001` fresh code review after fixer | Task 5 |
| `SKILL-003` QA conditional/deferred/not-run routing | Task 5 |
| `FLOW-002` target-change rebaseline and evidence invalidation | Task 6 |
| `SKILL-002` typed signoff evidence coverage | Task 7 |
| `FLOW-010` delivery-state enums and recovery fields | Task 8 |
| `FLOW-003` stage-dependent delivery-owner inputs | Task 9 |
| `FLOW-007` intake baseline/plan/cross-unit coverage | Task 9 |
| `FLOW-012` `safe_to_dispatch` versus baseline audit | Task 9 |
| `FLOW-004` terminal semantics | Task 10 |
| `FLOW-005` QA/code-review contract mismatch | Task 11 |
| `FLOW-011` director lock trace | Task 12 |
| `SKILL-004` no-progress escape path | Task 13 |
| `SKILL-005` advisory owner action consumption | Task 13 |

## Design Decisions

- For `FLOW-005`, choose delivery-owner DO-S6 as the sole code-review gate. QA should not own code-review authority. Remove `code-review-result` from QA required input and QA field consumption, then make delivery-owner closeout prove fresh code-review coverage.
- Runtime artifact registry is the recovery truth. Producers may write their own artifact, but before dispatching the next role there must be exactly one active registry entry per required artifact type for the relevant task/stage.
- `READY_FOR_COMMIT` means signoff package and commit handoff are prepared. `DELIVERED` means commit result is recorded. No delivery report before commit result.
- Scope/AC/goal/design changes are not signoff decisions. They must return to product/tech baseline freezing and explicitly supersede affected runtime evidence.
- Target changes use a new delivery-owner contract, `shared/skills/delivery-owner/contracts/target-change.schema.json`; do not stretch `user-decision.json` to carry rebaseline semantics.
- Intake preflight returns `safe_for_baseline_audit` after kickoff baseline checks. Only post-audit delivery-owner state may become `safe_to_dispatch`.
- Reuse shared-core state enums by reference/parity test. Do not edit `shared-core.schema.json` unless a target test proves the required canonical state is absent.
- New red tests must extend existing project gates named in each task. Do not create orphan test scripts outside `tests/run-all.sh` coverage unless the task explicitly says to add that script to the runner.

## Task 0: Close Task Packet `forbidden_scope` Migration

**Files:**
- Modify: `shared/skills/delivery-owner/scripts/task_packet_check.py`
- Modify: `tests/test-delivery-owner-sop-contract.sh`
- Modify: `shared/skills/delivery-owner/evals/evals.json`
- Modify: `shared/skills/delivery-owner/evals/minimal-behavior-replay.md`
- Verify: `tests/test-delivery-owner-source-anchor-contract.sh`

- [x] Step 1: Run the existing red test.

Run:

```bash
bash tests/test-delivery-owner-source-anchor-contract.sh
```

Expected: fail on `"scope"` in `task_packet_check.py`.

- [x] Step 2: Update packet validation to use `forbidden_scope`.

Implementation intent:

- Replace `packet.get("scope")` with `packet.get("forbidden_scope")` in consistency-auditor mode detection.
- Replace ambiguous-field validation entry `"scope"` with `"forbidden_scope"`.
- Keep business wording like `scope_verification` and `scope_boundary`; those are not packet field names.

- [x] Step 3: Update delivery-owner SOP packet fixtures.

In `tests/test-delivery-owner-sop-contract.sh`, migrate the old packet field name to `forbidden_scope`, reject any legacy top-level packet field named `scope`, and keep `forbidden_scope` semantically limited to files/directories the executor must not touch.

For negative ambiguous packet cases, ensure ambiguity is still tested against `forbidden_scope`.

- [x] Step 4: Update delivery-owner eval prompts and replay snippets.

Replace packet field lists that say `task_ref、role、goal、scope、input_refs...` with `task_ref、role、goal、forbidden_scope、input_refs...`.

- [x] Step 5: Verify.

Run:

```bash
bash tests/test-delivery-owner-source-anchor-contract.sh
bash tests/test-delivery-owner-sop-contract.sh
bash tests/test-delivery-owner-gate-contract.sh
bash tests/test-standard-chain-skill-evals.sh
```

Expected: all pass.

## Task 1: Verify Final Gate Enum And QA Admission

**Closes:** `FLOW-006`

**Files:**
- Modify: `shared/skills/verify/contracts/verify-result.schema.json`
- Modify: `shared/skills/verify/SKILL.md`
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/skills/qa/scripts/preflight_check.py`
- Test: `tests/test-standard-chain-validator-stack.sh`

- [x] Step 1: Add red assertions.

Add tests proving:

- final `gate_result=SPEC_OK` is invalid in `verify-result.schema.json`;
- QA preflight rejects verify-result with final `SPEC_OK`;
- `SPEC_OK` remains allowed only inside spec-review phase verdicts if that field exists.

- [x] Step 2: Implement schema enum.

Constrain final `gate_result` to:

```json
["PASS", "ISSUE", "BLOCKED"]
```

- [x] Step 3: Update QA admission.

In QA skill and preflight, accept only final `PASS` for verify admission.

- [ ] Step 4: Verify.

Run:

```bash
bash tests/test-standard-chain-validator-stack.sh
bash tests/run-all.sh --quick
```

Expected: target tests pass; quick remains green.

## Task 2: Make Artifact Registry Runtime Truth

**Closes:** `FLOW-009`

**Files:**
- Modify: `shared/skills/delivery-owner/contracts/artifact-registry.schema.json`
- Modify: `shared/skills/delivery-owner/templates/artifact-registry.template.json`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/developer/SKILL.md`
- Modify: `shared/skills/verify/SKILL.md`
- Modify: `shared/skills/qa/SKILL.md`
- Test: `tests/test-standard-chain-validator-stack.sh`

- [x] Step 1: Add red registry coverage tests.

Test that a phase registry missing active runtime entries for `developer-report`, `verify-result`, `code-review-result`, `qa-result`, or `consistency-audit-result` fails the relevant closeout/signoff readiness check.

- [x] Step 2: Add active uniqueness rules.

The registry must support exactly one active entry per required runtime artifact type for a task/stage.

- [x] Step 3: Define owner responsibility.

Skill prose must say: each producer writes the artifact, and delivery-owner must ensure the active registry entry exists before dispatching the next consumer.

- [x] Step 4: Verify.

Run:

```bash
bash tests/test-standard-chain-validator-stack.sh
bash tests/test-skill-output-and-gate-contract.sh
```

Expected: registry coverage and skill contract tests pass.

## Task 3: Enforce QA Per-Task Verify Coverage

**Closes:** `FLOW-001`

**Files:**
- Modify: `shared/skills/qa/scripts/preflight_check.py`
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `contracts/standard-chain.yaml`
- Modify fixtures under `tests/fixtures/standard-chain-foundation/` only when required by schema/contract tests.
- Test: `tests/test-standard-chain-validator-stack.sh`

- [x] Step 1: Add red fixture.

Create or extend a fixture where `tasks.json` has two in-scope tasks, but only one task has active `verify-result.gate_result=PASS`.

Expected QA preflight result:

```json
{
  "status": "BLOCKED",
  "safe_to_continue": false
}
```

- [x] Step 2: Implement task set join.

QA preflight must load:

- frozen `tasks.json`;
- active artifact registry;
- active developer-report for each in-scope task;
- active verify-result for each in-scope task.

It must block if any task lacks current developer evidence or final verify PASS.

- [x] Step 3: Verify matching refs.

Each accepted verify-result must match baseline/active refs from tasks and registry. Do not accept filesystem-only discovery as proof.

- [ ] Step 4: Verify.

Run:

```bash
bash tests/test-standard-chain-validator-stack.sh
bash tests/run-all.sh --quick
```

Expected: QA missing-task fixture blocks; valid fixture passes.

## Task 4: Add QA Obligation Results To Chain Consumption

**Closes:** `FLOW-008`

**Files:**
- Modify: `contracts/standard-chain.yaml`
- Modify: `contracts/standard-chain-field-consumption.yaml`
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Test: `tests/test-standard-chain-field-consumption-contract.sh`

- [x] Step 1: Add red field-consumption assertion.

Require `qa-result.obligation_results` to appear as a QA key field and as delivery-owner / signoff input.

- [x] Step 2: Add one-to-one obligation coverage rule.

QA and delivery-owner must require `obligation_results[].obligation_id` to cover `qa_handoff_contract[].obligation_id` and relevant cross-unit obligations.

- [x] Step 3: Verify.

Run:

```bash
bash tests/test-standard-chain-field-consumption-contract.sh
bash tests/run-all.sh --quick
```

Expected: field consumption contract passes.

## Task 5: Require Fresh Review After Fixer And Route QA Non-PASS States

**Closes:** `SKILL-001`, `SKILL-003`

**Files:**
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/delivery-owner/templates/status-card.template.md`
- Modify: `shared/skills/delivery-owner/contracts/delivery-state.schema.json`
- Test: delivery-owner SOP/gate contract tests.

- [x] Step 1: Add red assertions.

Add tests that fail when:

- QA FAIL -> fixer -> verify/QA omits fresh code-review;
- QA `CONDITIONAL`, `NOT_RUN`, `N_A`, `CONDITIONAL_ALLOW`, `BLOCK`, or `DEFER` has no explicit delivery-owner route.

- [x] Step 2: Update DO-S7 route.

After any fixer code change, route must be:

```text
affected verifier -> fresh code-reviewer -> affected QA
```

Closeout may consume only evidence after the last code change.

- [x] Step 3: Bind every QA non-PASS state.

Define next owner, required artifact, user-decision or waiver requirement, and resume condition for every QA gate/release recommendation combination.

- [x] Step 4: Verify.

Run:

```bash
bash tests/test-delivery-owner-sop-contract.sh
bash tests/test-delivery-owner-gate-contract.sh
```

Expected: both pass.

## Task 6: Split Target-Change Decisions From Signoff Decisions

**Closes:** `FLOW-002`

**Files:**
- Modify: `shared/skills/delivery-owner/contracts/user-decision.schema.json`
- Create: `shared/skills/delivery-owner/contracts/target-change.schema.json`
- Create: `shared/skills/delivery-owner/templates/target-change.template.json`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `contracts/standard-chain.yaml`
- Modify: `contracts/standard-chain-field-consumption.yaml`
- Test: standard-chain user-decision tests.

- [x] Step 1: Add red target-change fixture.

Fixture: user changes AC/scope after verify/QA evidence exists. Assert old runtime evidence is marked superseded and closeout blocks until rebaseline and fresh proof exist.

- [x] Step 2: Restrict `user-decision.json`.

Keep `user-decision.json` for signoff and risk acceptance. Do not let it silently represent scope/AC/goal/design changes without rebaseline semantics.

- [x] Step 3: Add target-change invalidation model.

Represent:

- changed target type;
- affected refs;
- superseded evidence refs;
- rebaseline owner;
- required fresh proof after rebaseline.

- [x] Step 4: Verify.

Run:

```bash
bash tests/test-standard-chain-user-decision.sh
bash tests/test-standard-chain-validator-stack.sh
```

Expected: target-change fixture blocks stale closeout.

## Task 7: Add Typed Signoff Runtime Evidence Coverage

**Closes:** `SKILL-002`

**Files:**
- Modify: `shared/skills/delivery-owner/contracts/signoff-package.schema.json`
- Modify: `shared/skills/delivery-owner/templates/signoff-package.template.json`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `tools/community/validate_readiness_contract.py`
- Test: signoff package fixture test.

- [x] Step 1: Add red signoff fixture.

Create a signoff package fixture missing one runtime artifact type, such as `code-review-result`.

Expected: signoff validation blocks.

- [x] Step 2: Add typed evidence matrix.

Required matrix types:

- `developer-report`
- `verify-result`
- `code-review-result`
- `qa-result`
- `consistency-audit-result`

Each entry must include canonical ref, producer, status, freshness basis, active registry proof, and stale/superseded check result.

- [x] Step 3: Remove logical refs as proof.

Skill text must say logical summaries explain evidence but never replace canonical artifact refs.

- [x] Step 4: Verify.

Run:

```bash
bash tests/test-standard-chain-validator-stack.sh
bash tests/run-all.sh --quick
```

Expected: missing evidence type blocks; full evidence fixture passes.

## Task 8: Unify Delivery State Vocabulary And Recovery Fields

**Closes:** `FLOW-010`

**Files:**
- Modify: `shared/skills/delivery-owner/contracts/delivery-state.schema.json`
- Modify: `shared/skills/delivery-owner/templates/status-card.template.md`
- Modify: `shared/skills/delivery-owner/templates/delivery-report.template.md`
- Test: delivery-state schema and recovery fixtures.

- [x] Step 1: Add red recovery fixture.

Fixture: blocked delivery state lacks blocker owner, next action, or resume condition. Assert schema or validator rejects it.

- [x] Step 2: Reference shared-core enums.

Use shared-core `current_stage` and `control_action` vocabulary or duplicate with exact enum parity and tests.

Default implementation: add parity tests in `tests/test-standard-chain-validator-stack.sh` and avoid editing `shared-core.schema.json`. If a required canonical state is missing from shared-core, stop and report the missing enum before expanding that shared contract.

- [x] Step 3: Require blocked/paused recovery fields.

When blocked or paused, require:

- `blocker_id`
- `blocker_owner`
- `blocker_basis_refs`
- `resume_stage`
- `next_action`
- `resume_condition`

- [x] Step 4: Verify.

Run:

```bash
bash tests/test-standard-chain-validator-stack.sh
bash tests/test-delivery-owner-sop-contract.sh
```

Expected: recovery fixture blocks when fields are absent.

## Task 9: Split Delivery-owner Inputs By Stage And Fix Intake Readiness

**Closes:** `FLOW-003`, `FLOW-007`, `FLOW-012`

**Files:**
- Modify: `contracts/standard-chain.yaml`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/delivery-owner/scripts/intake_preflight_check.py`
- Modify related tests in `tests/test-delivery-owner-sop-contract.sh`, `tests/test-task-contract-consumer-alignment.sh`, and standard-chain contract tests.

- [x] Step 1: Add red kickoff fixture.

Fixture: valid kickoff baseline exists but closeout runtime artifacts do not. Assert delivery-owner intake does not require future developer/verify/review/QA outputs.

- [x] Step 2: Add red unsafe baseline fixture.

Fixture: missing plan readiness, missing cross-unit obligations, or blocking typed gap. Assert intake blocks or reports not ready for baseline audit.

- [x] Step 3: Split stage inputs.

Define inputs for:

- DO-S1 kickoff baseline;
- DO-S5 execution evidence;
- DO-S6 review;
- DO-S7 QA;
- DO-S8 closeout/signoff.

- [x] Step 4: Rename dispatch safety state.

Change intake PASS to `safe_for_baseline_audit`. Do not return `safe_to_dispatch=true` from intake preflight. `safe_to_dispatch=true` is reserved for the post-baseline-audit state.

- [x] Step 5: Verify.

Run:

```bash
bash tests/test-delivery-owner-sop-contract.sh
bash tests/test-task-contract-consumer-alignment.sh
bash tests/test-standard-chain-field-consumption-contract.sh
```

Expected: kickoff no longer requires future artifacts; unsafe baseline does not dispatch.

## Task 10: Remove False Terminal Semantics From Runtime Artifacts

**Closes:** `FLOW-004`

**Files:**
- Modify: `contracts/standard-chain.yaml`
- Modify: `contracts/standard-chain-field-consumption.yaml` if consumer declarations need alignment.
- Test: `tests/test-standard-chain-field-consumption-contract.sh`

- [x] Step 1: Add red assertions.

Assert `developer-report`, `verify-result`, and `code-review-result` are not terminal while downstream consumers exist.

- [x] Step 2: Update artifact semantics.

Remove terminal meaning or replace it with explicit archival semantics that does not affect routing.

- [x] Step 3: Verify.

Run:

```bash
bash tests/test-standard-chain-field-consumption-contract.sh
bash tests/run-all.sh --quick
```

Expected: no consumed runtime artifact is marked terminal.

## Task 11: Resolve QA And Code-review Authority Mismatch

**Closes:** `FLOW-005`

**Decision:** QA will not own code-review admission. Delivery-owner DO-S6 owns code-review gate and DO-S8 proves fresh review evidence.

**Files:**
- Modify: `contracts/standard-chain.yaml`
- Modify: `contracts/standard-chain-field-consumption.yaml`
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Test: standard-chain field consumption and QA preflight tests.

- [x] Step 1: Add red mismatch test.

Test should fail if standard-chain says QA requires `code-review-result` while QA skill/preflight does not validate it.

- [x] Step 2: Remove QA code-review dependency.

Remove `code-review-result` from QA required inputs and QA field consumption.

- [x] Step 3: Strengthen delivery-owner review gate.

Delivery-owner must require fresh code-review result before QA and again after fixer code changes.

- [x] Step 4: Verify.

Run:

```bash
bash tests/test-standard-chain-field-consumption-contract.sh
bash tests/test-delivery-owner-sop-contract.sh
```

Expected: QA contract no longer falsely claims code-review consumption; DO owns review freshness.

## Task 12: Trace Director Locks Through Execution And Signoff

**Closes:** `FLOW-011`

**Files:**
- Modify: `contracts/standard-chain.yaml`
- Modify: `contracts/standard-chain-field-consumption.yaml`
- Modify: `shared/skills/delivery-owner/scripts/intake_preflight_check.py`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify consistency-auditor contracts/skill if it owns digest verification.
- Test: contract and intake fixture tests.

- [x] Step 1: Add red digest trace test.

Fixture: PM artifact lacks `director_confirmation.locked_field_digest` or digest mismatches Director baseline. Assert delivery-owner or consistency-auditor blocks.

- [x] Step 2: Add key fields and consumers.

Add `director_confirmation` and `locked_field_digest` to standard-chain key fields and field consumption.

- [x] Step 3: Add intake or audit check.

Before execution and signoff, verify director lock digests are present and match.

- [x] Step 4: Verify.

Run:

```bash
bash tests/test-standard-chain-field-consumption-contract.sh
bash tests/test-delivery-owner-sop-contract.sh
```

Expected: digest mismatch blocks before dispatch/signoff.

## Task 13: Close No-Progress And Advisory Owner-Action Escape Paths

**Closes:** `SKILL-004`, `SKILL-005`

**Files:**
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/delivery-owner/templates/status-card.template.md`
- Modify: `shared/skills/delivery-owner/contracts/delivery-state.schema.json` if structured fields are needed.
- Modify: `shared/skills/delivery-owner/contracts/delivery-state.schema.json`
- Test: delivery-owner SOP/gate tests.

- [x] Step 1: Add red assertions.

Tests should fail when:

- `owner_changed` alone counts as progress;
- advisory `required_owner_action` is marked consumed without `action_id`, owner, result, evidence ref, and state update.

- [x] Step 2: Redefine progress.

Progress means evidence that closes or narrows the current gap, changes the gap judgment, or routes to a more authoritative owner with next action and resume condition.

Bare owner change is not progress.

- [x] Step 3: Define owner-action consumption.

Required fields:

- `action_id`
- `required_owner`
- `routed_to`
- `result`
- `evidence_ref`
- `state_update`
- `reopen_condition`

Delivery-owner may route and record; it may not self-clear advisory obligations.

- [x] Step 4: Verify.

Run:

```bash
bash tests/test-delivery-owner-sop-contract.sh
bash tests/test-delivery-owner-gate-contract.sh
```

Expected: no-progress and owner-action tests pass.

## Task 14: Follow-up Review And Final Verification

**Files:**
- Create or update: `docs/reports/standard-chain-flow-instruction-control-followup-2026-05-28.md`
- Read-only review across full-review scope.

- [ ] Step 1: Run targeted tests.

Run every target command from Tasks 0-13.

- [ ] Step 2: Run quick regression.

Run:

```bash
bash tests/run-all.sh --quick
```

Expected: `All tests passed`.

- [ ] Step 3: Decide whether full regression is required.

Run full regression when any of these changed:

- `contracts/standard-chain.yaml`
- `contracts/standard-chain-field-consumption.yaml`
- shared schemas consumed by install/runtime tests
- cross-chain validators

Command:

```bash
bash tests/run-all.sh
```

Expected: all tests pass. If it fails because of pre-existing dirty runtime-rule work, stop and report the exact unrelated blocker.

- [ ] Step 4: Run follow-up review.

Review order:

1. P0 regression: no fake QA PASS, stale evidence reuse, stale code-review reuse, or logical signoff evidence.
2. State-machine review: schema, status card, report, and scripts use the same state vocabulary.
3. Registry/freshness review: active runtime coverage and producer/DO append responsibility are enforceable.
4. Instruction-control review: reread delivery-owner, QA, verify, and fix around pass/ready/consume/evidence/dispatch.
5. Full-scope pass: no new P0/P1.

- [ ] Step 5: Verify diff scope.

Run:

```bash
git diff --check
git status --short
```

Expected:

- no whitespace errors;
- changed files are explainable by Tasks 0-14;
- unrelated dirty runtime-rule/reference files are not modified by this work unless explicitly approved.
