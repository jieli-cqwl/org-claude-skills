#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

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
  if rg -n "$pattern" "$file" >/tmp/t6_cutover_absent.out 2>&1; then
    cat /tmp/t6_cutover_absent.out >&2
    fail "unexpected legacy pattern in $file: $pattern"
  fi
}

assert_present 'brief.json' "$ROOT/contracts/skill-chain.yaml"
assert_present 'phase-\{N\}/phase-prd.json' "$ROOT/contracts/skill-chain.yaml"
assert_present 'phase-\{N\}/design.json' "$ROOT/contracts/skill-chain.yaml"
assert_present 'phase-\{N\}/plan.json' "$ROOT/contracts/skill-chain.yaml"
assert_present 'phase-\{N\}/tasks.json' "$ROOT/contracts/skill-chain.yaml"
assert_present 'phase-\{N\}/unit-\{N\}/tasks/\{task_id\}/developer-report.json' "$ROOT/contracts/skill-chain.yaml"
assert_present 'phase-\{N\}/unit-\{N\}/tasks/\{task_id\}/verify-result.json' "$ROOT/contracts/skill-chain.yaml"
assert_present 'phase-\{N\}/qa-result.json' "$ROOT/contracts/skill-chain.yaml"
assert_present 'phase-\{N\}/delivery-state.json' "$ROOT/contracts/skill-chain.yaml"
assert_present 'phase-\{N\}/artifact-registry.json' "$ROOT/contracts/skill-chain.yaml"
assert_present 'phase-\{N\}/signoff-package.json' "$ROOT/contracts/skill-chain.yaml"
assert_absent 'brief.md|prd.md|design.md|plan.md|qa-report.md|developer-report-Task-N.md|acceptance-summary.md' "$ROOT/contracts/skill-chain.yaml"

assert_present 'brief.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'phase-prd.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'design.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'plan.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'tasks.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'artifact-registry.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'test-cases.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_present 'developer-report.json' "$ROOT/shared/protocols/phase-selection-protocol.md"
assert_absent 'brief.md|prd.md|qa-report.md|dev-report.md' "$ROOT/shared/protocols/phase-selection-protocol.md"

assert_present 'phase-prd.json' "$ROOT/shared/skills/product/references/phase-splitting-guide.md"
assert_present 'UNIT-\{N\}.json' "$ROOT/shared/skills/product/references/phase-splitting-guide.md"
assert_absent 'prd.md|UNIT-\*\.md' "$ROOT/shared/skills/product/references/phase-splitting-guide.md"

assert_present 'contracts/canonical/templates/planning/brief.template.json' "$ROOT/shared/skills/product/SKILL.md"
assert_present 'contracts/canonical/templates/planning/design.template.json' "$ROOT/shared/skills/design/SKILL.md"
assert_present 'contracts/canonical/templates/planning/test-cases.template.json' "$ROOT/shared/skills/test-design/SKILL.md"
assert_present 'contracts/canonical/templates/planning/plan.template.json' "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_present 'contracts/canonical/templates/runtime/developer-report.template.json' "$ROOT/shared/skills/developer/SKILL.md"
assert_present 'contracts/canonical/templates/runtime/code-review-result.template.json' "$ROOT/shared/skills/review/SKILL.md"
assert_present 'contracts/canonical/templates/runtime/verify-result.template.json' "$ROOT/shared/skills/verify/SKILL.md"
assert_present 'contracts/canonical/templates/runtime/qa-result.template.json' "$ROOT/shared/skills/qa/SKILL.md"
assert_present 'contracts/canonical/templates/runtime/signoff-package.template.json' "$ROOT/shared/skills/delivery-owner/SKILL.md"

assert_present 'validate_standard_chain_phase.py' "$ROOT/shared/skills/product/SKILL.md"
assert_present 'validate_standard_chain_phase.py' "$ROOT/shared/skills/design/SKILL.md"
assert_present 'validate_standard_chain_phase.py' "$ROOT/shared/skills/test-design/SKILL.md"
assert_present 'validate_standard_chain_phase.py' "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_present 'artifact-registry.json' "$ROOT/shared/skills/developer/SKILL.md"
assert_present 'artifact-registry.json' "$ROOT/shared/skills/review/SKILL.md"
assert_present 'artifact-registry.json' "$ROOT/shared/skills/verify/SKILL.md"
assert_present 'artifact-registry.json' "$ROOT/shared/skills/qa/SKILL.md"
assert_present 'artifact-registry.json' "$ROOT/shared/skills/delivery-owner/SKILL.md"

assert_present 'canonical JSON' "$ROOT/shared/agents/designer.md"
assert_present 'canonical JSON' "$ROOT/shared/agents/tech-lead.md"
assert_present 'canonical JSON' "$ROOT/shared/agents/test-designer.md"
assert_present 'active registry' "$ROOT/shared/agents/developer.md"
assert_present 'active registry' "$ROOT/shared/agents/code-reviewer.md"
assert_present 'active registry' "$ROOT/shared/agents/verifier.md"
assert_present 'active registry' "$ROOT/shared/agents/qa.md"

echo "[PASS] standard chain cutover"
