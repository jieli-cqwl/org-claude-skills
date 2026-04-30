#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/delivery-owner/SKILL.md"
INTAKE="$ROOT/shared/skills/delivery-owner/scripts/intake_preflight_check.sh"
PACKET="$ROOT/shared/skills/delivery-owner/scripts/task_packet_check.sh"
COMPLETION="$ROOT/shared/skills/delivery-owner/scripts/completion_check.sh"
MANIFEST="$ROOT/shared/skills/delivery-owner/scripts/manifest.json"
PHASE="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1"
TMP_DIR="$(mktemp -d "$ROOT/tests/.tmp.delivery-owner.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
rm -rf "$ROOT/shared/skills/delivery-owner/scripts/__pycache__"

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

assert_missing() {
  local path="$1"
  [ ! -e "$path" ] || fail "unexpected retained file: ${path#"$ROOT"/}"
}

[ -f "$SKILL" ] || fail "missing active delivery-owner skill"
[ -x "$INTAKE" ] || fail "missing intake preflight wrapper"
[ -x "$PACKET" ] || fail "missing task packet wrapper"
[ -x "$COMPLETION" ] || fail "missing delivery readiness wrapper"
test -f "$MANIFEST" || fail "missing delivery-owner script manifest"

assert_contains "name: delivery-owner" "$SKILL"
assert_contains "交付负责人" "$SKILL"
assert_contains "tech-lead 已冻结" "$SKILL"
assert_contains '调度 developer agent / verifier agent / qa agent / fixer agent / `/commit`' "$SKILL"
assert_contains "上游计划由 tech-lead 提供" "$SKILL"
assert_contains "前置校验" "$SKILL"
assert_contains "交付视角 review" "$SKILL"
assert_contains "开发/验证或 QA/修复达到 10 轮" "$SKILL"
assert_contains '调度 `/commit`' "$SKILL"
assert_contains "用户是决策方" "$SKILL"
assert_contains "developer agent" "$SKILL"
assert_contains "verifier agent" "$SKILL"
assert_contains "qa agent" "$SKILL"
assert_contains "fixer agent" "$SKILL"
assert_contains "NEEDS_RESOURCE" "$SKILL"
assert_contains "templates/user-decision-package.template.md" "$SKILL"
assert_contains "intake_preflight_check.sh" "$SKILL"
assert_contains "task_packet_check.sh" "$SKILL"
assert_contains "artifact-registry.json" "$SKILL"
assert_contains "worklog.md" "$SKILL"
assert_contains "references/plan-review.md" "$SKILL"
assert_contains "references/dispatch-packet.md" "$SKILL"
assert_contains "references/followup-loops.md" "$SKILL"
assert_contains "verifier agent FAIL" "$SKILL"
assert_contains "回派 developer agent" "$SKILL"
assert_contains "scope/AC/技术基线不清时暂停给用户" "$SKILL"
assert_contains "开发/验证循环" "$SKILL"
assert_contains "qa agent FAIL" "$SKILL"
assert_contains "可复现缺陷调度 fixer agent" "$SKILL"
assert_contains "fixer agent 后重跑受影响 verifier agent / qa agent" "$SKILL"
assert_contains "授权明确时调度" "$SKILL"

assert_not_contains "signoff_ready" "$SKILL"
assert_not_contains "不是 developer" "$SKILL"
assert_not_contains "主 Agent" "$SKILL"
assert_not_contains "不要用于" "$SKILL"
assert_not_contains "你只保留交付状态" "$SKILL"
assert_not_contains "对应 role agent" "$SKILL"
assert_not_contains "codex/agents" "$SKILL"
assert_not_contains "control_decision_check.sh" "$SKILL"
assert_not_contains "gap_delta" "$SKILL"
assert_not_contains "rebaseline_needed" "$SKILL"
assert_not_contains "references/routing-and-packet.md" "$SKILL"
assert_not_contains "references/evidence-and-followup.md" "$SKILL"
assert_not_contains "references/intake-and-state.md" "$SKILL"
assert_not_contains "references/escalation-and-signoff.md" "$SKILL"

assert_contains "Review Matrix" "$ROOT/shared/skills/delivery-owner/references/plan-review.md"
assert_contains "Dependency" "$ROOT/shared/skills/delivery-owner/references/plan-review.md"
assert_contains "Pause" "$ROOT/shared/skills/delivery-owner/references/plan-review.md"
assert_contains "gap -> logical role -> runtime executor -> packet -> evidence" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_contains "/commit handoff" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_contains "developer preflight" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_contains "RED/GREEN/REFACTOR" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_contains "developer-report.json" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_contains "verifier agent" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_contains '`verifier`' "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_contains "qa agent" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_contains "fixer agent" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_contains '`fixer`' "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_contains "runtime executor" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_contains "不写 runtime 专属文件路径" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_not_contains "codex/agents/developer.toml" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_not_contains "codex/agents/verifier.toml" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_not_contains "codex/agents/qa.toml" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_not_contains "codex/agents/fixer.toml" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_contains "QA_A/QA_B/QA_C/QA_D" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_contains "round 10" "$ROOT/shared/skills/delivery-owner/references/followup-loops.md"
assert_contains "无进展" "$ROOT/shared/skills/delivery-owner/references/followup-loops.md"
assert_contains "templates/user-decision-package.template.md" "$ROOT/shared/skills/delivery-owner/references/followup-loops.md"
assert_contains "PAUSED_FOR_USER_DECISION" "$ROOT/shared/skills/delivery-owner/templates/user-decision-package.template.md"
assert_contains "NEEDS_RESOURCE" "$ROOT/shared/skills/delivery-owner/templates/user-decision-package.template.md"
assert_contains "developer-verifier-fail-loop-reruns" "$ROOT/shared/skills/delivery-owner/evals/evals.json"
assert_contains "developer agent 返回后必须再次调度 verifier agent" "$ROOT/shared/skills/delivery-owner/evals/evals.json"
assert_contains "连续 2 轮无进展时暂停给用户决策" "$ROOT/shared/skills/delivery-owner/evals/evals.json"
assert_contains "qa-fixer-fail-loop-reruns" "$ROOT/shared/skills/delivery-owner/evals/evals.json"
assert_contains "fixer agent 修改后不能直接 /commit" "$ROOT/shared/skills/delivery-owner/evals/evals.json"
assert_contains "重跑受影响 verifier agent 和 qa agent" "$ROOT/shared/skills/delivery-owner/evals/evals.json"

STATUS_TEMPLATE="$ROOT/shared/skills/delivery-owner/templates/status-card.template.md"
DECISION_TEMPLATE="$ROOT/shared/skills/delivery-owner/templates/user-decision-package.template.md"
REPORT_TEMPLATE="$ROOT/shared/skills/delivery-owner/templates/delivery-report.template.md"

assert_contains "current_gap:" "$STATUS_TEMPLATE"
assert_contains "gap_owner:" "$STATUS_TEMPLATE"
assert_contains "next_owner:" "$STATUS_TEMPLATE"
assert_contains "progress_signal:" "$STATUS_TEMPLATE"
assert_contains "consecutive_no_progress_count:" "$STATUS_TEMPLATE"
assert_contains "stale_evidence_refs:" "$STATUS_TEMPLATE"
assert_contains "decision_boundary:" "$STATUS_TEMPLATE"
assert_contains "resume_condition:" "$STATUS_TEMPLATE"

assert_contains "decision_needed:" "$DECISION_TEMPLATE"
assert_contains "evidence_refs:" "$DECISION_TEMPLATE"
assert_contains "required_user_answer:" "$DECISION_TEMPLATE"
assert_contains "resume_condition:" "$DECISION_TEMPLATE"
assert_contains "next_action_after_decision:" "$DECISION_TEMPLATE"

assert_contains "dev_verify_summary:" "$REPORT_TEMPLATE"
assert_contains "qa_fix_summary:" "$REPORT_TEMPLATE"
assert_contains "commit_result:" "$REPORT_TEMPLATE"
assert_contains "open_risks:" "$REPORT_TEMPLATE"
assert_contains "evidence_refs:" "$REPORT_TEMPLATE"

for obsolete in \
  "$ROOT/shared/skills/delivery-owner/references/routing-and-packet.md" \
  "$ROOT/shared/skills/delivery-owner/references/evidence-and-followup.md" \
  "$ROOT/shared/skills/delivery-owner/references/intake-and-state.md" \
  "$ROOT/shared/skills/delivery-owner/references/escalation-and-signoff.md" \
  "$ROOT/shared/skills/delivery-owner/scripts/control_decision_check.sh" \
  "$ROOT/shared/skills/delivery-owner/scripts/control_decision_check.py" \
  "$ROOT/shared/skills/delivery-owner/scripts/control_decision_support.py" \
  "$ROOT/shared/skills/delivery-owner/scripts/__pycache__"
do
assert_missing "$obsolete"
done
assert_missing "$ROOT/shared/skills/delivery-owner-h"
assert_missing "$ROOT/tools/community/validate_delivery_owner_commit_preflight.py"

jq empty "$MANIFEST" >/dev/null || fail "delivery-owner manifest must be valid JSON"
python3 "$ROOT/tools/skill_quality/check_skill_body_quality.py" "$SKILL" >/tmp/delivery-owner-body-quality.json
python3 "$ROOT/tools/skill_quality/check_skill_package_quality.py" "$ROOT/shared/skills/delivery-owner" >/tmp/delivery-owner-package-quality.json
python3 -m py_compile \
  "$ROOT/shared/skills/delivery-owner/scripts/intake_preflight_check.py" \
  "$ROOT/shared/skills/delivery-owner/scripts/task_packet_check.py"
rm -rf "$ROOT/shared/skills/delivery-owner/scripts/__pycache__"
bash -n "$COMPLETION" || fail "completion wrapper must pass shell syntax"

python3 - "$MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
ids = {item.get("id") for item in manifest.get("scripts", [])}
if "control-decision-check" in ids:
    raise SystemExit("manifest must not expose old control-decision-check")
for expected in {"intake-preflight-check", "task-packet-check", "completion-check"}:
    if expected not in ids:
        raise SystemExit(f"manifest missing {expected}")
PY

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

cat >"$TMP_DIR/qa-packet-pass.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#qa",
  "role": "qa",
  "goal": "Validate required user paths after verified tasks",
  "scope": ["QA_A", "QA_B", "QA_C", "QA_D"],
  "input_refs": ["artifact://qa-handoff/sample-feature.phase-1.unit-1@v1#qa_handoff_contract"],
  "expected_evidence": ["QA_A result", "QA_B result", "QA_C result", "QA_D result", "qa-result.json"],
  "stop_condition": "All required QA paths pass or a reproducible issue is reported",
  "forbidden_actions": [
    "do not modify scope outside packet",
    "do not modify baseline or AC",
    "do not commit or release",
    "do not conclude for other roles"
  ]
}
JSON
bash "$PACKET" --packet "$TMP_DIR/qa-packet-pass.json" >"$TMP_DIR/qa-packet-pass.out"
python3 - "$TMP_DIR/qa-packet-pass.out" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "PASS"
assert payload["role"] == "qa"
PY

cat >"$TMP_DIR/verifier-packet-pass.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "role": "verifier",
  "goal": "Verify AC and scope for T1",
  "scope": ["src/feature.ts", "tests/feature.test.ts"],
  "input_refs": ["artifact://developer-report/sample-feature.phase-1.task-T1@v1#summary"],
  "expected_evidence": ["AC verification", "scope verification", "verify-result.json"],
  "stop_condition": "AC/scope PASS or exact missing gap is reported",
  "forbidden_actions": [
    "do not modify scope outside packet",
    "do not modify baseline or AC",
    "do not commit or release",
    "do not conclude for other roles"
  ]
}
JSON
bash "$PACKET" --packet "$TMP_DIR/verifier-packet-pass.json" >"$TMP_DIR/verifier-packet-pass.out"
python3 - "$TMP_DIR/verifier-packet-pass.out" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "PASS"
assert payload["role"] == "verifier"
PY

cat >"$TMP_DIR/fixer-packet-pass.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "role": "fixer",
  "goal": "Root cause and minimal fix for the reported failure",
  "scope": ["src/feature.ts", "tests/feature.test.ts"],
  "input_refs": ["artifact://verify-result/sample-feature.phase-1.task-T1@v1#fail"],
  "expected_evidence": ["root cause", "minimal fix", "freshness check", "fix-result.json"],
  "stop_condition": "Failure fixed or exact blocker is reported",
  "forbidden_actions": [
    "do not modify scope outside packet",
    "do not modify baseline or AC",
    "do not commit or release",
    "do not conclude for other roles"
  ]
}
JSON
bash "$PACKET" --packet "$TMP_DIR/fixer-packet-pass.json" >"$TMP_DIR/fixer-packet-pass.out"
python3 - "$TMP_DIR/fixer-packet-pass.out" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "PASS"
assert payload["role"] == "fixer"
PY

echo "[PASS] delivery-owner SOP contract"
