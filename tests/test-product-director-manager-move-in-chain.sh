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

SCRIPT="$ROOT/tools/eval/scripts/validate_product_director_manager_move_in_chain.py"
[ -f "$SCRIPT" ] || fail "missing product director-manager move-in chain validator"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PACKAGE="$TMP_ROOT/move-in-chain-package.json"
python3 "$SCRIPT" --emit-package >"$PACKAGE"

python3 "$SCRIPT" --package "$PACKAGE" >"$TMP_ROOT/package-pass.json" \
  || fail "valid Director->PM move-in chain package should pass"
python3 - "$TMP_ROOT/package-pass.json" <<'PY' || fail "move-in chain pass output mismatch"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit(payload)
if payload.get("stage2_readiness") != "director_manager_chain_meets_move_in_prd_rubric":
    raise SystemExit(payload)
expected = {
    "package_envelope",
    "director_boundary",
    "product_manager_package",
    "golden_prd_rubric",
    "downstream_consumability",
}
checks = {item.get("check") for item in payload.get("checks", [])}
missing = sorted(expected - checks)
if missing:
    raise SystemExit(f"missing checks: {missing}")
coverage = payload.get("rubric_summary", {}).get("coverage")
if coverage != "complete":
    raise SystemExit(payload)
PY

BROKEN_BUSINESS_TYPE="$TMP_ROOT/broken-business-type.json"
python3 - "$PACKAGE" "$BROKEN_BUSINESS_TYPE" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
phase = payload["product_manager_package"]["phase_prd"]
phase["coverage_matrix"] = [
    item for item in phase["coverage_matrix"] if item.get("business_type") != "集中"
]
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BROKEN_BUSINESS_TYPE" >"$TMP_ROOT/broken-business-type-output.json"; then
  fail "move-in chain must reject missing 集中 business-type coverage"
fi
rg -q "business_type.*集中|coverage_matrix" "$TMP_ROOT/broken-business-type-output.json" \
  || fail "missing business-type coverage failure should be explicit"

BROKEN_TECH_EVIDENCE="$TMP_ROOT/broken-tech-evidence.json"
python3 - "$PACKAGE" "$BROKEN_TECH_EVIDENCE" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
phase = payload["product_manager_package"]["phase_prd"]
phase["technical_evidence_requirements"] = [
    item for item in phase["technical_evidence_requirements"] if item.get("domain") != "idempotency_concurrency"
]
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BROKEN_TECH_EVIDENCE" >"$TMP_ROOT/broken-tech-evidence-output.json"; then
  fail "move-in chain must reject missing idempotency/concurrency technical evidence input"
fi
rg -q "idempotency_concurrency|technical_evidence_requirements" "$TMP_ROOT/broken-tech-evidence-output.json" \
  || fail "technical evidence failure should be explicit"

BROKEN_DIRECTOR="$TMP_ROOT/broken-director.json"
python3 - "$PACKAGE" "$BROKEN_DIRECTOR" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload["confirmed_brief_package"]["phase_prd"]["phase_goal"] = "允许已租房登记下一任租客"
Path(sys.argv[2]).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$SCRIPT" --package "$BROKEN_DIRECTOR" >"$TMP_ROOT/broken-director-output.json"; then
  fail "move-in chain must reject Director phase boundary that drops current-tenant protection"
fi
rg -q "当前在租|director_boundary|phase_goal" "$TMP_ROOT/broken-director-output.json" \
  || fail "Director boundary failure should be explicit"

printf '[PASS] product director-manager move-in chain gate\n'
