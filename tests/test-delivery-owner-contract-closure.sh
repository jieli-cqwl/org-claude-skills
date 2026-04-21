#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

CHECK_SCRIPT="$ROOT/shared/skills/delivery-owner/scripts/completion_check.sh"
FIXTURE="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

run_gate() {
  local root_dir="$1"
  local session_id="$2"
  local transcript_path="$3"
  local file_path="$4"
  local payload

  payload="$(jq -nc \
    --arg cwd "$root_dir" \
    --arg sid "$session_id" \
    --arg tp "$transcript_path" \
    --arg fp "$file_path" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp, tool_name:"Write", tool_input:{file_path:$fp}}')"

  LAST_CHECK_STDOUT="$(mktemp "${TMPDIR:-/tmp}/do-contract.stdout.XXXXXX")"
  LAST_CHECK_STDERR="$(mktemp "${TMPDIR:-/tmp}/do-contract.stderr.XXXXXX")"
  LAST_CHECK_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/do-contract.output.XXXXXX")"

  if bash "$CHECK_SCRIPT" >"$LAST_CHECK_STDOUT" 2>"$LAST_CHECK_STDERR" <<<"$payload"; then
    LAST_CHECK_STATUS=0
  else
    LAST_CHECK_STATUS=$?
  fi
  cat "$LAST_CHECK_STDOUT" "$LAST_CHECK_STDERR" >"$LAST_CHECK_OUTPUT"
}

expect_pass() {
  local root_dir="$1"
  local label="$2"
  local transcript_path="$3"
  local file_path="$4"

  run_gate "$root_dir" "$label" "$transcript_path" "$file_path"
  if [ "$LAST_CHECK_STATUS" -ne 0 ]; then
    cat "$LAST_CHECK_OUTPUT" >&2
    fail "$label: expected canonical completion gate to pass"
  fi
  assert_present '"decision":"allow"' "$LAST_CHECK_STDOUT"
  assert_present 'canonical readiness gate passed' "$LAST_CHECK_STDOUT"
}

expect_fail_with() {
  local root_dir="$1"
  local label="$2"
  local transcript_path="$3"
  local file_path="$4"
  local pattern="$5"

  run_gate "$root_dir" "$label" "$transcript_path" "$file_path"
  if [ "$LAST_CHECK_STATUS" -eq 0 ]; then
    cat "$LAST_CHECK_OUTPUT" >&2
    fail "$label: expected canonical completion gate to fail"
  fi
  assert_present "$pattern" "$LAST_CHECK_OUTPUT"
}

write_transcript() {
  local transcript_path="$1"
  local feature_name="$2"

  cat > "$transcript_path" <<EOF
docs/${feature_name}/phase-1/delivery-state.json
docs/${feature_name}/phase-1/signoff-package.json
EOF
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/do-contract.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

FEATURE_NAME="canonical-contract-closure"
PROJECT_ROOT="$TMP_ROOT/project"
mkdir -p "$PROJECT_ROOT/docs/$FEATURE_NAME"
cp -R "$FIXTURE/." "$PROJECT_ROOT/docs/$FEATURE_NAME/"

TRANSCRIPT="$PROJECT_ROOT/transcript.log"
write_transcript "$TRANSCRIPT" "$FEATURE_NAME"

expect_pass \
  "$PROJECT_ROOT" \
  "canonical-valid" \
  "$TRANSCRIPT" \
  "docs/$FEATURE_NAME/phase-1/signoff-package.json"

MISSING_SIGNOFF_ROOT="$TMP_ROOT/missing-signoff"
cp -R "$PROJECT_ROOT/." "$MISSING_SIGNOFF_ROOT/"
rm -f "$MISSING_SIGNOFF_ROOT/docs/$FEATURE_NAME/phase-1/signoff-package.json"
expect_fail_with \
  "$MISSING_SIGNOFF_ROOT" \
  "missing-signoff" \
  "$MISSING_SIGNOFF_ROOT/transcript.log" \
  "docs/$FEATURE_NAME/phase-1/signoff-package.json" \
  'signoff-package\.json'

NO_CANONICAL_TARGET_ROOT="$TMP_ROOT/no-canonical-target"
cp -R "$PROJECT_ROOT/." "$NO_CANONICAL_TARGET_ROOT/"
cat > "$NO_CANONICAL_TARGET_ROOT/transcript.log" <<EOF
docs/${FEATURE_NAME}/phase-1/notes.md
EOF
expect_fail_with \
  "$NO_CANONICAL_TARGET_ROOT" \
  "no-canonical-target" \
  "$NO_CANONICAL_TARGET_ROOT/transcript.log" \
  "docs/$FEATURE_NAME/phase-1/notes.md" \
  'canonical closeout 工件路径未命中'

echo "[PASS] delivery-owner canonical contract closure cases"
