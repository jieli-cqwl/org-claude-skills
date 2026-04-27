#!/usr/bin/env bash
# 文件职责：验证 developer Skill 以流程合规为核心价值，并避免与 canonical 模板重复。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/developer/SKILL.md"
REVIEW="$ROOT/shared/skills/developer/evals/lifecycle-review.json"

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

assert_present "## 流程合规输出合同" "$SKILL"
assert_present "canonical JSON 必需字段以 runtime schema/template 为准" "$SKILL"
assert_present "接口变更记录的展示格式由 projections/developer-report-template.md 维护" "$SKILL"
assert_absent "## Eval-Safe Response Contract" "$SKILL"
assert_absent "interface_change_log" "$SKILL"
assert_absent "微调变更日志格式" "$SKILL"

python3 - "$REVIEW" <<'PY'
import json
import sys
from pathlib import Path

review = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
rationale = review.get("existence_rationale")
if not isinstance(rationale, dict):
    raise SystemExit("developer lifecycle review missing existence_rationale")
if rationale.get("primary_value") != "process_compliance":
    raise SystemExit("developer primary_value must be process_compliance")
if rationale.get("capability_uplift") != "not_primary_success_metric":
    raise SystemExit("developer capability_uplift must be marked not_primary_success_metric")
PY

printf '[PASS] developer process compliance contract\n'
