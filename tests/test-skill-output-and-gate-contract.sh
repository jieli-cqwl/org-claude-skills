#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg
COMMON_SH="$ROOT/shared/hooks/lib/common.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/tmp/org_skill_gate_absent.out 2>&1; then
    cat /tmp/org_skill_gate_absent.out >&2
    fail "unexpected pattern in $file: $pattern"
  fi
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

assert_no_legacy_review_artifact_ref() {
  local file="$1"
  assert_absent 'product-[^[:space:]`"]*review\.md' "$file"
  assert_absent 'design-[^[:space:]`"]*review\.md' "$file"
  assert_absent 'testdesign-[^[:space:]`"]*review\.md' "$file"
}

extract_function_body() {
  local function_name="$1"
  local file="$2"
  awk -v function_name="$function_name" '
    $0 ~ ("^[[:space:]]*" function_name "\\(\\)[[:space:]]*\\{") { in_func=1 }
    in_func { print }
    in_func && $0 ~ /^[[:space:]]*}[[:space:]]*$/ { exit }
  ' "$file"
}

assert_confirmation_time_contract() {
  local file="$1"
  local label="$2"
  local placeholder_func
  local valid_time_func
  local script_content

  # 函数可能在脚本本地定义或在公共库 common.sh 中定义
  placeholder_func="$(extract_function_body "is_placeholder_text" "$file")"
  [ -n "$placeholder_func" ] || placeholder_func="$(extract_function_body "is_placeholder_text" "$COMMON_SH")"
  valid_time_func="$(extract_function_body "is_valid_confirmation_time" "$file")"
  [ -n "$valid_time_func" ] || valid_time_func="$(extract_function_body "is_valid_confirmation_time" "$COMMON_SH")"
  [ -n "$placeholder_func" ] || fail "${label}: missing is_placeholder_text()"
  [ -n "$valid_time_func" ] || fail "${label}: missing is_valid_confirmation_time()"

  script_content="$(printf '%s\n%s\n%s\n' "$placeholder_func" "$valid_time_func" "is_valid_confirmation_time \"\$TEST_VALUE\"")"

  if TEST_VALUE="YYYY-MM-DD HH:mm" bash -s >/dev/null 2>&1 <<<"$script_content"; then
    fail "${label}: placeholder time unexpectedly passes"
  fi
  if ! TEST_VALUE="2026-03-26 18:00" bash -s >/dev/null 2>&1 <<<"$script_content"; then
    fail "${label}: valid confirmation time unexpectedly fails"
  fi
  if TEST_VALUE="2026/03/26 18:00" bash -s >/dev/null 2>&1 <<<"$script_content"; then
    fail "${label}: invalid format unexpectedly passes"
  fi
}

run_completion_check_with_payload() {
  local script="$1"
  local root_dir="$2"
  local session_id="$3"
  local transcript_entries="$4"
  local tool_name="${5:-}"
  local file_path="${6:-}"
  local transcript_path="$root_dir/transcript.log"
  local payload

  printf '%b' "$transcript_entries" > "$transcript_path"

  if [ -n "$tool_name" ] || [ -n "$file_path" ]; then
    payload="$(jq -nc \
      --arg cwd "$root_dir" \
      --arg sid "$session_id" \
      --arg tp "$transcript_path" \
      --arg tn "$tool_name" \
      --arg fp "$file_path" \
      '{cwd:$cwd, session_id:$sid, transcript_path:$tp, tool_name:$tn, tool_input:(if $fp == "" then {} else {file_path:$fp} end)}')"
  else
    payload="$(jq -nc \
      --arg cwd "$root_dir" \
      --arg sid "$session_id" \
      --arg tp "$transcript_path" \
      '{cwd:$cwd, session_id:$sid, transcript_path:$tp}')"
  fi

  LAST_CHECK_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/org-hook-check.XXXXXX")"
  if bash "$script" >"$LAST_CHECK_OUTPUT" 2>&1 <<<"$payload"; then
    LAST_CHECK_STATUS=0
  else
    LAST_CHECK_STATUS=$?
  fi
}

assert_last_check_passes() {
  local label="$1"
  if [ "${LAST_CHECK_STATUS:-1}" -ne 0 ]; then
    cat "$LAST_CHECK_OUTPUT" >&2
    fail "${label}: expected completion_check to pass"
  fi
}

assert_last_check_fails_with() {
  local label="$1"
  local pattern="$2"
  if [ "${LAST_CHECK_STATUS:-0}" -eq 0 ]; then
    cat "$LAST_CHECK_OUTPUT" >&2
    fail "${label}: expected completion_check to fail"
  fi
  rg -n "$pattern" "$LAST_CHECK_OUTPUT" >/dev/null 2>&1 || {
    cat "$LAST_CHECK_OUTPUT" >&2
    fail "${label}: missing failure pattern: $pattern"
  }
}

assert_last_check_absent() {
  local label="$1"
  local pattern="$2"
  if rg -n "$pattern" "$LAST_CHECK_OUTPUT" >/tmp/org_skill_gate_last_absent.out 2>&1; then
    cat /tmp/org_skill_gate_last_absent.out >&2
    cat "$LAST_CHECK_OUTPUT" >&2
    fail "${label}: unexpected output pattern: $pattern"
  fi
}

create_tech_lead_fixture() {
  local root_dir="$1"
  local feature_name="$2"
  local design_decision_status="$3"
  local include_future_task="$4"
  local replan_variant="$5"
  local revision_variant="$6"

  local feature_dir="$root_dir/docs/$feature_name"
  local phase_dir="$feature_dir/phase-1"

  mkdir -p "$feature_dir/units" "$phase_dir/unit-1" "$phase_dir/design"

  cat > "$feature_dir/prd.md" <<'EOF'
# PRD

## 前置约束
- 无前置约束（经评估）
EOF

  cat > "$feature_dir/units/UNIT-1.md" <<'EOF'
# UNIT-1
EOF

  cat > "$phase_dir/design.md" <<'EOF'
# design

## 覆盖表
| UNIT | requirement_type | requirement_ref | requirement_desc | scope_item_id | design_ref | status |
|------|------------------|-----------------|------------------|---------------|------------|--------|
| UNIT-1 | AC | AC-U1-01 | 探索实施边界 | SCOPE-P1U1-001 | MOD-001 | COVERED |
EOF

  if [ "$include_future_task" = "yes" ]; then
    cat >> "$phase_dir/design.md" <<'EOF'
| UNIT-1 | AC | AC-U1-02 | 后续实施任务 | SCOPE-P1U1-002 | MOD-001 | COVERED |
EOF
  fi

  cat >> "$phase_dir/design.md" <<'EOF'

## 影响范围清单
- SCOPE-P1U1-001: 探索实现路径
EOF

  if [ "$include_future_task" = "yes" ]; then
    cat >> "$phase_dir/design.md" <<'EOF'
- SCOPE-P1U1-002: 后续实施落地
EOF
  fi

  cat > "$phase_dir/design/MOD-001.md" <<'EOF'
# MOD-001
EOF

  cat > "$phase_dir/unit-1/test-cases.md" <<'EOF'
# test-cases

### TC-U1-001: 探索任务验证
EOF

  if [ "$include_future_task" = "yes" ]; then
    cat >> "$phase_dir/unit-1/test-cases.md" <<'EOF'

### TC-U1-002: 后续任务验证
EOF
  fi

  cat > "$phase_dir/design-review-1.md" <<'EOF'
# design-review

- REVIEW: DESIGN_OK
EOF

  cat > "$phase_dir/plan.md" <<EOF
# plan.md

## 输入分析
复杂项目探索模式 gate 测试

## 计划模式
- 计划模式: 探索优先
- 采用原因: 需要先验证实施可行性
- 面向执行方: AI
- 设计决策状态: ${design_decision_status}

## Design 评审结论
- REVIEW: DESIGN_OK
- 评审摘要：设计可承接
- 关键结论：允许进入实施计划

## PRD 前置约束映射
| Constraint ID | 类型 | 约束内容 | Owner | 影响 UNIT | scope_item_id | preflight_ref | test_ref | 映射 Task | 验收证据 | 状态 |
|---------------|------|----------|-------|-----------|---------------|---------------|----------|-----------|----------|------|

## PRD / Design 覆盖矩阵
| UNIT | requirement_type | requirement_ref | requirement_desc | scope_item_id | design_ref | Task | test_ref | 影响分析 | 覆盖状态 |
|------|------------------|-----------------|------------------|---------------|------------|------|----------|----------|----------|
| UNIT-1 | AC | AC-U1-01 | 探索实施边界 | SCOPE-P1U1-001 | MOD-001 | Task-1 | TC-U1-001 | impact_files 已标注 | COVERED |
EOF

  if [ "$include_future_task" = "yes" ]; then
    cat >> "$phase_dir/plan.md" <<'EOF'
| UNIT-1 | AC | AC-U1-02 | 后续实施任务 | SCOPE-P1U1-002 | MOD-001 | Task-2 | TC-U1-002 | impact_files 已标注 | COVERED |
EOF
  fi

  cat >> "$phase_dir/plan.md" <<'EOF'

## Scope Freeze 与映射矩阵
| scope_item_id | 变更类型 | 风险等级 | 映射 Task | test_ref | impact_files | rollback_ref | 状态 |
|---------------|----------|----------|-----------|----------|--------------|--------------|------|
| SCOPE-P1U1-001 | 探索验证 | P1 | Task-1 | TC-U1-001 | src/explore.ts | plan.md#回滚策略-1 | FROZEN |
EOF

  if [ "$include_future_task" = "yes" ]; then
    cat >> "$phase_dir/plan.md" <<'EOF'
| SCOPE-P1U1-002 | 后续实施 | P1 | Task-2 | TC-U1-002 | src/followup.ts | plan.md#回滚策略-2 | FROZEN |
EOF
  fi

  cat >> "$phase_dir/plan.md" <<'EOF'

## Task 清单

### Task-1: 探索可行性
- 文件: src/explore.ts (Create)
- task_type: 探索
- unit_ref: UNIT-1
- design_ref: MOD-001
- scope_item_ref: SCOPE-P1U1-001
- constraint_ref: 无
- api_ref: 无接口交互
- test_ref: TC-U1-001
- hypothesis: 当前路径可在约束内落地
- success_signal: 方案验证通过并可继续实施
- failure_signal: 方案验证失败且需要调整路径
- unlock_condition: 刷新 plan.md 后允许继续
- complexity: S
- AC:
  1. 输出明确验证结论
  2. 输出下一步执行条件
- depends_on: []
- shared_files: []
- impact_files:
  - src/explore.ts: 新建探索任务文件
EOF

  if [ "$include_future_task" = "yes" ]; then
    cat >> "$phase_dir/plan.md" <<'EOF'

### Task-2: 后续实施
- 文件: src/followup.ts (Create)
- task_type: 实施
- unit_ref: UNIT-1
- design_ref: MOD-001
- scope_item_ref: SCOPE-P1U1-002
- constraint_ref: 无
- api_ref: 无接口交互
- test_ref: TC-U1-002
- hypothesis: 无
- success_signal: 无
- failure_signal: 无
- unlock_condition: 无
- complexity: S
- split_reason: 按实施边界拆分
- AC:
  1. 完成后续实施任务
- depends_on: [Task-1]
- shared_files: []
- impact_files:
  - src/followup.ts: 新建后续实施文件
EOF
  fi

  cat >> "$phase_dir/plan.md" <<'EOF'

## 依赖关系
- Task-1 depends_on: []
EOF

  if [ "$include_future_task" = "yes" ]; then
    cat >> "$phase_dir/plan.md" <<'EOF'
- Task-2 depends_on: {Task-1}
EOF
  fi

  cat >> "$phase_dir/plan.md" <<'EOF'

## 并行策略
并行策略：串行执行（按 Task 顺序执行）

## 再计划与解锁规则
EOF

  case "$replan_variant" in
    complete)
      cat >> "$phase_dir/plan.md" <<'EOF'
- 标准实施: N/A
- 探索优先:
  - 当前已解锁批次: Task-1
  - 再计划触发条件: 探索结果改变后续执行边界
  - 必须回到用户确认的条件: 改变路线或风险接受度
  - 停止条件: 探索失败或无法确认下一步
  - 解锁方式: 刷新 plan.md 后才允许继续
EOF
      ;;
    missing_fields)
      cat >> "$phase_dir/plan.md" <<'EOF'
- 标准实施: N/A
- 探索优先:
  - 当前已解锁批次: Task-1
EOF
      ;;
  esac

  cat >> "$phase_dir/plan.md" <<'EOF'

## 计划修订记录
| 版本 | 触发原因 | 变更摘要 | 是否已重新确认 |
|------|----------|----------|----------------|
EOF

  case "$revision_variant" in
    valid)
      cat >> "$phase_dir/plan.md" <<'EOF'
| v1 | 初版计划 | 首次输出当前解锁批次 | 是 |
EOF
      ;;
    placeholder)
      cat >> "$phase_dir/plan.md" <<'EOF'
| {版本} | {触发原因} | {变更摘要} | {是否已重新确认} |
EOF
      ;;
  esac

  cat >> "$phase_dir/plan.md" <<'EOF'

## Phase 3 审查分级
审查分级: 标准

判定依据:
- 标准: 当前批次需要代码审查和关键验收

强门禁矩阵:
- 轻量: REVIEW_A + QA_A
- 标准: REVIEW_A + REVIEW_B + QA_A + QA_C
- 完整: REVIEW_A + REVIEW_B + QA_A + QA_B + QA_C + QA_D
- REVIEW_C 仅作为可选增强审查，不进入 /project-manager 的强门禁判定

## 独立审查收敛
独立审查收敛状态: REVIEW_PASS

## 前置验证点
- 校验探索输入

## 关键里程碑
- 完成探索批次

## 风险与执行注意事项
- 严格按当前解锁批次执行

## 用户确认记录
- 确认状态: 确认
- 确认时间: 2026-04-08 10:00
- 确认备注: 允许进入探索批次

## 交接项
- 当前计划仅包含当前已解锁批次

## 回滚策略

### 回滚策略-1
- 回滚探索输出

### 回滚策略-2
- 回滚后续实施输出
EOF
}

run_tech_lead_completion_check() {
  local root_dir="$1"
  local feature_name="$2"
  local session_id="$3"
  local transcript_path="$root_dir/transcript.log"

  printf 'docs/%s/phase-1/plan.md\n' "$feature_name" > "$transcript_path"

  TECH_LEAD_LAST_OUTPUT="$(mktemp "$TECH_LEAD_FIXTURE_ROOT/tech-lead-output.XXXXXX")"
  if HOOK_STRICT_BLOCK=1 bash "$TECH_LEAD_CHECK" \
    >"$TECH_LEAD_LAST_OUTPUT" 2>&1 \
    <<<"{\"cwd\":\"$root_dir\",\"session_id\":\"$session_id\",\"transcript_path\":\"$transcript_path\"}"; then
    TECH_LEAD_LAST_STATUS=0
  else
    TECH_LEAD_LAST_STATUS=$?
  fi
}

assert_tech_lead_check_passes() {
  local label="$1"
  if [ "${TECH_LEAD_LAST_STATUS:-1}" -ne 0 ]; then
    cat "$TECH_LEAD_LAST_OUTPUT" >&2
    fail "${label}: expected completion_check to pass"
  fi
}

assert_tech_lead_check_fails_with() {
  local label="$1"
  local pattern="$2"
  if [ "${TECH_LEAD_LAST_STATUS:-0}" -eq 0 ]; then
    cat "$TECH_LEAD_LAST_OUTPUT" >&2
    fail "${label}: expected completion_check to fail"
  fi
  rg -n "$pattern" "$TECH_LEAD_LAST_OUTPUT" >/dev/null 2>&1 || {
    cat "$TECH_LEAD_LAST_OUTPUT" >&2
    fail "${label}: missing failure pattern: $pattern"
  }
}

PRODUCT_SKILL="$ROOT/shared/skills/product/SKILL.md"
DESIGN_SKILL="$ROOT/shared/skills/design/SKILL.md"
TEST_DESIGN_SKILL="$ROOT/shared/skills/test-design/SKILL.md"
TECH_LEAD_SKILL="$ROOT/shared/skills/tech-lead/SKILL.md"
PM_SKILL="$ROOT/shared/skills/project-manager/SKILL.md"
REVIEW_SKILL="$ROOT/shared/skills/review/SKILL.md"
QA_SKILL="$ROOT/shared/skills/qa/SKILL.md"
PRODUCT_PRD_REVIEWER_PROMPT="$ROOT/shared/skills/product/references/prd-reviewer-prompt.md"
PRODUCT_ARCH_REVIEWER_PROMPT="$ROOT/shared/skills/product/references/architect-reviewer-prompt.md"
PRODUCT_TEST_REVIEWER_PROMPT="$ROOT/shared/skills/product/references/tester-reviewer-prompt.md"
DESIGN_ARCH_REVIEWER_PROMPT="$ROOT/shared/skills/design/references/design-reviewer-prompt.md"
DESIGN_PRODUCT_REVIEWER_PROMPT="$ROOT/shared/skills/design/references/design-product-reviewer-prompt.md"
DESIGN_TEST_REVIEWER_PROMPT="$ROOT/shared/skills/design/references/design-test-reviewer-prompt.md"
REVIEW_SAFETY_PROMPT="$ROOT/shared/skills/review/references/code-safety-reviewer-prompt.md"
REVIEW_MAINTAINABILITY_PROMPT="$ROOT/shared/skills/review/references/code-maintainability-reviewer-prompt.md"
REVIEW_PERFORMANCE_PROMPT="$ROOT/shared/skills/review/references/code-performance-reviewer-prompt.md"
REVIEW_TEMPLATE="$ROOT/shared/skills/review/references/templates/code-review-report-template.md"
REVIEW_VERIFICATION_PROTOCOL="$ROOT/shared/skills/review/references/verification-protocol.md"
COMMIT_SKILL="$ROOT/shared/skills/commit/SKILL.md"
PRODUCT_CONVERSATION_GUIDE="$ROOT/shared/skills/product/references/conversation-guide.md"
DESIGN_DECISION_TEMPLATES="$ROOT/shared/skills/design/references/decision-templates.md"
PM_PHASE3_DOC="$ROOT/shared/skills/project-manager/references/phase3-dispatch.md"
PHASE_SELECTION_PROTOCOL="$ROOT/shared/protocols/phase-selection-protocol.md"
PRODUCT_CHECK="$ROOT/shared/skills/product/scripts/completion_check.sh"
CHAIN_CONTRACT="$ROOT/contracts/skill-chain.yaml"
DESIGNER_AGENT="$ROOT/shared/agents/designer.md"
TEST_DESIGNER_AGENT="$ROOT/shared/agents/test-designer.md"
TECH_LEAD_AGENT="$ROOT/shared/agents/tech-lead.md"
HARD_GATE_GRADER="$ROOT/tools/eval/graders/hard-gate-grader.md"
EVAL_RUNNER="$ROOT/tools/eval/run_skill_eval.sh"
EVAL_SCENARIO_DESIGN="$ROOT/tools/eval/scenarios/s1-design-execution.md"
EVAL_SCENARIO_REVIEW="$ROOT/tools/eval/scenarios/s2-review-planted.md"
EVAL_VARIANT_NO_WHY="$ROOT/tools/eval/scenarios/skill-variants/design-no-why.md"
EVAL_VARIANT_WITH_WHY="$ROOT/tools/eval/scenarios/skill-variants/design-with-why.md"

for skill in "$PRODUCT_SKILL" "$DESIGN_SKILL" "$TEST_DESIGN_SKILL" "$TECH_LEAD_SKILL" "$PM_SKILL"; do
  assert_absent '^## 输出呈现$' "$skill"
done

for skill in "$PRODUCT_SKILL" "$DESIGN_SKILL" "$TEST_DESIGN_SKILL" "$TECH_LEAD_SKILL" "$PM_SKILL"; do
  assert_present '^hooks:$' "$skill"
  assert_present '^  PostToolUse:$' "$skill"
  assert_present 'matcher: "Edit\|Write"' "$skill"
  assert_absent "显式执行 \`scripts/completion_check\\.sh\` 并通过，无 FAIL 项" "$skill"
  assert_absent "显式执行 \`scripts/completion_check\\.sh\`" "$skill"
  assert_absent 'hook 自动执行 completion gate 并通过，无 FAIL 项' "$skill"
done

assert_present 'command: bash \{\{RUNTIME_HOME\}\}/skills/product/scripts/completion_check\.sh' "$PRODUCT_SKILL"
assert_present 'command: bash \{\{RUNTIME_HOME\}\}/skills/design/scripts/completion_check\.sh' "$DESIGN_SKILL"
assert_present 'command: bash \{\{RUNTIME_HOME\}\}/skills/test-design/scripts/completion_check\.sh' "$TEST_DESIGN_SKILL"
assert_present 'command: bash \{\{RUNTIME_HOME\}\}/skills/tech-lead/scripts/completion_check\.sh' "$TECH_LEAD_SKILL"
assert_present 'command: bash \{\{RUNTIME_HOME\}\}/skills/project-manager/scripts/completion_check\.sh' "$PM_SKILL"

assert_present '^hooks:$' "$QA_SKILL"
assert_present '^  Stop:$' "$QA_SKILL"
assert_present 'command: bash \{\{RUNTIME_HOME\}\}/skills/qa/scripts/completion_check\.sh' "$QA_SKILL"
assert_absent "显式执行 \`scripts/completion_check\\.sh\` 并通过，无 FAIL 项" "$QA_SKILL"
assert_absent "显式执行 \`scripts/completion_check\\.sh\`" "$QA_SKILL"
assert_absent 'hook 自动执行 completion gate 并通过，无 FAIL 项' "$QA_SKILL"

for prompt in \
  "$PRODUCT_PRD_REVIEWER_PROMPT" \
  "$PRODUCT_ARCH_REVIEWER_PROMPT" \
  "$PRODUCT_TEST_REVIEWER_PROMPT" \
  "$DESIGN_ARCH_REVIEWER_PROMPT" \
  "$DESIGN_PRODUCT_REVIEWER_PROMPT" \
  "$DESIGN_TEST_REVIEWER_PROMPT"
do
  assert_absent '\[OPEN\]' "$prompt"
done

assert_present '^## 代码审查（Code Review）$' "$REVIEW_TEMPLATE"
assert_absent '^## Code Review$' "$REVIEW_TEMPLATE"
assert_present '^#### 发现（Findings）$' "$REVIEW_TEMPLATE"
assert_present '通过（APPROVE）' "$REVIEW_TEMPLATE"
assert_present '需修改（REQUEST_CHANGES）' "$REVIEW_TEMPLATE"
assert_present '评论（COMMENT）' "$REVIEW_TEMPLATE"
assert_present '已验证（Verified）' "$REVIEW_TEMPLATE"
assert_present '误报（False Positive）' "$REVIEW_TEMPLATE"
assert_present '待定（Inconclusive）' "$REVIEW_TEMPLATE"
assert_present '^#### 发现（Findings）$' "$REVIEW_SAFETY_PROMPT"
assert_present '^#### 发现（Findings）$' "$REVIEW_MAINTAINABILITY_PROMPT"
assert_present '^#### 发现（Findings）$' "$REVIEW_PERFORMANCE_PROMPT"
assert_present '已验证（Verified）' "$REVIEW_VERIFICATION_PROTOCOL"
assert_present '误报（False Positive）' "$REVIEW_VERIFICATION_PROTOCOL"
assert_present '待定（Inconclusive）' "$REVIEW_VERIFICATION_PROTOCOL"

assert_absent "Stop hook（\`completion_check\\.sh\`）执行通过，无 FAIL 项" "$PRODUCT_SKILL"
assert_absent "Stop hook（\`completion_check\\.sh\`）执行通过，无 FAIL 项" "$DESIGN_SKILL"
assert_absent "Stop hook（\`completion_check\\.sh\`）执行通过，无 FAIL 项" "$TEST_DESIGN_SKILL"
assert_absent "Stop hook（\`completion_check\\.sh\`）执行通过，无 FAIL 项" "$TECH_LEAD_SKILL"
assert_absent "Stop hook（\`completion_check\\.sh\`）执行通过，无 FAIL 项" "$PM_SKILL"
assert_absent "Stop hook（\`completion_check\\.sh\`）执行通过，无 FAIL 项" "$QA_SKILL"
assert_present '^## 中途插问处理$' "$PRODUCT_CONVERSATION_GUIDE"
assert_present '当前步骤保持不变' "$PRODUCT_CONVERSATION_GUIDE"
assert_present '^## 中途插问处理$' "$DESIGN_DECISION_TEMPLATES"
assert_present '当前步骤保持不变' "$DESIGN_DECISION_TEMPLATES"

assert_present '交付确认' "$PRODUCT_SKILL"
assert_present 'flow override in S2-S12' "$PRODUCT_SKILL"
assert_present '既有约束继承确认' "$DESIGN_SKILL"
assert_present 'flow override in S3-S8' "$DESIGN_SKILL"
assert_present 'shallow review evidence' "$TEST_DESIGN_SKILL"
assert_present '用户确认记录' "$TECH_LEAD_SKILL"
assert_present '确认状态=确认' "$TECH_LEAD_SKILL"
assert_present '仅适用于复杂项目' "$TECH_LEAD_SKILL"
assert_present 'plan\.md 主要面向 AI 执行' "$TECH_LEAD_SKILL"
assert_present '设计决策不确定.*回退.*/design' "$TECH_LEAD_SKILL"
assert_present '实施可行性不确定.*探索任务' "$TECH_LEAD_SKILL"
assert_present '先探后决' "$TECH_LEAD_SKILL"
assert_present 'Phase 3 gate evidence mismatches plan grade matrix' "$PM_SKILL"
assert_present 'protocols/phase-selection-protocol.md' "$DESIGN_SKILL"
assert_present 'protocols/phase-selection-protocol.md' "$TEST_DESIGN_SKILL"
assert_present 'protocols/phase-selection-protocol.md' "$TECH_LEAD_SKILL"
assert_present '交付画像' "$COMMIT_SKILL"
assert_present 'small-chain.*verify-change-report\.md.*qa.*N/A' "$COMMIT_SKILL"
assert_present 'phase.*code-review-report\.md.*qa-report\.md.*PASS' "$COMMIT_SKILL"
assert_present 'ad-hoc.*--force' "$COMMIT_SKILL"
assert_present 'verify-change=<PASS\|FAIL\|N/A\|FORCED>' "$COMMIT_SKILL"
assert_absent "先执行 code-review \\+ \`/qa\`" "$COMMIT_SKILL"
for file in \
  "$PRODUCT_SKILL" \
  "$DESIGN_SKILL" \
  "$TEST_DESIGN_SKILL" \
  "$TECH_LEAD_SKILL" \
  "$PM_SKILL" \
  "$REVIEW_SKILL" \
  "$PM_PHASE3_DOC"
do
  assert_absent 'reference/(phase-selection-protocol|review-fix-loop-protocol|review-iteration-protocol)\.md' "$file"
done

assert_absent 'equivalence/' "$PHASE_SELECTION_PROTOCOL"

PRODUCT_TEMPLATE="$ROOT/shared/skills/product/references/templates/prd-template.md"
DESIGN_TEMPLATE="$ROOT/shared/skills/design/references/templates/design-template.md"
PLAN_TEMPLATE="$ROOT/shared/skills/tech-lead/references/templates/plan-template.md"
IMPACT_ANALYSIS="$ROOT/shared/reference/影响范围分析.md"
IMPACT_FORMAT="$ROOT/shared/reference/影响文件格式.md"
TEST_CASES_TEMPLATE="$ROOT/shared/skills/test-design/references/templates/test-cases-template.md"

assert_present '^## 前置约束$' "$PRODUCT_TEMPLATE"
assert_absent '^## 约束$' "$PRODUCT_TEMPLATE"
# 约束提取函数可能在脚本本地或公共库 constraint.sh 中定义
CONSTRAINT_SH_CHECK="$ROOT/shared/hooks/lib/constraint.sh"
assert_present "extract_markdown_section \"\\\$prd_file\" \"## 前置约束\"" "$CONSTRAINT_SH_CHECK"
assert_present '^    "## 前置约束"$' "$PRODUCT_CHECK"
assert_absent "extract_markdown_section \"\\\$prd_file\" \"## 约束\"" "$CONSTRAINT_SH_CHECK"
assert_absent '^    "## 约束"$' "$PRODUCT_CHECK"
assert_present '^## 交付确认$' "$PRODUCT_TEMPLATE"
assert_present '^\| 交付确认 \| \| \| \|$' "$PRODUCT_TEMPLATE"
assert_present '^### 审查汇总$' "$PRODUCT_TEMPLATE"
assert_present '^\| 视角 \| Verdict \| Issue Count \|$' "$PRODUCT_TEMPLATE"
assert_present '^### 审查问题台账$' "$PRODUCT_TEMPLATE"
assert_present '^\| Issue ID \| 视角 \| Severity \| Status \| Evidence Anchor \| Handoff Target \| Review Round \| 处理摘要 \|$' "$PRODUCT_TEMPLATE"
assert_no_legacy_review_artifact_ref "$PRODUCT_TEMPLATE"
assert_present '^## 既有约束继承确认$' "$DESIGN_TEMPLATE"
assert_present '^## 上游审查承接$' "$DESIGN_TEMPLATE"
assert_present '^\| Issue ID \| 来源阶段 \| 视角 \| 发现摘要 \| 承接方式 \| 承接位置 \|$' "$DESIGN_TEMPLATE"
assert_present '^\| 决策点识别 \| \| \| \|$' "$DESIGN_TEMPLATE"
assert_present '^## 交付确认$' "$DESIGN_TEMPLATE"
assert_present '^### 审查汇总$' "$DESIGN_TEMPLATE"
assert_present '^\| 视角 \| Verdict \| Issue Count \|$' "$DESIGN_TEMPLATE"
assert_present '^### 审查问题台账$' "$DESIGN_TEMPLATE"
assert_no_legacy_review_artifact_ref "$DESIGN_TEMPLATE"
assert_present '^### 审查汇总$' "$TEST_CASES_TEMPLATE"
assert_present '^\| 视角 \| Verdict \| Issue Count \|$' "$TEST_CASES_TEMPLATE"
assert_present '^### 审查问题台账$' "$TEST_CASES_TEMPLATE"
assert_present '^### 收敛轮次摘要$' "$TEST_CASES_TEMPLATE"
assert_present '^\| 轮次 \| 结果 \| 说明 \|$' "$TEST_CASES_TEMPLATE"
assert_no_legacy_review_artifact_ref "$TEST_CASES_TEMPLATE"
assert_present '^## 用户确认记录$' "$PLAN_TEMPLATE"
assert_present '^## 计划模式$' "$PLAN_TEMPLATE"
assert_present '计划模式: \{标准实施, 探索优先\}' "$PLAN_TEMPLATE"
assert_present '设计决策状态: \{已收口；若未收口则禁止进入 /tech-lead\}' "$PLAN_TEMPLATE"
assert_present '^## 再计划与解锁规则$' "$PLAN_TEMPLATE"
assert_present '^## 计划修订记录$' "$PLAN_TEMPLATE"
assert_present '停止条件: \{探索失败或无法确认下一步\}' "$PLAN_TEMPLATE"
assert_present 'task_type: \{探索, 实施\}' "$PLAN_TEMPLATE"
assert_present 'hypothesis: \{待验证假设' "$PLAN_TEMPLATE"
assert_present 'success_signal: \{验证通过信号' "$PLAN_TEMPLATE"
assert_present 'failure_signal: \{验证失败信号' "$PLAN_TEMPLATE"
assert_present 'unlock_condition: \{允许解锁后续任务的条件' "$PLAN_TEMPLATE"
assert_present 'reference/影响文件格式.md' "$PLAN_TEMPLATE"
assert_present 'reference/影响文件格式.md' "$IMPACT_ANALYSIS"
assert_absent 'plan-template\.md' "$IMPACT_ANALYSIS"
test -f "$IMPACT_FORMAT" || fail "missing shared impact_files format reference"
assert_present 'planning_mode' "$CHAIN_CONTRACT"
assert_present 'replan_rules' "$CHAIN_CONTRACT"
assert_present 'plan_revisions' "$CHAIN_CONTRACT"
assert_present '探索任务' "$HARD_GATE_GRADER"
assert_present '计划模式' "$HARD_GATE_GRADER"

assert_no_legacy_review_artifact_ref "$CHAIN_CONTRACT"
assert_no_legacy_review_artifact_ref "$PHASE_SELECTION_PROTOCOL"
assert_no_legacy_review_artifact_ref "$DESIGNER_AGENT"
assert_no_legacy_review_artifact_ref "$TEST_DESIGNER_AGENT"
assert_no_legacy_review_artifact_ref "$HARD_GATE_GRADER"
assert_absent 'docs/weekly-report' "$EVAL_RUNNER"
assert_present 'tools/eval/fixtures/weekly-report/prd\.md' "$EVAL_RUNNER"
assert_absent 'docs/weekly-report' "$EVAL_SCENARIO_DESIGN"
assert_absent 'docs/weekly-report' "$EVAL_SCENARIO_REVIEW"
assert_no_legacy_review_artifact_ref "$EVAL_SCENARIO_DESIGN"
assert_no_legacy_review_artifact_ref "$EVAL_SCENARIO_REVIEW"
assert_no_legacy_review_artifact_ref "$EVAL_VARIANT_NO_WHY"
assert_no_legacy_review_artifact_ref "$EVAL_VARIANT_WITH_WHY"
assert_present 'tools/eval/fixtures/weekly-report/prd\.md' "$EVAL_SCENARIO_DESIGN"
assert_present 'tools/eval/fixtures/weekly-report/prd\.md' "$EVAL_SCENARIO_REVIEW"

PRODUCT_CHECK="$ROOT/shared/skills/product/scripts/completion_check.sh"
DESIGN_CHECK="$ROOT/shared/skills/design/scripts/completion_check.sh"
TECH_LEAD_CHECK="$ROOT/shared/skills/tech-lead/scripts/completion_check.sh"
TEST_DESIGN_CHECK="$ROOT/shared/skills/test-design/scripts/completion_check.sh"
PM_GATE_CHECK="$ROOT/shared/skills/project-manager/scripts/completion_check.sh"
QA_CHECK="$ROOT/shared/skills/qa/scripts/completion_check.sh"

assert_present '"## 交付确认"' "$PRODUCT_CHECK"
assert_present '"交付确认"; do' "$PRODUCT_CHECK"
assert_present '数据行不足 6 条' "$PRODUCT_CHECK"
assert_present '确认状态必须为「确认」' "$PRODUCT_CHECK"
assert_present 'extract_review_summary_row' "$PRODUCT_CHECK"
assert_present 'extract_review_issue_ledger_rows' "$PRODUCT_CHECK"
assert_no_legacy_review_artifact_ref "$PRODUCT_CHECK"

assert_present 'extract_inheritance_rows' "$DESIGN_CHECK"
assert_present '"## 既有约束继承确认"' "$DESIGN_CHECK"
assert_present '"决策点识别"' "$DESIGN_CHECK"
assert_present '处理方式非法' "$DESIGN_CHECK"
assert_present '"## 交付确认"' "$DESIGN_CHECK"
assert_present 'S10 最终确认' "$DESIGN_CHECK"
assert_present 'extract_review_summary_row' "$DESIGN_CHECK"
assert_present 'extract_review_issue_ledger_rows' "$DESIGN_CHECK"
assert_no_legacy_review_artifact_ref "$DESIGN_CHECK"

assert_present '"## 用户确认记录"' "$TECH_LEAD_CHECK"
assert_present '用户确认记录状态必须为「确认」' "$TECH_LEAD_CHECK"

assert_present '不满足 HARD-GATE 2' "$TEST_DESIGN_CHECK"
assert_present 'extract_review_summary_row' "$TEST_DESIGN_CHECK"
assert_present 'extract_review_issue_ledger_rows' "$TEST_DESIGN_CHECK"
assert_present 'extract_convergence_rows' "$TEST_DESIGN_CHECK"
assert_no_legacy_review_artifact_ref "$TEST_DESIGN_CHECK"

test -f "$QA_CHECK" || fail "missing qa completion_check.sh"
assert_present 'qa-report\.md' "$QA_CHECK"
assert_present '审查分级' "$QA_CHECK"
assert_present '## 验收汇总' "$QA_CHECK"
assert_present 'QA_A/QA_B/QA_C/QA_D' "$QA_CHECK"
assert_present 'RESULT: PASS \| FAIL' "$QA_CHECK"

assert_confirmation_time_contract "$PRODUCT_CHECK" "product completion_check"
assert_confirmation_time_contract "$DESIGN_CHECK" "design completion_check"
assert_confirmation_time_contract "$TECH_LEAD_CHECK" "tech-lead completion_check"

assert_present '设计决策状态' "$TECH_LEAD_CHECK"
assert_present '当前已解锁批次' "$TECH_LEAD_CHECK"
assert_present '停止条件' "$TECH_LEAD_CHECK"
assert_present 'test-cases\.md`（必须存在' "$TECH_LEAD_AGENT"

TECH_LEAD_FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/org-tech-lead-gate.XXXXXX")"
HOOK_FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/org-hook-gate.XXXXXX")"
trap 'rm -rf "$TECH_LEAD_FIXTURE_ROOT" "$HOOK_FIXTURE_ROOT" "${TECH_LEAD_LAST_OUTPUT:-}" "${LAST_CHECK_OUTPUT:-}"' EXIT

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-valid" "已收口" "no" "complete" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-valid" "session-valid"
assert_tech_lead_check_passes "valid exploration-first plan"

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-future-task" "已收口" "yes" "complete" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-future-task" "session-future-task"
assert_tech_lead_check_fails_with "future task leak" '未解锁批次之外的 Task|当前已解锁批次之外'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-incomplete-replan" "已收口" "no" "missing_fields" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-incomplete-replan" "session-incomplete-replan"
assert_tech_lead_check_fails_with "incomplete replan rules" '再计划与解锁规则.*不完整|缺少.*再计划触发条件'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-design-open" "未收口" "no" "complete" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-design-open" "session-design-open"
assert_tech_lead_check_fails_with "open design decisions" '设计决策状态.*已收口|未收口'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-revision-placeholder" "已收口" "no" "complete" "placeholder"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-revision-placeholder" "session-revision-placeholder"
assert_tech_lead_check_fails_with "plan revision placeholder" '计划修订记录.*占位|计划修订记录.*有效数据'

PRODUCT_HOOK_ROOT="$HOOK_FIXTURE_ROOT/product-hook"
mkdir -p "$PRODUCT_HOOK_ROOT/docs/product-hook/units"
cat > "$PRODUCT_HOOK_ROOT/docs/product-hook/prd.md" <<'EOF'
# PRD

## 审查结论
### 审查汇总

| 视角 | Verdict | Issue Count |
|------|---------|-------------|
| 产品 | PASS | 0 |

## 交付计划
### Phase 1
- 状态: NOT_STARTED

## 交接项
- late-stage artifact without confirmation
EOF
run_completion_check_with_payload \
  "$PRODUCT_CHECK" \
  "$PRODUCT_HOOK_ROOT" \
  "session-product-hook" \
  "docs/product-hook/prd.md\n" \
  "Write" \
  "docs/product-hook/prd.md"
assert_last_check_fails_with "product hook late-stage missing confirmation" 'PRD 缺少章节：## 交付确认|缺少「交付确认」章节'

PM_HOOK_ROOT="$HOOK_FIXTURE_ROOT/project-manager-hook"
mkdir -p "$PM_HOOK_ROOT/docs/pm-hook/phase-1/unit-1"
cat > "$PM_HOOK_ROOT/docs/pm-hook/phase-1/unit-1/dev-report.md" <<'EOF'
# dev report
EOF
cat > "$PM_HOOK_ROOT/docs/pm-hook/phase-1/acceptance-summary.md" <<'EOF'
## 交付范围
- Feature: pm-hook

## 质量门禁
| 门禁 | 状态 |
|------|------|
| TDD 证据 | PASS |

## 签收记录
- 备注: missing explicit sign-off
EOF
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_HOOK_ROOT" \
  "session-pm-hook" \
  "docs/pm-hook/phase-1/unit-1/dev-report.md\ndocs/pm-hook/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-hook/phase-1/acceptance-summary.md"
assert_last_check_fails_with "project-manager hook should reach full validation" 'plan\.md 不存在|design\.md 不存在|code-review-report\.md 不存在|qa-report\.md 不存在'
assert_last_check_absent "project-manager hook should not hit shell function ordering bug" 'trim: command not found|command not found'

QA_SCOPE_ROOT="$HOOK_FIXTURE_ROOT/qa-scope"
mkdir -p "$QA_SCOPE_ROOT/docs/qa-scope/phase-1"
cat > "$QA_SCOPE_ROOT/docs/qa-scope/phase-1/qa-report.md" <<'EOF'
审查分级: 标准
执行范围: full

## 验收汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | OK | 0 | ok |
| QA_B（E2E 旅程） | N/A | 0 | invalid for full |
| QA_C（回归验证） | OK | 0 | ok |
| QA_D（探索性测试） | N/A | 0 | invalid for full |

## 已排除潜在问题
| # | 潜在问题 | 排除依据 | 证据 |
|---|---------|---------|------|
| 1 | p1 | reason | evidence |
| 2 | p2 | reason | evidence |

RESULT: PASS
EOF
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_SCOPE_ROOT" \
  "session-qa-scope" \
  "docs/qa-scope/phase-1/qa-report.md\n"
assert_last_check_fails_with "qa full scope cannot contain N/A" '执行范围=full 时，QA_A/QA_B/QA_C/QA_D 均不得为 N/A'

QA_RESULT_ROOT="$HOOK_FIXTURE_ROOT/qa-result"
mkdir -p "$QA_RESULT_ROOT/docs/qa-result/phase-1"
cat > "$QA_RESULT_ROOT/docs/qa-result/phase-1/qa-report.md" <<'EOF'
审查分级: 标准
执行范围: 验证-A

## 验收汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | ISSUE | 1 | failed |
| QA_B（E2E 旅程） | N/A | 0 | na |
| QA_C（回归验证） | N/A | 0 | na |
| QA_D（探索性测试） | N/A | 0 | na |

## 已排除潜在问题
| # | 潜在问题 | 排除依据 | 证据 |
|---|---------|---------|------|
| 1 | p1 | reason | evidence |
| 2 | p2 | reason | evidence |

## FAIL 详情
| Issue ID | 阶段 | 期望行为 | 实际行为 | 复现命令 |
|----------|------|---------|---------|---------|
| QAR-001 | QA_A | a | b | c |

RESULT: PASS
EOF
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_RESULT_ROOT" \
  "session-qa-result" \
  "docs/qa-result/phase-1/qa-report.md\n"
assert_last_check_fails_with "qa result must match issue stages" 'RESULT=PASS 时，验收汇总中不得存在 ISSUE 阶段'

QA_EXCLUDED_ROOT="$HOOK_FIXTURE_ROOT/qa-excluded"
mkdir -p "$QA_EXCLUDED_ROOT/docs/qa-excluded/phase-1"
cat > "$QA_EXCLUDED_ROOT/docs/qa-excluded/phase-1/qa-report.md" <<'EOF'
审查分级: 标准
执行范围: 验证-A

## 验收汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | ISSUE | 1 | failed |
| QA_B（E2E 旅程） | N/A | 0 | na |
| QA_C（回归验证） | N/A | 0 | na |
| QA_D（探索性测试） | N/A | 0 | na |

## FAIL 详情
| Issue ID | 阶段 | 期望行为 | 实际行为 | 复现命令 |
|----------|------|---------|---------|---------|
| QAR-001 | QA_A | a | b | c |
| QAR-002 | QA_A | a | b | c |

## 已排除潜在问题
| # | 潜在问题 | 排除依据 | 证据 |
|---|---------|---------|------|
| 1 | only one | reason | evidence |

RESULT: FAIL
EOF
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_EXCLUDED_ROOT" \
  "session-qa-excluded" \
  "docs/qa-excluded/phase-1/qa-report.md\n"
assert_last_check_fails_with "qa excluded issue count must ignore fail IDs" '已排除潜在问题不足 2 条'

echo "[PASS] skill output/gate contract"
