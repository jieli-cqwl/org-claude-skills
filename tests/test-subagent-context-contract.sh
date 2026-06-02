#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in ${file#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected pattern in ${file#"$ROOT"/}: $pattern"
  fi
}

# 非运行时文件必须直接删除，不能保留为 reference 噪音
for file in \
  "$ROOT/shared/reference/subagent-recovery-contract.md" \
  "$ROOT/shared/reference/context-noise-metrics.md" \
  "$ROOT/shared/reference/templates/fact-scan-template.md" \
  "$ROOT/shared/reference/templates/hypothesis-draft-template.md" \
  "$ROOT/shared/reference/templates/structure-draft-template.md" \
  "$ROOT/shared/reference/templates/synthesis-template.md" \
  "$ROOT/shared/reference/templates/metrics-log-template.md"
do
  [ ! -e "$file" ] || fail "unexpected retained runtime-noise file: ${file#"$ROOT"/}"
done

assert_no_subagent_chapter() {
  local file="$1"
  python3 - "$file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
    stripped = line.strip()
    if stripped.startswith(("## ", "### ")) and stripped.split(maxsplit=1)[1] == "子代理边界":
        raise SystemExit(f"{path}:{line_no}: unexpected subagent boundary chapter")
PY
}

extract_stage_block() {
  local stage="$1"
  awk -v stage="$stage" '
    $0 == "  - name: " stage { in_block=1 }
    in_block && $0 ~ /^  - name: / && $0 != "  - name: " stage { exit }
    in_block { print }
  ' "$ROOT/contracts/standard-chain.yaml"
}

assert_stage_has() {
  local stage="$1"
  local pattern="$2"
  local block
  block="$(extract_stage_block "$stage")"
  printf '%s\n' "$block" | rg -n "$pattern" >/dev/null 2>&1 || fail "missing stage pattern in ${stage}: $pattern"
}

assert_stage_absent() {
  local stage="$1"
  local pattern="$2"
  local block
  block="$(extract_stage_block "$stage")"
  if printf '%s\n' "$block" | rg -n "$pattern" >/dev/null 2>&1; then
    fail "unexpected stage pattern in ${stage}: $pattern"
  fi
}

for skill in design test-design tech-lead delivery-owner; do
  skill_file="$ROOT/shared/skills/$skill/SKILL.md"
  assert_no_subagent_chapter "$skill_file"
done

assert_stage_absent 'delivery-owner' 'artifact: "phase-\{N\}/qa-report\.md"'
assert_present 'qa_report_producer: qa' "$ROOT/contracts/standard-chain.yaml"
assert_stage_absent 'design' 'subagent_policy:|max_subagents:|recovery_contract_ref:|metrics_ref:|allowed_subagent_kinds:'
assert_stage_absent 'test-design' 'subagent_policy:|max_subagents:|recovery_contract_ref:|metrics_ref:|allowed_subagent_kinds:'
assert_stage_absent 'tech-lead' 'subagent_policy:|max_subagents:|recovery_contract_ref:|metrics_ref:|allowed_subagent_kinds:'
assert_stage_absent 'delivery-owner' 'subagent_policy:|max_subagents:|recovery_contract_ref:|metrics_ref:|allowed_subagent_kinds:'
assert_absent 'metrics_log_template_ref' "$ROOT/contracts/standard-chain.yaml"

assert_present "\`goal_fidelity_review\`" "$ROOT/shared/skills/tech-lead/SKILL.md"
for prompt in \
  "$ROOT/shared/skills/tech-lead/references/plan-reviewer-prompt.md" \
  "$ROOT/shared/skills/tech-lead/references/plan-product-reviewer-prompt.md" \
  "$ROOT/shared/skills/tech-lead/references/plan-test-reviewer-prompt.md"; do
  [ ! -e "$prompt" ] || fail "unexpected retained tech-lead reviewer prompt: ${prompt#"$ROOT"/}"
done

assert_absent 'fact-scan-template\.md|subagent-recovery-contract|context-noise-metrics' "$ROOT/shared/skills/design/references/runtime-fact-capture.md"
assert_absent 'hypothesis-draft-template\.md|structure-draft-template\.md|subagent-recovery-contract|context-noise-metrics' "$ROOT/shared/skills/design/references/decision-templates.md"
assert_absent 'decision_state.*draft / frozen' "$ROOT/shared/skills/design/references/decision-templates.md"
assert_absent 'structure-draft-template\.md|subagent-recovery-contract|context-noise-metrics' "$ROOT/shared/skills/design/projections/adr-spec.md"
python3 - "$ROOT/shared/skills/design/SKILL.md" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
required = [
    "`final_confirmation`",
    "review_closure",
]
missing = [term for term in required if term not in text]
if missing:
    raise SystemExit(f"missing design finalization boundary fields: {missing}")
PY

ROUTING_REF="$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_absent 'synthesis-template\.md|subagent-recovery-contract|context-noise-metrics' "$ROUTING_REF"
assert_present '^role:$' "$ROUTING_REF"
assert_present '^task_ref:$' "$ROUTING_REF"
assert_present '^expected_evidence:$' "$ROUTING_REF"
assert_absent 'status-synthesis|evidence-synthesis' "$ROUTING_REF"
assert_absent '^\| Synthesis \|' "$ROUTING_REF"
DIRECTOR_PROBLEM_GUIDE="$ROOT/shared/skills/product-director/references/problem-clarification.md"

bash "$ROOT/tools/dev/validate-contracts.sh" >/tmp/org-validate-contracts.out 2>&1 || {
  cat /tmp/org-validate-contracts.out >&2
  fail "validate-contracts should pass"
}

echo "[PASS] subagent context contract"
