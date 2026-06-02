#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg
FIXTURE_ROOT="$ROOT/tests/fixtures/standard-chain-foundation/user-decision"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

for path in \
  "$FIXTURE_ROOT/approve.json" \
  "$FIXTURE_ROOT/reject.json" \
  "$FIXTURE_ROOT/accept-risk.json" \
  "$FIXTURE_ROOT/request-changes.json" \
  "$FIXTURE_ROOT/superseded.json" \
  "$FIXTURE_ROOT/authority-conflict.json" \
  "$FIXTURE_ROOT/missing-proof.json" \
  "$FIXTURE_ROOT/digest-mismatch.json" \
  "$FIXTURE_ROOT/expired-proof.json" \
  "$FIXTURE_ROOT/script-source.json" \
  "$FIXTURE_ROOT/stale-baseline.json"; do
  [ -f "$path" ] || fail "missing user-decision fixture: ${path#"$ROOT"/}"
done

[ -f "$ROOT/tools/community/authority_proof.py" ] || fail "missing authority_proof.py"
[ -f "$ROOT/tools/community/write_user_decision.py" ] || fail "missing write_user_decision.py"
[ -f "$ROOT/shared/skills/delivery-owner/contracts/target-change.schema.json" ] || fail "missing target-change schema"
[ -f "$ROOT/shared/skills/delivery-owner/templates/target-change.template.json" ] || fail "missing target-change template"

build_validation_fixture() {
  local source_fixture="$1"
  local decision_output="$2"
  local validation_fixture="$3"
  python3 - "$source_fixture" "$decision_output" "$validation_fixture" <<'PY'
import json
import sys
from pathlib import Path

source = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
decision = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
proof = source.get("proof")
if isinstance(proof, dict):
    proof = dict(proof)
    if source.get("proof_digest_mode") == "mismatch":
        proof["decision_payload_digest"] = "sha256:" + ("2" * 64)
    else:
        proof["decision_payload_digest"] = decision["decision_payload_digest"]
payload = {
    "decision_payload": decision,
    "proof": proof,
    "runtime_state": source["runtime_state"],
}
Path(sys.argv[3]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

build_rule_fixture() {
  local decision_output="$1"
  local source_fixture="$2"
  local rule_fixture="$3"
  python3 - "$decision_output" "$source_fixture" "$rule_fixture" <<'PY'
import json
import sys
from pathlib import Path

decision = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
source = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
payload = {
    "artifacts": [decision],
    "runtime_state": source["runtime_state"],
}
Path(sys.argv[3]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

run_positive_fixture() {
  local name="$1"
  local source_fixture="$FIXTURE_ROOT/$name.json"
  local decision_output="$TMP_DIR/$name.out.json"
  local proof_fixture="$TMP_DIR/$name.proof.json"
  local rule_fixture="$TMP_DIR/$name.rule.json"

  python3 "$ROOT/tools/community/write_user_decision.py" --fixture "$source_fixture" >"$decision_output" || fail "$name writer should pass"
  build_validation_fixture "$source_fixture" "$decision_output" "$proof_fixture"
  python3 "$ROOT/tools/community/authority_proof.py" --fixture "$proof_fixture" >/dev/null || fail "$name authority proof should pass"
  build_rule_fixture "$decision_output" "$source_fixture" "$rule_fixture"
  python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$rule_fixture" >/dev/null || fail "$name schema validation should pass"
  python3 "$ROOT/tools/community/validate_canonical_rules.py" --fixture "$rule_fixture" >/dev/null || fail "$name rule validation should pass"
}

for positive_case in approve reject accept-risk request-changes superseded; do
  run_positive_fixture "$positive_case"
done

missing_writer="$TMP_DIR/missing-proof.out"
if python3 "$ROOT/tools/community/write_user_decision.py" --fixture "$FIXTURE_ROOT/missing-proof.json" >"$missing_writer" 2>/tmp/t4_missing_proof.out; then
  cat /tmp/t4_missing_proof.out >&2
  fail "writer should reject missing proof refs"
fi

for negative_proof_case in authority-conflict digest-mismatch expired-proof; do
  decision_output="$TMP_DIR/$negative_proof_case.out.json"
  proof_fixture="$TMP_DIR/$negative_proof_case.proof.json"
  python3 "$ROOT/tools/community/write_user_decision.py" --fixture "$FIXTURE_ROOT/$negative_proof_case.json" >"$decision_output" || fail "$negative_proof_case writer should pass"
  build_validation_fixture "$FIXTURE_ROOT/$negative_proof_case.json" "$decision_output" "$proof_fixture"
  if python3 "$ROOT/tools/community/authority_proof.py" --fixture "$proof_fixture" >/tmp/t4_"$negative_proof_case".out 2>&1; then
    cat /tmp/t4_"$negative_proof_case".out >&2
    fail "$negative_proof_case authority proof should fail"
  fi
done

baseline_mismatch_decision="$TMP_DIR/baseline-mismatch.out.json"
baseline_mismatch_proof="$TMP_DIR/baseline-mismatch.proof.json"
python3 "$ROOT/tools/community/write_user_decision.py" --fixture "$FIXTURE_ROOT/approve.json" >"$baseline_mismatch_decision" || fail "baseline-mismatch writer should pass"
build_validation_fixture "$FIXTURE_ROOT/approve.json" "$baseline_mismatch_decision" "$baseline_mismatch_proof"
python3 - "$baseline_mismatch_proof" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["runtime_state"]["baseline_tasks_version_ref"] = (
    "artifact://tasks/sample-feature.phase-1.tasks@stale#task-registry"
)
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/authority_proof.py" --fixture "$baseline_mismatch_proof" >/tmp/t4_baseline_mismatch.out 2>&1; then
  cat /tmp/t4_baseline_mismatch.out >&2
  fail "baseline-mismatch authority proof should fail"
fi
rg -q "stale task baseline" /tmp/t4_baseline_mismatch.out \
  || fail "baseline-mismatch failure should name stale task baseline"

for negative_rule_case in script-source stale-baseline; do
  decision_output="$TMP_DIR/$negative_rule_case.out.json"
  rule_fixture="$TMP_DIR/$negative_rule_case.rule.json"
  python3 "$ROOT/tools/community/write_user_decision.py" --fixture "$FIXTURE_ROOT/$negative_rule_case.json" >"$decision_output" || fail "$negative_rule_case writer should pass"
  build_rule_fixture "$decision_output" "$FIXTURE_ROOT/$negative_rule_case.json" "$rule_fixture"
  if python3 "$ROOT/tools/community/validate_canonical_rules.py" --fixture "$rule_fixture" >/tmp/t4_"$negative_rule_case".rule.out 2>&1; then
    cat /tmp/t4_"$negative_rule_case".rule.out >&2
    fail "$negative_rule_case rule validation should fail"
  fi
done

target_change_user_decision_source="$TMP_DIR/target-change-user-decision.source.json"
python3 - "$FIXTURE_ROOT/approve.json" "$target_change_user_decision_source" <<'PY'
import json
import sys
from pathlib import Path

source = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
source["decision_payload"]["decision"] = "CHANGE_SCOPE"
source["decision_payload"]["decision_basis_refs"] = [
    "artifact://phase-prd/sample-feature.phase-1.prd@v1#phase-goal"
]
Path(sys.argv[2]).write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
target_change_user_decision_output="$TMP_DIR/target-change-user-decision.out.json"
target_change_user_decision_rule="$TMP_DIR/target-change-user-decision.rule.json"
python3 "$ROOT/tools/community/write_user_decision.py" --fixture "$target_change_user_decision_source" >"$target_change_user_decision_output" \
  || fail "target-change-shaped user-decision writer should emit payload before schema rejection"
build_rule_fixture "$target_change_user_decision_output" "$target_change_user_decision_source" "$target_change_user_decision_rule"
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$target_change_user_decision_rule" >/tmp/t4_target_change_user_decision.out 2>&1; then
  cat /tmp/t4_target_change_user_decision.out >&2
  fail "user-decision schema should reject target/scope change decisions"
fi

target_change_rule_fixture="$TMP_DIR/target-change.rule.json"
python3 - "$ROOT" "$target_change_rule_fixture" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
payload = {
    "artifacts": [
        json.loads(
            (root / "shared/skills/delivery-owner/templates/target-change.template.json").read_text(encoding="utf-8")
        )
    ],
    "runtime_state": {
        "active_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
    },
}
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$target_change_rule_fixture" >/dev/null \
  || fail "target-change template should pass canonical schema validation"

target_change_wrong_owner="$TMP_DIR/target-change-wrong-owner.rule.json"
python3 - "$ROOT" "$target_change_wrong_owner" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
target_change = json.loads(
    (root / "shared/skills/delivery-owner/templates/target-change.template.json").read_text(encoding="utf-8")
)
target_change["changed_target_type"] = "AC"
target_change["rebaseline_owner"] = "tech-lead"
payload = {
    "artifacts": [target_change],
    "runtime_state": {
        "active_tasks_version_ref": target_change["active_tasks_version_ref"],
    },
}
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$target_change_wrong_owner" >/tmp/t4_target_change_wrong_owner.out 2>&1; then
  cat /tmp/t4_target_change_wrong_owner.out >&2
  fail "target-change schema should route AC changes back to product-manager"
fi

target_change_missing_pm_fresh_proof="$TMP_DIR/target-change-missing-pm-fresh-proof.rule.json"
python3 - "$ROOT" "$target_change_missing_pm_fresh_proof" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
target_change = json.loads(
    (root / "shared/skills/delivery-owner/templates/target-change.template.json").read_text(encoding="utf-8")
)
target_change["changed_target_type"] = "SCOPE"
target_change["required_fresh_proof_after_rebaseline"] = [
    item
    for item in target_change["required_fresh_proof_after_rebaseline"]
    if item != "unit-definition"
]
payload = {
    "artifacts": [target_change],
    "runtime_state": {
        "active_tasks_version_ref": target_change["active_tasks_version_ref"],
    },
}
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$target_change_missing_pm_fresh_proof" >/tmp/t4_target_change_missing_pm_fresh_proof.out 2>&1; then
  cat /tmp/t4_target_change_missing_pm_fresh_proof.out >&2
  fail "target-change schema should require unit-definition proof for SCOPE changes"
fi

target_change_missing_brief_fresh_proof="$TMP_DIR/target-change-missing-brief-fresh-proof.rule.json"
python3 - "$ROOT" "$target_change_missing_brief_fresh_proof" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
target_change = json.loads(
    (root / "shared/skills/delivery-owner/templates/target-change.template.json").read_text(encoding="utf-8")
)
target_change["changed_target_type"] = "AC"
target_change["required_fresh_proof_after_rebaseline"] = [
    item
    for item in target_change["required_fresh_proof_after_rebaseline"]
    if item != "brief"
]
payload = {
    "artifacts": [target_change],
    "runtime_state": {
        "active_tasks_version_ref": target_change["active_tasks_version_ref"],
    },
}
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$target_change_missing_brief_fresh_proof" >/tmp/t4_target_change_missing_brief_fresh_proof.out 2>&1; then
  cat /tmp/t4_target_change_missing_brief_fresh_proof.out >&2
  fail "target-change schema should require brief proof for AC changes"
fi

user_decision_with_target_field="$TMP_DIR/user-decision-with-target-field.rule.json"
python3 - "$FIXTURE_ROOT/approve.json" "$user_decision_with_target_field" <<'PY'
import json
import sys
from pathlib import Path

source = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
decision = source["decision_payload"]
decision["changed_target_type"] = "AC"
payload = {
    "artifacts": [decision],
    "runtime_state": source["runtime_state"],
}
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$user_decision_with_target_field" >/tmp/t4_user_decision_with_target_field.out 2>&1; then
  cat /tmp/t4_user_decision_with_target_field.out >&2
  fail "user-decision schema should reject target-change fields"
fi

target_change_with_signoff_field="$TMP_DIR/target-change-with-signoff-field.rule.json"
python3 - "$ROOT" "$target_change_with_signoff_field" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
target_change = json.loads(
    (root / "shared/skills/delivery-owner/templates/target-change.template.json").read_text(encoding="utf-8")
)
target_change["sign_off_status"] = "SIGNED_OFF"
payload = {
    "artifacts": [target_change],
    "runtime_state": {
        "active_tasks_version_ref": target_change["active_tasks_version_ref"],
    },
}
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_schema.py" --fixture "$target_change_with_signoff_field" >/tmp/t4_target_change_with_signoff_field.out 2>&1; then
  cat /tmp/t4_target_change_with_signoff_field.out >&2
  fail "target-change schema should reject user-decision signoff fields"
fi

python3 - "$ROOT" <<'PY' || fail "simple schema fallback should enforce target/user separation"
import copy
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools/community"))
from normalize_canonical_artifact import normalize_artifact
from simple_json_schema import SimpleSchemaValidator, SimpleValidationError

schema_paths = [
    root / "shared/skills/lib/contracts/shared-core.schema.json",
    root / "shared/skills/delivery-owner/contracts/target-change.schema.json",
    root / "shared/skills/delivery-owner/contracts/user-decision.schema.json",
]
schemas = {json.loads(path.read_text(encoding="utf-8"))["$id"]: json.loads(path.read_text(encoding="utf-8")) for path in schema_paths}
validator = SimpleSchemaValidator(schemas)
target_schema = schemas[
    "https://org-claude-skills.local/shared/skills/delivery-owner/contracts/target-change.schema.json"
]
decision_schema = schemas[
    "https://org-claude-skills.local/shared/skills/delivery-owner/contracts/user-decision.schema.json"
]
target = normalize_artifact(
    json.loads(
        (root / "shared/skills/delivery-owner/templates/target-change.template.json").read_text(
            encoding="utf-8"
        )
    )
)
decision = normalize_artifact(
    json.loads(
        (
            root
            / "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/user-decision.json"
        ).read_text(encoding="utf-8")
    )
)

validator.validate(target, target_schema)
validator.validate(decision, decision_schema)

bad_target = copy.deepcopy(target)
bad_target["changed_target_type"] = "SCOPE"
bad_target["required_fresh_proof_after_rebaseline"] = [
    item for item in bad_target["required_fresh_proof_after_rebaseline"] if item != "unit-definition"
]
try:
    validator.validate(bad_target, target_schema)
except SimpleValidationError:
    pass
else:
    raise SystemExit("fallback accepted target-change without required SCOPE unit-definition proof")

bad_target = copy.deepcopy(target)
bad_target["changed_target_type"] = "AC"
bad_target["required_fresh_proof_after_rebaseline"] = [
    item for item in bad_target["required_fresh_proof_after_rebaseline"] if item != "brief"
]
try:
    validator.validate(bad_target, target_schema)
except SimpleValidationError:
    pass
else:
    raise SystemExit("fallback accepted target-change without required AC brief proof")

bad_decision = copy.deepcopy(decision)
bad_decision["changed_target_type"] = "AC"
try:
    validator.validate(bad_decision, decision_schema)
except SimpleValidationError:
    pass
else:
    raise SystemExit("fallback accepted target-change field on user-decision")

bad_target = copy.deepcopy(target)
bad_target["sign_off_status"] = "SIGNED_OFF"
try:
    validator.validate(bad_target, target_schema)
except SimpleValidationError:
    pass
else:
    raise SystemExit("fallback accepted user-decision signoff field on target-change")
PY

signoff_rule_fixture="$TMP_DIR/signoff.rule.json"
python3 - "$ROOT" "$signoff_rule_fixture" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
payload = {
    "artifacts": [
        json.loads(
            (root / "shared/skills/delivery-owner/templates/signoff-package.template.json").read_text(encoding="utf-8")
        )
    ],
    "runtime_state": {
        "active_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#plan-version",
        "active_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
    },
}
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_canonical_rules.py" --fixture "$signoff_rule_fixture" >/tmp/t4_signoff.rule.out 2>&1; then
  cat /tmp/t4_signoff.rule.out >&2
  fail "signoff-package stale active baseline should fail"
fi

echo "[PASS] standard chain user decision"
