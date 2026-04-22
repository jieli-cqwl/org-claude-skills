#!/usr/bin/env bash
set -euo pipefail

# File responsibility: prove standard-chain pilot audit reports block
# cross-feature residue and require review-fix regression evidence.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$ROOT/tools/community/validate_standard_chain_pilot_audit.py"
AUDIT="$ROOT/docs/standard-chain-pilot-audit-20260422/audit-report.json"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

expect_fail() {
  local label="$1"
  local expected="$2"
  shift 2
  local output="$TMP_DIR/${label//[^A-Za-z0-9_]/_}.out"

  if "$@" >"$output" 2>&1; then
    cat "$output" >&2
    fail "$label should fail"
  fi
  if ! rg -q "$expected" "$output"; then
    cat "$output" >&2
    fail "$label should mention $expected"
  fi
}

make_audit_copy() {
  local target="$1"
  cp "$AUDIT" "$target"
}

[ -f "$TOOL" ] || fail "missing pilot audit validator: ${TOOL#"$ROOT"/}"
[ -f "$AUDIT" ] || fail "missing pilot audit report: ${AUDIT#"$ROOT"/}"

python3 "$TOOL" --audit "$AUDIT" || fail "pilot audit report should pass"

missing_resolution="$TMP_DIR/missing-resolution.json"
make_audit_copy "$missing_resolution"
python3 - "$missing_resolution" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
for pilot in payload["pilots"]:
    if pilot["feature_id"] == "feedback-thanks-pilot":
        pilot["review_resolution_checks"] = [
            item
            for item in pilot["review_resolution_checks"]
            if item["finding_id"] != "CR-LEN-001"
        ]
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_fail \
  "missing resolved finding proof" \
  "missing resolution check for finding CR-LEN-001" \
  python3 "$TOOL" --audit "$missing_resolution"

fake_proof="$TMP_DIR/fake-proof.json"
make_audit_copy "$fake_proof"
python3 - "$fake_proof" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
for pilot in payload["pilots"]:
    if pilot["feature_id"] == "feedback-thanks-pilot":
        for item in pilot["review_resolution_checks"]:
            if item["finding_id"] == "CR-LEN-001":
                item["proof_command"] = "false"
                item["proof_result"] = "OK"
                item["proof_refs"] = [
                    {
                        "kind": "test_symbol",
                        "file": "tests/test_feedback_thanks_app.py",
                        "symbol": "request",
                    }
                ]
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_fail \
  "fake resolved finding proof" \
  "proof_command failed for finding CR-LEN-001" \
  python3 "$TOOL" --audit "$fake_proof"

fake_success_proof="$TMP_DIR/fake-success-proof.json"
make_audit_copy "$fake_success_proof"
python3 - "$fake_success_proof" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
for pilot in payload["pilots"]:
    if pilot["feature_id"] == "feedback-thanks-pilot":
        for item in pilot["review_resolution_checks"]:
            if item["finding_id"] == "CR-LEN-001":
                item["proof_command"] = "true"
                item["proof_result"] = "Ran 999 tests in 0.001s OK forged text"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_fail \
  "fake successful proof command" \
  "must run unittest" \
  python3 "$TOOL" --audit "$fake_success_proof"

unrelated_unittest_proof="$TMP_DIR/unrelated-unittest-proof.json"
make_audit_copy "$unrelated_unittest_proof"
python3 - "$unrelated_unittest_proof" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
for pilot in payload["pilots"]:
    if pilot["feature_id"] == "feedback-thanks-pilot":
        for item in pilot["review_resolution_checks"]:
            if item["finding_id"] == "CR-LEN-001":
                item["proof_command"] = (
                    "PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v "
                    "tests.test_feedback_thanks_app.FeedbackThanksAcceptanceTests."
                    "test_root_redirects_to_feedback_form"
                )
                item["proof_result"] = "Ran 1 test in 0.001s OK"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_fail \
  "unrelated unittest proof command" \
  "proof output missing test symbol test_negative_content_length_is_rejected_before_body_read" \
  python3 "$TOOL" --audit "$unrelated_unittest_proof"

forged_unrelated_refs="$TMP_DIR/forged-unrelated-refs.json"
make_audit_copy "$forged_unrelated_refs"
python3 - "$forged_unrelated_refs" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
for pilot in payload["pilots"]:
    if pilot["feature_id"] == "feedback-thanks-pilot":
        for item in pilot["review_resolution_checks"]:
            if item["finding_id"] == "CR-LEN-001":
                item["proof_command"] = (
                    "PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v "
                    "tests.test_feedback_thanks_app.FeedbackThanksAcceptanceTests."
                    "test_root_redirects_to_feedback_form"
                )
                item["proof_result"] = "OK"
                item["proof_refs"] = [
                    {
                        "kind": "test_symbol",
                        "file": "tests/test_feedback_thanks_app.py",
                        "symbol": "test_root_redirects_to_feedback_form",
                    }
                ]
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_fail \
  "forged unrelated regression refs" \
  "no relevant regression test symbol for finding CR-LEN-001" \
  python3 "$TOOL" --audit "$forged_unrelated_refs"

fake_noise_proof="$TMP_DIR/fake-noise-proof.json"
make_audit_copy "$fake_noise_proof"
python3 - "$fake_noise_proof" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
for pilot in payload["pilots"]:
    if pilot["feature_id"] == "feedback-thanks-pilot":
        for item in pilot["review_resolution_checks"]:
            if item["finding_id"] == "CR-DOC-001":
                item["proof_command"] = "true"
                item["proof_result"] = "0 matches"
                item.pop("expected_exit_code", None)
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_fail \
  "fake noise proof command" \
  "noise proof_command must run rg" \
  python3 "$TOOL" --audit "$fake_noise_proof"

residue_root="$TMP_DIR/residue"
mkdir -p "$residue_root"
cp -R "$ROOT/docs/feedback-thanks-pilot" "$residue_root/feedback-thanks-pilot"
printf '\n{"copied_noise": "login homepage logout IF-LOGIN"}\n' \
  >>"$residue_root/feedback-thanks-pilot/phase-1/history/tasks-v1.json"

residue_audit="$TMP_DIR/residue-audit.json"
make_audit_copy "$residue_audit"
python3 - "$residue_audit" "$residue_root/feedback-thanks-pilot/phase-1" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
phase_dir = Path(sys.argv[2])
payload = json.loads(path.read_text(encoding="utf-8"))
for pilot in payload["pilots"]:
    if pilot["feature_id"] == "feedback-thanks-pilot":
        pilot["phase_dir"] = str(phase_dir)
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_fail \
  "cross feature residue" \
  "forbidden term" \
  python3 "$TOOL" --audit "$residue_audit"

blocklist_gap_audit="$TMP_DIR/blocklist-gap-audit.json"
make_audit_copy "$blocklist_gap_audit"
python3 - "$blocklist_gap_audit" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
for pilot in payload["pilots"]:
    if pilot["feature_id"] == "feedback-thanks-pilot":
        for check in pilot["noise_checks"]:
            check["forbidden_terms"] = [
                term for term in check["forbidden_terms"] if term != "login"
            ]
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_fail \
  "required blocklist gap" \
  "missing required forbidden term login" \
  python3 "$TOOL" --audit "$blocklist_gap_audit"

interface_blocklist_gap_audit="$TMP_DIR/interface-blocklist-gap-audit.json"
make_audit_copy "$interface_blocklist_gap_audit"
python3 - "$interface_blocklist_gap_audit" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
for pilot in payload["pilots"]:
    if pilot["feature_id"] == "feedback-thanks-pilot":
        for check in pilot["noise_checks"]:
            check["forbidden_terms"] = [
                term for term in check["forbidden_terms"] if term != "IF-HOME"
            ]
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_fail \
  "required interface blocklist gap" \
  "missing required forbidden term if-home" \
  python3 "$TOOL" --audit "$interface_blocklist_gap_audit"

residue_escape_root="$TMP_DIR/residue-escape"
mkdir -p "$residue_escape_root"
cp -R "$ROOT/docs/feedback-thanks-pilot" "$residue_escape_root/feedback-thanks-pilot"
printf '\n{"copied_noise": "login only"}\n' \
  >>"$residue_escape_root/feedback-thanks-pilot/phase-1/history/tasks-v1.json"

residue_escape_audit="$TMP_DIR/residue-escape-audit.json"
make_audit_copy "$residue_escape_audit"
python3 - "$residue_escape_audit" "$residue_escape_root/feedback-thanks-pilot/phase-1" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
phase_dir = Path(sys.argv[2])
payload = json.loads(path.read_text(encoding="utf-8"))
for pilot in payload["pilots"]:
    if pilot["feature_id"] == "feedback-thanks-pilot":
        pilot["phase_dir"] = str(phase_dir)
        for check in pilot["noise_checks"]:
            check["forbidden_terms"] = [
                term for term in check["forbidden_terms"] if term != "login"
            ]
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_fail \
  "cross feature residue blocklist escape" \
  "forbidden term login" \
  python3 "$TOOL" --audit "$residue_escape_audit"

interface_residue_escape_root="$TMP_DIR/interface-residue-escape"
mkdir -p "$interface_residue_escape_root"
cp -R "$ROOT/docs/feedback-thanks-pilot" "$interface_residue_escape_root/feedback-thanks-pilot"
printf '\n{"copied_noise": "IF-HOME"}\n' \
  >>"$interface_residue_escape_root/feedback-thanks-pilot/phase-1/history/tasks-v1.json"

interface_residue_escape_audit="$TMP_DIR/interface-residue-escape-audit.json"
make_audit_copy "$interface_residue_escape_audit"
python3 - "$interface_residue_escape_audit" "$interface_residue_escape_root/feedback-thanks-pilot/phase-1" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
phase_dir = Path(sys.argv[2])
payload = json.loads(path.read_text(encoding="utf-8"))
for pilot in payload["pilots"]:
    if pilot["feature_id"] == "feedback-thanks-pilot":
        pilot["phase_dir"] = str(phase_dir)
        for check in pilot["noise_checks"]:
            check["forbidden_terms"] = [
                term for term in check["forbidden_terms"] if term != "IF-HOME"
            ]
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_fail \
  "cross feature interface residue blocklist escape" \
  "forbidden term if-home" \
  python3 "$TOOL" --audit "$interface_residue_escape_audit"

no_red_root="$TMP_DIR/no-red"
mkdir -p "$no_red_root"
cp -R "$ROOT/docs/feedback-thanks-pilot" "$no_red_root/feedback-thanks-pilot"
python3 - "$no_red_root/feedback-thanks-pilot/phase-1/unit-1/tasks/T1/developer-report.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
for item in payload["tdd_evidence_index"]:
    if item.get("phase") == "RED":
        item["result"] = "PASS"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

no_red_audit="$TMP_DIR/no-red-audit.json"
make_audit_copy "$no_red_audit"
python3 - "$no_red_audit" "$no_red_root/feedback-thanks-pilot/phase-1" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
phase_dir = Path(sys.argv[2])
payload = json.loads(path.read_text(encoding="utf-8"))
for pilot in payload["pilots"]:
    if pilot["feature_id"] == "feedback-thanks-pilot":
        pilot["phase_dir"] = str(phase_dir)
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_fail \
  "missing RED evidence" \
  "missing RED FAIL_EXPECTED evidence" \
  python3 "$TOOL" --audit "$no_red_audit"

printf '[PASS] standard-chain pilot audit\n'
