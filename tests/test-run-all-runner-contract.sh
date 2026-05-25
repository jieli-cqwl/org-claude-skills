#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$ROOT/tests/run-all.sh"
PLAN_INVENTORY="$ROOT/docs/reports/test-signal-inventory.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local needle="$1"
  local haystack="$2"
  local label="$3"

  if ! grep -Fq -- "$needle" <<<"$haystack"; then
    fail "$label missing: $needle"
  fi
}

assert_not_contains() {
  local needle="$1"
  local haystack="$2"
  local label="$3"

  if grep -Fq -- "$needle" <<<"$haystack"; then
    fail "$label should not include: $needle"
  fi
}

plan_count() {
  local key="$1"
  local plan="$2"

  grep "^${key}=" <<<"$plan" | cut -d= -f2
}

deleted_tests_from_inventory() {
  python3 - "$PLAN_INVENTORY" <<'PY'
import re
import sys
from pathlib import Path

for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    if "| Delete |" not in line:
        continue
    match = re.search(r"`(tests/[^`]+)`", line)
    if match:
        print(match.group(1))
PY
}

help_output="$(bash "$RUNNER" --help)"
assert_contains "--quick" "$help_output" "help output"
assert_contains "--full" "$help_output" "help output"
assert_contains "--release" "$help_output" "help output"
assert_contains "--profile" "$help_output" "help output"
assert_contains "--list" "$help_output" "help output"

full_plan="$(bash "$RUNNER" --full --list)"
quick_plan="$(bash "$RUNNER" --quick --list)"
release_plan="$(bash "$RUNNER" --release --list)"
runner_source="$(<"$RUNNER")"

assert_contains "shared/skills/delivery-owner/scripts/completion_check.sh" "$runner_source" "run-all shell syntax coverage"
assert_contains "shared/skills/delivery-owner/scripts/intake_preflight_check.sh" "$runner_source" "run-all shell syntax coverage"
assert_contains "shared/skills/delivery-owner/scripts/task_packet_check.sh" "$runner_source" "run-all shell syntax coverage"
assert_not_contains "shared/skills/delivery-owner/scripts/control_decision_check.sh" "$runner_source" "run-all shell syntax coverage"

assert_contains "mode=full" "$full_plan" "full plan"
assert_contains "mode=quick" "$quick_plan" "quick plan"
assert_contains "mode=release" "$release_plan" "release plan"
assert_contains "steps=" "$full_plan" "full plan"
assert_contains "steps=" "$quick_plan" "quick plan"
assert_contains "steps=" "$release_plan" "release plan"

full_steps="$(plan_count steps "$full_plan")"
quick_steps="$(plan_count steps "$quick_plan")"
release_steps="$(plan_count steps "$release_plan")"
quick_excluded_count="$(plan_count full_only_excluded "$quick_plan")"

[ "$full_steps" -gt "$quick_steps" ] || fail "full plan should have more steps than quick plan"
[ "$release_steps" -eq "$full_steps" ] || fail "release plan should match full plan step count"
[ "$quick_excluded_count" -ge 9 ] || fail "quick excluded count should not shrink below the post-cleanup floor"

assert_contains "bash $ROOT/tests/test-install-core.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-install-runtime-smoke.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-install-safety.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-install-runtime.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-install-migration.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-standard-chain-readiness-gate.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-developer-effectiveness-review-evals.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-developer-runtime-proof-contract.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-developer-runtime-failure-matrix.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-standard-chain-runtime-layering-contract.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-standard-chain-episode-package.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-standard-chain-harness-capability-eval.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-skill-quality-standard.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-shared-skill-package-quality-baseline.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-skill-body-quality-static-audit.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-skill-quality-detection-fixtures.sh" "$full_plan" "full plan"
assert_not_contains "test-skill-harness" "$full_plan" "full plan"
assert_not_contains "test-install-smoke.sh" "$full_plan" "full plan"
assert_not_contains "test-install-systematic.sh" "$full_plan" "full plan"
assert_not_contains "test-install-runtime-audit.sh" "$full_plan" "full plan"

assert_contains "bash $ROOT/tools/validate-contracts.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-entry-doc-source-contract.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-developer-effectiveness-review-evals.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-developer-runtime-proof-contract.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-developer-runtime-failure-matrix.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-standard-chain-runtime-layering-contract.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-standard-chain-episode-package.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-standard-chain-harness-capability-eval.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-test-assertion-boundary-contract.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-skill-quality-standard.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-shared-skill-package-quality-baseline.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-skill-body-quality-static-audit.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-skill-quality-detection-fixtures.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-review-fix-redesign-contract.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-product-role-split-contract.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-product-stability-guidance-contract.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-stage2-product-director-handoff.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-stage2-product-director-handoff.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-stage2-confirmed-brief-package.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-stage2-confirmed-brief-package.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-stage2-product-manager-package.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-stage2-product-manager-package.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-stage2-design-package.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-stage2-design-package.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-stage2-test-design-package.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-stage2-test-design-package.sh" "$full_plan" "full plan"
assert_contains "bash $ROOT/tests/test-stage2-tech-lead-package.sh" "$quick_plan" "quick plan"
assert_contains "bash $ROOT/tests/test-stage2-tech-lead-package.sh" "$full_plan" "full plan"

for release_heavy_test in \
  "tests/test-install-core.sh" \
  "tests/test-install-runtime-smoke.sh" \
  "tests/test-install-safety.sh" \
  "tests/test-install-runtime.sh" \
  "tests/test-install-migration.sh" \
  "tests/test-install-retired-skill-cleanup.sh" \
  "tests/test-runtime-integrity.sh" \
  "tests/test-platform-runtime-noise.sh" \
  "tests/test-codex-skill-adapter.sh"
do
  assert_contains "excluded: $release_heavy_test" "$quick_plan" "quick plan"
  assert_not_contains "bash $ROOT/$release_heavy_test" "$quick_plan" "quick plan"
  assert_contains "bash $ROOT/$release_heavy_test" "$full_plan" "full plan"
  assert_contains "bash $ROOT/$release_heavy_test" "$release_plan" "release plan"
done

for moved_test in \
  "tests/test-product-eval-contract.sh" \
  "tests/test-product-context-signal-quality.sh" \
  "tests/test-developer-process-compliance-contract.sh" \
  "tests/test-standard-chain-skill-structure.sh" \
  "tests/test-release-metadata.sh"
do
  assert_contains "excluded: $moved_test" "$quick_plan" "quick plan"
  assert_not_contains "bash $ROOT/$moved_test" "$quick_plan" "quick plan"
  assert_contains "bash $ROOT/$moved_test" "$full_plan" "full plan"
  assert_contains "bash $ROOT/$moved_test" "$release_plan" "release plan"
done

while IFS= read -r deleted_test; do
  [ -n "$deleted_test" ] || continue
  assert_not_contains "$deleted_test" "$quick_plan" "quick plan"
  assert_not_contains "$deleted_test" "$full_plan" "full plan"
  assert_not_contains "$deleted_test" "$release_plan" "release plan"
done < <(deleted_tests_from_inventory)

assert_not_contains "test-skill-harness" "$quick_plan" "quick plan"
assert_not_contains "test-install-smoke.sh" "$quick_plan" "quick plan"
assert_not_contains "test-install-systematic.sh" "$quick_plan" "quick plan"
assert_not_contains "test-install-runtime-audit.sh" "$quick_plan" "quick plan"

if bash "$RUNNER" --does-not-exist >/tmp/org_run_all_bad_option.out 2>&1; then
  fail "unknown option should fail"
fi
grep -Fq "unknown option" /tmp/org_run_all_bad_option.out || fail "unknown option message missing"

echo "run-all runner contract ok"
