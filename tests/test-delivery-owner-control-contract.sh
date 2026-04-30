#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/delivery-owner/SKILL.md"
HISTORICAL_SKILL="$ROOT/shared/skills/delivery-owner-h/SKILL.md"
INTAKE="$ROOT/shared/skills/delivery-owner/scripts/intake_preflight_check.sh"
PACKET="$ROOT/shared/skills/delivery-owner/scripts/task_packet_check.sh"
CONTROL="$ROOT/shared/skills/delivery-owner/scripts/control_decision_check.sh"
COMPLETION="$ROOT/shared/skills/delivery-owner/scripts/completion_check.sh"
MANIFEST="$ROOT/shared/skills/delivery-owner/scripts/manifest.json"
PHASE="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1"
TMP_DIR="$(mktemp -d "$ROOT/tests/.tmp.delivery-owner.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local needle="$1"
  local file="$2"
  grep -Fq -- "$needle" "$file" || fail "$file missing: $needle"
}

assert_not_contains() {
  local needle="$1"
  local file="$2"
  if grep -Fq -- "$needle" "$file"; then
    fail "$file should not contain: $needle"
  fi
}

[ -f "$SKILL" ] || fail "missing active delivery-owner skill"
[ -f "$HISTORICAL_SKILL" ] || fail "missing historical delivery-owner-h skill"
[ -x "$INTAKE" ] || fail "missing intake preflight wrapper"
[ -x "$PACKET" ] || fail "missing task packet wrapper"
[ -x "$CONTROL" ] || fail "missing control decision wrapper"
[ -x "$COMPLETION" ] || fail "missing delivery readiness wrapper"
test -f "$MANIFEST" || fail "missing delivery-owner script manifest"

assert_contains "name: delivery-owner" "$SKILL"
assert_contains "name: delivery-owner-h" "$HISTORICAL_SKILL"
assert_contains "交付负责人" "$SKILL"
assert_contains "tech-lead" "$SKILL"
assert_contains "task packet" "$SKILL"
assert_contains "intake_preflight_check.sh" "$SKILL"
assert_contains "task_packet_check.sh" "$SKILL"
assert_contains "control_decision_check.sh" "$SKILL"
assert_contains "loop_state" "$SKILL"
assert_contains "completion_check.sh" "$SKILL"
assert_contains "QA handoff" "$SKILL"
assert_contains "readiness bundle 已闭合" "$SKILL"
assert_contains "templates/signoff-package.template.json" "$SKILL"
assert_contains "没有可用 executor 时输出" "$SKILL"
assert_contains "不在主上下文切换到执行 Skill 代做" "$SKILL"
assert_contains "authority 只接收升级包" "$SKILL"
assert_contains "tech-lead" "$SKILL"
assert_contains "不写执行 packet" "$SKILL"
assert_contains "materialize-canonical-html" "$SKILL"
assert_contains "developer preflight" "$ROOT/shared/skills/delivery-owner/references/routing-and-packet.md"
assert_contains "RED/GREEN/REFACTOR" "$ROOT/shared/skills/delivery-owner/references/routing-and-packet.md"
assert_contains "developer-report.json" "$ROOT/shared/skills/delivery-owner/references/routing-and-packet.md"
assert_contains "verify-result.json" "$ROOT/shared/skills/delivery-owner/references/routing-and-packet.md"
assert_contains "code-review-result.json" "$ROOT/shared/skills/delivery-owner/references/routing-and-packet.md"
assert_contains "QA_A / QA_B / QA_C / QA_D" "$ROOT/shared/skills/delivery-owner/references/routing-and-packet.md"
assert_contains "qa-result.json" "$ROOT/shared/skills/delivery-owner/references/routing-and-packet.md"
assert_contains "task_packet_check.sh" "$ROOT/shared/skills/delivery-owner/references/routing-and-packet.md"
assert_contains "control_decision_check.sh" "$ROOT/shared/skills/delivery-owner/references/evidence-and-followup.md"
assert_contains "no_increment" "$ROOT/shared/skills/delivery-owner/references/evidence-and-followup.md"
assert_contains "escalation_packet" "$ROOT/shared/skills/delivery-owner/references/evidence-and-followup.md"
assert_contains "rebaseline_request" "$ROOT/shared/skills/delivery-owner/references/evidence-and-followup.md"
assert_contains "blocker_packet" "$ROOT/shared/skills/delivery-owner/references/evidence-and-followup.md"
assert_contains "gap_delta" "$ROOT/shared/skills/delivery-owner/references/intake-and-state.md"
assert_contains "packet_delta" "$ROOT/shared/skills/delivery-owner/references/intake-and-state.md"
assert_contains "loop_state" "$ROOT/shared/skills/delivery-owner/references/intake-and-state.md"
assert_contains "next_no_progress_action" "$ROOT/shared/skills/delivery-owner/references/evidence-and-followup.md"
assert_contains "last_control_decision" "$ROOT/shared/skills/delivery-owner/contracts/delivery-state.schema.json"
assert_contains "last_control_decision" "$ROOT/shared/skills/delivery-owner/templates/delivery-state.template.json"
assert_contains "Decision | Apply | Next" "$SKILL"
assert_contains "脚本 FAIL 时不更新状态" "$SKILL"
assert_contains "readiness bundle" "$SKILL"
assert_contains "不能因单个 role PASS" "$SKILL"
assert_contains "sign_off_status" "$SKILL"
assert_contains "PENDING" "$SKILL"
assert_contains "developer-report.json" "$ROOT/shared/skills/delivery-owner/references/escalation-and-signoff.md"
assert_contains "code-review-result.json" "$ROOT/shared/skills/delivery-owner/references/escalation-and-signoff.md"
assert_contains "QA_A / QA_B / QA_C / QA_D" "$ROOT/shared/skills/delivery-owner/references/escalation-and-signoff.md"
assert_contains "consistency-audit-result.json" "$ROOT/shared/skills/delivery-owner/references/escalation-and-signoff.md"
assert_contains "projection / replay readiness" "$ROOT/shared/skills/delivery-owner/references/escalation-and-signoff.md"
assert_contains "Closeout 合格线" "$ROOT/shared/skills/delivery-owner/references/escalation-and-signoff.md"
assert_contains "不能反向作为" "$ROOT/shared/skills/delivery-owner/references/escalation-and-signoff.md"
assert_contains "authority_proof_refs" "$ROOT/shared/skills/delivery-owner/references/escalation-and-signoff.md"
assert_not_contains "delivery-gate-dispatch.md" "$SKILL"
assert_not_contains "commit_preflight_check.sh" "$SKILL"
assert_not_contains "必要时才由当前模型切换" "$SKILL"
assert_not_contains "当前模型切换到该 skill" "$ROOT/shared/skills/delivery-owner/references/routing-and-packet.md"

python3 "$ROOT/tools/skill_quality/check_skill_body_quality.py" "$SKILL" >/tmp/delivery-owner-body-quality.json
python3 "$ROOT/tools/skill_quality/check_skill_package_quality.py" "$ROOT/shared/skills/delivery-owner" >/tmp/delivery-owner-package-quality.json
python3 -m py_compile \
  "$ROOT/shared/skills/delivery-owner/scripts/intake_preflight_check.py" \
  "$ROOT/shared/skills/delivery-owner/scripts/task_packet_check.py" \
  "$ROOT/shared/skills/delivery-owner/scripts/control_decision_support.py" \
  "$ROOT/shared/skills/delivery-owner/scripts/control_decision_check.py"
jq empty "$MANIFEST" >/dev/null || fail "delivery-owner manifest must be valid JSON"
bash -n "$COMPLETION" || fail "completion wrapper must pass shell syntax"

bash "$INTAKE" --phase-dir "$PHASE" >"$TMP_DIR/intake-pass.json"
python3 - "$TMP_DIR/intake-pass.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "PASS"
assert payload["decision"] == "ACCEPTED"
assert payload["safe_to_dispatch"] is True
assert payload["task_count"] >= 1
assert payload["qa_handoff_count"] >= 1
PY

mkdir -p "$TMP_DIR/missing-tasks"
cp "$PHASE/plan.json" "$TMP_DIR/missing-tasks/plan.json"
set +e
bash "$INTAKE" --phase-dir "$TMP_DIR/missing-tasks" >"$TMP_DIR/intake-fail.json"
intake_rc=$?
set -e
[ "$intake_rc" -ne 0 ] || fail "intake preflight should fail when tasks.json is missing"
python3 - "$TMP_DIR/intake-fail.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["decision"] == "NEEDS_INPUT"
assert payload["safe_to_dispatch"] is False
PY

cp -R "$PHASE" "$TMP_DIR/missing-qa-handoff"
jq 'del(.qa_handoff_contract)' \
  "$TMP_DIR/missing-qa-handoff/unit-1/test-cases.json" \
  >"$TMP_DIR/missing-qa-handoff/unit-1/test-cases.tmp"
mv "$TMP_DIR/missing-qa-handoff/unit-1/test-cases.tmp" \
  "$TMP_DIR/missing-qa-handoff/unit-1/test-cases.json"
set +e
bash "$INTAKE" --phase-dir "$TMP_DIR/missing-qa-handoff" >"$TMP_DIR/intake-missing-qa.json"
missing_qa_rc=$?
set -e
[ "$missing_qa_rc" -ne 0 ] || fail "intake preflight should fail when qa_handoff_contract is missing"
python3 - "$TMP_DIR/intake-missing-qa.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["decision"] == "NEEDS_BASELINE"
assert payload["failure_code"] == "MISSING_QA_HANDOFF"
assert payload["owner"] == "test-design"
assert payload["safe_to_dispatch"] is False
PY

cat >"$TMP_DIR/packet-pass.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "role": "developer",
  "goal": "Implement AC-T1-1 only",
  "scope": ["src/feature.ts", "tests/feature.test.ts"],
  "input_refs": ["artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version"],
  "expected_evidence": ["developer preflight PASS", "RED output", "GREEN output", "REFACTOR or no-op note", "developer-report.json"],
  "stop_condition": "AC-T1-1 green or scope/AC blocked",
  "forbidden_actions": [
    "do not modify scope outside packet",
    "do not modify baseline or AC",
    "do not commit or release",
    "do not conclude for other roles"
  ]
}
JSON
bash "$PACKET" --packet "$TMP_DIR/packet-pass.json" >"$TMP_DIR/packet-pass.out"
python3 - "$TMP_DIR/packet-pass.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "PASS"
assert payload["decision"] == "DISPATCH_READY"
assert payload["role"] == "developer"
PY

cat >"$TMP_DIR/packet-fail.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "role": "developer",
  "goal": "Fix it",
  "scope": "按需处理",
  "input_refs": ["artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version"],
  "expected_evidence": "完成即可",
  "stop_condition": "done",
  "forbidden_actions": ["do not commit"]
}
JSON
set +e
bash "$PACKET" --packet "$TMP_DIR/packet-fail.json" >"$TMP_DIR/packet-fail.out"
packet_rc=$?
set -e
[ "$packet_rc" -ne 0 ] || fail "task packet check should fail on ambiguous packet"
python3 - "$TMP_DIR/packet-fail.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["decision"] == "PACKET_BLOCKED"
assert payload["safe_to_dispatch"] is False
PY

cat >"$TMP_DIR/packet-unsafe.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "role": "developer",
  "goal": "Implement AC-T1-1 only",
  "scope": ["src/feature.ts", "tests/feature.test.ts"],
  "input_refs": ["artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version"],
  "expected_evidence": ["RED output", "GREEN output", "changed files"],
  "stop_condition": "AC-T1-1 green or scope/AC blocked",
  "forbidden_actions": ["do not commit"]
}
JSON
set +e
bash "$PACKET" --packet "$TMP_DIR/packet-unsafe.json" >"$TMP_DIR/packet-unsafe.out"
unsafe_packet_rc=$?
set -e
[ "$unsafe_packet_rc" -ne 0 ] || fail "task packet check should fail when forbidden_actions miss safety boundaries"
python3 - "$TMP_DIR/packet-unsafe.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "PACKET_UNSAFE"
assert payload["safe_to_dispatch"] is False
PY

cat >"$TMP_DIR/packet-evidence-incomplete.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "role": "developer",
  "goal": "Implement AC-T1-1 only",
  "scope": ["src/feature.ts", "tests/feature.test.ts"],
  "input_refs": ["artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version"],
  "expected_evidence": ["RED output", "GREEN output", "changed files"],
  "stop_condition": "AC-T1-1 green or scope/AC blocked",
  "forbidden_actions": [
    "do not modify scope outside packet",
    "do not modify baseline or AC",
    "do not commit or release",
    "do not conclude for other roles"
  ]
}
JSON
set +e
bash "$PACKET" --packet "$TMP_DIR/packet-evidence-incomplete.json" >"$TMP_DIR/packet-evidence-incomplete.out"
evidence_packet_rc=$?
set -e
[ "$evidence_packet_rc" -ne 0 ] || fail "task packet check should fail when expected_evidence misses role-specific evidence"
python3 - "$TMP_DIR/packet-evidence-incomplete.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "PACKET_EVIDENCE_INCOMPLETE"
assert payload["safe_to_dispatch"] is False
PY

cat >"$TMP_DIR/packet-qa-pass.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "role": "qa",
  "goal": "Validate required user and release paths",
  "scope": ["QA_A", "QA_B", "QA_C", "QA_D"],
  "input_refs": ["artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#qa-handoff"],
  "expected_evidence": ["QA_A PASS", "QA_B PASS", "QA_C PASS", "QA_D PASS", "qa-result.json"],
  "stop_condition": "QA stages pass or AC/scope blocked",
  "forbidden_actions": [
    "do not modify scope outside packet",
    "do not modify baseline or AC",
    "do not commit or release",
    "do not conclude for other roles"
  ]
}
JSON
bash "$PACKET" --packet "$TMP_DIR/packet-qa-pass.json" >"$TMP_DIR/packet-qa-pass.out"
python3 - "$TMP_DIR/packet-qa-pass.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "PASS"
assert payload["decision"] == "DISPATCH_READY"
assert payload["role"] == "qa"
PY

cat >"$TMP_DIR/packet-qa-incomplete.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "role": "qa",
  "goal": "Validate required user and release paths",
  "scope": ["QA_A", "QA_B", "QA_C", "QA_D"],
  "input_refs": ["artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#qa-handoff"],
  "expected_evidence": ["QA_A PASS", "qa-result.json"],
  "stop_condition": "QA stages pass or AC/scope blocked",
  "forbidden_actions": [
    "do not modify scope outside packet",
    "do not modify baseline or AC",
    "do not commit or release",
    "do not conclude for other roles"
  ]
}
JSON
set +e
bash "$PACKET" --packet "$TMP_DIR/packet-qa-incomplete.json" >"$TMP_DIR/packet-qa-incomplete.out"
qa_evidence_rc=$?
set -e
[ "$qa_evidence_rc" -ne 0 ] || fail "task packet check should fail when QA evidence misses required stages"
python3 - "$TMP_DIR/packet-qa-incomplete.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "PACKET_EVIDENCE_INCOMPLETE"
assert {"qa_b", "qa_c", "qa_d"}.issubset(set(payload["fields"]))
assert payload["safe_to_dispatch"] is False
PY

cat >"$TMP_DIR/packet-commit.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "role": "commit",
  "goal": "Commit the delivery result",
  "scope": ["."],
  "input_refs": ["artifact://signoff-package/sample-feature.phase-1.signoff@v1#goal-closure"],
  "expected_evidence": ["commit sha"],
  "stop_condition": "commit created or authority blocked",
  "forbidden_actions": ["do not release"]
}
JSON
set +e
bash "$PACKET" --packet "$TMP_DIR/packet-commit.json" >"$TMP_DIR/packet-commit.out"
commit_packet_rc=$?
set -e
[ "$commit_packet_rc" -ne 0 ] || fail "task packet check should not dispatch commit/release roles"
python3 - "$TMP_DIR/packet-commit.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "ROLE_UNSUPPORTED"
assert payload["safe_to_dispatch"] is False
PY

cat >"$TMP_DIR/packet-tech-lead.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "role": "tech-lead",
  "goal": "Refresh the task baseline",
  "scope": ["docs/sample-feature/phase-1/plan.json", "docs/sample-feature/phase-1/tasks.json"],
  "input_refs": ["artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1"],
  "expected_evidence": ["updated plan/tasks"],
  "stop_condition": "baseline refreshed or blocked",
  "forbidden_actions": [
    "do not modify scope outside packet",
    "do not modify baseline or AC without authority",
    "do not commit or release",
    "do not conclude for other roles"
  ]
}
JSON
set +e
bash "$PACKET" --packet "$TMP_DIR/packet-tech-lead.json" >"$TMP_DIR/packet-tech-lead.out"
tech_lead_packet_rc=$?
set -e
[ "$tech_lead_packet_rc" -ne 0 ] || fail "task packet check should not dispatch tech-lead rebaseline roles"
python3 - "$TMP_DIR/packet-tech-lead.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "ROLE_UNSUPPORTED"
assert payload["safe_to_dispatch"] is False
PY

cat >"$TMP_DIR/packet-authority.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "role": "authority",
  "goal": "Approve risk acceptance",
  "scope": ["phase-1/signoff"],
  "input_refs": ["artifact://signoff-package/sample-feature.phase-1.signoff@v1#risk"],
  "expected_evidence": ["authority decision"],
  "stop_condition": "decision recorded or authority unavailable",
  "forbidden_actions": ["do not implement", "do not commit", "do not release"]
}
JSON
set +e
bash "$PACKET" --packet "$TMP_DIR/packet-authority.json" >"$TMP_DIR/packet-authority.out"
authority_packet_rc=$?
set -e
[ "$authority_packet_rc" -ne 0 ] || fail "task packet check should not dispatch authority roles"
python3 - "$TMP_DIR/packet-authority.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "ROLE_UNSUPPORTED"
assert payload["safe_to_dispatch"] is False
PY

cat >"$TMP_DIR/control-return-pass.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "developer",
  "owner": "developer",
  "gap": "developer evidence does not include RED output",
  "decision": "RETURN",
  "increment": {
    "kind": "judgment",
    "effect": "gap_narrowed",
    "summary": "evidence gap identified after observing developer report"
  },
  "gap_delta": {
    "before_open_items": ["impl-status-unknown", "red-evidence-missing"],
    "after_open_items": ["red-evidence-missing"],
    "closed_items": ["impl-status-unknown"],
    "narrowing_basis_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index"]
  },
  "evidence_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index"],
  "next_action": "return bounded evidence gap to developer",
  "blocked_by": "无",
  "follow_up": {
    "missing_gap": "RED output for AC-T1-1",
    "expected_new_evidence": "developer-report.json with RED FAIL_EXPECTED and GREEN PASS",
    "stop_condition": "RED/GREEN evidence recorded or scope/AC blocked"
  },
  "loop_state": {
    "gap_id": "red-evidence-missing",
    "previous_control_decision_ref": "artifact://control-decision/sample-feature.phase-1.task-T1.control@v1#attempt-1",
    "remaining_gap_ids": ["red-evidence-missing"],
    "return_count": 2,
    "stop_condition": "RED/GREEN evidence recorded or scope/AC blocked",
    "next_no_progress_action": "REROUTE"
  }
}
JSON
bash "$CONTROL" --decision "$TMP_DIR/control-return-pass.json" >"$TMP_DIR/control-return-pass.out"
python3 - "$TMP_DIR/control-return-pass.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "PASS"
assert payload["decision"] == "CONTROL_READY"
assert payload["control_decision"] == "RETURN"
assert payload["increment_kind"] == "judgment"
PY

cat >"$TMP_DIR/control-return-missing-loop-state.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "developer",
  "owner": "developer",
  "gap": "developer evidence does not include RED output",
  "decision": "RETURN",
  "increment": {
    "kind": "judgment",
    "effect": "gap_narrowed",
    "summary": "evidence gap identified after observing developer report"
  },
  "gap_delta": {
    "before_open_items": ["impl-status-unknown", "red-evidence-missing"],
    "after_open_items": ["red-evidence-missing"],
    "closed_items": ["impl-status-unknown"],
    "narrowing_basis_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index"]
  },
  "evidence_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index"],
  "next_action": "return bounded evidence gap to developer",
  "blocked_by": "无",
  "follow_up": {
    "missing_gap": "RED output for AC-T1-1",
    "expected_new_evidence": "developer-report.json with RED FAIL_EXPECTED and GREEN PASS",
    "stop_condition": "RED/GREEN evidence recorded or scope/AC blocked"
  }
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-return-missing-loop-state.json" >"$TMP_DIR/control-return-missing-loop-state.out"
missing_loop_state_rc=$?
set -e
[ "$missing_loop_state_rc" -ne 0 ] || fail "control decision check should block RETURN without loop_state"
python3 - "$TMP_DIR/control-return-missing-loop-state.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "CONTROL_INCOMPLETE"
assert "loop_state" in payload["fields"]
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-return-next-action-return.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "developer",
  "owner": "developer",
  "gap": "developer evidence does not include RED output",
  "decision": "RETURN",
  "increment": {
    "kind": "judgment",
    "effect": "gap_narrowed",
    "summary": "evidence gap identified after observing developer report"
  },
  "gap_delta": {
    "before_open_items": ["impl-status-unknown", "red-evidence-missing"],
    "after_open_items": ["red-evidence-missing"],
    "closed_items": ["impl-status-unknown"],
    "narrowing_basis_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index"]
  },
  "evidence_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index"],
  "next_action": "return bounded evidence gap to developer",
  "blocked_by": "无",
  "follow_up": {
    "missing_gap": "RED output for AC-T1-1",
    "expected_new_evidence": "developer-report.json with RED FAIL_EXPECTED and GREEN PASS",
    "stop_condition": "RED/GREEN evidence recorded or scope/AC blocked"
  },
  "loop_state": {
    "gap_id": "red-evidence-missing",
    "previous_control_decision_ref": "artifact://control-decision/sample-feature.phase-1.task-T1.control@v1#attempt-1",
    "remaining_gap_ids": ["red-evidence-missing"],
    "return_count": 1,
    "stop_condition": "RED/GREEN evidence recorded or scope/AC blocked",
    "next_no_progress_action": "RETURN"
  }
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-return-next-action-return.json" >"$TMP_DIR/control-return-next-action-return.out"
next_action_return_rc=$?
set -e
[ "$next_action_return_rc" -ne 0 ] || fail "control decision check should block RETURN as next no-progress action"
python3 - "$TMP_DIR/control-return-next-action-return.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "LOOP_NEXT_ACTION_INVALID"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-return-unchanged-gap.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "developer",
  "owner": "developer",
  "gap": "developer evidence does not include RED output",
  "decision": "RETURN",
  "increment": {
    "kind": "judgment",
    "effect": "gap_narrowed",
    "summary": "claimed the gap narrowed after observing developer report"
  },
  "gap_delta": {
    "before_open_items": ["red-evidence-missing"],
    "after_open_items": ["red-evidence-missing"],
    "closed_items": ["impl-status-unknown"],
    "narrowing_basis_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index"]
  },
  "evidence_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index"],
  "next_action": "return bounded evidence gap to developer",
  "blocked_by": "无",
  "follow_up": {
    "missing_gap": "RED output for AC-T1-1",
    "expected_new_evidence": "developer-report.json with RED FAIL_EXPECTED and GREEN PASS",
    "stop_condition": "RED/GREEN evidence recorded or scope/AC blocked"
  }
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-return-unchanged-gap.json" >"$TMP_DIR/control-return-unchanged-gap.out"
unchanged_gap_rc=$?
set -e
[ "$unchanged_gap_rc" -ne 0 ] || fail "control decision check should block unchanged gap_delta"
python3 - "$TMP_DIR/control-return-unchanged-gap.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "GAP_NOT_NARROWED"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-return-owner-changed.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "developer",
  "owner": "fix",
  "gap": "developer evidence does not include RED output",
  "decision": "RETURN",
  "increment": {
    "kind": "judgment",
    "effect": "gap_narrowed",
    "summary": "evidence gap was narrowed but owner was changed without reroute"
  },
  "gap_delta": {
    "before_open_items": ["impl-status-unknown", "red-evidence-missing"],
    "after_open_items": ["red-evidence-missing"],
    "closed_items": ["impl-status-unknown"],
    "narrowing_basis_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index"]
  },
  "evidence_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index"],
  "next_action": "send the narrowed gap to fix",
  "blocked_by": "无",
  "follow_up": {
    "missing_gap": "RED output for AC-T1-1",
    "expected_new_evidence": "developer-report.json with RED FAIL_EXPECTED and GREEN PASS",
    "stop_condition": "RED/GREEN evidence recorded or scope/AC blocked"
  }
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-return-owner-changed.json" >"$TMP_DIR/control-return-owner-changed.out"
return_owner_changed_rc=$?
set -e
[ "$return_owner_changed_rc" -ne 0 ] || fail "control decision check should block RETURN when owner changes"
python3 - "$TMP_DIR/control-return-owner-changed.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "RETURN_OWNER_CHANGED"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-return-packet-changed.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "developer",
  "owner": "developer",
  "gap": "developer cannot produce RED evidence because packet goal is ambiguous",
  "decision": "RETURN",
  "increment": {
    "kind": "packet_changed",
    "effect": "packet_changed",
    "summary": "task packet was narrowed to the missing RED evidence only"
  },
  "packet_delta": {
    "before": "produce missing implementation evidence",
    "after": "produce RED FAIL_EXPECTED output for AC-T1-1 and update developer-report.json",
    "changed_fields": ["goal", "expected_evidence"],
    "change_basis_refs": ["artifact://executor-reply/sample-feature.phase-1.task-T1@attempt-2#ambiguous-packet"],
    "reason": "previous packet did not name the exact missing evidence"
  },
  "evidence_refs": ["artifact://executor-reply/sample-feature.phase-1.task-T1@attempt-2#ambiguous-packet"],
  "next_action": "return narrowed packet to developer",
  "blocked_by": "无",
  "follow_up": {
    "missing_gap": "RED output for AC-T1-1",
    "expected_new_evidence": "developer-report.json with RED FAIL_EXPECTED",
    "stop_condition": "RED evidence returned or scope/AC blocked"
  },
  "loop_state": {
    "gap_id": "red-evidence-missing",
    "previous_control_decision_ref": "artifact://control-decision/sample-feature.phase-1.task-T1.control@v1#attempt-1",
    "remaining_gap_ids": ["red-evidence-missing"],
    "return_count": 1,
    "stop_condition": "RED evidence returned or scope/AC blocked",
    "next_no_progress_action": "REROUTE"
  }
}
JSON
bash "$CONTROL" --decision "$TMP_DIR/control-return-packet-changed.json" >"$TMP_DIR/control-return-packet-changed.out"
python3 - "$TMP_DIR/control-return-packet-changed.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "PASS"
assert payload["control_decision"] == "RETURN"
assert payload["increment_effect"] == "packet_changed"
PY

cat >"$TMP_DIR/control-return-packet-rewrite-loop.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "developer",
  "owner": "developer",
  "gap": "developer cannot produce RED evidence because packet goal is ambiguous",
  "decision": "RETURN",
  "increment": {
    "kind": "packet_changed",
    "effect": "packet_changed",
    "summary": "task packet was narrowed again without gap progress"
  },
  "packet_delta": {
    "before": "produce RED FAIL_EXPECTED output for AC-T1-1",
    "after": "produce RED FAIL_EXPECTED command output and update developer-report.json",
    "changed_fields": ["expected_evidence"],
    "change_basis_refs": ["artifact://executor-reply/sample-feature.phase-1.task-T1@attempt-3#ambiguous-packet"],
    "reason": "previous narrowed packet still did not produce evidence"
  },
  "evidence_refs": ["artifact://executor-reply/sample-feature.phase-1.task-T1@attempt-3#ambiguous-packet"],
  "next_action": "return another narrowed packet to developer",
  "blocked_by": "无",
  "follow_up": {
    "missing_gap": "RED output for AC-T1-1",
    "expected_new_evidence": "developer-report.json with RED FAIL_EXPECTED",
    "stop_condition": "RED evidence returned or scope/AC blocked"
  },
  "loop_state": {
    "gap_id": "red-evidence-missing",
    "previous_control_decision_ref": "artifact://control-decision/sample-feature.phase-1.task-T1.control@v2#attempt-2",
    "remaining_gap_ids": ["red-evidence-missing"],
    "return_count": 2,
    "stop_condition": "RED evidence returned or scope/AC blocked",
    "next_no_progress_action": "REROUTE"
  }
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-return-packet-rewrite-loop.json" >"$TMP_DIR/control-return-packet-rewrite-loop.out"
packet_rewrite_loop_rc=$?
set -e
[ "$packet_rewrite_loop_rc" -ne 0 ] || fail "control decision check should block repeated same-owner packet rewrite"
python3 - "$TMP_DIR/control-return-packet-rewrite-loop.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "PACKET_REWRITE_LOOP"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-return-packet-changed-missing-delta.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "developer",
  "owner": "developer",
  "gap": "developer cannot produce RED evidence because packet goal is ambiguous",
  "decision": "RETURN",
  "increment": {
    "kind": "packet_changed",
    "effect": "packet_changed",
    "summary": "claimed task packet was narrowed"
  },
  "evidence_refs": ["artifact://executor-reply/sample-feature.phase-1.task-T1@attempt-2#ambiguous-packet"],
  "next_action": "return narrowed packet to developer",
  "blocked_by": "无",
  "follow_up": {
    "missing_gap": "RED output for AC-T1-1",
    "expected_new_evidence": "developer-report.json with RED FAIL_EXPECTED",
    "stop_condition": "RED evidence returned or scope/AC blocked"
  }
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-return-packet-changed-missing-delta.json" >"$TMP_DIR/control-return-packet-changed-missing-delta.out"
packet_changed_missing_delta_rc=$?
set -e
[ "$packet_changed_missing_delta_rc" -ne 0 ] || fail "control decision check should block packet_changed without packet_delta"
python3 - "$TMP_DIR/control-return-packet-changed-missing-delta.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "PACKET_DELTA_INCOMPLETE"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-return-packet-kind-mismatch.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "developer",
  "owner": "developer",
  "gap": "developer cannot produce RED evidence because packet goal is ambiguous",
  "decision": "RETURN",
  "increment": {
    "kind": "evidence",
    "effect": "packet_changed",
    "summary": "claimed packet changed but kind is evidence"
  },
  "packet_delta": {
    "before": "produce missing implementation evidence",
    "after": "produce RED FAIL_EXPECTED output for AC-T1-1 and update developer-report.json",
    "changed_fields": ["goal", "expected_evidence"],
    "change_basis_refs": ["artifact://executor-reply/sample-feature.phase-1.task-T1@attempt-2#ambiguous-packet"],
    "reason": "previous packet did not name the exact missing evidence"
  },
  "evidence_refs": ["artifact://executor-reply/sample-feature.phase-1.task-T1@attempt-2#ambiguous-packet"],
  "next_action": "return narrowed packet to developer",
  "blocked_by": "无",
  "follow_up": {
    "missing_gap": "RED output for AC-T1-1",
    "expected_new_evidence": "developer-report.json with RED FAIL_EXPECTED",
    "stop_condition": "RED evidence returned or scope/AC blocked"
  }
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-return-packet-kind-mismatch.json" >"$TMP_DIR/control-return-packet-kind-mismatch.out"
packet_kind_mismatch_rc=$?
set -e
[ "$packet_kind_mismatch_rc" -ne 0 ] || fail "control decision check should block packet_changed kind/effect mismatch"
python3 - "$TMP_DIR/control-return-packet-kind-mismatch.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "KIND_EFFECT_MISMATCH"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-advance-narrowed.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "developer",
  "owner": "developer",
  "gap": "developer evidence does not include RED output",
  "decision": "ADVANCE",
  "increment": {
    "kind": "judgment",
    "effect": "gap_narrowed",
    "summary": "implementation exists but RED evidence is still missing"
  },
  "gap_delta": {
    "before_open_items": ["impl-status-unknown", "red-evidence-missing"],
    "after_open_items": ["red-evidence-missing"],
    "closed_items": ["impl-status-unknown"],
    "narrowing_basis_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#summary"]
  },
  "evidence_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#summary"],
  "next_action": "advance to next gap",
  "blocked_by": "无"
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-advance-narrowed.json" >"$TMP_DIR/control-advance-narrowed.out"
advance_narrowed_rc=$?
set -e
[ "$advance_narrowed_rc" -ne 0 ] || fail "control decision check should block ADVANCE when current gap is only narrowed"
python3 - "$TMP_DIR/control-advance-narrowed.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "EFFECT_DECISION_MISMATCH"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-advance-authority-pass.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "authority",
  "owner": "delivery-owner",
  "gap": "business risk acceptance is unclear",
  "decision": "ADVANCE",
  "increment": {
    "kind": "authority_decision",
    "effect": "gap_closed",
    "summary": "authority accepted the documented business risk"
  },
  "gap_delta": {
    "before_open_items": ["risk-acceptance-unclear"],
    "after_open_items": [],
    "closed_items": ["risk-acceptance-unclear"],
    "narrowing_basis_refs": ["artifact://user-decision/sample-feature.phase-1.user-decision@v1#risk-acceptance"]
  },
  "evidence_refs": ["artifact://user-decision/sample-feature.phase-1.user-decision@v1#risk-acceptance"],
  "next_action": "continue readiness evaluation",
  "blocked_by": "无"
}
JSON
bash "$CONTROL" --decision "$TMP_DIR/control-advance-authority-pass.json" >"$TMP_DIR/control-advance-authority-pass.out"
python3 - "$TMP_DIR/control-advance-authority-pass.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "PASS"
assert payload["control_decision"] == "ADVANCE"
assert payload["increment_kind"] == "authority_decision"
assert payload["increment_effect"] == "gap_closed"
PY

cat >"$TMP_DIR/control-invalid-evidence-ref.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "authority",
  "owner": "delivery-owner",
  "gap": "business risk acceptance is unclear",
  "decision": "ADVANCE",
  "increment": {
    "kind": "authority_decision",
    "effect": "gap_closed",
    "summary": "authority accepted the documented business risk"
  },
  "gap_delta": {
    "before_open_items": ["risk-acceptance-unclear"],
    "after_open_items": [],
    "closed_items": ["risk-acceptance-unclear"],
    "narrowing_basis_refs": ["artifact://user-decision/sample-feature.phase-1.user-decision@v1#risk-acceptance"]
  },
  "evidence_refs": ["not-a-canonical-ref"],
  "next_action": "continue readiness evaluation",
  "blocked_by": "无"
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-invalid-evidence-ref.json" >"$TMP_DIR/control-invalid-evidence-ref.out"
invalid_ref_rc=$?
set -e
[ "$invalid_ref_rc" -ne 0 ] || fail "control decision check should block invalid evidence refs"
python3 - "$TMP_DIR/control-invalid-evidence-ref.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "INVALID_REF"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-advance-missing-gap-delta.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "verify",
  "owner": "delivery-owner",
  "gap": "AC verification is missing",
  "decision": "ADVANCE",
  "increment": {
    "kind": "evidence",
    "effect": "gap_closed",
    "summary": "verify-result.json passed"
  },
  "evidence_refs": ["artifact://verify-result/sample-feature.phase-1.unit-1.task-T1.verify@v1#summary"],
  "next_action": "pick next gap",
  "blocked_by": "无"
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-advance-missing-gap-delta.json" >"$TMP_DIR/control-advance-missing-gap-delta.out"
advance_missing_delta_rc=$?
set -e
[ "$advance_missing_delta_rc" -ne 0 ] || fail "control decision check should block ADVANCE without gap_delta"
python3 - "$TMP_DIR/control-advance-missing-gap-delta.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "GAP_DELTA_INCOMPLETE"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-escalate-after-authority-decision.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "authority",
  "owner": "business owner",
  "gap": "business risk acceptance is unclear",
  "decision": "ESCALATE",
  "increment": {
    "kind": "authority_decision",
    "effect": "authority_decision",
    "summary": "authority already accepted the documented business risk"
  },
  "evidence_refs": ["artifact://user-decision/sample-feature.phase-1.user-decision@v1#risk-acceptance"],
  "next_action": "ask authority again",
  "blocked_by": "无",
  "required_authority": "business owner"
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-escalate-after-authority-decision.json" >"$TMP_DIR/control-escalate-after-authority-decision.out"
escalate_after_authority_rc=$?
set -e
[ "$escalate_after_authority_rc" -ne 0 ] || fail "control decision check should block re-escalating after authority already decided"
python3 - "$TMP_DIR/control-escalate-after-authority-decision.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "INVALID_INCREMENT"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-return-new-blocker.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "developer",
  "owner": "developer",
  "gap": "developer found missing test environment permission",
  "decision": "RETURN",
  "increment": {
    "kind": "blocker",
    "effect": "new_blocker",
    "summary": "developer cannot run target verification without environment access"
  },
  "gap_delta": {
    "before": "developer needs to produce RED/GREEN evidence",
    "after": "developer cannot produce RED/GREEN evidence until environment access is restored"
  },
  "evidence_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v2#blocked"],
  "next_action": "ask developer to continue",
  "blocked_by": "missing environment access",
  "follow_up": {
    "missing_gap": "RED/GREEN evidence",
    "expected_new_evidence": "developer-report.json with RED/GREEN output",
    "stop_condition": "evidence returned"
  }
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-return-new-blocker.json" >"$TMP_DIR/control-return-new-blocker.out"
return_blocker_rc=$?
set -e
[ "$return_blocker_rc" -ne 0 ] || fail "control decision check should block RETURN when a new blocker needs strategy change"
python3 - "$TMP_DIR/control-return-new-blocker.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "EFFECT_DECISION_MISMATCH"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-no-increment-repeat.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "developer",
  "owner": "developer",
  "gap": "developer has not returned new evidence",
  "decision": "RETURN",
  "increment": {
    "kind": "no_increment",
    "effect": "no_progress",
    "reason": "second same-owner check produced no evidence, fix, blocker, or risk"
  },
  "evidence_refs": ["artifact://executor-reply/sample-feature.phase-1.task-T1@attempt-2#no-increment"],
  "next_action": "ask developer to continue",
  "blocked_by": "无",
  "follow_up": {
    "missing_gap": "new evidence",
    "expected_new_evidence": "any current execution evidence",
    "stop_condition": "new evidence returned"
  }
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-no-increment-repeat.json" >"$TMP_DIR/control-no-increment-repeat.out"
no_increment_rc=$?
set -e
[ "$no_increment_rc" -ne 0 ] || fail "control decision check should block no-increment same-owner RETURN"
python3 - "$TMP_DIR/control-no-increment-repeat.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "NO_INCREMENT_REPEATED"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-fake-evidence-no-progress.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "developer",
  "owner": "developer",
  "gap": "developer has not returned RED evidence",
  "decision": "RETURN",
  "increment": {
    "kind": "evidence",
    "effect": "no_progress",
    "summary": "developer replied with a status update but did not narrow the gap"
  },
  "evidence_refs": ["artifact://executor-reply/sample-feature.phase-1.task-T1@attempt-2#status-update"],
  "next_action": "ask developer to continue",
  "blocked_by": "无",
  "follow_up": {
    "missing_gap": "RED output",
    "expected_new_evidence": "developer-report.json with RED FAIL_EXPECTED",
    "stop_condition": "RED evidence returned"
  }
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-fake-evidence-no-progress.json" >"$TMP_DIR/control-fake-evidence-no-progress.out"
fake_evidence_rc=$?
set -e
[ "$fake_evidence_rc" -ne 0 ] || fail "control decision check should block fake evidence with no_progress effect"
python3 - "$TMP_DIR/control-fake-evidence-no-progress.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "INCREMENT_NO_PROGRESS"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-no-increment-reroute.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "developer",
  "owner": "fix",
  "gap": "developer cannot isolate failing command",
  "decision": "REROUTE",
  "increment": {
    "kind": "no_increment",
    "effect": "no_progress",
    "reason": "developer produced no new evidence after bounded follow-up"
  },
  "evidence_refs": ["artifact://executor-reply/sample-feature.phase-1.task-T1@attempt-2#no-increment"],
  "next_action": "reroute to fix for root cause isolation",
  "blocked_by": "无",
  "reroute_reason": "failure is now a root-cause investigation gap"
}
JSON
bash "$CONTROL" --decision "$TMP_DIR/control-no-increment-reroute.json" >"$TMP_DIR/control-no-increment-reroute.out"
python3 - "$TMP_DIR/control-no-increment-reroute.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "PASS"
assert payload["control_decision"] == "REROUTE"
assert payload["increment_kind"] == "no_increment"
PY

cat >"$TMP_DIR/control-reroute-unsupported-owner.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "developer",
  "owner": "authority",
  "gap": "developer cannot isolate failing command",
  "decision": "REROUTE",
  "increment": {
    "kind": "no_increment",
    "effect": "no_progress",
    "reason": "developer produced no new evidence after bounded follow-up"
  },
  "evidence_refs": ["artifact://executor-reply/sample-feature.phase-1.task-T1@attempt-2#no-increment"],
  "next_action": "reroute to authority",
  "blocked_by": "无",
  "reroute_reason": "authority is not an executable role owner"
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-reroute-unsupported-owner.json" >"$TMP_DIR/control-reroute-unsupported-owner.out"
unsupported_owner_rc=$?
set -e
[ "$unsupported_owner_rc" -ne 0 ] || fail "control decision check should block unsupported reroute owner"
python3 - "$TMP_DIR/control-reroute-unsupported-owner.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "REROUTE_OWNER_UNSUPPORTED"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-escalate-missing-packet.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "qa",
  "owner": "business owner",
  "gap": "release window risk has no business owner decision",
  "decision": "ESCALATE",
  "increment": {
    "kind": "risk",
    "effect": "new_risk",
    "summary": "QA found release risk that requires authority decision"
  },
  "evidence_refs": ["artifact://qa-result/sample-feature.phase-1.qa@v1#release-risk"],
  "next_action": "ask authority",
  "blocked_by": "release window decision missing",
  "required_authority": "business owner"
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-escalate-missing-packet.json" >"$TMP_DIR/control-escalate-missing-packet.out"
escalate_missing_packet_rc=$?
set -e
[ "$escalate_missing_packet_rc" -ne 0 ] || fail "control decision check should block ESCALATE without escalation_packet"
python3 - "$TMP_DIR/control-escalate-missing-packet.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "CONTROL_INCOMPLETE"
assert payload["fields"] == ["escalation_packet"]
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-escalate-pass.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "qa",
  "owner": "business owner",
  "gap": "release window risk has no business owner decision",
  "decision": "ESCALATE",
  "increment": {
    "kind": "risk",
    "effect": "new_risk",
    "summary": "QA found release risk that requires authority decision"
  },
  "evidence_refs": ["artifact://qa-result/sample-feature.phase-1.qa@v1#release-risk"],
  "next_action": "send escalation packet to business owner",
  "blocked_by": "release window decision missing",
  "required_authority": "business owner",
  "escalation_packet": {
    "problem": "release window risk has no accepted owner decision",
    "attempted_actions": ["QA completed release-risk check", "delivery-owner reviewed qa-result"],
    "blocking_decision": "accept risk or delay release",
    "options": ["accept documented risk", "delay release until support window opens"],
    "recommended_path": "delay release until support window opens",
    "risk": "unsupported release could leave users without rollback coverage",
    "required_authority": "business owner",
    "evidence_refs": ["artifact://qa-result/sample-feature.phase-1.qa@v1#release-risk"]
  }
}
JSON
bash "$CONTROL" --decision "$TMP_DIR/control-escalate-pass.json" >"$TMP_DIR/control-escalate-pass.out"
python3 - "$TMP_DIR/control-escalate-pass.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "PASS"
assert payload["control_decision"] == "ESCALATE"
assert payload["increment_effect"] == "new_risk"
PY

cat >"$TMP_DIR/control-escalate-owner-mismatch.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "qa",
  "owner": "authority",
  "gap": "release window risk has no business owner decision",
  "decision": "ESCALATE",
  "increment": {
    "kind": "risk",
    "effect": "new_risk",
    "summary": "QA found release risk that requires authority decision"
  },
  "evidence_refs": ["artifact://qa-result/sample-feature.phase-1.qa@v1#release-risk"],
  "next_action": "send escalation packet to business owner",
  "blocked_by": "release window decision missing",
  "required_authority": "business owner",
  "escalation_packet": {
    "problem": "release window risk has no accepted owner decision",
    "attempted_actions": ["QA completed release-risk check", "delivery-owner reviewed qa-result"],
    "blocking_decision": "accept risk or delay release",
    "options": ["accept documented risk", "delay release until support window opens"],
    "recommended_path": "delay release until support window opens",
    "risk": "unsupported release could leave users without rollback coverage",
    "required_authority": "business owner",
    "evidence_refs": ["artifact://qa-result/sample-feature.phase-1.qa@v1#release-risk"]
  }
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-escalate-owner-mismatch.json" >"$TMP_DIR/control-escalate-owner-mismatch.out"
escalate_owner_mismatch_rc=$?
set -e
[ "$escalate_owner_mismatch_rc" -ne 0 ] || fail "control decision check should block ESCALATE owner mismatch"
python3 - "$TMP_DIR/control-escalate-owner-mismatch.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "OWNER_AUTHORITY_MISMATCH"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-rebaseline-missing-request.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T2",
  "previous_owner": "developer",
  "owner": "tech-lead",
  "gap": "task scope no longer matches AC after dependency change",
  "decision": "REBASELINE",
  "increment": {
    "kind": "rebaseline_request",
    "effect": "rebaseline_needed",
    "summary": "scope and AC need tech-lead refresh"
  },
  "evidence_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T2.developer-report@v2#scope-blocked"],
  "next_action": "ask tech-lead to refresh task",
  "blocked_by": "scope/AC mismatch",
  "rebaseline_reason": "task scope no longer matches AC after dependency change"
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-rebaseline-missing-request.json" >"$TMP_DIR/control-rebaseline-missing-request.out"
rebaseline_missing_request_rc=$?
set -e
[ "$rebaseline_missing_request_rc" -ne 0 ] || fail "control decision check should block REBASELINE without rebaseline_request"
python3 - "$TMP_DIR/control-rebaseline-missing-request.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "CONTROL_INCOMPLETE"
assert payload["fields"] == ["rebaseline_request"]
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-rebaseline-pass.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T2",
  "previous_owner": "developer",
  "owner": "tech-lead",
  "gap": "task scope no longer matches AC after dependency change",
  "decision": "REBASELINE",
  "increment": {
    "kind": "rebaseline_request",
    "effect": "rebaseline_needed",
    "summary": "scope and AC need tech-lead refresh"
  },
  "evidence_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T2.developer-report@v2#scope-blocked"],
  "next_action": "send rebaseline request to tech-lead",
  "blocked_by": "scope/AC mismatch",
  "rebaseline_reason": "task scope no longer matches AC after dependency change",
  "rebaseline_request": {
    "problem": "task scope no longer matches AC after dependency change",
    "affected_refs": ["artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T2"],
    "requested_update": "refresh task scope and AC dependency notes",
    "rebaseline_owner": "tech-lead",
    "evidence_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T2.developer-report@v2#scope-blocked"],
    "stop_condition": "new frozen plan/tasks version is available"
  }
}
JSON
bash "$CONTROL" --decision "$TMP_DIR/control-rebaseline-pass.json" >"$TMP_DIR/control-rebaseline-pass.out"
python3 - "$TMP_DIR/control-rebaseline-pass.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "PASS"
assert payload["control_decision"] == "REBASELINE"
assert payload["increment_effect"] == "rebaseline_needed"
PY

cat >"$TMP_DIR/control-rebaseline-owner-mismatch.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T2",
  "previous_owner": "developer",
  "owner": "delivery-owner",
  "gap": "task scope no longer matches AC after dependency change",
  "decision": "REBASELINE",
  "increment": {
    "kind": "rebaseline_request",
    "effect": "rebaseline_needed",
    "summary": "scope and AC need tech-lead refresh"
  },
  "evidence_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T2.developer-report@v2#scope-blocked"],
  "next_action": "send rebaseline request to tech-lead",
  "blocked_by": "scope/AC mismatch",
  "rebaseline_reason": "task scope no longer matches AC after dependency change",
  "rebaseline_request": {
    "problem": "task scope no longer matches AC after dependency change",
    "affected_refs": ["artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T2"],
    "requested_update": "refresh task scope and AC dependency notes",
    "rebaseline_owner": "tech-lead",
    "evidence_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T2.developer-report@v2#scope-blocked"],
    "stop_condition": "new frozen plan/tasks version is available"
  }
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-rebaseline-owner-mismatch.json" >"$TMP_DIR/control-rebaseline-owner-mismatch.out"
rebaseline_owner_mismatch_rc=$?
set -e
[ "$rebaseline_owner_mismatch_rc" -ne 0 ] || fail "control decision check should block REBASELINE owner mismatch"
python3 - "$TMP_DIR/control-rebaseline-owner-mismatch.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "OWNER_REBASELINE_MISMATCH"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-blocked-missing-packet.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T3",
  "previous_owner": "developer",
  "owner": "resource owner",
  "gap": "developer executor is unavailable",
  "decision": "BLOCKED",
  "increment": {
    "kind": "no_increment",
    "effect": "no_progress",
    "reason": "no developer executor is available for the scoped task"
  },
  "evidence_refs": ["artifact://resource-check/sample-feature.phase-1.task-T3@v1#developer-unavailable"],
  "next_action": "wait for resource",
  "blocked_by": "developer executor unavailable"
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-blocked-missing-packet.json" >"$TMP_DIR/control-blocked-missing-packet.out"
blocked_missing_packet_rc=$?
set -e
[ "$blocked_missing_packet_rc" -ne 0 ] || fail "control decision check should block BLOCKED without blocker_packet"
python3 - "$TMP_DIR/control-blocked-missing-packet.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "CONTROL_INCOMPLETE"
assert payload["fields"] == ["blocker_packet"]
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-blocked-pass.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T3",
  "previous_owner": "developer",
  "owner": "resource owner",
  "gap": "developer executor is unavailable",
  "decision": "BLOCKED",
  "increment": {
    "kind": "no_increment",
    "effect": "no_progress",
    "reason": "no developer executor is available for the scoped task"
  },
  "evidence_refs": ["artifact://resource-check/sample-feature.phase-1.task-T3@v1#developer-unavailable"],
  "next_action": "request developer executor capacity",
  "blocked_by": "developer executor unavailable",
  "blocker_packet": {
    "blocked_by": "developer executor unavailable",
    "attempted_actions": ["checked available role executors", "confirmed no substitute developer agent is authorized"],
    "unblock_condition": "developer executor or explicit resource waiver is available",
    "next_owner": "resource owner",
    "evidence_refs": ["artifact://resource-check/sample-feature.phase-1.task-T3@v1#developer-unavailable"]
  }
}
JSON
bash "$CONTROL" --decision "$TMP_DIR/control-blocked-pass.json" >"$TMP_DIR/control-blocked-pass.out"
python3 - "$TMP_DIR/control-blocked-pass.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "PASS"
assert payload["control_decision"] == "BLOCKED"
assert payload["increment_effect"] == "no_progress"
PY

cat >"$TMP_DIR/control-blocked-owner-mismatch.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T3",
  "previous_owner": "developer",
  "owner": "delivery-owner",
  "gap": "developer executor is unavailable",
  "decision": "BLOCKED",
  "increment": {
    "kind": "no_increment",
    "effect": "no_progress",
    "reason": "no developer executor is available for the scoped task"
  },
  "evidence_refs": ["artifact://resource-check/sample-feature.phase-1.task-T3@v1#developer-unavailable"],
  "next_action": "request developer executor capacity",
  "blocked_by": "developer executor unavailable",
  "blocker_packet": {
    "blocked_by": "developer executor unavailable",
    "attempted_actions": ["checked available role executors", "confirmed no substitute developer agent is authorized"],
    "unblock_condition": "developer executor or explicit resource waiver is available",
    "next_owner": "resource owner",
    "evidence_refs": ["artifact://resource-check/sample-feature.phase-1.task-T3@v1#developer-unavailable"]
  }
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-blocked-owner-mismatch.json" >"$TMP_DIR/control-blocked-owner-mismatch.out"
blocked_owner_mismatch_rc=$?
set -e
[ "$blocked_owner_mismatch_rc" -ne 0 ] || fail "control decision check should block BLOCKED owner mismatch"
python3 - "$TMP_DIR/control-blocked-owner-mismatch.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "OWNER_BLOCKER_MISMATCH"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-signoff-missing-bundle.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "delivery-owner",
  "owner": "delivery-owner",
  "gap": "all role evidence appears complete",
  "decision": "SIGNOFF_READY",
  "increment": {
    "kind": "readiness_bundle",
    "effect": "readiness_bundle_complete",
    "summary": "attempting signoff readiness"
  },
  "evidence_refs": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#summary"],
  "next_action": "prepare signoff package",
  "blocked_by": "无"
}
JSON
set +e
bash "$CONTROL" --decision "$TMP_DIR/control-signoff-missing-bundle.json" >"$TMP_DIR/control-signoff-missing-bundle.out"
signoff_missing_rc=$?
set -e
[ "$signoff_missing_rc" -ne 0 ] || fail "control decision check should block SIGNOFF_READY without readiness bundle"
python3 - "$TMP_DIR/control-signoff-missing-bundle.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "BLOCKED"
assert payload["failure_code"] == "READINESS_BUNDLE_INCOMPLETE"
assert payload["safe_to_continue"] is False
PY

cat >"$TMP_DIR/control-signoff-pass.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "previous_owner": "delivery-owner",
  "owner": "delivery-owner",
  "gap": "all readiness evidence is closed",
  "decision": "SIGNOFF_READY",
  "increment": {
    "kind": "readiness_bundle",
    "effect": "readiness_bundle_complete",
    "summary": "readiness bundle assembled from role-owned evidence"
  },
  "evidence_refs": ["artifact://signoff-package/sample-feature.phase-1.signoff@v1#goal-closure"],
  "next_action": "hand signoff package to authority",
  "blocked_by": "无",
  "readiness_bundle_refs": {
    "developer_reports": ["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#summary"],
    "verify_results": ["artifact://verify-result/sample-feature.phase-1.unit-1.task-T1.verify@v1#summary"],
    "code_review_result": "artifact://code-review-result/sample-feature.phase-1.review@v1#summary",
    "qa_result": "artifact://qa-result/sample-feature.phase-1.qa@v1#release",
    "consistency_audit_result": "artifact://consistency-audit-result/sample-feature.phase-1.audit@v1#summary",
    "signoff_package": "artifact://signoff-package/sample-feature.phase-1.signoff@v1#goal-closure"
  }
}
JSON
bash "$CONTROL" --decision "$TMP_DIR/control-signoff-pass.json" >"$TMP_DIR/control-signoff-pass.out"
python3 - "$TMP_DIR/control-signoff-pass.out" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "PASS"
assert payload["control_decision"] == "SIGNOFF_READY"
assert payload["increment_kind"] == "readiness_bundle"
PY

echo "[PASS] delivery-owner control contract"
