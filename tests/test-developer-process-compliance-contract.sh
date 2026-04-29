#!/usr/bin/env bash
# 文件职责：验证 active developer 回到 TDD 实现职责，不承载 runtime-layering 治理正文。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/developer/SKILL.md"
REVIEW="$ROOT/shared/skills/developer/evals/lifecycle-review.json"
DECOMP="$ROOT/shared/skills/developer/references/execution-decomposition-guide.md"
SELF_TEST="$ROOT/shared/skills/developer/references/self-testing-methodology.md"
SELF_REVIEW="$ROOT/shared/skills/developer/references/self-review-methodology.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content in $file: $needle"
}

assert_absent() {
  local needle="$1"
  local file="$2"
  if grep -Fq "$needle" "$file"; then
    fail "unexpected duplicate/noise content in $file: $needle"
  fi
}

test -f "$SKILL" || fail "missing developer skill"
test -f "$REVIEW" || fail "missing developer lifecycle review"
test -f "$DECOMP" || fail "missing developer decomposition reference"
test -f "$SELF_TEST" || fail "missing developer self-testing reference"
test -f "$SELF_REVIEW" || fail "missing developer self-review reference"

assert_present "## HARD-GATE" "$SKILL"
assert_present "## 输入识别" "$SKILL"
assert_present "## 流程图" "$SKILL"
assert_present "digraph developer_flow" "$SKILL"
assert_present "RED/GREEN/REFACTOR" "$SKILL"
assert_present "self-testing" "$SKILL"
assert_present "developer-report.json" "$SKILL"
assert_present '默认输出是当前 Task 的 `developer-report.json`' "$SKILL"
assert_absent "shared/skills/developer/scripts/completion_check.sh" "$SKILL"
assert_absent "shared/hooks/registry.json" "$SKILL"
assert_absent "completion gate" "$SKILL"
assert_absent "hook payload" "$SKILL"

assert_absent "## Runtime Layering Contract" "$SKILL"
assert_absent "## 工具边界" "$SKILL"
assert_absent "## 前置条件" "$SKILL"
assert_absent "Runtime Inputs And Authority" "$SKILL"
assert_absent "## 流程合规输出合同" "$SKILL"
assert_absent "## 失败路由合同" "$SKILL"
assert_absent "### 流程状态表" "$SKILL"
assert_absent "只用于理解 AC" "$SKILL"
assert_absent "常用证据组包括" "$SKILL"
assert_absent "projections/developer-report-template.md" "$SKILL"
assert_absent "你不负责：" "$SKILL"
assert_absent "scope registry" "$SKILL"
assert_absent "worklog.md" "$SKILL"
assert_absent "canonical: active refs" "$SKILL"
assert_absent "确定性 preflight" "$SKILL"
assert_absent "Trigger:" "$SKILL"
assert_absent "Read:" "$SKILL"
assert_absent "Expect:" "$SKILL"
assert_absent "Consume:" "$SKILL"
assert_absent "Evidence:" "$SKILL"
assert_absent "Sync:" "$SKILL"

for ref in "$DECOMP" "$SELF_TEST" "$SELF_REVIEW"; do
  assert_absent "引用者：" "$ref"
  assert_absent "Trigger:" "$ref"
  assert_absent "Triggered by" "$ref"
  assert_absent "Read:" "$ref"
  assert_absent "Expect:" "$ref"
  assert_absent "Consume:" "$ref"
  assert_absent "Consumer" "$ref"
  assert_absent "Evidence:" "$ref"
  assert_absent "Sync:" "$ref"
done

assert_absent "### 主动探索" "$DECOMP"
assert_absent '`ls`' "$DECOMP"
assert_absent "Grep 搜索" "$DECOMP"

python3 - "$REVIEW" <<'PY'
import json
import sys
from pathlib import Path

review = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
rationale = review.get("existence_rationale")
if not isinstance(rationale, dict):
    raise SystemExit("developer lifecycle review missing existence_rationale")
if rationale.get("primary_value") != "task_execution_tdd_report_evidence":
    raise SystemExit("developer primary_value must be task_execution_tdd_report_evidence")
if rationale.get("capability_uplift") != "pending_redesign_eval":
    raise SystemExit("developer capability_uplift must be pending_redesign_eval after rebuild")
PY

printf '[PASS] developer process compliance contract\n'
