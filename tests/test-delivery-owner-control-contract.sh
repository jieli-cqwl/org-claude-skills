#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/delivery-owner/SKILL.md"
HISTORICAL_SKILL="$ROOT/shared/skills/delivery-owner-h/SKILL.md"
INTAKE="$ROOT/shared/skills/delivery-owner/scripts/intake_preflight_check.sh"
PACKET="$ROOT/shared/skills/delivery-owner/scripts/task_packet_check.sh"
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
[ -x "$COMPLETION" ] || fail "missing delivery readiness wrapper"
test -f "$MANIFEST" || fail "missing delivery-owner script manifest"

assert_contains "name: delivery-owner" "$SKILL"
assert_contains "name: delivery-owner-h" "$HISTORICAL_SKILL"
assert_contains "交付负责人" "$SKILL"
assert_contains "tech-lead" "$SKILL"
assert_contains "task packet" "$SKILL"
assert_contains "intake_preflight_check.sh" "$SKILL"
assert_contains "task_packet_check.sh" "$SKILL"
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
  "$ROOT/shared/skills/delivery-owner/scripts/task_packet_check.py"
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

echo "[PASS] delivery-owner control contract"
