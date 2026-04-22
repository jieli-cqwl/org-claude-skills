#!/usr/bin/env bash
# Tests review canonical gate semantics for conclusion mapping and finding locators.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK_SCRIPT="$ROOT/shared/skills/review/scripts/completion_check.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/review-canonical-gate.XXXXXX")"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

prepare_workspace() {
  local workspace="$1"
  mkdir -p "$workspace/docs" "$workspace/src"
  cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$workspace/docs/sample-feature"
  printf 'export const reviewed = 1;\nexport const bounded = 2;\n' > "$workspace/src/review-target.ts"
}

review_result_path() {
  local workspace="$1"
  printf '%s\n' "$workspace/docs/sample-feature/phase-1/code-review-result.json"
}

run_review_hook() {
  local workspace="$1"
  local session_id="$2"
  local transcript_path="$workspace/transcript.log"
  local payload status

  printf '%s\n' "docs/sample-feature/phase-1/code-review-result.json" > "$transcript_path"
  payload="$(jq -nc \
    --arg cwd "$workspace" \
    --arg sid "$session_id" \
    --arg tp "$transcript_path" \
    '{cwd:$cwd,
      session_id:$sid,
      transcript_path:$tp,
      tool_name:"Write",
      tool_input:{file_path:"docs/sample-feature/phase-1/code-review-result.json"}}')"

  if (cd "$workspace" && bash "$CHECK_SCRIPT" <<<"$payload") >"$workspace/hook.stdout" 2>"$workspace/hook.stderr"; then
    status=0
  else
    status=$?
  fi
  printf '%s\n' "$status" > "$workspace/hook.status"
}

assert_hook_passed() {
  local workspace="$1"
  local label="$2"
  local status

  status="$(cat "$workspace/hook.status")"
  if [ "$status" != "0" ]; then
    cat "$workspace/hook.stderr" >&2
    fail "$label should pass"
  fi
  jq -e '.decision == "allow"' "$workspace/hook.stdout" >/dev/null 2>&1 || {
    cat "$workspace/hook.stdout" >&2
    cat "$workspace/hook.stderr" >&2
    fail "$label should emit allow decision"
  }
}

assert_hook_blocked_with() {
  local workspace="$1"
  local label="$2"
  local expected="$3"
  local status

  status="$(cat "$workspace/hook.status")"
  if [ "$status" = "0" ]; then
    cat "$workspace/hook.stdout" >&2
    fail "$label should block"
  fi
  jq -e '.decision == "block"' "$workspace/hook.stdout" >/dev/null 2>&1 || {
    cat "$workspace/hook.stdout" >&2
    cat "$workspace/hook.stderr" >&2
    fail "$label should emit block decision"
  }
  grep -Fq "$expected" "$workspace/hook.stderr" || {
    cat "$workspace/hook.stderr" >&2
    fail "$label should report: $expected"
  }
}

set_mismatched_conclusion() {
  local target="$1"
  jq '.gate_result = "PASS" | .review_conclusion = "REQUEST_CHANGES"' "$target" > "$target.tmp"
  mv "$target.tmp" "$target"
}

set_single_finding() {
  local target="$1"
  local file_path="$2"
  local line_number="$3"

  jq \
    --arg file_path "$file_path" \
    --argjson line_number "$line_number" \
    '.gate_result = "FAIL"
      | .review_conclusion = "REQUEST_CHANGES"
      | .dimension_verdicts.correctness = "ISSUE"
      | .findings = [{
          finding_id: "REV-001",
          severity: "S2",
          summary: "synthetic review finding",
          file_path: $file_path,
          line_number: $line_number,
          confidence: 90,
          verification_status: "NOT_REQUIRED"
        }]' "$target" > "$target.tmp"
  mv "$target.tmp" "$target"
}

assert_schema_rejects_phase() {
  local workspace="$1"
  local label="$2"

  if (cd "$ROOT" && python3 tools/community/validate_canonical_schema.py --phase-dir "$workspace/docs/sample-feature/phase-1") \
    >"$workspace/schema.stdout" 2>"$workspace/schema.stderr"; then
    fail "$label should fail schema validation"
  fi
}

valid_workspace="$TMP_ROOT/valid"
prepare_workspace "$valid_workspace"
run_review_hook "$valid_workspace" "review-valid"
assert_hook_passed "$valid_workspace" "valid review result"

mismatch_workspace="$TMP_ROOT/mismatched-conclusion"
prepare_workspace "$mismatch_workspace"
set_mismatched_conclusion "$(review_result_path "$mismatch_workspace")"
run_review_hook "$mismatch_workspace" "review-mismatched-conclusion"
assert_hook_blocked_with \
  "$mismatch_workspace" \
  "mismatched gate_result and review_conclusion" \
  "gate_result must align with review_conclusion"

traversal_workspace="$TMP_ROOT/path-traversal"
prepare_workspace "$traversal_workspace"
set_single_finding "$(review_result_path "$traversal_workspace")" "../outside.ts" 1
run_review_hook "$traversal_workspace" "review-path-traversal"
assert_hook_blocked_with \
  "$traversal_workspace" \
  "finding path traversal" \
  "finding file_path must be repo-local"

missing_file_workspace="$TMP_ROOT/missing-file"
prepare_workspace "$missing_file_workspace"
set_single_finding "$(review_result_path "$missing_file_workspace")" "src/missing.ts" 1
run_review_hook "$missing_file_workspace" "review-missing-file"
assert_hook_blocked_with \
  "$missing_file_workspace" \
  "finding missing file" \
  "finding file_path does not exist"

missing_schema_workspace="$TMP_ROOT/schema-path-traversal"
prepare_workspace "$missing_schema_workspace"
set_single_finding "$(review_result_path "$missing_schema_workspace")" "../outside.ts" 1
assert_schema_rejects_phase "$missing_schema_workspace" "finding path traversal schema"

line_workspace="$TMP_ROOT/line-out-of-range"
prepare_workspace "$line_workspace"
set_single_finding "$(review_result_path "$line_workspace")" "src/review-target.ts" 999
run_review_hook "$line_workspace" "review-line-out-of-range"
assert_hook_blocked_with \
  "$line_workspace" \
  "finding line out of range" \
  "finding line_number exceeds file length"

echo "PASS: review canonical result gate enforces conclusion mapping and finding locators"
