#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/tools/community/validate_episode_package.py"
FIXTURE_ROOT="$ROOT/tests/fixtures/standard-chain-harness"
VALID="$FIXTURE_ROOT/developer-episode-package.valid.json"
MISSING_EVIDENCE="$FIXTURE_ROOT/developer-episode-package.missing-verification-evidence.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$SCRIPT" ] || fail "missing episode package validator"
[ -f "$ROOT/contracts/episode-package.schema.json" ] || fail "missing episode package schema"
[ -f "$VALID" ] || fail "missing valid episode package fixture"
[ -f "$MISSING_EVIDENCE" ] || fail "missing negative episode package fixture"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/episode-package.XXXXXX")"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

python3 "$SCRIPT" --package "$VALID" >"$TMP_DIR/valid.out" \
  || fail "valid developer episode package should pass"
jq -e '.status == "PASS" and .episode_id == "developer:T1:attempt-1"' "$TMP_DIR/valid.out" >/dev/null \
  || fail "valid episode package output should identify the package"

if python3 "$SCRIPT" --package "$MISSING_EVIDENCE" >"$TMP_DIR/missing-evidence.out" 2>/dev/null; then
  cat "$TMP_DIR/missing-evidence.out" >&2
  fail "package without verification.evidence_refs should fail"
fi
jq -e '.status == "FAIL" and (.errors[] | contains("verification.evidence_refs"))' "$TMP_DIR/missing-evidence.out" >/dev/null \
  || fail "missing verification evidence failure should identify verification.evidence_refs"

jq '.verification.default_fail = false' "$VALID" >"$TMP_DIR/default-fail-false.json"
if python3 "$SCRIPT" --package "$TMP_DIR/default-fail-false.json" >"$TMP_DIR/default-fail-false.out" 2>/dev/null; then
  cat "$TMP_DIR/default-fail-false.out" >&2
  fail "package with verification.default_fail=false should fail"
fi
jq -e '.status == "FAIL" and (.errors[] | contains("verification.default_fail"))' "$TMP_DIR/default-fail-false.out" >/dev/null \
  || fail "default-fail failure should identify verification.default_fail"

jq 'del(.verification.proving_commands[0].current_output_ref)' "$VALID" >"$TMP_DIR/missing-command-output.json"
if python3 "$SCRIPT" --package "$TMP_DIR/missing-command-output.json" >"$TMP_DIR/missing-command-output.out" 2>/dev/null; then
  cat "$TMP_DIR/missing-command-output.out" >&2
  fail "package proving command without current_output_ref should fail"
fi
jq -e '.status == "FAIL" and (.errors[] | contains("current_output_ref"))' "$TMP_DIR/missing-command-output.out" >/dev/null \
  || fail "missing current output failure should identify current_output_ref"

printf '[PASS] standard-chain episode package\n'
