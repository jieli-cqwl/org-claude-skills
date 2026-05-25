#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/tools/community/validate_episode_package.py"
FIXTURE_ROOT="$ROOT/tests/fixtures/standard-chain-harness"
VALID="$FIXTURE_ROOT/developer-episode-package.valid.json"
MISSING_EVIDENCE="$FIXTURE_ROOT/developer-episode-package.missing-verification-evidence.json"
GOLDEN_DEVELOPER_REPORT="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$SCRIPT" ] || fail "missing episode package validator"
[ -f "$ROOT/contracts/episode-package.schema.json" ] || fail "missing episode package schema"
[ -f "$VALID" ] || fail "missing valid episode package fixture"
[ -f "$MISSING_EVIDENCE" ] || fail "missing negative episode package fixture"
[ -f "$GOLDEN_DEVELOPER_REPORT" ] || fail "missing golden developer report fixture"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/episode-package.XXXXXX")"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

assert_indexes_golden_fresh_proof() {
  local package_file="$1"
  jq -e -n \
    --slurpfile package "$package_file" \
    --slurpfile report "$GOLDEN_DEVELOPER_REPORT" '
      def normalized_command:
        {
          command: .command,
          current_output_ref: .current_output_ref,
          result: (.result | ascii_downcase)
        };

      ($package[0]) as $package |
      ($report[0]) as $report |
      ($package.state_after_refs | index($report.reviewable_anchor) != null)
      and ($package.verification.evidence_refs == $report.fresh_proof.current_evidence_refs)
      and (
        [$package.verification.proving_commands[] | normalized_command]
        == [$report.fresh_proof.proving_commands[] | normalized_command]
      )
    ' >/dev/null
}

python3 "$SCRIPT" --package "$VALID" >"$TMP_DIR/valid.out" \
  || fail "valid developer episode package should pass"
jq -e '.status == "PASS" and .episode_id == "developer:T1:attempt-1"' "$TMP_DIR/valid.out" >/dev/null \
  || fail "valid episode package output should identify the package"
assert_indexes_golden_fresh_proof "$VALID" \
  || fail "valid episode package should index the golden developer-report fresh_proof without inventing verification refs"

jq '.verification.evidence_refs += ["artifact://evidence/invented.log@ev-x#fake"]' "$VALID" >"$TMP_DIR/invented-evidence-ref.json"
if assert_indexes_golden_fresh_proof "$TMP_DIR/invented-evidence-ref.json"; then
  fail "golden fresh_proof binding should reject invented verification evidence refs"
fi

jq '.verification.proving_commands += [{
  "command": "bash tests/fake.sh",
  "current_output_ref": "artifact://evidence/invented.log@ev-x#fake",
  "result": "pass"
}]' "$VALID" >"$TMP_DIR/invented-proving-command.json"
if assert_indexes_golden_fresh_proof "$TMP_DIR/invented-proving-command.json"; then
  fail "golden fresh_proof binding should reject invented proving commands"
fi

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
