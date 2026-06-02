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

SCRIPT="$ROOT/tools/eval/scripts/validate_stage2_product_manager_package.py"
[ -f "$SCRIPT" ] || fail "missing Stage 2 product-manager package validator"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PACKAGE="$TMP_ROOT/product-manager-package.json"
python3 - "$ROOT" "$PACKAGE" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools/eval/scripts"))

from render_stage2_product_director_handoff import render
from validate_stage2_confirmed_brief_materials import build_package as build_confirmed_package
from validate_stage2_intake_gate import DEFAULT_INTAKE, load_json
from validate_stage2_product_director_handoff_materials import make_real_candidate
from validate_stage2_product_manager_materials_builder import build_pm_package

example_payload = load_json(root / DEFAULT_INTAKE.relative_to(root))
handoff, handoff_exit = render(
    make_real_candidate(example_payload), Path("real-stage2-intake-facts.json")
)
if handoff_exit != 0:
    raise SystemExit(handoff)

package = build_pm_package(build_confirmed_package(handoff))
Path(sys.argv[2]).write_text(
    json.dumps(package, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
PY

python3 "$SCRIPT" --package "$PACKAGE" >"$TMP_ROOT/package-pass.json" \
  || fail "valid Stage 2 product-manager package should pass"
python3 - "$TMP_ROOT/package-pass.json" <<'PY' || fail "Stage 2 product-manager package output mismatch"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit(payload)
if payload.get("stage2_readiness") != "product_manager_prd_ready_for_design":
    raise SystemExit(payload)
if payload.get("next_standard_chain_role") != "design":
    raise SystemExit(payload)
expected = {
    "package_envelope",
    "confirmed_brief_binding",
    "director_lock_preservation",
    "pm_artifacts",
    "pm_review_closure",
    "authorization_boundary",
}
checks = {item.get("check") for item in payload.get("checks", [])}
missing = sorted(expected - checks)
if missing:
    raise SystemExit(f"missing checks: {missing}")
PY

BROKEN_UNIT="$TMP_ROOT/broken-unit.json"
python3 - "$PACKAGE" "$BROKEN_UNIT" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["units"][0].pop("acceptance_criteria", None)
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BROKEN_UNIT" >"$TMP_ROOT/broken-unit-output.json"; then
  fail "product-manager package must reject UNIT without acceptance_criteria"
fi
rg -q "acceptance_criteria" "$TMP_ROOT/broken-unit-output.json" \
  || fail "UNIT acceptance_criteria failure should be explicit"

BROKEN_UNIT_SOURCE_REFS="$TMP_ROOT/broken-unit-source-refs.json"
python3 - "$PACKAGE" "$BROKEN_UNIT_SOURCE_REFS" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["units"][0]["acceptance_criteria"][0].pop("source_refs", None)
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BROKEN_UNIT_SOURCE_REFS" >"$TMP_ROOT/broken-unit-source-refs-output.json"; then
  fail "product-manager package must reject UNIT acceptance_criteria without source_refs"
fi
rg -q "source_refs" "$TMP_ROOT/broken-unit-source-refs-output.json" \
  || fail "UNIT acceptance_criteria source_refs failure should be explicit"

DRIFT="$TMP_ROOT/director-drift.json"
python3 - "$PACKAGE" "$DRIFT" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["phase_prd"]["phase_goal"] = "PM illegally rewrote the Director phase goal"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$DRIFT" >"$TMP_ROOT/director-drift-output.json"; then
  fail "product-manager package must reject Director-owned phase drift"
fi
rg -q "Director|phase_goal" "$TMP_ROOT/director-drift-output.json" \
  || fail "Director drift failure should be explicit"

BAD_BOUNDARY="$TMP_ROOT/bad-boundary.json"
python3 - "$PACKAGE" "$BAD_BOUNDARY" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["decision_boundary"]["blocked_actions"] = [
    item for item in payload["decision_boundary"]["blocked_actions"] if item != "auto_send"
]
payload["decision_boundary"]["allowed_actions"].append("language_selection")
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BAD_BOUNDARY" >"$TMP_ROOT/bad-boundary-output.json"; then
  fail "product-manager package must reject authorization boundary drift"
fi
rg -q "auto_send|language_selection" "$TMP_ROOT/bad-boundary-output.json" \
  || fail "authorization boundary failure should be explicit"

BROKEN_CLOSURE="$TMP_ROOT/broken-closure.json"
python3 - "$PACKAGE" "$BROKEN_CLOSURE" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["brief"].pop("review_conclusion", None)
payload["brief"].pop("issue_ledger", None)
payload["brief"].pop("delivery_confirmation", None)
payload["phase_prd"].pop("review_conclusion", None)
payload["phase_prd"].pop("issue_ledger", None)
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BROKEN_CLOSURE" >"$TMP_ROOT/broken-closure-output.json"; then
  fail "product-manager package must reject missing review closure and delivery confirmation"
fi
rg -q "review_conclusion|issue_ledger|delivery_confirmation" "$TMP_ROOT/broken-closure-output.json" \
  || fail "review closure failure should be explicit"

printf '[PASS] Stage 2 product-manager package gate\n'
