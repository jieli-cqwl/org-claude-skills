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

SCRIPT="$ROOT/tools/eval/scripts/validate_stage2_tech_lead_package.py"
[ -f "$SCRIPT" ] || fail "missing Stage 2 tech-lead package validator"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PACKAGE="$TMP_ROOT/tech-lead-package.json"
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
from validate_stage2_tech_lead_materials import build_tech_lead_package
from validate_stage2_test_design_materials import build_test_design_package

example_payload = load_json(root / DEFAULT_INTAKE.relative_to(root))
handoff, handoff_exit = render(make_real_candidate(example_payload), Path("real-stage2-intake-facts.json"))
if handoff_exit != 0:
    raise SystemExit(handoff)

pm_package = build_pm_package(build_confirmed_package(handoff))
design_package = build_design_package(pm_package)
test_design_package = build_test_design_package(design_package)
package = build_tech_lead_package(test_design_package)
Path(sys.argv[2]).write_text(json.dumps(package, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

python3 "$SCRIPT" --package "$PACKAGE" >"$TMP_ROOT/package-pass.json" \
  || fail "valid Stage 2 tech-lead package should pass"
python3 - "$TMP_ROOT/package-pass.json" <<'PY' || fail "Stage 2 tech-lead package output mismatch"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit(payload)
if payload.get("stage2_readiness") != "tech_lead_ready_for_delivery_owner":
    raise SystemExit(payload)
if payload.get("next_standard_chain_role") != "delivery-owner":
    raise SystemExit(payload)
expected = {
    "package_envelope",
    "test_design_package_binding",
    "plan_artifact",
    "tasks_artifact",
    "artifact_registry",
    "planning_preflight",
    "planning_semantic_integrity",
    "delivery_owner_intake",
    "authorization_boundary",
}
checks = {item.get("check") for item in payload.get("checks", [])}
missing = sorted(expected - checks)
if missing:
    raise SystemExit(f"missing checks: {missing}")
PY

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
  fail "tech-lead package must reject implementation boundary drift"
fi
rg -q "code_changes" "$TMP_ROOT/bad-boundary-output.json" \
  || fail "authorization boundary failure should be explicit"

UNCONFIRMED="$TMP_ROOT/unconfirmed-tasks.json"
python3 - "$PACKAGE" "$UNCONFIRMED" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["tasks"]["user_confirmation"]["status"] = "PENDING"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$UNCONFIRMED" >"$TMP_ROOT/unconfirmed-output.json"; then
  fail "tech-lead package must reject unconfirmed tasks"
fi
rg -q "user_confirmation|BASELINE_NOT_CONFIRMED|CONFIRMED" "$TMP_ROOT/unconfirmed-output.json" \
  || fail "unconfirmed tasks failure should be explicit"

UNKNOWN_DEP="$TMP_ROOT/unknown-dependency.json"
python3 - "$PACKAGE" "$UNKNOWN_DEP" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["tasks"]["tasks"][0]["depends_on"] = ["TASK-DOES-NOT-EXIST"]
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$UNKNOWN_DEP" >"$TMP_ROOT/unknown-dependency-output.json"; then
  fail "tech-lead package must reject dependency drift"
fi
rg -q "depends_on|DEPENDENCY_DRIFT|unknown task" "$TMP_ROOT/unknown-dependency-output.json" \
  || fail "dependency drift failure should be explicit"

MISSING_QA="$TMP_ROOT/missing-qa-handoff.json"
python3 - "$PACKAGE" "$MISSING_QA" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["test_design_package"]["test_cases"]["qa_handoff_contract"] = []
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$MISSING_QA" >"$TMP_ROOT/missing-qa-output.json"; then
  fail "tech-lead package must reject missing QA handoff baseline"
fi
rg -q "qa_handoff_contract|MISSING_QA_HANDOFF|test_cases" "$TMP_ROOT/missing-qa-output.json" \
  || fail "missing QA handoff failure should be explicit"

printf '[PASS] Stage 2 tech-lead package gate\n'
