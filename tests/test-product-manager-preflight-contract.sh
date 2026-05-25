#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PREFLIGHT="$ROOT/shared/skills/product-manager/scripts/preflight_check.sh"
PREFLIGHT_PY="$ROOT/shared/skills/product-manager/scripts/preflight_check.py"
MANIFEST="$ROOT/shared/skills/product-manager/scripts/manifest.json"
SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
BRIEF_TEMPLATE="$ROOT/shared/skills/product-manager/templates/brief.template.json"
PHASE_TEMPLATE="$ROOT/shared/skills/product-manager/templates/phase-prd.template.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Eq "$pattern" "$file" || fail "expected pattern '$pattern' in $file"
}

assert_json_status() {
  local path="$1"
  local expected="$2"
  python3 - "$path" "$expected" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
expected = sys.argv[2]
actual = payload.get("status")
if actual != expected:
    raise SystemExit(f"expected status {expected}, got {actual}: {payload}")
PY
}

assert_failure_reason_contains() {
  local path="$1"
  local needle="$2"
  python3 - "$path" "$needle" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
needle = sys.argv[2]
reason = str(payload.get("reason", ""))
if payload.get("status") != "BLOCKED" or needle not in reason:
    raise SystemExit(f"expected BLOCKED reason containing {needle!r}, got {payload}")
PY
}

copy_fixtures() {
  local target="$1"
  mkdir -p "$target/feature/phase-1"
  cp "$BRIEF_TEMPLATE" "$target/feature/brief.json"
  cp "$PHASE_TEMPLATE" "$target/feature/phase-1/phase-prd.json"
}

assert_file "$PREFLIGHT"
assert_file "$PREFLIGHT_PY"
assert_file "$MANIFEST"
assert_file "$SKILL"
python3 -m py_compile "$PREFLIGHT_PY"

python3 - "$MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
scripts = {script.get("id"): script for script in manifest.get("scripts", [])}
preflight = scripts.get("preflight-check")
if not preflight:
    raise SystemExit("manifest missing preflight-check")
if preflight.get("path") != "scripts/preflight_check.sh":
    raise SystemExit("preflight-check path drift")
for arg in ("--brief", "--phase-prd", "--phase-dir", "--pre-unit", "--help", "-h"):
    if arg not in preflight.get("allowed_args", []):
        raise SystemExit(f"preflight-check missing allowed arg {arg}")
PY

assert_present 'preflight_check\.sh --brief "\$BRIEF_JSON" --phase-prd "\$PHASE_PRD_JSON"' "$SKILL"
assert_present 'preflight_check\.sh --phase-dir "\$PHASE_DIR"' "$SKILL"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
copy_fixtures "$TMP_DIR"

PASS_OUT="$TMP_DIR/pass.json"
bash "$PREFLIGHT" \
  --brief "$TMP_DIR/feature/brief.json" \
  --phase-prd "$TMP_DIR/feature/phase-1/phase-prd.json" >"$PASS_OUT"
assert_json_status "$PASS_OUT" "PASS"

PHASE_DIR_OUT="$TMP_DIR/phase-dir-pass.json"
if bash "$PREFLIGHT" --phase-dir "$TMP_DIR/feature/phase-1" >"$PHASE_DIR_OUT"; then
  fail "preflight must block phase-dir mode before UNIT files exist"
fi
assert_failure_reason_contains "$PHASE_DIR_OUT" "units/UNIT-*.json"

PRE_UNIT_OUT="$TMP_DIR/pre-unit-pass.json"
bash "$PREFLIGHT" --phase-dir "$TMP_DIR/feature/phase-1" --pre-unit >"$PRE_UNIT_OUT"
assert_json_status "$PRE_UNIT_OUT" "PASS"

OPEN_RISK_DIR="$TMP_DIR/open-risk"
copy_fixtures "$OPEN_RISK_DIR"
python3 - "$OPEN_RISK_DIR/feature/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["risk_ledger"][0]["status"] = "OPEN"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
OPEN_RISK_OUT="$TMP_DIR/open-risk.json"
if bash "$PREFLIGHT" --phase-dir "$OPEN_RISK_DIR/feature/phase-1" --pre-unit >"$OPEN_RISK_OUT"; then
  fail "preflight --pre-unit must block OPEN risk_ledger status"
fi
assert_failure_reason_contains "$OPEN_RISK_OUT" "non-closed risk status"

FULL_PM_MODEL_DIR="$TMP_DIR/full-pm-model"
copy_fixtures "$FULL_PM_MODEL_DIR"
python3 - "$FULL_PM_MODEL_DIR/feature/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["coverage_matrix"] = [
    {
        "coverage_id": "COV-1",
        "scenario_ref": "TOBE-1",
        "business_type": "standard",
        "platform": "PC",
        "action_or_path": "submit request and view approved status",
        "support_status": "SUPPORTED",
        "unit_refs": ["UNIT-1"],
        "ac_refs": ["AC-U1-01"],
        "evidence_refs": ["EV-1"],
        "evidence_targets": ["page screenshot", "data before/after"],
    }
]
payload["technical_evidence_requirements"] = [
    {
        "requirement_id": "TECH-1",
        "domain": "api_contract",
        "business_invariant": "unauthorized reviewer cannot change request status",
        "required_downstream_proof": "service rejection evidence linked to AC-U1-01",
        "unit_refs": ["UNIT-1"],
        "risk_refs": ["RISK-1"],
        "status": "REQUIRED",
    }
]
payload["release_readiness"] = {
    "supported_platforms": ["PC"],
    "conditional_platforms": [],
    "unsupported_platforms": [],
    "residual_risks": [
        {
            "risk_id": "RR-1",
            "description": "no residual PM release risk",
            "owner": "product-manager",
            "target_resolution": "before delivery",
            "status": "CLOSED",
        }
    ],
}
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
FULL_PM_MODEL_OUT="$TMP_DIR/full-pm-model.json"
bash "$PREFLIGHT" --phase-dir "$FULL_PM_MODEL_DIR/feature/phase-1" --pre-unit >"$FULL_PM_MODEL_OUT"
assert_json_status "$FULL_PM_MODEL_OUT" "PASS"

MISSING_COVERAGE_DIR="$TMP_DIR/missing-coverage"
cp -R "$FULL_PM_MODEL_DIR" "$MISSING_COVERAGE_DIR"
python3 - "$MISSING_COVERAGE_DIR/feature/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["coverage_matrix"] = []
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
MISSING_COVERAGE_OUT="$TMP_DIR/missing-coverage.json"
if bash "$PREFLIGHT" --phase-dir "$MISSING_COVERAGE_DIR/feature/phase-1" --pre-unit >"$MISSING_COVERAGE_OUT"; then
  fail "preflight --pre-unit must block missing coverage_matrix"
fi
assert_failure_reason_contains "$MISSING_COVERAGE_OUT" "coverage_matrix"

MISSING_TECH_DIR="$TMP_DIR/missing-technical-evidence"
cp -R "$FULL_PM_MODEL_DIR" "$MISSING_TECH_DIR"
python3 - "$MISSING_TECH_DIR/feature/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["technical_evidence_requirements"] = []
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
MISSING_TECH_OUT="$TMP_DIR/missing-technical-evidence.json"
if bash "$PREFLIGHT" --phase-dir "$MISSING_TECH_DIR/feature/phase-1" --pre-unit >"$MISSING_TECH_OUT"; then
  fail "preflight --pre-unit must block missing technical_evidence_requirements"
fi
assert_failure_reason_contains "$MISSING_TECH_OUT" "technical_evidence_requirements"

OPEN_RELEASE_RISK_DIR="$TMP_DIR/open-release-risk"
cp -R "$FULL_PM_MODEL_DIR" "$OPEN_RELEASE_RISK_DIR"
python3 - "$OPEN_RELEASE_RISK_DIR/feature/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["release_readiness"]["residual_risks"][0]["status"] = "OPEN"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
OPEN_RELEASE_RISK_OUT="$TMP_DIR/open-release-risk.json"
if bash "$PREFLIGHT" --phase-dir "$OPEN_RELEASE_RISK_DIR/feature/phase-1" --pre-unit >"$OPEN_RELEASE_RISK_OUT"; then
  fail "preflight --pre-unit must block open release_readiness residual risk"
fi
assert_failure_reason_contains "$OPEN_RELEASE_RISK_OUT" "release_readiness"

BAD_STATUS_DIR="$TMP_DIR/bad-status"
copy_fixtures "$BAD_STATUS_DIR"
python3 - "$BAD_STATUS_DIR/feature/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["director_confirmation"]["status"] = "pending"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
BAD_STATUS_OUT="$TMP_DIR/bad-status.json"
if bash "$PREFLIGHT" --phase-dir "$BAD_STATUS_DIR/feature/phase-1" >"$BAD_STATUS_OUT"; then
  fail "preflight must block unpassed director_confirmation.status"
fi
assert_failure_reason_contains "$BAD_STATUS_OUT" "director_confirmation.status"

DRIFT_DIR="$TMP_DIR/drift"
copy_fixtures "$DRIFT_DIR"
python3 - "$DRIFT_DIR/feature/phase-1/phase-prd.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["phase_goal"] = "silently expanded phase goal"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
DRIFT_OUT="$TMP_DIR/drift.json"
if bash "$PREFLIGHT" --phase-dir "$DRIFT_DIR/feature/phase-1" >"$DRIFT_OUT"; then
  fail "preflight must block Director-owned field drift"
fi
assert_failure_reason_contains "$DRIFT_OUT" "locked_fields"

TIMEBOX_DIR="$TMP_DIR/timebox"
copy_fixtures "$TIMEBOX_DIR"
python3 - "$TIMEBOX_DIR/feature/brief.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["delivery_plan"][0]["iteration_timebox_days"] = 21
locked = payload["director_confirmation"]["locked_fields"]
locked["delivery_plan"][0]["iteration_timebox_days"] = 21
raw = json.dumps(locked, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
payload["director_confirmation"]["locked_field_digest"] = "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
TIMEBOX_OUT="$TMP_DIR/timebox.json"
if bash "$PREFLIGHT" --phase-dir "$TIMEBOX_DIR/feature/phase-1" >"$TIMEBOX_OUT"; then
  fail "preflight must block Phase iteration timebox over 14 days"
fi
assert_failure_reason_contains "$TIMEBOX_OUT" "iteration_timebox_days"

MARKDOWN_OUT="$TMP_DIR/markdown.json"
printf '# legacy brief\n' >"$TMP_DIR/feature/brief.md"
if bash "$PREFLIGHT" \
  --brief "$TMP_DIR/feature/brief.md" \
  --phase-prd "$TMP_DIR/feature/phase-1/phase-prd.json" >"$MARKDOWN_OUT"; then
  fail "preflight must reject non-canonical brief paths"
fi
assert_failure_reason_contains "$MARKDOWN_OUT" "canonical JSON"

printf '[PASS] product-manager preflight contract\n'
