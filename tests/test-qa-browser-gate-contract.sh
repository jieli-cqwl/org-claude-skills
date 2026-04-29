#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

QA_CHECK="$ROOT/shared/skills/qa/scripts/completion_check.sh"
QA_MANIFEST="$ROOT/shared/skills/qa/scripts/manifest.json"
HOOK_REGISTRY="$ROOT/shared/hooks/registry.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_manifest_contract() {
  [ -f "$QA_MANIFEST" ] || fail "qa scripts manifest missing"
  jq -e '
    .schema_version == "1.0.0"
    and (.scripts | type == "array" and length > 0)
    and any(.scripts[];
      .id == "completion-check"
      and .path == "scripts/completion_check.sh"
      and .owner == "qa"
      and (.allowed_args | index("hook payload via stdin only") != null)
      and (.allowed_args | index("--help") != null)
      and (.denied_args | index("--exec") != null)
      and .timeout_seconds == 15
      and .failure_state == "QA_COMPLETION_GATE_FAILED"
      and (.verification_command | contains("tests/test-qa-browser-gate-contract.sh"))
    )
  ' "$QA_MANIFEST" >/dev/null || fail "qa manifest must define owner, args, timeout, failure state, and proof command"
  python3 - "$QA_MANIFEST" "$HOOK_REGISTRY" <<'PY' || fail "qa manifest and registry must mirror completion gate contract"
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
registry = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
script = next(item for item in manifest["scripts"] if item.get("id") == "completion-check")
entries = [item for item in registry["skill_completion_gates"] if item.get("skill") == "qa"]
if len(entries) != 1:
    raise SystemExit("qa registry must have exactly one entry")
entry = entries[0]
required = {"owner", "allowed_args", "output_root", "failure_state"}
missing = sorted(required - set(entry))
if missing:
    raise SystemExit(f"qa registry missing keys: {missing}")
if entry.get("handler_rel") != f"skills/qa/{script['path']}":
    raise SystemExit("qa registry and manifest handler drift")
if entry.get("timeout_sec") != script.get("timeout_seconds"):
    raise SystemExit("qa registry and manifest timeout drift")
for field in required:
    if entry.get(field) != script.get(field):
        raise SystemExit(f"qa registry and manifest {field} drift")
PY
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

make_fail_issue() {
  local qa_result="$1"
  local issue_id_expr="$2"
  jq ".gate_result = \"FAIL\"
    | .stage_results[0].gate_result = \"FAIL\"
    | .issue_ledger = [{
      \"severity\": \"S2\",
      \"priority\": \"P1\",
      \"impact_scope\": \"核心旅程\",
      \"user_impact\": \"用户无法完成 QA 验收路径\",
      \"environment_or_build\": \"local-test\",
      \"regression_flag\": \"yes\",
      \"temporary_workaround\": \"none\",
      \"owner_hint\": \"qa\",
      \"expected_behavior\": \"QA gate blocks invalid failure records\",
      \"actual_behavior\": \"failure record is malformed\",
      \"reproduction\": \"bash shared/skills/qa/scripts/completion_check.sh\"
    }]
    | $issue_id_expr" "$qa_result" > "$qa_result.tmp"
  mv "$qa_result.tmp" "$qa_result"
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

assert_manifest_contract

prepare_workspace "$TMP_ROOT"
make_browser_required "$TMP_ROOT/docs/sample-feature/phase-1/unit-1/test-cases.json"

run_gate "$TMP_ROOT"
assert_failed_with "$TMP_ROOT" 'browser_tool, entry_url, and browser-native evidence'

add_browser_evidence "$TMP_ROOT/docs/sample-feature/phase-1/qa-result.json"
run_gate "$TMP_ROOT"
assert_passed "$TMP_ROOT"

MISSING_QAR="$TMP_ROOT/missing-qar"
prepare_workspace "$MISSING_QAR"
make_fail_issue "$MISSING_QAR/docs/sample-feature/phase-1/qa-result.json" '.'
run_gate "$MISSING_QAR"
assert_failed_with "$MISSING_QAR" 'issue_id=QAR-XXX'

BAD_QAR="$TMP_ROOT/bad-qar"
prepare_workspace "$BAD_QAR"
make_fail_issue "$BAD_QAR/docs/sample-feature/phase-1/qa-result.json" '.issue_ledger[0].issue_id = "BUG-1"'
run_gate "$BAD_QAR"
assert_failed_with "$BAD_QAR" 'issue_id=QAR-XXX'

VALID_QAR="$TMP_ROOT/valid-qar"
prepare_workspace "$VALID_QAR"
make_fail_issue "$VALID_QAR/docs/sample-feature/phase-1/qa-result.json" '.issue_ledger[0].issue_id = "QAR-001"'
run_gate "$VALID_QAR"
assert_passed "$VALID_QAR"

printf '[PASS] qa browser gate contract\n'
