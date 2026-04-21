#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

QA_CHECK="$ROOT/shared/skills/qa/scripts/completion_check.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

prepare_workspace() {
  local workspace="$1"
  mkdir -p "$workspace/docs"
  cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$workspace/docs/sample-feature"
}

run_gate() {
  local workspace="$1"
  local payload
  printf 'docs/sample-feature/phase-1/qa-result.json\n' > "$workspace/transcript.log"
  payload="$(jq -nc \
    --arg cwd "$workspace" \
    --arg sid "qa-browser-gate-contract" \
    --arg tp "$workspace/transcript.log" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp}')"
  if (cd "$workspace" && bash "$QA_CHECK" <<<"$payload") >"$workspace/qa.stdout" 2>"$workspace/qa.stderr"; then
    printf '0\n' > "$workspace/qa.status"
  else
    printf '%s\n' "$?" > "$workspace/qa.status"
  fi
}

assert_failed_with() {
  local workspace="$1"
  local pattern="$2"
  local status
  status="$(cat "$workspace/qa.status")"
  [ "$status" != "0" ] || {
    cat "$workspace/qa.stdout" >&2
    fail "QA browser gate was expected to block"
  }
  rg -n "$pattern" "$workspace/qa.stderr" >/dev/null 2>&1 || {
    cat "$workspace/qa.stderr" >&2
    fail "QA browser gate did not report expected pattern: $pattern"
  }
}

assert_passed() {
  local workspace="$1"
  local status
  status="$(cat "$workspace/qa.status")"
  [ "$status" = "0" ] || {
    cat "$workspace/qa.stderr" >&2
    fail "QA browser gate should pass"
  }
  jq -e '.decision == "allow"' "$workspace/qa.stdout" >/dev/null 2>&1 || {
    cat "$workspace/qa.stdout" >&2
    fail "QA browser gate did not emit allow decision"
  }
}

make_browser_required() {
  local test_cases="$1"
  jq '
    .qa_handoff_contract += [{
      "test_obligation": "E2E browser journey",
      "trigger_source": "web entrypoint",
      "qa_stage": "QA_B",
      "requiredness": "REQUIRED",
      "execution_mode": "browser_required",
      "skip_rule": "must explain if not executed",
      "evidence_expectation": "browser trace or screenshot"
    }]
  ' "$test_cases" > "$test_cases.tmp"
  mv "$test_cases.tmp" "$test_cases"
}

add_browser_evidence() {
  local qa_result="$1"
  jq '
    .browser_tool = "playwright"
    | .entry_url = "https://example.test/login"
    | .browser_evidence = [
      "playwright trace: traces/login.zip",
      "browser screenshot: artifacts/login-success.png"
    ]
  ' "$qa_result" > "$qa_result.tmp"
  mv "$qa_result.tmp" "$qa_result"
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/qa-browser-canonical.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

prepare_workspace "$TMP_ROOT"
make_browser_required "$TMP_ROOT/docs/sample-feature/phase-1/unit-1/test-cases.json"

run_gate "$TMP_ROOT"
assert_failed_with "$TMP_ROOT" 'browser_tool, entry_url, and browser-native evidence'

add_browser_evidence "$TMP_ROOT/docs/sample-feature/phase-1/qa-result.json"
run_gate "$TMP_ROOT"
assert_passed "$TMP_ROOT"

printf '[PASS] qa browser gate contract\n'
