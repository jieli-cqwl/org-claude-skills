#!/usr/bin/env bash
# 文件职责：验证 Skill 优化由行为 eval 覆盖和质量审计证明。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_MANAGER_DIR="$ROOT/shared/skills/product-manager"
DEVELOPER_DIR="$ROOT/shared/skills/developer"
PRODUCT_MANAGER_EVALS="$PRODUCT_MANAGER_DIR/evals/evals.json"
BODY_QUALITY_AUDIT="$ROOT/tools/skill_quality/check_skill_body_quality.py"
ANTI_NOISE_AUDIT="$ROOT/tools/skill_quality/check_skill_anti_noise.py"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  local label="$2"

  [ -f "$path" ] || fail "missing $label: $path"
}

assert_static_pass() {
  local label="$1"
  local report="$2"

  python3 - "$label" "$report" <<'PY'
import json
import sys
from pathlib import Path

label = sys.argv[1]
path = Path(sys.argv[2])
payload = json.loads(path.read_text(encoding="utf-8"))
if payload.get("status") != "static_pass":
    raise SystemExit(f"{label} must be static_pass: {payload}")
PY
}

assert_product_manager_behavior_evals() {
  python3 - "$PRODUCT_MANAGER_EVALS" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))

anchors = {anchor.get("id") for anchor in data.get("preference_anchors", [])}
required_anchors = {"review-fail-warn-closure", "director-lock-no-drift", "delivery-confirmation", "pm-recommendation-first", "high-risk-review"}
missing_anchors = sorted(required_anchors - anchors)
if missing_anchors:
    raise SystemExit(f"{path}: missing behavior anchors {missing_anchors}")

case_by_id = {case.get("id"): case for case in data.get("evals", [])}
required_cases = {
    "director-lock-drift-blocking": {
        "anchors": {"director-lock-no-drift"},
        "signals": ["Director 锁定字段漂移", "停止并报告用户", "用户裁决"],
    },
    "unit-context-and-ac-closure": {
        "anchors": {"pm-recommendation-first"},
        "signals": ["PM 推荐", "未闭合业务假设", "用户只确认会改变结论的业务事实"],
    },
    "review-delivery-guided-confirmation": {
        "anchors": {"review-fail-warn-closure", "delivery-confirmation", "pm-recommendation-first"},
        "signals": ["收口建议", "issue_ledger", "delivery_confirmation", "验证一个会改变交付确认结论的具体业务假设"],
    },
    "high-risk-review-on-demand": {
        "anchors": {"high-risk-review"},
        "signals": ["高风险", "High-Risk Signals", "不追加高风险检查"],
    },
}

for case_id, requirement in required_cases.items():
    case = case_by_id.get(case_id)
    if not case:
        raise SystemExit(f"{path}: missing behavior eval {case_id}")
    case_anchors = set(case.get("expected_anchors", []))
    missing = sorted(requirement["anchors"] - case_anchors)
    if missing:
        raise SystemExit(f"{path}: eval {case_id} missing anchors {missing}")
    expectations = case.get("expectations", [])
    if not isinstance(expectations, list) or not expectations:
        raise SystemExit(f"{path}: eval {case_id} must define expectations")
    behavior_text = "\n".join(expectations)
    missing_signals = [signal for signal in requirement["signals"] if signal not in behavior_text]
    if missing_signals:
        raise SystemExit(f"{path}: eval {case_id} missing behavior signals {missing_signals}")
PY
}

run_body_quality_audit() {
  local label="$1"
  local skill_dir="$2"
  local report="$TMP_DIR/$label-body-quality.json"

  python3 "$BODY_QUALITY_AUDIT" "$skill_dir" >"$report"
  assert_static_pass "$label body quality" "$report"
}

run_anti_noise_audit() {
  local label="$1"
  local skill_dir="$2"
  local report="$TMP_DIR/$label-anti-noise.json"

  python3 "$ANTI_NOISE_AUDIT" --path "$skill_dir" >"$report"
  assert_static_pass "$label anti-noise" "$report"
}

assert_file "$PRODUCT_MANAGER_EVALS" "product-manager evals"
assert_file "$BODY_QUALITY_AUDIT" "skill body quality checker"
assert_file "$ANTI_NOISE_AUDIT" "skill anti-noise checker"

assert_product_manager_behavior_evals
run_body_quality_audit "product-manager" "$PRODUCT_MANAGER_DIR"
run_anti_noise_audit "product-manager" "$PRODUCT_MANAGER_DIR"
run_body_quality_audit "developer" "$DEVELOPER_DIR"
run_anti_noise_audit "developer" "$DEVELOPER_DIR"

printf '[PASS] skill optimization behavior and quality gates\n'
