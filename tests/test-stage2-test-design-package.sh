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

SCRIPT="$ROOT/tools/eval/scripts/validate_stage2_test_design_package.py"
[ -f "$SCRIPT" ] || fail "missing Stage 2 test-design package validator"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PACKAGE="$TMP_ROOT/test-design-package.json"
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
from validate_stage2_test_design_materials import build_test_design_package

example_payload = load_json(root / DEFAULT_INTAKE.relative_to(root))
handoff, handoff_exit = render(make_real_candidate(example_payload), Path("real-stage2-intake-facts.json"))
if handoff_exit != 0:
    raise SystemExit(handoff)

pm_package = build_pm_package(build_confirmed_package(handoff))
design_package = build_design_package(pm_package)
package = build_test_design_package(design_package)
Path(sys.argv[2]).write_text(json.dumps(package, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

python3 "$SCRIPT" --package "$PACKAGE" >"$TMP_ROOT/package-pass.json" \
  || fail "valid Stage 2 test-design package should pass"
python3 - "$TMP_ROOT/package-pass.json" <<'PY' || fail "Stage 2 test-design package output mismatch"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit(payload)
if payload.get("stage2_readiness") != "test_design_ready_for_tech_lead":
    raise SystemExit(payload)
if payload.get("next_standard_chain_role") != "tech-lead":
    raise SystemExit(payload)
expected = {
    "package_envelope",
    "design_package_binding",
    "test_cases_artifact",
    "test_cases_review_digest",
    "test_cases_semantic_integrity",
    "authorization_boundary",
}
checks = {item.get("check") for item in payload.get("checks", [])}
missing = sorted(expected - checks)
if missing:
    raise SystemExit(f"missing checks: {missing}")
PY

BLOCKING_GAP="$TMP_ROOT/blocking-gap.json"
python3 - "$PACKAGE" "$BLOCKING_GAP" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["test_cases"]["design_gap_report"] = {
    "status": "HAS_GAPS",
    "gaps": [
        {
            "gap_id": "GAP-TD-001",
            "gap_type": "DESIGN_GAP",
            "blocking_refs": ["design.json#rollback_plan[0]"],
            "owner": "design",
            "next_action": "补齐回滚策略后重新生成 test-design package",
            "blocking": True,
        }
    ],
}
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BLOCKING_GAP" >"$TMP_ROOT/blocking-gap-output.json"; then
  fail "test-design package must reject blocking typed gap"
fi
rg -q "blocking gap|blocking=true|design_gap_report" "$TMP_ROOT/blocking-gap-output.json" \
  || fail "blocking gap failure should be explicit"

DIGEST_DRIFT="$TMP_ROOT/digest-drift.json"
python3 - "$PACKAGE" "$DIGEST_DRIFT" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["test_cases"]["review_conclusion"]["reviewed_test_cases_digest"] = "sha256:" + "0" * 64
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$DIGEST_DRIFT" >"$TMP_ROOT/digest-drift-output.json"; then
  fail "test-design package must reject digest drift"
fi
rg -q "reviewed_test_cases_digest|digest" "$TMP_ROOT/digest-drift-output.json" \
  || fail "digest drift failure should be explicit"

MISSING_SPECIAL="$TMP_ROOT/missing-special.json"
python3 - "$PACKAGE" "$MISSING_SPECIAL" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["test_cases"]["special_test_triggers"] = []
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$MISSING_SPECIAL" >"$TMP_ROOT/missing-special-output.json"; then
  fail "test-design package must reject missing specialty triggers"
fi
rg -q "special_test_triggers" "$TMP_ROOT/missing-special-output.json" \
  || fail "special trigger failure should be explicit"

BAD_BOUNDARY="$TMP_ROOT/bad-boundary.json"
python3 - "$PACKAGE" "$BAD_BOUNDARY" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["decision_boundary"]["blocked_actions"] = [
    item for item in payload["decision_boundary"]["blocked_actions"] if item != "task_decomposition"
]
payload["decision_boundary"]["allowed_actions"].append("task_decomposition")
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BAD_BOUNDARY" >"$TMP_ROOT/bad-boundary-output.json"; then
  fail "test-design package must reject tech-lead boundary drift"
fi
rg -q "task_decomposition" "$TMP_ROOT/bad-boundary-output.json" \
  || fail "authorization boundary failure should be explicit"

printf '[PASS] Stage 2 test-design package gate\n'
