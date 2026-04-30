#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/delivery-owner/SKILL.md"
HISTORICAL_SKILL="$ROOT/shared/skills/delivery-owner-h/SKILL.md"
INTAKE="$ROOT/shared/skills/delivery-owner/scripts/intake_preflight_check.sh"
PACKET="$ROOT/shared/skills/delivery-owner/scripts/task_packet_check.sh"
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

assert_contains "name: delivery-owner" "$SKILL"
assert_contains "name: delivery-owner-h" "$HISTORICAL_SKILL"
assert_contains "交付控制负责人" "$SKILL"
assert_contains "tech-lead" "$SKILL"
assert_contains "task packet" "$SKILL"
assert_contains "intake_preflight_check.sh" "$SKILL"
assert_contains "task_packet_check.sh" "$SKILL"
assert_not_contains "delivery-gate-dispatch.md" "$SKILL"
assert_not_contains "commit_preflight_check.sh" "$SKILL"

python3 "$ROOT/tools/skill_quality/check_skill_body_quality.py" "$SKILL" >/tmp/delivery-owner-body-quality.json
python3 "$ROOT/tools/skill_quality/check_skill_package_quality.py" "$ROOT/shared/skills/delivery-owner" >/tmp/delivery-owner-package-quality.json
python3 -m py_compile \
  "$ROOT/shared/skills/delivery-owner/scripts/intake_preflight_check.py" \
  "$ROOT/shared/skills/delivery-owner/scripts/task_packet_check.py"

bash "$INTAKE" --phase-dir "$PHASE" >"$TMP_DIR/intake-pass.json"
python3 - "$TMP_DIR/intake-pass.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["status"] == "PASS"
assert payload["decision"] == "ACCEPTED"
assert payload["safe_to_dispatch"] is True
assert payload["task_count"] >= 1
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

cat >"$TMP_DIR/packet-pass.json" <<'JSON'
{
  "task_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
  "role": "developer",
  "goal": "Implement AC-T1-1 only",
  "scope": ["src/feature.ts", "tests/feature.test.ts"],
  "input_refs": ["artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version"],
  "expected_evidence": ["RED output", "GREEN output", "changed files"],
  "stop_condition": "AC-T1-1 green or scope/AC blocked",
  "forbidden_actions": ["do not modify scope outside packet", "do not commit"]
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

echo "[PASS] delivery-owner control contract"
