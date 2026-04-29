#!/usr/bin/env bash
# File role: prove Skill quality standards detect known-good and known-bad Skill packages.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKER="$ROOT/tools/skill_quality/check_skill_package_quality.py"
MANIFEST="$ROOT/tools/skill_quality/manifest.json"
FIXTURES="$ROOT/tests/fixtures/skill-quality-detection"
TMP_DIR="$(mktemp -d "$FIXTURES/.tmp.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_case() {
  local name="$1"
  local expected_status="$2"
  local expected_code="$3"
  local expected_dimension="$4"
  local expected_severity="$5"
  local expected_rc="$6"
  local output="$TMP_DIR/$name.json"

  set +e
  python3 "$CHECKER" "$FIXTURES/$name" >"$output"
  local rc=$?
  set -e
  [ "$rc" -eq "$expected_rc" ] || fail "$name expected rc $expected_rc, got $rc"

  python3 - "$output" "$expected_status" "$expected_code" "$expected_dimension" "$expected_severity" <<'PY'
import json
import sys

path, expected_status, expected_code, expected_dimension, expected_severity = sys.argv[1:]
data = json.load(open(path, encoding="utf-8"))
assert data["artifact_type"] == "skill-quality-package-audit", data
assert data["status"] == expected_status, data
if expected_code == "NONE":
    assert data["finding_count"] == 0, data
    raise SystemExit(0)
matches = [finding for finding in data["findings"] if finding["code"] == expected_code]
if not matches:
    raise SystemExit(f"missing {expected_code}: {[finding['code'] for finding in data['findings']]}")
finding = matches[0]
assert finding["dimension"] == expected_dimension, finding
assert finding["severity"] == expected_severity, finding
assert finding["priority"] in {"P0", "P1", "P2", "P3"}, finding
assert finding["skill_id"], finding
assert finding["runtime_target"] == "repo-static", finding
assert finding["scope"], finding
assert finding["owner"] == "skill-author", finding
assert finding["file_ref"].startswith("tests/fixtures/skill-quality-detection/"), finding
assert finding["evidence_refs"], finding
assert finding["impact"], finding
assert finding["recommendation"], finding
assert finding["verification"].startswith("python3 tools/skill_quality/check_skill_package_quality.py "), finding
assert finding["false_positive_guard"], finding
PY
}

[ -f "$CHECKER" ] || fail "missing package quality checker"

assert_case "good-package" "static_pass" "NONE" "NONE" "NONE" 0
assert_case "weak-trigger" "static_warn" "TRIGGER_CONTRACT_TOO_WEAK" "S1" "WARN" 0
assert_case "workflow-output-missing" "static_warn" "WORKFLOW_OUTPUT_CONTRACT_MISSING" "S3" "WARN" 0
assert_case "artifact-contract-missing" "static_warn" "ARTIFACT_CONTRACT_MISSING" "S6" "WARN" 0
assert_case "retain-low-uplift" "static_fail" "RETAIN_UPLIFT_GATE_UNMET" "E3" "FAIL" 1

python3 "$CHECKER" "$ROOT/shared/skills/skill-refiner" >"$TMP_DIR/skill-refiner.json"
python3 "$CHECKER" "$ROOT/shared/skills/developer" >"$TMP_DIR/developer.json"
python3 - "$TMP_DIR/skill-refiner.json" "$TMP_DIR/developer.json" <<'PY'
import json
import sys

for path in sys.argv[1:]:
    data = json.load(open(path, encoding="utf-8"))
    assert data["artifact_type"] == "skill-quality-package-audit", data
    fail_findings = [finding for finding in data["findings"] if finding["severity"] == "FAIL"]
    if fail_findings:
        raise SystemExit(f"real Skill smoke produced FAIL findings in {path}: {fail_findings}")
print("[PASS] real Skill smoke audit")
PY

grep -Fq '"check-package-quality"' "$MANIFEST" \
  || fail "manifest must expose check-package-quality"

printf '[PASS] skill quality detection fixtures\n'
