# Skill Harness Standard-Chain Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Upgrade `skill-harness` from lightweight baseline audit into a standard-chain Harness governance entry with final enums, deterministic proof gates, old-asset ownership, delivery-owner dry-run calibration, and a lightweight default path.

**Architecture:** Keep `SKILL.md` as the LLM-facing router. Move detailed contracts into focused references, schemas, fixtures, and Bash/Python gates. Existing tests remain baseline smoke; new implementation proof scripts provide RED -> GREEN coverage for the contracts defined in `design.md`.

**Tech Stack:** Markdown Skill files, Bash contract tests, Python 3 standard-library JSON/YAML/path checks, existing canonical contracts under `contracts/canonical`, existing `tools/community/check_task_plan_consistency.py`.

---

## Execution Preconditions

- Run in an isolated branch or worktree before editing implementation files.
- Run `git status --short` before kickoff and record the result in the final report.
- Stop before editing when a declared target file has pre-existing uncommitted changes not owned by this task.
- Treat `shared/skills/delivery-owner/*` as read-only calibration input for this plan.
- Do not use `tests/test-delivery-owner-phase3-contract.sh` as primary proof for new `skill-harness` contracts; it remains baseline smoke.

## File Boundaries

- Modify: `shared/skills/skill-harness/SKILL.md`
- Modify: `shared/skills/skill-harness/references/audit-method.md`
- Modify: `shared/skills/skill-harness/references/content-order-contract.md`
- Modify: `shared/skills/skill-harness/references/runtime-noise-contract.md`
- Create: `shared/skills/skill-harness/references/reference-contract.md`
- Create: `shared/skills/skill-harness/references/permission-script-contract.md`
- Create: `shared/skills/skill-harness/references/hook-adapter-contract.md`
- Create: `shared/skills/skill-harness/references/subagent-handoff-contract.md`
- Create: `shared/skills/skill-harness/references/example-contract.md`
- Create: `shared/skills/skill-harness/schemas/field-consumers.json`
- Modify: `shared/skills/skill-harness/scripts/check_skill_harness_contract.py`
- Modify: `shared/skills/skill-harness/scripts/manifest.json`
- Modify: `tests/fixtures/skill-harness/cases/*.json`
- Create or modify fixtures under `tests/fixtures/skill-harness/`
- Create: `tests/test-skill-harness-responsibility-contract.sh`
- Create: `tests/test-skill-harness-main-content-noise.sh`
- Create: `tests/test-skill-harness-runtime-noise.sh`
- Create: `tests/test-skill-harness-legacy-label-migration.sh`
- Create: `tests/test-skill-harness-field-consumers.sh`
- Create: `tests/test-skill-harness-engineering-control.sh`
- Create: `tests/test-skill-harness-directory-capability.sh`
- Create: `tests/test-skill-harness-standard-chain-integration.sh`
- Create: `tests/test-skill-harness-dry-run.sh`
- Create: `tests/test-skill-harness-lightweight-path.sh`
- Create: `docs/skill-harness/2026-04-20-standard-chain-harness-governance/delivery-owner-dry-run-report.json`
- Create: `docs/skill-harness/2026-04-20-standard-chain-harness-governance/delivery-owner-dry-run-report.md`
- Create: `docs/skill-harness/2026-04-20-standard-chain-harness-governance/verify-change-report.md`

### Task 1: Final Audit Enums And LLM Contract [T1]

Context: The active skill contains legacy delivery-owner calibration language. This task freezes final runtime fields while keeping legacy labels only in migration and baseline-smoke contexts.

Files:
- Modify: `shared/skills/skill-harness/SKILL.md`
- Modify: `shared/skills/skill-harness/references/audit-method.md`
- Create: `tests/test-skill-harness-responsibility-contract.sh`

1. [T1] Write the RED test for final runtime fields.

Create `tests/test-skill-harness-responsibility-contract.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/shared/skills/skill-harness/SKILL.md"
AUDIT="$ROOT/shared/skills/skill-harness/references/audit-method.md"

fail() { echo "[FAIL] $*" >&2; exit 1; }

grep -Fq 'audit_proof_type' "$SKILL" || fail "SKILL missing audit_proof_type"
grep -Fq 'overall_verdict' "$SKILL" || fail "SKILL missing overall_verdict"
grep -Fq 'dimension_result' "$SKILL" || fail "SKILL missing dimension_result"
grep -Fq 'legacy_baseline_label' "$SKILL" || fail "SKILL missing legacy_baseline_label boundary"
grep -Fq 'final_dimension_enum' "$AUDIT" || fail "audit method missing final dimension enum"
grep -Fq 'PASS / FAIL / COMMENT' "$AUDIT" || fail "audit method missing overall verdict enum"
grep -Fq 'Correctness PASS / Practice FAIL' "$AUDIT" || fail "audit method missing legacy mapping note"
if grep -Eq '(^|[^[:alnum:]_])proof_type([^[:alnum:]_]|$)' "$SKILL"; then
  fail "SKILL contains standalone proof_type"
fi
printf '[PASS] skill-harness responsibility contract\n'
```

2. [T1] Run the RED command.

Run: `bash tests/test-skill-harness-responsibility-contract.sh`
Expected: FAIL with one missing final-field message.

3. [T1] Update `SKILL.md` output contract.

Replace old output fields with this contract:

```markdown
Fields: `overall_verdict`, `dimension`, `dimension_result`, `finding_severity`, `file:line`, `evidence`, `impact`, `recommendation`, `audit_proof_type`, `proof_command`, `gate_type`, `legacy_baseline_label`.

Enums:
- `overall_verdict`: `PASS / FAIL / COMMENT`
- `dimension_result`: `PASS / FAIL / WARN / NOT_APPLICABLE`
- `finding_severity`: `S1 / S2 / S3 / INFO`
- `audit_proof_type`: `file_evidence / fixture_proof / fresh_proving`
- `legacy_baseline_label`: migration and baseline-smoke evidence only
```

4. [T1] Update `audit-method.md`.

Add final dimension and verdict sections:

```markdown
## Final Dimension Enum

`Trigger / Loading / Decision / Execution / Verification / Evolution / Main Content Noise / Chain Integration / Engineering Control / Directory Capability`

## Verdict Enum

`overall_verdict`: `PASS / FAIL / COMMENT`
`dimension_result`: `PASS / FAIL / WARN / NOT_APPLICABLE`
`finding_severity`: `S1 / S2 / S3 / INFO`
`dry_run_verdict`: `CONTINUE / STOP`

Legacy labels such as `Correctness PASS / Practice FAIL` remain migration evidence and never define active audit output.
```

5. [T1] Run the GREEN command.

Run: `bash tests/test-skill-harness-responsibility-contract.sh`
Expected: `[PASS] skill-harness responsibility contract`.

### Task 2: Checker Support For New Audit Fields [T2]

Context: The Python checker is the deterministic guard for enum drift, old active labels, audit/canonical proof-name collisions, and missing audit proof mode.

Files:
- Modify: `shared/skills/skill-harness/scripts/check_skill_harness_contract.py`
- Modify: `tests/fixtures/skill-harness/cases/*.json`
- Create: `tests/fixtures/skill-harness/cases/illegal-dimension.json`
- Create: `tests/fixtures/skill-harness/cases/illegal-verdict.json`
- Create: `tests/fixtures/skill-harness/cases/legacy-label-active-output.json`
- Create: `tests/fixtures/skill-harness/cases/missing-audit-proof-type.json`
- Create: `tests/fixtures/skill-harness/cases/standalone-proof-type.json`
- Create: `tests/test-skill-harness-main-content-noise.sh`
- Create: `tests/test-skill-harness-runtime-noise.sh`
- Create: `tests/test-skill-harness-legacy-label-migration.sh`

1. [T2] Write RED tests for enum and legacy-label rejection.

Create `tests/test-skill-harness-legacy-label-migration.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py"
CASES="$ROOT/tests/fixtures/skill-harness/cases"
fail() { echo "[FAIL] $*" >&2; exit 1; }
expect_fail() {
  label="$1"; shift
  if "$@" >/tmp/skill-harness-negative.out 2>&1; then
    fail "$label expected failure did not happen"
  fi
}

python3 "$CHECKER" "$CASES/delivery-owner-practice-risk.json"
expect_fail "legacy label active output" python3 "$CHECKER" "$CASES/legacy-label-active-output.json"
expect_fail "illegal dimension" python3 "$CHECKER" "$CASES/illegal-dimension.json"
expect_fail "illegal verdict" python3 "$CHECKER" "$CASES/illegal-verdict.json"
expect_fail "missing audit_proof_type" python3 "$CHECKER" "$CASES/missing-audit-proof-type.json"
expect_fail "standalone proof_type" python3 "$CHECKER" "$CASES/standalone-proof-type.json"
printf '[PASS] skill-harness legacy label migration\n'
```

2. [T2] Run the RED command.

Run: `bash tests/test-skill-harness-legacy-label-migration.sh`
Expected: FAIL because the new fixture files or checker rules are absent.

3. [T2] Update the positive baseline fixtures.

Change `tests/fixtures/skill-harness/cases/good-markdown-audit.json` to include final enum fields:

```json
{
  "sample_id": "good-markdown-audit",
  "mode": "human_markdown_audit",
  "overall_verdict": "PASS",
  "dimension": "Verification",
  "dimension_result": "PASS",
  "finding_severity": "INFO",
  "audit_proof_type": "file_evidence",
  "file_line": "shared/skills/example/SKILL.md:1",
  "evidence": ["shared/skills/example/SKILL.md:1"],
  "impact": "No blocking issue.",
  "recommendation": "Keep the audit in structured Markdown unless a named machine consumer requires JSON.",
  "proof_command": "bash tests/test-skill-harness-gates.sh",
  "manifest_command_exists": true,
  "active_alias": false,
  "hard_gate_position": "early",
  "expected_result": "pass"
}
```

Change `tests/fixtures/skill-harness/cases/delivery-owner-practice-risk.json` to include:

```json
{
  "sample_id": "delivery-owner-practice-risk",
  "mode": "calibration_audit",
  "overall_verdict": "FAIL",
  "dimension": "Main Content Noise",
  "dimension_result": "FAIL",
  "finding_severity": "S2",
  "legacy_baseline_label": "Correctness PASS / Practice FAIL",
  "audit_proof_type": "file_evidence",
  "file_line": "shared/skills/delivery-owner/SKILL.md:14",
  "evidence": ["shared/skills/delivery-owner/SKILL.md:14"],
  "impact": "Delivery-owner can be functionally correct while still teaching a noisy default runtime path.",
  "recommendation": "Keep closed-loop ownership and move state-heavy mechanics into engineering gates or focused references.",
  "proof_command": "bash tests/test-skill-harness-gates.sh",
  "manifest_command_exists": true,
  "active_alias": false,
  "hard_gate_position": "early",
  "expected_result": "pass"
}
```

4. [T2] Migrate existing negative baseline fixtures.

Update existing negative fixtures so they use final dimensions and include `audit_proof_type`, while preserving their intended failure code:

| Fixture | Final dimension | Intended failure |
| --- | --- | --- |
| `active-alias.json` | `Evolution` | `ACTIVE_ALIAS` |
| `darwin-tail-hard-gate.json` | `Loading` | `CONTENT_ORDER` |
| `invalid-file-line.json` | `Verification` | `INVALID_FILE_LINE` |
| `json-without-consumer.json` | `Engineering Control` | `JSON_WITHOUT_CONSUMER` |
| `markdown-fact-source.json` | `Engineering Control` | `MARKDOWN_FACT_SOURCE` |
| `missing-command.json` | `Verification` | `MISSING_COMMAND` |
| `missing-recommendation.json` | `Verification` | `MISSING_RECOMMENDATION` |
| `no-evidence-fail.json` | `Verification` | `NEED_EVIDENCE` |

5. [T2] Add new negative fixtures.

Create `illegal-dimension.json` with `dimension: "Practice"`.
Create `illegal-verdict.json` with `overall_verdict: "Correctness PASS / Practice FAIL"`.
Create `legacy-label-active-output.json` with `legacy_baseline_label` and `mode: "active_audit_output"`.
Create `missing-audit-proof-type.json` without `audit_proof_type`.
Create `standalone-proof-type.json` with `proof_type: "file_evidence"` and no `audit_proof_type`.

6. [T2] Update `check_skill_harness_contract.py`.

Add constants:

```python
FINAL_DIMENSIONS = {
    "Trigger", "Loading", "Decision", "Execution", "Verification", "Evolution",
    "Main Content Noise", "Chain Integration", "Engineering Control", "Directory Capability",
}
OVERALL_VERDICTS = {"PASS", "FAIL", "COMMENT"}
DIMENSION_RESULTS = {"PASS", "FAIL", "WARN", "NOT_APPLICABLE"}
SEVERITIES = {"S1", "S2", "S3", "INFO"}
AUDIT_PROOF_TYPES = {"file_evidence", "fixture_proof", "fresh_proving"}
```

Add checks that reject:

```text
dimension not in FINAL_DIMENSIONS
overall_verdict not in OVERALL_VERDICTS
dimension_result not in DIMENSION_RESULTS
finding_severity not in SEVERITIES
proof_type present in audit fixtures
audit_proof_type missing
mode active_audit_output with legacy_baseline_label present
```

7. [T2] Create thin wrappers for main-content and runtime-noise gates.

Create `tests/test-skill-harness-main-content-noise.sh` and `tests/test-skill-harness-runtime-noise.sh` as wrappers that run the checker against `delivery-owner-practice-risk.json`, `illegal-dimension.json`, and `legacy-label-active-output.json`, then print `[PASS]` with their script names.

8. [T2] Run GREEN commands.

Run:

```bash
bash tests/test-skill-harness-legacy-label-migration.sh
bash tests/test-skill-harness-main-content-noise.sh
bash tests/test-skill-harness-runtime-noise.sh
bash tests/test-skill-harness-gates.sh
```

Expected: all print `[PASS]`.

### Task 3: Field Consumers, Engineering Control, And Old Asset Ownership [T3]

Context: Old `skill-audit` knowledge must be actively consumed, converted to fixtures, deferred with a trigger, or left in archive. Runtime fields and retained assets need machine-checkable consumers and failure semantics.

Files:
- Create: `shared/skills/skill-harness/references/reference-contract.md`
- Create: `shared/skills/skill-harness/references/permission-script-contract.md`
- Create: `shared/skills/skill-harness/references/hook-adapter-contract.md`
- Create: `shared/skills/skill-harness/references/subagent-handoff-contract.md`
- Create: `shared/skills/skill-harness/references/example-contract.md`
- Create: `shared/skills/skill-harness/schemas/field-consumers.json`
- Create: `tests/fixtures/skill-harness/field-consumers/invalid-command.json`
- Create: `tests/fixtures/skill-harness/field-consumers/invalid-consumer.json`
- Create: `tests/fixtures/skill-harness/field-consumers/missing-drop-condition.json`
- Create: `tests/fixtures/skill-harness/legacy-assets/asset-ownership.json`
- Create: `tests/fixtures/skill-harness/legacy-assets/invalid-missing-target.json`
- Create: `tests/fixtures/skill-harness/legacy-assets/invalid-duplicate-source.json`
- Create: `tests/fixtures/skill-harness/legacy-assets/invalid-immediate-and-triggered.json`
- Create: `tests/test-skill-harness-field-consumers.sh`
- Create: `tests/test-skill-harness-engineering-control.sh`
- Create: `tests/test-skill-harness-directory-capability.sh`

1. [T3] Write the RED field-consumer test.

Create `tests/test-skill-harness-field-consumers.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIELD="$ROOT/shared/skills/skill-harness/schemas/field-consumers.json"
fail() { echo "[FAIL] $*" >&2; exit 1; }
expect_fail() {
  label="$1"; shift
  if "$@" >/tmp/skill-harness-field-consumer-negative.out 2>&1; then
    fail "$label expected failure did not happen"
  fi
}
[ -f "$FIELD" ] || fail "missing field-consumers.json"
python3 - "$FIELD" "$ROOT" <<'PY'
import json, os, shlex, subprocess, sys
from pathlib import Path

path = Path(sys.argv[1])
root = Path(sys.argv[2])
data = json.load(path.open(encoding="utf-8"))
required_keys = {"field", "consumer", "read_purpose", "validation_command", "drop_condition", "failure_state"}
required_fields = {
    "audit_proof_type", "legacy_baseline_label", "dimension",
    "dimension_result", "finding_severity",
}
seen = set()
allowed_consumers = {
    "check_skill_harness_contract.py",
    "human_projection",
    "hook_adapter",
    "release_gate",
    "runner",
    "validator",
}

def resolve_validation_script(command: str) -> Path:
    parts = shlex.split(command)
    if len(parts) >= 2 and parts[0] in {"bash", "python3", "python"}:
        candidate = root / parts[1]
        if candidate.exists():
            return candidate
    raise SystemExit(f"validation command is not repo-local or executable: {command}")

def validate_consumer(consumer: str) -> None:
    if consumer in allowed_consumers:
        return
    candidate = root / consumer
    if candidate.exists():
        return
    raise SystemExit(f"consumer does not resolve to allowed type or repo path: {consumer}")

for row in data["fields"]:
    missing = required_keys - row.keys()
    if missing:
        raise SystemExit(f"missing keys: {sorted(missing)}")
    if not row["consumer"] or not row["validation_command"] or not row["drop_condition"] or not row["failure_state"]:
        raise SystemExit(f"incomplete consumer row: {row.get('field')}")
    validate_consumer(row["consumer"])
    script = resolve_validation_script(row["validation_command"])
    if os.environ.get("SKILL_HARNESS_FIELD_CONSUMER_SKIP_SELF") != "1":
        env = os.environ.copy()
        env["SKILL_HARNESS_FIELD_CONSUMER_SKIP_SELF"] = "1"
        subprocess.run(shlex.split(row["validation_command"]), cwd=root, env=env, timeout=30, check=True)
    if str(script.relative_to(root)).startswith("docs/"):
        raise SystemExit(f"validation command must not live under docs: {row['validation_command']}")
    seen.add(row["field"])
missing_fields = required_fields - seen
if missing_fields:
    raise SystemExit(f"missing consumer coverage: {sorted(missing_fields)}")
print("[PASS] field consumer coverage")
PY
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py"
FIXTURES="$ROOT/tests/fixtures/skill-harness/field-consumers"
expect_fail "invalid command" python3 "$CHECKER" "$FIXTURES/invalid-command.json"
expect_fail "invalid consumer" python3 "$CHECKER" "$FIXTURES/invalid-consumer.json"
expect_fail "missing drop condition" python3 "$CHECKER" "$FIXTURES/missing-drop-condition.json"
printf '[PASS] skill-harness field consumers\n'
```

2. [T3] Run the RED field-consumer command.

Run: `bash tests/test-skill-harness-field-consumers.sh`
Expected: FAIL with `missing field-consumers.json`.

3. [T3] Create `field-consumers.json`.

Use this shape and include every `required_fields` entry from the test. Each `consumer` must be an allowed runtime consumer type or a repo path. Each `validation_command` must resolve to a repo-local script and pass the controlled smoke run used by the test:

```json
{
  "fields": [
    {
      "field": "audit_proof_type",
      "consumer": "check_skill_harness_contract.py",
      "read_purpose": "separate audit evidence modes from canonical authority proof_type",
      "validation_command": "bash tests/test-skill-harness-legacy-label-migration.sh",
      "drop_condition": "audit output no longer has proof fields",
      "failure_state": "AUDIT_PROOF_TYPE_INVALID"
    }
  ]
}
```

4. [T3] Add field-consumer negative fixtures and checker support.

Create `invalid-command.json`, `invalid-consumer.json`, and `missing-drop-condition.json` under `tests/fixtures/skill-harness/field-consumers/`. Update `check_skill_harness_contract.py` so those fixtures fail with stable field-consumer errors.

5. [T3] Write the RED directory capability test.

Create `tests/test-skill-harness-directory-capability.sh` to validate `asset-ownership.json` and reject invalid fixtures:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="$ROOT/tests/fixtures/skill-harness/legacy-assets/asset-ownership.json"
fail() { echo "[FAIL] $*" >&2; exit 1; }
expect_fail() {
  label="$1"; shift
  if "$@" >/tmp/skill-harness-directory-negative.out 2>&1; then
    fail "$label expected failure did not happen"
  fi
}
[ -f "$DATA" ] || fail "missing asset-ownership.json"
python3 "$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py" "$DATA"
expect_fail "missing target" python3 "$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py" "$ROOT/tests/fixtures/skill-harness/legacy-assets/invalid-missing-target.json"
expect_fail "duplicate source" python3 "$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py" "$ROOT/tests/fixtures/skill-harness/legacy-assets/invalid-duplicate-source.json"
expect_fail "immediate and triggered" python3 "$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py" "$ROOT/tests/fixtures/skill-harness/legacy-assets/invalid-immediate-and-triggered.json"
printf '[PASS] skill-harness directory capability\n'
```

6. [T3] Create `asset-ownership.json`.

Include entries for:

```text
audit-method
runtime-noise-contract
reference-contract
permission-script-contract
hook-adapter-contract
subagent-handoff-contract
field-consumers
schemas
evals
examples
templates-renderer
optimization-plan
verification-result
old-runtime-entry
old-agent-exposure
permission-profiles
source-map
quality-dimension-mapping
old-scripts-manifest
old-audit-runner-scripts
old-artifact-builders
archive-readme-docs
```

Each entry must include `source_path`, `target_action`, `consumer`, `validation_command`, `drop_condition`, and `failure_state`. Each entry must include exactly one of `immediate_target_path`, `target_path_when_triggered`, or `archive_boundary`. Immediate and archive paths must exist by the GREEN step.

7. [T3] Add checker support for directory capability.

Update `check_skill_harness_contract.py` so `asset-ownership.json` checks:

```text
target_action is one of keep_inline_summary, route_to_reference, port_to_contract, move_to_fixture, triggered_artifact, archive_only
source_path exists
no duplicate source_path across active ownership rows
exactly one target mode is present
immediate_target_path and archive_boundary paths exist
target_path_when_triggered has deferred_until and consumer
validation_command is non-empty and points to a known test command
validation_command resolves to a repo-local script and passes a controlled smoke run
consumer resolves to an allowed runtime consumer type or a repo path
consumer target, validation script, manifest, test, or reference contains a reverse reference to asset id, source path, or target path
```

8. [T3] Write the RED engineering-control test.

Create `tests/test-skill-harness-engineering-control.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/shared/skills/skill-harness/scripts/manifest.json"
FIELD="$ROOT/shared/skills/skill-harness/schemas/field-consumers.json"
fail() { echo "[FAIL] $*" >&2; exit 1; }
[ -f "$MANIFEST" ] || fail "missing manifest"
[ -f "$FIELD" ] || fail "missing field-consumers"
python3 - "$MANIFEST" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
required = {"id", "path", "owner", "allowed_args", "timeout_seconds", "output_root", "allowed_input_roots", "failure_state"}
for script in data["scripts"]:
    missing = required - script.keys()
    if missing:
        raise SystemExit(f"manifest script missing keys: {sorted(missing)}")
    if not script["owner"] or not script["failure_state"] or script["timeout_seconds"] <= 0:
        raise SystemExit(f"incomplete manifest script: {script.get('id')}")
print("[PASS] manifest engineering control")
PY
bash "$ROOT/tests/test-skill-harness-field-consumers.sh"
bash "$ROOT/tests/test-skill-harness-directory-capability.sh"
printf '[PASS] skill-harness engineering control\n'
```

9. [T3] Create active references.

Each new reference file must include `Trigger / Read / Expect / Consume / Evidence / Sync` and reference its matching old archive path.

10. [T3] Run GREEN commands.

Run:

```bash
bash tests/test-skill-harness-field-consumers.sh
bash tests/test-skill-harness-directory-capability.sh
bash tests/test-skill-harness-engineering-control.sh
```

Expected: all print `[PASS]`.

### Task 4: Standard-Chain Gate Integration [T4]

Context: Standard-chain governance needs full role catalog coverage, conditional gate/proof fields, canonical user-decision authorization, and manifest input-root alignment.

Files:
- Create: `tests/fixtures/skill-harness/standard-chain/role-catalog.json`
- Create: `tests/fixtures/skill-harness/standard-chain/machine-gate.json`
- Create: `tests/fixtures/skill-harness/standard-chain/human-review-gate.json`
- Create: `tests/fixtures/skill-harness/standard-chain/user-decision-gate.json`
- Create: `tests/fixtures/skill-harness/standard-chain/file-evidence.json`
- Create: `tests/fixtures/skill-harness/standard-chain/fixture-proof.json`
- Create: `tests/fixtures/skill-harness/standard-chain/fresh-proving.json`
- Create negative fixtures under `tests/fixtures/skill-harness/standard-chain/`
- Create: `tests/test-skill-harness-standard-chain-integration.sh`
- Modify: `shared/skills/skill-harness/scripts/check_skill_harness_contract.py`
- Modify: `shared/skills/skill-harness/scripts/manifest.json`

1. [T4] Write the RED standard-chain integration test.

Create `tests/test-skill-harness-standard-chain-integration.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py"
CASES="$ROOT/tests/fixtures/skill-harness/standard-chain"
MANIFEST="$ROOT/shared/skills/skill-harness/scripts/manifest.json"
fail() { echo "[FAIL] $*" >&2; exit 1; }
expect_fail() {
  label="$1"; shift
  if "$@" >/tmp/skill-harness-standard-chain.out 2>&1; then
    fail "$label expected failure did not happen"
  fi
}
python3 - "$MANIFEST" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
roots = set()
for script in data["scripts"]:
    roots.update(script.get("allowed_input_roots", []))
if "tests/fixtures/skill-harness/standard-chain" not in roots:
    raise SystemExit("manifest missing standard-chain input root")
print("[PASS] manifest standard-chain root")
PY
for case in role-catalog machine-gate human-review-gate user-decision-gate file-evidence fixture-proof fresh-proving; do
  python3 "$CHECKER" "$CASES/$case.json"
done
for case in missing-gate-fields missing-user-authority missing-evidence-locator missing-fixture-command missing-proof-command proof-type-mismatch channel-mismatch digest-mismatch stale-baseline; do
  expect_fail "$case" python3 "$CHECKER" "$CASES/$case.json"
done
printf '[PASS] skill-harness standard-chain integration\n'
```

2. [T4] Run the RED command.

Run: `bash tests/test-skill-harness-standard-chain-integration.sh`
Expected: FAIL because fixtures, manifest input roots, or checker rules are absent.

3. [T4] Add role catalog fixture.

`role-catalog.json` must list:

```text
product-director
product-manager
design
test-design
tech-lead
delivery-owner
developer
verify
review
qa
sign-off
archive
```

Each role entry must include `role`, `input`, `output`, `state_transition`, `hard_gate`, `evidence`, `consumer`, and `handoff_boundary`.

4. [T4] Add gate and proof fixtures.

`machine-gate.json` must include `gate_type: "machine_gate"`, `must_block_when`, and `failure_state`.
`human-review-gate.json` must include `gate_type: "human_review_gate"`, `review_owner`, `verdict_field`, `block_when`, and `evidence_ref`.
`user-decision-gate.json` must include canonical envelope fields, user-decision fields, `allowed_final_decision_sources`, authority checks, actor/channel checks, and active/baseline refs.
`file-evidence.json` must include `audit_proof_type: "file_evidence"`, `file_line`, and `evidence_locator`.
`fixture-proof.json` must include `audit_proof_type: "fixture_proof"`, `fixture_path`, and `fixture_command`.
`fresh-proving.json` must include `audit_proof_type: "fresh_proving"`, `freshness_required: true`, and `proof_command`.

5. [T4] Add negative fixtures.

Create these negative cases:

```text
missing-gate-fields
missing-user-authority
missing-evidence-locator
missing-fixture-command
missing-proof-command
proof-type-mismatch
channel-mismatch
digest-mismatch
stale-baseline
```

6. [T4] Update checker gate and proof rules.

Rules:

```text
machine_gate requires must_block_when and failure_state
human_review_gate requires review_owner, verdict_field, block_when, evidence_ref
user_decision_gate requires canonical envelope, user-decision required fields, authority_proof_refs, decision_payload_digest, actor/channel match, active/baseline refs, and allowed_final_decision_sources from contracts/canonical/authority-registry.yaml
user_decision_gate reads decision_source_rules.required_proof_type and decision_source_rules.allowed_channels
file_evidence requires file_line and evidence_locator
fixture_proof requires fixture_path and fixture_command
fresh_proving requires freshness_required=true and proof_command
```

7. [T4] Update manifest input roots.

Add `tests/fixtures/skill-harness/standard-chain` to the `check-contract` `allowed_input_roots` entry in `shared/skills/skill-harness/scripts/manifest.json`.

8. [T4] Add standard-chain field consumers.

Update `shared/skills/skill-harness/schemas/field-consumers.json` and `tests/test-skill-harness-field-consumers.sh` so these fields are covered and their validation commands resolve to repo-local scripts:

```text
gate_type
allowed_final_decision_sources
must_verify_authority_proof_refs
must_verify_payload_digest
must_match_actor_and_channel
decision_payload_digest
baseline_plan_version_ref
active_plan_version_ref
```

Run: `bash tests/test-skill-harness-field-consumers.sh`
Expected: `[PASS] skill-harness field consumers`.

9. [T4] Run canonical user-decision baseline command.

Run: `bash tests/test-standard-chain-user-decision.sh`
Expected: `[PASS] standard chain user decision`.

10. [T4] Run the GREEN command.

Run: `bash tests/test-skill-harness-standard-chain-integration.sh`
Expected: `[PASS] skill-harness standard-chain integration`.

### Task 5: Delivery-Owner Dry-Run Calibration [T5]

Context: `delivery-owner` is the calibration sample. The implementation must prove that `skill-harness` can find high-value issues against real semantic lines before the plan proceeds to final packaging.

Files:
- Read: `shared/skills/delivery-owner/SKILL.md`
- Create: `tests/fixtures/skill-harness/dry-run/delivery-owner-continue.json`
- Create: `tests/fixtures/skill-harness/dry-run/delivery-owner-stop-abstract.json`
- Create: `tests/fixtures/skill-harness/dry-run/delivery-owner-stop-duplicate.json`
- Create: `tests/test-skill-harness-dry-run.sh`
- Create: `docs/skill-harness/2026-04-20-standard-chain-harness-governance/delivery-owner-dry-run-report.json`
- Create: `docs/skill-harness/2026-04-20-standard-chain-harness-governance/delivery-owner-dry-run-report.md`
- Modify: `shared/skills/skill-harness/scripts/check_skill_harness_contract.py`
- Modify: `shared/skills/skill-harness/scripts/manifest.json`

1. [T5] Write the RED dry-run test.

Create `tests/test-skill-harness-dry-run.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py"
REPORT="$ROOT/docs/skill-harness/2026-04-20-standard-chain-harness-governance/delivery-owner-dry-run-report.json"
CASES="$ROOT/tests/fixtures/skill-harness/dry-run"
fail() { echo "[FAIL] $*" >&2; exit 1; }
expect_fail() {
  label="$1"; shift
  if "$@" >/tmp/skill-harness-dry-run-negative.out 2>&1; then
    fail "$label expected failure did not happen"
  fi
}
[ -f "$REPORT" ] || fail "missing delivery-owner dry-run report"
python3 "$CHECKER" "$CASES/delivery-owner-continue.json"
python3 "$CHECKER" "$REPORT"
expect_fail "abstract stop" python3 "$CHECKER" "$CASES/delivery-owner-stop-abstract.json"
expect_fail "duplicate stop" python3 "$CHECKER" "$CASES/delivery-owner-stop-duplicate.json"
printf '[PASS] skill-harness dry-run\n'
```

2. [T5] Run the RED command.

Run: `bash tests/test-skill-harness-dry-run.sh`
Expected: FAIL because the report and dry-run fixtures are absent.

3. [T5] Add dry-run validation rules.

Update `check_skill_harness_contract.py` so `dry_run_verdict=CONTINUE` requires:

```text
at least 3 high_value_finding entries
at least 2 distinct dimensions
at least 1 finding in Engineering Control or Chain Integration
each finding has success_criterion_ref, implementation_boundary_ref, dimension_spread, proof_or_gate_ref, next_implementation_object, expected_benefit, stop_condition, and non_duplicate=true
file_line points to a real non-frontmatter line in shared/skills/delivery-owner/SKILL.md
```

`dry_run_verdict=STOP` must be returned when findings are abstract, duplicated, missing an implementation object, missing proof/gate, or concentrated in one low-value dimension.

4. [T5] Create dry-run fixtures.

`delivery-owner-continue.json` must contain 3 high-value findings anchored to real delivery-owner lines:

```text
shared/skills/delivery-owner/SKILL.md:14
shared/skills/delivery-owner/SKILL.md:37
shared/skills/delivery-owner/SKILL.md:40
```

Use `delivery-owner-stop-abstract.json` for missing `file_line` or missing proof/gate. Use `delivery-owner-stop-duplicate.json` for repeated root cause and same implementation object.

5. [T5] Write the real dry-run report.

Create `delivery-owner-dry-run-report.json` with the same validation shape as `delivery-owner-continue.json`, sourced from the current `shared/skills/delivery-owner/SKILL.md` read-only target. Create `delivery-owner-dry-run-report.md` as the human projection of the JSON report.

6. [T5] Update manifest input roots.

Add `tests/fixtures/skill-harness/dry-run` and `docs/skill-harness/2026-04-20-standard-chain-harness-governance` to `check-contract.allowed_input_roots`.

7. [T5] Add dry-run field consumers.

Update `shared/skills/skill-harness/schemas/field-consumers.json` and `tests/test-skill-harness-field-consumers.sh` so these fields are covered and their validation commands resolve to repo-local scripts:

```text
dry_run_verdict
high_value_finding
next_implementation_object
expected_benefit
stop_condition
proof_or_gate_ref
```

Run: `bash tests/test-skill-harness-field-consumers.sh`
Expected: `[PASS] skill-harness field consumers`.

8. [T5] Run the GREEN command.

Run: `bash tests/test-skill-harness-dry-run.sh`
Expected: `[PASS] skill-harness dry-run`.

### Task 6: Lightweight Default Path [T6]

Context: The new contracts must not force every audit to load JSON, schemas, renderers, hooks, or user-decision envelope fields. The default path stays read-first and human-readable.

Files:
- Create: `tests/test-skill-harness-lightweight-path.sh`
- Modify: `shared/skills/skill-harness/SKILL.md`
- Modify: `shared/skills/skill-harness/scripts/manifest.json`

1. [T6] Write the RED lightweight path test.

Create `tests/test-skill-harness-lightweight-path.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/shared/skills/skill-harness/SKILL.md"
MANIFEST="$ROOT/shared/skills/skill-harness/scripts/manifest.json"
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py"
GOOD="$ROOT/tests/fixtures/skill-harness/cases/good-markdown-audit.json"
fail() { echo "[FAIL] $*" >&2; exit 1; }

grep -Fq 'Default output: structured Markdown findings' "$SKILL" || fail "default output must remain Markdown"
grep -Fq 'JSON only through the JSON upgrade gate' "$SKILL" || fail "JSON must remain consumer-triggered"
grep -Fq 'baseline smoke' "$SKILL" || fail "missing baseline smoke boundary"
for field in authority_proof_refs decision_payload_digest active_plan_version_ref active_tasks_version_ref; do
  if grep -E "Default output|Fields:" "$SKILL" | grep -Fq "$field"; then
    fail "default output includes conditional user-decision field: $field"
  fi
done
python3 - "$MANIFEST" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
paths = {script["path"] for script in data["scripts"]}
blocked = {"scripts/render_report.py", "hooks/hook_adapter.py"}
bad = paths & blocked
if bad:
    raise SystemExit(f"default manifest includes consumer-triggered command: {sorted(bad)}")
print("[PASS] lightweight manifest")
PY
python3 "$CHECKER" "$GOOD"
printf '[PASS] skill-harness lightweight path\n'
```

2. [T6] Run the RED command.

Run: `bash tests/test-skill-harness-lightweight-path.sh`
Expected: FAIL until `SKILL.md` names the baseline smoke boundary and conditional fields leave default output.

3. [T6] Update `SKILL.md`.

Add:

```markdown
Default output: structured Markdown findings.

JSON only through the JSON upgrade gate.

Baseline smoke commands prove the active runtime did not regress. They do not prove new Harness governance contracts. Implementation proof commands are created task-by-task and run before any best-practice release claim.

Conditional gate fields are loaded only by gate type, proof type, or JSON upgrade route.
```

4. [T6] Run the GREEN command.

Run: `bash tests/test-skill-harness-lightweight-path.sh`
Expected: `[PASS] skill-harness lightweight path`.

### Task 7: Verification And Package [T7]

Context: This task proves the small-chain package is internally consistent, separates primary implementation proof from baseline smoke, and records residual risk for verify-change.

Files:
- Modify: `docs/skill-harness/2026-04-20-standard-chain-harness-governance/tasks.md`
- Create: `docs/skill-harness/2026-04-20-standard-chain-harness-governance/verify-change-report.md`

1. [T7] Run task-plan consistency.

Run:

```bash
python3 tools/community/check_task_plan_consistency.py docs/skill-harness/2026-04-20-standard-chain-harness-governance/tasks.md docs/skill-harness/2026-04-20-standard-chain-harness-governance/plan.md
```

Expected: `[PASS] tasks-plan consistency (7 tasks,` followed by the step count.

2. [T7] Run primary implementation proof commands.

Run:

```bash
bash tests/test-skill-harness-responsibility-contract.sh
bash tests/test-skill-harness-main-content-noise.sh
bash tests/test-skill-harness-runtime-noise.sh
bash tests/test-skill-harness-legacy-label-migration.sh
bash tests/test-skill-harness-field-consumers.sh
bash tests/test-skill-harness-engineering-control.sh
bash tests/test-skill-harness-directory-capability.sh
bash tests/test-skill-harness-standard-chain-integration.sh
bash tests/test-skill-harness-dry-run.sh
bash tests/test-skill-harness-lightweight-path.sh
```

Expected: every command exits 0.

3. [T7] Run secondary baseline smoke and hygiene commands.

Run:

```bash
bash tests/test-skill-harness-contract.sh
bash tests/test-skill-harness-gates.sh
bash tests/test-skill-harness-migration.sh
bash tests/test-delivery-owner-phase3-contract.sh
bash tests/test-standard-chain-user-decision.sh
git diff --check
```

Expected: every command exits 0. Record these as baseline smoke or hygiene checks, not as primary proof of new Harness governance contracts.

4. [T7] Update task checkboxes after each AC passes.

Only change a task to `[x]` after its AC command exits 0.

5. [T7] Write `verify-change-report.md`.

The report must include:

```markdown
# verify-change report: skill-harness standard-chain governance

## Execution Preconditions

| Check | Result |
| --- | --- |
| `git status --short` before kickoff | PASS |
| declared target files free of unrelated dirty changes | PASS |

## Primary Implementation Proof

| Command | Result |
| --- | --- |
| `bash tests/test-skill-harness-responsibility-contract.sh` | PASS |

## Secondary Baseline Smoke

| Command | Result |
| --- | --- |
| `bash tests/test-skill-harness-contract.sh` | PASS |

## Residual Risks

- Existing delivery-owner canonical migration changes remain read-only calibration input unless a later task lists them in file scope.
```

6. [T7] Run final task-plan consistency again.

Run:

```bash
python3 tools/community/check_task_plan_consistency.py docs/skill-harness/2026-04-20-standard-chain-harness-governance/tasks.md docs/skill-harness/2026-04-20-standard-chain-harness-governance/plan.md
```

Expected: `[PASS] tasks-plan consistency (7 tasks,` followed by the step count.
