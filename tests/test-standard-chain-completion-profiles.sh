#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$ROOT/tools/community/validate_failure_routing_contract.py"
FIXTURE="$ROOT/tests/fixtures/standard-chain-pilots/login-homepage-pilot"
PHASE_DIR="$FIXTURE/phase-1"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

roles=(product-director product-manager design test-design tech-lead delivery-owner developer verify review qa)

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

json_field() {
  python3 - "$1" "$2" <<'PY'
import json, sys
print(json.loads(sys.argv[1])[sys.argv[2]])
PY
}

assert_routing() {
  local payload="$1" expected_status="$2" expected_code="$3"
  python3 "$VALIDATOR" --repo-root "$ROOT" --result-json "$payload" >/dev/null
  [[ "$(json_field "$payload" status)" == "$expected_status" ]] || fail "expected status $expected_status, got $payload"
  [[ "$(json_field "$payload" failure_code)" == "$expected_code" ]] || fail "expected failure_code $expected_code, got $payload"
}

assert_decision() {
  local payload="$1" expected="$2"
  [[ "$(json_field "$payload" decision)" == "$expected" ]] || fail "expected decision $expected, got $payload"
}

copy_fixture() {
  mkdir -p "$(dirname "$1")"
  cp -R "$FIXTURE" "$1"
}

run_core() {
  local role="$1"; shift
  local out="$TMP_DIR/core-${role}.json"
  set +e
  "$ROOT/shared/skills/$role/scripts/check_completion.sh" "$@" >"$out"
  set -e
  cat "$out"
}

run_adapter() {
  local role="$1" payload="$2" out="$TMP_DIR/adapter-${role}.json"
  set +e
  "$ROOT/shared/skills/$role/scripts/completion_check.sh" <<<"$payload" >"$out"
  set -e
  cat "$out"
}

core_args_for_role() {
  local role="$1" feature="${2:-$FIXTURE}" phase="${3:-$PHASE_DIR}"
  case "$role" in
    product-director|product-manager|design|tech-lead|delivery-owner|qa)
      printf '%s\n' --feature "$feature" --phase-dir "$phase" ;;
    test-design)
      printf '%s\n' --feature "$feature" --phase-dir "$phase" --unit UNIT-1 ;;
    developer|verify|review)
      printf '%s\n' --feature "$feature" --phase-dir "$phase" --unit UNIT-1 --task-id T1 ;;
    *) fail "unknown role $role" ;;
  esac
}

adapter_payload_for_role() {
  local role="$1" feature="${2:-$FIXTURE}" phase="${3:-$PHASE_DIR}"
  python3 - "$ROOT" "$role" "$feature" "$phase" <<'PY'
import json, sys
root, role, feature, phase = sys.argv[1:]
target = {"feature": feature, "phase_dir": phase}
if role in {"test-design", "developer", "verify", "review"}:
    target["unit"] = "UNIT-1"
if role in {"developer", "verify", "review"}:
    target["task_id"] = "T1"
print(json.dumps({"cwd": root, "standard_chain": target}, sort_keys=True))
PY
}

for role in "${roles[@]}"; do
  [[ -x "$ROOT/shared/skills/$role/scripts/check_completion.sh" ]] || fail "$role missing executable check_completion.sh"
  args=()
  while IFS= read -r arg; do args+=("$arg"); done < <(core_args_for_role "$role")
  assert_routing "$(run_core "$role" "${args[@]}")" PASS NONE
  assert_decision "$(run_adapter "$role" "$(adapter_payload_for_role "$role")")" allow
done

legacy_root="$TMP_DIR/legacy-root"
copy_fixture "$legacy_root/docs/login-homepage-pilot"
legacy_payload="$(python3 - "$legacy_root" <<'PY'
import json, sys
print(json.dumps({"cwd": sys.argv[1], "tool_input": {"file_path": "docs/login-homepage-pilot/phase-1/qa-result.json"}}))
PY
)"
assert_decision "$(run_adapter qa "$legacy_payload")" allow

active_target_payload="$(python3 - "$ROOT" "$FIXTURE" "$PHASE_DIR" <<'PY'
import json, sys
root, feature, phase = sys.argv[1:]
print(json.dumps({"cwd": root, "active_targets": [{"feature": feature, "phase_dir": phase, "unit": "UNIT-1", "task_id": "T1"}]}))
PY
)"
assert_decision "$(run_adapter verify "$active_target_payload")" allow

conflict_target_payload="$(python3 - "$ROOT" "$FIXTURE" "$PHASE_DIR" <<'PY'
import json, sys
root, feature, phase = sys.argv[1:]
print(json.dumps({"cwd": root, "active_targets": [{"feature": feature, "phase_dir": phase, "unit": "UNIT-1", "task_id": "T1"}], "standard_chain": {"phase_dir": "phase-404", "task_id": "T2"}}))
PY
)"
assert_decision "$(run_adapter verify "$conflict_target_payload")" allow

missing_fixture="$TMP_DIR/missing-output"
copy_fixture "$missing_fixture"
rm "$missing_fixture/phase-1/plan.json"
assert_routing "$(run_core tech-lead --feature "$missing_fixture" --phase-dir "$missing_fixture/phase-1")" BLOCKED MISSING_ARTIFACT

malformed_fixture="$TMP_DIR/malformed-output"
copy_fixture "$malformed_fixture"
printf '{bad-json\n' >"$malformed_fixture/phase-1/qa-result.json"
assert_routing "$(run_core qa --feature "$malformed_fixture" --phase-dir "$malformed_fixture/phase-1")" BLOCKED MALFORMED_ARTIFACT

stale_fixture="$TMP_DIR/stale-proof"
copy_fixture "$stale_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text()); d["active_plan_version_ref"]=d["active_plan_version_ref"].replace("@plan-v2","@plan-v1"); p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n")' "$stale_fixture/phase-1/unit-1/tasks/T1/developer-report.json"
assert_routing "$(run_core developer --feature "$stale_fixture" --phase-dir "$stale_fixture/phase-1" --unit UNIT-1 --task-id T1)" BLOCKED STALE_EVIDENCE

missing_ref_fixture="$TMP_DIR/missing-proof-ref"
copy_fixture "$missing_ref_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text()); d.pop("active_plan_version_ref",None); d.pop("active_tasks_version_ref",None); p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n")' "$missing_ref_fixture/phase-1/unit-1/tasks/T1/developer-report.json"
assert_routing "$(run_core developer --feature "$missing_ref_fixture" --phase-dir "$missing_ref_fixture/phase-1" --unit UNIT-1 --task-id T1)" BLOCKED STALE_EVIDENCE

missing_verify_fixture="$TMP_DIR/missing-review-verify"
copy_fixture "$missing_verify_fixture"
rm "$missing_verify_fixture/phase-1/unit-1/tasks/T1/verify-result.json"
assert_routing "$(run_core review --feature "$missing_verify_fixture" --phase-dir "$missing_verify_fixture/phase-1" --unit UNIT-1 --task-id T1)" BLOCKED MISSING_ARTIFACT

wrong_task_fixture="$TMP_DIR/wrong-review-task"
copy_fixture "$wrong_task_fixture"
rm "$wrong_task_fixture/phase-1/unit-1/tasks/T2/verify-result.json"
assert_routing "$(run_core review --feature "$wrong_task_fixture" --phase-dir "$wrong_task_fixture/phase-1" --unit UNIT-1 --task-id T2)" BLOCKED MISSING_ARTIFACT

missing_dev_fixture="$TMP_DIR/missing-review-dev"
copy_fixture "$missing_dev_fixture"
rm "$missing_dev_fixture/phase-1/unit-1/tasks/T1/developer-report.json"
assert_routing "$(run_core review --feature "$missing_dev_fixture" --phase-dir "$missing_dev_fixture/phase-1" --unit UNIT-1 --task-id T1)" BLOCKED MISSING_ARTIFACT

handoff_fixture="$TMP_DIR/handoff-not-ready"
copy_fixture "$handoff_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text()); d["gate_result"]="FAIL"; d["review_conclusion"]="REQUEST_CHANGES"; p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n")' "$handoff_fixture/phase-1/code-review-result.json"
assert_routing "$(run_core review --feature "$handoff_fixture" --phase-dir "$handoff_fixture/phase-1" --unit UNIT-1 --task-id T1)" BLOCKED HANDOFF_NOT_READY

verify_fail_fixture="$TMP_DIR/review-verify-fail"
copy_fixture "$verify_fail_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text()); d["gate_result"]="FAIL"; p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n")' "$verify_fail_fixture/phase-1/unit-1/tasks/T1/verify-result.json"
assert_routing "$(run_core review --feature "$verify_fail_fixture" --phase-dir "$verify_fail_fixture/phase-1" --unit UNIT-1 --task-id T1)" BLOCKED HANDOFF_NOT_READY

pm_reject_fixture="$TMP_DIR/pm-reject"
copy_fixture "$pm_reject_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text()); d["delivery_confirmation"]["status"]="REJECTED"; d["review_conclusion"]="CHANGES_REQUESTED"; p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n")' "$pm_reject_fixture/brief.json"
assert_routing "$(run_core product-manager --feature "$pm_reject_fixture" --phase-dir "$pm_reject_fixture/phase-1")" BLOCKED MISSING_HUMAN_CONFIRMATION

design_reject_fixture="$TMP_DIR/design-reject"
copy_fixture "$design_reject_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text()); d["final_confirmation"]["status"]="REJECTED"; d["product_handoff"]["status"]="REJECTED"; p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n")' "$design_reject_fixture/phase-1/design.json"
assert_routing "$(run_core design --feature "$design_reject_fixture" --phase-dir "$design_reject_fixture/phase-1")" BLOCKED HANDOFF_NOT_READY

test_design_reject_fixture="$TMP_DIR/test-design-reject"
copy_fixture "$test_design_reject_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text()); d["review_conclusion"]="CHANGES_REQUESTED"; d["qa_handoff_contract"]={"status":"REJECTED"}; p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n")' "$test_design_reject_fixture/phase-1/unit-1/test-cases.json"
assert_routing "$(run_core test-design --feature "$test_design_reject_fixture" --phase-dir "$test_design_reject_fixture/phase-1" --unit UNIT-1)" BLOCKED HANDOFF_NOT_READY

basis_fixture="$TMP_DIR/missing-delegated-basis"
copy_fixture "$basis_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text()); d["user_confirmation"].pop("confirmation_basis",None); p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n")' "$basis_fixture/phase-1/plan.json"
assert_routing "$(run_core tech-lead --feature "$basis_fixture" --phase-dir "$basis_fixture/phase-1")" BLOCKED MISSING_HUMAN_CONFIRMATION

timeout_result="$(SC_COMPLETION_DELAY_SECONDS=2 SC_COMPLETION_ADAPTER_TIMEOUT_SECONDS=1 run_adapter qa "$(adapter_payload_for_role qa)")"
assert_decision "$timeout_result" block

overflow_result="$(SC_COMPLETION_ADAPTER_OUTPUT_LIMIT_BYTES=16 run_adapter qa "$(adapter_payload_for_role qa)")"
assert_decision "$overflow_result" block

python3 - "$ROOT" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
profiles = json.loads((root / "shared/runtime/standard-chain-completion-profiles.json").read_text())
roles = profiles["roles"]
expected = {"tech-lead": "developer", "developer": "verify", "verify": "review", "review": "qa", "qa": "delivery-owner"}
for role, handoff in expected.items():
    if roles[role]["handoff_to"] != handoff:
        raise SystemExit(f"{role}.handoff_to expected {handoff}, got {roles[role]['handoff_to']}")
text = (root / "contracts/standard-chain.yaml").read_text()
positions = {name: text.index(f"  - name: {name}\n") for name in ["developer", "verify", "review", "qa"]}
if not (positions["developer"] < positions["verify"] < positions["review"] < positions["qa"]):
    raise SystemExit("contract sequence must be developer -> verify -> review -> qa")
registry = json.loads((root / "shared/hooks/registry.json").read_text())
entries = {entry["skill"]: entry for entry in registry["skill_completion_gates"]}
for role in ["product-director", "product-manager", "design", "test-design", "tech-lead", "delivery-owner", "developer", "verify", "review", "qa"]:
    entry = entries.get(role)
    if not entry:
        raise SystemExit(f"missing registry completion gate for {role}")
    if entry.get("handler_rel") != f"skills/{role}/scripts/completion_check.sh":
        raise SystemExit(f"registry handler drift for {role}")
    if not isinstance(entry.get("timeout_sec"), int) or entry["timeout_sec"] <= 0:
        raise SystemExit(f"registry timeout missing for {role}")
PY

echo "[PASS] standard-chain completion profiles"
