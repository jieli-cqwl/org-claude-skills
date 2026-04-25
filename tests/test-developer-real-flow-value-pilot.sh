#!/usr/bin/env bash
# 文件职责：验证 developer 真实流程价值 pilot 与去重决策证据。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT/shared/skills/developer/scripts/completion_check.sh"
REVIEW="$ROOT/shared/skills/developer/evals/lifecycle-review.json"
ARCHIVE_CHANGELOG="$ROOT/docs/archive/skill-lifecycle-eval/CHANGELOG.md"
GOLDEN_REPORT="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json"
CLEANUP_PATHS=()

cleanup_paths() {
  local path
  for path in "${CLEANUP_PATHS[@]}"; do
    rm -rf "$path"
  done
}
trap cleanup_paths EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  test -f "$1" || fail "missing file: $1"
}

assert_present() {
  local needle="$1" file="$2"
  grep -Fq "$needle" "$file" || fail "missing content in $file: $needle"
}

run_completion_gate_case() {
  local label="$1" jq_filter="$2" expected_rc="$3" tmp_root report transcript stdout_file stderr_file payload rc

  tmp_root="$(mktemp -d "$ROOT/docs/developer-real-flow-pilot.XXXXXX")"
  stdout_file="$(mktemp "${TMPDIR:-/tmp}/developer-real-flow.stdout.XXXXXX")"
  stderr_file="$(mktemp "${TMPDIR:-/tmp}/developer-real-flow.stderr.XXXXXX")"

  CLEANUP_PATHS+=("$tmp_root" "$stdout_file" "$stderr_file")

  mkdir -p "$tmp_root/phase-1/unit-1/tasks/T1"
  report="$tmp_root/phase-1/unit-1/tasks/T1/developer-report.json"
  jq "$jq_filter" "$GOLDEN_REPORT" > "$report"
  transcript="$tmp_root/transcript.log"
  printf 'Write %s\n' "${report#"$ROOT"/}" > "$transcript"

  payload="$(jq -nc \
    --arg cwd "$ROOT" \
    --arg sid "session-developer-real-flow-pilot" \
    --arg tp "$transcript" \
    --arg fp "${report#"$ROOT"/}" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp, tool_name:"Write", tool_input:{file_path:$fp}}')"

  if bash "$CHECK" >"$stdout_file" 2>"$stderr_file" <<<"$payload"; then
    rc=0
  else
    rc=$?
  fi

  if [ "$expected_rc" = "nonzero" ] && [ "$rc" -eq 0 ]; then
    cat "$stdout_file" "$stderr_file" >&2
    fail "$label expected nonzero rc got rc=0"
  fi
  if [ "$expected_rc" != "nonzero" ] && [ "$rc" -ne "$expected_rc" ]; then
    cat "$stdout_file" "$stderr_file" >&2
    fail "$label expected rc=$expected_rc got rc=$rc"
  fi
}

assert_file "$CHECK"
assert_file "$REVIEW"
assert_file "$GOLDEN_REPORT"

git cat-file -e "e2ab752^{commit}" || fail "golden RED commit is not traceable"
git cat-file -e "9ec55db^{commit}" || fail "golden GREEN commit is not traceable"

run_completion_gate_case "golden pilot developer report" "." 0
run_completion_gate_case "mutated untraceable commit" '.tdd_evidence_index[0].commit_sha = "deadbee"' nonzero
run_completion_gate_case "mutated RED result" '.tdd_evidence_index[0].result = "PASS"' nonzero

assert_file "$ARCHIVE_CHANGELOG"
assert_present "## 2026-04-24 - Developer Real Flow Value Pilot" "$ARCHIVE_CHANGELOG"
assert_present "traceable RED/GREEN commits" "$ARCHIVE_CHANGELOG"
assert_present 'tests/test-developer-real-flow-value-pilot.sh' "$ARCHIVE_CHANGELOG"
assert_present "Classified \`developer\` as a merge candidate" "$ARCHIVE_CHANGELOG"

python3 - "$REVIEW" <<'PY'
import json
import sys
from pathlib import Path

review = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
pilot = review.get("process_value_pilot")
if not isinstance(pilot, dict):
    raise SystemExit("missing process_value_pilot")
if pilot.get("status") != "recorded":
    raise SystemExit("process_value_pilot.status must be recorded")
if pilot.get("pilot_type") != "real_flow_gate_pilot":
    raise SystemExit("pilot_type must be real_flow_gate_pilot")
if pilot.get("completion_gate_result") != "pass_with_negative_controls":
    raise SystemExit("completion gate result must include negative controls")
if pilot.get("sample_ref") != "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json":
    raise SystemExit("sample_ref must point at the golden pilot developer report")

dedupe = pilot.get("dedupe_summary")
if not isinstance(dedupe, dict):
    raise SystemExit("missing dedupe_summary")
if dedupe.get("developer_unique_responsibility") != "task_execution_tdd_report_evidence":
    raise SystemExit("wrong developer unique responsibility")
for role in ["delivery-owner", "verify", "test-driven-development", "subagent-driven-development"]:
    if role not in dedupe.get("overlap_roles", []):
        raise SystemExit(f"missing overlap role: {role}")

disposition = pilot.get("disposition")
if not isinstance(disposition, dict):
    raise SystemExit("missing disposition")
if disposition.get("current_lifecycle_decision") != "optimize":
    raise SystemExit("current lifecycle decision must stay optimize")
if disposition.get("recommended_action") != "merge_contracts_before_retirement_decision":
    raise SystemExit("recommended action must be merge_contracts_before_retirement_decision")
if disposition.get("retain_as_capability_uplift_skill") is not False:
    raise SystemExit("developer must not be retained as capability-uplift skill")
PY

printf '[PASS] developer real flow value pilot\n'
