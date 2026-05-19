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

SCRIPT="$ROOT/tools/eval/scripts/render_stage2_product_director_handoff.py"
EXAMPLE="$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/stage-2-intake-facts.example.json"

[ -f "$SCRIPT" ] || fail "missing Stage 2 product-director handoff renderer"
[ -f "$EXAMPLE" ] || fail "missing Stage 2 intake facts example"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

if python3 "$SCRIPT" --intake "$EXAMPLE" >"$TMP_ROOT/example-blocked.json"; then
  fail "example intake should not render product-director handoff"
fi
rg -q "fill_real_stage2_intake_facts" "$TMP_ROOT/example-blocked.json" \
  || fail "example block should preserve required owner action"

REAL_INTAKE="$TMP_ROOT/real-stage2-intake-facts.json"
python3 - "$EXAMPLE" "$REAL_INTAKE" <<'PY'
import json
import sys
from pathlib import Path

source = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
source["intake_provenance"] = {
    "source_type": "human_business_owner_input",
    "filled_by": "产研负责人",
    "confirmed_by": "客服运营负责人",
    "confirmed_at": "2026-05-14",
    "confirmation_basis": "human/business owner 明确确认该文件用于 Stage 2 真实采证入口",
    "fact_source_refs": [
        "human://客服运营负责人/stage-2-intake-confirmation/2026-05-14",
        "doc://stage-2-intake-business-sample",
    ],
    "not_copied_from_example": True,
}
Path(sys.argv[2]).write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

HANDOFF_OUTPUT="$TMP_ROOT/handoff.json"
python3 "$SCRIPT" --intake "$REAL_INTAKE" >"$HANDOFF_OUTPUT" \
  || fail "real Stage 2 intake should render product-director handoff"

python3 - "$HANDOFF_OUTPUT" <<'PY' || fail "product-director handoff output mismatch"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit(payload)
if payload.get("artifact_type") != "stage-2-product-director-handoff":
    raise SystemExit(payload)
if payload.get("handoff_owner_role") != "product-director":
    raise SystemExit(payload)
if payload.get("input_origin") != "stage-2-intake-facts":
    raise SystemExit(payload)
if payload.get("stage2_readiness") != "intake_complete_for_discovery":
    raise SystemExit(payload)
if payload.get("next_required_action") != "start_product_director_confirmed_brief":
    raise SystemExit(payload)

boundary = payload.get("discovery_boundary", {})
for action in ["real_qft_pai_discovery", "confirmed_brief_drafting", "phase1_boundary_freeze"]:
    if action not in boundary.get("allowed_actions", []):
        raise SystemExit(payload)
for action in ["language_selection", "architecture_finalization", "code_changes", "commit", "deploy", "auto_send", "business_risk_acceptance"]:
    if action not in boundary.get("blocked_actions", []):
        raise SystemExit(payload)

steps = payload.get("required_product_director_steps", [])
if steps != ["D-S1", "D-S2", "D-S3", "D-S4", "D-S5", "D-S5.5", "D-S6", "D-G1"]:
    raise SystemExit(payload)

source_refs = payload.get("source_refs", [])
if not any(str(ref).startswith("human://") for ref in source_refs):
    raise SystemExit(payload)
if not any(str(ref).startswith("doc://") for ref in source_refs):
    raise SystemExit(payload)

focus = payload.get("director_focus", {})
for key in [
    "business_context",
    "root_problem_input",
    "target_outcome",
    "phase1_candidate_boundary",
    "success_metric_names",
    "success_metrics",
    "acceptance_owner",
    "risk_acceptance_boundary",
]:
    if key not in focus:
        raise SystemExit(payload)
business_context = focus.get("business_context", {})
for key in ["sample_name", "business_owner", "real_user", "scenario"]:
    if not business_context.get(key):
        raise SystemExit(payload)
success_metrics = focus.get("success_metrics", [])
if len(success_metrics) < 2:
    raise SystemExit(payload)
for metric in success_metrics:
    for key in ["metric_id", "name", "threshold", "measurement_source", "owner"]:
        if not metric.get(key):
            raise SystemExit(payload)
acceptance_owner = focus.get("acceptance_owner", {})
for key in ["name", "role", "decision_authority", "acceptance_method"]:
    if not acceptance_owner.get(key):
        raise SystemExit(payload)
PY

printf '[PASS] Stage 2 product-director handoff renderer\n'
