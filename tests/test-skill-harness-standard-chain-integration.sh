#!/usr/bin/env bash
# File role: prove skill-harness validates standard-chain gates and evidence contracts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py"
MANIFEST="$ROOT/shared/skills/skill-harness/scripts/manifest.json"
FIXTURES="$ROOT/tests/fixtures/skill-harness/standard-chain"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/skill-harness-standard-chain.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

expect_fail() {
  local label="$1"
  local expected="$2"
  shift 2
  local stdout_file
  local stderr_file
  stdout_file="$(mktemp "$TMP_DIR/stdout.XXXXXX")"
  stderr_file="$(mktemp "$TMP_DIR/stderr.XXXXXX")"
  set +e
  "$@" >"$stdout_file" 2>"$stderr_file"
  local rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    cat "$stdout_file"
    cat "$stderr_file" >&2
    fail "$label unexpectedly passed"
  fi
  if ! grep -Fq "$expected" "$stdout_file" "$stderr_file"; then
    cat "$stdout_file"
    cat "$stderr_file" >&2
    fail "$label did not report $expected"
  fi
}

[ -x "$CHECKER" ] || fail "missing executable checker"
[ -f "$MANIFEST" ] || fail "missing skill-harness manifest"

python3 - "$MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
roots = []
for script in manifest.get("scripts", []):
    if script.get("id") == "check-contract":
        roots = script.get("allowed_input_roots", [])
        break
if "tests/fixtures/skill-harness/standard-chain" not in roots:
    raise SystemExit("STANDARD_CHAIN_ROOT_MISSING")
PY

for positive_case in \
  role-catalog \
  machine-gate \
  human-review-gate \
  user-decision-gate \
  file-evidence \
  fixture-proof \
  fresh-proving; do
  python3 "$CHECKER" "$FIXTURES/$positive_case.json"
done

expect_fail "missing gate fields" "GATE_FIELDS_REQUIRED" \
  python3 "$CHECKER" "$FIXTURES/missing-gate-fields.json"
expect_fail "missing user authority" "USER_AUTHORITY_REQUIRED" \
  python3 "$CHECKER" "$FIXTURES/missing-user-authority.json"
expect_fail "missing evidence locator" "EVIDENCE_LOCATOR_REQUIRED" \
  python3 "$CHECKER" "$FIXTURES/missing-evidence-locator.json"
expect_fail "missing fixture command" "FIXTURE_COMMAND_REQUIRED" \
  python3 "$CHECKER" "$FIXTURES/missing-fixture-command.json"
expect_fail "missing proof command" "PROOF_COMMAND_REQUIRED" \
  python3 "$CHECKER" "$FIXTURES/missing-proof-command.json"
expect_fail "invalid file evidence path" "INVALID_FILE_EVIDENCE" \
  python3 "$CHECKER" "$FIXTURES/invalid-file-evidence-path.json"
expect_fail "invalid fixture path" "INVALID_FIXTURE_PROOF" \
  python3 "$CHECKER" "$FIXTURES/invalid-fixture-path.json"
expect_fail "invalid fixture command" "INVALID_FIXTURE_PROOF" \
  python3 "$CHECKER" "$FIXTURES/invalid-fixture-command.json"
expect_fail "invalid fresh proof command" "INVALID_PROOF_COMMAND" \
  python3 "$CHECKER" "$FIXTURES/invalid-fresh-proof-command.json"
expect_fail "invalid machine gate types" "GATE_FIELDS_REQUIRED" \
  python3 "$CHECKER" "$FIXTURES/invalid-machine-gate-types.json"
expect_fail "invalid human gate types" "GATE_FIELDS_REQUIRED" \
  python3 "$CHECKER" "$FIXTURES/invalid-human-gate-types.json"
expect_fail "invalid user decision shape" "USER_DECISION_SHAPE_INVALID" \
  python3 "$CHECKER" "$FIXTURES/invalid-user-decision-shape.json"
expect_fail "proof type mismatch" "PROOF_TYPE_MISMATCH" \
  python3 "$CHECKER" "$FIXTURES/proof-type-mismatch.json"
expect_fail "channel mismatch" "CHANNEL_MISMATCH" \
  python3 "$CHECKER" "$FIXTURES/channel-mismatch.json"
expect_fail "actor mismatch" "ACTOR_MISMATCH" \
  python3 "$CHECKER" "$FIXTURES/actor-mismatch.json"
expect_fail "digest mismatch" "DIGEST_MISMATCH" \
  python3 "$CHECKER" "$FIXTURES/digest-mismatch.json"
expect_fail "stale baseline" "BASELINE_DRIFT" \
  python3 "$CHECKER" "$FIXTURES/stale-baseline.json"

printf '[PASS] skill-harness standard-chain integration\n'
