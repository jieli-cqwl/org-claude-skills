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

SCRIPT="$ROOT/tools/eval/scripts/validate_stage2_intake_gate.py"
TEMPLATE="$ROOT/docs/feature--agent-delivery-operating-system/stage-2-intake-facts.template.json"
EXAMPLE="$ROOT/docs/feature--agent-delivery-operating-system/stage-2-intake-facts.example.json"
GUIDE="$ROOT/docs/feature--agent-delivery-operating-system/stage-2-intake-gate.md"
CHARTER="$ROOT/docs/feature--agent-delivery-operating-system/stage-1-eval-charter.md"
GOAL_DOC="$ROOT/docs/feature--agent-delivery-operating-system/goal-and-success-criteria.md"

[ -f "$SCRIPT" ] || fail "missing Stage 2 intake validator"
[ -f "$TEMPLATE" ] || fail "missing Stage 2 intake facts template"
[ -f "$EXAMPLE" ] || fail "missing Stage 2 intake facts example"
[ -f "$GUIDE" ] || fail "missing Stage 2 intake gate guide"
[ -f "$CHARTER" ] || fail "missing Stage 1 eval charter"
[ -f "$GOAL_DOC" ] || fail "missing goal and success criteria"
rg -q "stage2_route" "$GUIDE" || fail "Stage 2 guide should document stage2_route"
rg -q "fact_source_refs" "$GUIDE" || fail "Stage 2 guide should document fact_source_refs"
rg -q "business_risk_acceptance" "$GUIDE" || fail "Stage 2 guide should document business_risk_acceptance block"
rg -q "validate_stage2_confirmed_brief_package.py" "$GUIDE" || fail "Stage 2 guide should document confirmed brief package gate"
rg -q "validate_stage2_product_manager_package.py" "$GUIDE" || fail "Stage 2 guide should document product-manager package gate"
rg -q "validate_stage2_design_package.py" "$GUIDE" || fail "Stage 2 guide should document design package gate"
rg -q "validate_stage2_test_design_package.py" "$GUIDE" || fail "Stage 2 guide should document test-design package gate"
rg -q "validate_stage2_tech_lead_package.py" "$GUIDE" || fail "Stage 2 guide should document tech-lead package gate"
rg -q "stage-2-intake-facts" "$CHARTER" || fail "Stage 1 charter should bind Stage 2 entry to intake facts"
rg -q "render_stage2_product_director_handoff.py" "$CHARTER" || fail "Stage 1 charter should bind Stage 2 entry to product-director handoff"
rg -q "validate_stage2_confirmed_brief_package.py" "$CHARTER" || fail "Stage 1 charter should bind Stage 2 entry to confirmed brief package gate"
rg -q "validate_stage2_product_manager_package.py" "$CHARTER" || fail "Stage 1 charter should bind Stage 2 entry to product-manager package gate"
rg -q "validate_stage2_design_package.py" "$CHARTER" || fail "Stage 1 charter should bind Stage 2 entry to design package gate"
rg -q "validate_stage2_test_design_package.py" "$CHARTER" || fail "Stage 1 charter should bind Stage 2 entry to test-design package gate"
rg -q "validate_stage2_tech_lead_package.py" "$CHARTER" || fail "Stage 1 charter should bind Stage 2 entry to tech-lead package gate"
rg -q "stage-2-intake-facts" "$GOAL_DOC" || fail "Goal doc should bind Stage 2 entry to intake facts"
rg -q "render_stage2_product_director_handoff.py" "$GOAL_DOC" || fail "Goal doc should bind Stage 2 entry to product-director handoff"
rg -q "validate_stage2_confirmed_brief_package.py" "$GOAL_DOC" || fail "Goal doc should bind Stage 2 entry to confirmed brief package gate"
rg -q "validate_stage2_product_manager_package.py" "$GOAL_DOC" || fail "Goal doc should bind Stage 2 entry to product-manager package gate"
rg -q "validate_stage2_design_package.py" "$GOAL_DOC" || fail "Goal doc should bind Stage 2 entry to design package gate"
rg -q "validate_stage2_test_design_package.py" "$GOAL_DOC" || fail "Goal doc should bind Stage 2 entry to test-design package gate"
rg -q "validate_stage2_tech_lead_package.py" "$GOAL_DOC" || fail "Goal doc should bind Stage 2 entry to tech-lead package gate"
rg -q '"fact_source_refs"' "$TEMPLATE" || fail "Stage 2 template should expose fact_source_refs"
rg -q "fixture://stage-2-intake-example" "$EXAMPLE" || fail "Stage 2 example should declare fixture source ref"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS_OUTPUT="$TMP_ROOT/pass.json"
python3 "$SCRIPT" --intake "$EXAMPLE" >"$PASS_OUTPUT" \
  || fail "complete Stage 2 intake example should pass structural gate"

python3 - "$PASS_OUTPUT" <<'PY' || fail "Stage 2 intake pass output mismatch"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit(payload)
if payload.get("intake_kind") != "example":
    raise SystemExit(payload)
if payload.get("stage2_readiness") != "materials_verified_not_authorization":
    raise SystemExit(payload)
if payload.get("stage2_discovery_entry_allowed") is not False:
    raise SystemExit(payload)
route = payload.get("stage2_route") or {}
if route.get("next_standard_chain_role") is not None:
    raise SystemExit(payload)
if route.get("required_owner_action") != "fill_real_stage2_intake_facts":
    raise SystemExit(payload)
for action in ["language_selection", "code_changes", "commit", "deploy", "auto_send"]:
    if action not in route.get("blocked_actions", []):
        raise SystemExit(payload)
expected = {
    "intake_provenance",
    "business_sample",
    "acceptance_owner",
    "success_metrics",
    "execution_environment",
    "qft_pai_scope",
    "integration_boundaries",
    "gray_rollback",
    "risk_acceptance",
    "stage2_non_goals",
}
checks = {item.get("check") for item in payload.get("checks", [])}
missing = sorted(expected - checks)
if missing:
    raise SystemExit(f"missing checks: {missing}")
PY

REAL_INTAKE="$TMP_ROOT/real-stage2-intake-facts.json"
cp "$EXAMPLE" "$REAL_INTAKE"
if python3 "$SCRIPT" --intake "$REAL_INTAKE" >"$TMP_ROOT/real-copy-blocked.json"; then
  fail "renamed Stage 2 intake example should not pass as real facts"
fi
rg -q "intake_provenance.source_type" "$TMP_ROOT/real-copy-blocked.json" \
  || fail "renamed example failure should name intake_provenance.source_type"

python3 - "$REAL_INTAKE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
source = json.loads(path.read_text(encoding="utf-8"))
source["intake_provenance"] = {
    "source_type": "human_business_owner_input",
    "filled_by": "产研负责人",
    "confirmed_by": "客服运营负责人",
    "confirmed_at": "2026-05-14",
    "confirmation_basis": "human/business owner 明确确认该文件用于 Stage 2 真实采证入口",
    "not_copied_from_example": True,
}
path.write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

if python3 "$SCRIPT" --intake "$REAL_INTAKE" >"$TMP_ROOT/real-source-blocked.json"; then
  fail "real Stage 2 intake facts without real source refs should not pass discovery gate"
fi
rg -q "intake_provenance.fact_source_refs" "$TMP_ROOT/real-source-blocked.json" \
  || fail "missing real source refs failure should name intake_provenance.fact_source_refs"

python3 - "$REAL_INTAKE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
source = json.loads(path.read_text(encoding="utf-8"))
source["intake_provenance"]["fact_source_refs"] = [
    "human://客服运营负责人/stage-2-intake-confirmation/2026-05-14",
    "doc://stage-2-intake-business-sample",
]
path.write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

REAL_OUTPUT="$TMP_ROOT/real-pass.json"
python3 "$SCRIPT" --intake "$REAL_INTAKE" >"$REAL_OUTPUT" \
  || fail "complete real Stage 2 intake facts should pass discovery gate"
python3 - "$REAL_OUTPUT" <<'PY' || fail "real Stage 2 intake output mismatch"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit(payload)
if payload.get("intake_kind") != "real_intake_candidate":
    raise SystemExit(payload)
if payload.get("stage2_readiness") != "intake_complete_for_discovery":
    raise SystemExit(payload)
if payload.get("stage2_discovery_entry_allowed") is not True:
    raise SystemExit(payload)
route = payload.get("stage2_route") or {}
if route.get("next_standard_chain_role") != "product-director":
    raise SystemExit(payload)
if route.get("required_owner_action") != "start_product_director_confirmed_brief":
    raise SystemExit(payload)
for action in ["real_qft_pai_discovery", "confirmed_brief_drafting", "phase1_boundary_freeze"]:
    if action not in route.get("allowed_actions", []):
        raise SystemExit(payload)
for action in ["language_selection", "architecture_finalization", "code_changes", "commit", "deploy", "auto_send"]:
    if action not in route.get("blocked_actions", []):
        raise SystemExit(payload)
PY

if python3 "$SCRIPT" --intake "$TEMPLATE" >"$TMP_ROOT/template-output.json"; then
  fail "unfilled Stage 2 intake template should not pass structural gate"
fi
rg -q "business_sample.sample_name" "$TMP_ROOT/template-output.json" \
  || fail "template failure should name missing business_sample.sample_name"

BROKEN="$TMP_ROOT/missing-risk-owner.json"
python3 - "$EXAMPLE" "$BROKEN" <<'PY'
import json
import sys
from pathlib import Path

source = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
source["risk_acceptance"]["business_owner"] = ""
Path(sys.argv[2]).write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

if python3 "$SCRIPT" --intake "$BROKEN" >"$TMP_ROOT/broken-risk.json"; then
  fail "missing risk owner should block Stage 2 intake"
fi
rg -q "risk_acceptance.business_owner" "$TMP_ROOT/broken-risk.json" \
  || fail "missing risk owner failure should name risk_acceptance.business_owner"

BROKEN_ROLLBACK="$TMP_ROOT/missing-rollback.json"
python3 - "$EXAMPLE" "$BROKEN_ROLLBACK" <<'PY'
import json
import sys
from pathlib import Path

source = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
source["gray_rollback"]["rollback_owner"] = ""
Path(sys.argv[2]).write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

if python3 "$SCRIPT" --intake "$BROKEN_ROLLBACK" >"$TMP_ROOT/broken-rollback.json"; then
  fail "missing rollback owner should block Stage 2 intake"
fi
rg -q "gray_rollback.rollback_owner" "$TMP_ROOT/broken-rollback.json" \
  || fail "missing rollback owner failure should name gray_rollback.rollback_owner"

printf '[PASS] Stage 2 intake gate\n'
