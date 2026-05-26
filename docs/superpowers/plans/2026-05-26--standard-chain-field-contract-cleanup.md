# Standard Chain Field Contract Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tighten the `product-director -> product-manager -> design` chain so every retained field has a necessary, sufficient, non-duplicated, verifiable downstream contract; keep Director's necessary pre-finalization ledger, remove Product Manager's process ledger, and make Design confirmation data an explicit API contract rather than a summary.

**Architecture:** Add one field-consumption contract for cross-stage field ownership and downstream use. Keep schemas/templates as structural truth, skill instructions as runtime behavior, and tests/eval fixtures as executable proof. Changes are applied from contract outward: contract -> validators/tests -> skill text -> schemas/templates/scripts -> fixtures/eval packages.

**Tech Stack:** Bash test scripts, Python validators, YAML contracts, JSON Schema, jq, existing `tests/run-all.sh` gate runner.

---

## Success Criteria

- Product Manager active runtime no longer requires, generates, validates, or consumes `product-manager-ledger.json`.
- Product Director still validates `product-director-ledger.json` for Director-only pre-finalization recovery and confirmation.
- No active downstream contract treats any co-creation ledger as a canonical requirement source.
- Every retained field in Director, PM, and Design active artifacts has `producer`, `authority`, `consumers`, `consumed_for`, `consume_mode`, `required_when`, and `failure_effect`.
- Design's current `co_creation_summary` is replaced with a clearer confirmation contract: `design_stage_confirmations`.
- Tests cover direct scripts, downstream consumers, eval package validators, fixtures, and full quick gate.
- `bash tests/run-all.sh --quick` passes after targeted tests pass.

## Non-Goals

- Do not redesign the full standard chain after Design (`test-design`, `tech-lead`, `developer`, `qa`, `delivery-owner`) except where those stages are declared consumers of PM/Design fields.
- Do not edit historical `tools/eval/results/**` snapshots.
- Do not add a replacement PM process summary field.
- Do not keep or add fields for aesthetic completeness, future speculation, or prose projection convenience.
- Do not use Design-only consumption to delete PM fields that are consumed by `test-design`, `tech-lead`, `qa`, or `delivery-owner`.

## File Map

**Create**
- `contracts/standard-chain-field-consumption.yaml` - machine-readable field-level producer/authority/consumer contract for Director, PM, and Design artifacts.
- `tools/community/validate_standard_chain_field_consumption.py` - validates the new contract against `contracts/standard-chain.yaml` and active schemas.
- `tests/test-standard-chain-field-consumption-contract.sh` - regression test for field contract completeness and PM ledger removal.

**Modify**
- `contracts/standard-chain.yaml` - remove PM ledger from `co_creation_ledgers`; add/align Design field name; keep downstream consumer declarations aligned.
- `contracts/co-creation-ledgers.yaml` - Director-only ledger contract.
- `contracts/product-artifacts.yaml` - remove section-only ambiguity or point to the field-consumption contract for executable field semantics.
- `tools/community/validate_co_creation_ledger.py` - reject active `product-manager` and `design` ledger producers; retain `product-director`.
- `shared/skills/product-director/SKILL.md` and `shared/skills/product-director/references/final-artifacts.md` - clarify Director ledger as Director-only pre-finalization recovery, not downstream input.
- `shared/skills/product-manager/SKILL.md` - remove PM ledger instructions and route blockers into formal fields or blocking replies.
- `shared/skills/product-manager/scripts/*` - remove PM ledger validation references; preserve formal closure checks.
- `shared/skills/product-manager/templates/*.json` and `shared/skills/product-manager/contracts/*.schema.json` - align field descriptions and required conditions with field-consumption contract.
- `shared/skills/design/SKILL.md` - replace `co_creation_summary` behavior with `design_stage_confirmations`.
- `shared/skills/design/templates/design.template.json` - rename and reshape the confirmation field.
- `shared/skills/design/contracts/design.schema.json` - rename and tighten schema for the confirmation field.
- `shared/skills/design/scripts/completion_check.sh` - check `design_stage_confirmations`.
- `shared/skills/design/scripts/render_projection.py` - project from `design_stage_confirmations`.
- `shared/skills/design/projections/design-template.md` - update projection source refs.
- `shared/skills/design/references/canonical-ref-cheatsheet.md` - update canonical field names.
- `tools/community/canonical_design_confirmation_rules.py` - validate `design_stage_confirmations`.
- `tools/community/canonical_design_errors.py` - update error text and missing-stage guidance.
- `tools/community/validate_standard_chain_phase.py` - inspect with `rg -n 'co_creation_summary|product-manager-ledger|product_manager_ledger'`; modify when matched, record `no active reference` when not matched.
- `tools/eval/scripts/validate_stage2_product_manager_materials.py` - remove PM ledger materials from generated/validated package.
- `tools/eval/scripts/validate_stage2_product_manager_package.py` - remove `product_manager_ledger` package requirement and ledger validation.
- `tools/eval/scripts/validate_stage2_design_materials.py` - emit `design_stage_confirmations`.
- `tools/eval/scripts/validate_stage2_design_package.py` - validate renamed field.
- `tests/gate-plan.json` and `tests/run-all.sh` - add the field-consumption contract test and remove outdated PM ledger expectations if present.
- Existing tests named in the task sections below.
- Active fixtures under `tests/fixtures/standard-chain-foundation/**`, `tests/fixtures/standard-chain-pilots/**`, and `shared/skills/design/examples/**` that contain the renamed Design field.

---

### Task 1: Add The Field Consumption Contract Gate

**Files:**
- Create: `contracts/standard-chain-field-consumption.yaml`
- Create: `tools/community/validate_standard_chain_field_consumption.py`
- Create: `tests/test-standard-chain-field-consumption-contract.sh`
- Modify: `tests/run-all.sh`
- Modify: `tests/gate-plan.json`

- [ ] **Step 1: Write the failing shell test**

Create `tests/test-standard-chain-field-consumption-contract.sh` with these checks:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTRACT="$ROOT/contracts/standard-chain-field-consumption.yaml"
VALIDATOR="$ROOT/tools/community/validate_standard_chain_field_consumption.py"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing contracts/standard-chain-field-consumption.yaml"
[[ -f "$VALIDATOR" ]] || fail "missing validate_standard_chain_field_consumption.py"

python3 "$VALIDATOR" \
  --standard-chain "$ROOT/contracts/standard-chain.yaml" \
  --field-consumption "$CONTRACT"

if rg -n 'product-manager-ledger\.json|producer:\s*product-manager|--producer product-manager' "$CONTRACT" "$ROOT/contracts/co-creation-ledgers.yaml" "$ROOT/contracts/standard-chain.yaml"; then
  fail "active field and ledger contracts must not keep product-manager-ledger"
fi

rg -q 'design_stage_confirmations' "$CONTRACT" \
  || fail "field contract must include design_stage_confirmations"
```

- [ ] **Step 2: Run the test and verify it fails for missing files**

Run:

```bash
bash tests/test-standard-chain-field-consumption-contract.sh
```

Expected: fails with `missing contracts/standard-chain-field-consumption.yaml`.

- [ ] **Step 3: Implement the validator**

Create `tools/community/validate_standard_chain_field_consumption.py`. The validator must:

- Load YAML using the same dependency pattern already used by nearby contract validators.
- Require top-level `version: 1`.
- Require every artifact entry to define `path`, `producer`, and `fields`.
- Require every field to define `producer`, `authority`, `consumers`, `required_when`, and `failure_effect`.
- Require every consumer entry to define non-empty `consumed_for` and `consume_mode`.
- Allow `consume_mode` only as `reference`, `transform`, `gate`, or `handoff`.
- Reject `product-manager-ledger.json`, `design-ledger.json`, `co_creation_summary`, and active `producer: product-manager` ledger references.
- Check every `key_fields` entry in `contracts/standard-chain.yaml` for `product-director`, `product-manager`, and `design` has a matching field in the field-consumption contract.

- [ ] **Step 4: Add the field-consumption contract**

Create `contracts/standard-chain-field-consumption.yaml` with field entries for:

- `docs/{feature}/brief.json`
- `docs/{feature}/phase-{N}/phase-prd.json`
- `docs/{feature}/phase-{N}/units/UNIT-{N}.json`
- `docs/{feature}/phase-{N}/design.json`

Each field must identify all legitimate consumers from `contracts/standard-chain.yaml`, including cases where Design does not consume a PM field but `test-design`, `tech-lead`, `qa`, or `delivery-owner` does.

- [ ] **Step 5: Wire the test into gates**

Add `tests/test-standard-chain-field-consumption-contract.sh` to:

- `tests/run-all.sh` syntax/quick or full list following nearby standard-chain contract tests.
- `tests/gate-plan.json` as a `standard-chain` contract test.

- [ ] **Step 6: Verify Task 1**

Run:

```bash
bash tests/test-standard-chain-field-consumption-contract.sh
python3 -m py_compile tools/community/validate_standard_chain_field_consumption.py
```

Expected: both pass.

---

### Task 2: Keep Director Ledger, Remove PM Ledger From Active Contracts

**Files:**
- Modify: `contracts/co-creation-ledgers.yaml`
- Modify: `contracts/standard-chain.yaml`
- Modify: `tools/community/validate_co_creation_ledger.py`
- Modify: `tests/test-standard-chain-co-creation-ledger-contract.sh`
- Modify: `tests/test-standard-chain-hard-gate-boundary-contract.sh`
- Verify: `tests/test-product-director-real-demand-smoke.sh`
- Verify: `tests/test-skill-output-and-gate-contract.sh`

- [ ] **Step 1: Update failing expectations**

Change `tests/test-standard-chain-co-creation-ledger-contract.sh` so it asserts:

- `product-director-ledger.json` is present.
- `product-manager-ledger.json` is absent.
- `docs/{feature}/product-director-ledger.json` remains in `contracts/standard-chain.yaml`.
- `docs/{feature}/phase-{N}/product-manager-ledger.json` is absent from `contracts/standard-chain.yaml`.
- `validate_co_creation_ledger.py --producer product-manager` fails with an explicit unsupported-producer message.

- [ ] **Step 2: Run the updated test and verify it fails**

Run:

```bash
bash tests/test-standard-chain-co-creation-ledger-contract.sh
```

Expected: fails while contracts and validator still allow Product Manager ledger.

- [ ] **Step 3: Modify `contracts/co-creation-ledgers.yaml`**

Keep only the `product-director` ledger under `co_creation_ledgers.ledgers`. Clarify:

- `scope: feature`
- `consumer: product-director`
- `control_input: false`
- `canonical_outputs` remain `brief.json` and `phase-{N}/phase-prd.json`
- Product Manager and Design do not have co-creation ledger artifacts.

- [ ] **Step 4: Modify `contracts/standard-chain.yaml`**

In `co_creation_ledgers.artifacts`, remove the `product-manager` block. Keep the Director block only.

- [ ] **Step 5: Modify `validate_co_creation_ledger.py`**

Restrict accepted producers to `product-director`. Unsupported producers must fail before finalization checks with a clear message:

```text
unsupported co-creation ledger producer: product-manager
```

- [ ] **Step 6: Update hard-gate tests**

In `tests/test-standard-chain-hard-gate-boundary-contract.sh`, keep the Director validator assertion and remove any assertion requiring:

```bash
python3 tools/community/validate_co_creation_ledger.py --artifact "$PHASE_DIR/product-manager-ledger.json" --producer product-manager --require-finalized
```

- [ ] **Step 7: Verify Task 2**

Run:

```bash
bash tests/test-standard-chain-co-creation-ledger-contract.sh
bash tests/test-standard-chain-hard-gate-boundary-contract.sh
bash tests/test-product-director-real-demand-smoke.sh
bash tests/test-skill-output-and-gate-contract.sh
```

Expected: all pass. Director missing/non-finalized ledger cases must still fail as before.

---

### Task 3: Remove Product Manager Ledger From Runtime, Eval, And Package Materials

**Files:**
- Modify: `shared/skills/product-manager/SKILL.md`
- Modify: `shared/skills/product-manager/scripts/completion_check.sh` after inspecting it with `rg -n 'product-manager-ledger|product_manager_ledger|validate_co_creation_ledger'`; remove matched PM ledger references, record `no active PM ledger reference` when not matched.
- Modify: `tools/eval/scripts/validate_stage2_product_manager_materials.py`
- Modify: `tools/eval/scripts/validate_stage2_product_manager_package.py`
- Modify: `tests/test-stage2-product-manager-package.sh`
- Modify: `tests/test-product-director-manager-move-in-chain.sh`
- Modify: any active test found by `rg -n 'product-manager-ledger' tests tools shared contracts -g '!tools/eval/results/**'`

- [ ] **Step 1: Write the no-PM-ledger assertion**

Add or update an assertion in `tests/test-standard-chain-field-consumption-contract.sh`:

```bash
if rg -n 'product-manager-ledger\.json|product_manager_ledger|--producer product-manager' \
  "$ROOT/shared/skills/product-manager" \
  "$ROOT/tools/eval/scripts" \
  "$ROOT/contracts" \
  "$ROOT/tests" \
  -g '!tools/eval/results/**' \
  -g '!docs/superpowers/plans/**'; then
  fail "active runtime must not depend on product-manager-ledger"
fi
```

Only negative assertions may keep the literal `product-manager-ledger` string. Put each allowed negative assertion in `tests/test-standard-chain-co-creation-ledger-contract.sh` or `tests/test-standard-chain-field-consumption-contract.sh` with a nearby comment that says `negative assertion only`.

- [ ] **Step 2: Run the assertion and verify it fails**

Run:

```bash
bash tests/test-standard-chain-field-consumption-contract.sh
```

Expected: fails on current Product Manager skill/eval/test references.

- [ ] **Step 3: Rewrite Product Manager skill instructions**

In `shared/skills/product-manager/SKILL.md`:

- Remove `product-manager-ledger.json` from HARD-GATE, output list, process ledger section, Handoff gate, PM handoff gate, Delivery, write locations, and completion check.
- Replace `product-manager-ledger.json.open_questions` with a blocking reply contract: `owner`, `blocking_fact`, `affected_artifact`, `return_to`, `recovery_condition`.
- Replace `product-manager-ledger.json.supersedes` with formal drift handling: Director-owned drift stops and returns to Director/user; PM-owned post-review drift invalidates digest and returns to the owning PM step.
- Keep review closure in `review_conclusion / issue_ledger`.
- Keep delivery closure in `brief.json.delivery_confirmation`.

- [ ] **Step 4: Remove PM ledger from eval materials**

In `tools/eval/scripts/validate_stage2_product_manager_materials.py` and `tools/eval/scripts/validate_stage2_product_manager_package.py`:

- Stop generating `product-manager-ledger.json`.
- Stop requiring `product_manager_ledger`.
- Stop importing or calling `validate_co_creation_ledger` for Product Manager packages.
- Keep package validation for `brief.json`, `phase-prd.json`, `UNIT-*.json`, review digest, product closure, and standard-chain phase validation.

- [ ] **Step 5: Update PM package tests**

In `tests/test-stage2-product-manager-package.sh`:

- Remove fixture construction of a PM ledger.
- Add a negative assertion that a package containing only ledger closure but missing `review_conclusion` / `issue_ledger` / `delivery_confirmation` still fails.

- [ ] **Step 6: Verify Task 3**

Run:

```bash
bash tests/test-standard-chain-field-consumption-contract.sh
bash tests/test-stage2-product-manager-package.sh
bash tests/test-product-director-manager-move-in-chain.sh
bash tests/test-pm-design-chain-e2e.sh
```

Expected: all pass and `rg` finds no active PM ledger dependency outside allowed historical snapshots.

---

### Task 4: Tighten Director Ledger Semantics Without Making It A Downstream Source

**Files:**
- Modify: `shared/skills/product-director/SKILL.md`
- Modify: `shared/skills/product-director/references/final-artifacts.md`
- Inspect and possibly modify: `shared/skills/product-director/scripts/evaluate_content_quality.py`. Run `rg -n 'ledger|summary|finalization_basis|brief|phase-prd' shared/skills/product-director/scripts/evaluate_content_quality.py`; if ledger text is accepted as a substitute for canonical `brief.json` / `phase-prd.json` fields, change the evaluator so ledger checks are limited to checkpoint/finalization evidence and canonical field quality is checked from canonical artifacts.
- Modify: `tests/test-product-director-real-demand-smoke.sh`
- Modify: `tests/test-product-context-signal-quality.sh`

- [ ] **Step 1: Add explicit Director-only ledger checks**

Update Director tests so they assert:

- Director ledger is finalized before final artifacts pass.
- Director ledger references `brief.json` and every `phase-{N}/phase-prd.json`.
- PM/Design handoff text says downstream consumes canonical JSON, not the ledger.
- Ledger summaries cannot substitute missing `brief.json` or `phase-prd.json` fields.

- [ ] **Step 2: Update Director instructions**

In Director skill/final artifacts references, define ledger as:

- Purpose: preserve pre-finalization confirmation checkpoints and drift recovery for Director only.
- Allowed content: checkpoint, subject ref, user-confirmed decision summary, source refs, output refs, open questions, supersedes, handoff refs, finalization basis.
- Forbidden content: full baseline copy, PM product model, AC, design decisions, implementation details, downstream requirements.

- [ ] **Step 3: Verify Task 4**

Run:

```bash
bash tests/test-product-director-real-demand-smoke.sh
bash tests/test-product-context-signal-quality.sh
bash tests/test-skill-output-and-gate-contract.sh
```

Expected: all pass; Director ledger remains a gate for Director only.

---

### Task 5: Replace Design `co_creation_summary` With A Clear Confirmation Contract

**Files:**
- Modify: `shared/skills/design/SKILL.md`
- Modify: `shared/skills/design/templates/design.template.json`
- Modify: `shared/skills/design/contracts/design.schema.json`
- Modify: `shared/skills/design/scripts/completion_check.sh`
- Modify: `shared/skills/design/scripts/render_projection.py`
- Modify: `shared/skills/design/projections/design-template.md`
- Modify: `shared/skills/design/references/canonical-ref-cheatsheet.md`
- Modify: `tools/community/canonical_design_confirmation_rules.py`
- Modify: `tools/community/canonical_design_errors.py`
- Inspect and possibly modify: `tools/community/validate_standard_chain_phase.py`. Run `rg -n 'co_creation_summary|design_stage_confirmations' tools/community/validate_standard_chain_phase.py`; replace old-field references when matched, record `no direct design confirmation field reference` when not matched.
- Modify: `tools/eval/scripts/validate_stage2_design_materials.py`
- Modify: `tools/eval/scripts/validate_stage2_design_package.py`
- Modify: active Design fixtures and examples containing `co_creation_summary`.

- [ ] **Step 1: Update failing tests for the new field**

Update existing tests that currently require `co_creation_summary` so they require `design_stage_confirmations`:

- `tests/test-stage2-design-package.sh`
- `tests/test-standard-chain-closure-contract.sh`
- `tests/test-standard-chain-foundation-registry.sh`
- `tests/test-design-skill-governance-redesign.sh`
- `tests/test-design-dogfood-e2e.sh`

The new field shape is:

```json
"design_stage_confirmations": [
  {
    "stage_id": "stakeholders-and-concerns",
    "confirmation_focus": "which consumers and architecture-significant concerns are confirmed",
    "user_confirmation_summary": "confirmed facts or risk acceptance that can change design",
    "design_refs": ["design.json#input_analysis"]
  }
]
```

- [ ] **Step 2: Run updated tests and verify failure**

Run:

```bash
bash tests/test-stage2-design-package.sh
bash tests/test-standard-chain-closure-contract.sh
```

Expected: fail while schema/templates/scripts still use `co_creation_summary`.

- [ ] **Step 3: Rename and reshape the schema field**

In `shared/skills/design/contracts/design.schema.json`:

- Replace top-level required `co_creation_summary` with `design_stage_confirmations`.
- Replace item fields:
  - remove `stage_name`
  - rename `question_or_focus` to `confirmation_focus`
  - keep `user_confirmation_summary`
  - rename `decision_refs` to `design_refs`
- Keep stage enum coverage for the seven Design semantic stages.
- Set `additionalProperties: false` for each confirmation item unless an existing validator proves a needed extension.

- [ ] **Step 4: Update template and skill instructions**

In `design.template.json` and `design/SKILL.md`:

- Replace every old field reference.
- Describe the field as a confirmation index, not a process summary.
- State that it records only confirmations that change or freeze design obligations.
- State that detailed design facts live in owned fields such as `key_decisions`, `option_analysis`, `runtime_facts`, `interfaces`, `verification_mapping`, and `risk_response`.

- [ ] **Step 5: Update scripts and errors**

Update validation/rendering code:

- `canonical_design_confirmation_rules.py`
- `canonical_design_errors.py`
- `completion_check.sh`
- `render_projection.py`
- `validate_standard_chain_phase.py` when the Step 5 inspection command reports a direct old-field reference.

Error messages must name `design_stage_confirmations` and tell the writer which stage id is missing.

- [ ] **Step 6: Update eval scripts and fixtures**

Update active generated examples and fixtures:

- `tools/eval/scripts/validate_stage2_design_materials.py`
- `tools/eval/scripts/validate_stage2_design_package.py`
- `tests/fixtures/standard-chain-foundation/**/design.json`
- `tests/fixtures/standard-chain-pilots/**/design.json`
- `shared/skills/design/examples/**/design.json`

Do not edit `tools/eval/results/**` snapshots.

- [ ] **Step 7: Verify Task 5**

Run:

```bash
bash tests/test-stage2-design-package.sh
bash tests/test-standard-chain-closure-contract.sh
bash tests/test-standard-chain-foundation-registry.sh
bash tests/test-design-skill-governance-redesign.sh
bash tests/test-design-dogfood-e2e.sh
python3 -m py_compile tools/community/canonical_design_confirmation_rules.py tools/community/canonical_design_errors.py
```

Expected: all pass and no active file outside historical snapshots contains `co_creation_summary`.

---

### Task 6: Align Formal PM And Design Fields With Downstream Consumers

**Files:**
- Modify: `contracts/standard-chain-field-consumption.yaml`
- Modify: `contracts/product-artifacts.yaml`
- Modify: `shared/skills/product-manager/contracts/brief.schema.json`
- Modify: `shared/skills/product-manager/contracts/phase-prd.schema.json`
- Modify: `shared/skills/product-manager/contracts/unit-definition.schema.json`
- Modify: `shared/skills/product-manager/templates/*.json`
- Modify: `shared/skills/design/contracts/design.schema.json`
- Modify: `shared/skills/design/templates/design.template.json`
- Modify: `tests/test-task-contract-consumer-alignment.sh`
- Modify: `tests/test-standard-chain-runtime-layering-contract.sh`

- [ ] **Step 1: Add consumer-alignment assertions**

Tests must prove these examples:

- PM `acceptance_criteria` and UNIT `verification_plan` are consumed by `test-design`, even if Design only references them.
- PM `risk_ledger` and `release_readiness` are consumed by `qa` and `delivery-owner`.
- PM `design_decision_candidates` and `technical_evidence_requirements` are consumed by Design.
- Design `verification_mapping` is consumed by `test-design`.
- Design `planning_constraints`, `migration_plan`, and `rollback_plan` are consumed by `tech-lead` and `delivery-owner`.

- [ ] **Step 2: Tighten field descriptions**

For retained fields, descriptions must state:

- what the field uniquely owns
- who writes it
- who consumes it
- whether downstream references or transforms it
- what fails if it is missing

Avoid descriptions that only say "summary", "details", "information", or "record" without a consumer and failure effect.

- [ ] **Step 3: Review `additionalProperties`**

For touched schema objects, set `additionalProperties: false` when all allowed fields are known. Keep `true` only when there is a documented compatibility reason in the schema description or nearby comment.

- [ ] **Step 4: Verify Task 6**

Run:

```bash
bash tests/test-task-contract-consumer-alignment.sh
bash tests/test-standard-chain-runtime-layering-contract.sh
bash tests/test-standard-chain-field-consumption-contract.sh
```

Expected: all pass and field-consumption contract explains the retained PM/Design field set.

---

### Task 7: End-To-End Pressure Test And Gate Closure

**Files:**
- Inspect and possibly modify: `tests/test-pm-design-chain-e2e.sh` after `rg -n 'product-manager-ledger|co_creation_summary' tests/test-pm-design-chain-e2e.sh`.
- Inspect and possibly modify: `tests/test-standard-chain-login-homepage-pilot.sh` after `rg -n 'product-manager-ledger|co_creation_summary' tests/test-standard-chain-login-homepage-pilot.sh`.
- Inspect and possibly modify: `tests/test-install-runtime-quick-canary.sh` after `rg -n 'product-manager-ledger|co_creation_summary' tests/test-install-runtime-quick-canary.sh`.

- [ ] **Step 1: Run focused contract tests**

Run:

```bash
bash tests/test-standard-chain-field-consumption-contract.sh
bash tests/test-standard-chain-co-creation-ledger-contract.sh
bash tests/test-stage2-product-manager-package.sh
bash tests/test-stage2-design-package.sh
bash tests/test-pm-design-chain-e2e.sh
```

Expected: all pass.

- [ ] **Step 2: Run full quick gate**

Run:

```bash
bash tests/run-all.sh --quick
```

Expected: pass.

- [ ] **Step 3: Run targeted full-tier tests affected by gate changes**

Run:

```bash
bash tests/test-standard-chain-hard-gate-boundary-contract.sh
bash tests/test-skill-output-and-gate-contract.sh
bash tests/test-standard-chain-foundation-registry.sh
bash tests/test-design-skill-governance-redesign.sh
```

Expected: all pass.

- [ ] **Step 4: Run final residue scan**

Run:

```bash
rg -n 'product-manager-ledger\.json|product_manager_ledger|co_creation_summary|design-ledger\.json|--producer design|--producer product-manager' \
  shared contracts tests tools \
  -g '!tools/eval/results/**' \
  -g '!docs/superpowers/plans/**'
```

Expected: no active dependency remains. Allowed hits must be explicit negative assertions in tests; document any allowed hit in the final report.

- [ ] **Step 5: Review git diff against scope**

Run:

```bash
git diff --stat
git diff -- contracts shared/skills/product-director shared/skills/product-manager shared/skills/design tools/community tools/eval/scripts tests
```

Expected: changes are inside this plan's scope. Any unrelated existing dirty changes remain untouched and are reported separately.

---

## Implementation Notes

- Run tasks serially. The shared contracts and field names are common dependencies; parallel execution before Task 1 and Task 2 are complete risks inconsistent tests.
- If Task 5 rename creates too broad a fixture update, do not keep both field names for compatibility. Stop and report the impacted active fixture set; compatibility aliases would violate the "one authority field" goal unless the user explicitly accepts a migration window.
- If a PM field appears unused by Design, do not delete it until `standard-chain-field-consumption.yaml` proves no `test-design`, `tech-lead`, `qa`, or `delivery-owner` consumer.
- If a schema currently uses `additionalProperties: true`, tighten only for touched objects with clear allowed fields. Report broader schema looseness outside the touched objects as follow-up.
- Do not edit `tools/eval/results/**`.

## Self-Review

- Spec coverage: Covers Director ledger retention, PM ledger removal, Design confirmation contract, field-level API semantics, downstream consumers, tests/eval/fixtures, and quick-gate verification.
- Placeholder scan: No `TBD`, `TODO`, or open-ended "add tests" steps remain; each task lists concrete files and commands.
- Type consistency: The new Design field is consistently named `design_stage_confirmations`; the new field-consumption contract is consistently named `contracts/standard-chain-field-consumption.yaml`.
