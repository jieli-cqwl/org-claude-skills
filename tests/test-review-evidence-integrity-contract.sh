#!/usr/bin/env bash
# 文件职责：验证 /review 已沉淀 Harness 证据链完整性专项审查合同。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg
REVIEW_SKILL="$ROOT/shared/skills/review/SKILL.md"
REFERENCE="$ROOT/shared/skills/review/references/evidence-integrity-review.md"
TEMPLATE="$ROOT/shared/skills/review/projections/code-review-report-template.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

[ -f "$REFERENCE" ] || fail "missing evidence integrity reference"

assert_present '证据链完整性专项' "$REVIEW_SKILL"
assert_present 'references/evidence-integrity-review\.md' "$REVIEW_SKILL"
assert_present 'skill|eval|validator|artifact|installer|runtime gate' "$REVIEW_SKILL"
assert_present '证据链完整性专项' "$TEMPLATE"
assert_present '适用性.*适用 / 不适用' "$TEMPLATE"

for marker in \
  '自证检测' \
  '声称/证据一致' \
  '负例驱动' \
  '过时材料清理' \
  '行为边界' \
  '消费者链路' \
  '权限真实边界' \
  '计划/实现漂移' \
  '失败产物污染' \
  '回归证明'
do
  assert_present "$marker" "$REFERENCE"
done

assert_present 'observed.*expected' "$REFERENCE"
assert_present 'PASS.*真实执行' "$REFERENCE"
assert_present '失败.*PASS.*artifact' "$REFERENCE"
assert_present 'seed eval.*live benchmark' "$REFERENCE"

printf '[PASS] review evidence integrity contract\n'
