# Standard-chain Product-to-delivery Production Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `product-director -> product-manager -> tech-lead baseline -> delivery-owner -> signoff` chain production-ready for daily team use, with deterministic contracts, gates, runtime evidence, recovery, and signoff.

**Architecture:** Treat the design spec and field decision matrix as the source of truth. Close the contract surface first, then update schemas/templates/scripts/fixtures, then prove two happy-path pilots and all blocking failure modes with deterministic validators. The model may generate and judge semantics, but it must not be the control plane for field guessing, freshness, recovery, or signoff.

**Tech Stack:** Bash gate scripts, Python validators, YAML standard-chain contracts, JSON Schema artifacts, JSON fixtures, Markdown skill instructions.

---

## Source Of Truth

- Design spec: `docs/superpowers/specs/2026-05-31--standard-chain-product-to-delivery-production-readiness--design.md`
- Field matrix: `docs/superpowers/specs/2026-05-31--standard-chain-product-to-delivery-production-readiness--field-decision-matrix.md`
- Active chain contract: `contracts/standard-chain.yaml`
- Field consumption contract: `contracts/standard-chain-field-consumption.yaml`
- Canonical pilots:
  - `tests/fixtures/standard-chain-pilots/login-homepage-pilot`
  - `tests/fixtures/standard-chain-pilots/feedback-thanks-pilot`

## Completion Definition

This work is complete only when all of these are true:

- Every row in the field matrix is implemented or explicitly proven already implemented by active contracts, schemas, templates, scripts, fixtures, and tests.
- `contracts/standard-chain.yaml` and `contracts/standard-chain-field-consumption.yaml` cover retained active fields and reject removed active concepts.
- `plan.json.baseline_plan_version_ref` and scoped runtime `active_plan_version_ref` are not required or consumed by this chain.
- `chain_registry_digest` and Director lock digests are deterministic validation points, not hand-waved model-written facts.
- Delivery-owner DO-S1 consumes only baseline inputs; DO-S5 through DO-S8 consume runtime evidence at the correct stages.
- Runtime evidence is consumable through active `artifact-registry.json` entries, freshness checks, and task-level refs.
- `signoff-package.runtime_evidence_matrix` proves complete, fresh, active, non-superseded runtime evidence.
- `user-decision.json` and `target-change.json` remain separate decision channels.
- Both canonical pilots pass.
- Every failure mode `FM-01` through `FM-18` has a deterministic negative proof.
- `bash tests/run-all.sh --quick` passes.
- `bash tests/run-all.sh` passes before claiming production readiness.
- Two clean review loops find no new target-scope issue.

## Non-Goals

- Do not continue the separate test-system cleanup task.
- Do not edit `docs/archive/**`, `tools/eval/results/**`, raw transcripts, or historical outputs only to make text searches clean.
- Do not rewrite role internals unless their output contract cannot support delivery-owner intake, runtime evidence consumption, recovery, or signoff.
- Do not treat projection manifests, replay oracle records, or rendered HTML as canonical signoff truth.
- Do not loosen tests, skip tests, xfail tests, or replace deterministic gates with Markdown assertions.

## File Responsibility Map

- `tools/community/validate_standard_chain_field_decision_matrix.py`: persistent validator for the field decision matrix table shape, allowed decisions, cleanup/evidence closure, deterministic verification method, and unresolved human-decision blocks.
- `tests/test-standard-chain-product-delivery-production-readiness.sh`: quick targeted gate for the matrix validator and production-readiness contract smoke checks.
- `tests/test-standard-chain-product-delivery-negative-modes.sh`: full targeted gate for all 18 production-readiness failure modes.
- `tests/gate-plan.json`: include the new targeted gate in the `standard-chain` area so `tests/run-all.sh --quick` or full gate can run it according to tier.
- `tests/run-all.sh`: add any new Python validator to syntax compilation checks.
- `contracts/standard-chain.yaml`: active artifact key fields, stage inputs, stage boundaries, and terminal semantics.
- `contracts/standard-chain-field-consumption.yaml`: producer, authority, consumer, consumed_for, consume_mode, required_when, and failure_effect for every retained key field.
- `shared/skills/*/contracts/*.schema.json`: enforce artifact fields and failure blocking at the artifact boundary.
- `shared/skills/*/templates/*.template.json`: keep generated artifacts aligned with schemas and active contracts.
- `tools/community/validate_standard_chain_readiness.py`: end-to-end readiness gate for required files, stage-specific runtime evidence, QA route, active registry, freshness, and signoff.
- `tools/community/validate_readiness_contract.py`: registry, runtime identity, signoff, user-decision, and target-change semantic checks.
- `tools/community/readiness_runtime_checks.py`: task-level developer/verify runtime evidence identity and active task ref checks.
- `tools/community/readiness_signoff_checks.py`: runtime evidence matrix, registry active proof, stale/superseded, authority, and Director digest checks.
- `tools/community/replay_canonical_phase.py`: replay oracle extraction for fields that remain relevant to the two canonical pilots.
- `tests/fixtures/standard-chain-pilots/**`: happy-path fixture truth.
- `tests/fixtures/standard-chain-pilots/negative/FM-XX--*/`: persistent negative fixtures when the failure mode is too large for a generated temp mutation.
- Role `SKILL.md` files: align role instructions with the deterministic contract; no broad prose rewrite.

## Task-To-Criterion Map

| Success criterion | Tasks |
| --- | --- |
| SC-1 Contract cleanliness | Tasks 0, 1, 2 |
| SC-2 Stage boundaries | Tasks 1, 4, 6 |
| SC-3 Deterministic delivery-owner execution | Tasks 3, 4, 6 |
| SC-4 Runtime evidence consumability | Tasks 3, 5, 6 |
| SC-5 Hard-blocking failure paths | Task 6 |
| SC-6 Auditable signoff | Tasks 4, 5, 6 |
| SC-7 Separated human decisions | Tasks 4, 6 |
| SC-8 Repeatable pilot proof | Task 5 |
| SC-9 Production-readiness verification | Tasks 0 through 8 |

## Failure Mode Map

| Failure mode | Primary task | Required proof target |
| --- | --- | --- |
| FM-01 Missing baseline input | Task 6 | DO-S1 negative fixture removes one required baseline artifact. |
| FM-02 Director confirmation missing or failed | Task 6 | DO-S1 negative fixture mutates `director_confirmation.status`. |
| FM-03 Director lock digest drift | Task 4, Task 6 | Readiness/signoff validator blocks digest drift. |
| FM-04 Mixed baseline or tasks version | Task 3, Task 6 | Runtime identity validator blocks mixed refs. |
| FM-05 Plan/tasks version mismatch | Task 1, Task 6 | Intake validator blocks mismatch. |
| FM-06 Tasks not frozen or confirmed | Task 1, Task 6 | Intake validator blocks absent/failed `tasks.user_confirmation`. |
| FM-07 Task AC refs missing | Task 3, Task 6 | Dispatch/readiness validator blocks missing AC trace. |
| FM-08 QA obligations missing or uncovered | Task 3, Task 6 | DO-S1 or DO-S7 validator blocks missing QA handoff/coverage. |
| FM-09 Developer or verify evidence missing | Task 3, Task 6 | DO-S5 validator blocks missing task runtime evidence. |
| FM-10 Code review missing/stale/blocking | Task 3, Task 6 | DO-S6 validator blocks missing/stale/blocking review. |
| FM-11 QA result missing/not PASS/incomplete | Task 3, Task 6 | DO-S7 validator blocks bad QA route. |
| FM-12 Consistency action not consumed | Task 4, Task 6 | DO-S8 validator blocks unconsumed owner action. |
| FM-13 Evidence file not active in registry | Task 3, Task 6 | Registry validator blocks filesystem-only evidence. |
| FM-14 Registry lifecycle inactive/non-final | Task 3, Task 6 | Registry validator blocks inactive/stale/superseded entry. |
| FM-15 Signoff matrix missing coverage | Task 4, Task 6 | Signoff validator blocks missing runtime evidence matrix row. |
| FM-16 Target change invalidates evidence | Task 4, Task 6 | Target-change validator blocks stale evidence after invalidation. |
| FM-17 Required user decision absent | Task 4, Task 6 | User-decision validator blocks absent waiver/authorization/risk acceptance. |
| FM-18 READY_FOR_COMMIT treated as DELIVERED | Task 4, Task 6 | Delivery-state closeout validator blocks missing commit/equivalent delivery result. |

## Task 0: Add Matrix Closure Gate

**Files:**
- Create: `tools/community/validate_standard_chain_field_decision_matrix.py`
- Create: `tests/test-standard-chain-product-delivery-production-readiness.sh`
- Modify: `tests/run-all.sh`
- Modify: `tests/gate-plan.json`

- [x] **Step 1: Write the failing matrix gate**

Create `tests/test-standard-chain-product-delivery-production-readiness.sh` with this shape:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MATRIX="$ROOT/docs/superpowers/specs/2026-05-31--standard-chain-product-to-delivery-production-readiness--field-decision-matrix.md"
VALIDATOR="$ROOT/tools/community/validate_standard_chain_field_decision_matrix.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$MATRIX" ] || fail "missing field decision matrix"
[ -f "$VALIDATOR" ] || fail "missing matrix validator"

python3 "$VALIDATOR" --matrix "$MATRIX"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

python3 - "$MATRIX" "$TMP_DIR/missing-evidence.md" <<'PY'
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text(encoding="utf-8")
bad = source.replace("| Cleanup surface | Decision evidence |", "| Cleanup surface / evidence |", 1)
Path(sys.argv[2]).write_text(bad, encoding="utf-8")
PY
if python3 "$VALIDATOR" --matrix "$TMP_DIR/missing-evidence.md" >"$TMP_DIR/matrix_missing_evidence.out" 2>&1; then
  cat "$TMP_DIR/matrix_missing_evidence.out" >&2
  fail "matrix validator must reject collapsed cleanup/evidence column"
fi

python3 - "$MATRIX" "$TMP_DIR/needs-human-decision.md" <<'PY'
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text(encoding="utf-8")
bad = source.replace("| C-001 |", "| BAD-001 |", 1).replace("| keep |", "| needs-human-decision |", 1)
Path(sys.argv[2]).write_text(bad, encoding="utf-8")
PY
if python3 "$VALIDATOR" --matrix "$TMP_DIR/needs-human-decision.md" >"$TMP_DIR/matrix_human_decision.out" 2>&1; then
  cat "$TMP_DIR/matrix_human_decision.out" >&2
  fail "matrix validator must reject unresolved needs-human-decision rows"
fi

printf '[PASS] standard-chain product-delivery production readiness matrix\n'
```

Run:

```bash
bash tests/test-standard-chain-product-delivery-production-readiness.sh
```

Expected: FAIL with `missing matrix validator`.

- [x] **Step 2: Implement the validator**

Create `tools/community/validate_standard_chain_field_decision_matrix.py` with these required checks:

```python
EXPECTED_HEADER = [
    "ID",
    "Artifact",
    "JSONPath",
    "Decision",
    "Owner",
    "Consumer",
    "Write stage",
    "Read stage",
    "Purpose",
    "Source of truth",
    "Verification method",
    "Failure behavior",
    "Recovery owner",
    "Cleanup surface",
    "Decision evidence",
]
ALLOWED_DECISIONS = {"keep", "delete", "derive", "move", "rename", "needs-human-decision"}
DETERMINISTIC_TOKENS = {
    "schema",
    "validator",
    "check",
    "test",
    "preflight",
    "pilot",
    "contract",
    "readiness",
    "signoff",
    "assert",
}
```

The validator must:

- parse only the matrix table under `## Matrix`;
- require exactly the header above;
- require unique non-empty IDs;
- reject any empty cell;
- reject decisions outside `ALLOWED_DECISIONS`;
- reject every `needs-human-decision` row;
- reject a `keep` row whose verification method lacks a deterministic token;
- reject non-`keep` rows without cleanup surface and decision evidence;
- reject `derive` rows unless source of truth names a deterministic source such as digest, canonical value, active registry ref, locked fields, or another source artifact;
- require markers for `$.pre_review_issue_ledger`, `$.user_confirmation`, `$.active_tasks_version_ref`, `$.baseline_plan_version_ref`, `$.active_plan_version_ref`, `$.chain_registry_digest`, `$.runtime_evidence_matrix`, `$.actor_id`, `$.change_source`, delivery-state recovery fields, QA browser evidence, review integrity, consistency runtime fields, `artifact-registry.json`, `delivery-state.json`, `fix-result.json`, and projection/replay exclusion.

Run:

```bash
python3 tools/community/validate_standard_chain_field_decision_matrix.py \
  --matrix docs/superpowers/specs/2026-05-31--standard-chain-product-to-delivery-production-readiness--field-decision-matrix.md
bash tests/test-standard-chain-product-delivery-production-readiness.sh
```

Expected: both pass.

- [x] **Step 3: Wire the new gate**

Modify `tests/run-all.sh` syntax checks:

```bash
python3 -m py_compile "$ROOT/tools/community/validate_standard_chain_field_decision_matrix.py"
```

Modify `tests/gate-plan.json` by adding one `quick` `standard-chain` step:

```json
{
  "id": "standard-chain-product-delivery-production-readiness",
  "command": [
    "bash",
    "tests/test-standard-chain-product-delivery-production-readiness.sh"
  ],
  "area": "standard-chain",
  "tier": "quick",
  "tags": [
    "standard-chain",
    "contract",
    "production-readiness"
  ],
  "parallel_safe": true,
  "timeout_sec": 90
}
```

Run:

```bash
bash tests/run-all.sh --list --format=json | python3 -m json.tool >/dev/null
bash tests/test-run-all-runner-contract.sh
```

Expected: list output remains valid JSON and runner contract passes.

## Task 1: Close Standard-chain Key Fields And Field Consumption

**Files:**
- Modify: `contracts/standard-chain.yaml`
- Modify: `contracts/standard-chain-field-consumption.yaml`
- Modify: `tests/test-standard-chain-field-consumption-contract.sh`

- [x] **Step 1: Add red contract assertions**

Extend `tests/test-standard-chain-field-consumption-contract.sh` with Python assertions for the exact field decisions:

```python
required_key_fields = {
    "product-manager:phase-{N}/phase-prd.json": {"pre_review_issue_ledger"},
    "tech-lead:phase-{N}/tasks.json": {"user_confirmation"},
    "developer:phase-{N}/unit-{N}/tasks/{task_id}/developer-report.json": {
        "task_id",
        "active_tasks_version_ref",
        "task_scope",
        "file_changes",
        "self_testing",
        "fresh_proof",
    },
    "verify:phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json": {
        "task_id",
        "active_tasks_version_ref",
    },
    "review:phase-{N}/code-review-result.json": {
        "review_round",
        "active_tasks_version_ref",
        "evidence_integrity",
    },
    "qa:phase-{N}/qa-result.json": {"active_tasks_version_ref", "browser_tool", "entry_url", "browser_evidence"},
    "consistency-auditor:phase-{N}/consistency-audit-result.json": {
        "active_tasks_version_ref",
        "evidence_refs",
        "audit_scope",
        "mode",
        "runtime_chain",
    },
    "delivery-owner:phase-{N}/delivery-state.json": {
        "blocked_from_stage",
        "blocker_reason_code",
        "blocker_resolution_evidence_refs",
        "unblocked_by_ref",
    },
    "delivery-owner:phase-{N}/target-change.json": {"actor_id", "change_source"},
}
for stage_artifact, fields in required_key_fields.items():
    stage, artifact = stage_artifact.split(":", 1)
    actual = key_fields_for(stage, artifact)
    missing = fields - set(actual)
    if missing:
        raise SystemExit(f"{stage_artifact} missing key_fields: {', '.join(sorted(missing))}")

forbidden_key_fields = {
    "tech-lead:phase-{N}/plan.json": {"baseline_plan_version_ref"},
    "developer:phase-{N}/unit-{N}/tasks/{task_id}/developer-report.json": {"active_plan_version_ref"},
    "verify:phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json": {"active_plan_version_ref"},
    "review:phase-{N}/code-review-result.json": {"active_plan_version_ref"},
    "qa:phase-{N}/qa-result.json": {"active_plan_version_ref"},
    "consistency-auditor:phase-{N}/consistency-audit-result.json": {"active_plan_version_ref"},
}
for stage_artifact, fields in forbidden_key_fields.items():
    stage, artifact = stage_artifact.split(":", 1)
    actual = set(key_fields_for(stage, artifact))
    overlap = fields & actual
    if overlap:
        raise SystemExit(f"{stage_artifact} must not keep fields: {', '.join(sorted(overlap))}")
```

`key_fields_for(stage, artifact)` must be a local helper that reads `contracts/standard-chain.yaml` using `runtime_yaml.load_yaml` and returns the matching output `key_fields`.

Run:

```bash
bash tests/test-standard-chain-field-consumption-contract.sh
```

Expected: FAIL on currently missing contract coverage.

- [x] **Step 2: Update `contracts/standard-chain.yaml`**

Apply these exact decisions:

- Add `pre_review_issue_ledger` to product-manager `phase-{N}/phase-prd.json`.
- Add `user_confirmation` to tech-lead `phase-{N}/tasks.json`.
- Remove `baseline_plan_version_ref` from tech-lead `phase-{N}/plan.json` if present.
- Add runtime fields from the field matrix rows `R-001`, `V-001`, `Q-001`, `A-001`, `A-002`, `S-001`, `O-003`, and `X-002`.
- Do not add `active_plan_version_ref` anywhere in scoped runtime outputs.
- Keep DO-S1 required inputs limited to baseline artifacts and keep DO-S5 through DO-S8 runtime evidence stage inputs as stage-specific required inputs.

- [x] **Step 3: Update `contracts/standard-chain-field-consumption.yaml`**

For every added key field, add a field entry with the concrete producer, authority, consumer, required condition, and failure effect below. Do not use generic phrasing such as `consume FIELD from ARTIFACT artifact`; the existing contract test rejects that pattern.

| Artifact path | Fields | Producer | Authority | Consumer | Consume mode | Consumed for | Required when | Failure effect |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `docs/{feature}/phase-{N}/phase-prd.json` | `pre_review_issue_ledger` | product-manager | product-manager | product-manager, delivery-owner | gate | block PM handoff or delivery intake when pre-review blockers remain unresolved | PM review digest or downstream handoff is prepared | unresolved PM blockers can enter design/planning/delivery without owner routing |
| `docs/{feature}/phase-{N}/tasks.json` | `user_confirmation` | tech-lead | tech-lead | delivery-owner, developer, verify, qa | gate | prove the task registry was explicitly confirmed before dispatch and runtime evidence production | DO-S1 dispatch readiness or runtime evidence admission runs | delivery may start from an unconfirmed task registry |
| `docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/developer-report.json` | `task_id`, `active_tasks_version_ref`, `task_scope`, `file_changes`, `self_testing`, `fresh_proof` | developer | developer | verify, review, qa, delivery-owner | gate | prove task identity, active task freshness, implementation scope, changed surface, self-test, and fresh proof | developer evidence is consumed by DO-S5 through DO-S8 | runtime evidence cannot be tied to the active task or reviewed changed surface |
| `docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json` | `task_id`, `active_tasks_version_ref` | verify | verify | qa, delivery-owner | gate | prove verify evidence belongs to the active task registry | QA admission or DO-S5/DO-S8 consumes verify evidence | stale or cross-task verify evidence can satisfy closure |
| `docs/{feature}/phase-{N}/code-review-result.json` | `review_round`, `active_tasks_version_ref`, `evidence_integrity` | review | review | delivery-owner, qa | gate | prove review freshness, round identity, and evidence integrity before QA/signoff | DO-S6 or QA admission consumes review evidence | stale or integrity-failed review can pass into QA/signoff |
| `docs/{feature}/phase-{N}/qa-result.json` | `active_tasks_version_ref`, `browser_tool`, `entry_url`, `browser_evidence` | qa | qa | delivery-owner, consistency-auditor | gate | prove QA belongs to the active task registry and browser-required obligations used browser evidence | DO-S7 or DO-S8 consumes QA evidence | QA PASS can be accepted without active baseline or required browser proof |
| `docs/{feature}/phase-{N}/consistency-audit-result.json` | `active_tasks_version_ref`, `evidence_refs`, `audit_scope`, `mode`, `runtime_chain` | consistency-auditor | consistency-auditor | delivery-owner | gate | prove audit scope, evidence basis, mode, and runtime-chain currency before closeout | DO-S8 consumes consistency audit evidence | required owner action or stale runtime chain can be skipped |
| `docs/{feature}/phase-{N}/delivery-state.json` | `blocked_from_stage`, `blocker_reason_code`, `blocker_resolution_evidence_refs`, `unblocked_by_ref` | delivery-owner | delivery-owner | delivery-owner, consistency-auditor | gate | prove blocked/unblocked recovery origin, reason, resolution evidence, and unblock ref | recovery or resume is attempted | delivery can resume without auditable resolution proof |
| `docs/{feature}/phase-{N}/target-change.json` | `actor_id`, `change_source` | delivery-owner | user | delivery-owner, authority proof validator | gate | identify accountable actor and source of target-change authority | target change invalidates baseline or runtime evidence | evidence can be invalidated without accountable authority |

Run:

```bash
bash tests/test-standard-chain-field-consumption-contract.sh
```

Expected: pass.

## Task 2: Align Schemas, Templates, And Active Fixture Surface

**Files:**
- Modify: `shared/skills/product-manager/contracts/phase-prd.schema.json`
- Modify: `shared/skills/product-manager/templates/phase-prd.template.json`
- Modify: `shared/skills/tech-lead/contracts/plan.schema.json`
- Modify: `shared/skills/tech-lead/templates/plan.template.json`
- Modify: `shared/skills/tech-lead/contracts/tasks.schema.json`
- Modify: `shared/skills/tech-lead/templates/tasks.template.json`
- Modify: `shared/skills/developer/contracts/developer-report.schema.json`
- Modify: `shared/skills/developer/templates/developer-report.template.json`
- Modify: `shared/skills/verify/contracts/verify-result.schema.json`
- Modify: `shared/skills/verify/templates/verify-result.template.json`
- Modify: `shared/skills/review/contracts/code-review-result.schema.json`
- Modify: `shared/skills/review/templates/code-review-result.template.json`
- Modify: `shared/skills/qa/contracts/qa-result.schema.json`
- Modify: `shared/skills/qa/templates/qa-result.template.json`
- Modify: `shared/skills/consistency-audit/contracts/consistency-audit-result.schema.json`
- Modify: `shared/skills/consistency-audit/templates/consistency-audit-result.template.json`
- Modify: `shared/skills/delivery-owner/contracts/delivery-state.schema.json`
- Modify: `shared/skills/delivery-owner/templates/delivery-state.template.json`
- Modify fixtures under `tests/fixtures/standard-chain-pilots/**`
- Test: `tests/test-standard-chain-product-delivery-production-readiness.sh`
- Test: `tests/test-standard-chain-validator-stack.sh`

- [x] **Step 1: Add red active-surface assertions**

Extend `tests/test-standard-chain-product-delivery-production-readiness.sh` with JSON scans:

```python
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])

forbidden_runtime_fields = {"active_plan_version_ref"}
forbidden_canonical_noise_fields = {
    "parent_refs",
    "related_issue_ids",
    "title",
    "stage",
    "sort_key",
    "filter_tags",
    "jump_anchor",
}
scoped_fixture_roots = [
    root / "tests/fixtures/standard-chain-pilots/login-homepage-pilot",
    root / "tests/fixtures/standard-chain-pilots/feedback-thanks-pilot",
]
scoped_template_roots = [
    root / "shared/skills/product-manager/templates",
    root / "shared/skills/tech-lead/templates",
    root / "shared/skills/developer/templates",
    root / "shared/skills/verify/templates",
    root / "shared/skills/review/templates",
    root / "shared/skills/qa/templates",
    root / "shared/skills/consistency-audit/templates",
    root / "shared/skills/delivery-owner/templates",
]
runtime_artifacts = {
    "developer-report.json",
    "verify-result.json",
    "code-review-result.json",
    "qa-result.json",
    "consistency-audit-result.json",
}

def json_files_under(roots):
    for scan_root in roots:
        for path in sorted(scan_root.rglob("*.json")):
            yield path

for path in json_files_under(scoped_fixture_roots + scoped_template_roots):
    payload = json.loads(path.read_text(encoding="utf-8"))
    if path.name in runtime_artifacts:
        overlap = forbidden_runtime_fields & set(payload)
        if overlap:
            raise SystemExit(f"{path} keeps forbidden runtime fields: {sorted(overlap)}")
    if path.name != "phase-operational.projection-manifest.json" and "replay" not in path.parts and "views" not in path.parts:
        overlap = forbidden_canonical_noise_fields & set(payload)
        if overlap:
            raise SystemExit(f"{path} keeps canonical presentation fields: {sorted(overlap)}")
```

Run:

```bash
bash tests/test-standard-chain-product-delivery-production-readiness.sh
```

Expected: FAIL if scoped fixtures or templates still carry deleted active fields.

- [x] **Step 2: Remove `plan.json.baseline_plan_version_ref` from active plan surfaces**

Update `shared/skills/tech-lead/contracts/plan.schema.json`, `shared/skills/tech-lead/templates/plan.template.json`, and pilot `plan.json` fixtures:

- remove `baseline_plan_version_ref` from `required`;
- remove its property definition if it is only used for this scoped plan contract;
- remove the template field;
- remove it from `authoritative_fields` in fixtures if present.

The retained plan linkage remains:

```json
{
  "plan_version": "v1",
  "baseline_tasks_version_ref": "artifact://tasks/login-homepage-pilot.phase-1.tasks@tasks-v2#task-registry"
}
```

- [x] **Step 3: Ensure retained fields are present where schema already expects them**

For fields that already exist in schema but are missing from templates or pilots, update templates and fixtures. Required examples:

- `developer-report.fresh_proof`
- `qa-result.browser_evidence`
- `delivery-state.blocked_from_stage`
- `delivery-state.blocker_reason_code`
- `delivery-state.blocker_resolution_evidence_refs`
- `delivery-state.unblocked_by_ref`

Run:

```bash
bash tests/test-standard-chain-validator-stack.sh
bash tests/test-standard-chain-product-delivery-production-readiness.sh
```

Expected: both pass.

## Task 3: Enforce Runtime Evidence And Registry Consumability

**Files:**
- Modify: `tools/community/validate_standard_chain_readiness.py`
- Modify: `tools/community/validate_readiness_contract.py`
- Modify: `tools/community/readiness_runtime_checks.py`
- Modify: `tools/community/readiness_review_checks.py`
- Modify: `tools/community/delivery_owner_freshness.py`
- Modify: `shared/skills/delivery-owner/contracts/artifact-registry.schema.json`
- Modify: `shared/skills/delivery-owner/templates/artifact-registry.template.json`
- Test: `tests/test-standard-chain-readiness-gate.sh`
- Test: `tests/test-standard-chain-validator-stack.sh`

- [x] **Step 1: Add red runtime evidence negatives**

Extend `tests/test-standard-chain-readiness-gate.sh` or add helper cases in `tests/test-standard-chain-product-delivery-production-readiness.sh` for:

- developer-report exists on disk but has no active registry entry;
- verify-result active entry points to the wrong task;
- code-review-result has `active_tasks_version_ref` drift;
- qa-result is `PASS` but lacks active browser evidence when `qa_handoff_contract` has `browser_required`;
- consistency-audit-result has required owner action not consumed by delivery-state.

Each negative must call:

```bash
python3 "$ROOT/tools/community/validate_standard_chain_readiness.py" \
  --phase-dir "$CASE_DIR/phase-1" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json"
```

Expected for every negative: command exits non-zero and exposes a block contract with status, owner, reason, recovery condition, and `signoff_allowed=false`. If the current readiness validator only raises plain exceptions, add a small failure formatter before completing this task; a raw traceback does not prove the production-readiness failure contract.

- [x] **Step 2: Implement task runtime identity checks**

In `tools/community/readiness_runtime_checks.py`, enforce:

- every in-scope task has exactly one active developer-report and verify-result;
- each runtime artifact has `task_id`;
- `active_tasks_version_ref` matches active `tasks.json`;
- verify-result links to developer-report through `developer_report_ref`;
- stale or superseded registry entries cannot satisfy evidence consumption.

- [x] **Step 3: Implement registry active proof checks**

In `tools/community/validate_readiness_contract.py`, keep filesystem discovery as a candidate source only. The accepted source must be an active registry entry with:

```json
{
  "lifecycle_state": "FINALIZED",
  "active_for_consumption": true
}
```

Also enforce exactly one active registry entry per required artifact type/task scope.

Run:

```bash
bash tests/test-standard-chain-readiness-gate.sh
bash tests/test-standard-chain-validator-stack.sh
```

Expected: pass.

## Task 4: Close Delivery State, Signoff, User Decision, And Target Change Semantics

**Files:**
- Modify: `shared/skills/delivery-owner/contracts/delivery-state.schema.json`
- Modify: `shared/skills/delivery-owner/templates/delivery-state.template.json`
- Modify: `shared/skills/delivery-owner/contracts/signoff-package.schema.json`
- Modify: `shared/skills/delivery-owner/templates/signoff-package.template.json`
- Modify: `shared/skills/delivery-owner/contracts/user-decision.schema.json`
- Modify: `shared/skills/delivery-owner/templates/user-decision.template.json`
- Modify: `shared/skills/delivery-owner/contracts/target-change.schema.json`
- Modify: `shared/skills/delivery-owner/templates/target-change.template.json`
- Modify: `tools/community/readiness_signoff_checks.py`
- Modify: `tools/community/readiness_closure_checks.py`
- Test: `tests/test-standard-chain-user-decision.sh`
- Test: `tests/test-runtime-closeout-record.sh`
- Test: `tests/test-standard-chain-readiness-gate.sh`

- [x] **Step 1: Add red closeout and decision negatives**

Add tests for:

- `delivery-state.status=DELIVERED` without commit result or equivalent delivery result blocks;
- `READY_FOR_COMMIT` is accepted only as signoff/commit-handoff prepared;
- `user-decision.json` carrying `changed_target_type` blocks;
- `target-change.json` carrying `sign_off_status` blocks;
- target-change invalidates evidence and old evidence remains in `signoff-package.runtime_evidence_matrix`.

Expected command pattern:

```bash
bash tests/test-standard-chain-user-decision.sh
bash tests/test-runtime-closeout-record.sh
bash tests/test-standard-chain-readiness-gate.sh
```

Expected before implementation: at least one new assertion fails.

- [x] **Step 2: Implement signoff evidence matrix completeness**

In `tools/community/readiness_signoff_checks.py`, enforce every required runtime evidence type and task-level evidence row has:

```json
{
  "artifact_type": "developer-report",
  "artifact_ref": "artifact://developer-report/login-homepage-pilot.phase-1.unit-1.task-T1.developer-report@v1#runtime-status",
  "producer": "developer",
  "status": "VERIFIED",
  "freshness_basis_ref": "artifact://tasks/login-homepage-pilot.phase-1.tasks@tasks-v2#task-registry",
  "active_registry_proof": {
    "registry_ref": "artifact://artifact-registry/login-homepage-pilot.phase-1.artifact-registry@rev-4#active-entry:developer-report:login-homepage-pilot.phase-1.unit-1.task-T1.developer-report",
    "lifecycle_state": "FINALIZED",
    "active_for_consumption": true
  },
  "stale_superseded_check": "CURRENT"
}
```

Allowed runtime matrix status values are artifact-specific: `developer-report=VERIFIED`, `verify-result=PASS`, `code-review-result=PASS`, `qa-result=PASS`, `consistency-audit-result=CLOSED`, and triggered `fix-result=FIXED`.

The validator must reject narrative-only summaries and runtime evidence not backed by registry proof.

- [x] **Step 3: Implement decision channel separation**

Keep this invariant:

- `user-decision.json` records signoff, authorization, waiver, or risk acceptance.
- `target-change.json` records changes to scope, AC, goal, tasks, design target, or other baseline-changing facts.

Tests must fail if fields from one channel are accepted in the other.

Run:

```bash
bash tests/test-standard-chain-user-decision.sh
bash tests/test-runtime-closeout-record.sh
bash tests/test-standard-chain-readiness-gate.sh
```

Expected: pass.

## Task 5: Refresh Canonical Pilots And Replay Oracles

**Files:**
- Modify: `tests/fixtures/standard-chain-pilots/login-homepage-pilot/**`
- Modify: `tests/fixtures/standard-chain-pilots/feedback-thanks-pilot/**`
- Modify: `tools/community/replay_canonical_phase.py` only if retained fields must be replayed
- Test: `tests/test-standard-chain-login-homepage-pilot.sh`
- Test: `tests/test-standard-chain-feedback-thanks-pilot.sh`

- [x] **Step 1: Run pilots before fixture edits**

Run:

```bash
bash tests/test-standard-chain-login-homepage-pilot.sh
bash tests/test-standard-chain-feedback-thanks-pilot.sh
```

Expected: fail only on contract drift introduced by Tasks 1 through 4, or pass if fixtures are already aligned.

- [x] **Step 2: Update fixture artifacts**

For both pilots:

- remove `baseline_plan_version_ref` from `phase-1/plan.json`;
- remove `active_plan_version_ref` from runtime artifacts if present;
- remove canonical presentation/noise fields from JSON artifacts outside `views/**` and `replay/**`;
- add required runtime fields from the matrix when missing;
- update `artifact-registry.json` so every consumed runtime artifact has one active finalized entry;
- update `signoff-package.runtime_evidence_matrix` to cover developer, verify, review, QA, consistency, and triggered fix evidence;
- update replay oracle only for fields still intentionally replayed.

- [x] **Step 3: Verify both pilots**

Run:

```bash
bash tests/test-standard-chain-login-homepage-pilot.sh
bash tests/test-standard-chain-feedback-thanks-pilot.sh
```

Expected: both pass.

## Task 6: Add Failure-mode Negative Suite

**Files:**
- Create: `tools/community/standard_chain_negative_cases.py`
- Create: `tests/test-standard-chain-product-delivery-negative-modes.sh`
- Create when needed: `tests/fixtures/standard-chain-pilots/negative/FM-XX--*/`
- Test: `tests/test-standard-chain-product-delivery-negative-modes.sh`

- [x] **Step 1: Add a generated negative-case runner**

Create `tools/community/standard_chain_negative_cases.py` with a table:

```python
CASES = [
    ("FM-01", "missing required baseline input", mutate_remove_baseline_input),
    ("FM-02", "director confirmation missing or failed", mutate_director_confirmation_failed),
    ("FM-03", "director lock digest drift", mutate_director_digest_drift),
    ("FM-04", "mixed baseline or tasks version", mutate_mixed_versions),
    ("FM-05", "plan/tasks version mismatch", mutate_plan_tasks_version_mismatch),
    ("FM-06", "tasks not frozen or confirmed", mutate_tasks_unconfirmed),
    ("FM-07", "task acceptance refs missing", mutate_task_acceptance_refs_missing),
    ("FM-08", "qa handoff obligations missing", mutate_qa_obligation_missing),
    ("FM-09", "developer or verify evidence missing", mutate_runtime_evidence_missing),
    ("FM-10", "code review missing stale or blocking", mutate_code_review_blocking),
    ("FM-11", "qa result missing not pass or incomplete", mutate_qa_not_pass),
    ("FM-12", "consistency action not consumed", mutate_consistency_action_unconsumed),
    ("FM-13", "runtime evidence not active in registry", mutate_registry_inactive_evidence),
    ("FM-14", "registry lifecycle inactive", mutate_registry_lifecycle_inactive),
    ("FM-15", "signoff evidence matrix omits coverage", mutate_signoff_matrix_missing_row),
    ("FM-16", "target change invalidates evidence", mutate_target_change_invalidates_evidence),
    ("FM-17", "required user decision absent", mutate_user_decision_absent),
    ("FM-18", "ready for commit treated as delivered", mutate_delivered_without_commit),
]
```

Each mutator must copy a canonical pilot to a unique temp directory, change one primary condition, run `validate_standard_chain_readiness.py`, and assert non-zero exit plus the full failure contract:

```json
{
  "status": "BLOCKED",
  "owner": "delivery-owner",
  "reason": "FM-13 runtime evidence is not active in artifact-registry",
  "recovery_condition": "register exactly one FINALIZED active evidence entry before retry",
  "signoff_allowed": false
}
```

The expected owner and reason code may differ per `FM-XX`, but every case must prove all five keys. The negative runner must fail if a case only proves command failure without owner, reason, recovery condition, and no-signoff semantics.

- [x] **Step 2: Wire all 18 cases into the full targeted gate**

Create `tests/test-standard-chain-product-delivery-negative-modes.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 "$ROOT/tools/community/standard_chain_negative_cases.py" \
  --pilot "$ROOT/tests/fixtures/standard-chain-pilots/login-homepage-pilot" \
  --catalog "$ROOT/shared/runtime/standard-chain-catalog.json"

printf '[PASS] standard-chain product-delivery negative modes\n'
```

Add this full-tier gate-plan step:

```json
{
  "id": "standard-chain-product-delivery-negative-modes",
  "command": [
    "bash",
    "tests/test-standard-chain-product-delivery-negative-modes.sh"
  ],
  "area": "standard-chain",
  "tier": "full",
  "tags": [
    "standard-chain",
    "negative",
    "production-readiness"
  ],
  "parallel_safe": true,
  "timeout_sec": 180
}
```

The quick gate remains `tests/test-standard-chain-product-delivery-production-readiness.sh`; it must not run all 18 negative cases.

Run:

```bash
bash tests/test-standard-chain-product-delivery-negative-modes.sh
```

Expected: pass with all 18 negative cases proving block behavior.

```bash
bash tests/test-standard-chain-product-delivery-production-readiness.sh
```

Expected: still passes as a quick matrix/contract smoke gate.

## Task 7: Align Role Instructions With Contracts

**Files:**
- Modify: `shared/skills/product-manager/SKILL.md`
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `shared/skills/developer/SKILL.md`
- Modify: `shared/skills/verify/SKILL.md`
- Modify: `shared/skills/review/SKILL.md`
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/skills/consistency-audit/SKILL.md`
- Modify: `shared/skills/fix/SKILL.md`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Test: `tests/test-skill-output-and-gate-contract.sh`
- Test: `tests/test-standard-chain-skill-evals.sh`
- Test: `tests/test-test-assertion-boundary-contract.sh`

- [x] **Step 1: Add contract-driven instruction assertions**

Add or extend tests through structured contract surfaces, not direct shell `grep` or `rg` assertions over Skill Markdown natural-language bodies. Acceptable checks are:

- YAML/JSON contract checks against `contracts/standard-chain.yaml`, `contracts/standard-chain-field-consumption.yaml`, schema files, templates, and script outputs;
- Markdown checks only for stable machine-readable contract references such as exact file paths or fenced contract identifiers;
- the repository assertion-boundary gate proving no new low-signal natural-language Skill Markdown assertions were introduced.

The checks must enforce that role instructions do not:

- ask delivery-owner DO-S1 to read developer, verify, review, QA, consistency, or fix evidence;
- tell any runtime producer to write `active_plan_version_ref`;
- tell tech-lead to require `baseline_plan_version_ref`;
- present projection/replay artifacts as canonical signoff truth;
- mix `user-decision.json` and `target-change.json` semantics.

Run:

```bash
bash tests/test-skill-output-and-gate-contract.sh
bash tests/test-standard-chain-skill-evals.sh
bash tests/test-test-assertion-boundary-contract.sh
```

Expected: fail on any stale instruction.

- [x] **Step 2: Update only behavior-relevant prose**

Update instructions to name:

- fields each role must write;
- fields each downstream gate consumes;
- block condition and recovery owner;
- registry/freshness obligation before dispatching the next stage;
- signoff evidence boundary and target-change boundary.

Do not rewrite unrelated method guidance.

Run:

```bash
bash tests/test-skill-output-and-gate-contract.sh
bash tests/test-standard-chain-skill-evals.sh
bash tests/test-test-assertion-boundary-contract.sh
```

Expected: pass.

## Task 8: Final Gate And Review Loop

**Files:**
- Verify all files changed in Tasks 0 through 7.

- [x] **Step 1: Run targeted gates**

Run:

```bash
bash tests/test-standard-chain-product-delivery-production-readiness.sh
bash tests/test-standard-chain-product-delivery-negative-modes.sh
bash tests/test-standard-chain-field-consumption-contract.sh
bash tests/test-standard-chain-readiness-gate.sh
bash tests/test-standard-chain-validator-stack.sh
bash tests/test-standard-chain-login-homepage-pilot.sh
bash tests/test-standard-chain-feedback-thanks-pilot.sh
bash tests/test-standard-chain-user-decision.sh
bash tests/test-runtime-closeout-record.sh
```

Expected: all pass.

- [x] **Step 2: Run repository gates**

Run:

```bash
bash tests/run-all.sh --quick
bash tests/run-all.sh
```

Expected: both pass before claiming production readiness.

- [x] **Step 3: Review diff against scope**

Run:

```bash
git diff --check
git diff --stat
git diff -- contracts/standard-chain.yaml contracts/standard-chain-field-consumption.yaml
git diff -- tools/community tests shared/skills docs/superpowers
```

Expected:

- no whitespace errors;
- diff only touches task-2 production-readiness scope;
- no unrelated test-system cleanup;
- no archive/eval-result edits for search cleanliness;
- removed fields have matching tests;
- retained fields have owner, consumer, gate, failure, and recovery evidence.

- [x] **Step 4: Complete two clean review loops**

For each loop, restate:

- objective;
- success criteria;
- scope;
- evidence;
- target-scope risks.

Then review changed contracts, validators, fixtures, and tests. Fix only target-scope evidence-backed issues. Delivery is allowed only after two consecutive loops find no new target-scope issue.
