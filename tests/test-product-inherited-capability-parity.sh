#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
DIRECTOR_PROBLEM_GUIDE="$ROOT/shared/skills/product-director/references/problem-clarification.md"
DIRECTOR_SUCCESS_GUIDE="$ROOT/shared/skills/product-director/references/success-investment-boundary.md"
DIRECTOR_SCOPE_GUIDE="$ROOT/shared/skills/product-director/references/scope-constraints.md"
MANAGER_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
MANAGER_REVIEW_ORCHESTRATION="$ROOT/shared/skills/product-manager/references/review-orchestration.md"
MANAGER_REVIEW_TEMPLATE="$ROOT/shared/skills/product-manager/projections/product-manager-review-template.md"
MANAGER_EVALS="$ROOT/shared/skills/product-manager/evals/evals.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Eq "$pattern" "$file" || fail "missing pattern in $file: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if grep -Eq "$pattern" "$file"; then
    fail "unexpected pattern in $file: $pattern"
  fi
}

assert_terms_present() {
  local file="$1"
  local label="$2"
  shift 2
  python3 - "$file" "$label" "$@" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
label = sys.argv[2]
terms = sys.argv[3:]
text = path.read_text(encoding="utf-8")
missing = [term for term in terms if term not in text]
if missing:
    raise SystemExit(f"{path}: missing {label} terms: {', '.join(missing)}")
PY
}

test -f "$DIRECTOR_SKILL" || fail "missing director skill: $DIRECTOR_SKILL"
test -f "$DIRECTOR_PROBLEM_GUIDE" || fail "missing director problem guide: $DIRECTOR_PROBLEM_GUIDE"
test -f "$DIRECTOR_SUCCESS_GUIDE" || fail "missing director success/investment-boundary guide: $DIRECTOR_SUCCESS_GUIDE"
test -f "$DIRECTOR_SCOPE_GUIDE" || fail "missing director scope/constraints guide: $DIRECTOR_SCOPE_GUIDE"
test -f "$MANAGER_SKILL" || fail "missing manager skill: $MANAGER_SKILL"
test -f "$MANAGER_REVIEW_ORCHESTRATION" || fail "missing manager review orchestration: $MANAGER_REVIEW_ORCHESTRATION"
test -f "$MANAGER_REVIEW_TEMPLATE" || fail "missing manager review template: $MANAGER_REVIEW_TEMPLATE"

# Validated product capabilities must survive the split through explicit
# contracts, not runtime references to retired skills.
assert_present 'references/success-investment-boundary\.md' "$DIRECTOR_SKILL"
assert_present 'references/scope-constraints\.md' "$DIRECTOR_SKILL"
assert_absent 'references/conversation-guide\.md' "$DIRECTOR_SKILL"
assert_absent 'references/product-thinking-contract\.md' "$DIRECTOR_SKILL"

assert_present 'references/review-orchestration\.md' "$MANAGER_SKILL"
assert_absent 'references/review-orchestration\.md#|references/[^`[:space:]]+-contract\.md|Contract v1' "$MANAGER_SKILL"

assert_present '^allowed-tools: .*TeamCreate' "$MANAGER_SKILL"
assert_present '^allowed-tools: .*SendMessage' "$MANAGER_SKILL"
assert_present '^allowed-tools: .*TeamDelete' "$MANAGER_SKILL"
assert_present '"id": "canonical-review-required"' "$MANAGER_EVALS"
assert_present 'PM owner 自检通过后' "$MANAGER_EVALS"
assert_present 'reviewed_bundle_digest' "$MANAGER_SKILL"
assert_present 'control_action=CONFIRMATION' "$MANAGER_REVIEW_ORCHESTRATION"
assert_terms_present "$MANAGER_REVIEW_ORCHESTRATION" "fail-view rerun" "FAIL" "重新提交" "视角" "评审"
assert_terms_present "$MANAGER_REVIEW_ORCHESTRATION" "projection source boundary" "canonical JSON" "人类投影视图" "渲染"

assert_present 'PR-\* / AR-\* / TR-\* / HIS-\*' "$MANAGER_REVIEW_TEMPLATE"
assert_present 'Review Round' "$MANAGER_REVIEW_TEMPLATE"
assert_present 'Issue Count.*PR-\* / AR-\* / TR-\*' "$MANAGER_REVIEW_TEMPLATE"
assert_present 'HIS-\*' "$MANAGER_REVIEW_TEMPLATE"

# Inheritance must not reintroduce the removed runtime skill or shared directory.
assert_absent 'product-shared' "$DIRECTOR_SKILL"
assert_absent 'product-shared' "$MANAGER_SKILL"
assert_absent '/product ' "$DIRECTOR_SKILL"
assert_absent '/product ' "$MANAGER_SKILL"

echo "[PASS] product inherited capability parity"
