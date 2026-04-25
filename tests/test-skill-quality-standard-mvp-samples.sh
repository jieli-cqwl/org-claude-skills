#!/usr/bin/env bash
# File role: prove Phase 1 sample findings are reviewable and map to MVP quality concerns.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAMPLES="$ROOT/docs/archive/skill-quality-standard-mvp/2026-04-24-phase-1-design/sample-findings.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  grep -Fq "$needle" "$SAMPLES" || fail "sample findings missing: $needle"
}

assert_absent_authority() {
  local needle="$1"
  if grep -F "Authority:" "$SAMPLES" | grep -Fq "$needle"; then
    fail "sample findings use forbidden authority: $needle"
  fi
}

test -f "$SAMPLES" || fail "missing sample findings"
assert_present '## delivery-owner Findings'
assert_present '## skill-harness Findings'

for field in 'Verdict:' 'MVP Quality Concern:' 'Evidence:' 'Impact:' 'Recommendation:' 'Dimension Label Only:' 'Authority:'; do
  assert_present "$field"
done

for concern in \
  'Role clarity' \
  'Evidence-backed claims' \
  'Harness governance' \
  'D9 readiness boundary'; do
  assert_present "MVP Quality Concern: $concern"
done

assert_absent_authority 'Correctness PASS / Practice FAIL'
assert_absent_authority '250/200/150/100'
assert_absent_authority 'D9 readiness metadata'
assert_absent_authority 'skill-harness dimension'

printf '[PASS] skill quality standard MVP samples\n'
