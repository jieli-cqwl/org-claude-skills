#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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
