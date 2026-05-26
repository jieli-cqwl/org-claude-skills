#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

failures=0

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  failures=$((failures + 1))
}

assert_present() {
  local pattern="$1"
  local file="$2"
  local scope="${3:-}"
  if ! rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "${scope:+$scope: }missing pattern in $file: $pattern"
  fi
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  local scope="${3:-}"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "${scope:+$scope: }unexpected pattern in $file: $pattern"
  fi
}

extract_section() {
  local file="$1"
  local heading="$2"
  awk -v heading="$heading" '
    $0 == heading { in_section=1; print; next }
    in_section && /^```/ { in_code = !in_code; print; next }
    in_section && !in_code && /^## / && $0 != heading { exit }
    in_section { print }
  ' "$file"
}

assert_section_present() {
  local file="$1"
  local heading="$2"
  local pattern="$3"
  local scope="$4"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/product-context-signal.XXXXXX")"
  extract_section "$file" "$heading" > "$tmp"
  assert_present "$pattern" "$tmp" "$scope"
  rm -f "$tmp"
}

assert_section_absent() {
  local file="$1"
  local heading="$2"
  local pattern="$3"
  local scope="$4"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/product-context-signal.XXXXXX")"
  extract_section "$file" "$heading" > "$tmp"
  assert_absent "$pattern" "$tmp" "$scope"
  rm -f "$tmp"
}

assert_any_present() {
  local file="$1"
  local scope="$2"
  shift 2
  local pattern
  local hit=1
  for pattern in "$@"; do
    if rg -n "$pattern" "$file" >/dev/null 2>&1; then
      hit=0
      break
    fi
  done
  if [ "$hit" -ne 0 ]; then
    fail "${scope:+$scope: }missing any of patterns in $file: $*"
  fi
}

assert_audit_round_count() {
  local file="$1"
  local expected="$2"
  local actual

  if [ ! -f "$file" ]; then
    fail "missing audit loop record: $file"
    return
  fi
  actual=$(rg -n '^\| R[0-9]{2} \|' "$file" | wc -l | tr -d ' ')
  if [ "$actual" -lt "$expected" ]; then
    fail "expected at least $expected audit rounds in $file, got $actual"
  fi
}

assert_manager_review_owner_boundary() {
  local file="$1"
  python3 - "$file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
requirements = {
    "handoff_gate": ["handoff", "阻断"],
    "review_step": ["Agent review", "评审"],
    "delivery_confirmation": ["Delivery", "交付确认"],
}
missing = [name for name, terms in requirements.items() if not all(term in text for term in terms)]
if missing:
    raise SystemExit(f"{path}: missing manager review owner boundary: {', '.join(missing)}")
PY
}

assert_manager_warn_carryover_contract() {
  local file="$1"
  python3 - "$file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
requirements = {
    "warn": ["WARN"],
    "review_conclusion": ["review_conclusion"],
    "issue_ledger": ["issue_ledger"],
}
missing = [name for name, terms in requirements.items() if not all(term in text for term in terms)]
if missing:
    raise SystemExit(f"{path}: missing manager WARN carryover contract: {', '.join(missing)}")
PY
}

assert_manager_fail_rerun_contract() {
  local file="$1"
  python3 - "$file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
requirements = {
    "fail_view_rerun": ["FAIL", "重新提交", "视角", "评审"],
}
missing = [name for name, terms in requirements.items() if not all(term in text for term in terms)]
if missing:
    raise SystemExit(f"{path}: missing manager FAIL rerun contract: {', '.join(missing)}")
PY
}

DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
MANAGER_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
DIRECTOR_PROBLEM_GUIDE="$ROOT/shared/skills/product-director/references/problem-clarification.md"
DIRECTOR_SUCCESS_GUIDE="$ROOT/shared/skills/product-director/references/success-investment-boundary.md"
DIRECTOR_BUSINESS_GUIDE="$ROOT/shared/skills/product-director/references/business-semantics.md"
DIRECTOR_SCOPE_GUIDE="$ROOT/shared/skills/product-director/references/scope-constraints.md"
DIRECTOR_RISKS_GUIDE="$ROOT/shared/skills/product-director/references/risks-unknowns.md"
DIRECTOR_PHASE_GUIDE="$ROOT/shared/skills/product-director/references/phase-planning.md"
DIRECTOR_FINAL_GUIDE="$ROOT/shared/skills/product-director/references/final-artifacts.md"
MANAGER_REVIEW="$ROOT/shared/skills/product-manager/references/review-orchestration.md"
PRD_REVIEWER="$ROOT/shared/skills/product-manager/references/prd-reviewer-prompt.md"
ARCHITECT_REVIEWER="$ROOT/shared/skills/product-manager/references/architect-reviewer-prompt.md"
TESTER_REVIEWER="$ROOT/shared/skills/product-manager/references/tester-reviewer-prompt.md"
AUDIT_LOOP_RECORD="$ROOT/tests/fixtures/product-context-signal-cleanup-20260416/context-signal-audit-10-rounds.md"
DESIGN_DOC="$ROOT/tests/fixtures/product-context-signal-cleanup-20260416/design.md"
DESIGN_SKILL="$ROOT/shared/skills/design/SKILL.md"
DESIGN_TEMPLATE="$ROOT/shared/skills/design/projections/design-template.md"
TECH_LEAD_SKILL="$ROOT/shared/skills/tech-lead/SKILL.md"

test -f "$DIRECTOR_SKILL" || fail "missing director skill: $DIRECTOR_SKILL"
test -f "$MANAGER_SKILL" || fail "missing manager skill: $MANAGER_SKILL"
test -f "$DIRECTOR_PROBLEM_GUIDE" || fail "missing director problem guide: $DIRECTOR_PROBLEM_GUIDE"
test -f "$DIRECTOR_SUCCESS_GUIDE" || fail "missing director success/investment-boundary guide: $DIRECTOR_SUCCESS_GUIDE"
test -f "$DIRECTOR_BUSINESS_GUIDE" || fail "missing director business semantics guide: $DIRECTOR_BUSINESS_GUIDE"
test -f "$DIRECTOR_SCOPE_GUIDE" || fail "missing director scope/constraints guide: $DIRECTOR_SCOPE_GUIDE"
test -f "$DIRECTOR_RISKS_GUIDE" || fail "missing director risks/unknowns guide: $DIRECTOR_RISKS_GUIDE"
test -f "$DIRECTOR_PHASE_GUIDE" || fail "missing director phase guide: $DIRECTOR_PHASE_GUIDE"
test -f "$DIRECTOR_FINAL_GUIDE" || fail "missing director final-artifacts guide: $DIRECTOR_FINAL_GUIDE"
test -f "$MANAGER_REVIEW" || fail "missing manager review orchestration: $MANAGER_REVIEW"
test -f "$PRD_REVIEWER" || fail "missing PRD reviewer prompt: $PRD_REVIEWER"
test -f "$ARCHITECT_REVIEWER" || fail "missing architect reviewer prompt: $ARCHITECT_REVIEWER"
test -f "$TESTER_REVIEWER" || fail "missing tester reviewer prompt: $TESTER_REVIEWER"
test -f "$DESIGN_DOC" || fail "missing design doc: $DESIGN_DOC"
test -f "$DESIGN_SKILL" || fail "missing design skill: $DESIGN_SKILL"
test -f "$DESIGN_TEMPLATE" || fail "missing design template: $DESIGN_TEMPLATE"
test -f "$TECH_LEAD_SKILL" || fail "missing tech-lead skill: $TECH_LEAD_SKILL"

assert_absent '至少 10 轮|10 轮审计|审计结果进入任务证据|T7|T8' "$DESIGN_DOC" "design doc process noise"
assert_manager_review_owner_boundary "$MANAGER_SKILL" "manager review owner boundary"
assert_section_present "$MANAGER_SKILL" "## The Process" '\*\*Agent review\*\*' "manager review owner boundary"
assert_section_present "$MANAGER_SKILL" "## The Process" 'reviewed_bundle_digest' "manager review owner boundary"

assert_present 'brief\.json\.review_conclusion' "$MANAGER_REVIEW" "manager review artifact definition"
assert_present 'issue_ledger' "$MANAGER_REVIEW" "manager review artifact definition"

assert_section_present "$DIRECTOR_SKILL" "## 流程" '"Explore demand context" -> "Ask one clarifying question"' "director flow sequence"
assert_section_present "$DIRECTOR_SKILL" "## 流程" 'Self-review and gates' "director flow diagram"
assert_section_present "$MANAGER_SKILL" "## 流程" '"AC" -> "Verification Plan"' "manager flow sequence"
assert_section_present "$MANAGER_SKILL" "## 流程" 'Verification Plan' "manager flow diagram"
assert_section_present "$MANAGER_SKILL" "## The Process" '\*\*Verification Plan\*\*' "manager flow details"
assert_section_present "$MANAGER_SKILL" "## The Process" '\*\*Handoff gate\*\*' "manager flow details"
assert_absent 'digraph product_flow|references/flow-contract\.md' "$DIRECTOR_SKILL" "director flow narrative noise"
assert_absent 'digraph product_flow|references/flow-contract\.md' "$MANAGER_SKILL" "manager flow narrative noise"
assert_section_present "$DIRECTOR_SKILL" "## The Process" 'references/problem-clarification\.md' "director natural process"
assert_section_present "$DIRECTOR_SKILL" "## The Process" 'references/final-artifacts\.md' "director finalization route"
assert_section_absent "$DIRECTOR_SKILL" "## The Process" '\| Step \| Read \| Advance when \| Stop when \|' "director process table noise"
assert_absent 'references/conversation-guide\.md' "$DIRECTOR_SKILL" "director removed conversation guide"
python3 - "$DIRECTOR_SKILL" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
for forbidden in [
    r"^## 触发边界$",
    r"^## Handoff Contract",
]:
    if re.search(forbidden, text, re.M):
        raise SystemExit(f"unexpected Director section: {forbidden}")
PY
assert_section_absent "$DIRECTOR_SKILL" "## HARD-GATE" 'director_confirmation|locked_field_digest' "director runtime-lock noise"
assert_absent 'digest|locked_field|director_confirmation' "$DIRECTOR_FINAL_GUIDE" "director runtime-lock finalization noise"
assert_present 'product-director-ledger\.json' "$DIRECTOR_FINAL_GUIDE" "director ledger artifact boundary"




assert_present '召集 agent teams' "$MANAGER_REVIEW" "review orchestration"
assert_present '3 视角×max10轮' "$MANAGER_REVIEW" "review orchestration"
assert_present 'CONFIRMATION' "$MANAGER_REVIEW" "review orchestration"
assert_manager_fail_rerun_contract "$MANAGER_REVIEW"
assert_manager_warn_carryover_contract "$MANAGER_REVIEW" "review orchestration"

assert_audit_round_count "$AUDIT_LOOP_RECORD" 10

if [ "$failures" -ne 0 ]; then
  printf '[FAIL] product context signal quality contract: %s failed check(s)\n' "$failures" >&2
  exit 1
fi

echo "[PASS] product context signal quality contract"
