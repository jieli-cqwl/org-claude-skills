# fix-1: user-decision canonical shape gate

## Input

- Source: system review finding against `shared/skills/skill-harness/scripts/check_skill_harness_contract.py:332-337`.
- Symptom: `validate_user_decision_shape()` accepted malformed canonical fields when `decision_payload_digest` and `authority_proof.decision_payload_digest` were recomputed.
- Work dir: `docs/skill-harness/2026-04-20-standard-chain-harness-governance`.

## Environment Snapshot

| Check | Result |
| --- | --- |
| Branch | `skill-harness-std-governance` |
| Worktree before fix | clean |
| Latest completed commit before fix | `7b4578f T7 mark skill-harness package complete` |
| Existing fix reports | none |

## Observe

The following mutation reproduced the failure:

1. Start from `tests/fixtures/skill-harness/standard-chain/user-decision-gate.json`.
2. Change `authoritative_fields`, `authority_proof_refs`, `decision_basis_refs`, and `director_lock_digests` from their canonical array/object shapes into strings.
3. Recompute `decision_payload_digest` and `authority_proof.decision_payload_digest`.
4. Run `python3 shared/skills/skill-harness/scripts/check_skill_harness_contract.py <mutated.json>`.

Observed result before the fix: `[PASS] user-decision-shape-drift`.

Expected result: stable failure before digest acceptance.

## Hypotheses

| Hypothesis | Test | Result |
| --- | --- | --- |
| H1: digest mismatch hides the shape problem | Recomputed digest for malformed payload and reran checker | Confirmed: malformed payload passed before fix |
| H2: canonical schema permits these fields as strings | Read `contracts/canonical/schemas/runtime/user-decision.schema.json` | Excluded: schema requires canonical ref arrays and `director_lock_digests` object |
| H3: validator only checks presence/truthiness | Read `validate_user_decision_shape()` and `require_keys()` call path | Confirmed: user-decision shape was not type-checked before authority/digest checks |

## Root Cause

`shared/skills/skill-harness/scripts/check_skill_harness_contract.py:332-337` used `require_keys()` for canonical user-decision fields. `require_keys()` rejects missing or empty values, but does not validate list/object/string shape. Since `decision_payload_digest()` hashes whatever values are present, a malformed but internally self-consistent payload could pass.

Semantic trace:

- `validate_gate()` dispatches `gate_type=user_decision_gate` to `validate_user_decision()`.
- `validate_user_decision()` calls `validate_user_decision_shape()`.
- `validate_user_decision_shape()` only checked truthiness for canonical fields before authority and digest validation.

## Fix

failure_class: `FIXABLE`

Implemented:

- Added `shared/skills/skill-harness/scripts/check_skill_harness_user_decision.py` for user-decision shape, authority, baseline, and digest validation.
- Enforced:
  - `authoritative_fields`, `authority_proof_refs`, and `decision_basis_refs` are non-empty string arrays.
  - `director_lock_digests` is exactly an object with `brief` and `phase-prd` sha256 digests.
  - `decision_payload_digest` and authority proof digest use `sha256:<64 hex>`.
- Added `tests/fixtures/skill-harness/standard-chain/invalid-user-decision-shape.json`.
- Updated `tests/test-skill-harness-standard-chain-integration.sh` to require `USER_DECISION_SHAPE_INVALID`.

## RED / GREEN Evidence

| Step | Command | Result |
| --- | --- | --- |
| RED | `bash tests/test-skill-harness-standard-chain-integration.sh` | FAIL: invalid user decision shape unexpectedly passed |
| GREEN | `bash tests/test-skill-harness-standard-chain-integration.sh` | PASS |
| Direct negative | `python3 shared/skills/skill-harness/scripts/check_skill_harness_contract.py tests/fixtures/skill-harness/standard-chain/invalid-user-decision-shape.json` | FAIL with `USER_DECISION_SHAPE_INVALID` as expected |
| Mutation repro | recomputed digest after malformed canonical fields | FAIL with `USER_DECISION_SHAPE_INVALID` |

## Regression Proof

| Command | Result |
| --- | --- |
| `bash tests/test-skill-harness-responsibility-contract.sh` | PASS |
| `bash tests/test-skill-harness-main-content-noise.sh` | PASS |
| `bash tests/test-skill-harness-runtime-noise.sh` | PASS |
| `bash tests/test-skill-harness-legacy-label-migration.sh` | PASS |
| `bash tests/test-skill-harness-field-consumers.sh` | PASS |
| `bash tests/test-skill-harness-engineering-control.sh` | PASS |
| `bash tests/test-skill-harness-directory-capability.sh` | PASS |
| `bash tests/test-skill-harness-standard-chain-integration.sh` | PASS |
| `bash tests/test-skill-harness-dry-run.sh` | PASS |
| `bash tests/test-skill-harness-lightweight-path.sh` | PASS |
| `bash tests/test-skill-harness-contract.sh` | PASS |
| `bash tests/test-skill-harness-gates.sh` | PASS |
| `bash tests/test-skill-harness-migration.sh` | PASS |
| `bash tests/test-delivery-owner-phase3-contract.sh` | PASS |
| `bash tests/test-standard-chain-user-decision.sh` | PASS |
| `python3 -m py_compile shared/skills/skill-harness/scripts/check_skill_harness_contract.py shared/skills/skill-harness/scripts/check_skill_harness_dry_run.py shared/skills/skill-harness/scripts/check_skill_harness_user_decision.py` | PASS |
| function complexity check for checker/helper files | PASS |
| `python3 tools/community/check_task_plan_consistency.py docs/skill-harness/2026-04-20-standard-chain-harness-governance/tasks.md docs/skill-harness/2026-04-20-standard-chain-harness-governance/plan.md` | PASS |
| `git diff --check` | PASS |

## Four Questions

1. Root cause: canonical user-decision fields were checked for presence but not type/shape.
2. Completeness: fix covers all affected user-decision gate paths by moving user-decision validation into a dedicated helper used by the gate dispatcher.
3. New risk: helper split adds one imported module; `py_compile`, standard-chain integration, field-consumer smoke, and baseline tests passed.
4. Test coverage: new malformed-shape fixture locks the review finding; mutation repro also fails after recomputing digest.
