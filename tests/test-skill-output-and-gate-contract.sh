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
  local review_variant="${7:-valid}"
  local evidence_variant="${8:-valid}"
  local matrix_variant="${9:-valid}"

  local feature_dir="$root_dir/docs/$feature_name"
  local phase_dir="$feature_dir/phase-1"

  mkdir -p "$phase_dir/units" "$phase_dir/unit-1" "$phase_dir/design"

  cat > "$feature_dir/brief.md" <<'EOF'
# Brief

## 前置约束
- 无前置约束（经评估）
EOF

  cat > "$phase_dir/units/UNIT-1.md" <<'EOF'
# UNIT-1
EOF

  cat > "$phase_dir/prd.md" <<'EOF'
# Phase 1

> 项目背景、约束与设计决策见 [brief.md](../brief.md)

## 阶段目标
探索可行性验证

## 入口与出口条件
- 入口条件: Brief 审查通过
- 出口条件: Phase 1 所有 UNIT QA 通过

## 功能需求（UNIT 索引）

| UNIT | 标题 | 闭环目标 | 优先级 | 依赖 | 定义文件 |
|------|------|----------|--------|------|----------|
| UNIT-1 | 探索实施边界 | 验证路径 | MVP | - | units/UNIT-1.md |
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
| UNIT-1 | AC | AC-U1-01 | 探索实施边界 | SCOPE-P1U1-001 | MOD-001 | Task-1 | TC-U1-001 | impact_files 已标注 | $( [ "$matrix_variant" = "coverage_gap" ] && printf 'COVERED-NO-TEST' || printf 'COVERED' ) |
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

  cat >> "$phase_dir/plan.md" <<EOF

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
- proving_command: $( [ "$evidence_variant" = "missing_proving_command" ] && printf '{待补 proving command}' || [ "$evidence_variant" = "noop_proving_command" ] && printf 'echo PASS' || printf 'bash tests/run-all.sh' )
- real_dependency_note: $( [ "$evidence_variant" = "mock_only" ] && printf '仅依赖 Mock 验收，无真实集成路径' || [ "$evidence_variant" = "semantic_real_dependency" ] && printf '连接 staging PostgreSQL 与对象存储执行端到端验证，保留完整命令输出' || printf '依赖真实测试环境与完整测试套件，最终验收不得只看 Mock' )
- evidence_target: $( [ "$evidence_variant" = "missing_evidence_target" ] && printf '{待补 evidence target}' || [ "$evidence_variant" = "unanchored_evidence_target" ] && printf 'dev-report.md + qa-report.md#qa_a-unit-1' || printf 'dev-report.md#task-1 + qa-report.md#qa_a-unit-1 + acceptance-summary.md#质量门禁' )
- mock_boundary_note: $( [ "$evidence_variant" = "mock_only" ] && printf '最终验收允许使用 Mock 作为完成证据' || printf 'Mock 仅用于分层隔离测试，最终验收必须走真实依赖与完整输出' )
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
- proving_command: bash tests/run-all.sh
- real_dependency_note: 依赖真实测试环境与完整测试套件，最终验收不得只看 Mock
- evidence_target: dev-report.md#task-2 + qa-report.md#qa_a-unit-1 + acceptance-summary.md#质量门禁
- mock_boundary_note: Mock 仅用于分层隔离测试，最终验收必须走真实依赖与完整输出
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
EOF

  case "$review_variant" in
    valid)
      cat >> "$phase_dir/plan.md" <<'EOF'
### 审查汇总

| 视角 | Verdict | Review Round | Issue Count | 结论摘要 |
|------|---------|--------------|-------------|---------|
| 产品 | PASS | R2 | 0 | 本 Phase 目标与交付价值未漂移 |
| 架构 | PASS | R2 | 0 | Task 拆分与 design 一致，可直接执行 |
| 测试验收 | PASS | R2 | 0 | AC、证据链与真实验证路径完整 |

### 审查问题台账

| Issue ID | 视角 | Severity | Status | Evidence Anchor | Handoff Target | Review Round | 风险接受记录 | 处理摘要 |
|----------|------|----------|--------|-----------------|----------------|--------------|--------------|---------|

### 收敛轮次摘要

| 轮次 | 结果 | FAIL数 | 未关闭 Issue IDs | 控制动作 | 说明 |
|------|------|-------|------------------|----------|------|
| R1 | PASS | 0 | 无 | CONTINUE | 首轮三视角审查通过，进入确认轮 |
| R2 | PASS | 0 | 无 | CONFIRMATION | 确认轮复核通过，允许进入 project-manager |

### 用户裁决记录

| 触发轮次 | 控制动作 | 用户决定 | 关联 Issue IDs | 记录时间 | 说明 |
|----------|----------|----------|----------------|----------|------|

独立审查收敛状态: REVIEW_PASS
EOF
      ;;
    missing_summary)
      cat >> "$phase_dir/plan.md" <<'EOF'
独立审查收敛状态: REVIEW_PASS
EOF
      ;;
    warn_without_handoff)
      cat >> "$phase_dir/plan.md" <<'EOF'
### 审查汇总

| 视角 | Verdict | Review Round | Issue Count | 结论摘要 |
|------|---------|--------------|-------------|---------|
| 产品 | WARN | R1 | 1 | Phase 目标仍成立，但交付价值承接未写清 |
| 架构 | PASS | R1 | 0 | Task 拆分与 design 一致 |
| 测试验收 | PASS | R1 | 0 | 证据链闭环 |

### 审查问题台账

| Issue ID | 视角 | Severity | Status | Evidence Anchor | Handoff Target | Review Round | 风险接受记录 | 处理摘要 |
|----------|------|----------|--------|-----------------|----------------|--------------|--------------|---------|
| PLP-001 | 产品 | P2 | OPEN | plan.md#Task-清单 | {待承接} | R1 | {待补} | {待补} |

### 收敛轮次摘要

| 轮次 | 结果 | FAIL数 | 未关闭 Issue IDs | 控制动作 | 说明 |
|------|------|-------|------------------|----------|------|
| R1 | WARN | 0 | 无 | CONFIRMATION | 保留 WARN 并继续输出计划 |

### 用户裁决记录

| 触发轮次 | 控制动作 | 用户决定 | 关联 Issue IDs | 记录时间 | 说明 |
|----------|----------|----------|----------------|----------|------|

独立审查收敛状态: REVIEW_PASS
EOF
      ;;
  esac

  cat >> "$phase_dir/plan.md" <<'EOF'

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

create_project_manager_fixture() {
  local root_dir="$1"
  local feature_name="$2"
  local plan_evidence_variant="${3:-valid}"
  local report_evidence_variant="${4:-valid}"
  local fresh_output_variant="${5:-valid}"

  create_tech_lead_fixture "$root_dir" "$feature_name" "已收口" "no" "complete" "valid" "valid" "$plan_evidence_variant" "valid"

  local feature_dir="$root_dir/docs/$feature_name"
  local phase_dir="$feature_dir/phase-1"
  local report_proving_command="bash tests/run-all.sh"
  local report_real_dependency_note="依赖真实测试环境与完整测试套件，最终验收不得只看 Mock"
  local report_evidence_target="dev-report.md#task-1 + qa-report.md#qa_a-unit-1 + acceptance-summary.md#质量门禁"
  local report_mock_boundary_note="Mock 仅用于分层隔离测试，最终验收必须走真实依赖与完整输出"
  local fresh_proving_output=$'bash tests/run-all.sh\n1 passing'

  case "$report_evidence_variant" in
    missing_proving_command)
      report_proving_command="{待补 proving command}"
      ;;
    noop_proving_command)
      report_proving_command="echo PASS"
      ;;
    drift_proving_command)
      report_proving_command="bash tests/unit-only.sh"
      ;;
  esac

  case "$report_evidence_variant" in
    mock_only)
      report_real_dependency_note="仅依赖 Mock 验收，无真实集成路径"
      report_mock_boundary_note="最终验收允许使用 Mock 作为完成证据"
      ;;
    semantic_real_dependency)
      report_real_dependency_note="连接 staging PostgreSQL 与对象存储执行端到端验证，保留完整命令输出"
      ;;
  esac

  case "$report_evidence_variant" in
    missing_evidence_target)
      report_evidence_target="{待补 evidence target}"
      ;;
    unanchored_evidence_target)
      report_evidence_target="dev-report.md + qa-report.md#qa_a-unit-1"
      ;;
    drift_evidence_target)
      report_evidence_target="dev-report.md#task-1 + qa-report.md#qa_a-unit-1"
      ;;
  esac

  if [ "$fresh_output_variant" = "summary_only" ]; then
    fresh_proving_output="PASS"
  fi

  cat > "$phase_dir/unit-1/test-cases.md" <<'EOF'
# test-cases

### TC-U1-001: 探索任务验证

## 等价性对照矩阵
| scope_item_id | requirement_ref | test_ref | 验证方法 | 备注 | status |
|---------------|-----------------|----------|----------|------|--------|
| SCOPE-P1U1-001 | AC-U1-01 | TC-U1-001 | 手工+自动 | ok | EQ-COVERED |
EOF

  cat > "$phase_dir/unit-1/dev-report.md" <<EOF
# dev-report.md

## 输入分析
执行 Task-1 并回填真实验证证据

## 决策
串行执行，保持与 plan.md 一致

## 产出
TEST_CMD: bash tests/run-all.sh

### Task-1: 探索可行性
- scope_item_ref: SCOPE-P1U1-001
- impact_files: src/explore.ts, tests/explore.test.ts
- rollback_ref: plan.md#回滚策略-1
- proving_command: $report_proving_command
- real_dependency_note: $report_real_dependency_note
- evidence_target: $report_evidence_target
- mock_boundary_note: $report_mock_boundary_note

#### TDD 完整证据

RED 阶段输出:
\`\`\`text
1 failing
\`\`\`

GREEN 阶段输出:
\`\`\`text
1 passing
\`\`\`

Fresh proving command:
\`\`\`text
$fresh_proving_output
\`\`\`

- Spec Review: SPEC_OK
- Phase2A: 2A_OK
- Phase2B: 2B_OK
- Phase2C: 2C_OK
- Commit: feat(Task-1): finish task

### Task-Commit 对照表
| Task | Commit | 含测试 | Spec | 2A | 2B | 2C | 状态 |
|------|--------|--------|------|----|----|----|------|
| Task-1 | abc1234 | yes | SPEC_OK | 2A_OK | 2B_OK | 2C_OK | DONE |

### Task-scope 对照表
| Task | scope_item_ref | impact_files | rollback_ref | 边界校验 |
|------|----------------|--------------|--------------|----------|
| Task-1 | SCOPE-P1U1-001 | src/explore.ts, tests/explore.test.ts | plan.md#回滚策略-1 | OK |

### 全量测试结果
TEST_CMD: bash tests/run-all.sh
1 passed

### 交接项
- Task-1 已交接
EOF

  cat > "$phase_dir/code-review-report.md" <<'EOF'
审查分级: 标准

## 审查汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| REVIEW_A | OK | 0 | ok |
| REVIEW_B | OK | 0 | ok |
EOF

  cat > "$phase_dir/qa-report.md" <<'EOF'
审查分级: 标准
执行范围: full

## 验收汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | OK | 0 | ok |
| QA_B（E2E 旅程） | N/A | 0 | na |
| QA_C（回归验证） | OK | 0 | ok |
| QA_D（探索性测试） | N/A | 0 | na |

### QA_A UNIT 执行汇总
| UNIT | unit_work_dir | test_cases_ref | 状态 | issue_ids | 说明 |
|------|---------------|----------------|------|-----------|------|
| UNIT-1 | unit-1 | unit-1/test-cases.md | OK | - | AC 全通过 |

## 验证-A 明细

### AC 追踪表
| UNIT | unit_work_dir | AC ID | AC 摘要 | test_ref | 验证方法 | 结果 | 证据摘要 |
|------|---------------|-------|---------|----------|---------|------|---------|
| UNIT-1 | unit-1 | AC-U1-01 | 探索实施边界 | TC-U1-001 | 手工+自动 | PASS | qa-report.md#qa_a-unit-1 |

## 验证-A 结论
QA_A_OK
EOF

  cat > "$phase_dir/acceptance-summary.md" <<'EOF'
## 交付范围
- Feature: pm evidence
- PRD: docs/feature/brief.md
- Plan: docs/feature/phase-1/plan.md
- Task 数: 1（完成: 1，BLOCKED: 0）

## 质量门禁
| 门禁 | 状态 |
|------|------|
| TDD 证据 | PASS |
| Code Review (REVIEW_A) | OK |
| Code Review (REVIEW_B) | OK |
| QA_A (AC 验收) | OK |
| QA_B (E2E 旅程) | N/A |
| QA_C (回归验证) | OK |
| QA_D (探索性测试) | N/A |
| 全量测试 | PASS |

## 签收记录
- 签收状态: 确认
- 签收人: user
- 签收时间: 2026-04-11T10:00:00+08:00
- 备注: ok
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
OVERVIEW_SKILL="$ROOT/shared/skills/overview/SKILL.md"
NEW_SKILLS_SKILL="$ROOT/shared/skills/new-skills/SKILL.md"
AGENT_TEAM_PATTERNS="$ROOT/shared/reference/agent-team-patterns.md"
OVERVIEW_MODE_SELECTION="$ROOT/shared/skills/overview/references/mode-selection.md"
OVERVIEW_AGENT_ASSIGNMENTS="$ROOT/shared/skills/overview/references/agent-assignments.md"
PRODUCT_PRD_REVIEWER_PROMPT="$ROOT/shared/skills/product/references/prd-reviewer-prompt.md"
PRODUCT_ARCH_REVIEWER_PROMPT="$ROOT/shared/skills/product/references/architect-reviewer-prompt.md"
PRODUCT_TEST_REVIEWER_PROMPT="$ROOT/shared/skills/product/references/tester-reviewer-prompt.md"
DESIGN_ARCH_REVIEWER_PROMPT="$ROOT/shared/skills/design/references/design-reviewer-prompt.md"
DESIGN_PRODUCT_REVIEWER_PROMPT="$ROOT/shared/skills/design/references/design-product-reviewer-prompt.md"
DESIGN_TEST_REVIEWER_PROMPT="$ROOT/shared/skills/design/references/design-test-reviewer-prompt.md"
TESTDESIGN_QUALITY_REVIEWER_PROMPT="$ROOT/shared/skills/test-design/references/testdesign-reviewer-prompt.md"
TESTDESIGN_ARCH_REVIEWER_PROMPT="$ROOT/shared/skills/test-design/references/testdesign-arch-reviewer-prompt.md"
TESTDESIGN_PRODUCT_REVIEWER_PROMPT="$ROOT/shared/skills/test-design/references/testdesign-product-reviewer-prompt.md"
TECH_LEAD_PLAN_REVIEWER_PROMPT="$ROOT/shared/skills/tech-lead/references/plan-reviewer-prompt.md"
TECH_LEAD_PRODUCT_REVIEWER_PROMPT="$ROOT/shared/skills/tech-lead/references/plan-product-reviewer-prompt.md"
TECH_LEAD_TEST_REVIEWER_PROMPT="$ROOT/shared/skills/tech-lead/references/plan-test-reviewer-prompt.md"
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
HOOK_REGISTRY="$ROOT/shared/hooks/registry.json"
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
EVAL_REVIEW_PRODUCT_RESULT="$ROOT/tools/eval/results/s2-run-1/review-product.md"
EVAL_REVIEW_ARCH_RESULT="$ROOT/tools/eval/results/s2-run-1/review-arch.md"
EVAL_REVIEW_TEST_RESULT="$ROOT/tools/eval/results/s2-run-1/review-test.md"

for skill in "$PRODUCT_SKILL" "$DESIGN_SKILL" "$TEST_DESIGN_SKILL" "$TECH_LEAD_SKILL" "$PM_SKILL"; do
  assert_absent '^hooks:$' "$skill"
  assert_absent "显式执行 \`scripts/completion_check\\.sh\` 并通过，无 FAIL 项" "$skill"
  assert_absent "显式执行 \`scripts/completion_check\\.sh\`" "$skill"
  assert_absent 'hook 自动执行 completion gate 并通过，无 FAIL 项' "$skill"
done

assert_present '^allowed-tools: .*AskUserQuestion' "$OVERVIEW_SKILL"
assert_present '^allowed-tools: .*Agent' "$OVERVIEW_SKILL"

assert_absent '^hooks:$' "$QA_SKILL"
assert_absent "显式执行 \`scripts/completion_check\\.sh\` 并通过，无 FAIL 项" "$QA_SKILL"
assert_absent "显式执行 \`scripts/completion_check\\.sh\`" "$QA_SKILL"
assert_absent 'hook 自动执行 completion gate 并通过，无 FAIL 项' "$QA_SKILL"

assert_present '"skill_completion_gates"' "$HOOK_REGISTRY"
assert_present '"runtime_hooks"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"product"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"design"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"test-design"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"tech-lead"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"project-manager"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"qa"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"review"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"developer"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"fix"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"scan"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"security"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"refactor"' "$HOOK_REGISTRY"
assert_present '"id"[[:space:]]*:[[:space:]]*"dangerous-bash"' "$HOOK_REGISTRY"
assert_present '"id"[[:space:]]*:[[:space:]]*"codex-track-active-skill"' "$HOOK_REGISTRY"
assert_present '"id"[[:space:]]*:[[:space:]]*"codex-stop-dispatch"' "$HOOK_REGISTRY"
assert_present '"id"[[:space:]]*:[[:space:]]*"claude-code-quality-check"' "$HOOK_REGISTRY"
assert_present '"supported"[[:space:]]*:[[:space:]]*false' "$HOOK_REGISTRY"
assert_present 'Write/Edit' "$HOOK_REGISTRY"

for prompt in \
  "$PRODUCT_PRD_REVIEWER_PROMPT" \
  "$PRODUCT_ARCH_REVIEWER_PROMPT" \
  "$PRODUCT_TEST_REVIEWER_PROMPT" \
  "$DESIGN_ARCH_REVIEWER_PROMPT" \
  "$DESIGN_PRODUCT_REVIEWER_PROMPT" \
  "$DESIGN_TEST_REVIEWER_PROMPT" \
  "$TESTDESIGN_QUALITY_REVIEWER_PROMPT" \
  "$TESTDESIGN_ARCH_REVIEWER_PROMPT" \
  "$TESTDESIGN_PRODUCT_REVIEWER_PROMPT" \
  "$TECH_LEAD_PLAN_REVIEWER_PROMPT" \
  "$TECH_LEAD_PRODUCT_REVIEWER_PROMPT" \
  "$TECH_LEAD_TEST_REVIEWER_PROMPT"
do
  assert_absent '\[OPEN\]' "$prompt"
done

for prompt in \
  "$PRODUCT_PRD_REVIEWER_PROMPT" \
  "$PRODUCT_ARCH_REVIEWER_PROMPT" \
  "$PRODUCT_TEST_REVIEWER_PROMPT" \
  "$DESIGN_ARCH_REVIEWER_PROMPT" \
  "$DESIGN_PRODUCT_REVIEWER_PROMPT" \
  "$DESIGN_TEST_REVIEWER_PROMPT" \
  "$TESTDESIGN_QUALITY_REVIEWER_PROMPT" \
  "$TESTDESIGN_ARCH_REVIEWER_PROMPT" \
  "$TESTDESIGN_PRODUCT_REVIEWER_PROMPT"
do
  assert_present '^## Findings$' "$prompt"
  assert_present '^\| Issue ID \| Severity \| 维度 \| 发现 \| 证据 \| 承接目标 \|$' "$prompt"
  assert_absent '^\| Issue ID \| Severity \| 维度 \| 发现 \| 证据 \| 建议 \|$' "$prompt"
  assert_present '必须给出 .*稳定 issue id 和.?承接目标' "$prompt"
  assert_present '^### 关键问题（FAIL 项详述）$' "$prompt"
  assert_present '^### 改进建议（WARN 项）$' "$prompt"
  assert_absent '详细说明和改进建议' "$prompt"
done

for prompt in \
  "$TECH_LEAD_PLAN_REVIEWER_PROMPT" \
  "$TECH_LEAD_PRODUCT_REVIEWER_PROMPT" \
  "$TECH_LEAD_TEST_REVIEWER_PROMPT"
do
  assert_present '^## Findings$' "$prompt"
  assert_present '^\| Issue ID \| Severity \| 维度 \| 发现 \| 证据 \| 承接目标 \|$' "$prompt"
  assert_present '稳定 issue id 和.?承接目标' "$prompt"
  assert_present '^### 关键问题（FAIL 项详述）$' "$prompt"
  assert_present '^### 改进建议（WARN 项）$' "$prompt"
done

assert_present '问题：\[详细问题\]' "$TECH_LEAD_PLAN_REVIEWER_PROMPT"
assert_present '影响：\[为什么阻断执行\]' "$TECH_LEAD_PLAN_REVIEWER_PROMPT"
assert_present '修复要求：\[如何修正\]' "$TECH_LEAD_PLAN_REVIEWER_PROMPT"
assert_present '建议：\[改进建议\]' "$TECH_LEAD_PLAN_REVIEWER_PROMPT"
assert_absent '修复建议：\[如何修正\]' "$TECH_LEAD_PLAN_REVIEWER_PROMPT"

assert_present '^## 代码审查（Code Review）$' "$REVIEW_TEMPLATE"
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
assert_present '模式选择共创' "$OVERVIEW_SKILL"
assert_present 'AskUserQuestion' "$OVERVIEW_SKILL"
assert_present '未完成模式选择确认前禁止继续' "$OVERVIEW_SKILL"
assert_present "报告模板：\`references/mode-selection\\.md\`" "$OVERVIEW_SKILL"
assert_present '默认推荐自动继续' "$OVERVIEW_MODE_SELECTION"
assert_present '串行概览（更快）' "$OVERVIEW_MODE_SELECTION"
assert_present '分层 agent team 概览（更全面）' "$OVERVIEW_MODE_SELECTION"
assert_present '推荐话术' "$OVERVIEW_MODE_SELECTION"
assert_present '用户确认后再继续' "$OVERVIEW_MODE_SELECTION"
assert_present '返回格式' "$OVERVIEW_AGENT_ASSIGNMENTS"
assert_present '输入边界' "$OVERVIEW_AGENT_ASSIGNMENTS"
assert_present '主代理汇总协议' "$OVERVIEW_AGENT_ASSIGNMENTS"
assert_present '不允许静默回退到串行' "$OVERVIEW_AGENT_ASSIGNMENTS"
assert_present '高差异模式必须在主流程中显式共创选择' "$AGENT_TEAM_PATTERNS"
assert_present '不能只写“用户明确要求时”' "$AGENT_TEAM_PATTERNS"
assert_present '主文档必须写清模式选择触发点' "$NEW_SKILLS_SKILL"
assert_present '用户共创节点' "$NEW_SKILLS_SKILL"

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
assert_present '产品审查 prompt' "$TECH_LEAD_SKILL"
assert_present '测试验收审查 prompt' "$TECH_LEAD_SKILL"
assert_present '3 个 reviewer' "$TECH_LEAD_SKILL"
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

PRODUCT_TEMPLATE="$ROOT/shared/skills/product/references/templates/brief-template.md"
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
assert_present '^### 收敛轮次摘要$' "$PRODUCT_TEMPLATE"
assert_present '^\| 轮次 \| 结果 \| FAIL数 \| 未关闭 Issue IDs \| 控制动作 \| 说明 \|$' "$PRODUCT_TEMPLATE"
assert_present '^### 用户裁决记录$' "$PRODUCT_TEMPLATE"
assert_present '^\| 触发轮次 \| 控制动作 \| 用户决定 \| 关联 Issue IDs \| 记录时间 \| 说明 \|$' "$PRODUCT_TEMPLATE"
assert_no_legacy_review_artifact_ref "$PRODUCT_TEMPLATE"
assert_present '^## 既有约束继承确认$' "$DESIGN_TEMPLATE"
assert_present '^## 上游审查承接$' "$DESIGN_TEMPLATE"
assert_present '^\| Issue ID \| 来源阶段 \| 视角 \| 发现摘要 \| 承接方式 \| 承接位置 \|$' "$DESIGN_TEMPLATE"
assert_present '^\| 决策点识别 \| \| \| \|$' "$DESIGN_TEMPLATE"
assert_present '^## 交付确认$' "$DESIGN_TEMPLATE"
assert_present '^### 审查汇总$' "$DESIGN_TEMPLATE"
assert_present '^\| 视角 \| Verdict \| Issue Count \|$' "$DESIGN_TEMPLATE"
assert_present '^### 审查问题台账$' "$DESIGN_TEMPLATE"
assert_present '^### 收敛轮次摘要$' "$DESIGN_TEMPLATE"
assert_present '^\| 轮次 \| 结果 \| FAIL数 \| 未关闭 Issue IDs \| 控制动作 \| 说明 \|$' "$DESIGN_TEMPLATE"
assert_present '^### 用户裁决记录$' "$DESIGN_TEMPLATE"
assert_present '^\| 触发轮次 \| 控制动作 \| 用户决定 \| 关联 Issue IDs \| 记录时间 \| 说明 \|$' "$DESIGN_TEMPLATE"
assert_no_legacy_review_artifact_ref "$DESIGN_TEMPLATE"
assert_present '^### 审查汇总$' "$TEST_CASES_TEMPLATE"
assert_present '^\| 视角 \| Verdict \| Issue Count \|$' "$TEST_CASES_TEMPLATE"
assert_present '^### 审查问题台账$' "$TEST_CASES_TEMPLATE"
assert_present '^### 收敛轮次摘要$' "$TEST_CASES_TEMPLATE"
assert_present '^\| 轮次 \| 结果 \| FAIL数 \| 未关闭 Issue IDs \| 控制动作 \| 说明 \|$' "$TEST_CASES_TEMPLATE"
assert_present '^### 用户裁决记录$' "$TEST_CASES_TEMPLATE"
assert_present '^\| 触发轮次 \| 控制动作 \| 用户决定 \| 关联 Issue IDs \| 记录时间 \| 说明 \|$' "$TEST_CASES_TEMPLATE"
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
assert_present 'proving_command: \{执行阶段需要 fresh 重跑的真实验证命令' "$PLAN_TEMPLATE"
assert_present 'real_dependency_note: \{说明是否依赖真实服务' "$PLAN_TEMPLATE"
assert_present 'evidence_target: \{指向 dev-report' "$PLAN_TEMPLATE"
assert_present 'mock_boundary_note: \{说明 Mock 仅可用于' "$PLAN_TEMPLATE"
assert_present '^### 审查汇总$' "$PLAN_TEMPLATE"
assert_present '^\| 视角 \| Verdict \| Review Round \| Issue Count \| 结论摘要 \|$' "$PLAN_TEMPLATE"
assert_present '^### 审查问题台账$' "$PLAN_TEMPLATE"
assert_present '^\| Issue ID \| 视角 \| Severity \| Status \| Evidence Anchor \| Handoff Target \| Review Round \| 风险接受记录 \| 处理摘要 \|$' "$PLAN_TEMPLATE"
assert_present '^### 收敛轮次摘要$' "$PLAN_TEMPLATE"
assert_present '^### 用户裁决记录$' "$PLAN_TEMPLATE"
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
assert_present '当前契约样例' "$EVAL_SCENARIO_REVIEW"
assert_present '必须同步刷新这些样例' "$EVAL_SCENARIO_REVIEW"

for artifact in \
  "$EVAL_REVIEW_PRODUCT_RESULT" \
  "$EVAL_REVIEW_ARCH_RESULT" \
  "$EVAL_REVIEW_TEST_RESULT"
do
  assert_present '^\| Issue ID \| Severity \| 维度 \| 发现 \| 证据 \| 承接目标 \|$' "$artifact"
  assert_present '^### 关键问题（FAIL 项详述）$' "$artifact"
  assert_present '^问题：' "$artifact"
  assert_present '^影响：' "$artifact"
  assert_present '^修复要求：' "$artifact"
  assert_present '^### 改进建议（WARN 项）$' "$artifact"
  assert_absent '业务意图偏离程度' "$artifact"
  assert_absent '测试后果' "$artifact"
done

assert_present '^\| DPR-001 \| FAIL \|' "$EVAL_REVIEW_PRODUCT_RESULT"
assert_absent '^\| P-001 \| FAIL \|' "$EVAL_REVIEW_PRODUCT_RESULT"
assert_present '^#### DPR-001：' "$EVAL_REVIEW_PRODUCT_RESULT"

assert_present '^\| DR-001 \| FAIL \|' "$EVAL_REVIEW_ARCH_RESULT"
assert_absent '^\| DA-001 \| FAIL \|' "$EVAL_REVIEW_ARCH_RESULT"
assert_present '^#### DR-001：' "$EVAL_REVIEW_ARCH_RESULT"

assert_present '^\| DTR-001 \| FAIL \|' "$EVAL_REVIEW_TEST_RESULT"
assert_absent '^\| T-001 \| FAIL \|' "$EVAL_REVIEW_TEST_RESULT"
assert_present '^#### DTR-001：' "$EVAL_REVIEW_TEST_RESULT"

PRODUCT_CHECK="$ROOT/shared/skills/product/scripts/completion_check.sh"
DESIGN_CHECK="$ROOT/shared/skills/design/scripts/completion_check.sh"
TECH_LEAD_CHECK="$ROOT/shared/skills/tech-lead/scripts/completion_check.sh"
TEST_DESIGN_CHECK="$ROOT/shared/skills/test-design/scripts/completion_check.sh"
PM_GATE_CHECK="$ROOT/shared/skills/project-manager/scripts/completion_check.sh"
QA_CHECK="$ROOT/shared/skills/qa/scripts/completion_check.sh"
RESEARCH_CHECK="$ROOT/shared/skills/research/scripts/completion_check.sh"

assert_present '"## 交付确认"' "$PRODUCT_CHECK"
assert_present '"交付确认"; do' "$PRODUCT_CHECK"
assert_present '数据行不足 7 条' "$PRODUCT_CHECK"
assert_present '确认状态必须为「确认」' "$PRODUCT_CHECK"
assert_present 'extract_review_summary_row' "$PRODUCT_CHECK"
assert_present 'extract_review_issue_ledger_rows' "$PRODUCT_CHECK"
assert_present 'validate_review_convergence_policy' "$PRODUCT_CHECK"
assert_no_legacy_review_artifact_ref "$PRODUCT_CHECK"

assert_present 'extract_inheritance_rows' "$DESIGN_CHECK"
assert_present '"## 既有约束继承确认"' "$DESIGN_CHECK"
assert_present '"决策点识别"' "$DESIGN_CHECK"
assert_present '处理方式非法' "$DESIGN_CHECK"
assert_present '"## 交付确认"' "$DESIGN_CHECK"
assert_present 'S10 最终确认' "$DESIGN_CHECK"
assert_present 'extract_review_summary_row' "$DESIGN_CHECK"
assert_present 'extract_review_issue_ledger_rows' "$DESIGN_CHECK"
assert_present 'validate_review_convergence_policy' "$DESIGN_CHECK"
assert_no_legacy_review_artifact_ref "$DESIGN_CHECK"

assert_present '"## 用户确认记录"' "$TECH_LEAD_CHECK"
assert_present '用户确认记录状态必须为「确认」' "$TECH_LEAD_CHECK"
assert_present '### 审查汇总' "$TECH_LEAD_CHECK"
assert_present 'proving_command' "$TECH_LEAD_CHECK"
assert_present 'real_dependency_note' "$TECH_LEAD_CHECK"
assert_present 'evidence_target' "$TECH_LEAD_CHECK"
assert_present 'mock_boundary_note' "$TECH_LEAD_CHECK"
assert_present 'COVERED-NO-TEST' "$TECH_LEAD_CHECK"
assert_present 'EX-NO-TEST' "$TECH_LEAD_CHECK"

assert_present '不满足 HARD-GATE 2' "$TEST_DESIGN_CHECK"
assert_present 'extract_review_summary_row' "$TEST_DESIGN_CHECK"
assert_present 'extract_review_issue_ledger_rows' "$TEST_DESIGN_CHECK"
assert_present 'validate_review_convergence_policy' "$TEST_DESIGN_CHECK"
assert_no_legacy_review_artifact_ref "$TEST_DESIGN_CHECK"

test -f "$QA_CHECK" || fail "missing qa completion_check.sh"
assert_present 'qa-report\.md' "$QA_CHECK"
assert_present '审查分级' "$QA_CHECK"
assert_present '## 验收汇总' "$QA_CHECK"
assert_present 'QA_A/QA_B/QA_C/QA_D' "$QA_CHECK"
assert_present 'RESULT: PASS \| FAIL' "$QA_CHECK"

test -f "$RESEARCH_CHECK" || fail "missing research completion_check.sh"
assert_present 'research-report\.md' "$RESEARCH_CHECK"
assert_present '呈现模式' "$RESEARCH_CHECK"
assert_present 'decision\|understanding\|audit' "$RESEARCH_CHECK"
assert_present '章节顺序错误' "$RESEARCH_CHECK"

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

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-valid" "已收口" "no" "complete" "valid" "valid" "valid" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-valid" "session-valid"
assert_tech_lead_check_passes "valid exploration-first plan"

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-future-task" "已收口" "yes" "complete" "valid" "valid" "valid" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-future-task" "session-future-task"
assert_tech_lead_check_fails_with "future task leak" '未解锁批次之外的 Task|当前已解锁批次之外'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-incomplete-replan" "已收口" "no" "missing_fields" "valid" "valid" "valid" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-incomplete-replan" "session-incomplete-replan"
assert_tech_lead_check_fails_with "incomplete replan rules" '再计划与解锁规则.*不完整|缺少.*再计划触发条件'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-design-open" "未收口" "no" "complete" "valid" "valid" "valid" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-design-open" "session-design-open"
assert_tech_lead_check_fails_with "open design decisions" '设计决策状态.*已收口|未收口'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-revision-placeholder" "已收口" "no" "complete" "placeholder" "valid" "valid" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-revision-placeholder" "session-revision-placeholder"
assert_tech_lead_check_fails_with "plan revision placeholder" '计划修订记录.*占位|计划修订记录.*有效数据'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-missing-review-summary" "已收口" "no" "complete" "valid" "missing_summary" "valid" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-missing-review-summary" "session-missing-review-summary"
assert_tech_lead_check_fails_with "missing review summary" '独立审查收敛.*审查汇总|缺少产品视角结论行'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-warn-without-handoff" "已收口" "no" "complete" "valid" "warn_without_handoff" "valid" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-warn-without-handoff" "session-warn-without-handoff"
assert_tech_lead_check_fails_with "warn without handoff" 'WARN 项 .*缺少 Handoff Target|缺少风险接受记录|缺少处理摘要'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-missing-proving-command" "已收口" "no" "complete" "valid" "valid" "missing_proving_command" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-missing-proving-command" "session-missing-proving-command"
assert_tech_lead_check_fails_with "missing proving command" 'proving_command'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-mock-only-evidence" "已收口" "no" "complete" "valid" "valid" "mock_only" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-mock-only-evidence" "session-mock-only-evidence"
assert_tech_lead_check_fails_with "mock used as final acceptance evidence" 'Mock.*最终验收|最终验收.*Mock|真实依赖'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-missing-evidence-target" "已收口" "no" "complete" "valid" "valid" "missing_evidence_target" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-missing-evidence-target" "session-missing-evidence-target"
assert_tech_lead_check_fails_with "missing evidence target" 'evidence_target'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-semantic-real-dependency" "已收口" "no" "complete" "valid" "valid" "semantic_real_dependency" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-semantic-real-dependency" "session-semantic-real-dependency"
assert_tech_lead_check_passes "semantic real dependency note should pass"

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-noop-proving-command" "已收口" "no" "complete" "valid" "valid" "noop_proving_command" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-noop-proving-command" "session-noop-proving-command"
assert_tech_lead_check_fails_with "noop proving command should fail" 'proving_command.*真实验证|proving_command.*空心|proving_command.*不得'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-unanchored-evidence-target" "已收口" "no" "complete" "valid" "valid" "unanchored_evidence_target" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-unanchored-evidence-target" "session-unanchored-evidence-target"
assert_tech_lead_check_fails_with "unanchored evidence target should fail" 'evidence_target.*锚点|evidence_target.*#'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-coverage-gap-without-handoff" "已收口" "no" "complete" "valid" "valid" "valid" "coverage_gap"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-coverage-gap-without-handoff" "session-coverage-gap-without-handoff"
assert_tech_lead_check_fails_with "coverage gap without explicit handoff" 'COVERED-NO-TEST.*测试验收|测试验收视角.*PASS'

PRODUCT_HOOK_ROOT="$HOOK_FIXTURE_ROOT/product-hook"
mkdir -p "$PRODUCT_HOOK_ROOT/docs/product-hook/phase-1/units"
cat > "$PRODUCT_HOOK_ROOT/docs/product-hook/brief.md" <<'EOF'
# Brief

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
  "docs/product-hook/brief.md\n" \
  "Write" \
  "docs/product-hook/brief.md"
assert_last_check_fails_with "product hook late-stage missing confirmation" 'brief.md 缺少章节：## 交付确认|缺少「交付确认」章节'

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

PM_EVIDENCE_ROOT="$HOOK_FIXTURE_ROOT/project-manager-evidence"

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-noop-proving" "noop_proving_command" "noop_proving_command" "valid"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-noop-proving" \
  "docs/pm-noop-proving/phase-1/unit-1/dev-report.md\ndocs/pm-noop-proving/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-noop-proving/phase-1/acceptance-summary.md"
assert_last_check_fails_with "project-manager noop proving command should fail" 'D5\[unit-1\]: Task-1 proving_command.*空心命令|D5\[unit-1\]: Task-1 proving_command.*真实验证'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-unanchored-evidence" "unanchored_evidence_target" "unanchored_evidence_target" "valid"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-unanchored-evidence" \
  "docs/pm-unanchored-evidence/phase-1/unit-1/dev-report.md\ndocs/pm-unanchored-evidence/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-unanchored-evidence/phase-1/acceptance-summary.md"
assert_last_check_fails_with "project-manager unanchored evidence target should fail" 'D5\[unit-1\]: Task-1 evidence_target.*锚点|D5\[unit-1\]: Task-1 evidence_target.*#'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-drift-command" "valid" "drift_proving_command" "valid"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-drift-command" \
  "docs/pm-drift-command/phase-1/unit-1/dev-report.md\ndocs/pm-drift-command/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-drift-command/phase-1/acceptance-summary.md"
assert_last_check_fails_with "project-manager proving command drift should fail" 'D5\[unit-1\]: Task-1 proving_command 与 plan\.md 不一致'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-summary-only-output" "valid" "valid" "summary_only"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-summary-only-output" \
  "docs/pm-summary-only-output/phase-1/unit-1/dev-report.md\ndocs/pm-summary-only-output/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-summary-only-output/phase-1/acceptance-summary.md"
assert_last_check_fails_with "project-manager summary-only fresh output should fail" 'D5\[unit-1\]: Task-1 Fresh proving command.*完整输出|D5\[unit-1\]: Task-1 Fresh proving command.*摘要'

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
