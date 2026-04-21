#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/shared/skills/skill-harness/SKILL.md"
AUDIT="$ROOT/shared/skills/skill-harness/references/audit-method.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

grep -Fq 'audit_proof_type' "$SKILL" || fail "SKILL missing audit_proof_type"
grep -Fq 'overall_verdict' "$SKILL" || fail "SKILL missing overall_verdict"
grep -Fq 'dimension_result' "$SKILL" || fail "SKILL missing dimension_result"
grep -Fq 'dry_run_verdict' "$SKILL" || fail "SKILL missing dry_run_verdict"
grep -Fq 'legacy_baseline_label' "$SKILL" || fail "SKILL missing legacy_baseline_label boundary"

grep -Fq 'final_dimension_enum' "$AUDIT" || fail "audit method missing final dimension enum"
grep -Fq 'overall_verdict' "$AUDIT" || fail "audit method missing overall_verdict"
grep -Fq 'dimension_result' "$AUDIT" || fail "audit method missing dimension_result"
grep -Fq 'finding_severity' "$AUDIT" || fail "audit method missing finding_severity"
grep -Fq 'dry_run_verdict' "$AUDIT" || fail "audit method missing dry_run_verdict"
grep -Fq 'legacy_baseline_label' "$AUDIT" || fail "audit method missing legacy_baseline_label boundary"
grep -Fq 'audit_proof_type' "$AUDIT" || fail "audit method missing audit_proof_type"
grep -Fq 'PASS / FAIL / COMMENT' "$AUDIT" || fail "audit method missing overall verdict enum"
grep -Fq 'Correctness PASS / Practice FAIL' "$AUDIT" || fail "audit method missing legacy mapping note"

if grep -Eq '(^|[^[:alnum:]_])proof_type([^[:alnum:]_]|$)' "$SKILL"; then
  fail "SKILL contains standalone proof_type"
fi

printf '[PASS] skill-harness responsibility contract\n'
