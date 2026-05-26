#!/usr/bin/env bash
# File role: prove skill-refiner SOP keeps retired dependencies and wording out.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REFINER="$ROOT/shared/skills/skill-refiner/SKILL.md"
VALIDATOR="$ROOT/shared/skills/skill-refiner/scripts/validate_noisy_implementation_result.sh"
EXAMPLE="$ROOT/shared/skills/skill-refiner/references/examples/developer-optimization-case.md"
OLD_EXAMPLE="$ROOT/shared/skills/skill-refiner/references/developer-optimization-case.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_absent() {
  local needle="$1"
  local file="$2"
  if grep -Fq "$needle" "$file"; then
    fail "forbidden content in ${file#"$ROOT"/}: $needle"
  fi
}

test -f "$REFINER" || fail "missing skill-refiner SKILL.md"
test -f "$VALIDATOR" || fail "missing noisy fixture validator"
test -f "$EXAMPLE" || fail "missing developer success example"
test ! -e "$OLD_EXAMPLE" || fail "old developer optimization case path must be removed"

assert_absent '环节队列循环' "$EXAMPLE"

retired_skill_name="$(printf '%s-%s' skill harness)"
retired_checker_name="$(printf 'check_%s_%s' skill harness)"
retired_eval_wording="$(printf '%s-%s' harness only)"
retired_typo="$(printf 'her%s' ness)"
retired_test_slug="$(printf 'no-%s-dependency' harness)"
retired_pass_phrase="$(printf 'no %s dependency' harness)"

assert_absent "$retired_skill_name" "$REFINER"
assert_absent 'check_skill_package_quality.py' "$REFINER"
assert_absent 'check_skill_body_quality.py' "$REFINER"
assert_absent "$retired_checker_name" "$REFINER"
assert_absent 'references/reviewers/' "$REFINER"
assert_absent 'discover_refinement_candidates.py' "$REFINER"

assert_absent "$retired_skill_name" "$VALIDATOR"
assert_absent 'check_skill_package_quality.py' "$VALIDATOR"
assert_absent 'check_skill_body_quality.py' "$VALIDATOR"
assert_absent "$retired_checker_name" "$VALIDATOR"

scan_roots=(
  "$ROOT/docs/reports"
  "$ROOT/shared/skills/skill-refiner/evals"
  "$ROOT/shared/skills/tech-lead/evals"
  "$ROOT/tests"
)

for retired_wording in \
  "$retired_skill_name" \
  "$retired_checker_name" \
  "$retired_eval_wording" \
  "$retired_typo" \
  "$retired_test_slug" \
  "$retired_pass_phrase"; do
  if rg -n -F "$retired_wording" "${scan_roots[@]}" >/dev/null; then
    rg -n -F "$retired_wording" "${scan_roots[@]}" >&2
    fail "retired wording must stay out of reports, eval evidence and tests"
  fi

  if (
    cd "$ROOT"
    rg --files docs/reports shared/skills/skill-refiner/evals shared/skills/tech-lead/evals tests \
      | grep -F "$retired_wording" >/dev/null
  ); then
    (
      cd "$ROOT"
      rg --files docs/reports shared/skills/skill-refiner/evals shared/skills/tech-lead/evals tests \
        | grep -F "$retired_wording"
    ) >&2
    fail "retired wording must stay out of file paths"
  fi
done

printf '[PASS] skill-refiner legacy dependency cleanup\n'
