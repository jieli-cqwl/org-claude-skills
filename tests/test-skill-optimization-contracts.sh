#!/usr/bin/env bash
# 文件职责：验证本轮 Skill 优化合同锚点已写入 product-manager 与 developer。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_MANAGER="$ROOT/shared/skills/product-manager/SKILL.md"
PRODUCT_MANAGER_GUIDE="$ROOT/shared/skills/product-manager/references/conversation-guide.md"
PRODUCT_MANAGER_FLOW="$ROOT/shared/skills/product-manager/references/business-flow-refinement.md"
PRODUCT_MANAGER_DESIGN_HANDOFF="$ROOT/shared/skills/product-manager/references/design-handoff-decisions.md"
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
test -f "$PRODUCT_MANAGER_FLOW" || fail "missing product-manager business flow guide"
test -f "$PRODUCT_MANAGER_DESIGN_HANDOFF" || fail "missing product-manager design handoff guide"
test -f "$PRODUCT_MANAGER_EVALS" || fail "missing product-manager evals"
test -f "$DEVELOPER" || fail "missing developer skill"
test -f "$QUALITY_AUDIT" || fail "missing skill body quality checker"

assert_present "product-manager" "## PM 执行锚点" "$PRODUCT_MANAGER"
assert_present "product-manager" "PM-OPT-1 UNIT 闭环锚点" "$PRODUCT_MANAGER"
assert_present "product-manager" "PM-OPT-2 AC 与排除项追踪锚点" "$PRODUCT_MANAGER"
assert_present "product-manager" "PM-OPT-3 阻断回答仍保留下游锚点" "$PRODUCT_MANAGER"
assert_present "product-manager" "PM-OPT-4 关键业务假设锚点" "$PRODUCT_MANAGER"
assert_present "product-manager" "输入 / 触发 / 核心行为 / 可观察结果" "$PRODUCT_MANAGER"
assert_present "product-manager" "Verification Plan 映射" "$PRODUCT_MANAGER"
assert_present "product-manager" "排除项追踪字段" "$PRODUCT_MANAGER"
assert_present "product-manager" "M-S1~M-S9" "$PRODUCT_MANAGER"
assert_present "product-manager" "已冻结事实 → PM 推荐结论草案 → 推荐理由 → 一个会改变结论的具体业务假设" "$PRODUCT_MANAGER"
assert_present "product-manager" "不从该文件推导业务流程、用户路径、规则映射、UNIT、AC、Verification Plan、设计决策或输出字段" "$PRODUCT_MANAGER"
assert_present "product-manager" "references/business-flow-refinement.md" "$PRODUCT_MANAGER"
assert_present "product-manager" "references/design-handoff-decisions.md" "$PRODUCT_MANAGER"
assert_absent "product-manager" "## Response Contract" "$PRODUCT_MANAGER"
assert_absent "product-manager" "推荐草案或 2-3 个选项" "$PRODUCT_MANAGER"
assert_absent "product-manager" "一个确认、选择或修正问题" "$PRODUCT_MANAGER"

assert_present "product-manager-guide" "## 共创回合协议" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "## 业务事实回应处理" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "## 模式差异" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "## 关键假设模板" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "推荐结论、推荐理由和会改变结论的未闭合业务假设" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "回应中的业务事实支撑关键假设时，将 PM 推荐结论作为当前步骤结论写入 checkpoint" "$PRODUCT_MANAGER_GUIDE"
assert_present "product-manager-guide" "回应包含 Director 锁定字段、Phase 边界、范围或约束事实的替换事实时，回退 \`/product-director\`" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "## 主导共创" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "## 每轮共创收口" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "## 对话节奏" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "## 交互模式" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "## 步骤引导卡" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "确认、选择或修正" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "推荐选项" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "为了共创" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "专业判断拆给用户" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "业务适配" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "## 关键追问模板" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "这个 UNIT 涉及哪些现有业务模块" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "请给这个 AC 一个具体示例输入" "$PRODUCT_MANAGER_GUIDE"
assert_absent "product-manager-guide" "这里需要 /design 裁决什么" "$PRODUCT_MANAGER_GUIDE"

assert_present "product-manager-flow" 'phase-prd.json.business_flows / user_paths / rule_mappings' "$PRODUCT_MANAGER_FLOW"
assert_present "product-manager-flow" "不写 UNIT、AC、测试命令、路由结构、组件方案或技术落点" "$PRODUCT_MANAGER_FLOW"
assert_present "product-manager-flow" "关键流程假设闭合后，写入 \`phase-prd.json.business_flows\`" "$PRODUCT_MANAGER_FLOW"
assert_present "product-manager-design-handoff" 'phase-prd.json.design_decision_candidates' "$PRODUCT_MANAGER_DESIGN_HANDOFF"
assert_present "product-manager-design-handoff" "不提前给技术答案" "$PRODUCT_MANAGER_DESIGN_HANDOFF"

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
    "收口建议",
    "具体业务假设",
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
