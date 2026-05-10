#!/usr/bin/env bash
# File responsibility: prove PM → design handoff chain works end to end on a
# shared fixture, and that drift on the PM side is blocked before design
# consumes it. Complements test-product-manager-dogfood-e2e.sh and
# test-design-dogfood-e2e.sh by testing the handoff between them.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PM_PREFLIGHT="$ROOT/shared/skills/product-manager/scripts/preflight_check.py"
DESIGN_PREFLIGHT="$ROOT/shared/skills/design/scripts/preflight_check.sh"
SOURCE_FEATURE="$ROOT/shared/skills/product-manager/examples/feature--user-login-validation"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/pm-design-chain.XXXXXX")"

trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
    printf '[FAIL] %s\n' "$*" >&2
    exit 1
}

ok() {
    printf '[PASS] %s\n' "$*"
}

clone_feature() {
    local dest="$1"
    cp -R "$SOURCE_FEATURE" "$dest/feature"
    printf '%s' "$dest/feature"
}

# --- Case 1: clean PM output must pass design preflight ---
clean_dir="$TMP_ROOT/clean"
mkdir -p "$clean_dir"
feature_dir="$(clone_feature "$clean_dir")"
phase_dir="$feature_dir/phase-1"

python3 "$PM_PREFLIGHT" --phase-dir "$phase_dir" >"$clean_dir/pm-preflight.json" \
    || fail "case1: PM preflight rejected golden PM example on its own side"
jq -e '.status == "PASS"' "$clean_dir/pm-preflight.json" >/dev/null \
    || fail "case1: PM preflight did not return PASS on golden example"

bash "$DESIGN_PREFLIGHT" --phase-dir "$phase_dir" >"$clean_dir/design-preflight.json" \
    || fail "case1: design preflight rejected clean PM output"
jq -e '.status == "PASS" and (.unit_count == 4)' "$clean_dir/design-preflight.json" >/dev/null \
    || fail "case1: design preflight PASS payload shape regressed (expected unit_count=4)"
ok "case1: clean PM output flows into design preflight"

# --- Case 2: PM-side priority drift must be blocked at PM preflight before
# design ever sees it (upstream gate catches drift) ---
drift_priority_dir="$TMP_ROOT/drift-priority"
mkdir -p "$drift_priority_dir"
feature_dir="$(clone_feature "$drift_priority_dir")"
phase_dir="$feature_dir/phase-1"

jq '(.unit_priority_order[] | select(.unit_id=="UNIT-2") | .priority) = "P2"' \
    "$phase_dir/phase-prd.json" >"$phase_dir/phase-prd.tmp.json"
mv "$phase_dir/phase-prd.tmp.json" "$phase_dir/phase-prd.json"

set +e
python3 "$PM_PREFLIGHT" --phase-dir "$phase_dir" >"$drift_priority_dir/pm-preflight.json"
pm_status=$?
set -e
[ "$pm_status" -eq 1 ] || fail "case2: PM preflight should exit 1 on priority drift, got $pm_status"
jq -e '.status == "BLOCKED" and .failure_code == "PRIORITY_INCONSISTENCY_FAILURE" and .owner == "product-manager"' \
    "$drift_priority_dir/pm-preflight.json" >/dev/null \
    || fail "case2: PM preflight did not surface PRIORITY_INCONSISTENCY_FAILURE with owner=product-manager"
ok "case2: priority drift blocked at PM preflight (never reaches design)"

# --- Case 3: PM-side terminology drift must be blocked at PM preflight ---
drift_term_dir="$TMP_ROOT/drift-terminology"
mkdir -p "$drift_term_dir"
feature_dir="$(clone_feature "$drift_term_dir")"
phase_dir="$feature_dir/phase-1"

python3 - "$phase_dir/units/UNIT-1.json" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
d = json.loads(p.read_text(encoding="utf-8"))
ac = json.dumps(d["acceptance_criteria"], ensure_ascii=False).replace("会话标识", "token", 1)
d["acceptance_criteria"] = json.loads(ac)
p.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")
PY

set +e
python3 "$PM_PREFLIGHT" --phase-dir "$phase_dir" >"$drift_term_dir/pm-preflight.json"
pm_status=$?
set -e
[ "$pm_status" -eq 1 ] || fail "case3: PM preflight should exit 1 on terminology drift, got $pm_status"
jq -e '.status == "BLOCKED" and .failure_code == "TERMINOLOGY_DRIFT_FAILURE" and .owner == "product-manager"' \
    "$drift_term_dir/pm-preflight.json" >/dev/null \
    || fail "case3: PM preflight did not surface TERMINOLOGY_DRIFT_FAILURE with owner=product-manager"
ok "case3: terminology drift blocked at PM preflight (never reaches design)"

# --- Case 4: PM output missing delivery_confirmation must be blocked at
# design preflight (downstream gate catches upstream-produced-but-unconfirmed
# product closure) ---
drift_delivery_dir="$TMP_ROOT/drift-delivery"
mkdir -p "$drift_delivery_dir"
feature_dir="$(clone_feature "$drift_delivery_dir")"
phase_dir="$feature_dir/phase-1"

jq 'del(.delivery_confirmation)' "$feature_dir/brief.json" >"$feature_dir/brief.tmp.json"
mv "$feature_dir/brief.tmp.json" "$feature_dir/brief.json"

set +e
bash "$DESIGN_PREFLIGHT" --phase-dir "$phase_dir" >"$drift_delivery_dir/design-preflight.json"
design_status=$?
set -e
[ "$design_status" -eq 1 ] || fail "case4: design preflight should exit 1 on missing delivery_confirmation, got $design_status"
jq -e '.status == "BLOCKED" and .owner == "product-manager"' \
    "$drift_delivery_dir/design-preflight.json" >/dev/null \
    || fail "case4: design preflight did not blame product-manager for missing delivery_confirmation"
ok "case4: missing delivery_confirmation blocked at design preflight"

# --- Case 5: restoring clean input must still PASS (no residual tmp state) ---
restore_dir="$TMP_ROOT/restore"
mkdir -p "$restore_dir"
feature_dir="$(clone_feature "$restore_dir")"
phase_dir="$feature_dir/phase-1"

python3 "$PM_PREFLIGHT" --phase-dir "$phase_dir" >"$restore_dir/pm.json" \
    || fail "case5: clean re-clone failed PM preflight"
bash "$DESIGN_PREFLIGHT" --phase-dir "$phase_dir" >"$restore_dir/design.json" \
    || fail "case5: clean re-clone failed design preflight"
ok "case5: clean re-clone repasses both gates (no cross-test contamination)"

printf '\n[SUMMARY] PM → design chain E2E: 5/5 cases passed\n'
