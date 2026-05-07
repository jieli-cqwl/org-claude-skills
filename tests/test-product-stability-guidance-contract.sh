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
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected pattern in $file: $pattern"
  fi
}

SKILL="$ROOT/shared/skills/product-director/SKILL.md"
CONVERSATION_GUIDE="$ROOT/shared/skills/product-director/references/conversation-guide.md"
DIRECTOR_D_S2="$ROOT/shared/skills/product-director/references/d-s2-problem-clarification.md"
DIRECTOR_D_S3="$ROOT/shared/skills/product-director/references/d-s3-success-appetite.md"
DIRECTOR_D_S4="$ROOT/shared/skills/product-director/references/d-s4-business-semantics.md"
DIRECTOR_D_S5="$ROOT/shared/skills/product-director/references/d-s5-scope-constraints.md"
DIRECTOR_D_S55="$ROOT/shared/skills/product-director/references/d-s55-risks-unknowns.md"
DIRECTOR_D_S6="$ROOT/shared/skills/product-director/references/d-s6-phase-planning.md"
CHECK_SCRIPT="$ROOT/shared/skills/product-director/scripts/completion_check.sh"
SCRIPT_MANIFEST="$ROOT/shared/skills/product-director/scripts/manifest.json"
OUTPUT_CONTRACT="$ROOT/shared/skills/product-director/references/output-contract.md"
HOOK_REGISTRY="$ROOT/shared/hooks/registry.json"
DIRECTOR_BRIEF_JSON_TEMPLATE="$ROOT/shared/skills/product-director/templates/brief.template.json"
DIRECTOR_PHASE_JSON_TEMPLATE="$ROOT/shared/skills/product-director/templates/phase-prd.template.json"

test -f "$SKILL" || fail "missing director skill: $SKILL"
test -f "$CONVERSATION_GUIDE" || fail "missing director conversation guide: $CONVERSATION_GUIDE"
test -f "$DIRECTOR_D_S2" || fail "missing director D-S2 reference: $DIRECTOR_D_S2"
test -f "$DIRECTOR_D_S3" || fail "missing director D-S3 reference: $DIRECTOR_D_S3"
test -f "$DIRECTOR_D_S4" || fail "missing director D-S4 reference: $DIRECTOR_D_S4"
test -f "$DIRECTOR_D_S5" || fail "missing director D-S5 reference: $DIRECTOR_D_S5"
test -f "$DIRECTOR_D_S55" || fail "missing director D-S5.5 reference: $DIRECTOR_D_S55"
test -f "$DIRECTOR_D_S6" || fail "missing director D-S6 reference: $DIRECTOR_D_S6"
test -f "$CHECK_SCRIPT" || fail "missing director completion check: $CHECK_SCRIPT"
test -f "$SCRIPT_MANIFEST" || fail "missing director script manifest: $SCRIPT_MANIFEST"
test -f "$OUTPUT_CONTRACT" || fail "missing director output contract: $OUTPUT_CONTRACT"
test -f "$HOOK_REGISTRY" || fail "missing hook registry: $HOOK_REGISTRY"
test -f "$DIRECTOR_BRIEF_JSON_TEMPLATE" || fail "missing director brief JSON template: $DIRECTOR_BRIEF_JSON_TEMPLATE"
test -f "$DIRECTOR_PHASE_JSON_TEMPLATE" || fail "missing director phase JSON template: $DIRECTOR_PHASE_JSON_TEMPLATE"
if [ -d "$ROOT/shared/skills/product-director/references/templates" ]; then
  fail "product-director must not retain active references/templates"
fi

assert_present '^name: product-director$' "$SKILL"
assert_present '^allowed-tools: .*Bash' "$SKILL"
assert_absent '^## 流程总览$' "$SKILL"
assert_present '^## 流程图$' "$SKILL"
assert_absent '^## 流程导航$' "$SKILL"
assert_absent '节点顺序：' "$SKILL"
assert_present '"D-S1 静默信息收集" -> "D-S2 问题与用户澄清"' "$SKILL"
assert_present '"D-S6 Phase 规划" -> "Pause D-S6 等待用户修正" -> "D-G1 总监确认门"' "$SKILL"
assert_absent 'brief\.lock\.json|phase-\{N\}/prd\.lock\.json|历史 product-artifact 兼容校验' "$SKILL"
assert_present '/product-manager' "$SKILL"
assert_present 'references/d-s2-problem-clarification\.md' "$SKILL"
assert_present 'references/d-s3-success-appetite\.md' "$SKILL"
assert_present 'references/d-s4-business-semantics\.md' "$SKILL"
assert_present 'references/d-s5-scope-constraints\.md' "$SKILL"
assert_present 'references/d-s55-risks-unknowns\.md' "$SKILL"
assert_present 'references/d-s6-phase-planning\.md' "$SKILL"
assert_present 'references/conversation-guide\.md' "$SKILL"
assert_absent 'references/product-thinking-contract\.md|references/phase-splitting-guide\.md' "$SKILL"
assert_absent 'standard-chain' "$SKILL"
assert_absent 'canonical' "$SKILL"
assert_absent '资源路由：Trigger:' "$SKILL"
assert_absent 'Trigger:|Read:|Expect:|Consume:|Evidence:|Sync:' "$SKILL"
assert_absent '^## 按需 references$' "$SKILL"
assert_absent '按需读取|需要时|若需要|落盘|真源|当前 eval|当前验证命令|等价证据引用|可委派|尽量' "$SKILL"
assert_absent '仅说明性润色' "$SKILL"
assert_absent 'product-shared' "$SKILL"
assert_absent '旧 `/product`|旧 /product|已验证实践' "$SKILL"

assert_present '对话节奏' "$CONVERSATION_GUIDE"
assert_present '第一性原理追问' "$CONVERSATION_GUIDE"
assert_present '警示信号' "$CONVERSATION_GUIDE"
assert_present 'Director 关键追问点' "$CONVERSATION_GUIDE"
assert_present '深度路由' "$CONVERSATION_GUIDE"
assert_present 'D-G1 前自检' "$CONVERSATION_GUIDE"
assert_present '用户画像|当前绕行方式' "$DIRECTOR_D_S2"
assert_present '价值假设验证' "$DIRECTOR_D_S3"
assert_present 'Appetite' "$DIRECTOR_D_S3"
assert_present 'MVP 范围界定' "$DIRECTOR_D_S5"
assert_present 'Director / Manager 边界' "$DIRECTOR_D_S5"
assert_present 'Rabbit Holes|风险与未知项' "$DIRECTOR_D_S55"

assert_present 'shared/skills/product-director/templates/brief\.template\.json' "$OUTPUT_CONTRACT"
assert_present 'shared/skills/product-director/templates/phase-prd\.template\.json' "$OUTPUT_CONTRACT"
assert_absent 'brief\.lock\.json|prd\.lock\.json|contracts/product-artifacts\.yaml' "$OUTPUT_CONTRACT"

assert_present '主导共创' "$CONVERSATION_GUIDE"
assert_present 'D-S2~D-G1.*references/conversation-guide\.md' "$SKILL"
assert_present 'D-S2~D-S6 的业务口径只读取各自 D-Sx 扩展文件' "$SKILL"
assert_absent '^## 对话规则引用$' "$SKILL"
assert_absent '^## Response Contract$|主导共创规则：' "$SKILL"
assert_present '不复制阶段流水账' "$DIRECTOR_D_S4"
assert_present '默认单 Phase' "$DIRECTOR_D_S6"
assert_present '只能在 D-G1 用户明确 `产品总监确认`' "$DIRECTOR_D_S6"
assert_present 'validate_director_confirmation' "$CHECK_SCRIPT"
assert_present 'validate_director_lock' "$CHECK_SCRIPT"
assert_present 'validate_director_boundary' "$CHECK_SCRIPT"
jq -e '
  .schema_version == "1.0.0"
  and (.scripts | length == 1)
  and .scripts[0].id == "completion-check"
  and .scripts[0].path == "scripts/completion_check.sh"
  and .scripts[0].owner == "product-director"
  and (.scripts[0].allowed_args | index("hook payload via stdin only"))
  and .scripts[0].timeout_seconds == 15
  and .scripts[0].output_root == "."
  and (.scripts[0].allowed_output_roots | index("$TMPDIR"))
  and (.scripts[0].allowed_input_roots | index("docs"))
  and (.scripts[0].failure_state | test("blocks handoff"))
' "$SCRIPT_MANIFEST" >/dev/null
jq -e '
  .skill_completion_gates[]
  | select(.skill == "product-director")
  | .owner == "product-director"
    and (.allowed_args | index("hook payload via stdin only"))
    and (.allowed_args | index("--help"))
    and (.allowed_args | index("-h"))
    and .timeout_sec == 15
    and .output_root == "."
    and (.failure_state | test("blocks handoff"))
' "$HOOK_REGISTRY" >/dev/null
jq -e '.director_confirmation.locked_fields and (.unit_index? // empty | arrays)' "$DIRECTOR_PHASE_JSON_TEMPLATE" >/dev/null
jq -e '.director_confirmation.locked_fields and (.review_conclusion? | not)' "$DIRECTOR_BRIEF_JSON_TEMPLATE" >/dev/null
jq -e '
  .user_profile
  and .appetite
  and .non_goals
  and .feasibility_constraints
  and .risks_and_unknowns
  and .decision_rationale
' "$DIRECTOR_BRIEF_JSON_TEMPLATE" >/dev/null
jq -e '((.unit_index // []) | type == "array" and length == 0)' "$DIRECTOR_PHASE_JSON_TEMPLATE" >/dev/null

echo "[PASS] product stability guidance contract"
