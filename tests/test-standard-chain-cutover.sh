#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  assert_rg_no_match \
    /tmp/t6_cutover_absent.out \
    "unexpected legacy pattern in $file: $pattern" \
    -n "$pattern" "$file"
}

assert_present 'brief.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/phase-prd.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/design.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/plan.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/tasks.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/unit-\{N\}/tasks/\{task_id\}/developer-report.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/unit-\{N\}/tasks/\{task_id\}/verify-result.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/qa-result.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/delivery-state.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/artifact-registry.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'scope registry' "$ROOT/contracts/standard-chain.yaml"
assert_present 'worklog.md' "$ROOT/contracts/standard-chain.yaml"
assert_present 'canonical:' "$ROOT/contracts/standard-chain.yaml"
assert_present 'name: consistency-auditor' "$ROOT/contracts/standard-chain.yaml"
assert_present 'position: sidecar' "$ROOT/contracts/standard-chain.yaml"
assert_present 'decision_authority: advisory_only' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/consistency-audit-result.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/fix-result.json' "$ROOT/contracts/standard-chain.yaml"
assert_present 'phase-\{N\}/signoff-package.json' "$ROOT/contracts/standard-chain.yaml"
assert_absent 'brief.md|prd.md|design.md|plan.md|qa-report.md|developer-report-Task-N.md|acceptance-summary.md|product-manager-review.md|legacy_projection' "$ROOT/contracts/standard-chain.yaml"
assert_absent 'gate_escalation' "$ROOT/contracts/standard-chain.yaml"

assert_present 'brief.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'phase-prd.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'design.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'plan.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'tasks.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'artifact-registry.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'test-cases.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'developer-report.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_absent 'brief.md|prd.md|qa-report.md|dev-report.md' "$ROOT/shared/protocols/phase-selection-protocol.md"

assert_present 'phase-prd.json' "$ROOT/shared/skills/product-director/references/phase-planning.md"
assert_present 'phase-prd.json' "$ROOT/shared/skills/product-manager/SKILL.md"
assert_present 'UNIT-\*\.json' "$ROOT/shared/skills/product-manager/SKILL.md"

assert_present 'shared/skills/product-director/templates/brief.template.json' "$ROOT/shared/skills/product-director/references/final-artifacts.md"
assert_present 'shared/skills/product-manager/templates/brief.template.json' "$ROOT/shared/skills/product-manager/SKILL.md"
assert_present 'shared/skills/design/templates/design.template.json' "$ROOT/shared/skills/design/SKILL.md"
assert_present 'shared/skills/test-design/templates/test-cases.template.json' "$ROOT/shared/skills/test-design/SKILL.md"
assert_present 'shared/skills/tech-lead/templates/tasks.template.json' "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_present 'shared/skills/developer/templates/developer-report.template.json' "$ROOT/shared/skills/developer/SKILL.md"
assert_present 'shared/skills/review/templates/code-review-result.template.json' "$ROOT/shared/skills/review/SKILL.md"
assert_present 'shared/skills/verify/templates/verify-result.template.json' "$ROOT/shared/skills/verify/SKILL.md"
assert_present 'shared/skills/qa/templates/qa-result.template.json' "$ROOT/shared/skills/qa/SKILL.md"
[ ! -d "$ROOT/shared/skills/qa/projections" ] \
  || fail "qa projections directory must be removed"
[ ! -d "$ROOT/shared/skills/consistency-audit/projections" ] \
  || fail "consistency-audit projections directory must be removed"
assert_absent 'shared/skills/delivery-owner/templates/signoff-package.template.json' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present 'fix-result.json' "$ROOT/shared/skills/fix/SKILL.md"

python3 - "$ROOT/shared/skills/product-director/references/final-artifacts.md" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
required_paths = [
    "tools/community/validate_co_creation_ledger.py",
    "shared/skills/product-director/templates/brief.template.json",
    "shared/skills/product-director/templates/phase-prd.template.json",
]
missing = [path for path in required_paths if path not in text]
if missing:
    raise SystemExit(f"product-director final artifacts missing contract paths: {missing}")
PY
assert_absent 'validate_canonical_schema.py' "$ROOT/shared/skills/product-director/references/final-artifacts.md"
assert_absent 'validate_standard_chain_phase.py' "$ROOT/shared/skills/product-director/SKILL.md"
assert_absent 'validate_standard_chain_phase.py' "$ROOT/shared/skills/product-director/references/final-artifacts.md"
assert_present 'validate_standard_chain_phase.py' "$ROOT/shared/skills/product-manager/SKILL.md"
assert_present 'validate_standard_chain_phase.py' "$ROOT/shared/skills/design/SKILL.md"
assert_present 'validate_standard_chain_phase.py' "$ROOT/shared/skills/test-design/SKILL.md"
assert_present 'validate_standard_chain_phase.py' "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_present '"traceability_matrix"' "$ROOT/shared/skills/test-design/contracts/test-cases.schema.json"
assert_present '\$\.traceability_matrix' "$ROOT/shared/skills/test-design/templates/test-cases.template.json"
assert_present 'cross_unit_obligations' "$ROOT/shared/skills/test-design/projections/test-cases-template.md"
assert_present 'assertion_target' "$ROOT/shared/skills/developer/SKILL.md"
assert_present 'qa_handoff_contract' "$ROOT/shared/skills/delivery-owner/SKILL.md"
for design_prompt in \
  "$ROOT/shared/skills/design/references/design-reviewer-prompt.md" \
  "$ROOT/shared/skills/design/references/design-product-reviewer-prompt.md" \
  "$ROOT/shared/skills/design/references/design-test-reviewer-prompt.md"
do
  assert_present 'review_closure' "$design_prompt"
  assert_present 'final_confirmation' "$design_prompt"
  assert_present 'sha256:' "$design_prompt"
  assert_absent 'design/MOD-\*|ADR-\*|design\.json\.review_conclusion|\bADR\b|MOD-[0-9]|brief\.md|prd\.md|UNIT-\*\.md|test-cases\.md' "$design_prompt"
done
for design_prompt in \
  "$ROOT/shared/skills/test-design/references/testdesign-arch-reviewer-prompt.md" \
  "$ROOT/shared/skills/test-design/references/methodology.md"
do
  assert_present 'canonical `design.json`' "$design_prompt"
  assert_absent 'design/MOD-\*|ADR-\*|design\.json\.review_conclusion|\bADR\b|MOD-[0-9]|brief\.md|prd\.md|UNIT-\*\.md|test-cases\.md' "$design_prompt"
done
assert_present 'artifact-registry.json' "$ROOT/shared/skills/review/SKILL.md"
assert_present 'artifact-registry.json' "$ROOT/shared/skills/verify/SKILL.md"
assert_present 'artifact-registry.json' "$ROOT/shared/skills/qa/SKILL.md"
assert_present 'artifact-registry.json' "$ROOT/shared/skills/delivery-owner/SKILL.md"
jq -e '
  .authoritative_fields
  | index("$.review_conclusion") != null
    and index("$.issue_ledger") != null
    and index("$.delivery_confirmation") != null
' "$ROOT/shared/skills/product-manager/templates/brief.template.json" >/dev/null \
  || fail "product-manager brief template must expose handoff closure fields"
assert_present 'validate_product_closure.py' "$ROOT/shared/skills/product-manager/SKILL.md"
for standard_skill in \
  "$ROOT/shared/skills/tech-lead/SKILL.md" \
  "$ROOT/shared/skills/test-design/SKILL.md" \
  "$ROOT/shared/skills/verify/SKILL.md" \
  "$ROOT/shared/skills/qa/SKILL.md" \
  "$ROOT/shared/skills/delivery-owner/SKILL.md" \
  "$ROOT/shared/skills/fix/SKILL.md" \
  "$ROOT/shared/skills/consistency-audit/SKILL.md"
do
  case "$standard_skill" in
    "$ROOT/shared/skills/test-design/SKILL.md")
      assert_present 'canonical JSON' "$standard_skill"
      ;;
    "$ROOT/shared/skills/tech-lead/SKILL.md")
      assert_present 'plan canonical: `templates/plan\.template\.json`' "$standard_skill"
      assert_present 'tasks canonical: `templates/tasks\.template\.json`' "$standard_skill"
      ;;
    "$ROOT/shared/skills/qa/SKILL.md")
      assert_present 'canonical schema/template' "$standard_skill"
      assert_present 'artifact-registry.json' "$standard_skill"
      ;;
    "$ROOT/shared/skills/delivery-owner/SKILL.md")
      assert_present 'artifact-registry.json' "$standard_skill"
      ;;
    "$ROOT/shared/skills/fix/SKILL.md")
      assert_present 'artifact-registry.json' "$standard_skill"
      ;;
    "$ROOT/shared/skills/verify/SKILL.md")
      assert_present 'canonical:' "$standard_skill"
      assert_present 'scope registry' "$standard_skill"
      assert_present 'worklog.md' "$standard_skill"
      ;;
    "$ROOT/shared/skills/consistency-audit/SKILL.md")
      assert_present 'canonical JSON' "$standard_skill"
      assert_present 'artifact-registry.json' "$standard_skill"
      ;;
  esac
done

assert_absent 'scope registry|worklog\.md|active-doc-scope|artifact-registry' "$ROOT/shared/skills/product-director/SKILL.md"
assert_absent 'scope registry|worklog\.md|active-doc-scope|artifact-registry' "$ROOT/shared/skills/design/SKILL.md"
assert_absent 'scope registry|worklog\.md|canonical: active refs' "$ROOT/shared/skills/developer/SKILL.md"

for agent_contract in "$ROOT/shared/agents/claude"/*.md
do
  assert_absent '^model:|^maxTurns:|^memory:' "$agent_contract"
  assert_absent '\{work_dir\}|\{phase_dir\}|docs/\{feature\}|developer-report\.json|verify-result\.json|qa-result\.json|code-review-result\.json|test-cases\.json|plan\.json|design\.json|brief\.json|phase-prd\.json|UNIT-\*\.json|MOD-\*\.md|ADR-\*\.md' "$agent_contract"
done

[ ! -e "$ROOT/shared/agents/claude/designer.md" ] || fail "designer should remain a manual skill, not a delivery-owner dispatch agent"
[ ! -e "$ROOT/shared/agents/claude/tech-lead.md" ] || fail "tech-lead should remain a manual skill, not a delivery-owner dispatch agent"
[ ! -e "$ROOT/shared/agents/claude/test-designer.md" ] || fail "test-designer should remain a manual skill, not a delivery-owner dispatch agent"
[ ! -e "$ROOT/shared/agents/claude/code-reviewer.md" ] || fail "local code-reviewer agent contract should be retired in favor of Superpowers reviewer semantics"

echo "[PASS] standard chain cutover"
