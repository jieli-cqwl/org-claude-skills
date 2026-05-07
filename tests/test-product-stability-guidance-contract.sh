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
DIRECTOR_PROBLEM_GUIDE="$ROOT/shared/skills/product-director/references/problem-clarification.md"
DIRECTOR_SUCCESS_GUIDE="$ROOT/shared/skills/product-director/references/success-appetite.md"
DIRECTOR_SEMANTICS_GUIDE="$ROOT/shared/skills/product-director/references/business-semantics.md"
DIRECTOR_SCOPE_GUIDE="$ROOT/shared/skills/product-director/references/scope-constraints.md"
DIRECTOR_RISKS_GUIDE="$ROOT/shared/skills/product-director/references/risks-unknowns.md"
DIRECTOR_PHASE_GUIDE="$ROOT/shared/skills/product-director/references/phase-planning.md"
CHECK_SCRIPT="$ROOT/shared/skills/product-director/scripts/completion_check.sh"
SCRIPT_MANIFEST="$ROOT/shared/skills/product-director/scripts/manifest.json"
OUTPUT_CONTRACT="$ROOT/shared/skills/product-director/references/output-contract.md"
HOOK_REGISTRY="$ROOT/shared/hooks/registry.json"
DIRECTOR_BRIEF_JSON_TEMPLATE="$ROOT/shared/skills/product-director/templates/brief.template.json"
DIRECTOR_PHASE_JSON_TEMPLATE="$ROOT/shared/skills/product-director/templates/phase-prd.template.json"

test -f "$SKILL" || fail "missing director skill: $SKILL"
test -f "$CONVERSATION_GUIDE" || fail "missing director conversation guide: $CONVERSATION_GUIDE"
test -f "$DIRECTOR_PROBLEM_GUIDE" || fail "missing director problem clarification guide: $DIRECTOR_PROBLEM_GUIDE"
test -f "$DIRECTOR_SUCCESS_GUIDE" || fail "missing director success/appetite guide: $DIRECTOR_SUCCESS_GUIDE"
test -f "$DIRECTOR_SEMANTICS_GUIDE" || fail "missing director business semantics guide: $DIRECTOR_SEMANTICS_GUIDE"
test -f "$DIRECTOR_SCOPE_GUIDE" || fail "missing director scope/constraints guide: $DIRECTOR_SCOPE_GUIDE"
test -f "$DIRECTOR_RISKS_GUIDE" || fail "missing director risks/unknowns guide: $DIRECTOR_RISKS_GUIDE"
test -f "$DIRECTOR_PHASE_GUIDE" || fail "missing director phase planning guide: $DIRECTOR_PHASE_GUIDE"
test -f "$CHECK_SCRIPT" || fail "missing director completion check: $CHECK_SCRIPT"
test -f "$SCRIPT_MANIFEST" || fail "missing director script manifest: $SCRIPT_MANIFEST"
test -f "$OUTPUT_CONTRACT" || fail "missing director output contract: $OUTPUT_CONTRACT"
test -f "$HOOK_REGISTRY" || fail "missing hook registry: $HOOK_REGISTRY"
test -f "$DIRECTOR_BRIEF_JSON_TEMPLATE" || fail "missing director brief JSON template: $DIRECTOR_BRIEF_JSON_TEMPLATE"
test -f "$DIRECTOR_PHASE_JSON_TEMPLATE" || fail "missing director phase JSON template: $DIRECTOR_PHASE_JSON_TEMPLATE"
if [ -d "$ROOT/shared/skills/product-director/references/templates" ]; then
  fail "product-director must not retain active references/templates"
fi
if find "$ROOT/shared/skills/product-director/references" -maxdepth 1 -type f -name 'd-s*.md' | rg . >/dev/null 2>&1; then
  fail "product-director reference filenames must use semantic names, not D-S step prefixes"
fi

assert_present '^name: product-director$' "$SKILL"
assert_present '^allowed-tools: .*Bash' "$SKILL"
assert_absent '^## 流程总览$' "$SKILL"
assert_present '^## 流程图$' "$SKILL"
assert_absent '^## 流程导航$' "$SKILL"
assert_absent '节点顺序：' "$SKILL"
assert_present '"D-S1 静默信息收集" -> "D-S2 问题与用户澄清"' "$SKILL"
assert_present '"D-S6 Phase 规划" -> "Pause D-S6 Phase 假设未闭合" -> "D-G1 总监确认门"' "$SKILL"
assert_absent 'brief\.lock\.json|phase-\{N\}/prd\.lock\.json|历史 product-artifact 兼容校验' "$SKILL"
assert_present '/product-manager' "$SKILL"
assert_present 'references/problem-clarification\.md' "$SKILL"
assert_present 'references/success-appetite\.md' "$SKILL"
assert_present 'references/business-semantics\.md' "$SKILL"
assert_present 'references/scope-constraints\.md' "$SKILL"
assert_present 'references/risks-unknowns\.md' "$SKILL"
assert_present 'references/phase-planning\.md' "$SKILL"
assert_present 'references/conversation-guide\.md' "$SKILL"
assert_absent 'references/d-s[0-9]' "$SKILL"
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

assert_present '共创回合协议' "$CONVERSATION_GUIDE"
assert_present '业务事实回应处理' "$CONVERSATION_GUIDE"
assert_present '模式差异' "$CONVERSATION_GUIDE"
assert_present '方案输入处理' "$CONVERSATION_GUIDE"
assert_present '推荐结论、推荐理由和会改变结论的未闭合业务假设' "$CONVERSATION_GUIDE"
assert_present '回应中的业务事实支撑关键假设时，将推荐结论作为当前步骤结论写入 checkpoint' "$CONVERSATION_GUIDE"
assert_present '回应包含已闭合上游事实的替换事实时，回到该事实的拥有步骤重新闭合' "$CONVERSATION_GUIDE"
assert_present '深度路由' "$CONVERSATION_GUIDE"
assert_present '确认门自检' "$CONVERSATION_GUIDE"
assert_absent 'D-S2~D-G1|D-S1 候选线索|全共创用于 D-S|草案修正用于 D-S|^## D-G1 前自检$|\| D-S[0-9]' "$CONVERSATION_GUIDE"
assert_absent '本文件只承载|跨环节复用的基础对话规则|^## 使用边界$|^## 裁决问题格式$|^## 主导共创$|^## 沟通风格$|^## 每轮共创收口$|^## 对话节奏$|^## 交互模式$|为了共创|专业判断拆给用户' "$CONVERSATION_GUIDE"
assert_absent '最佳实践推荐 \+ 业务适配裁决|PM 最佳实践推荐 \+ 业务适配裁决|业务适配|适配你的业务|必要时给 2-3 个选项|推荐选项|请确认 / 选择 / 修正|多选题优先|用户只做选择|让用户选择最接近' "$CONVERSATION_GUIDE"
assert_present '用户画像|当前绕行方式' "$DIRECTOR_PROBLEM_GUIDE"
assert_absent '让用户选择最接近' "$DIRECTOR_PROBLEM_GUIDE"
assert_absent '^## 主导共创$' "$DIRECTOR_PROBLEM_GUIDE"
assert_present '价值假设验证' "$DIRECTOR_SUCCESS_GUIDE"
assert_present 'Appetite' "$DIRECTOR_SUCCESS_GUIDE"
assert_present 'MVP 范围界定' "$DIRECTOR_SCOPE_GUIDE"
assert_present 'Director / Manager 边界' "$DIRECTOR_SCOPE_GUIDE"
assert_present 'Rabbit Holes|风险与未知项' "$DIRECTOR_RISKS_GUIDE"

assert_present 'shared/skills/product-director/templates/brief\.template\.json' "$OUTPUT_CONTRACT"
assert_present 'shared/skills/product-director/templates/phase-prd\.template\.json' "$OUTPUT_CONTRACT"
assert_absent 'brief\.lock\.json|prd\.lock\.json|contracts/product-artifacts\.yaml' "$OUTPUT_CONTRACT"

assert_present '共创回合协议' "$CONVERSATION_GUIDE"
assert_present '验证关键业务假设.*references/conversation-guide\.md|references/conversation-guide\.md.*共创回合协议' "$SKILL"
assert_present '不从该文件推导根问题、成功标准、范围、风险、Phase 规划或输出字段' "$SKILL"
assert_present '关键假设验证、暂停点和确认门自检不得产生业务结论' "$SKILL"
assert_absent '^## 对话规则引用$' "$SKILL"
assert_absent '^## Response Contract$|主导共创规则：' "$SKILL"
assert_present '不复制阶段流水账' "$DIRECTOR_SEMANTICS_GUIDE"
assert_present '默认单 Phase' "$DIRECTOR_PHASE_GUIDE"
assert_present '只能在总监确认门收到明确 `产品总监确认`' "$DIRECTOR_PHASE_GUIDE"
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
