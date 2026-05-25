#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

SCRIPT="$ROOT/tools/eval/scripts/run_stage1_eval_checks.py"
[ -f "$SCRIPT" ] || fail "missing stage 1 eval checks runner"

TMP_OUTPUT="$(mktemp)"
trap 'rm -f "$TMP_OUTPUT"' EXIT

python3 "$SCRIPT" >"$TMP_OUTPUT" || fail "stage 1 eval checks runner should pass"

python3 - "$TMP_OUTPUT" <<'PY' || fail "stage 1 eval checks runner output mismatch"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit(payload)
if payload.get("failed_checks"):
    raise SystemExit(payload["failed_checks"])

checks = {item.get("check"): item for item in payload.get("checks", [])}
expected = {
    "dry_run_graders",
    "artifact_structure_contracts",
    "resume_chain",
    "stage2_intake_gate",
    "stage2_product_director_handoff",
    "stage2_confirmed_brief_package",
    "stage2_product_manager_package",
    "stage2_director_pm_move_in_chain",
    "stage2_design_package",
    "stage2_test_design_package",
    "stage2_tech_lead_package",
}
missing = sorted(expected - set(checks))
if missing:
    raise SystemExit(f"missing runner checks: {missing}")
for name in expected:
    if checks[name].get("status") != "pass":
        raise SystemExit(f"{name} did not pass: {checks[name]}")

stage2_payload = checks["stage2_intake_gate"].get("payload", {})
if stage2_payload.get("intake_kind") != "example":
    raise SystemExit(stage2_payload)
if stage2_payload.get("stage2_readiness") != "materials_verified_not_authorization":
    raise SystemExit(stage2_payload)
if stage2_payload.get("stage2_discovery_entry_allowed") is not False:
    raise SystemExit(stage2_payload)
route = stage2_payload.get("stage2_route") or {}
if route.get("next_standard_chain_role") is not None:
    raise SystemExit(stage2_payload)
if route.get("required_owner_action") != "fill_real_stage2_intake_facts":
    raise SystemExit(stage2_payload)
if "code_changes" not in route.get("blocked_actions", []):
    raise SystemExit(stage2_payload)
stage2_checks = {item.get("check") for item in stage2_payload.get("checks", [])}
if "intake_provenance" not in stage2_checks:
    raise SystemExit(stage2_payload)

handoff_payload = checks["stage2_product_director_handoff"].get("payload", {})
if handoff_payload.get("status") != "pass":
    raise SystemExit(handoff_payload)
if handoff_payload.get("example_block_reason") != "product_director_handoff_not_allowed":
    raise SystemExit(handoff_payload)
real_handoff = handoff_payload.get("real_handoff", {})
if real_handoff.get("handoff_owner_role") != "product-director":
    raise SystemExit(handoff_payload)
if real_handoff.get("next_required_action") != "start_product_director_confirmed_brief":
    raise SystemExit(handoff_payload)
if "code_changes" not in real_handoff.get("discovery_boundary", {}).get("blocked_actions", []):
    raise SystemExit(handoff_payload)

confirmed_brief_payload = checks["stage2_confirmed_brief_package"].get("payload", {})
if confirmed_brief_payload.get("status") != "pass":
    raise SystemExit(confirmed_brief_payload)
if confirmed_brief_payload.get("stage2_readiness") != "confirmed_brief_ready_for_product_manager":
    raise SystemExit(confirmed_brief_payload)
if confirmed_brief_payload.get("next_standard_chain_role") != "product-manager":
    raise SystemExit(confirmed_brief_payload)
if "code_changes" not in confirmed_brief_payload.get("validated_blocked_actions", []):
    raise SystemExit(confirmed_brief_payload)

product_manager_payload = checks["stage2_product_manager_package"].get("payload", {})
if product_manager_payload.get("status") != "pass":
    raise SystemExit(product_manager_payload)
if product_manager_payload.get("stage2_readiness") != "product_manager_prd_ready_for_design":
    raise SystemExit(product_manager_payload)
if product_manager_payload.get("next_standard_chain_role") != "design":
    raise SystemExit(product_manager_payload)
if "auto_send" not in product_manager_payload.get("validated_blocked_actions", []):
    raise SystemExit(product_manager_payload)

director_pm_payload = checks["stage2_director_pm_move_in_chain"].get("payload", {})
if director_pm_payload.get("status") != "pass":
    raise SystemExit(director_pm_payload)
if director_pm_payload.get("stage2_readiness") != "director_manager_chain_meets_move_in_prd_rubric":
    raise SystemExit(director_pm_payload)
if director_pm_payload.get("rubric_summary", {}).get("coverage") != "complete":
    raise SystemExit(director_pm_payload)
chain_checks = {item.get("check") for item in director_pm_payload.get("checks", [])}
for required_check in {
    "director_boundary",
    "product_manager_package",
    "golden_prd_rubric",
    "downstream_consumability",
}:
    if required_check not in chain_checks:
        raise SystemExit(director_pm_payload)

design_payload = checks["stage2_design_package"].get("payload", {})
if design_payload.get("status") != "pass":
    raise SystemExit(design_payload)
if design_payload.get("stage2_readiness") != "design_ready_for_test_design":
    raise SystemExit(design_payload)
if design_payload.get("next_standard_chain_role") != "test-design":
    raise SystemExit(design_payload)
if "code_changes" not in design_payload.get("validated_blocked_actions", []):
    raise SystemExit(design_payload)

test_design_payload = checks["stage2_test_design_package"].get("payload", {})
if test_design_payload.get("status") != "pass":
    raise SystemExit(test_design_payload)
if test_design_payload.get("stage2_readiness") != "test_design_ready_for_tech_lead":
    raise SystemExit(test_design_payload)
if test_design_payload.get("next_standard_chain_role") != "tech-lead":
    raise SystemExit(test_design_payload)
if "task_decomposition" not in test_design_payload.get("validated_blocked_actions", []):
    raise SystemExit(test_design_payload)

tech_lead_payload = checks["stage2_tech_lead_package"].get("payload", {})
if tech_lead_payload.get("status") != "pass":
    raise SystemExit(tech_lead_payload)
if tech_lead_payload.get("stage2_readiness") != "tech_lead_ready_for_delivery_owner":
    raise SystemExit(tech_lead_payload)
if tech_lead_payload.get("next_standard_chain_role") != "delivery-owner":
    raise SystemExit(tech_lead_payload)
if "code_changes" not in tech_lead_payload.get("validated_blocked_actions", []):
    raise SystemExit(tech_lead_payload)
if "qa_execution" not in tech_lead_payload.get("validated_blocked_actions", []):
    raise SystemExit(tech_lead_payload)
PY

printf '[PASS] stage 1 eval checks runner passes\n'
