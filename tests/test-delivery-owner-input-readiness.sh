#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$ROOT/shared/skills/delivery-owner/scripts/input_readiness_check.sh"
PY_VALIDATOR="$ROOT/tools/community/validate_delivery_owner_input_readiness.py"
FIXTURE="$ROOT/tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$VALIDATOR" || fail "missing input readiness wrapper: $VALIDATOR"
bash -n "$VALIDATOR" || fail "input readiness wrapper must pass bash syntax check"
python3 -m py_compile "$PY_VALIDATOR" || fail "python input readiness validator must compile"

expect_pass() {
  local phase_dir="$1"
  "$VALIDATOR" --phase-dir "$phase_dir" >/tmp/do-input-readiness-pass.out 2>&1 \
    || { cat /tmp/do-input-readiness-pass.out >&2; fail "expected input readiness to pass: $phase_dir"; }
  rg -n "delivery-owner input readiness passed" /tmp/do-input-readiness-pass.out >/dev/null \
    || fail "pass output missing readiness confirmation"
}

expect_fail_with() {
  local phase_dir="$1"
  local pattern="$2"
  if "$VALIDATOR" --phase-dir "$phase_dir" >/tmp/do-input-readiness-fail.out 2>&1; then
    cat /tmp/do-input-readiness-fail.out >&2
    fail "expected input readiness to fail: $phase_dir"
  fi
  rg -n "$pattern" /tmp/do-input-readiness-fail.out >/dev/null \
    || { cat /tmp/do-input-readiness-fail.out >&2; fail "failure output missing pattern: $pattern"; }
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/do-input-readiness.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS_ROOT="$TMP_ROOT/pass/sample-feature"
mkdir -p "$(dirname "$PASS_ROOT")"
cp -R "$FIXTURE" "$PASS_ROOT"
expect_pass "$PASS_ROOT/phase-1"

NO_CONFIRM_ROOT="$TMP_ROOT/no-confirm/sample-feature"
mkdir -p "$(dirname "$NO_CONFIRM_ROOT")"
cp -R "$FIXTURE" "$NO_CONFIRM_ROOT"
jq 'del(.user_confirmation)' "$NO_CONFIRM_ROOT/phase-1/plan.json" > "$NO_CONFIRM_ROOT/phase-1/plan.tmp.json"
mv "$NO_CONFIRM_ROOT/phase-1/plan.tmp.json" "$NO_CONFIRM_ROOT/phase-1/plan.json"
expect_fail_with "$NO_CONFIRM_ROOT/phase-1" "plan.user_confirmation"

BLOCKING_GAP_ROOT="$TMP_ROOT/blocking-gap/sample-feature"
mkdir -p "$(dirname "$BLOCKING_GAP_ROOT")"
cp -R "$FIXTURE" "$BLOCKING_GAP_ROOT"
jq '.design_gap_report.status = "BLOCKED" | .design_gap_report.gaps = [{"gap_id":"DG-1","blocking":true,"owner":"design"}]' \
  "$BLOCKING_GAP_ROOT/phase-1/unit-1/test-cases.json" > "$BLOCKING_GAP_ROOT/phase-1/unit-1/test-cases.tmp.json"
mv "$BLOCKING_GAP_ROOT/phase-1/unit-1/test-cases.tmp.json" "$BLOCKING_GAP_ROOT/phase-1/unit-1/test-cases.json"
expect_fail_with "$BLOCKING_GAP_ROOT/phase-1" "blocking design gap"

MISSING_UNIT_ROOT="$TMP_ROOT/missing-unit/sample-feature"
mkdir -p "$(dirname "$MISSING_UNIT_ROOT")"
cp -R "$FIXTURE" "$MISSING_UNIT_ROOT"
rm -f "$MISSING_UNIT_ROOT/phase-1/units/UNIT-1.json"
expect_fail_with "$MISSING_UNIT_ROOT/phase-1" "units/UNIT-1.json"

MISSING_UNIT_REGISTRY_ROOT="$TMP_ROOT/missing-unit-registry/sample-feature"
mkdir -p "$(dirname "$MISSING_UNIT_REGISTRY_ROOT")"
cp -R "$FIXTURE" "$MISSING_UNIT_REGISTRY_ROOT"
jq '(.revisions[].entries) |= map(select(.artifact_type != "unit-definition"))' \
  "$MISSING_UNIT_REGISTRY_ROOT/phase-1/artifact-registry.json" > "$MISSING_UNIT_REGISTRY_ROOT/phase-1/artifact-registry.tmp.json"
mv "$MISSING_UNIT_REGISTRY_ROOT/phase-1/artifact-registry.tmp.json" "$MISSING_UNIT_REGISTRY_ROOT/phase-1/artifact-registry.json"
expect_fail_with "$MISSING_UNIT_REGISTRY_ROOT/phase-1" "unit-definition"

MISSING_SECOND_UNIT_REGISTRY_ROOT="$TMP_ROOT/missing-second-unit-registry/sample-feature"
mkdir -p "$(dirname "$MISSING_SECOND_UNIT_REGISTRY_ROOT")"
cp -R "$FIXTURE" "$MISSING_SECOND_UNIT_REGISTRY_ROOT"
jq '.unit_index += ["UNIT-2"]' \
  "$MISSING_SECOND_UNIT_REGISTRY_ROOT/phase-1/phase-prd.json" > "$MISSING_SECOND_UNIT_REGISTRY_ROOT/phase-1/phase-prd.tmp.json"
mv "$MISSING_SECOND_UNIT_REGISTRY_ROOT/phase-1/phase-prd.tmp.json" "$MISSING_SECOND_UNIT_REGISTRY_ROOT/phase-1/phase-prd.json"
jq '.unit_id = "UNIT-2" | .artifact_id = "sample-feature.phase-1.unit-2"' \
  "$MISSING_SECOND_UNIT_REGISTRY_ROOT/phase-1/units/UNIT-1.json" > "$MISSING_SECOND_UNIT_REGISTRY_ROOT/phase-1/units/UNIT-2.json"
mkdir -p "$MISSING_SECOND_UNIT_REGISTRY_ROOT/phase-1/unit-2"
jq '.artifact_id = "sample-feature.phase-1.unit-2.test-cases"
    | (.cross_unit_obligations[]? |= (.participant_unit_refs = ["UNIT-2.json#unit_id"] | .local_unit_ref = "UNIT-2.json#unit_id"))' \
  "$MISSING_SECOND_UNIT_REGISTRY_ROOT/phase-1/unit-1/test-cases.json" > "$MISSING_SECOND_UNIT_REGISTRY_ROOT/phase-1/unit-2/test-cases.json"
expect_fail_with "$MISSING_SECOND_UNIT_REGISTRY_ROOT/phase-1" "UNIT-2"

REGISTRY_PAYLOAD_DRIFT_ROOT="$TMP_ROOT/registry-payload-drift/sample-feature"
mkdir -p "$(dirname "$REGISTRY_PAYLOAD_DRIFT_ROOT")"
cp -R "$FIXTURE" "$REGISTRY_PAYLOAD_DRIFT_ROOT"
jq '.artifact_id = "sample-feature.phase-1.other-design"' \
  "$REGISTRY_PAYLOAD_DRIFT_ROOT/phase-1/design.json" > "$REGISTRY_PAYLOAD_DRIFT_ROOT/phase-1/design.tmp.json"
mv "$REGISTRY_PAYLOAD_DRIFT_ROOT/phase-1/design.tmp.json" "$REGISTRY_PAYLOAD_DRIFT_ROOT/phase-1/design.json"
expect_fail_with "$REGISTRY_PAYLOAD_DRIFT_ROOT/phase-1" "artifact-registry payload drift"

PATH_ESCAPE_ROOT="$TMP_ROOT/path-escape/sample-feature"
mkdir -p "$(dirname "$PATH_ESCAPE_ROOT")"
cp -R "$FIXTURE" "$PATH_ESCAPE_ROOT"
cp "$PATH_ESCAPE_ROOT/phase-1/design.json" "$(dirname "$PATH_ESCAPE_ROOT")/outside-design.json"
jq '(.revisions[].entries[] | select(.artifact_type == "design")).artifact_path = "../../outside-design.json"' \
  "$PATH_ESCAPE_ROOT/phase-1/artifact-registry.json" > "$PATH_ESCAPE_ROOT/phase-1/artifact-registry.tmp.json"
mv "$PATH_ESCAPE_ROOT/phase-1/artifact-registry.tmp.json" "$PATH_ESCAPE_ROOT/phase-1/artifact-registry.json"
expect_fail_with "$PATH_ESCAPE_ROOT/phase-1" "artifact-registry active path escapes"

printf '[PASS] delivery-owner input readiness\n'
