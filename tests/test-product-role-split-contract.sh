#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

# Literal regex patterns intentionally match backticks and shell-like variables
# in Markdown/Bash source files.

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected pattern in $file: $pattern"
  fi
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

assert_registry_codex_supported() {
  local registry_file="$1"
  local skill_name="$2"
  local expected="$3"
  local actual

  actual=$(jq -r --arg skill "$skill_name" '.skill_completion_gates[] | select(.skill == $skill) | .codex.supported' "$registry_file")
  [ "$actual" = "$expected" ] || fail "unexpected codex.supported for $skill_name: expected $expected, got ${actual:-<empty>}"
}

DIRECTOR_BRIEF_JSON_TEMPLATE="$ROOT/shared/skills/product-director/templates/brief.template.json"
DIRECTOR_PHASE_JSON_TEMPLATE="$ROOT/shared/skills/product-director/templates/phase-prd.template.json"
MANAGER_BRIEF_TEMPLATE="$ROOT/shared/skills/product-manager/projections/brief-template.md"
MANAGER_PHASE_TEMPLATE="$ROOT/shared/skills/product-manager/projections/phase-prd-template.md"
MANAGER_REVIEW_TEMPLATE="$ROOT/shared/skills/product-manager/projections/product-manager-review-template.md"
MANAGER_REVIEW_CONTRACT="$ROOT/shared/skills/product-manager/references/review-orchestration-contract.md"
PRODUCT_DIRECTOR_ROOT="$ROOT/shared/skills/product-director"
PRODUCT_MANAGER_ROOT="$ROOT/shared/skills/product-manager"
DIRECTOR_PROBLEM_GUIDE="$PRODUCT_DIRECTOR_ROOT/references/problem-clarification.md"
MANAGER_CONVERSATION_GUIDE="$PRODUCT_MANAGER_ROOT/references/conversation-guide.md"
CHAIN_CONTRACT="$ROOT/contracts/standard-chain.yaml"
PRODUCT_ARTIFACT_CONTRACT="$ROOT/contracts/product-artifacts.yaml"
PRODUCT_ARTIFACT_TEST="$ROOT/tests/test-product-artifact-contract.sh"
HOOK_REGISTRY="$ROOT/shared/hooks/registry.json"
PRODUCT_MANAGER_MANIFEST="$ROOT/shared/skills/product-manager/scripts/manifest.json"
DESIGN_SKILL="$ROOT/shared/skills/design/SKILL.md"
TEST_DESIGN_SKILL="$ROOT/shared/skills/test-design/SKILL.md"
TECH_LEAD_SKILL="$ROOT/shared/skills/tech-lead/SKILL.md"
DELIVERY_OWNER_SKILL="$ROOT/shared/skills/delivery-owner/SKILL.md"
FIX_SKILL="$ROOT/shared/skills/fix/SKILL.md"
DESIGN_DECISION_TEMPLATES="$ROOT/shared/skills/design/references/decision-templates.md"
PRODUCT_MANAGER_CHECK="$ROOT/shared/skills/product-manager/scripts/completion_check.sh"
PRODUCT_MANAGER_REVIEWER="$ROOT/shared/skills/product-manager/references/prd-reviewer-prompt.md"

test -f "$DIRECTOR_BRIEF_JSON_TEMPLATE" || fail "missing director brief JSON template: $DIRECTOR_BRIEF_JSON_TEMPLATE"
test -f "$DIRECTOR_PHASE_JSON_TEMPLATE" || fail "missing director phase JSON template: $DIRECTOR_PHASE_JSON_TEMPLATE"
test -f "$MANAGER_BRIEF_TEMPLATE" || fail "missing manager brief template: $MANAGER_BRIEF_TEMPLATE"
test -f "$MANAGER_PHASE_TEMPLATE" || fail "missing manager phase template: $MANAGER_PHASE_TEMPLATE"
test -f "$MANAGER_REVIEW_TEMPLATE" || fail "missing manager review template: $MANAGER_REVIEW_TEMPLATE"
test -f "$MANAGER_REVIEW_CONTRACT" || fail "missing manager review contract: $MANAGER_REVIEW_CONTRACT"
test -d "$PRODUCT_DIRECTOR_ROOT" || fail "missing product-director root: $PRODUCT_DIRECTOR_ROOT"
test -f "$DIRECTOR_PROBLEM_GUIDE" || fail "missing product-director problem clarification guide: $DIRECTOR_PROBLEM_GUIDE"
test -d "$PRODUCT_MANAGER_ROOT" || fail "missing product-manager root: $PRODUCT_MANAGER_ROOT"
test -f "$PRODUCT_ARTIFACT_CONTRACT" || fail "missing product artifact contract: $PRODUCT_ARTIFACT_CONTRACT"
test -f "$PRODUCT_ARTIFACT_TEST" || fail "missing product artifact contract test: $PRODUCT_ARTIFACT_TEST"
test -f "$PRODUCT_MANAGER_MANIFEST" || fail "missing product-manager script manifest: $PRODUCT_MANAGER_MANIFEST"
if [ -d "$PRODUCT_DIRECTOR_ROOT/references/templates" ]; then
  fail "product-director must not retain active references/templates"
fi

jq -e '
  .director_confirmation.locked_fields
  and (.delivery_confirmation? | not)
  and (.review_conclusion? | not)
  and (.issue_ledger? | not)
' "$DIRECTOR_BRIEF_JSON_TEMPLATE" >/dev/null || fail "director brief JSON template must not include Manager-owned closure"
jq -e '
  .phase_goal
  and .entry_conditions
  and .exit_conditions
  and ((.unit_index // []) | type == "array" and length == 0)
  and (.review_conclusion? | not)
  and (.business_flows? | not)
  and (.user_paths? | not)
' "$DIRECTOR_PHASE_JSON_TEMPLATE" >/dev/null || fail "director phase JSON template must not include Manager-owned content"

assert_absent '^## 产品总监确认$' "$MANAGER_BRIEF_TEMPLATE"
assert_present '^## 交付计划承接$' "$MANAGER_BRIEF_TEMPLATE"
assert_present '^## 约束与风险承接$' "$MANAGER_BRIEF_TEMPLATE"
assert_present '^## PM 评审闭环$' "$MANAGER_BRIEF_TEMPLATE"
assert_present '^## 问题台账$' "$MANAGER_BRIEF_TEMPLATE"
assert_present '^## 交付确认$' "$MANAGER_BRIEF_TEMPLATE"
assert_absent 'MVP|前置约束执行映射|scope_item_id|test_ref|SCOPE-P1U1|确认备注' "$MANAGER_BRIEF_TEMPLATE"
assert_absent '^## 共创摘要$' "$MANAGER_BRIEF_TEMPLATE"
assert_absent '^## 审查结论$' "$MANAGER_BRIEF_TEMPLATE"
assert_absent '^## 交接项$' "$MANAGER_BRIEF_TEMPLATE"

assert_present '^## 功能需求（UNIT 索引）$' "$MANAGER_PHASE_TEMPLATE"
assert_present '^\| UNIT \| 标题 \| 闭环目标 \| 优先级 \| 依赖 \| 定义文件 \|$' "$MANAGER_PHASE_TEMPLATE"
assert_present '^## 最终结论$' "$MANAGER_REVIEW_TEMPLATE"
assert_present '^## 审查汇总$' "$MANAGER_REVIEW_TEMPLATE"
assert_present '^## 审查问题台账$' "$MANAGER_REVIEW_TEMPLATE"
assert_present '^## 收敛轮次摘要$' "$MANAGER_REVIEW_TEMPLATE"
assert_present '^## 用户裁决记录$' "$MANAGER_REVIEW_TEMPLATE"
assert_present '^## 未决阻断$' "$MANAGER_REVIEW_TEMPLATE"

assert_present 'name: product-director' "$CHAIN_CONTRACT"
assert_present 'name: product-manager' "$CHAIN_CONTRACT"
assert_absent 'name: product$' "$CHAIN_CONTRACT"
assert_present 'required: \[brief\.json, "phase-\{N\}/phase-prd\.json"\]' "$CHAIN_CONTRACT"
assert_present 'artifact: "phase-\{N\}/units/UNIT-\{N\}\.json"' "$CHAIN_CONTRACT"
assert_present 'key_fields: \[phase_goal, entry_conditions, exit_conditions, business_flows, user_paths, rule_mappings, unit_index, design_decision_candidates, review_conclusion, issue_ledger\]' "$CHAIN_CONTRACT"
assert_absent 'artifact: review\.md|required: \[brief\.md, review\.md|required: \[brief\.md, product-manager-review\.md|required: \[brief\.md' "$CHAIN_CONTRACT"

assert_present '"skill"[[:space:]]*:[[:space:]]*"product-director"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"product-manager"' "$HOOK_REGISTRY"
assert_absent '"skill"[[:space:]]*:[[:space:]]*"product"' "$HOOK_REGISTRY"
assert_registry_codex_supported "$HOOK_REGISTRY" "product-director" "true"
assert_registry_codex_supported "$HOOK_REGISTRY" "product-manager" "true"

python3 - "$PRODUCT_MANAGER_MANIFEST" "$HOOK_REGISTRY" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
registry = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))

script = next(
    item
    for item in manifest["scripts"]
    if item.get("id") == "completion-check"
)
required_script = {
    "id",
    "path",
    "owner",
    "allowed_args",
    "timeout_seconds",
    "output_root",
    "allowed_input_roots",
    "failure_state",
}
missing_script = sorted(required_script - set(script))
if missing_script:
    raise SystemExit(f"product-manager manifest script missing keys: {missing_script}")
if script["owner"] != "product-manager":
    raise SystemExit("product-manager manifest owner mismatch")
if script["path"] != "scripts/completion_check.sh":
    raise SystemExit("product-manager manifest path mismatch")
if not isinstance(script["timeout_seconds"], int) or script["timeout_seconds"] <= 0:
    raise SystemExit("product-manager manifest timeout invalid")

entry = next(
    item
    for item in registry["skill_completion_gates"]
    if item.get("skill") == "product-manager"
)
required_registry = {"owner", "allowed_args", "output_root", "failure_state"}
missing_registry = sorted(required_registry - set(entry))
if missing_registry:
    raise SystemExit(f"product-manager registry missing keys: {missing_registry}")
for field in required_registry:
    if entry[field] != script[field]:
        raise SystemExit(f"product-manager registry and manifest {field} drift")
if entry.get("handler_rel") != f"skills/product-manager/{script['path']}":
    raise SystemExit("product-manager registry and manifest handler drift")
if entry.get("timeout_sec") != script["timeout_seconds"]:
    raise SystemExit("product-manager registry and manifest timeout drift")
PY

assert_absent 'product-shared' "$PRODUCT_DIRECTOR_ROOT/SKILL.md"
assert_absent 'product-shared' "$PRODUCT_MANAGER_ROOT/SKILL.md"
assert_absent '/product ' "$PRODUCT_DIRECTOR_ROOT/SKILL.md"
assert_absent '/product ' "$PRODUCT_MANAGER_ROOT/SKILL.md"
assert_present 'review_conclusion' "$PRODUCT_MANAGER_ROOT/templates/brief.template.json"
assert_present 'issue_ledger' "$PRODUCT_MANAGER_ROOT/templates/brief.template.json"
assert_present 'review_conclusion' "$PRODUCT_MANAGER_ROOT/templates/phase-prd.template.json"
assert_present 'issue_ledger' "$PRODUCT_MANAGER_ROOT/templates/phase-prd.template.json"
assert_present 'references/review-orchestration-contract\.md' "$PRODUCT_MANAGER_ROOT/SKILL.md"
assert_present '^allowed-tools: .*TeamCreate' "$PRODUCT_MANAGER_ROOT/SKILL.md"
assert_present '^allowed-tools: .*Bash' "$PRODUCT_MANAGER_ROOT/SKILL.md"
assert_present 'TeamCreate 协作团队' "$PRODUCT_MANAGER_ROOT/SKILL.md"
assert_present 'validate_product_closure\.py' "$PRODUCT_MANAGER_ROOT/SKILL.md"
assert_absent 'product-manager/scripts/completion_check\.sh|hook payload' "$PRODUCT_MANAGER_ROOT/SKILL.md"
assert_absent '旧 `/product`|旧 /product|已验证实践' "$PRODUCT_MANAGER_ROOT/SKILL.md"
assert_present '高频重复触发 / 批量重放' "$MANAGER_REVIEW_CONTRACT"
assert_present 'M-HG-8' "$PRODUCT_MANAGER_ROOT/SKILL.md"
assert_present 'M-HG-9' "$PRODUCT_MANAGER_ROOT/SKILL.md"
assert_present 'D-S2~D-G1.*references/conversation-guide\.md' "$PRODUCT_DIRECTOR_ROOT/SKILL.md"
assert_absent '^## 对话规则引用$|^## Response Contract$|主导共创规则：' "$PRODUCT_DIRECTOR_ROOT/SKILL.md"
assert_present '主导共创' "$DIRECTOR_PROBLEM_GUIDE"
assert_present '问题框架或 2-3 个选项' "$DIRECTOR_PROBLEM_GUIDE"
assert_present '请确认/选择/修正' "$DIRECTOR_PROBLEM_GUIDE"
assert_present '主导共创' "$MANAGER_CONVERSATION_GUIDE"
assert_present '先给出最佳实践草案、推荐选项和裁决理由' "$MANAGER_CONVERSATION_GUIDE"
assert_present '用户只需要选择、修正或补充业务事实' "$MANAGER_CONVERSATION_GUIDE"

assert_present '/product-manager' "$DESIGN_SKILL"
assert_present '主导技术共创' "$DESIGN_SKILL"
assert_present '先给推荐方案、备选方案和取舍理由' "$DESIGN_SKILL"
assert_present '用户负责裁决和补充领域事实' "$DESIGN_SKILL"
assert_absent 'review\.md' "$DESIGN_SKILL"
assert_present '/product-manager' "$TEST_DESIGN_SKILL"
assert_present '/product-manager' "$TECH_LEAD_SKILL"
assert_absent 'review\.md' "$TECH_LEAD_SKILL"
assert_present '/?product-manager' "$DELIVERY_OWNER_SKILL"
assert_present '/product-director' "$FIX_SKILL"
assert_present '主导技术共创' "$DESIGN_DECISION_TEMPLATES"
assert_present '先给推荐选项' "$DESIGN_DECISION_TEMPLATES"
assert_absent 'product-manager/references/conversation-guide\.md|核心参考：.*product-manager' "$DESIGN_DECISION_TEMPLATES"
assert_absent 'shared/skills/product/scripts/completion_check\.sh' "$PRODUCT_MANAGER_CHECK"
assert_absent '^LEGACY_PRODUCT_CHECK=' "$PRODUCT_MANAGER_CHECK"
assert_absent 'REVIEW_FILE="\$FEATURE_DIR/product-manager-review\.md"' "$PRODUCT_MANAGER_CHECK"
assert_present 'validate_canonical_schema\.py' "$PRODUCT_MANAGER_CHECK"
assert_present 'validate_product_closure\.py' "$PRODUCT_MANAGER_CHECK"
assert_present 'R13' "$PRODUCT_MANAGER_REVIEWER"
assert_present 'PR-C1' "$PRODUCT_MANAGER_REVIEWER"
assert_present 'test-product-artifact-contract\.sh' "$0"

echo "[PASS] product role split contract"
