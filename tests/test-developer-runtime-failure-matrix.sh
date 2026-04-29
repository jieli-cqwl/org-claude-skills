#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_PHASE_FIXTURE="$ROOT/tests/fixtures/developer-runtime-layering/phase-1"
WORK_ROOT="$(mktemp -d "$ROOT/docs/developer-runtime-fixture.XXXXXX")"
PHASE_FIXTURE="$WORK_ROOT/phase-1"
UNIT_FIXTURE="$PHASE_FIXTURE/unit-1"
REPORT="$UNIT_FIXTURE/tasks/T1/developer-report.json"
VALID_REPORT="$ROOT/tests/fixtures/developer-runtime-layering/verified-report.json"
BLOCKED_REPORT="$ROOT/tests/fixtures/developer-runtime-layering/blocked-report.json"

cp -R "$SOURCE_PHASE_FIXTURE" "$PHASE_FIXTURE"
mkdir -p "$(dirname "$REPORT")"
cp "$VALID_REPORT" "$REPORT"
restore_report() {
  rm -rf "$WORK_ROOT"
}
trap restore_report EXIT

run_validator() {
  python3 "$ROOT/tools/community/validate_developer_runtime_contract.py" \
    --phase-dir "$PHASE_FIXTURE" \
    --task-id T1 \
    --report "$REPORT"
}

run_validator >/dev/null

expect_block() {
  local label="$1" jq_filter="$2" expected_code="$3"
  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/developer-runtime-matrix.XXXXXX")"
  cp -R "$PHASE_FIXTURE" "$tmp/phase-1"
  jq "$jq_filter" "$REPORT" >"$tmp/phase-1/unit-1/tasks/T1/developer-report.json"
  if python3 "$ROOT/tools/community/validate_developer_runtime_contract.py" --phase-dir "$tmp/phase-1" --task-id T1 --report "$tmp/phase-1/unit-1/tasks/T1/developer-report.json" >"$tmp/out.json" 2>/dev/null; then
    printf '[FAIL] %s passed unexpectedly\n' "$label" >&2
    exit 1
  fi
  jq -e --arg code "$expected_code" '.failure_contract.failure_code == $code and .failure_contract.safe_to_continue == false' "$tmp/out.json" >/dev/null
  rm -rf "$tmp"
}

expect_phase_block() {
  local label="$1" expected_code="$2" mutation_script="$3"
  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/developer-runtime-phase.XXXXXX")"
  cp -R "$PHASE_FIXTURE" "$tmp/phase-1"
  PHASE_UNDER_TEST="$tmp/phase-1" bash -c "$mutation_script"
  if python3 "$ROOT/tools/community/validate_developer_runtime_contract.py" --phase-dir "$tmp/phase-1" --task-id T1 --report "$tmp/phase-1/unit-1/tasks/T1/developer-report.json" >"$tmp/out.json" 2>/dev/null; then
    printf '[FAIL] %s passed unexpectedly\n' "$label" >&2
    exit 1
  fi
  jq -e --arg code "$expected_code" '.failure_contract.failure_code == $code and .failure_contract.safe_to_continue == false' "$tmp/out.json" >/dev/null
  rm -rf "$tmp"
}

expect_blocked_report_passes_without_missing_inputs() {
  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/developer-runtime-blocked.XXXXXX")"
  cp -R "$PHASE_FIXTURE" "$tmp/phase-1"
  rm -f "$tmp/phase-1/design.json" "$tmp/phase-1/unit-1/test-cases.json"
  cp "$BLOCKED_REPORT" "$tmp/phase-1/unit-1/tasks/T1/developer-report.json"
  if ! python3 "$ROOT/tools/community/validate_developer_runtime_contract.py" --phase-dir "$tmp/phase-1" --task-id T1 --report "$tmp/phase-1/unit-1/tasks/T1/developer-report.json" >"$tmp/out.json" 2>/dev/null; then
    cat "$tmp/out.json" >&2
    printf '[FAIL] blocked report should pass without the missing runtime inputs it reports\n' >&2
    exit 1
  fi
  jq -e '.status == "PASS"' "$tmp/out.json" >/dev/null
  rm -rf "$tmp"
}

expect_phase_block "missing artifact registry" "MISSING_INPUT" "rm -f \"\$PHASE_UNDER_TEST/artifact-registry.json\""
expect_phase_block "unresolved active registry ref" "UNRESOLVED_REF" "jq 'del(.revisions[0].entries[] | select(.artifact_type == \"tasks\"))' \"\$PHASE_UNDER_TEST/artifact-registry.json\" > \"\$PHASE_UNDER_TEST/artifact-registry.json.tmp\" && mv \"\$PHASE_UNDER_TEST/artifact-registry.json.tmp\" \"\$PHASE_UNDER_TEST/artifact-registry.json\""
expect_blocked_report_passes_without_missing_inputs
expect_block "missing input" 'del(.active_plan_version_ref)' "MISSING_INPUT"
expect_block "ambiguous scope" '.task_scope = [] | .runtime_status = "PARTIAL"' "AMBIGUOUS_SCOPE"
expect_block "unresolved ref" '.tdd_evidence_index[0].ac_refs = ["artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-UNKNOWN"]' "UNRESOLVED_REF"
expect_block "owner mismatch" '.runtime_status = "BLOCKED" | .task_scope = [] | .file_changes = [] | .failure_contract = {"status":"BLOCKED","failure_code":"MISSING_INPUT","reason":"canonical inputs are missing","owner":"developer","safe_to_continue":false,"next_action":"redispatch through delivery-owner","evidence_refs":["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#blocked"],"user_message":"developer 输入缺失，已阻断。"}' "OWNER_MISMATCH"
expect_block "out of scope" '.file_changes = ["src/outside.ts"]' "OUT_OF_SCOPE_CHANGE"
expect_block "stale replay" '.active_plan_version_ref = "artifact://plan/sample-feature.phase-1.plan@old#plan-version"' "STALE_STATE_REPLAY"
expect_block "fresh proof gap" 'del(.fresh_proof.current_evidence_refs)' "FRESH_PROOF_GAP"

MALFORMED_DIR="$(mktemp -d "${TMPDIR:-/tmp}/developer-runtime-malformed.XXXXXX")"
cp -R "$PHASE_FIXTURE" "$MALFORMED_DIR/phase-1"
printf '{' >"$MALFORMED_DIR/phase-1/unit-1/tasks/T1/developer-report.json"
if python3 "$ROOT/tools/community/validate_developer_runtime_contract.py" --phase-dir "$MALFORMED_DIR/phase-1" --task-id T1 --report "$MALFORMED_DIR/phase-1/unit-1/tasks/T1/developer-report.json" >"$MALFORMED_DIR/out.json" 2>/dev/null; then
  printf '[FAIL] malformed report passed unexpectedly\n' >&2
  exit 1
fi
jq -e '.failure_contract.failure_code == "SCHEMA_FAILURE" and .failure_contract.safe_to_continue == false' "$MALFORMED_DIR/out.json" >/dev/null
rm -rf "$MALFORMED_DIR"

transcript="$(mktemp "${TMPDIR:-/tmp}/developer-runtime-gate.transcript.XXXXXX")"
stdout_file="$(mktemp "${TMPDIR:-/tmp}/developer-runtime-gate.stdout.XXXXXX")"
stderr_file="$(mktemp "${TMPDIR:-/tmp}/developer-runtime-gate.stderr.XXXXXX")"
payload="$(jq -nc \
  --arg cwd "$ROOT" \
  --arg tp "$transcript" \
  --arg fp "${REPORT#"$ROOT"/}" \
  '{cwd:$cwd, session_id:"developer-runtime-layering", transcript_path:$tp, tool_name:"Write", tool_input:{file_path:$fp}}')"
printf 'Write %s\n' "${REPORT#"$ROOT"/}" >"$transcript"
jq 'del(.fresh_proof.current_evidence_refs)' "$REPORT" >"$REPORT.tmp"
mv "$REPORT.tmp" "$REPORT"
if bash "$ROOT/shared/skills/developer/scripts/completion_check.sh" >"$stdout_file" 2>"$stderr_file" <<<"$payload"; then
  printf '[FAIL] developer completion gate accepted fresh proof gap\n' >&2
  exit 1
fi
grep -Eq 'FRESH_PROOF_GAP|fresh proof|runtime contract' "$stdout_file" "$stderr_file"
rm -f "$transcript" "$stdout_file" "$stderr_file"

printf '[PASS] developer runtime failure matrix\n'
