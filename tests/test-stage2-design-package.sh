#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

SCRIPT="$ROOT/tools/eval/scripts/validate_stage2_design_package.py"
[ -f "$SCRIPT" ] || fail "missing Stage 2 design package validator"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PACKAGE="$TMP_ROOT/design-package.json"
python3 - "$ROOT" "$PACKAGE" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools/eval/scripts"))

from render_stage2_product_director_handoff import render
from validate_stage2_confirmed_brief_materials import build_package as build_confirmed_package
from validate_stage2_design_materials import build_design_package
from validate_stage2_intake_gate import DEFAULT_INTAKE, load_json
from validate_stage2_product_director_handoff_materials import make_real_candidate
from validate_stage2_product_manager_materials import build_pm_package

example_payload = load_json(root / DEFAULT_INTAKE.relative_to(root))
handoff, handoff_exit = render(make_real_candidate(example_payload), Path("real-stage2-intake-facts.json"))
if handoff_exit != 0:
    raise SystemExit(handoff)

pm_package = build_pm_package(build_confirmed_package(handoff))
package = build_design_package(pm_package)
Path(sys.argv[2]).write_text(json.dumps(package, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

python3 "$SCRIPT" --package "$PACKAGE" >"$TMP_ROOT/package-pass.json" \
  || fail "valid Stage 2 design package should pass"
python3 - "$TMP_ROOT/package-pass.json" <<'PY' || fail "Stage 2 design package output mismatch"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit(payload)
if payload.get("stage2_readiness") != "design_ready_for_test_design":
    raise SystemExit(payload)
if payload.get("next_standard_chain_role") != "test-design":
    raise SystemExit(payload)
expected = {
    "package_envelope",
    "product_manager_binding",
    "design_artifact",
    "design_review_digest",
    "design_reference_integrity",
    "design_ledger",
    "authorization_boundary",
}
checks = {item.get("check") for item in payload.get("checks", [])}
missing = sorted(expected - checks)
if missing:
    raise SystemExit(f"missing checks: {missing}")
PY

BROKEN_CONFIRMATION="$TMP_ROOT/broken-confirmation.json"
python3 - "$PACKAGE" "$BROKEN_CONFIRMATION" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["design"].pop("final_confirmation", None)
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BROKEN_CONFIRMATION" >"$TMP_ROOT/broken-confirmation-output.json"; then
  fail "design package must reject design without final_confirmation"
fi
rg -q "final_confirmation" "$TMP_ROOT/broken-confirmation-output.json" \
  || fail "final_confirmation failure should be explicit"

BROKEN_COVERAGE="$TMP_ROOT/broken-coverage.json"
python3 - "$PACKAGE" "$BROKEN_COVERAGE" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["design"]["unit_coverage"] = []
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BROKEN_COVERAGE" >"$TMP_ROOT/broken-coverage-output.json"; then
  fail "design package must reject missing UNIT coverage"
fi
rg -q "unit_coverage|unit_not_covered_by_design|UNIT-1" "$TMP_ROOT/broken-coverage-output.json" \
  || fail "UNIT coverage failure should be explicit"

BROKEN_LEDGER="$TMP_ROOT/broken-ledger.json"
python3 - "$PACKAGE" "$BROKEN_LEDGER" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["design_ledger"]["confirmations"] = [
    item for item in payload["design_ledger"]["confirmations"] if item["step"] != "option-tradeoff"
]
payload["design_ledger"]["latest_checkpoint_id"] = payload["design_ledger"]["confirmations"][-1]["checkpoint_id"]
payload["design_ledger"]["finalization_basis"]["accepted_checkpoint_ids"] = [
    item["checkpoint_id"] for item in payload["design_ledger"]["confirmations"]
]
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BROKEN_LEDGER" >"$TMP_ROOT/broken-ledger-output.json"; then
  fail "design package must reject ledger missing option-tradeoff"
fi
rg -q "option-tradeoff|ledger" "$TMP_ROOT/broken-ledger-output.json" \
  || fail "ledger failure should be explicit"

BAD_BOUNDARY="$TMP_ROOT/bad-boundary.json"
python3 - "$PACKAGE" "$BAD_BOUNDARY" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["decision_boundary"]["blocked_actions"] = [
    item for item in payload["decision_boundary"]["blocked_actions"] if item != "code_changes"
]
payload["decision_boundary"]["allowed_actions"].append("code_changes")
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BAD_BOUNDARY" >"$TMP_ROOT/bad-boundary-output.json"; then
  fail "design package must reject implementation authorization drift"
fi
rg -q "code_changes" "$TMP_ROOT/bad-boundary-output.json" \
  || fail "authorization boundary failure should be explicit"

MALFORMED_PM="$TMP_ROOT/malformed-pm-package.json"
python3 - "$PACKAGE" "$MALFORMED_PM" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["product_manager_package"] = {}
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$MALFORMED_PM" >"$TMP_ROOT/malformed-pm-output.json"; then
  fail "design package must reject malformed PM package"
fi
python3 - "$TMP_ROOT/malformed-pm-output.json" <<'PY' || fail "malformed PM package failure should stay JSON"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "fail":
    raise SystemExit(payload)
joined = "\n".join(payload.get("failed_checks", []))
if "product_manager_package" not in joined:
    raise SystemExit(payload)
PY

printf '[PASS] Stage 2 design package gate\n'
