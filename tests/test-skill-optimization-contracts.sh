#!/usr/bin/env bash
# 文件职责：验证本轮 Skill 优化合同锚点已写入 product-manager 与 developer。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_MANAGER="$ROOT/shared/skills/product-manager/SKILL.md"
PRODUCT_MANAGER_GUIDE="$ROOT/shared/skills/product-manager/references/conversation-guide.md"
PRODUCT_MANAGER_EVALS="$ROOT/shared/skills/product-manager/evals/evals.json"
DEVELOPER="$ROOT/shared/skills/developer/SKILL.md"
QUALITY_AUDIT="$ROOT/tools/skill_quality/check_skill_body_quality.py"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local label="$1"
  local needle="$2"
  local file="$3"
  grep -Fq "$needle" "$file" || fail "$label missing optimization phrase: $needle"
}

assert_absent() {
  local label="$1"
  local needle="$2"
  local file="$3"
  if grep -Fq "$needle" "$file"; then
    fail "$label contains retired/noise phrase: $needle"
  fi
}

test -f "$PRODUCT_MANAGER" || fail "missing product-manager skill"
test -f "$PRODUCT_MANAGER_GUIDE" || fail "missing product-manager conversation guide"
test -f "$PRODUCT_MANAGER_EVALS" || fail "missing product-manager evals"
test -f "$DEVELOPER" || fail "missing developer skill"
test -f "$QUALITY_AUDIT" || fail "missing skill body quality checker"

assert_present "product-manager" "## Response Contract" "$PRODUCT_MANAGER"
assert_present "product-manager" "PM-OPT-1 UNIT 闭环锚点" "$PRODUCT_MANAGER"
assert_present "product-manager" "PM-OPT-2 AC 与排除项追踪锚点" "$PRODUCT_MANAGER"
assert_present "product-manager" "PM-OPT-3 阻断回答仍保留下游锚点" "$PRODUCT_MANAGER"
assert_present "product-manager" "PM-OPT-4 主导共创引导锚点" "$PRODUCT_MANAGER"
assert_present "product-manager" "输入 / 触发 / 核心行为 / 可观察结果" "$PRODUCT_MANAGER"
assert_present "product-manager" "Verification Plan 映射" "$PRODUCT_MANAGER"
assert_present "product-manager" "排除项追踪字段" "$PRODUCT_MANAGER"
assert_present "product-manager" "M-S1~M-S9" "$PRODUCT_MANAGER"
assert_present "product-manager" "已冻结事实 → 推荐草案或 2-3 个选项 → 推荐理由与假设 → 一个确认、选择或修正问题" "$PRODUCT_MANAGER"

assert_present "product-manager-guide" "## 回复骨架" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "已冻结事实" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "PM 推荐" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "理由与假设" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "请确认、选择或修正" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "## 步骤引导卡" "$PRODUCT_MANAGER_GUIDE"
for step in M-S0 M-S1 M-S2 M-S3 M-S4 M-S5 M-S5.5 M-S6 M-S7 M-S8 M-G1 M-S9; do
  assert_present "product-manager-guide" "| $step |" "$PRODUCT_MANAGER_GUIDE"
done
assert_present "product-manager-guide" "事实锚点" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "推荐输出" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "裁决问题" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "写入目标" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "不要问“你想怎么做”" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "## 裁决式追问模板" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "推荐：" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "请确认" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "## 关键追问模板" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "这个 UNIT 涉及哪些现有业务模块" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "请给这个 AC 一个具体示例输入" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "这里需要 /design 裁决什么" "$PRODUCT_MANAGER_GUIDE"

python3 - "$PRODUCT_MANAGER_EVALS" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
case_by_id = {case.get("id"): case for case in data.get("evals", [])}
case = case_by_id.get("review-delivery-guided-confirmation")
if not case:
    raise SystemExit(f"{path}: missing review/delivery guided confirmation eval")

expected_anchors = set(case.get("expected_anchors", []))
required_anchors = {"PA-4", "PA-6", "PA-7"}
missing_anchors = sorted(required_anchors - expected_anchors)
if missing_anchors:
    raise SystemExit(f"{path}: review/delivery eval missing anchors {missing_anchors}")

text = "\n".join([case.get("prompt", ""), case.get("expected_output", ""), *case.get("expectations", [])])
required_terms = [
    "M-S7",
    "M-S8",
    "M-S9",
    "裁决建议",
    "确认、选择或修正",
    "review_conclusion",
    "issue_ledger",
    "WARN",
    "delivery_confirmation",
    "/design",
    "不得问开放式",
]
missing_terms = [term for term in required_terms if term not in text]
if missing_terms:
    raise SystemExit(f"{path}: review/delivery eval missing terms {missing_terms}")
PY

python3 "$QUALITY_AUDIT" "$ROOT/shared/skills/product-manager" >"$TMP_DIR/product-manager-quality.json"
python3 - "$TMP_DIR/product-manager-quality.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "static_pass":
    raise SystemExit(f"product-manager must pass Skill body quality audit: {payload}")
PY

assert_present "developer" "## 输入识别" "$DEVELOPER"
assert_present "developer" "## 流程图" "$DEVELOPER"
assert_present "developer" "digraph developer_flow" "$DEVELOPER"
assert_present "developer" "RED/GREEN/REFACTOR" "$DEVELOPER"
assert_present "developer" "developer-report.json" "$DEVELOPER"
assert_present "developer" "默认输出是当前 Task 的 \`developer-report.json\`" "$DEVELOPER"
assert_absent "developer" "shared/skills/developer/scripts/completion_check.sh" "$DEVELOPER"
assert_absent "developer" "shared/hooks/registry.json" "$DEVELOPER"
assert_absent "developer" "completion gate" "$DEVELOPER"
assert_absent "developer" "常用证据组包括" "$DEVELOPER"
assert_absent "developer" "projections/developer-report-template.md" "$DEVELOPER"

printf '[PASS] skill optimization contracts\n'
