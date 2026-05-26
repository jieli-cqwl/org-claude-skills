#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="$ROOT/shared/skills/test-design"
HISTORY_DIR="$ROOT/shared/skills/test-design-h"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: ${1#"$ROOT"/}"
}

assert_absent() {
  local pattern="$1" path="$2"
  if grep -R -n -E "$pattern" "$path" >/tmp/test_design_clean_resource.out 2>&1; then
    cat /tmp/test_design_clean_resource.out >&2
    fail "unexpected pattern under ${path#"$ROOT"/}: $pattern"
  fi
}

assert_present() {
  local pattern="$1" file="$2"
  grep -E "$pattern" "$file" >/dev/null || fail "missing pattern in ${file#"$ROOT"/}: $pattern"
}

assert_file "$SKILL_DIR/SKILL.md"
assert_file "$SKILL_DIR/references/methodology.md"
assert_file "$SKILL_DIR/references/test-obligation-shaping.md"
assert_file "$SKILL_DIR/references/specialty-test-design.md"
assert_file "$SKILL_DIR/references/testdesign-reviewer-prompt.md"
assert_file "$SKILL_DIR/references/testdesign-product-reviewer-prompt.md"
assert_file "$SKILL_DIR/references/testdesign-arch-reviewer-prompt.md"
assert_file "$SKILL_DIR/scripts/preflight_check.sh"
assert_file "$SKILL_DIR/scripts/completion_check.sh"
assert_file "$SKILL_DIR/contracts/test-cases.schema.json"
assert_file "$SKILL_DIR/templates/test-cases.template.json"
assert_file "$SKILL_DIR/projections/test-cases-template.md"

for removed in \
  integration-test-methodology.md \
  contract-test-methodology.md \
  security-test-methodology.md \
  performance-test-methodology.md; do
  [ ! -e "$SKILL_DIR/references/$removed" ] || fail "old specialty reference still exists: $removed"
done

[ ! -e "$HISTORY_DIR" ] || fail "historical test-design-h should be deleted"

assert_absent '^(>|[[:space:]])*(Trigger|Read|Expect|Consume|Sync):' "$SKILL_DIR/references"
assert_absent '产品是一等真源|下游消费者成功标准|输入准入|主 Agent|主 agent|本 eval 不要求实际写文件|不要求实际写文件|要求先执行 design|要求先回到 design' "$SKILL_DIR"
assert_absent 'references/methodology\.md.*Trigger:.*Read:.*Expect:.*Consume:.*Evidence:.*Sync:' "$SKILL_DIR/SKILL.md"

assert_present 'references/methodology\.md' "$SKILL_DIR/SKILL.md"
assert_present 'references/test-obligation-shaping\.md' "$SKILL_DIR/SKILL.md"
assert_present 'references/specialty-test-design\.md' "$SKILL_DIR/SKILL.md"
assert_present 'references/testdesign-reviewer-prompt\.md' "$SKILL_DIR/SKILL.md"
assert_present '你复核 findings' "$SKILL_DIR/SKILL.md"
assert_present '事实输入仅限 canonical JSON' "$SKILL_DIR/SKILL.md"
assert_present 'digraph test_design_flow' "$SKILL_DIR/SKILL.md"
assert_absent '```mermaid|graph TD' "$SKILL_DIR/SKILL.md"
assert_present '等待用户裁决' "$SKILL_DIR/SKILL.md"
assert_present '相邻 Skill 只作为可选下一步，是否执行由用户裁决' "$SKILL_DIR/SKILL.md"
assert_present '写入并等待 hooks gate' "$SKILL_DIR/SKILL.md"
assert_present 'hooks completion gate 未返回 BLOCKED' "$SKILL_DIR/SKILL.md"
assert_present '3 视角×max10轮' "$SKILL_DIR/SKILL.md"
assert_present 'R2 / CONFIRMATION' "$SKILL_DIR/SKILL.md"
assert_present '只重提 FAIL 视角' "$SKILL_DIR/SKILL.md"
assert_present '连续 2 轮 FAIL 数不减少' "$SKILL_DIR/SKILL.md"
assert_present '同一 issue 连续 3 轮未关闭' "$SKILL_DIR/SKILL.md"
assert_present 'review_conclusion\.convergence_evidence\[\]' "$SKILL_DIR/SKILL.md"
assert_present 'templates/test-cases\.template\.json' "$SKILL_DIR/SKILL.md"
assert_present 'contracts/test-cases\.schema\.json' "$SKILL_DIR/SKILL.md"
assert_present 'validator' "$SKILL_DIR/SKILL.md"
printf '[PASS] test-design clean resource\n'
