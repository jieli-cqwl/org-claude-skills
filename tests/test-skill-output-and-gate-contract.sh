#!/usr/bin/env bash
set -euo pipefail

export ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=1

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

assert_no_subagent_chapter() {
  local file="$1"
  assert_absent '^## .*Sub-Agent' "$file"
  assert_absent '^## .*sub agent' "$file"
  assert_absent '^## .*共享 Sub-Agent' "$file"
  assert_absent '^## .*草稿回收记录' "$file"
  assert_absent '^### .*Sub-Agent' "$file"
  assert_absent '^### .*sub agent' "$file"
  assert_absent '^### .*共享 Sub-Agent' "$file"
  assert_absent '^### .*草稿回收记录' "$file"
}

assert_present 'authority_contract:' "$ROOT/contracts/skill-chain.yaml"
assert_present 'phase_delivery_owner: delivery-owner' "$ROOT/contracts/skill-chain.yaml"
assert_present 'quality_judgment_owner: qa' "$ROOT/contracts/skill-chain.yaml"
assert_present 'business_risk_acceptance_owner: user' "$ROOT/contracts/skill-chain.yaml"
assert_present 'plan_version' "$ROOT/contracts/skill-chain.yaml"
assert_present 'delivery_confirmation' "$ROOT/contracts/skill-chain.yaml"
assert_present 'entry_conditions' "$ROOT/contracts/skill-chain.yaml"
assert_present 'exit_conditions' "$ROOT/contracts/skill-chain.yaml"
assert_present 'unit_id' "$ROOT/contracts/skill-chain.yaml"
assert_present 'qa_handoff_contract' "$ROOT/contracts/skill-chain.yaml"
assert_present 'ruled_out_issues' "$ROOT/contracts/skill-chain.yaml"
assert_absent 'non_functional_req([[:space:]\],]|$)' "$ROOT/contracts/skill-chain.yaml"
assert_absent 'entry_exit_conditions' "$ROOT/contracts/skill-chain.yaml"
assert_present '当前 Phase 的交付目标负责人' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present "在 \`Scope Freeze\` 内可重排批次、优先级和质量门禁强度" "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present 'replan_request' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_absent 'rebaseline' "$ROOT/shared/skills/delivery-owner/SKILL.md"
assert_present 'planning owner' "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_present 'execution kickoff、执行期 gate 升档、最终 sign-off 和业务风险接受' "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_present '独立质量判断 owner' "$ROOT/shared/skills/qa/SKILL.md"
assert_present '不负责用户 sign-off，也不接受业务风险' "$ROOT/shared/skills/qa/SKILL.md"
assert_present 'Task 实现 owner' "$ROOT/shared/skills/developer/SKILL.md"
assert_present "复杂度偏差、接口漂移、依赖漂移和不收敛信号结构化回传给 \`delivery-owner\`" "$ROOT/shared/skills/developer/SKILL.md"
assert_present '## 权责矩阵' "$ROOT/docs/delivery-owner-role-20260411/authority-matrix.md"
assert_present 'Delivery Kickoff Checklist' "$ROOT/shared/skills/delivery-owner/references/kickoff-checklist.md"
assert_present '## 目标闭环' "$ROOT/docs/delivery-owner-role-20260411/goal-evidence-model.md"
assert_present '## 冻结说明' "$ROOT/docs/delivery-owner-role-20260411/goal-evidence-model.md"
assert_present 'goal_source_ref' "$ROOT/docs/delivery-owner-role-20260411/goal-evidence-model.md"
assert_present 'execution_basis_ref' "$ROOT/docs/delivery-owner-role-20260411/goal-evidence-model.md"
assert_present 'Pilot：总分' "$ROOT/docs/delivery-owner-role-20260411/quality-rubric.md"
assert_present '## 冻结说明' "$ROOT/docs/delivery-owner-role-20260411/quality-rubric.md"
assert_present 'pilot_object:' "$ROOT/docs/delivery-owner-role-20260411/pilot-evidence.md"
assert_present 'rubric_score:' "$ROOT/docs/delivery-owner-role-20260411/pilot-evidence.md"
assert_present 'residual_risk_ref:' "$ROOT/docs/delivery-owner-role-20260411/pilot-evidence.md"
assert_present 'delivery-owner rollout gate contract' "$ROOT/tests/test-delivery-owner-rollout-gate.sh"
assert_present 'delivery-owner replay contract' "$ROOT/tests/test-delivery-owner-replay-contract.sh"
assert_present 'readiness failure' "$ROOT/docs/delivery-owner-role-20260411/replay-scenarios.md"
assert_present '## 冻结说明' "$ROOT/docs/delivery-owner-role-20260411/replay-scenarios.md"
assert_present '## 计划版本' "$ROOT/shared/skills/tech-lead/references/templates/plan-template.md"
assert_present 'plan_version:' "$ROOT/shared/skills/tech-lead/references/templates/plan-template.md"
assert_present '## 引用锚点合同' "$ROOT/shared/skills/product/references/templates/brief-template.md"
assert_present '## 引用锚点合同' "$ROOT/shared/skills/product/references/templates/phase-prd-template.md"
assert_present '## 引用锚点合同' "$ROOT/shared/skills/design/references/templates/design-template.md"
assert_present '## 引用锚点合同' "$ROOT/shared/skills/test-design/references/templates/test-cases-template.md"
assert_present 'plan_version_ref' "$ROOT/shared/skills/delivery-owner/references/kickoff-checklist.md"
assert_present '## 运行态协议' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_present '## 编排协议' "$ROOT/shared/skills/delivery-owner/references/dispatch-guide.md"
assert_present 'last_observed_at:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'runtime_snapshot:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'active_blocker:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'blocker_owner:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'takeover_note:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'decision_basis:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'dispatch_mode:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'current_batch:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'batch_unlock_condition:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'merge_readiness:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'next_action:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'plan_version_ref:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'plan_version_value:' "$ROOT/shared/skills/delivery-owner/references/templates/dev-report-template.md"
assert_present 'plan_version_ref:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present '## 最新状态摘要' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'last_observed_at:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'runtime_snapshot:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'active_blocker:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'blocker_owner:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'takeover_note:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'decision_basis:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'current_plan_version_ref:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'current_plan_version_value:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'plan_version_ref:' "$ROOT/shared/skills/qa/references/templates/qa-report-template.md"
assert_present 'plan_version_value:' "$ROOT/shared/skills/qa/references/templates/qa-report-template.md"
assert_present 'issue_ledger_anchor:' "$ROOT/shared/skills/qa/references/templates/qa-report-template.md"
assert_present 'sign_off_status:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'business_risk_acceptance_status:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'risk_acceptance_basis:' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'goal_source_ref' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'execution_basis_ref' "$ROOT/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md"
assert_present 'runtime prompt 去章节化' "$ROOT/docs/harness-prompt-noise-optimization-20260412/best-practice-plan.md"
assert_present 'sub agent 只在使用点出现' "$ROOT/docs/harness-prompt-noise-optimization-20260412/best-practice-plan.md"
assert_present 'central truth 保留但引用说明收缩' "$ROOT/docs/harness-prompt-noise-optimization-20260412/implementation-plan.md"

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

  run_completion_check_with_raw_payload "$script" "$payload"
}

run_completion_check_with_raw_payload() {
  local script="$1"
  local payload="$2"

  LAST_CHECK_STDOUT="$(mktemp "${TMPDIR:-/tmp}/org-hook-check.stdout.XXXXXX")"
  LAST_CHECK_STDERR="$(mktemp "${TMPDIR:-/tmp}/org-hook-check.stderr.XXXXXX")"
  LAST_CHECK_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/org-hook-check.XXXXXX")"
  if bash "$script" >"$LAST_CHECK_STDOUT" 2>"$LAST_CHECK_STDERR" <<<"$payload"; then
    LAST_CHECK_STATUS=0
  else
    LAST_CHECK_STATUS=$?
  fi
  cat "$LAST_CHECK_STDOUT" "$LAST_CHECK_STDERR" >"$LAST_CHECK_OUTPUT"
}

run_completion_check_with_raw_payload_and_path() {
  local script="$1"
  local payload="$2"
  local custom_path="$3"

  LAST_CHECK_STDOUT="$(mktemp "${TMPDIR:-/tmp}/org-hook-check.stdout.XXXXXX")"
  LAST_CHECK_STDERR="$(mktemp "${TMPDIR:-/tmp}/org-hook-check.stderr.XXXXXX")"
  LAST_CHECK_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/org-hook-check.XXXXXX")"
  if PATH="$custom_path" bash "$script" >"$LAST_CHECK_STDOUT" 2>"$LAST_CHECK_STDERR" <<<"$payload"; then
    LAST_CHECK_STATUS=0
  else
    LAST_CHECK_STATUS=$?
  fi
  cat "$LAST_CHECK_STDOUT" "$LAST_CHECK_STDERR" >"$LAST_CHECK_OUTPUT"
}

create_test_design_browser_fixture() {
  local root_dir="$1"
  local feature_name="$2"
  local handoff_variant="${3:-valid}"
  local feature_dir="$root_dir/docs/$feature_name"
  local phase_dir="$feature_dir/phase-1"
  local unit_dir="$phase_dir/unit-1"
  local execution_mode_e2e="browser_required"
  local execution_mode_ux="browser_required"
  local execution_mode_recovery="browser_required"
  local e2e_trigger_source="Web/H5 登录 + 重定向 + 路由守卫"
  local ux_trigger_source="Web/H5 页面状态反馈 + 关键 UX 检查点"
  local recovery_trigger_source="Web/H5 错误提示 + 恢复路径"

  mkdir -p "$phase_dir/units" "$unit_dir" "$phase_dir/design"

  case "$handoff_variant" in
    missing_execution_mode)
      execution_mode_e2e=""
      ;;
    browser_signal_non_browser)
      execution_mode_e2e="non_browser_ok"
      execution_mode_ux="non_browser_ok"
      execution_mode_recovery="non_browser_ok"
      ;;
    ux_template_non_browser)
      execution_mode_e2e="non_browser_ok"
      execution_mode_ux="non_browser_ok"
      execution_mode_recovery="non_browser_ok"
      e2e_trigger_source="CLI 主流程"
      ux_trigger_source="ux.md / 交互约束 / 可用性风险"
      recovery_trigger_source="中断/重试/幂等/补偿风险"
      ;;
  esac

  cat > "$feature_dir/brief.md" <<'EOF'
# Brief

## 前置约束
- 无前置约束（经评估）
EOF

  cat > "$phase_dir/prd.md" <<'EOF'
# Phase 1

## 功能需求（UNIT 索引）

| UNIT | 标题 | 闭环目标 | 优先级 | 依赖 | 定义文件 |
|------|------|----------|--------|------|----------|
| UNIT-1 | 登录旅程 | 用户可完成登录并看到反馈 | MVP | - | units/UNIT-1.md |
EOF

  cat > "$phase_dir/units/UNIT-1.md" <<'EOF'
# UNIT-1

## AC
- AC-U1-01：用户可以通过登录页完成登录，并看到成功反馈
EOF

  cat > "$phase_dir/design.md" <<'EOF'
# design

## 覆盖表
| UNIT | requirement_type | requirement_ref | requirement_desc | scope_item_id | design_ref | status |
|------|------------------|-----------------|------------------|---------------|------------|--------|
| UNIT-1 | AC | AC-U1-01 | 用户可完成登录并看到成功反馈 | SCOPE-P1U1-001 | MOD-001 | COVERED |

## 影响范围清单
- SCOPE-P1U1-001: 登录页与登录成功反馈

## 质量属性
- 需要验证登录页状态反馈、错误提示与恢复路径
EOF

  cat > "$phase_dir/design/MOD-001.md" <<'EOF'
# MOD-001
EOF

  cat > "$unit_dir/test-cases.md" <<EOF
# test-cases.md

## 用例统计
| 类别 | 数量 |
|------|------|
| 正例 | 1 |
| 反例 | 1 |
| 边界 | 1 |
| 排除项验证 | 1 |
| 专项测试 | 0 |
| 合计 | 4 |

## UNIT 覆盖视图
| UNIT | 闭环目标 | 关联 AC | 用例编号 | 覆盖状态 |
|------|----------|---------|---------|---------|
| UNIT-1 | 用户完成登录并收到成功反馈 | AC-U1-01 | TC-U1-001, TC-U1-002, TC-U1-003 | COVERED |

## AC 覆盖矩阵
| UNIT | AC 编号 | AC 描述 | scope_item_id | 用例编号 | 类型（正例/反例/边界） | 覆盖状态 |
|------|---------|---------|---------------|---------|----------------------|---------|
| UNIT-1 | AC-U1-01 | 用户完成登录并收到成功反馈 | SCOPE-P1U1-001 | TC-U1-001, TC-U1-002, TC-U1-003 | 正例, 反例, 边界 | COVERED |

## 等价性对照矩阵
| scope_item_id | 关联 AC | 关联 TC | 对照输入 | 不变量 | 结果状态 | 备注 |
|---------------|---------|---------|----------|--------|----------|------|
| SCOPE-P1U1-001 | AC-U1-01 | TC-U1-001, TC-U1-003 | 正常账号 / 错误密码 | 登录成功后页面反馈一致 | EQ-COVERED | qa-login-journey |

## Design 问题报告
无设计缺口。

## 测试用例

### TC-U1-001: 登录成功
- 关联 UNIT: UNIT-1
- 关联 AC: AC-U1-01
- scope_item_id: SCOPE-P1U1-001
- 类型: 正例
- 前置条件: 存在可用测试账号
- 输入/操作: 在登录页输入正确账号密码并提交
- 期望输出: 登录成功，页面展示成功反馈
- 验证命令: 运行真实登录流程并检查页面反馈

### TC-U1-002: 登录失败提示
- 关联 UNIT: UNIT-1
- 关联 AC: AC-U1-01
- scope_item_id: SCOPE-P1U1-001
- 类型: 反例
- 前置条件: 存在测试账号
- 输入/操作: 输入错误密码并提交
- 期望输出: 页面展示明确错误提示
- 验证命令: 运行登录失败流程并核对错误提示

### TC-U1-003: 登录边界
- 关联 UNIT: UNIT-1
- 关联 AC: AC-U1-01
- scope_item_id: SCOPE-P1U1-001
- 类型: 边界
- 前置条件: 输入框已聚焦
- 输入/操作: 使用边界长度账号密码提交
- 期望输出: 页面反馈符合设计约束
- 验证命令: 使用边界数据执行登录流程并核对反馈

### TC-U1-004: 排除项验证
- 关联 UNIT: UNIT-1
- 关联 AC: AC-U1-01
- scope_item_id: SCOPE-P1U1-001
- 类型: 排除项验证
- 前置条件: 系统正常运行
- 输入/操作: 尝试绕过登录页直接进入受保护路由
- 期望输出: 被重定向回登录页
- 验证命令: 直接访问受保护路由并核对重定向

## QA 交接契约

| test_obligation | trigger_source | qa_stage | requiredness | execution_mode | skip_rule | evidence_expectation |
|-----------------|----------------|----------|--------------|----------------|-----------|----------------------|
| 冒烟 | 默认强制 | QA_A | REQUIRED | non_browser_ok | 不可跳过 | 启动命令 + 健康检查 + 关键入口可用 |
| AC/功能 | AC 覆盖矩阵 | QA_A | REQUIRED | non_browser_ok | 不可跳过 | AC 追踪表 + 规则级证据 |
| API/接口 | design.md / 登录接口 | QA_A | REQUIRED | non_browser_ok | 不可跳过 | 请求/响应证据 + 错误路径验证 |
| E2E | ${e2e_trigger_source} | QA_B | REQUIRED | ${execution_mode_e2e} | 未触发时必须写未触发原因 | 旅程表 + 页面状态反馈 + 数据流转证据 |
| 回归 | 变更影响面分析 | QA_C | REQUIRED | non_browser_ok | 不可跳过 | 回归命令 + 影响面验证 |
| 探索 | 风险清单 / 未知交互面 | QA_D | CONDITIONAL | non_browser_ok | 未触发时必须写风险评估结论 | 章程 + 发现记录 |
| UX | ${ux_trigger_source} | QA_B | CONDITIONAL | ${execution_mode_ux} | 未触发时必须写不执行理由 | 检查点 + 截图/录屏/描述证据 |
| 异常恢复 | ${recovery_trigger_source} | QA_B | CONDITIONAL | ${execution_mode_recovery} | 未触发时必须写不执行理由 | 恢复路径证据 + 截图 |
| NFR | 暂未命中专项 | NFR | CONDITIONAL | non_browser_ok | 未触发，当前需求无专项测试触发信号 | 延后说明 |

## 审查结论
### 审查汇总

| 视角 | Verdict | Issue Count |
|------|---------|-------------|
| 测试质量 | WARN | 1 |
| 产品 | PASS | 0 |
| 架构 | PASS | 0 |

TQR-001: 已修正 QA 交接契约中的 execution_mode，并将浏览器旅程承接到 QA_B。

### 审查问题台账

| Issue ID | 视角 | Severity | Status | Evidence Anchor | Handoff Target | Review Round | 处理摘要 |
| TQR-001 | 测试质量 | P2 | OPEN | test-cases.md#qa-交接契约 | TC-U1-001 | R1 | 已补 execution_mode 与浏览器触发说明 |

### 收敛轮次摘要

| 轮次 | 结果 | FAIL数 | 未关闭 Issue IDs | 控制动作 | 说明 |
|------|------|-------|------------------|----------|------|
| R1 | FAIL | 1 | TQR-001 | CONTINUE | 首轮补齐 QA 交接契约中的浏览器执行模式 |
| R2 | PASS | 0 | 无 | CONFIRMATION | 确认轮通过，允许进入 tech-lead |

### 用户裁决记录

| 触发轮次 | 控制动作 | 用户决定 | 关联 Issue IDs | 记录时间 | 说明 |
EOF
}

create_qa_browser_fixture() {
  local root_dir="$1"
  local feature_name="$2"
  local report_variant="${3:-valid}"
  local feature_dir="$root_dir/docs/$feature_name"
  local phase_dir="$feature_dir/phase-1"
  local unit_dir="$phase_dir/unit-1"
  local browser_evidence_line='browser_evidence: screenshot=artifacts/login-success.png; trace/video=artifacts/login-trace.zip'
  local journey_design_rows='| 1 | 登录成功旅程 | 核心路径 | AC-U1-01 | browser_required | 3 |'
  local journey_execution_block='#### 旅程 1: 登录成功旅程
| 步骤 | 操作 | 输入 | 期望输出 | 实际输出 | 状态 |
|------|------|------|---------|---------|------|
| 1 | 打开登录页 | /login | 页面可见 | 页面可见 | PASS |
| 2 | 输入正确账号密码 | valid-user | 可提交 | 可提交 | PASS |
| 3 | 提交登录 | click submit | 跳转首页并展示成功反馈 | 跳转首页并展示成功反馈 | PASS |'
  local data_flow_rows='| 2 -> 3 | 已输入账号密码 | 登录请求体 | 一致 |'
  local browser_tool_line='browser_tool: webapp-testing / Playwright'
  local entry_url_line='entry_url: http://localhost:3000/login'
  local referenced_test_cases='- test_cases_refs: unit-1/test-cases.md'
  local unit1_handoff='| E2E | Web/H5 登录 + 重定向 + 路由守卫 | QA_B | REQUIRED | browser_required | 未触发时必须写未触发原因 | 旅程表 + 页面状态反馈 + 数据流转证据 |
| UX | Web/H5 页面状态反馈 + 关键 UX 检查点 | QA_B | CONDITIONAL | browser_required | 未触发时必须写不执行理由 | 检查点 + 截图/录屏/描述证据 |
| 异常恢复 | Web/H5 错误提示 + 恢复路径 | QA_B | CONDITIONAL | browser_required | 未触发时必须写不执行理由 | 恢复路径证据 + 截图 |'

  mkdir -p "$unit_dir"

  cat > "$phase_dir/plan.md" <<'EOF'
## 计划版本
- plan_version: v1
- 版本说明: QA 夹具当前消费的唯一执行基线
EOF

  case "$report_variant" in
    missing_browser_evidence)
      browser_evidence_line=""
      ;;
    api_only_browser_evidence)
      browser_evidence_line='browser_evidence: api_response=200; curl_log=artifacts/login-api.log'
      ;;
    placeholder_browser_evidence)
      browser_evidence_line='browser_evidence: screenshot=待补; webapp-testing=TODO'
      ;;
    empty_journey_body)
      journey_design_rows=''
      journey_execution_block=''
      data_flow_rows=''
      ;;
    unreferenced_browser_required)
      browser_tool_line=''
      entry_url_line=''
      browser_evidence_line=''
      unit1_handoff='| E2E | CLI 主流程 | QA_B | REQUIRED | non_browser_ok | 未触发时必须写未触发原因 | 旅程表 + 数据流转证据 |'
      mkdir -p "$phase_dir/unit-2"
      cat > "$phase_dir/unit-2/test-cases.md" <<'EOF'
# test-cases.md

## QA 交接契约
| test_obligation | trigger_source | qa_stage | requiredness | execution_mode | skip_rule | evidence_expectation |
|-----------------|----------------|----------|--------------|----------------|-----------|----------------------|
| E2E | Web/H5 登录 + 重定向 + 路由守卫 | QA_B | REQUIRED | browser_required | 未触发时必须写未触发原因 | 旅程表 + 页面状态反馈 + 数据流转证据 |
EOF
      journey_design_rows='| 1 | CLI 主流程 | 核心路径 | AC-U1-01 | non_browser_ok | 2 |'
      journey_execution_block='#### 旅程 1: CLI 主流程
| 步骤 | 操作 | 输入 | 期望输出 | 实际输出 | 状态 |
|------|------|------|---------|---------|------|
| 1 | 执行命令 | run | 命令成功 | 命令成功 | PASS |'
      data_flow_rows='| 1 -> 1 | 命令输出 | 后续校验 | 一致 |'
      ;;
  esac

  cat > "$unit_dir/test-cases.md" <<'EOF'
# test-cases.md

## QA 交接契约
| test_obligation | trigger_source | qa_stage | requiredness | execution_mode | skip_rule | evidence_expectation |
|-----------------|----------------|----------|--------------|----------------|-----------|----------------------|
EOF
  printf '%s\n' "$unit1_handoff" >> "$unit_dir/test-cases.md"

  cat >> "$phase_dir/qa-report.md" <<EOF
审查分级: 完整
执行范围: 验证-B
plan_version_ref: plan.md#计划版本
plan_version_value: v1
release_recommendation: 放行
residual_risk: 低，剩余风险已被浏览器旅程验收覆盖
uncovered_boundary: 无
conditional_release_basis: 无
issue_ledger_anchor: qa-report.md#fail-details

## 验收汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | N/A | 0 | scope=验证-B，本轮未执行 |
| QA_B（E2E 旅程） | OK | 0 | 浏览器旅程验收通过 |
| QA_C（回归验证） | N/A | 0 | scope=验证-B，本轮未执行 |
| QA_D（探索性测试） | N/A | 0 | scope=验证-B，本轮未执行 |

## 非执行项记录
| stage_or_obligation | not_executed_reason |
|---------------------|---------------------|
| QA_A | scope=验证-B，本轮未执行 |
| QA_C | scope=验证-B，本轮未执行 |
| QA_D | scope=验证-B，本轮未执行 |

## 验证-B: E2E 用户旅程
### 覆盖范围
- UNIT 集合: {UNIT-1}
${referenced_test_cases}

### 旅程设计
| # | 旅程名称 | 类型 | 涉及 AC | execution_mode | 步骤数 |
|---|---------|------|---------|----------------|--------|
${journey_design_rows}

### 浏览器执行信息（execution_mode=browser_required 时必填）
${browser_tool_line}
${entry_url_line}
${browser_evidence_line}

### 旅程执行
${journey_execution_block}

#### 数据流转验证
| 步骤 | 前序输出 | 后续输入 | 一致性 |
|------|---------|---------|--------|
${data_flow_rows}

#### UX / 异常恢复检查点
| obligation | 检查点 | 状态 | 证据 | not_executed_reason |
|------------|--------|------|------|---------------------|
| UX | 登录成功反馈可见 | DONE | evidence-ux-1 | N/A |
| 异常恢复 | 错误密码后可重试 | DONE | evidence-recovery-1 | N/A |

### 验证-B 结论
QA_B_OK

## 已排除潜在问题
| # | 潜在问题 | 排除依据 | 证据 |
|---|---------|---------|------|
| 1 | 登录成功后路由未切换 | 浏览器旅程已验证跳转 | evidence-1 |
| 2 | 页面成功反馈缺失 | 浏览器执行证据已覆盖 | evidence-2 |

## FAIL 详情
| Issue ID | 阶段 | severity | priority | impact_scope | user_impact | environment_or_build | regression_flag | temporary_workaround | owner_hint | 期望行为 | 实际行为 | 复现命令 |
|----------|------|----------|----------|--------------|-------------|----------------------|-----------------|----------------------|------------|---------|---------|---------|

RESULT: PASS
EOF
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

assert_last_check_blocks_with() {
  local label="$1"
  local pattern="$2"
  assert_last_check_fails_with "$label" "$pattern"
  assert_last_check_stdout_json "$label" "block"
}

assert_last_check_stdout_json() {
  local label="$1"
  local decision="$2"
  jq -e --arg decision "$decision" '.decision == $decision' "$LAST_CHECK_STDOUT" >/dev/null 2>&1 || {
    cat "$LAST_CHECK_STDOUT" >&2
    fail "${label}: stdout missing decision=$decision JSON"
  }
}

assert_last_check_stdout_nonempty() {
  local label="$1"
  [ -s "$LAST_CHECK_STDOUT" ] || {
    cat "$LAST_CHECK_OUTPUT" >&2
    fail "${label}: stdout should not be empty"
  }
}

assert_last_check_contains() {
  local label="$1"
  local pattern="$2"
  rg -n "$pattern" "$LAST_CHECK_OUTPUT" >/dev/null 2>&1 || {
    cat "$LAST_CHECK_OUTPUT" >&2
    fail "${label}: missing output pattern: $pattern"
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
  local goal_review_variant="${10:-valid}"
  local metric_guardrail_variant="${11:-valid}"

  local feature_dir="$root_dir/docs/$feature_name"
  local phase_dir="$feature_dir/phase-1"
  local task_1_baseline_note="当前没有统一的 fresh 验证基线，需要先跑 bash tests/run-all.sh 记录结果"
  local task_1_guardrail_note="不得弱化登录成功/失败反馈与真实依赖验证链路"
  local goal_review_block=""
  local extra_brief_goal_row=""

  mkdir -p "$phase_dir/units" "$phase_dir/unit-1" "$phase_dir/design"

  case "$metric_guardrail_variant" in
    missing_baseline)
      task_1_baseline_note="{待补 baseline note}"
      ;;
    missing_guardrail)
      task_1_guardrail_note="{待补 guardrail note}"
      ;;
  esac

  case "$goal_review_variant" in
    valid)
      goal_review_block=$(cat <<'EOF'
## 目标闭环与执行度量
| 目标 | goal_source_ref | 承接 Task | execution_basis_ref | 成功信号 | 基线 | 护栏 | 说明 |
|------|-----------------|----------|---------------------|---------|------|------|------|
| 登录旅程完成 | brief.md#目标与成功标准 | Task-1 | plan.md#Task-1 + design.md#覆盖表 | 登录探索路径可被 fresh 验证并保留明确反馈 | 当前没有统一的 fresh 验证基线，以现有证据分散为基线 | 不得放宽登录成功/失败反馈与真实依赖验证要求 | 承接 brief 目标 |
| 探索可行性验证 | prd.md#阶段目标 | Task-1 | plan.md#Task-1 + test-cases.md#tc-u1-001-探索任务验证 | 探索结论足够解锁下一批次 | 当前需先确认可行路径，无稳定执行基线 | 不得跳过真实验证命令与证据锚点 | 承接当前 phase 目标 |
EOF
)
      ;;
    missing_section)
      goal_review_block=""
      ;;
    invalid_goal_source_ref)
      goal_review_block=$(cat <<'EOF'
## 目标闭环与执行度量
| 目标 | goal_source_ref | 承接 Task | execution_basis_ref | 成功信号 | 基线 | 护栏 | 说明 |
|------|-----------------|----------|---------------------|---------|------|------|------|
| 登录旅程完成 | design.md#覆盖表 | Task-1 | plan.md#Task-1 | 登录探索路径可被 fresh 验证并保留明确反馈 | 当前没有统一的 fresh 验证基线 | 不得放宽登录成功/失败反馈与真实依赖验证要求 | 故意制造非法来源引用 |
EOF
)
      ;;
    duplicate_brief_goal_rows)
      goal_review_block=$(cat <<'EOF'
## 目标闭环与执行度量
| 目标 | goal_source_ref | 承接 Task | execution_basis_ref | 成功信号 | 基线 | 护栏 | 说明 |
|------|-----------------|----------|---------------------|---------|------|------|------|
| 登录旅程完成 | brief.md#目标与成功标准 | Task-1 | plan.md#Task-1 + design.md#覆盖表 | 登录探索路径可被 fresh 验证并保留明确反馈 | 当前没有统一的 fresh 验证基线，以现有证据分散为基线 | 不得放宽登录成功/失败反馈与真实依赖验证要求 | 承接 brief 目标的第一条执行度量 |
| 登录旅程完成 | brief.md#目标与成功标准 | Task-1 | plan.md#Task-1 + test-cases.md#tc-u1-001-探索任务验证 | 探索任务完成后可给出下一步实施依据 | 当前基线仍需由 fresh 命令补齐 | 不得跳过 QA 交接契约与真实验证 | 同一上游目标拆成第二条执行度量 |
| 探索可行性验证 | prd.md#阶段目标 | Task-1 | plan.md#Task-1 + test-cases.md#tc-u1-001-探索任务验证 | 探索结论足够解锁下一批次 | 当前需先确认可行路径，无稳定执行基线 | 不得跳过真实验证命令与证据锚点 | 承接当前 phase 目标 |
EOF
)
      ;;
    missing_second_brief_goal_same_count)
      extra_brief_goal_row='| 二次校验完成 | 用户可以在登录后完成二次校验 | 机械型 | 登录后二次校验成功率 62% | 成功率提升至 85% | 14 天 | 行为埋点 |'
      goal_review_block=$(cat <<'EOF'
## 目标闭环与执行度量
| 目标 | goal_source_ref | 承接 Task | execution_basis_ref | 成功信号 | 基线 | 护栏 | 说明 |
|------|-----------------|----------|---------------------|---------|------|------|------|
| 登录旅程完成 | brief.md#目标与成功标准 | Task-1 | plan.md#Task-1 + design.md#覆盖表 | 登录探索路径可被 fresh 验证并保留明确反馈 | 当前没有统一的 fresh 验证基线，以现有证据分散为基线 | 不得放宽登录成功/失败反馈与真实依赖验证要求 | 只承接了第一个 brief 目标 |
| 登录旅程完成 | brief.md#目标与成功标准 | Task-1 | plan.md#Task-1 + test-cases.md#tc-u1-001-探索任务验证 | 探索任务完成后可给出下一步实施依据 | 当前基线仍需由 fresh 命令补齐 | 不得跳过 QA 交接契约与真实验证 | 重复同一个 brief 目标，故意制造假覆盖 |
| 探索可行性验证 | prd.md#阶段目标 | Task-1 | plan.md#Task-1 + test-cases.md#tc-u1-001-探索任务验证 | 探索结论足够解锁下一批次 | 当前需先确认可行路径，无稳定执行基线 | 不得跳过真实验证命令与证据锚点 | 承接当前 phase 目标 |
EOF
)
      ;;
    invalid_execution_basis_anchor)
      goal_review_block=$(cat <<'EOF'
## 目标闭环与执行度量
| 目标 | goal_source_ref | 承接 Task | execution_basis_ref | 成功信号 | 基线 | 护栏 | 说明 |
|------|-----------------|----------|---------------------|---------|------|------|------|
| 登录旅程完成 | brief.md#目标与成功标准 | Task-1 | design.md#不存在的锚点 | 登录探索路径可被 fresh 验证并保留明确反馈 | 当前没有统一的 fresh 验证基线 | 不得放宽登录成功/失败反馈与真实依赖验证要求 | 故意制造无效锚点 |
| 探索可行性验证 | prd.md#阶段目标 | Task-1 | plan.md#Task-1 | 探索结论足够解锁下一批次 | 当前需先确认可行路径，无稳定执行基线 | 不得跳过真实验证命令与证据锚点 | 承接当前 phase 目标 |
EOF
)
      ;;
  esac

  cat > "$feature_dir/brief.md" <<'EOF'
# Brief

## 业务背景与根问题
- 现有登录旅程缺少可回溯验证，导致是否可以进入后续实施没有统一证据。

## 目标与成功标准
| 目标 | 成功标准 | 度量方式 |
|------|---------|---------|
| 登录旅程完成 | 用户可以完成登录并得到正确反馈 | QA_A 通过 + acceptance-summary 目标闭环收口 |

## 前置约束
- 无前置约束（经评估）
EOF

  if [ -n "$extra_brief_goal_row" ]; then
    brief_tmp="$feature_dir/brief.tmp"
    awk -v extra="$extra_brief_goal_row" '
      /^\| 登录旅程完成 / {
        print
        print extra
        next
      }
      { print }
    ' "$feature_dir/brief.md" > "$brief_tmp"
    mv "$brief_tmp" "$feature_dir/brief.md"
  fi

  cat > "$phase_dir/units/UNIT-1.md" <<'EOF'
# UNIT-1

## 功能闭环定义
- 输入/触发：用户提交登录请求
- 核心行为：系统校验凭证并返回登录结果
- 可观察结果：成功时进入已登录状态，失败时返回明确错误反馈

## 验收标准
- AC-U1-01: 输入有效账号密码 -> 登录成功并得到正确反馈
- AC-U1-02: 输入无效账号密码 -> 登录失败并得到明确错误提示
- AC-U1-03: 输入边界值/缺失字段 -> 系统拒绝并返回可观察错误

## 排除项
- EX-001: 本期不覆盖第三方登录
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

## AC 覆盖矩阵
| UNIT | AC | 描述 | 正例 | 反例 | 边界 | 排除 | 状态 |
|------|----|------|------|------|------|------|------|
| UNIT-1 | AC-U1-01 | 登录成功 | TC-U1-001 | TC-U1-002 | TC-U1-003 | EX-001 | COVERED |

### TC-U1-001: 探索任务验证

## QA 交接契约
| obligation_id | test_ref | qa_stage | execution_mode | evidence_expectation |
|---------------|----------|----------|----------------|----------------------|
| QA-A-U1-001 | TC-U1-001 | QA_A | cli | qa-report.md#qa_a-unit-1 |
EOF

  if [ "$include_future_task" = "yes" ]; then
    cat >> "$phase_dir/unit-1/test-cases.md" <<'EOF'

### TC-U1-002: 后续任务验证
EOF
  fi

  cat > "$phase_dir/design-review-1.md" <<'EOF'
# design-review

## 审查汇总
| 视角 | Verdict | Issue Count |
|------|---------|-------------|
| 架构 | PASS | 0 |
| 产品 | PASS | 0 |
| 测试 | PASS | 0 |

- REVIEW: DESIGN_OK
EOF

  cat > "$phase_dir/plan.md" <<EOF
# plan.md

## 输入分析
探索优先模式 gate 测试

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
| UNIT-1 | AC | AC-U1-01 | 探索实施边界 | SCOPE-P1U1-001 | MOD-001 | Task-1 | TC-U1-001 | 已分析 | $( [ "$matrix_variant" = "coverage_gap" ] && printf 'COVERED-NO-TEST' || printf 'COVERED' ) |
EOF

  if [ "$include_future_task" = "yes" ]; then
    cat >> "$phase_dir/plan.md" <<'EOF'
| UNIT-1 | AC | AC-U1-02 | 后续实施任务 | SCOPE-P1U1-002 | MOD-001 | Task-2 | TC-U1-002 | 已分析 | COVERED |
EOF
  fi

  cat >> "$phase_dir/plan.md" <<'EOF'

## Scope Freeze 与映射矩阵
| scope_item_id | 变更类型 | 风险等级 | 映射 Task | test_ref | rollback_ref | 状态 |
|---------------|----------|----------|-----------|----------|--------------|------|
| SCOPE-P1U1-001 | 探索验证 | P1 | Task-1 | TC-U1-001 | plan.md#回滚策略-1 | FROZEN |
EOF

  if [ "$include_future_task" = "yes" ]; then
    cat >> "$phase_dir/plan.md" <<'EOF'
| SCOPE-P1U1-002 | 后续实施 | P1 | Task-2 | TC-U1-002 | src/followup.ts | plan.md#回滚策略-2 | FROZEN |
EOF
  fi

  cat >> "$phase_dir/plan.md" <<EOF

$goal_review_block

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
- baseline_note: ${task_1_baseline_note}
- guardrail_note: ${task_1_guardrail_note}
- failure_signal: 方案验证失败且需要调整路径
- unlock_condition: 刷新 plan.md 后允许继续
- complexity: S
- AC:
  1. 输出明确验证结论
  2. 输出下一步执行条件
- depends_on: []
- shared_files: []
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
- baseline_note: 无
- guardrail_note: 无
- failure_signal: 无
- unlock_condition: 无
- complexity: S
- split_reason: 按实施边界拆分
- AC:
  1. 完成后续实施任务
- depends_on: [Task-1]
- shared_files: []
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

## 计划版本
- plan_version: v1
- 版本说明: 当前唯一有效的执行基线版本
- 引用锚点合同: 下游统一引用 plan.md#计划版本 和 plan.md#计划修订记录

## 计划修订记录
| plan_version | 触发原因 | 变更摘要 | 是否已重新确认 |
|--------------|----------|----------|----------------|
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
- REVIEW_C 仅作为可选增强审查，不进入 /delivery-owner 的强门禁判定

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
| R2 | PASS | 0 | 无 | CONFIRMATION | 确认轮复核通过，允许进入 delivery-owner |

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

create_product_goal_gate_fixture() {
  local root_dir="$1"
  local feature_name="$2"
  local goal_variant="${3:-missing_baseline}"
  local feature_dir="$root_dir/docs/$feature_name"
  local phase_dir="$feature_dir/phase-1"
  local goal_row='| 登录旅程完成 | 用户可以完成登录并得到正确反馈 | 机械型 | {待补 baseline} | 成功率提升 | 7 天 | 埋点看板 |'
  local observation_note=''
  local extra_goal_row=''

  mkdir -p "$phase_dir/units"

  case "$goal_variant" in
    missing_baseline)
      goal_row='| 登录旅程完成 | 用户可以完成登录并得到正确反馈 | 机械型 | {待补 baseline} | 成功率提升 | 7 天 | 埋点看板 |'
      ;;
    observation_without_note)
      goal_row='| 登录旅程完成 | 用户可以完成登录并得到正确反馈 | 观察型 | 当前客服投诉较多 | 投诉率下降 | 14 天 | 客服工单 |'
      ;;
    observation_partial_note)
      goal_row='| 登录旅程完成 | 用户可以完成登录并得到正确反馈 | 观察型 | 当前客服投诉较多 | 投诉率下降 | 14 天 | 客服工单 |'
      extra_goal_row='| 二次校验完成 | 用户可以在登录后完成二次校验 | 观察型 | 当前二次校验成功率波动较大 | 成功率稳定提升 | 14 天 | 行为埋点 |'
      observation_note='观察型说明：目标=登录旅程完成; 原因=当前只能从客服工单和用户反馈观察效果; 替代观测信号=客服投诉量下降'
      ;;
  esac

  if [ "$goal_variant" = "observation_without_note" ]; then
    observation_note=''
  fi

  cat > "$feature_dir/brief.md" <<EOF
# Brief

## 业务背景与根问题
- 登录链路缺少稳定成功信号，导致是否达成目标难以复盘。

## 目标与成功标准
| 目标 | 成功标准 | 度量类型 | 当前基线 | 目标值/方向 | 观测窗口 | 数据来源 |
|------|---------|---------|---------|------------|---------|---------|
$goal_row
$extra_goal_row
$observation_note

## 用户角色与核心场景
- 作为普通用户，我希望成功登录并收到明确反馈，这样我能继续使用系统。

## 业务术语
| 术语 | 定义 | 备注 |
|------|------|------|
| 登录成功 | 用户进入已登录状态 | 需要有可观察反馈 |

## 业务对象
| 对象 | 说明 | 关键状态/属性 |
|------|------|---------------|
| 登录请求 | 用户提交账号密码的动作 | success / failed |

## 当前业务流程
- 用户提交登录请求，结果反馈缺少统一追踪。

## 目标业务流程
- 用户提交登录请求后，系统返回明确结果并可被追踪。

## 范围 / 本期不交付
| 类型 | 内容 |
|------|------|
| 范围 | 登录结果反馈与追踪 |
| 本期不交付 | 第三方登录 |

## 业务规则
- 登录失败必须返回可观察错误提示。

## 影响范围
- 登录反馈文案与埋点统计会受影响。

## 非功能需求
| 编号 | 类别 | 验收标准（输入/操作 → 可观察结果） |
|------|------|-----------------------------------|
| GAC-001 | 可观测性 | 用户完成登录 -> 能在日志与埋点中看到结果 |

## 全局排除项
- 不扩展鉴权协议。

## 前置约束
- 无前置约束（经评估）

## 待设计决策
- DD-001: 登录失败提示文案是否统一复用现有组件

## 已排查并排除的潜在问题
- EP-001: 不是账号体系切换问题
- EP-002: 不是登录接口不可用问题

## 关键假设
| 假设 | 不成立时的后果 | 验证方式 |
|------|--------------|---------|
| 用户主要抱怨来自反馈不清晰 | 目标会偏离真正问题 | 对照客服工单与埋点数据 |

## 共创摘要
| 阶段 | 关键提问 | 用户回应 | 对文档的影响 |
|------|----------|----------|--------------|
| 根问题澄清 | 当前最痛的问题是什么 | 登录完成后没有统一成功信号 | 明确根问题 |
| 目标与成功标准对齐 | 什么叫成功 | 能看到稳定成功信号 | 收紧目标定义 |
| 语义/范围收口 | 本次只做什么 | 先收口登录反馈追踪 | 限定范围 |
| Phase 规划 | 先做哪一段 | 先覆盖登录主链路 | 固定 phase 范围 |
| PRD/UNIT 与 AC | 如何拆成闭环 | 先拆一个登录 UNIT | 产出 UNIT 索引 |
| 待设计决策/完整性 | 还缺什么决策 | 失败提示组件待设计收口 | 记录 DD |
| 交付确认 | 是否可以进入下游 | 可以 | 允许继续 |

## 交付确认
- 确认状态: 确认
- 确认时间: 2026-04-14 10:00

## 审查结论
### 审查汇总

| 视角 | Verdict | Issue Count |
|------|---------|-------------|
| 产品 | PASS | 0 |
| 架构 | PASS | 0 |
| 测试 | PASS | 0 |

### 审查问题台账

| Issue ID | 视角 | Severity | Status | Evidence Anchor | Handoff Target | Review Round | 处理摘要 |
|----------|------|----------|--------|-----------------|----------------|--------------|---------|
| HIS-001 | 历史说明 | P3 | RESOLVED | brief.md#目标与成功标准 | brief.md#目标与成功标准 | R1 | 无新增审查问题 |

### 收敛轮次摘要

| 轮次 | 结果 | FAIL数 | 未关闭 Issue IDs | 控制动作 | 说明 |
|------|------|-------|------------------|----------|------|
| R1 | PASS | 0 | 无 | CONTINUE | 首轮通过 |
| R2 | PASS | 0 | 无 | CONFIRMATION | 确认轮通过 |

### 用户裁决记录

| 触发轮次 | 控制动作 | 用户决定 | 关联 Issue IDs | 记录时间 | 说明 |
|----------|----------|----------|----------------|----------|------|

## 交接项
- 交给 design 补齐交互与埋点方案。
EOF

  cat > "$phase_dir/prd.md" <<'EOF'
# Phase 1

## 阶段目标
- 收口登录成功信号

## 入口与出口条件
- 入口条件: brief 通过
- 出口条件: UNIT-1 明确可验证

## 功能需求（UNIT 索引）
| UNIT | 标题 | 闭环目标 | 优先级 | 依赖 | 定义文件 |
|------|------|----------|--------|------|----------|
| UNIT-1 | 登录成功信号收口 | 用户完成登录后得到明确反馈 | MVP | - | units/UNIT-1.md |
EOF

  cat > "$phase_dir/units/UNIT-1.md" <<'EOF'
# UNIT-1

## 功能闭环定义
- 输入/触发：用户提交登录请求
- 核心行为：系统返回成功或失败反馈
- 可观察结果：用户可以感知结果且日志可记录

### 正常场景
- 输入有效账号密码 -> 登录成功并得到明确反馈

### 异常场景
- 输入无效账号密码 -> 登录失败并得到明确错误提示

### 边界条件
- 输入缺失字段 -> 系统拒绝并返回可观察错误

## 排除项
- 不覆盖第三方登录
EOF
}

create_project_manager_fixture() {
  local root_dir="$1"
  local feature_name="$2"
  local plan_evidence_variant="${3:-valid}"
  local report_evidence_variant="${4:-valid}"
  local fresh_output_variant="${5:-valid}"
  local readiness_variant="${6:-valid}"
  local goal_variant="${7:-valid}"
  local developer_ref_variant="${8:-valid}"
  local summary_variant="${9:-n_a}"
  local freshness_variant="${10:-valid}"

  create_tech_lead_fixture "$root_dir" "$feature_name" "已收口" "no" "complete" "valid" "valid" "$plan_evidence_variant" "valid"

  local feature_dir="$root_dir/docs/$feature_name"
  local phase_dir="$feature_dir/phase-1"
  local report_proving_command="bash tests/run-all.sh"
  local report_real_dependency_note="依赖真实测试环境与完整测试套件，最终验收不得只看 Mock"
  local report_evidence_target="dev-report.md#task-1 + qa-report.md#qa_a-unit-1 + acceptance-summary.md#质量门禁"
  local report_mock_boundary_note="Mock 仅用于分层隔离测试，最终验收必须走真实依赖与完整输出"
  local developer_report_ref="developer-report-Task-1.md#reviewable-anchor"
  local fresh_proving_output=$'bash tests/run-all.sh\n1 passing'
  local kickoff_status="READY"
  local preflight_evidence_ref="preflight-evidence.md#preflight-con-001"
  local environment_ready="yes"
  local dependency_ready="yes"
  local risk_owner_ready="yes"
  local qa_handoff_ready="yes"
  local readiness_waiver="无"
  local status_summary_state="N/A"
  local evidence_summary_state="N/A"
  local create_status_summary="no"
  local create_evidence_summary="no"
  local summary_parallel_trigger="no"
  local task_1_commit_status="DONE"
  local status_summary_task_state="DONE"
  local goal_closure_block='## 目标闭环
| 目标 | goal_source_ref | execution_basis_ref | evidence_ref | result | remaining_gap |
|------|-----------------|---------------------|--------------|--------|---------------|
| 登录旅程完成 | brief.md#目标与成功标准 | plan.md#计划版本 | dev-report.md#task-1 + qa-report.md#qa_a-unit-1 | 已达成 | 无 |
| 探索可行性验证 | prd.md#阶段目标 | unit-1/test-cases.md#QA-交接契约 | qa-report.md#qa_a-unit-1 + dev-report.md#task-1 | 已达成 | 无 |'
  local fresh_proving_executed_at="2026-04-11T09:30:00+08:00"
  local fresh_proving_exit_code="0"
  local full_test_executed_at="2026-04-11T09:40:00+08:00"
  local full_test_exit_code="0"
  local extra_brief_goal_row=""
  local signoff_time="2026-04-11T10:00:00+08:00"
  local dev_last_observed_at="2026-04-11T09:45:00+08:00"
  local dev_runtime_snapshot="Task-1 已完成开发验证，等待 Review/QA 汇总"
  local dev_active_blocker="无"
  local dev_blocker_owner="无"
  local dev_takeover_note="无（主 Agent 持续跟进）"
  local dev_decision_basis="plan.md#计划版本 + dev-report.md#task-1 + qa-report.md#qa_a-unit-1"
  local dev_dispatch_mode="SERIAL"
  local dev_current_batch="SERIAL"
  local dev_batch_unlock_condition="无（串行执行，按 Task 编号逐个推进）"
  local dev_merge_readiness="READY"
  local dev_next_action="REQUEST_REVIEW"
  local dev_plan_version_ref="plan.md#计划版本"
  local dev_plan_version_value="v1"
  local dev_replan_request="无"
  local dev_batch_freeze_reason="无"
  local dev_unlock_resolution="无"
  local accept_last_observed_at="2026-04-11T09:50:00+08:00"
  local accept_runtime_snapshot="所有强门禁已完成，等待用户签收"
  local accept_active_blocker="无"
  local accept_blocker_owner="无"
  local accept_takeover_note="无（主 Agent 持续跟进）"
  local accept_decision_basis="dev-report.md#执行编排状态 + qa-report.md#qa_a-unit-1 + plan.md#计划版本"
  local accept_current_plan_version_ref="plan.md#计划版本"
  local accept_current_plan_version_value="v1"

  cat > "$feature_dir/brief.md" <<EOF
# Brief

## 业务背景与根问题
- 登录主链路需要一套从 plan 到 acceptance 的统一证据闭环。

## 目标与成功标准
| 目标 | 成功标准 | 度量方式 |
|------|---------|---------|
| 登录旅程完成 | 用户可以完成登录并得到正确反馈 | QA_A 通过 + acceptance-summary 目标闭环收口 |
$extra_brief_goal_row

## 前置约束
| Constraint ID | 类型 | 约束内容 | Owner | 影响 UNIT | scope_item_id | preflight_ref | test_ref | 状态 |
|---------------|------|----------|-------|-----------|---------------|---------------|----------|------|
| CON-001 | env | 登录环境必须 ready | delivery-owner | UNIT-1 | SCOPE-P1U1-001 | preflight-evidence.md#preflight-con-001 | TC-U1-001 | ACTIVE |
EOF

  perl -0pi -e 's/(\|---------------\|------\|----------\|-------\|-----------\|---------------\|---------------\|----------\|-----------\|----------\|------\|\n)/${1}| CON-001 | env | 登录环境必须 ready | delivery-owner | UNIT-1 | SCOPE-P1U1-001 | preflight-evidence.md#preflight-con-001 | TC-U1-001 | Task-1 | acceptance-summary.md#constraint-CON-001 | MAPPED |\n/' "$phase_dir/plan.md"

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

  case "$developer_ref_variant" in
    missing_developer_report_ref)
      developer_report_ref="{待补 developer report ref}"
      ;;
    unanchored_developer_report_ref)
      developer_report_ref="developer-report-Task-1.md"
      ;;
  esac

  case "$readiness_variant" in
    kickoff_missing_risk_owner)
      risk_owner_ready="no"
      ;;
    kickoff_waived)
      kickoff_status="WAIVED"
      risk_owner_ready="no"
      readiness_waiver="PMW-001 + 环境临时豁免"
      ;;
  esac

  case "$goal_variant" in
    missing_goal_closure)
      goal_closure_block=""
      ;;
    goal_missing_second)
      extra_brief_goal_row='| 二次校验完成 | 用户可以在登录后完成二次校验 | QA_A 通过 + acceptance-summary 目标闭环收口 |'
      ;;
    goal_duplicate_brief_rows)
      goal_closure_block='## 目标闭环
| 目标 | goal_source_ref | execution_basis_ref | evidence_ref | result | remaining_gap |
|------|-----------------|---------------------|--------------|--------|---------------|
| 登录旅程完成 | brief.md#目标与成功标准 | plan.md#计划版本 | dev-report.md#task-1 + qa-report.md#qa_a-unit-1 | 已达成 | 无 |
| 登录旅程完成 | brief.md#目标与成功标准 | unit-1/test-cases.md#QA-交接契约 | qa-report.md#qa_a-unit-1 + dev-report.md#task-1 | 已达成 | 无 |
| 探索可行性验证 | prd.md#阶段目标 | unit-1/test-cases.md#QA-交接契约 | qa-report.md#qa_a-unit-1 + dev-report.md#task-1 | 已达成 | 无 |'
      ;;
    goal_missing_second_same_count)
      extra_brief_goal_row='| 二次校验完成 | 用户可以在登录后完成二次校验 | QA_A 通过 + acceptance-summary 目标闭环收口 |'
      goal_closure_block='## 目标闭环
| 目标 | goal_source_ref | execution_basis_ref | evidence_ref | result | remaining_gap |
|------|-----------------|---------------------|--------------|--------|---------------|
| 登录旅程完成 | brief.md#目标与成功标准 | plan.md#计划版本 | dev-report.md#task-1 + qa-report.md#qa_a-unit-1 | 已达成 | 无 |
| 登录旅程完成 | brief.md#目标与成功标准 | unit-1/test-cases.md#QA-交接契约 | qa-report.md#qa_a-unit-1 + dev-report.md#task-1 | 已达成 | 无 |
| 探索可行性验证 | prd.md#阶段目标 | unit-1/test-cases.md#QA-交接契约 | qa-report.md#qa_a-unit-1 + dev-report.md#task-1 | 已达成 | 无 |'
      ;;
    goal_unmapped)
      goal_closure_block='## 目标闭环
| 目标 | goal_source_ref | execution_basis_ref | evidence_ref | result | remaining_gap |
|------|-----------------|---------------------|--------------|--------|---------------|
| 未映射目标 | brief.md#不存在的锚点 | plan.md#计划版本 | dev-report.md#task-1 + qa-report.md#qa_a-unit-1 | 已达成 | 无 |'
      ;;
    goal_missing_source_ref)
      goal_closure_block='## 目标闭环
| 目标 | goal_source_ref | execution_basis_ref | evidence_ref | result | remaining_gap |
|------|-----------------|---------------------|--------------|--------|---------------|
| 登录旅程完成 | {待补 goal source} | plan.md#计划版本 | dev-report.md#task-1 + qa-report.md#qa_a-unit-1 | 已达成 | 无 |'
      ;;
    goal_invalid_source_ref)
      goal_closure_block='## 目标闭环
| 目标 | goal_source_ref | execution_basis_ref | evidence_ref | result | remaining_gap |
|------|-----------------|---------------------|--------------|--------|---------------|
| 登录旅程完成 | design.md#设计概览 | plan.md#计划版本 | dev-report.md#task-1 + qa-report.md#qa_a-unit-1 | 已达成 | 无 |'
      ;;
    goal_missing_execution_basis_ref)
      goal_closure_block='## 目标闭环
| 目标 | goal_source_ref | execution_basis_ref | evidence_ref | result | remaining_gap |
|------|-----------------|---------------------|--------------|--------|---------------|
| 登录旅程完成 | brief.md#目标与成功标准 | {待补 execution basis} | dev-report.md#task-1 + qa-report.md#qa_a-unit-1 | 已达成 | 无 |'
      ;;
    goal_invalid_execution_basis_ref)
      goal_closure_block='## 目标闭环
| 目标 | goal_source_ref | execution_basis_ref | evidence_ref | result | remaining_gap |
|------|-----------------|---------------------|--------------|--------|---------------|
| 登录旅程完成 | brief.md#目标与成功标准 | brief.md#目标与成功标准 | dev-report.md#task-1 + qa-report.md#qa_a-unit-1 | 已达成 | 无 |'
      ;;
    goal_partial)
      goal_closure_block='## 目标闭环
| 目标 | goal_source_ref | execution_basis_ref | evidence_ref | result | remaining_gap |
|------|-----------------|---------------------|--------------|--------|---------------|
| 登录旅程完成 | brief.md#目标与成功标准 | plan.md#计划版本 | dev-report.md#task-1 + qa-report.md#qa_a-unit-1 | 部分达成 | 仍需补浏览器旅程 |'
      ;;
    goal_unmet)
      goal_closure_block='## 目标闭环
| 目标 | goal_source_ref | execution_basis_ref | evidence_ref | result | remaining_gap |
|------|-----------------|---------------------|--------------|--------|---------------|
| 登录旅程完成 | brief.md#目标与成功标准 | plan.md#计划版本 | dev-report.md#task-1 + qa-report.md#qa_a-unit-1 | 未达成 | 关键登录反馈仍未闭环 |'
      ;;
  esac

  case "$freshness_variant" in
    stale_after_fix)
      signoff_time="2026-04-11T12:00:00+08:00"
      ;;
  esac

  if [ -n "$extra_brief_goal_row" ]; then
    brief_tmp="$feature_dir/brief.tmp"
    awk -v extra="$extra_brief_goal_row" '
      /^\| 登录旅程完成 / {
        print
        print extra
        next
      }
      { print }
    ' "$feature_dir/brief.md" > "$brief_tmp"
    mv "$brief_tmp" "$feature_dir/brief.md"
  fi

  case "$summary_variant" in
    n_a)
      ;;
    triggered_without_parallel_batch)
      status_summary_state="TRIGGERED"
      evidence_summary_state="TRIGGERED"
      create_status_summary="yes"
      create_evidence_summary="yes"
      ;;
    status_triggered_missing_file)
      summary_parallel_trigger="yes"
      task_1_commit_status="IN_PROGRESS"
      status_summary_task_state="IN_PROGRESS"
      status_summary_state="TRIGGERED"
      evidence_summary_state="TRIGGERED"
      create_evidence_summary="yes"
      dev_dispatch_mode="PARALLEL"
      dev_current_batch="Batch-1"
      dev_batch_unlock_condition="Batch-1 全部 VERIFIED 且 merge_readiness=READY 后解锁下一批"
      dev_merge_readiness="PENDING"
      dev_next_action="WAIT_BATCH"
      dev_runtime_snapshot="Batch-1 并行执行中，等待剩余 Task 完成"
      ;;
    evidence_triggered_missing_file)
      summary_parallel_trigger="yes"
      task_1_commit_status="IN_PROGRESS"
      status_summary_task_state="IN_PROGRESS"
      status_summary_state="TRIGGERED"
      evidence_summary_state="TRIGGERED"
      create_status_summary="yes"
      dev_dispatch_mode="PARALLEL"
      dev_current_batch="Batch-1"
      dev_batch_unlock_condition="Batch-1 全部 VERIFIED 且 merge_readiness=READY 后解锁下一批"
      dev_merge_readiness="PENDING"
      dev_next_action="WAIT_BATCH"
      dev_runtime_snapshot="Batch-1 并行执行中，等待剩余 Task 完成"
      ;;
    status_triggered_with_file)
      summary_parallel_trigger="yes"
      task_1_commit_status="IN_PROGRESS"
      status_summary_task_state="IN_PROGRESS"
      status_summary_state="TRIGGERED"
      evidence_summary_state="TRIGGERED"
      create_status_summary="yes"
      create_evidence_summary="yes"
      dev_dispatch_mode="PARALLEL"
      dev_current_batch="Batch-1"
      dev_batch_unlock_condition="Batch-1 全部 VERIFIED 且 merge_readiness=READY 后解锁下一批"
      dev_merge_readiness="PENDING"
      dev_next_action="WAIT_BATCH"
      dev_runtime_snapshot="Batch-1 并行执行中，等待剩余 Task 完成"
      ;;
    evidence_triggered_with_file)
      summary_parallel_trigger="yes"
      task_1_commit_status="IN_PROGRESS"
      status_summary_task_state="IN_PROGRESS"
      status_summary_state="TRIGGERED"
      evidence_summary_state="TRIGGERED"
      create_status_summary="yes"
      create_evidence_summary="yes"
      dev_dispatch_mode="PARALLEL"
      dev_current_batch="Batch-1"
      dev_batch_unlock_condition="Batch-1 全部 VERIFIED 且 merge_readiness=READY 后解锁下一批"
      dev_merge_readiness="PENDING"
      dev_next_action="WAIT_BATCH"
      dev_runtime_snapshot="Batch-1 并行执行中，等待剩余 Task 完成"
      ;;
    status_stale_with_file)
      summary_parallel_trigger="yes"
      task_1_commit_status="IN_PROGRESS"
      status_summary_task_state="IN_PROGRESS"
      status_summary_state="STALE"
      evidence_summary_state="TRIGGERED"
      create_status_summary="yes"
      create_evidence_summary="yes"
      dev_dispatch_mode="PARALLEL"
      dev_current_batch="Batch-1"
      dev_batch_unlock_condition="Batch-1 全部 VERIFIED 且 merge_readiness=READY 后解锁下一批"
      dev_merge_readiness="PENDING"
      dev_next_action="WAIT_BATCH"
      dev_runtime_snapshot="Batch-1 并行执行中，等待剩余 Task 完成"
      ;;
    evidence_without_status)
      summary_parallel_trigger="yes"
      task_1_commit_status="IN_PROGRESS"
      evidence_summary_state="TRIGGERED"
      create_evidence_summary="yes"
      dev_dispatch_mode="PARALLEL"
      dev_current_batch="Batch-1"
      dev_batch_unlock_condition="Batch-1 全部 VERIFIED 且 merge_readiness=READY 后解锁下一批"
      dev_merge_readiness="PENDING"
      dev_next_action="WAIT_BATCH"
      dev_runtime_snapshot="Batch-1 并行执行中，等待剩余 Task 完成"
      ;;
  esac

  if [ "$summary_parallel_trigger" = "yes" ]; then
    tmp_plan_file="$phase_dir/plan.parallel.tmp"
    awk '
      BEGIN {
        replacement = "## 并行策略\n\n团队规模：4 名开发者\n\n#### Batch 1（可并行）\n| 开发者 | Task | 文件范围 | worktree 隔离 | 说明 |\n|--------|------|---------|--------------|------|\n| dev-1 | Task-1 | src/explore.ts | yes | 当前活跃任务 |\n| dev-2 | Task-2 | src/followup-a.ts | yes | 并行子任务 |\n| dev-3 | Task-3 | src/followup-b.ts | yes | 并行子任务 |\n| dev-4 | Task-4 | src/followup-c.ts | yes | 并行子任务 |"
      }
      /^## 并行策略$/ { print replacement; skip = 1; next }
      skip && /^## 再计划与解锁规则$/ { skip = 0; print; next }
      !skip { print }
    ' "$phase_dir/plan.md" > "$tmp_plan_file"
    mv "$tmp_plan_file" "$phase_dir/plan.md"
    perl -0pi -e 's/- 当前已解锁批次: Task-1/- 当前已解锁批次: Task-1, Task-2, Task-3, Task-4/' "$phase_dir/plan.md"
  fi

  if [ "$fresh_output_variant" = "summary_only" ]; then
    fresh_proving_output="PASS"
  fi

  cat > "$phase_dir/unit-1/test-cases.md" <<'EOF'
# test-cases

### TC-U1-001: 探索任务验证

## QA 交接契约
| test_obligation | trigger_source | qa_stage | requiredness | execution_mode | skip_rule | evidence_expectation |
|-----------------|----------------|----------|--------------|----------------|-----------|----------------------|
| AC/功能 | AC 覆盖矩阵 | QA_A | REQUIRED | non_browser_ok | 不可跳过 | AC 追踪表 + 规则级证据 |

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

### 运行态状态感知
- last_observed_at: $dev_last_observed_at
- runtime_snapshot: $dev_runtime_snapshot
- active_blocker: $dev_active_blocker
- blocker_owner: $dev_blocker_owner
- takeover_note: $dev_takeover_note
- decision_basis: $dev_decision_basis

### 执行编排状态
- dispatch_mode: $dev_dispatch_mode
- current_batch: $dev_current_batch
- batch_unlock_condition: $dev_batch_unlock_condition
- merge_readiness: $dev_merge_readiness
- next_action: $dev_next_action
- plan_version_ref: $dev_plan_version_ref
- plan_version_value: $dev_plan_version_value
- replan_request: $dev_replan_request
- batch_freeze_reason: $dev_batch_freeze_reason
- unlock_resolution: $dev_unlock_resolution

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
- developer_report_ref: $developer_report_ref
- deviation_trigger: NONE
- control_action: CONTINUE

#### 一手证据引用
- developer_report_ref 指向唯一权威 TDD 证据

- proving_command_executed_at: $fresh_proving_executed_at
- proving_command_exit_code: $fresh_proving_exit_code
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
| Task-1 | abc1234 | yes | SPEC_OK | 2A_OK | 2B_OK | 2C_OK | $task_1_commit_status |

### Task-scope 对照表
| Task | scope_item_ref | impact_files | rollback_ref | 边界校验 |
|------|----------------|--------------|--------------|----------|
| Task-1 | SCOPE-P1U1-001 | src/explore.ts, tests/explore.test.ts | plan.md#回滚策略-1 | OK |

### 全量测试结果
TEST_CMD: bash tests/run-all.sh
- TEST_EXECUTED_AT: $full_test_executed_at
- TEST_EXIT_CODE: $full_test_exit_code
1 passed

### 交接项
- Task-1 已交接

## 汇总代理引用
| Agent | 触发条件 | 汇总文件 | 字段引用位 | 证据锚点引用位 | 重入规则 | 汇总状态 |
|------|----------|----------|-----------|----------------|----------|----------|
| Status Synthesis Agent | plan.md 当前批次并行 Task 数 >= 4，且 qa-report.md 尚未完成 | delivery-status-summary.md | 输入边界 / 当前判断 / 未决项 / 禁止越权项 | dev-report.md#task-1 / qa-report.md#qa_a-unit-1 | BLOCKED 计入并行数；重试不重复计数；replan 跨批次重新计数 | $status_summary_state |
| Evidence Synthesis Agent | plan.md 当前批次并行 Task 数 >= 4，且 dev-report.md、code-review-report.md、qa-report.md 已产出、acceptance-summary.md 尚未完成 | evidence-summary.md | 输入边界 / 当前判断 / 证据锚点 / 未决项 / 禁止越权项 | dev-report.md#task-1 / code-review-report.md#summary / qa-report.md#qa_a-unit-1 / acceptance-summary.md#质量门禁 | 仅允许在 Status Synthesis Agent 结束或停止后进入；旧 summary 可标记 STALE，且仅允许重跑 1 次 | $evidence_summary_state |
EOF

  cat > "$phase_dir/unit-1/developer-report-Task-1.md" <<'EOF'
# developer-report-Task-1.md

### 权威证据工件
- authoritative_evidence_artifact: `developer-report-Task-1.md`
- evidence_bundle_ref: `developer-report-Task-1.md#tdd-evidence-index`
- reviewable_anchor: `developer-report-Task-1.md#reviewable-anchor`

### TDD 记录
| AC | 测试描述 | RED 证据 | GREEN 证据 |
|----|---------|---------|-----------|
| AC-U1-01 | 登录完成 | red | green |

### TDD 证据索引
<a id="tdd-evidence-index"></a>
| 阶段 | Commit SHA | 测试文件 | 结果 |
|------|-----------|---------|------|
| RED | abc1111 | tests/explore.test.ts | FAIL (expected) |
| GREEN | abc2222 | tests/explore.test.ts | PASS |

<a id="reviewable-anchor"></a>
### 自测结果
- 通过
EOF

  cat > "$phase_dir/code-review-report.md" <<'EOF'
审查分级: 标准

## 审查汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| REVIEW_A | OK | 0 | ok |
| REVIEW_B | OK | 0 | ok |
EOF

  cat >> "$phase_dir/code-review-report.md" <<EOF

## 汇总代理引用
| Agent | 汇总文件 | 字段引用位 | 证据锚点引用位 | 重入规则 | 汇总状态 |
|------|----------|-----------|----------------|----------|----------|
| Status Synthesis Agent | delivery-status-summary.md | 输入边界 / 当前判断 / 未决项 / 禁止越权项 | code-review-report.md#summary / qa-report.md#qa_a-unit-1 | BLOCKED 计入并行数；重试不重复计数；replan 跨批次重新计数 | $status_summary_state |
| Evidence Synthesis Agent | evidence-summary.md | 输入边界 / 当前判断 / 证据锚点 / 未决项 / 禁止越权项 | code-review-report.md#summary / qa-report.md#qa_a-unit-1 / acceptance-summary.md#质量门禁 | 仅允许在 Status Synthesis Agent 结束或停止后进入；旧 summary 可标记 STALE，且仅允许重跑 1 次 | $evidence_summary_state |
EOF

cat > "$phase_dir/qa-report.md" <<'EOF'
审查分级: 标准
执行范围: full
plan_version_ref: plan.md#计划版本
plan_version_value: v1
release_recommendation: 放行
residual_risk: 低，残余风险可接受
uncovered_boundary: 无
conditional_release_basis: 无
issue_ledger_anchor: qa-report.md#fail-details

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

## FAIL 详情
| Issue ID | 阶段 | severity | priority | impact_scope | user_impact | environment_or_build | regression_flag | temporary_workaround | owner_hint | 期望行为 | 实际行为 | 复现命令 |
|----------|------|----------|----------|--------------|-------------|----------------------|-----------------|----------------------|------------|---------|---------|---------|
EOF

  if [ "$readiness_variant" != "preflight_missing" ]; then
    if [ "$readiness_variant" = "preflight_empty" ]; then
      : > "$phase_dir/preflight-evidence.md"
    else
      cat > "$phase_dir/preflight-evidence.md" <<'EOF'
# preflight-evidence.md

## preflight-con-001
| Constraint ID | 结果 | 证据 | 备注 |
|---------------|------|------|------|
| CON-001 | OK | smoke-check | 环境已准备好 |
EOF
    fi
  fi

  cat > "$phase_dir/acceptance-summary.md" <<EOF
## 交付范围
- Feature: pm evidence
- PRD: docs/feature/brief.md
- Plan: docs/feature/phase-1/plan.md
- Task 数: 1（完成: 1，BLOCKED: 0）

## Kickoff 状态
- kickoff_status: $kickoff_status
- plan_version_ref: plan.md#计划版本
- preflight_evidence_ref: $preflight_evidence_ref
- environment_ready: $environment_ready
- dependency_ready: $dependency_ready
- risk_owner_ready: $risk_owner_ready
- qa_handoff_ready: $qa_handoff_ready
- readiness_waiver: $readiness_waiver

## 最新状态摘要
- last_observed_at: $accept_last_observed_at
- runtime_snapshot: $accept_runtime_snapshot
- active_blocker: $accept_active_blocker
- blocker_owner: $accept_blocker_owner
- takeover_note: $accept_takeover_note
- decision_basis: $accept_decision_basis
- current_plan_version_ref: $accept_current_plan_version_ref
- current_plan_version_value: $accept_current_plan_version_value

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

## 前置约束验收状态
| Constraint ID | 类型 | Plan 状态 | preflight_ref | test_ref | 验收结果 | 证据 | 备注 |
|---------------|------|-----------|---------------|----------|----------|------|------|
| CON-001 | env | MAPPED | preflight-evidence.md#preflight-con-001 | TC-U1-001 | OK | qa-report.md#qa_a-unit-1 | 已验证 |

## 发布建议对齐
- qa_report_release_recommendation: 放行
- acceptance_release_recommendation: 放行
- residual_risk: 低，残余风险可接受
- uncovered_boundary: 无
- conditional_release_basis: 无
- not_executed_reason: QA_B/QA_D 未触发，见 qa-report.md#验收汇总
- risk_acceptance_basis: 无

## 汇总代理引用
| Agent | 汇总文件 | 字段引用位 | 证据锚点引用位 | 重入规则 | 汇总状态 |
|------|----------|-----------|----------------|----------|----------|
| Status Synthesis Agent | delivery-status-summary.md | 输入边界 / 当前判断 / 未决项 / 禁止越权项 | dev-report.md#task-1 / qa-report.md#qa_a-unit-1 | BLOCKED 计入并行数；重试不重复计数；replan 跨批次重新计数 | $status_summary_state |
| Evidence Synthesis Agent | evidence-summary.md | 输入边界 / 当前判断 / 证据锚点 / 未决项 / 禁止越权项 | dev-report.md#task-1 / code-review-report.md#summary / qa-report.md#qa_a-unit-1 / acceptance-summary.md#质量门禁 | 仅允许在 Status Synthesis Agent 结束或停止后进入；旧 summary 可标记 STALE，且仅允许重跑 1 次 | $evidence_summary_state |

$goal_closure_block


## 已知问题
| Issue ID | 来源 | 描述 | 严重度 | 处置 |
|----------|------|------|--------|------|

## 签收记录
- sign_off_status: 确认
- sign_off_by: user
- sign_off_at: $signoff_time
- business_risk_acceptance_status: 不适用
- business_risk_acceptance_by: 无
- business_risk_acceptance_at: 无
- 备注: ok
EOF

  if [ "$create_status_summary" = "yes" ]; then
    cat > "$phase_dir/delivery-status-summary.md" <<EOF
# delivery-status-summary.md

Status Synthesis Agent
- agent_kind: synthesis
- current_judgment_type: summary
- decision_state: 待裁决
- input_boundary: plan.md#Task-清单 + dev-report.md#task-1 + qa-report.md#qa_a-unit-1
- evidence_anchor: dev-report.md#task-1 + qa-report.md#qa_a-unit-1 + plan.md#并行策略
- forbidden_action: 不得新增风险接受；不得新增放行或 Gate 结论；不得替主 Agent 做 sign-off

## 汇总结果
- Task 状态: $status_summary_task_state
- BLOCKED: 无
- 批次顺序: Batch-1
EOF
  fi

  if [ "$create_evidence_summary" = "yes" ]; then
    cat > "$phase_dir/evidence-summary.md" <<'EOF'
# evidence-summary.md

Evidence Synthesis Agent
- agent_kind: synthesis
- current_judgment_type: summary
- decision_state: 待裁决
- input_boundary: plan.md#Task-清单 + dev-report.md#task-1 + code-review-report.md#summary + qa-report.md#qa_a-unit-1
- evidence_anchor: dev-report.md#task-1 + code-review-report.md#summary + qa-report.md#qa_a-unit-1 + acceptance-summary.md#质量门禁
- forbidden_action: 不得新增风险接受；不得新增放行或 Gate 结论；不得替主 Agent 做 sign-off

## 汇总结果
- 证据锚点: 已汇总到 delivery-owner summary
- 风险承接: 低，残余风险可接受
- 签收前缺口: 无
EOF
  fi
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
PM_SKILL="$ROOT/shared/skills/delivery-owner/SKILL.md"
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
PM_PHASE3_DOC="$ROOT/shared/skills/delivery-owner/references/phase3-dispatch.md"
PHASE_SELECTION_PROTOCOL="$ROOT/shared/protocols/phase-selection-protocol.md"
PRODUCT_CHECK="$ROOT/shared/skills/product/scripts/completion_check.sh"
HOOK_REGISTRY="$ROOT/shared/hooks/registry.json"
CHAIN_CONTRACT="$ROOT/contracts/skill-chain.yaml"
DESIGNER_AGENT="$ROOT/shared/agents/designer.md"
TEST_DESIGNER_AGENT="$ROOT/shared/agents/test-designer.md"
TECH_LEAD_AGENT="$ROOT/shared/agents/tech-lead.md"
QA_AGENT="$ROOT/shared/agents/qa.md"
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
assert_present '"skill"[[:space:]]*:[[:space:]]*"delivery-owner"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"qa"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"review"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"developer"' "$HOOK_REGISTRY"
assert_present '"skill"[[:space:]]*:[[:space:]]*"verify"' "$HOOK_REGISTRY"
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
  assert_absent '首轮请独立完成审查并输出结论' "$prompt"
  assert_absent '如主 agent 为解决冲突、补盲或核对相互矛盾的证据而发起澄清' "$prompt"
  assert_absent '最终 verdict 仍按各视角独立负责' "$prompt"
  assert_absent '首轮 reviewer 之间不得交换结论' "$prompt"
  assert_absent '不与其他 reviewer 协调结论' "$prompt"
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
assert_present '^## 对话节奏$' "$PRODUCT_CONVERSATION_GUIDE"
assert_present '每条消息只问一个问题，先复述理解再追问' "$PRODUCT_CONVERSATION_GUIDE"
assert_present '^## 共创对话原则$' "$DESIGN_DECISION_TEMPLATES"
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
assert_present '不负责 execution kickoff、执行期 gate 升档、最终 sign-off 和业务风险接受' "$TECH_LEAD_SKILL"
assert_present '多 Task、跨批次、探索任务、或需要统一冻结' "$TECH_LEAD_SKILL"
assert_present '设计决策不确定.*回退.*/design' "$TECH_LEAD_SKILL"
assert_present '实施可行性不确定.*探索任务' "$TECH_LEAD_SKILL"
assert_present '8\. 跨职能评审' "$TECH_LEAD_SKILL"
assert_absent 'Agent Team 独立评审' "$TECH_LEAD_SKILL"
assert_present '跨职能评审收敛后' "$TECH_LEAD_SKILL"
assert_present '已通过 TeamCreate 完成跨职能评审' "$TECH_LEAD_SKILL"
assert_absent '已通过 TeamCreate 完成独立审查' "$TECH_LEAD_SKILL"
assert_present '产品审查 prompt' "$TECH_LEAD_SKILL"
assert_present '测试验收审查 prompt' "$TECH_LEAD_SKILL"
assert_present '3 个 reviewer' "$TECH_LEAD_SKILL"
assert_present '不能替代 readiness、门禁裁决或用户签收推进' "$PM_SKILL"
for skill in "$PRODUCT_SKILL" "$DESIGN_SKILL" "$TEST_DESIGN_SKILL" "$TECH_LEAD_SKILL" "$PM_SKILL"; do
  assert_no_subagent_chapter "$skill"
done
assert_present '用于确认 PRD 是否完整回答用户问题' "$PRODUCT_SKILL"
assert_present '用于确认需求在当前技术上下文中可落地' "$PRODUCT_SKILL"
assert_present '用于确认 AC 能被真实验证' "$PRODUCT_SKILL"
assert_present '用于确认设计方案能承接需求' "$DESIGN_SKILL"
assert_present '用于确认设计没有偏离用户意图' "$DESIGN_SKILL"
assert_present '用于确认设计具备可测试性' "$DESIGN_SKILL"
assert_present '用于确认测试用例本身完整、可执行' "$TEST_DESIGN_SKILL"
assert_present '用于确认测试设计仍忠实覆盖业务意图' "$TEST_DESIGN_SKILL"
assert_present '用于确认测试设计覆盖接口契约、技术约束与专项测试触发' "$TEST_DESIGN_SKILL"
assert_present '用于确认计划没有改写本 Phase 目标' "$TECH_LEAD_SKILL"
assert_present '用于确认 plan task 拆分、依赖关系与 design 映射可直接执行' "$TECH_LEAD_SKILL"
assert_present '用于确认 AC / test_ref / 真实证据链闭环' "$TECH_LEAD_SKILL"
assert_absent '不做二次分级、不按条件触发' "$TECH_LEAD_SKILL"
assert_absent '3 个 reviewer 只审计划阶段特有风险' "$TECH_LEAD_SKILL"
assert_present '复核问题证据、影响范围与承接位置' "$PRODUCT_SKILL"
assert_present "系统性修复 \`brief\.json / phase-\{N\}/phase-prd\.json / phase-\{N\}/units/\`" "$PRODUCT_SKILL"
assert_present '仅对 FAIL 视角重新提交评审' "$PRODUCT_SKILL"
assert_present '复核问题证据、影响范围与承接位置' "$DESIGN_SKILL"
assert_present "系统性修复 \`design\.json\`" "$DESIGN_SKILL"
assert_present '仅对 FAIL 视角重新提交评审' "$DESIGN_SKILL"
assert_present '复核问题证据、影响范围与承接位置' "$TEST_DESIGN_SKILL"
assert_present "系统性修复 \`test-cases\.json\`" "$TEST_DESIGN_SKILL"
assert_present '仅对 FAIL 视角重新提交评审' "$TEST_DESIGN_SKILL"
assert_present '复核问题证据、影响范围与承接位置' "$TECH_LEAD_SKILL"
assert_present '修正计划' "$TECH_LEAD_SKILL"
assert_present '仅重跑失败视角' "$TECH_LEAD_SKILL"
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
assert_present '^## QA 交接契约$' "$TEST_CASES_TEMPLATE"
assert_present '^\| test_obligation \| trigger_source \| qa_stage \| requiredness \| execution_mode \| skip_rule \| evidence_expectation \|$' "$TEST_CASES_TEMPLATE"
assert_present 'browser_required, non_browser_ok' "$TEST_CASES_TEMPLATE"
assert_present '\| 冒烟 \|' "$TEST_CASES_TEMPLATE"
assert_present '\| API/接口 \|' "$TEST_CASES_TEMPLATE"
assert_present '\| UX \|' "$TEST_CASES_TEMPLATE"
assert_present '\| 异常恢复 \|' "$TEST_CASES_TEMPLATE"
assert_present '\| NFR \|' "$TEST_CASES_TEMPLATE"
assert_no_legacy_review_artifact_ref "$TEST_CASES_TEMPLATE"
assert_present '^## 用户确认记录$' "$PLAN_TEMPLATE"
assert_present '^## 计划模式$' "$PLAN_TEMPLATE"
assert_present '^## 目标闭环与执行度量$' "$PLAN_TEMPLATE"
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
assert_present 'baseline_note: \{当前基线' "$PLAN_TEMPLATE"
assert_present 'guardrail_note: \{不可退化的护栏' "$PLAN_TEMPLATE"
assert_present '^\| 目标 \| goal_source_ref \| 承接 Task \| execution_basis_ref \| 成功信号 \| 基线 \| 护栏 \| 说明 \|$' "$PLAN_TEMPLATE"
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
REVIEW_CHECK="$ROOT/shared/skills/review/scripts/completion_check.sh"
TECH_LEAD_CHECK="$ROOT/shared/skills/tech-lead/scripts/completion_check.sh"
TEST_DESIGN_CHECK="$ROOT/shared/skills/test-design/scripts/completion_check.sh"
PM_GATE_CHECK="$ROOT/shared/skills/delivery-owner/scripts/completion_check.sh"
QA_CHECK="$ROOT/shared/skills/qa/scripts/completion_check.sh"
VERIFY_CHECK="$ROOT/shared/skills/verify/scripts/completion_check.sh"
RESEARCH_CHECK="$ROOT/shared/skills/research/scripts/completion_check.sh"

assert_present '"## 交付确认"' "$PRODUCT_CHECK"
assert_present '"交付确认"; do' "$PRODUCT_CHECK"
assert_present '数据行不足 7 条' "$PRODUCT_CHECK"
assert_present '确认状态必须为「确认」' "$PRODUCT_CHECK"
assert_present 'brief\.json' "$PRODUCT_CHECK"
assert_present '目标与成功标准' "$PRODUCT_CHECK"
assert_present '当前基线' "$PRODUCT_CHECK"
assert_present '目标值/方向' "$PRODUCT_CHECK"
assert_present '观测窗口' "$PRODUCT_CHECK"
assert_present '数据来源' "$PRODUCT_CHECK"
assert_present '观察型说明' "$PRODUCT_CHECK"
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
assert_present '最终冻结内容不得残留候选/草稿痕迹' "$DESIGN_CHECK"
assert_present 'extract_review_summary_row' "$DESIGN_CHECK"
assert_present 'extract_review_issue_ledger_rows' "$DESIGN_CHECK"
assert_present 'validate_review_convergence_policy' "$DESIGN_CHECK"
assert_no_legacy_review_artifact_ref "$DESIGN_CHECK"

test -f "$REVIEW_CHECK" || fail "missing review completion_check.sh"
assert_present 'code-review-result\.json' "$REVIEW_CHECK"
assert_present 'standard-chain canonical review artifact valid' "$REVIEW_CHECK"

test -f "$VERIFY_CHECK" || fail "missing verify completion_check.sh"
assert_present 'verify-result\.json' "$VERIFY_CHECK"
assert_present 'standard-chain canonical verify artifact valid' "$VERIFY_CHECK"

assert_present '"## 用户确认记录"' "$TECH_LEAD_CHECK"
assert_present '用户确认记录状态必须为「确认」' "$TECH_LEAD_CHECK"
assert_present 'validate_standard_chain_phase\.py' "$TECH_LEAD_CHECK"
assert_present 'docs/\[\^/"\[:space:\]\*\{\}\]\+/phase-\[0-9\]\+/\(plan\|tasks\)\\.json' "$TECH_LEAD_CHECK"
assert_present 'legacy markdown tech-lead hook disabled' "$TECH_LEAD_CHECK"
assert_present '### 审查汇总' "$TECH_LEAD_CHECK"
assert_present 'proving_command' "$TECH_LEAD_CHECK"
assert_present 'real_dependency_note' "$TECH_LEAD_CHECK"
assert_present 'evidence_target' "$TECH_LEAD_CHECK"
assert_present 'mock_boundary_note' "$TECH_LEAD_CHECK"
assert_present 'COVERED-NO-TEST' "$TECH_LEAD_CHECK"
assert_present 'EX-NO-TEST' "$TECH_LEAD_CHECK"
assert_present '目标闭环与执行度量' "$TECH_LEAD_CHECK"
assert_present 'goal_fidelity_review' "$CHAIN_CONTRACT"
assert_present 'baseline_note' "$TECH_LEAD_CHECK"
assert_present 'guardrail_note' "$TECH_LEAD_CHECK"

assert_present '不满足 HARD-GATE 2' "$TEST_DESIGN_CHECK"
assert_present '草稿内容泄漏到最终 test-cases.md' "$TEST_DESIGN_CHECK"
assert_present 'QA 交接契约' "$TEST_DESIGN_CHECK"
assert_present 'test-cases\.json' "$TEST_DESIGN_CHECK"
assert_present 'extract_review_summary_row' "$TEST_DESIGN_CHECK"
assert_present 'extract_review_issue_ledger_rows' "$TEST_DESIGN_CHECK"
assert_present 'validate_review_convergence_policy' "$TEST_DESIGN_CHECK"
assert_present 'test_obligation' "$TEST_DESIGN_CHECK"
assert_present 'qa_stage' "$TEST_DESIGN_CHECK"
assert_present 'requiredness' "$TEST_DESIGN_CHECK"
assert_present 'execution_mode' "$TEST_DESIGN_CHECK"
assert_no_legacy_review_artifact_ref "$TEST_DESIGN_CHECK"

test -f "$QA_CHECK" || fail "missing qa completion_check.sh"
assert_present 'qa-result\.json' "$QA_CHECK"
assert_present 'baseline_plan_version_ref' "$QA_CHECK"
assert_present 'baseline_tasks_version_ref' "$QA_CHECK"
assert_present 'gate_result' "$QA_CHECK"
assert_present '审查分级' "$QA_CHECK"
assert_present '## 验收汇总' "$QA_CHECK"
assert_present 'QA_A/QA_B/QA_C/QA_D' "$QA_CHECK"
assert_present 'RESULT: PASS \| FAIL' "$QA_CHECK"
assert_present 'release_recommendation' "$QA_CHECK"
assert_present 'residual_risk' "$QA_CHECK"
assert_present 'uncovered_boundary' "$QA_CHECK"
assert_present 'conditional_release_basis' "$QA_CHECK"
assert_present 'not_executed_reason' "$QA_CHECK"
assert_present '条件放行' "$QA_CHECK"
assert_present 'severity' "$QA_CHECK"
assert_present 'priority' "$QA_CHECK"
assert_present 'impact_scope' "$QA_CHECK"
assert_present 'user_impact' "$QA_CHECK"
assert_present 'browser_tool' "$QA_CHECK"
assert_present 'entry_url' "$QA_CHECK"
assert_present 'browser_evidence' "$QA_CHECK"
assert_present 'browser_required' "$QA_CHECK"
assert_present 'ruled_out_issues' "$QA_CHECK"
assert_present 'signoff-package\.json' "$PM_GATE_CHECK"
assert_present 'delivery-state\.json' "$PM_GATE_CHECK"
assert_present 'artifact-registry\.json' "$PM_GATE_CHECK"
assert_present 'validate_standard_chain_readiness\.py' "$PM_GATE_CHECK"

assert_present 'test_cases_ref' "$QA_SKILL"
assert_present 'Phase 级' "$QA_SKILL"
assert_present 'release_recommendation' "$QA_SKILL"
assert_present 'ALLOW \| CONDITIONAL_ALLOW \| BLOCK \| DEFER' "$QA_SKILL"
assert_present 'uncovered_boundary' "$QA_SKILL"
assert_present 'issue_ledger' "$QA_SKILL"
assert_present 'conditional_release_basis' "$QA_SKILL"
assert_present 'not_executed_reason' "$QA_SKILL"
assert_present 'test_cases_refs' "$QA_SKILL"
assert_present 'browser_required' "$QA_SKILL"
assert_present 'browser_tool' "$QA_SKILL"
assert_present 'entry_url' "$QA_SKILL"
assert_present 'browser_evidence' "$QA_SKILL"
assert_present 'test_cases_ref（必填）' "$QA_AGENT"
assert_present 'test_cases_refs（QA_B/QA_C/QA_D 聚合输入）' "$QA_AGENT"
assert_present 'qa-result.json（Phase 级）' "$QA_AGENT"
assert_present 'browser_required' "$QA_AGENT"
assert_present 'webapp-testing' "$ROOT/shared/skills/qa/references/e2e-journey-methodology.md"
assert_present 'Playwright' "$ROOT/shared/skills/qa/references/e2e-journey-methodology.md"
assert_present '浏览器 E2E' "$ROOT/shared/skills/qa/references/e2e-journey-methodology.md"
assert_present '多步骤表单 / 向导 / 下单流' "$ROOT/docs/qa-test-v2/2026-04-11-best-practice-rebuild/replay-scenarios.md"

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
assert_present 'test-cases\.json`（必须存在' "$TECH_LEAD_AGENT"

TECH_LEAD_FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/org-tech-lead-gate.XXXXXX")"
HOOK_FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/org-hook-gate.XXXXXX")"
trap 'rm -rf "$TECH_LEAD_FIXTURE_ROOT" "$HOOK_FIXTURE_ROOT" "${ORPHAN_GATE_ROOT:-}" "${TECH_LEAD_LAST_OUTPUT:-}" "${LAST_CHECK_OUTPUT:-}" "${LAST_CHECK_STDOUT:-}" "${LAST_CHECK_STDERR:-}"' EXIT

CANONICAL_TECH_LEAD_ROOT="$TECH_LEAD_FIXTURE_ROOT/canonical-tech-lead"
mkdir -p "$CANONICAL_TECH_LEAD_ROOT/docs"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$CANONICAL_TECH_LEAD_ROOT/docs/"
mkdir -p "$CANONICAL_TECH_LEAD_ROOT/tools" "$CANONICAL_TECH_LEAD_ROOT/contracts" "$CANONICAL_TECH_LEAD_ROOT/shared"
cp -R "$ROOT/tools/community" "$CANONICAL_TECH_LEAD_ROOT/tools/"
cp -R "$ROOT/contracts/canonical" "$CANONICAL_TECH_LEAD_ROOT/contracts/"
cp -R "$ROOT/shared/runtime" "$CANONICAL_TECH_LEAD_ROOT/shared/"

ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$TECH_LEAD_CHECK" \
  "$CANONICAL_TECH_LEAD_ROOT" \
  "session-tech-lead-canonical-pass" \
  "docs/sample-feature/phase-1/plan.json\n" \
  "Write" \
  "docs/sample-feature/phase-1/plan.json"
[ "$LAST_CHECK_STATUS" -eq 0 ] || {
  cat "$LAST_CHECK_OUTPUT" >&2
  fail "tech-lead canonical gate should pass for valid plan.json edit"
}

rm -f "$CANONICAL_TECH_LEAD_ROOT/docs/sample-feature/phase-1/tasks.json"
ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$TECH_LEAD_CHECK" \
  "$CANONICAL_TECH_LEAD_ROOT" \
  "session-tech-lead-canonical-fail" \
  "docs/sample-feature/phase-1/plan.json\n" \
  "Write" \
  "docs/sample-feature/phase-1/plan.json"
[ "$LAST_CHECK_STATUS" -ne 0 ] || fail "tech-lead canonical gate should fail when tasks.json is missing"
assert_present 'tasks\.json|canonical tech-lead phase gate 未通过' "$LAST_CHECK_OUTPUT"

ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$TECH_LEAD_CHECK" \
  "$CANONICAL_TECH_LEAD_ROOT" \
  "session-tech-lead-canonical-missing-file-path" \
  "docs/sample-feature/phase-1/plan.json\n" \
  "Write"
[ "$LAST_CHECK_STATUS" -ne 0 ] || fail "tech-lead canonical gate should fail closed when file_path is missing"
assert_present 'tool_input\.file_path|canonical tech-lead gate' "$LAST_CHECK_OUTPUT"

TECH_LEAD_CANONICAL_MIXED_ROOT="$TECH_LEAD_FIXTURE_ROOT/canonical-tech-lead-mixed"
mkdir -p "$TECH_LEAD_CANONICAL_MIXED_ROOT/docs"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TECH_LEAD_CANONICAL_MIXED_ROOT/docs/"
mkdir -p "$TECH_LEAD_CANONICAL_MIXED_ROOT/tools" "$TECH_LEAD_CANONICAL_MIXED_ROOT/contracts" "$TECH_LEAD_CANONICAL_MIXED_ROOT/shared"
cp -R "$ROOT/tools/community" "$TECH_LEAD_CANONICAL_MIXED_ROOT/tools/"
cp -R "$ROOT/contracts/canonical" "$TECH_LEAD_CANONICAL_MIXED_ROOT/contracts/"
cp -R "$ROOT/shared/runtime" "$TECH_LEAD_CANONICAL_MIXED_ROOT/shared/"
cat > "$TECH_LEAD_CANONICAL_MIXED_ROOT/docs/sample-feature/brief.md" <<'EOF'
# Legacy brief should be rejected once canonical-only gate is active.
EOF
cat > "$TECH_LEAD_CANONICAL_MIXED_ROOT/docs/sample-feature/phase-1/plan.md" <<'EOF'
# Legacy plan should be rejected once canonical-only gate is active.
EOF
ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$TECH_LEAD_CHECK" \
  "$TECH_LEAD_CANONICAL_MIXED_ROOT" \
  "session-tech-lead-canonical-mixed-mode" \
  "docs/sample-feature/phase-1/plan.json\n" \
  "Write" \
  "docs/sample-feature/phase-1/plan.json"
[ "$LAST_CHECK_STATUS" -ne 0 ] || fail "tech-lead canonical gate should reject mixed markdown/json phase layouts"
assert_present 'canonical-only|legacy markdown|mixed mode' "$LAST_CHECK_OUTPUT"

TECH_LEAD_CANONICAL_MISSING_DESIGN_ROOT="$TECH_LEAD_FIXTURE_ROOT/canonical-tech-lead-missing-design"
mkdir -p "$TECH_LEAD_CANONICAL_MISSING_DESIGN_ROOT/docs"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TECH_LEAD_CANONICAL_MISSING_DESIGN_ROOT/docs/"
mkdir -p "$TECH_LEAD_CANONICAL_MISSING_DESIGN_ROOT/tools" "$TECH_LEAD_CANONICAL_MISSING_DESIGN_ROOT/contracts" "$TECH_LEAD_CANONICAL_MISSING_DESIGN_ROOT/shared"
cp -R "$ROOT/tools/community" "$TECH_LEAD_CANONICAL_MISSING_DESIGN_ROOT/tools/"
cp -R "$ROOT/contracts/canonical" "$TECH_LEAD_CANONICAL_MISSING_DESIGN_ROOT/contracts/"
cp -R "$ROOT/shared/runtime" "$TECH_LEAD_CANONICAL_MISSING_DESIGN_ROOT/shared/"
rm -f "$TECH_LEAD_CANONICAL_MISSING_DESIGN_ROOT/docs/sample-feature/phase-1/design.json"
ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$TECH_LEAD_CHECK" \
  "$TECH_LEAD_CANONICAL_MISSING_DESIGN_ROOT" \
  "session-tech-lead-canonical-missing-design" \
  "docs/sample-feature/phase-1/tasks.json\n" \
  "Write" \
  "docs/sample-feature/phase-1/tasks.json"
[ "$LAST_CHECK_STATUS" -ne 0 ] || fail "tech-lead canonical gate should require upstream design.json"
assert_present 'design\.json|canonical tech-lead phase gate 未通过' "$LAST_CHECK_OUTPUT"

TECH_LEAD_CANONICAL_MISSING_TEST_CASES_ROOT="$TECH_LEAD_FIXTURE_ROOT/canonical-tech-lead-missing-test-cases"
mkdir -p "$TECH_LEAD_CANONICAL_MISSING_TEST_CASES_ROOT/docs"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$TECH_LEAD_CANONICAL_MISSING_TEST_CASES_ROOT/docs/"
mkdir -p "$TECH_LEAD_CANONICAL_MISSING_TEST_CASES_ROOT/tools" "$TECH_LEAD_CANONICAL_MISSING_TEST_CASES_ROOT/contracts" "$TECH_LEAD_CANONICAL_MISSING_TEST_CASES_ROOT/shared"
cp -R "$ROOT/tools/community" "$TECH_LEAD_CANONICAL_MISSING_TEST_CASES_ROOT/tools/"
cp -R "$ROOT/contracts/canonical" "$TECH_LEAD_CANONICAL_MISSING_TEST_CASES_ROOT/contracts/"
cp -R "$ROOT/shared/runtime" "$TECH_LEAD_CANONICAL_MISSING_TEST_CASES_ROOT/shared/"
rm -f "$TECH_LEAD_CANONICAL_MISSING_TEST_CASES_ROOT/docs/sample-feature/phase-1/unit-1/test-cases.json"
ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$TECH_LEAD_CHECK" \
  "$TECH_LEAD_CANONICAL_MISSING_TEST_CASES_ROOT" \
  "session-tech-lead-canonical-missing-test-cases" \
  "docs/sample-feature/phase-1/tasks.json\n" \
  "Write" \
  "docs/sample-feature/phase-1/tasks.json"
[ "$LAST_CHECK_STATUS" -ne 0 ] || fail "tech-lead canonical gate should require unit test-cases.json"
assert_present 'test-cases\.json|canonical tech-lead phase gate 未通过' "$LAST_CHECK_OUTPUT"

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-valid" "已收口" "no" "complete" "valid" "valid" "valid" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-valid" "session-valid"
assert_tech_lead_check_passes "valid exploration-first plan"

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-missing-goal-review" "已收口" "no" "complete" "valid" "valid" "valid" "valid" "missing_section" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-missing-goal-review" "session-missing-goal-review"
assert_tech_lead_check_fails_with "missing goal fidelity review" '目标闭环与执行度量|goal_fidelity_review'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-duplicate-goal-rows" "已收口" "no" "complete" "valid" "valid" "valid" "valid" "duplicate_brief_goal_rows" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-duplicate-goal-rows" "session-duplicate-goal-rows"
assert_tech_lead_check_passes "duplicate goal review rows for one upstream goal should pass"

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-missing-second-goal-same-count" "已收口" "no" "complete" "valid" "valid" "valid" "valid" "missing_second_brief_goal_same_count" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-missing-second-goal-same-count" "session-missing-second-goal-same-count"
assert_tech_lead_check_fails_with "missing second upstream goal should fail even when row count matches" 'brief.*目标未完整承接|目标闭环与执行度量.*未完整承接|目标闭环与执行度量.*二次校验完成'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-invalid-goal-source" "已收口" "no" "complete" "valid" "valid" "valid" "valid" "invalid_goal_source_ref" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-invalid-goal-source" "session-invalid-goal-source"
assert_tech_lead_check_fails_with "invalid goal source ref" 'goal_source_ref.*brief\.md#目标与成功标准.*prd\.md#阶段目标|目标闭环与执行度量.*goal_source_ref'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-invalid-execution-basis-anchor" "已收口" "no" "complete" "valid" "valid" "valid" "valid" "invalid_execution_basis_anchor" "valid"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-invalid-execution-basis-anchor" "session-invalid-execution-basis-anchor"
assert_tech_lead_check_fails_with "invalid execution basis anchor should fail" 'execution_basis_ref.*锚点不存在|execution_basis_ref.*不存在的锚点'

create_tech_lead_fixture "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-missing-baseline-note" "已收口" "no" "complete" "valid" "valid" "valid" "valid" "valid" "missing_baseline"
run_tech_lead_completion_check "$TECH_LEAD_FIXTURE_ROOT" "tech-lead-missing-baseline-note" "session-missing-baseline-note"
assert_tech_lead_check_fails_with "missing baseline note for exploration task" 'baseline_note'

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

PRODUCT_GOAL_ROOT="$HOOK_FIXTURE_ROOT/product-goal"
create_product_goal_gate_fixture "$PRODUCT_GOAL_ROOT" "product-goal" "missing_baseline"
run_completion_check_with_payload \
  "$PRODUCT_CHECK" \
  "$PRODUCT_GOAL_ROOT" \
  "session-product-goal" \
  "docs/product-goal/brief.md\n" \
  "Write" \
  "docs/product-goal/brief.md"
assert_last_check_fails_with "product goal signal contract should require baseline" '目标与成功标准.*当前基线|目标与成功标准.*基线'

PRODUCT_GOAL_OBS_ROOT="$HOOK_FIXTURE_ROOT/product-goal-observation"
create_product_goal_gate_fixture "$PRODUCT_GOAL_OBS_ROOT" "product-goal-observation" "observation_without_note"
run_completion_check_with_payload \
  "$PRODUCT_CHECK" \
  "$PRODUCT_GOAL_OBS_ROOT" \
  "session-product-goal-observation" \
  "docs/product-goal-observation/brief.md\n" \
  "Write" \
  "docs/product-goal-observation/brief.md"
assert_last_check_fails_with "product observation signal should require note" '观察型说明|为什么当前不能机械化|替代观测信号'

PRODUCT_GOAL_OBS_PARTIAL_ROOT="$HOOK_FIXTURE_ROOT/product-goal-observation-partial"
create_product_goal_gate_fixture "$PRODUCT_GOAL_OBS_PARTIAL_ROOT" "product-goal-observation-partial" "observation_partial_note"
run_completion_check_with_payload \
  "$PRODUCT_CHECK" \
  "$PRODUCT_GOAL_OBS_PARTIAL_ROOT" \
  "session-product-goal-observation-partial" \
  "docs/product-goal-observation-partial/brief.md\n" \
  "Write" \
  "docs/product-goal-observation-partial/brief.md"
assert_last_check_fails_with "product observation note should bind every observation goal" '观察型说明.*二次校验完成|替代观测信号.*二次校验完成|为什么当前不能机械化.*二次校验完成'

PM_HOOK_ROOT="$HOOK_FIXTURE_ROOT/delivery-owner-hook"
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
assert_last_check_fails_with "delivery-owner hook should reach full validation" 'plan\.md 不存在|design\.md 不存在|code-review-report\.md 不存在|qa-report\.md 不存在'
assert_last_check_stdout_json "delivery-owner hook failure should emit block json" "block"
assert_last_check_absent "delivery-owner hook should not hit shell function ordering bug" 'trim: command not found|command not found'

run_completion_check_with_raw_payload "$PM_GATE_CHECK" ''
assert_last_check_fails_with "delivery-owner hook empty stdin should block" 'stdin 为空|hook 上下文'
assert_last_check_stdout_json "delivery-owner hook empty stdin should emit block json" "block"

run_completion_check_with_raw_payload "$PM_GATE_CHECK" 'not-json'
assert_last_check_fails_with "delivery-owner hook invalid json should block" '不是有效 JSON|hook 上下文'
assert_last_check_stdout_json "delivery-owner hook invalid json should emit block json" "block"

run_completion_check_with_raw_payload "$PM_GATE_CHECK" '{"cwd":"/definitely/missing","session_id":"session-bad-cwd","transcript_path":"/tmp/missing-transcript.log"}'
assert_last_check_fails_with "delivery-owner hook bad cwd should block" 'cwd 不存在'
assert_last_check_stdout_json "delivery-owner hook bad cwd should emit block json" "block"

QA_CANONICAL_ROOT="$HOOK_FIXTURE_ROOT/qa-canonical"
mkdir -p "$QA_CANONICAL_ROOT/docs/qa-canonical"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$QA_CANONICAL_ROOT/docs/qa-canonical/"
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_CANONICAL_ROOT" \
  "session-qa-canonical" \
  "docs/qa-canonical/phase-1/qa-result.json\n" \
  "Write" \
  "docs/qa-canonical/phase-1/qa-result.json"
assert_last_check_passes "qa canonical artifact should pass"

PRODUCT_CANONICAL_ROOT="$HOOK_FIXTURE_ROOT/product-canonical"
mkdir -p "$PRODUCT_CANONICAL_ROOT/docs/product-canonical"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$PRODUCT_CANONICAL_ROOT/docs/product-canonical/"
run_completion_check_with_payload \
  "$PRODUCT_CHECK" \
  "$PRODUCT_CANONICAL_ROOT" \
  "session-product-canonical" \
  "docs/product-canonical/brief.json\n" \
  "Write" \
  "docs/product-canonical/brief.json"
assert_last_check_passes "product canonical artifact should pass"
assert_last_check_stdout_json "product canonical artifact should emit allow json" "allow"
assert_last_check_stdout_nonempty "product canonical artifact should emit canonical decision"

DESIGN_CANONICAL_ROOT="$HOOK_FIXTURE_ROOT/design-canonical"
mkdir -p "$DESIGN_CANONICAL_ROOT/docs/design-canonical"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$DESIGN_CANONICAL_ROOT/docs/design-canonical/"
ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$DESIGN_CHECK" \
  "$DESIGN_CANONICAL_ROOT" \
  "session-design-canonical" \
  "docs/design-canonical/phase-1/design.json\n" \
  "Write" \
  "docs/design-canonical/phase-1/design.json"
assert_last_check_passes "design canonical artifact should pass"
assert_last_check_stdout_json "design canonical artifact should emit allow json" "allow"
assert_last_check_stdout_nonempty "design canonical artifact should emit canonical decision"

DESIGN_CANONICAL_SPARSE_ROOT="$HOOK_FIXTURE_ROOT/design-canonical-sparse"
mkdir -p "$DESIGN_CANONICAL_SPARSE_ROOT/docs/design-canonical-sparse"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$DESIGN_CANONICAL_SPARSE_ROOT/docs/design-canonical-sparse/"
jq 'del(.key_decisions)' \
  "$DESIGN_CANONICAL_SPARSE_ROOT/docs/design-canonical-sparse/phase-1/design.json" \
  > "$DESIGN_CANONICAL_SPARSE_ROOT/docs/design-canonical-sparse/phase-1/design.tmp.json"
mv "$DESIGN_CANONICAL_SPARSE_ROOT/docs/design-canonical-sparse/phase-1/design.tmp.json" \
  "$DESIGN_CANONICAL_SPARSE_ROOT/docs/design-canonical-sparse/phase-1/design.json"
ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$DESIGN_CHECK" \
  "$DESIGN_CANONICAL_SPARSE_ROOT" \
  "session-design-canonical-sparse" \
  "docs/design-canonical-sparse/phase-1/design.json\n" \
  "Write" \
  "docs/design-canonical-sparse/phase-1/design.json"
assert_last_check_fails_with "design canonical sparse artifact should fail" 'design\.json 缺少 canonical 必填字段|design\.json'
assert_last_check_stdout_json "design canonical sparse artifact should emit block json" "block"

DESIGN_CANONICAL_MISSING_TARGET_ROOT="$HOOK_FIXTURE_ROOT/design-canonical-missing-target"
mkdir -p "$DESIGN_CANONICAL_MISSING_TARGET_ROOT/docs/design-canonical-missing-target"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$DESIGN_CANONICAL_MISSING_TARGET_ROOT/docs/design-canonical-missing-target/"
ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$DESIGN_CHECK" \
  "$DESIGN_CANONICAL_MISSING_TARGET_ROOT" \
  "session-design-canonical-missing-target" \
  ""
assert_last_check_fails_with "design canonical stop gate should fail closed when design.json is never written" 'design\.json 路径未命中|canonical'
assert_last_check_stdout_json "design canonical missing-target should emit block json" "block"

REVIEW_CANONICAL_ROOT="$HOOK_FIXTURE_ROOT/review-canonical"
mkdir -p "$REVIEW_CANONICAL_ROOT/docs/review-canonical"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$REVIEW_CANONICAL_ROOT/docs/review-canonical/"
ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$REVIEW_CHECK" \
  "$REVIEW_CANONICAL_ROOT" \
  "session-review-canonical" \
  "docs/review-canonical/phase-1/code-review-result.json\n" \
  "Write" \
  "docs/review-canonical/phase-1/code-review-result.json"
assert_last_check_passes "review canonical artifact should pass"
assert_last_check_stdout_json "review canonical artifact should emit allow json" "allow"
assert_last_check_stdout_nonempty "review canonical artifact should emit canonical decision"

REVIEW_CANONICAL_SPARSE_ROOT="$HOOK_FIXTURE_ROOT/review-canonical-sparse"
mkdir -p "$REVIEW_CANONICAL_SPARSE_ROOT/docs/review-canonical-sparse"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$REVIEW_CANONICAL_SPARSE_ROOT/docs/review-canonical-sparse/"
jq 'del(.gate_result)' \
  "$REVIEW_CANONICAL_SPARSE_ROOT/docs/review-canonical-sparse/phase-1/code-review-result.json" \
  > "$REVIEW_CANONICAL_SPARSE_ROOT/docs/review-canonical-sparse/phase-1/code-review-result.tmp.json"
mv "$REVIEW_CANONICAL_SPARSE_ROOT/docs/review-canonical-sparse/phase-1/code-review-result.tmp.json" \
  "$REVIEW_CANONICAL_SPARSE_ROOT/docs/review-canonical-sparse/phase-1/code-review-result.json"
ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$REVIEW_CHECK" \
  "$REVIEW_CANONICAL_SPARSE_ROOT" \
  "session-review-canonical-sparse" \
  "docs/review-canonical-sparse/phase-1/code-review-result.json\n" \
  "Write" \
  "docs/review-canonical-sparse/phase-1/code-review-result.json"
assert_last_check_fails_with "review canonical sparse artifact should fail" 'code-review-result\.json 缺少 canonical 必填字段|code-review-result\.json'
assert_last_check_stdout_json "review canonical sparse artifact should emit block json" "block"

REVIEW_CANONICAL_MISSING_TARGET_ROOT="$HOOK_FIXTURE_ROOT/review-canonical-missing-target"
mkdir -p "$REVIEW_CANONICAL_MISSING_TARGET_ROOT/docs/review-canonical-missing-target"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$REVIEW_CANONICAL_MISSING_TARGET_ROOT/docs/review-canonical-missing-target/"
ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$REVIEW_CHECK" \
  "$REVIEW_CANONICAL_MISSING_TARGET_ROOT" \
  "session-review-canonical-missing-target" \
  ""
assert_last_check_fails_with "review canonical stop gate should fail closed when code-review-result.json is never written" 'code-review-result\.json 路径未命中|canonical'
assert_last_check_stdout_json "review canonical missing-target should emit block json" "block"

PRODUCT_CANONICAL_SPARSE_ROOT="$HOOK_FIXTURE_ROOT/product-canonical-sparse"
mkdir -p "$PRODUCT_CANONICAL_SPARSE_ROOT/docs/product-canonical-sparse"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$PRODUCT_CANONICAL_SPARSE_ROOT/docs/product-canonical-sparse/"
jq 'del(.delivery_confirmation)' \
  "$PRODUCT_CANONICAL_SPARSE_ROOT/docs/product-canonical-sparse/brief.json" \
  > "$PRODUCT_CANONICAL_SPARSE_ROOT/docs/product-canonical-sparse/brief.tmp.json"
mv "$PRODUCT_CANONICAL_SPARSE_ROOT/docs/product-canonical-sparse/brief.tmp.json" \
  "$PRODUCT_CANONICAL_SPARSE_ROOT/docs/product-canonical-sparse/brief.json"
run_completion_check_with_payload \
  "$PRODUCT_CHECK" \
  "$PRODUCT_CANONICAL_SPARSE_ROOT" \
  "session-product-canonical-sparse" \
  "docs/product-canonical-sparse/brief.json\n" \
  "Write" \
  "docs/product-canonical-sparse/brief.json"
assert_last_check_fails_with "product canonical sparse brief should fail" 'brief\.json 缺少 canonical 必填字段'
assert_last_check_stdout_json "product canonical sparse brief should emit block json" "block"

PRODUCT_CANONICAL_EMPTY_SHELL_ROOT="$HOOK_FIXTURE_ROOT/product-canonical-empty-shell"
mkdir -p "$PRODUCT_CANONICAL_EMPTY_SHELL_ROOT/docs/product-canonical-empty-shell"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$PRODUCT_CANONICAL_EMPTY_SHELL_ROOT/docs/product-canonical-empty-shell/"
jq '.delivery_confirmation = {}' \
  "$PRODUCT_CANONICAL_EMPTY_SHELL_ROOT/docs/product-canonical-empty-shell/brief.json" \
  > "$PRODUCT_CANONICAL_EMPTY_SHELL_ROOT/docs/product-canonical-empty-shell/brief.tmp.json"
mv "$PRODUCT_CANONICAL_EMPTY_SHELL_ROOT/docs/product-canonical-empty-shell/brief.tmp.json" \
  "$PRODUCT_CANONICAL_EMPTY_SHELL_ROOT/docs/product-canonical-empty-shell/brief.json"
run_completion_check_with_payload \
  "$PRODUCT_CHECK" \
  "$PRODUCT_CANONICAL_EMPTY_SHELL_ROOT" \
  "session-product-canonical-empty-shell" \
  "docs/product-canonical-empty-shell/brief.json\n" \
  "Write" \
  "docs/product-canonical-empty-shell/brief.json"
assert_last_check_fails_with "product canonical empty-shell brief should fail" 'brief\.json 缺少 canonical 必填字段'
assert_last_check_stdout_json "product canonical empty-shell brief should emit block json" "block"

PRODUCT_CANONICAL_LEGACY_ALIAS_ROOT="$HOOK_FIXTURE_ROOT/product-canonical-legacy-alias"
mkdir -p "$PRODUCT_CANONICAL_LEGACY_ALIAS_ROOT/docs/product-canonical-legacy-alias"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$PRODUCT_CANONICAL_LEGACY_ALIAS_ROOT/docs/product-canonical-legacy-alias/"
jq '(.non_functional_req = .non_functional_requirements) | del(.non_functional_requirements)' \
  "$PRODUCT_CANONICAL_LEGACY_ALIAS_ROOT/docs/product-canonical-legacy-alias/brief.json" \
  > "$PRODUCT_CANONICAL_LEGACY_ALIAS_ROOT/docs/product-canonical-legacy-alias/brief.tmp.json"
mv "$PRODUCT_CANONICAL_LEGACY_ALIAS_ROOT/docs/product-canonical-legacy-alias/brief.tmp.json" \
  "$PRODUCT_CANONICAL_LEGACY_ALIAS_ROOT/docs/product-canonical-legacy-alias/brief.json"
run_completion_check_with_payload \
  "$PRODUCT_CHECK" \
  "$PRODUCT_CANONICAL_LEGACY_ALIAS_ROOT" \
  "session-product-canonical-legacy-alias" \
  "docs/product-canonical-legacy-alias/brief.json\n" \
  "Write" \
  "docs/product-canonical-legacy-alias/brief.json"
assert_last_check_fails_with "product canonical legacy alias should fail" 'brief\.json 缺少 canonical 必填字段|non_functional_requirements'
assert_last_check_stdout_json "product canonical legacy alias should emit block json" "block"

PRODUCT_CANONICAL_MISSING_TARGET_ROOT="$HOOK_FIXTURE_ROOT/product-canonical-missing-target"
mkdir -p "$PRODUCT_CANONICAL_MISSING_TARGET_ROOT/docs/product-canonical-missing-target"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$PRODUCT_CANONICAL_MISSING_TARGET_ROOT/docs/product-canonical-missing-target/"
ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$PRODUCT_CHECK" \
  "$PRODUCT_CANONICAL_MISSING_TARGET_ROOT" \
  "session-product-canonical-missing-target" \
  ""
assert_last_check_fails_with "product canonical stop gate should fail closed when no canonical artifact is written" 'canonical product 工件路径未命中|brief\.json'
assert_last_check_stdout_json "product canonical missing-target should emit block json" "block"

TEST_DESIGN_CANONICAL_ROOT="$HOOK_FIXTURE_ROOT/test-design-canonical"
mkdir -p "$TEST_DESIGN_CANONICAL_ROOT/docs/test-design-canonical"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$TEST_DESIGN_CANONICAL_ROOT/docs/test-design-canonical/"
run_completion_check_with_payload \
  "$TEST_DESIGN_CHECK" \
  "$TEST_DESIGN_CANONICAL_ROOT" \
  "session-test-design-canonical" \
  "docs/test-design-canonical/phase-1/unit-1/test-cases.json\n" \
  "Write" \
  "docs/test-design-canonical/phase-1/unit-1/test-cases.json"
assert_last_check_passes "test-design canonical artifact should pass"

TEST_DESIGN_CANONICAL_SPARSE_ROOT="$HOOK_FIXTURE_ROOT/test-design-canonical-sparse"
mkdir -p "$TEST_DESIGN_CANONICAL_SPARSE_ROOT/docs/test-design-canonical-sparse"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$TEST_DESIGN_CANONICAL_SPARSE_ROOT/docs/test-design-canonical-sparse/"
jq 'del(.qa_handoff_contract)' \
  "$TEST_DESIGN_CANONICAL_SPARSE_ROOT/docs/test-design-canonical-sparse/phase-1/unit-1/test-cases.json" \
  > "$TEST_DESIGN_CANONICAL_SPARSE_ROOT/docs/test-design-canonical-sparse/phase-1/unit-1/test-cases.tmp.json"
mv "$TEST_DESIGN_CANONICAL_SPARSE_ROOT/docs/test-design-canonical-sparse/phase-1/unit-1/test-cases.tmp.json" \
  "$TEST_DESIGN_CANONICAL_SPARSE_ROOT/docs/test-design-canonical-sparse/phase-1/unit-1/test-cases.json"
run_completion_check_with_payload \
  "$TEST_DESIGN_CHECK" \
  "$TEST_DESIGN_CANONICAL_SPARSE_ROOT" \
  "session-test-design-canonical-sparse" \
  "docs/test-design-canonical-sparse/phase-1/unit-1/test-cases.json\n" \
  "Write" \
  "docs/test-design-canonical-sparse/phase-1/unit-1/test-cases.json"
assert_last_check_fails_with "test-design canonical sparse artifact should fail" 'test-cases\.json 缺少 canonical 必填字段'
assert_last_check_stdout_json "test-design canonical sparse artifact should emit block json" "block"

TEST_DESIGN_CANONICAL_EMPTY_SHELL_ROOT="$HOOK_FIXTURE_ROOT/test-design-canonical-empty-shell"
mkdir -p "$TEST_DESIGN_CANONICAL_EMPTY_SHELL_ROOT/docs/test-design-canonical-empty-shell"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$TEST_DESIGN_CANONICAL_EMPTY_SHELL_ROOT/docs/test-design-canonical-empty-shell/"
jq '.qa_handoff_contract = [{}]' \
  "$TEST_DESIGN_CANONICAL_EMPTY_SHELL_ROOT/docs/test-design-canonical-empty-shell/phase-1/unit-1/test-cases.json" \
  > "$TEST_DESIGN_CANONICAL_EMPTY_SHELL_ROOT/docs/test-design-canonical-empty-shell/phase-1/unit-1/test-cases.tmp.json"
mv "$TEST_DESIGN_CANONICAL_EMPTY_SHELL_ROOT/docs/test-design-canonical-empty-shell/phase-1/unit-1/test-cases.tmp.json" \
  "$TEST_DESIGN_CANONICAL_EMPTY_SHELL_ROOT/docs/test-design-canonical-empty-shell/phase-1/unit-1/test-cases.json"
run_completion_check_with_payload \
  "$TEST_DESIGN_CHECK" \
  "$TEST_DESIGN_CANONICAL_EMPTY_SHELL_ROOT" \
  "session-test-design-canonical-empty-shell" \
  "docs/test-design-canonical-empty-shell/phase-1/unit-1/test-cases.json\n" \
  "Write" \
  "docs/test-design-canonical-empty-shell/phase-1/unit-1/test-cases.json"
assert_last_check_fails_with "test-design canonical empty-shell artifact should fail" 'test-cases\.json 缺少 canonical 必填字段'
assert_last_check_stdout_json "test-design canonical empty-shell artifact should emit block json" "block"

TEST_DESIGN_CANONICAL_INVALID_MODE_ROOT="$HOOK_FIXTURE_ROOT/test-design-canonical-invalid-mode"
mkdir -p "$TEST_DESIGN_CANONICAL_INVALID_MODE_ROOT/docs/test-design-canonical-invalid-mode"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$TEST_DESIGN_CANONICAL_INVALID_MODE_ROOT/docs/test-design-canonical-invalid-mode/"
jq '.["qa_handoff_contract"][0].execution_mode = "browser_only"' \
  "$TEST_DESIGN_CANONICAL_INVALID_MODE_ROOT/docs/test-design-canonical-invalid-mode/phase-1/unit-1/test-cases.json" \
  > "$TEST_DESIGN_CANONICAL_INVALID_MODE_ROOT/docs/test-design-canonical-invalid-mode/phase-1/unit-1/test-cases.tmp.json"
mv "$TEST_DESIGN_CANONICAL_INVALID_MODE_ROOT/docs/test-design-canonical-invalid-mode/phase-1/unit-1/test-cases.tmp.json" \
  "$TEST_DESIGN_CANONICAL_INVALID_MODE_ROOT/docs/test-design-canonical-invalid-mode/phase-1/unit-1/test-cases.json"
run_completion_check_with_payload \
  "$TEST_DESIGN_CHECK" \
  "$TEST_DESIGN_CANONICAL_INVALID_MODE_ROOT" \
  "session-test-design-canonical-invalid-mode" \
  "docs/test-design-canonical-invalid-mode/phase-1/unit-1/test-cases.json\n" \
  "Write" \
  "docs/test-design-canonical-invalid-mode/phase-1/unit-1/test-cases.json"
assert_last_check_fails_with "test-design canonical invalid execution_mode should fail" 'execution_mode|browser_required|non_browser_ok'
assert_last_check_stdout_json "test-design canonical invalid execution_mode should emit block json" "block"

TEST_DESIGN_CANONICAL_MISSING_TARGET_ROOT="$HOOK_FIXTURE_ROOT/test-design-canonical-missing-target"
mkdir -p "$TEST_DESIGN_CANONICAL_MISSING_TARGET_ROOT/docs/test-design-canonical-missing-target"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$TEST_DESIGN_CANONICAL_MISSING_TARGET_ROOT/docs/test-design-canonical-missing-target/"
ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$TEST_DESIGN_CHECK" \
  "$TEST_DESIGN_CANONICAL_MISSING_TARGET_ROOT" \
  "session-test-design-canonical-missing-target" \
  ""
assert_last_check_fails_with "test-design canonical stop gate should fail closed when test-cases.json is never written" 'test-cases\.json 路径未命中|canonical'
assert_last_check_stdout_json "test-design canonical missing-target should emit block json" "block"

QA_CANONICAL_SPARSE_ROOT="$HOOK_FIXTURE_ROOT/qa-canonical-sparse"
mkdir -p "$QA_CANONICAL_SPARSE_ROOT/docs/qa-canonical-sparse"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$QA_CANONICAL_SPARSE_ROOT/docs/qa-canonical-sparse/"
jq 'del(.ruled_out_issues)' \
  "$QA_CANONICAL_SPARSE_ROOT/docs/qa-canonical-sparse/phase-1/qa-result.json" \
  > "$QA_CANONICAL_SPARSE_ROOT/docs/qa-canonical-sparse/phase-1/qa-result.tmp.json"
mv "$QA_CANONICAL_SPARSE_ROOT/docs/qa-canonical-sparse/phase-1/qa-result.tmp.json" \
  "$QA_CANONICAL_SPARSE_ROOT/docs/qa-canonical-sparse/phase-1/qa-result.json"
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_CANONICAL_SPARSE_ROOT" \
  "session-qa-canonical-sparse" \
  "docs/qa-canonical-sparse/phase-1/qa-result.json\n" \
  "Write" \
  "docs/qa-canonical-sparse/phase-1/qa-result.json"
assert_last_check_fails_with "qa canonical sparse artifact should fail" 'qa-result\.json 缺少 canonical 必填字段'
assert_last_check_stdout_json "qa canonical sparse artifact should emit block json" "block"

QA_CANONICAL_BROWSER_REQUIRED_ROOT="$HOOK_FIXTURE_ROOT/qa-canonical-browser-required"
mkdir -p "$QA_CANONICAL_BROWSER_REQUIRED_ROOT/docs/qa-canonical-browser-required"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$QA_CANONICAL_BROWSER_REQUIRED_ROOT/docs/qa-canonical-browser-required/"
jq '.qa_handoff_contract |= map(. + {execution_mode:"browser_required"})' \
  "$QA_CANONICAL_BROWSER_REQUIRED_ROOT/docs/qa-canonical-browser-required/phase-1/unit-1/test-cases.json" \
  > "$QA_CANONICAL_BROWSER_REQUIRED_ROOT/docs/qa-canonical-browser-required/phase-1/unit-1/test-cases.tmp.json"
mv "$QA_CANONICAL_BROWSER_REQUIRED_ROOT/docs/qa-canonical-browser-required/phase-1/unit-1/test-cases.tmp.json" \
  "$QA_CANONICAL_BROWSER_REQUIRED_ROOT/docs/qa-canonical-browser-required/phase-1/unit-1/test-cases.json"
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_CANONICAL_BROWSER_REQUIRED_ROOT" \
  "session-qa-canonical-browser-required" \
  "docs/qa-canonical-browser-required/phase-1/qa-result.json\n" \
  "Write" \
  "docs/qa-canonical-browser-required/phase-1/qa-result.json"
assert_last_check_fails_with "qa canonical browser_required artifact must include browser evidence" 'browser_evidence|browser_tool|entry_url|browser_required'
assert_last_check_stdout_json "qa canonical browser_required artifact should emit block json" "block"

QA_CANONICAL_BROWSER_API_ONLY_ROOT="$HOOK_FIXTURE_ROOT/qa-canonical-browser-api-only"
mkdir -p "$QA_CANONICAL_BROWSER_API_ONLY_ROOT/docs/qa-canonical-browser-api-only"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$QA_CANONICAL_BROWSER_API_ONLY_ROOT/docs/qa-canonical-browser-api-only/"
jq '.qa_handoff_contract |= map(. + {execution_mode:"browser_required"})' \
  "$QA_CANONICAL_BROWSER_API_ONLY_ROOT/docs/qa-canonical-browser-api-only/phase-1/unit-1/test-cases.json" \
  > "$QA_CANONICAL_BROWSER_API_ONLY_ROOT/docs/qa-canonical-browser-api-only/phase-1/unit-1/test-cases.tmp.json"
mv "$QA_CANONICAL_BROWSER_API_ONLY_ROOT/docs/qa-canonical-browser-api-only/phase-1/unit-1/test-cases.tmp.json" \
  "$QA_CANONICAL_BROWSER_API_ONLY_ROOT/docs/qa-canonical-browser-api-only/phase-1/unit-1/test-cases.json"
python3 - "$QA_CANONICAL_BROWSER_API_ONLY_ROOT/docs/qa-canonical-browser-api-only/phase-1/qa-result.json" <<'PY'
import json
import sys
from pathlib import Path

qa_path = Path(sys.argv[1])
payload = json.loads(qa_path.read_text(encoding="utf-8"))
payload["browser_tool"] = "curl"
payload["entry_url"] = "http://127.0.0.1:3000/login"
payload["browser_evidence"] = ["curl output attached"]
qa_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_CANONICAL_BROWSER_API_ONLY_ROOT" \
  "session-qa-canonical-browser-api-only" \
  "docs/qa-canonical-browser-api-only/phase-1/qa-result.json\n" \
  "Write" \
  "docs/qa-canonical-browser-api-only/phase-1/qa-result.json"
assert_last_check_fails_with "qa canonical browser_required artifact must reject api-only evidence" 'browser_evidence|browser_tool|浏览器'
assert_last_check_stdout_json "qa canonical browser api-only artifact should emit block json" "block"

QA_CANONICAL_MISSING_TARGET_ROOT="$HOOK_FIXTURE_ROOT/qa-canonical-missing-target"
mkdir -p "$QA_CANONICAL_MISSING_TARGET_ROOT/docs/qa-canonical-missing-target"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$QA_CANONICAL_MISSING_TARGET_ROOT/docs/qa-canonical-missing-target/"
ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_CANONICAL_MISSING_TARGET_ROOT" \
  "session-qa-canonical-missing-target" \
  ""
assert_last_check_fails_with "qa canonical stop gate should fail closed when qa-result.json is never written" 'qa-result\.json 路径未命中|canonical'
assert_last_check_stdout_json "qa canonical missing-target should emit block json" "block"

PM_CANONICAL_ROOT="$HOOK_FIXTURE_ROOT/pm-canonical"
mkdir -p "$PM_CANONICAL_ROOT/docs/pm-canonical"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$PM_CANONICAL_ROOT/docs/pm-canonical/"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_CANONICAL_ROOT" \
  "session-pm-canonical" \
  "docs/pm-canonical/phase-1/signoff-package.json\n" \
  "Write" \
  "docs/pm-canonical/phase-1/signoff-package.json"
assert_last_check_passes "delivery-owner canonical signoff package should pass readiness gate"

PM_CANONICAL_DELIVERY_STATE_ROOT="$HOOK_FIXTURE_ROOT/pm-canonical-delivery-state"
mkdir -p "$PM_CANONICAL_DELIVERY_STATE_ROOT/docs/pm-canonical-delivery-state"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$PM_CANONICAL_DELIVERY_STATE_ROOT/docs/pm-canonical-delivery-state/"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_CANONICAL_DELIVERY_STATE_ROOT" \
  "session-pm-canonical-delivery-state" \
  "docs/pm-canonical-delivery-state/phase-1/delivery-state.json\n" \
  "Write" \
  "docs/pm-canonical-delivery-state/phase-1/delivery-state.json"
assert_last_check_passes "delivery-owner canonical delivery-state should pass readiness gate"

PM_CANONICAL_MISSING_TARGET_ROOT="$HOOK_FIXTURE_ROOT/pm-canonical-missing-target"
mkdir -p "$PM_CANONICAL_MISSING_TARGET_ROOT/docs/pm-canonical-missing-target"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$PM_CANONICAL_MISSING_TARGET_ROOT/docs/pm-canonical-missing-target/"
ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=0 \
  run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_CANONICAL_MISSING_TARGET_ROOT" \
  "session-pm-canonical-missing-target" \
  ""
assert_last_check_fails_with "delivery-owner canonical stop gate should fail closed when closeout artifacts are never written" 'canonical closeout 工件路径未命中|delivery-state'
assert_last_check_stdout_json "delivery-owner canonical missing-target should emit block json" "block"

PM_CANONICAL_REGISTRY_ROOT="$HOOK_FIXTURE_ROOT/pm-canonical-artifact-registry"
mkdir -p "$PM_CANONICAL_REGISTRY_ROOT/docs/pm-canonical-artifact-registry"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/." "$PM_CANONICAL_REGISTRY_ROOT/docs/pm-canonical-artifact-registry/"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_CANONICAL_REGISTRY_ROOT" \
  "session-pm-canonical-artifact-registry" \
  "docs/pm-canonical-artifact-registry/phase-1/artifact-registry.json\n" \
  "Write" \
  "docs/pm-canonical-artifact-registry/phase-1/artifact-registry.json"
assert_last_check_passes "delivery-owner canonical artifact-registry should pass readiness gate"

ORPHAN_GATE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/org-pm-orphan.XXXXXX")"
cp "$PM_GATE_CHECK" "$ORPHAN_GATE_ROOT/completion_check.sh"
run_completion_check_with_raw_payload "$ORPHAN_GATE_ROOT/completion_check.sh" '{"cwd":".","session_id":"session-orphan","transcript_path":"/tmp/orphan.log"}'
assert_last_check_fails_with "delivery-owner hook missing dependencies should block" '初始化失败|缺少 hooks 依赖目录|无法加载'
assert_last_check_stdout_json "delivery-owner hook missing dependencies should emit block json" "block"

run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_HOOK_ROOT" \
  "session-pm-non-target" \
  "docs/pm-hook/phase-1/unit-1/dev-report.md\n" \
  "Write" \
  "docs/pm-hook/phase-1/unit-1/dev-report.md"
assert_last_check_passes "delivery-owner hook non-closeout artifact should skip explicitly"
assert_last_check_stdout_json "delivery-owner hook non-closeout artifact should emit allow json" "allow"
assert_last_check_contains "delivery-owner hook skip reason should be visible" 'skip: 当前写入目标不是 acceptance-summary\.md'

run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_HOOK_ROOT" \
  "session-pm-read-skip" \
  "docs/pm-hook/phase-1/unit-1/dev-report.md\n" \
  "Read" \
  "docs/pm-hook/phase-1/unit-1/dev-report.md"
assert_last_check_passes "delivery-owner hook non Write/Edit tool should skip explicitly"
assert_last_check_stdout_json "delivery-owner hook non Write/Edit should emit allow json" "allow"
assert_last_check_contains "delivery-owner hook non Write/Edit skip reason should be visible" 'skip: 当前工具不是 Write/Edit'

run_completion_check_with_raw_payload \
  "$PM_GATE_CHECK" \
  "$(jq -nc --arg cwd "$PM_HOOK_ROOT" --arg sid "session-pm-missing-file-path" --arg tp "$PM_HOOK_ROOT/transcript.log" '{cwd:$cwd, session_id:$sid, transcript_path:$tp, tool_name:"Write", tool_input:{}}')"
assert_last_check_fails_with "delivery-owner hook missing file_path should block explicitly" 'tool_input\.file_path|acceptance-summary\.md 收口写入'
assert_last_check_stdout_json "delivery-owner hook missing file_path should emit block json" "block"

PM_DRAFT_ROOT="$HOOK_FIXTURE_ROOT/delivery-owner-draft"
mkdir -p "$PM_DRAFT_ROOT/docs/pm-draft/phase-1/unit-1"
cat > "$PM_DRAFT_ROOT/docs/pm-draft/phase-1/unit-1/dev-report.md" <<'EOF'
# dev report
EOF
cat > "$PM_DRAFT_ROOT/docs/pm-draft/phase-1/acceptance-summary.md" <<'EOF'
# acceptance-summary draft
EOF
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_DRAFT_ROOT" \
  "session-pm-draft" \
  "docs/pm-draft/phase-1/unit-1/dev-report.md\ndocs/pm-draft/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-draft/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner acceptance draft should not silent skip" '交付完整性检查未通过|plan\.md 不存在|acceptance-summary\.md'
assert_last_check_stdout_json "delivery-owner acceptance draft should emit block json" "block"

FAKE_JQ_BIN="$(mktemp -d "${TMPDIR:-/tmp}/org-fake-jq.XXXXXX")"
cat > "$FAKE_JQ_BIN/jq" <<'EOF'
#!/usr/bin/env bash
exit 127
EOF
chmod +x "$FAKE_JQ_BIN/jq"
run_completion_check_with_raw_payload_and_path "$PM_GATE_CHECK" 'not-json' "$FAKE_JQ_BIN:/bin:/usr/bin"
assert_last_check_fails_with "delivery-owner hook missing jq should still block with protocol output" '缺少 jq|hook payload|初始化失败|不是有效 JSON'
assert_last_check_stdout_json "delivery-owner hook missing jq should still emit block json" "block"

COMMON_RETRY_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/org-common-retry.XXXXXX")"
cat > "$COMMON_RETRY_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$1"
SESSION="$2"
source "$ROOT/shared/hooks/lib/common.sh"
SESSION_ID="$SESSION"
FAILURES=""
add_failure "boom"
output_failures "demo-title" ""
EOF
chmod +x "$COMMON_RETRY_SCRIPT"
COMMON_RETRY_SESSION="session-common-retry"
rm -f "${TMPDIR:-/tmp}/claude_hook_${COMMON_RETRY_SESSION}_retry"
for run_idx in 1 2 3 4; do
  LAST_CHECK_STDOUT="$(mktemp "${TMPDIR:-/tmp}/org-hook-check.stdout.XXXXXX")"
  LAST_CHECK_STDERR="$(mktemp "${TMPDIR:-/tmp}/org-hook-check.stderr.XXXXXX")"
  LAST_CHECK_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/org-hook-check.XXXXXX")"
  if bash "$COMMON_RETRY_SCRIPT" "$ROOT" "$COMMON_RETRY_SESSION" >"$LAST_CHECK_STDOUT" 2>"$LAST_CHECK_STDERR"; then
    LAST_CHECK_STATUS=0
  else
    LAST_CHECK_STATUS=$?
  fi
  cat "$LAST_CHECK_STDOUT" "$LAST_CHECK_STDERR" >"$LAST_CHECK_OUTPUT"
  if [ "$run_idx" -eq 4 ]; then
    assert_last_check_fails_with "common output_failures should remain fail-close after repeated retries" 'demo-title|boom'
    assert_last_check_stdout_json "common output_failures repeated retries should still emit block json" "block"
  fi
done

PM_EVIDENCE_ROOT="$HOOK_FIXTURE_ROOT/delivery-owner-evidence"

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-noop-proving" "noop_proving_command" "noop_proving_command" "valid"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-noop-proving" \
  "docs/pm-noop-proving/phase-1/unit-1/dev-report.md\ndocs/pm-noop-proving/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-noop-proving/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner noop proving command should fail" 'D5\[unit-1\]: Task-1 proving_command.*空心命令|D5\[unit-1\]: Task-1 proving_command.*真实验证'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-unanchored-evidence" "unanchored_evidence_target" "unanchored_evidence_target" "valid"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-unanchored-evidence" \
  "docs/pm-unanchored-evidence/phase-1/unit-1/dev-report.md\ndocs/pm-unanchored-evidence/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-unanchored-evidence/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner unanchored evidence target should fail" 'D5\[unit-1\]: Task-1 evidence_target.*锚点|D5\[unit-1\]: Task-1 evidence_target.*#'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-drift-command" "valid" "drift_proving_command" "valid"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-drift-command" \
  "docs/pm-drift-command/phase-1/unit-1/dev-report.md\ndocs/pm-drift-command/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-drift-command/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner proving command drift should fail" 'D5\[unit-1\]: Task-1 proving_command 与 plan\.md 不一致'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-summary-only-output" "valid" "valid" "summary_only"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-summary-only-output" \
  "docs/pm-summary-only-output/phase-1/unit-1/dev-report.md\ndocs/pm-summary-only-output/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-summary-only-output/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner summary-only fresh output should fail" 'D5\[unit-1\]: Task-1 Fresh proving command.*完整输出|D5\[unit-1\]: Task-1 Fresh proving command.*摘要'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-missing-preflight" "valid" "valid" "valid" "preflight_missing"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-missing-preflight" \
  "docs/pm-missing-preflight/phase-1/unit-1/dev-report.md\ndocs/pm-missing-preflight/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-missing-preflight/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner missing preflight evidence should fail" 'D-PRE: .*preflight-evidence\.md'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-kickoff-missing-owner" "valid" "valid" "valid" "kickoff_missing_risk_owner"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-kickoff-missing-owner" \
  "docs/pm-kickoff-missing-owner/phase-1/unit-1/dev-report.md\ndocs/pm-kickoff-missing-owner/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-kickoff-missing-owner/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner kickoff ready without risk owner should fail" 'kickoff_status=READY.*risk_owner_ready|risk_owner_ready 必须为 yes'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-missing-goal-closure" "valid" "valid" "valid" "valid" "missing_goal_closure"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-missing-goal-closure" \
  "docs/pm-missing-goal-closure/phase-1/unit-1/dev-report.md\ndocs/pm-missing-goal-closure/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-missing-goal-closure/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner missing goal closure should fail" '缺少「目标闭环」章节|目标闭环'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-goal-unmet" "valid" "valid" "valid" "valid" "goal_unmet"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-goal-unmet" \
  "docs/pm-goal-unmet/phase-1/unit-1/dev-report.md\ndocs/pm-goal-unmet/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-goal-unmet/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner unmet goal should fail sign-off" '存在未达成目标时不得确认签收|目标闭环'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-goal-unmapped" "valid" "valid" "valid" "valid" "goal_unmapped"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-goal-unmapped" \
  "docs/pm-goal-unmapped/phase-1/unit-1/dev-report.md\ndocs/pm-goal-unmapped/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-goal-unmapped/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner unmapped goal should fail" 'goal_source_ref.*brief\.md#目标与成功标准.*prd\.md#阶段目标|行数与 brief/phase 目标数不一致|brief/phase 目标未完整承接'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-goal-duplicate-rows" "valid" "valid" "valid" "valid" "goal_duplicate_brief_rows"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-goal-duplicate-rows" \
  "docs/pm-goal-duplicate-rows/phase-1/unit-1/dev-report.md\ndocs/pm-goal-duplicate-rows/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-goal-duplicate-rows/phase-1/acceptance-summary.md"
assert_last_check_passes "delivery-owner duplicate rows for one upstream goal should pass"

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-goal-missing-second-same-count" "valid" "valid" "valid" "valid" "goal_missing_second_same_count"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-goal-missing-second-same-count" \
  "docs/pm-goal-missing-second-same-count/phase-1/unit-1/dev-report.md\ndocs/pm-goal-missing-second-same-count/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-goal-missing-second-same-count/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner should reject duplicate rows masking missing second goal" 'brief 目标未完整承接|目标闭环.*二次校验完成|目标闭环.*未完整承接'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-goal-missing-source-ref" "valid" "valid" "valid" "valid" "goal_missing_source_ref"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-goal-missing-source-ref" \
  "docs/pm-goal-missing-source-ref/phase-1/unit-1/dev-report.md\ndocs/pm-goal-missing-source-ref/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-goal-missing-source-ref/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner missing goal_source_ref should fail" 'goal_source_ref'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-goal-invalid-source-ref" "valid" "valid" "valid" "valid" "goal_invalid_source_ref"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-goal-invalid-source-ref" \
  "docs/pm-goal-invalid-source-ref/phase-1/unit-1/dev-report.md\ndocs/pm-goal-invalid-source-ref/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-goal-invalid-source-ref/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner invalid goal_source_ref should fail" 'goal_source_ref.*brief\.md#目标与成功标准.*prd\.md#阶段目标'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-goal-missing-execution-basis-ref" "valid" "valid" "valid" "valid" "goal_missing_execution_basis_ref"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-goal-missing-execution-basis-ref" \
  "docs/pm-goal-missing-execution-basis-ref/phase-1/unit-1/dev-report.md\ndocs/pm-goal-missing-execution-basis-ref/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-goal-missing-execution-basis-ref/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner missing execution_basis_ref should fail" 'execution_basis_ref'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-goal-invalid-execution-basis-ref" "valid" "valid" "valid" "valid" "goal_invalid_execution_basis_ref"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-goal-invalid-execution-basis-ref" \
  "docs/pm-goal-invalid-execution-basis-ref/phase-1/unit-1/dev-report.md\ndocs/pm-goal-invalid-execution-basis-ref/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-goal-invalid-execution-basis-ref/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner invalid execution_basis_ref should fail" 'execution_basis_ref.*design\.md.*plan\.md.*test-cases\.md'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-goal-missing-second" "valid" "valid" "valid" "valid" "goal_missing_second"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-goal-missing-second" \
  "docs/pm-goal-missing-second/phase-1/unit-1/dev-report.md\ndocs/pm-goal-missing-second/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-goal-missing-second/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner goal closure must cover every upstream goal" '行数与 brief/phase 目标数不一致|brief 目标未完整承接|phase 目标未完整承接'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-missing-developer-ref" "valid" "valid" "valid" "valid" "valid" "missing_developer_report_ref"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-missing-developer-ref" \
  "docs/pm-missing-developer-ref/phase-1/unit-1/dev-report.md\ndocs/pm-missing-developer-ref/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-missing-developer-ref/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner missing developer report ref should fail" 'developer_report_ref'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-invalid-developer-anchor" "valid" "valid" "valid"
perl -0pi -e 's/developer-report-Task-1\.md#reviewable-anchor/developer-report-Task-1.md#missing-reviewable-anchor/' "$PM_EVIDENCE_ROOT/docs/pm-invalid-developer-anchor/phase-1/unit-1/dev-report.md"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-invalid-developer-anchor" \
  "docs/pm-invalid-developer-anchor/phase-1/unit-1/dev-report.md\ndocs/pm-invalid-developer-anchor/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-invalid-developer-anchor/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner invalid developer_report_ref anchor should fail" 'developer_report_ref.*锚点不存在'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-invalid-evidence-anchor" "valid" "valid" "valid"
perl -0pi -e 's/- evidence_target: dev-report\.md#task-1 \+ qa-report\.md#qa_a-unit-1 \+ acceptance-summary\.md#质量门禁/- evidence_target: dev-report.md#task-1 + qa-report.md#missing-qa-anchor + acceptance-summary.md#质量门禁/' "$PM_EVIDENCE_ROOT/docs/pm-invalid-evidence-anchor/phase-1/unit-1/dev-report.md"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-invalid-evidence-anchor" \
  "docs/pm-invalid-evidence-anchor/phase-1/unit-1/dev-report.md\ndocs/pm-invalid-evidence-anchor/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-invalid-evidence-anchor/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner invalid evidence_target anchor should fail" 'evidence_target.*锚点不存在'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-invalid-preflight-anchor" "valid" "valid" "valid"
perl -0pi -e 's/preflight-evidence\.md#preflight-con-001/preflight-evidence.md#missing-preflight-anchor/' "$PM_EVIDENCE_ROOT/docs/pm-invalid-preflight-anchor/phase-1/acceptance-summary.md"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-invalid-preflight-anchor" \
  "docs/pm-invalid-preflight-anchor/phase-1/unit-1/dev-report.md\ndocs/pm-invalid-preflight-anchor/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-invalid-preflight-anchor/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner invalid preflight evidence anchor should fail" 'preflight_evidence_ref.*锚点不存在'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-fix-rounds" "valid" "valid" "valid"
cat > "$PM_EVIDENCE_ROOT/docs/pm-fix-rounds/phase-1/fix-1.md" <<'EOF'
# fix-1
EOF
cat >> "$PM_EVIDENCE_ROOT/docs/pm-fix-rounds/phase-1/code-review-report.md" <<'EOF'

## 审查轮次记录
| 轮次 | 结论 | 说明 |
|------|------|------|
| R1 | FAIL | 修复后待复审 |
EOF
cat >> "$PM_EVIDENCE_ROOT/docs/pm-fix-rounds/phase-1/qa-report.md" <<'EOF'

## 审查轮次记录
| 轮次 | 结论 | 说明 |
|------|------|------|
| R1 | FAIL | 修复后待复审 |
EOF
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-fix-rounds" \
  "docs/pm-fix-rounds/phase-1/unit-1/dev-report.md\ndocs/pm-fix-rounds/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-fix-rounds/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner fix reports must require re-review rounds" 'D15: \[code-review-report\]|D15: \[qa-report\]'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-stale-proof-after-fix" "valid" "valid" "valid" "valid" "valid" "valid" "n_a" "stale_after_fix"
cat > "$PM_EVIDENCE_ROOT/docs/pm-stale-proof-after-fix/phase-1/fix-1.md" <<'EOF'
# fix-1
EOF
touch -t 202604111100 "$PM_EVIDENCE_ROOT/docs/pm-stale-proof-after-fix/phase-1/fix-1.md"
cat >> "$PM_EVIDENCE_ROOT/docs/pm-stale-proof-after-fix/phase-1/code-review-report.md" <<'EOF'

## 审查轮次记录
| 轮次 | 结论 | 说明 |
|------|------|------|
| R1 | FAIL | 修复前 |
| R2 | PASS | 修复后复审 |
EOF
cat >> "$PM_EVIDENCE_ROOT/docs/pm-stale-proof-after-fix/phase-1/qa-report.md" <<'EOF'

## 审查轮次记录
| 轮次 | 结论 | 说明 |
|------|------|------|
| R1 | FAIL | 修复前 |
| R2 | PASS | 修复后复审 |
EOF
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-stale-proof-after-fix" \
  "docs/pm-stale-proof-after-fix/phase-1/unit-1/dev-report.md\ndocs/pm-stale-proof-after-fix/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-stale-proof-after-fix/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner stale proving or test evidence after fix should fail" 'proving_command_executed_at 早于最近 fix 报告|TEST_EXECUTED_AT 早于最近 fix 报告'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-reround-without-fix" "valid" "valid" "valid"
cat >> "$PM_EVIDENCE_ROOT/docs/pm-reround-without-fix/phase-1/code-review-report.md" <<'EOF'

## 审查轮次记录
| 轮次 | 结论 | 说明 |
|------|------|------|
| R1 | FAIL | 修复前 |
| R2 | PASS | 修复后复审 |
EOF
cat >> "$PM_EVIDENCE_ROOT/docs/pm-reround-without-fix/phase-1/qa-report.md" <<'EOF'

## 审查轮次记录
| 轮次 | 结论 | 说明 |
|------|------|------|
| R1 | FAIL | 修复前 |
| R2 | PASS | 修复后复审 |
EOF
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-reround-without-fix" \
  "docs/pm-reround-without-fix/phase-1/unit-1/dev-report.md\ndocs/pm-reround-without-fix/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-reround-without-fix/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner re-review without fix artifact should fail" '缺少 fix-N\.md|已发生复审'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-triggered-summaries-valid" "valid" "valid" "valid" "valid" "valid" "valid" "status_triggered_with_file"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-triggered-summaries-valid" \
  "docs/pm-triggered-summaries-valid/phase-1/unit-1/dev-report.md\ndocs/pm-triggered-summaries-valid/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-triggered-summaries-valid/phase-1/acceptance-summary.md"
assert_last_check_passes "delivery-owner triggered summaries with real parallel batch should pass"
assert_last_check_stdout_json "delivery-owner passing closeout should emit allow json" "allow"

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-missing-runtime-summary" "valid" "valid" "valid"
perl -0pi -e 's/^- last_observed_at:.*\n//m' "$PM_EVIDENCE_ROOT/docs/pm-missing-runtime-summary/phase-1/acceptance-summary.md"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-missing-runtime-summary" \
  "docs/pm-missing-runtime-summary/phase-1/unit-1/dev-report.md\ndocs/pm-missing-runtime-summary/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-missing-runtime-summary/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner missing latest runtime summary should fail" '最新状态摘要|last_observed_at'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-parallel-missing-plan-version-ref" "valid" "valid" "valid" "valid" "valid" "valid" "status_triggered_with_file"
perl -0pi -e 's/^- plan_version_ref:.*\n//m' "$PM_EVIDENCE_ROOT/docs/pm-parallel-missing-plan-version-ref/phase-1/unit-1/dev-report.md"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-parallel-missing-plan-version-ref" \
  "docs/pm-parallel-missing-plan-version-ref/phase-1/unit-1/dev-report.md\ndocs/pm-parallel-missing-plan-version-ref/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-parallel-missing-plan-version-ref/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner parallel dispatch without plan version ref should fail" 'plan_version_ref'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-drift-missed-escalation" "valid" "valid" "valid" "valid" "valid" "valid" "status_triggered_with_file"
perl -0pi -e 's/- deviation_trigger: NONE/- deviation_trigger: INTERFACE_BREAK/' "$PM_EVIDENCE_ROOT/docs/pm-drift-missed-escalation/phase-1/unit-1/dev-report.md"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-drift-missed-escalation" \
  "docs/pm-drift-missed-escalation/phase-1/unit-1/dev-report.md\ndocs/pm-drift-missed-escalation/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-drift-missed-escalation/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner high-risk drift without escalation should fail" 'D5\[unit-1\]: Task-1 命中高风险 deviation_trigger=INTERFACE_BREAK 时，control_action 不能为 CONTINUE'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-drift-escalated" "valid" "valid" "valid" "valid" "valid" "valid" "status_triggered_with_file"
perl -0pi -e 's/- deviation_trigger: NONE/- deviation_trigger: INTERFACE_BREAK/' "$PM_EVIDENCE_ROOT/docs/pm-drift-escalated/phase-1/unit-1/dev-report.md"
perl -0pi -e 's/- control_action: CONTINUE/- control_action: ESCALATE/' "$PM_EVIDENCE_ROOT/docs/pm-drift-escalated/phase-1/unit-1/dev-report.md"
perl -0pi -e 's/- next_action: WAIT_BATCH/- next_action: ESCALATE/' "$PM_EVIDENCE_ROOT/docs/pm-drift-escalated/phase-1/unit-1/dev-report.md"
perl -0pi -e 's/\| QA_B（E2E 旅程） \| N\/A \| 0 \| na \|/\| QA_B（E2E 旅程） \| OK \| 0 \| drift escalation ok \|/' "$PM_EVIDENCE_ROOT/docs/pm-drift-escalated/phase-1/qa-report.md"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-drift-escalated" \
  "docs/pm-drift-escalated/phase-1/unit-1/dev-report.md\ndocs/pm-drift-escalated/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-drift-escalated/phase-1/acceptance-summary.md"
assert_last_check_passes "delivery-owner high-risk drift with escalation should pass"

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-replan-missing-closure" "valid" "valid" "valid" "valid" "valid" "valid" "n_a"
perl -0pi -e 's/- control_action: CONTINUE/- control_action: REPLAN/' "$PM_EVIDENCE_ROOT/docs/pm-replan-missing-closure/phase-1/unit-1/dev-report.md"
perl -0pi -e 's/- next_action: REQUEST_REVIEW/- next_action: REPLAN_REQUEST/' "$PM_EVIDENCE_ROOT/docs/pm-replan-missing-closure/phase-1/unit-1/dev-report.md"
perl -0pi -e 's/- active_blocker: 无/- active_blocker: REPLAN 处理中，等待新计划版本/' "$PM_EVIDENCE_ROOT/docs/pm-replan-missing-closure/phase-1/unit-1/dev-report.md"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-replan-missing-closure" \
  "docs/pm-replan-missing-closure/phase-1/unit-1/dev-report.md\ndocs/pm-replan-missing-closure/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-replan-missing-closure/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner replan without recovery fields should fail" 'D6\[unit-1\]: 命中 REPLAN 时，必须记录 replan_request|D6\[unit-1\]: 命中 REPLAN 时，必须记录 batch_freeze_reason|D6\[unit-1\]: 命中 REPLAN 时，必须记录 unlock_resolution'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-replan-recovery" "valid" "valid" "valid" "valid" "valid" "valid" "status_triggered_with_file"
perl -0pi -e 's/- deviation_trigger: NONE/- deviation_trigger: INTERFACE_BREAK/' "$PM_EVIDENCE_ROOT/docs/pm-replan-recovery/phase-1/unit-1/dev-report.md"
perl -0pi -e 's/- control_action: CONTINUE/- control_action: REPLAN/' "$PM_EVIDENCE_ROOT/docs/pm-replan-recovery/phase-1/unit-1/dev-report.md"
perl -0pi -e 's/- next_action: WAIT_BATCH/- next_action: REPLAN_REQUEST/' "$PM_EVIDENCE_ROOT/docs/pm-replan-recovery/phase-1/unit-1/dev-report.md"
perl -0pi -e 's/- active_blocker: 无/- active_blocker: REPLAN 处理中，等待新计划版本/' "$PM_EVIDENCE_ROOT/docs/pm-replan-recovery/phase-1/unit-1/dev-report.md"
perl -0pi -e 's/- blocker_owner: 无/- blocker_owner: delivery-owner/' "$PM_EVIDENCE_ROOT/docs/pm-replan-recovery/phase-1/unit-1/dev-report.md"
perl -0pi -e 's/- replan_request: 无/- replan_request: plan.md#计划修订记录/' "$PM_EVIDENCE_ROOT/docs/pm-replan-recovery/phase-1/unit-1/dev-report.md"
perl -0pi -e 's/- batch_freeze_reason: 无/- batch_freeze_reason: Batch-1 在 REPLAN 前冻结，避免沿旧版本继续推进/' "$PM_EVIDENCE_ROOT/docs/pm-replan-recovery/phase-1/unit-1/dev-report.md"
perl -0pi -e 's/- unlock_resolution: 无/- unlock_resolution: 仅允许 Task-1 以 v2 作为新的解锁基线/' "$PM_EVIDENCE_ROOT/docs/pm-replan-recovery/phase-1/unit-1/dev-report.md"
perl -0pi -e 's/- plan_version_value: v1/- plan_version_value: v2/' "$PM_EVIDENCE_ROOT/docs/pm-replan-recovery/phase-1/unit-1/dev-report.md"
perl -0pi -e 's/- plan_version: v1/- plan_version: v2/' "$PM_EVIDENCE_ROOT/docs/pm-replan-recovery/phase-1/plan.md"
perl -0pi -e 's/\| v1 \| 初版计划 \| 首次输出当前解锁批次 \| 是 \|/\| v2 \| REPLAN 恢复后版本 \| 刷新当前解锁基线 \| 是 \|/' "$PM_EVIDENCE_ROOT/docs/pm-replan-recovery/phase-1/plan.md"
perl -0pi -e 's/\| QA_B（E2E 旅程） \| N\/A \| 0 \| na \|/\| QA_B（E2E 旅程） \| OK \| 0 \| replan e2e ok \|/' "$PM_EVIDENCE_ROOT/docs/pm-replan-recovery/phase-1/qa-report.md"
perl -0pi -e 's/plan_version_value: v1/plan_version_value: v2/g' "$PM_EVIDENCE_ROOT/docs/pm-replan-recovery/phase-1/qa-report.md"
perl -0pi -e 's/current_plan_version_value: v1/current_plan_version_value: v2/' "$PM_EVIDENCE_ROOT/docs/pm-replan-recovery/phase-1/acceptance-summary.md"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-replan-recovery" \
  "docs/pm-replan-recovery/phase-1/unit-1/dev-report.md\ndocs/pm-replan-recovery/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-replan-recovery/phase-1/acceptance-summary.md"
assert_last_check_passes "delivery-owner replan recovery with refreshed plan version should pass"

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-empty-blocked-section" "valid" "valid" "valid"
perl -0pi -e 's@(### Task-scope 对照表)@### BLOCKED 任务\n| Task | 原因 | worktree 保留 |\n|------|------|--------------|\n\n### Task 执行进度\n| Task | 预标复杂度 | 实际复杂度 | 预期轮次 | 实际轮次 | 偏差触发器 | 控制动作 | 状态 |\n|------|-----------|-----------|---------|---------|-----------|----------|------|\n| Task-1 | L | L | 1 | 1 | NONE | CONTINUE | DONE |\n\n$1@' "$PM_EVIDENCE_ROOT/docs/pm-empty-blocked-section/phase-1/unit-1/dev-report.md"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-empty-blocked-section" \
  "docs/pm-empty-blocked-section/phase-1/unit-1/dev-report.md\ndocs/pm-empty-blocked-section/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-empty-blocked-section/phase-1/acceptance-summary.md"
assert_last_check_passes "delivery-owner empty BLOCKED section should not misparse task progress as blocked"
assert_last_check_stdout_json "delivery-owner empty BLOCKED section should still emit allow json" "allow"

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-triggered-without-parallel-batch" "valid" "valid" "valid" "valid" "valid" "valid" "triggered_without_parallel_batch"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-triggered-without-parallel-batch" \
  "docs/pm-triggered-without-parallel-batch/phase-1/unit-1/dev-report.md\ndocs/pm-triggered-without-parallel-batch/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-triggered-without-parallel-batch/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner should reject triggered summaries without real parallel batch" '未满足触发条件|并行 Task 数 < 4'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-missing-status-summary" "valid" "valid" "valid" "valid" "valid" "valid" "status_triggered_missing_file"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-missing-status-summary" \
  "docs/pm-missing-status-summary/phase-1/unit-1/dev-report.md\ndocs/pm-missing-status-summary/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-missing-status-summary/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner triggered status summary must exist" 'delivery-status-summary\.md|Status Synthesis Agent'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-missing-evidence-summary" "valid" "valid" "valid" "valid" "valid" "valid" "evidence_triggered_missing_file"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-missing-evidence-summary" \
  "docs/pm-missing-evidence-summary/phase-1/unit-1/dev-report.md\ndocs/pm-missing-evidence-summary/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-missing-evidence-summary/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner triggered evidence summary must exist" 'evidence-summary\.md|Evidence Synthesis Agent'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-status-summary-stale" "valid" "valid" "valid" "valid" "valid" "valid" "status_stale_with_file"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-status-summary-stale" \
  "docs/pm-status-summary-stale/phase-1/unit-1/dev-report.md\ndocs/pm-status-summary-stale/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-status-summary-stale/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner should reject stale synthesis summaries" '不得为 STALE|STALE'

create_project_manager_fixture "$PM_EVIDENCE_ROOT" "pm-evidence-without-status" "valid" "valid" "valid" "valid" "valid" "valid" "evidence_without_status"
run_completion_check_with_payload \
  "$PM_GATE_CHECK" \
  "$PM_EVIDENCE_ROOT" \
  "session-pm-evidence-without-status" \
  "docs/pm-evidence-without-status/phase-1/unit-1/dev-report.md\ndocs/pm-evidence-without-status/phase-1/acceptance-summary.md\n" \
  "Edit" \
  "docs/pm-evidence-without-status/phase-1/acceptance-summary.md"
assert_last_check_fails_with "delivery-owner should enforce synthesis sequence" 'Status Synthesis Agent 的 TRIGGERED 记录|delivery-status-summary\.md'

TEST_DESIGN_BROWSER_ROOT="$HOOK_FIXTURE_ROOT/test-design-browser"

create_test_design_browser_fixture "$TEST_DESIGN_BROWSER_ROOT" "td-browser-valid" "valid"
run_completion_check_with_payload \
  "$TEST_DESIGN_CHECK" \
  "$TEST_DESIGN_BROWSER_ROOT" \
  "session-td-browser-valid" \
  "docs/td-browser-valid/phase-1/unit-1/test-cases.md\n" \
  "Write" \
  "docs/td-browser-valid/phase-1/unit-1/test-cases.md"
assert_last_check_passes "test-design handoff with browser execution_mode should pass"

create_test_design_browser_fixture "$TEST_DESIGN_BROWSER_ROOT" "td-browser-missing-mode" "missing_execution_mode"
run_completion_check_with_payload \
  "$TEST_DESIGN_CHECK" \
  "$TEST_DESIGN_BROWSER_ROOT" \
  "session-td-browser-missing-mode" \
  "docs/td-browser-missing-mode/phase-1/unit-1/test-cases.md\n" \
  "Write" \
  "docs/td-browser-missing-mode/phase-1/unit-1/test-cases.md"
assert_last_check_fails_with "test-design handoff must require execution_mode" 'execution_mode|占位字段'

create_test_design_browser_fixture "$TEST_DESIGN_BROWSER_ROOT" "td-browser-wrong-mode" "browser_signal_non_browser"
run_completion_check_with_payload \
  "$TEST_DESIGN_CHECK" \
  "$TEST_DESIGN_BROWSER_ROOT" \
  "session-td-browser-wrong-mode" \
  "docs/td-browser-wrong-mode/phase-1/unit-1/test-cases.md\n" \
  "Write" \
  "docs/td-browser-wrong-mode/phase-1/unit-1/test-cases.md"
assert_last_check_fails_with "test-design browser scenarios must be marked browser_required" 'browser_required'

create_test_design_browser_fixture "$TEST_DESIGN_BROWSER_ROOT" "td-browser-ux-template" "ux_template_non_browser"
run_completion_check_with_payload \
  "$TEST_DESIGN_CHECK" \
  "$TEST_DESIGN_BROWSER_ROOT" \
  "session-td-browser-ux-template" \
  "docs/td-browser-ux-template/phase-1/unit-1/test-cases.md\n" \
  "Write" \
  "docs/td-browser-ux-template/phase-1/unit-1/test-cases.md"
assert_last_check_fails_with "test-design template-style UX and recovery signals must be browser_required" 'browser_required'

QA_VALID_ROOT="$HOOK_FIXTURE_ROOT/qa-valid"
mkdir -p "$QA_VALID_ROOT/docs/qa-valid/phase-1"
cat > "$QA_VALID_ROOT/docs/qa-valid/phase-1/plan.md" <<'EOF'
## 计划版本
- plan_version: v1
- 版本说明: QA 夹具当前消费的唯一执行基线
EOF
cat > "$QA_VALID_ROOT/docs/qa-valid/phase-1/qa-report.md" <<'EOF'
审查分级: 标准
执行范围: 验证-A
plan_version_ref: plan.md#计划版本
plan_version_value: v1
release_recommendation: 放行
residual_risk: 低，剩余风险已被现有回归与上线监控覆盖
uncovered_boundary: 无
conditional_release_basis: 无
issue_ledger_anchor: qa-report.md#fail-details

## 验收汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | OK | 0 | AC 验收通过 |
| QA_B（E2E 旅程） | N/A | 0 | scope=验证-A，本轮未执行 |
| QA_C（回归验证） | N/A | 0 | scope=验证-A，本轮未执行 |
| QA_D（探索性测试） | N/A | 0 | scope=验证-A，本轮未执行 |

## 非执行项记录
| stage_or_obligation | not_executed_reason |
|---------------------|---------------------|
| QA_B | scope=验证-A，本轮未执行 |
| QA_C | scope=验证-A，本轮未执行 |
| QA_D | scope=验证-A，本轮未执行 |

## 已排除潜在问题
| # | 潜在问题 | 排除依据 | 证据 |
|---|---------|---------|------|
| 1 | 边界输入可能破坏约束 | 反例与边界均已执行 | evidence-1 |
| 2 | AC 与用例映射可能漂移 | AC 追踪表已核对 | evidence-2 |

## FAIL 详情
| Issue ID | 阶段 | severity | priority | impact_scope | user_impact | environment_or_build | regression_flag | temporary_workaround | owner_hint | 期望行为 | 实际行为 | 复现命令 |
|----------|------|----------|----------|--------------|-------------|----------------------|-----------------|----------------------|------------|---------|---------|---------|

RESULT: PASS
EOF
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_VALID_ROOT" \
  "session-qa-valid" \
  "docs/qa-valid/phase-1/qa-report.md\n"
assert_last_check_passes "qa scoped report with release evidence should pass"

cp -R "$QA_VALID_ROOT/docs/qa-valid" "$QA_VALID_ROOT/docs/qa-invalid-plan-anchor"
perl -0pi -e 's/## 计划版本/## 计划版本-旧/' "$QA_VALID_ROOT/docs/qa-invalid-plan-anchor/phase-1/plan.md"
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_VALID_ROOT" \
  "session-qa-invalid-plan-anchor" \
  "docs/qa-invalid-plan-anchor/phase-1/qa-report.md\n"
assert_last_check_fails_with "qa report plan_version_ref invalid anchor should fail" 'plan_version_ref.*锚点不存在'

cp -R "$QA_VALID_ROOT/docs/qa-valid" "$QA_VALID_ROOT/docs/qa-invalid-issue-ledger-anchor"
perl -0pi -e 's/## FAIL 详情/## FAIL 详情-旧/' "$QA_VALID_ROOT/docs/qa-invalid-issue-ledger-anchor/phase-1/qa-report.md"
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_VALID_ROOT" \
  "session-qa-invalid-issue-ledger-anchor" \
  "docs/qa-invalid-issue-ledger-anchor/phase-1/qa-report.md\n"
assert_last_check_fails_with "qa report invalid issue ledger anchor should fail" 'issue_ledger_anchor.*锚点不存在'

cp -R "$QA_VALID_ROOT/docs/qa-valid" "$QA_VALID_ROOT/docs/qa-invalid-issue-ledger-target"
perl -0pi -e 's/issue_ledger_anchor: qa-report\.md#fail-details/issue_ledger_anchor: qa-report.md#验收汇总/' "$QA_VALID_ROOT/docs/qa-invalid-issue-ledger-target/phase-1/qa-report.md"
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_VALID_ROOT" \
  "session-qa-invalid-issue-ledger-target" \
  "docs/qa-invalid-issue-ledger-target/phase-1/qa-report.md\n"
assert_last_check_fails_with "qa report wrong issue ledger target should fail" 'issue_ledger_anchor.*qa-report\.md#fail-details'

QA_BROWSER_ROOT="$HOOK_FIXTURE_ROOT/qa-browser"

create_qa_browser_fixture "$QA_BROWSER_ROOT" "qa-browser-valid" "valid"
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_BROWSER_ROOT" \
  "session-qa-browser-valid" \
  "docs/qa-browser-valid/phase-1/qa-report.md\n"
assert_last_check_passes "qa browser_required report with browser evidence should pass"

create_qa_browser_fixture "$QA_BROWSER_ROOT" "qa-browser-missing-evidence" "missing_browser_evidence"
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_BROWSER_ROOT" \
  "session-qa-browser-missing-evidence" \
  "docs/qa-browser-missing-evidence/phase-1/qa-report.md\n"
assert_last_check_fails_with "qa browser_required report must include browser evidence" 'browser_evidence|浏览器证据'

create_qa_browser_fixture "$QA_BROWSER_ROOT" "qa-browser-api-only" "api_only_browser_evidence"
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_BROWSER_ROOT" \
  "session-qa-browser-api-only" \
  "docs/qa-browser-api-only/phase-1/qa-report.md\n"
assert_last_check_fails_with "qa browser_required report cannot use api-only evidence" 'browser_evidence|浏览器证据|API'

create_qa_browser_fixture "$QA_BROWSER_ROOT" "qa-browser-placeholder-evidence" "placeholder_browser_evidence"
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_BROWSER_ROOT" \
  "session-qa-browser-placeholder-evidence" \
  "docs/qa-browser-placeholder-evidence/phase-1/qa-report.md\n"
assert_last_check_fails_with "qa browser_required report cannot accept placeholder browser evidence" 'browser_evidence|浏览器证据'

create_qa_browser_fixture "$QA_BROWSER_ROOT" "qa-browser-empty-journey" "empty_journey_body"
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_BROWSER_ROOT" \
  "session-qa-browser-empty-journey" \
  "docs/qa-browser-empty-journey/phase-1/qa-report.md\n"
assert_last_check_fails_with "qa browser_required report must include journey body" '旅程设计|旅程执行|数据流转'

create_qa_browser_fixture "$QA_BROWSER_ROOT" "qa-browser-unreferenced" "unreferenced_browser_required"
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_BROWSER_ROOT" \
  "session-qa-browser-unreferenced" \
  "docs/qa-browser-unreferenced/phase-1/qa-report.md\n"
assert_last_check_passes "qa hook should only honor browser_required from referenced test_cases_refs"

QA_SCOPE_ROOT="$HOOK_FIXTURE_ROOT/qa-scope"
mkdir -p "$QA_SCOPE_ROOT/docs/qa-scope/phase-1"
cat > "$QA_SCOPE_ROOT/docs/qa-scope/phase-1/plan.md" <<'EOF'
## 计划版本
- plan_version: v1
- 版本说明: QA 夹具当前消费的唯一执行基线
EOF
cat > "$QA_SCOPE_ROOT/docs/qa-scope/phase-1/qa-report.md" <<'EOF'
审查分级: 标准
执行范围: full
plan_version_ref: plan.md#计划版本
plan_version_value: v1
release_recommendation: 放行
residual_risk: 低
uncovered_boundary: 无
conditional_release_basis: 无
issue_ledger_anchor: qa-report.md#fail-details

## 验收汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | OK | 0 | ok |
| QA_B（E2E 旅程） | N/A | 0 | invalid for full |
| QA_C（回归验证） | OK | 0 | ok |
| QA_D（探索性测试） | N/A | 0 | invalid for full |

## 非执行项记录
| stage_or_obligation | not_executed_reason |
|---------------------|---------------------|
| QA_B | invalid for full |
| QA_D | invalid for full |

## 已排除潜在问题
| # | 潜在问题 | 排除依据 | 证据 |
|---|---------|---------|------|
| 1 | p1 | reason | evidence |
| 2 | p2 | reason | evidence |

## FAIL 详情
| Issue ID | 阶段 | severity | priority | impact_scope | user_impact | environment_or_build | regression_flag | temporary_workaround | owner_hint | 期望行为 | 实际行为 | 复现命令 |
|----------|------|----------|----------|--------------|-------------|----------------------|-----------------|----------------------|------------|---------|---------|---------|

RESULT: PASS
EOF
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_SCOPE_ROOT" \
  "session-qa-scope" \
  "docs/qa-scope/phase-1/qa-report.md\n"
assert_last_check_fails_with "qa full scope cannot contain N/A" '执行范围=full 时，QA_A/QA_B/QA_C/QA_D 均不得为 N/A'

QA_MISSING_RELEASE_ROOT="$HOOK_FIXTURE_ROOT/qa-missing-release"
mkdir -p "$QA_MISSING_RELEASE_ROOT/docs/qa-missing-release/phase-1"
cat > "$QA_MISSING_RELEASE_ROOT/docs/qa-missing-release/phase-1/plan.md" <<'EOF'
## 计划版本
- plan_version: v1
- 版本说明: QA 夹具当前消费的唯一执行基线
EOF
cat > "$QA_MISSING_RELEASE_ROOT/docs/qa-missing-release/phase-1/qa-report.md" <<'EOF'
审查分级: 标准
执行范围: 验证-A
plan_version_ref: plan.md#计划版本
plan_version_value: v1
residual_risk: 中，需要继续关注修复回归
uncovered_boundary: 登录失败路径仍未收敛
conditional_release_basis: 无
issue_ledger_anchor: qa-report.md#fail-details

## 验收汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | ISSUE | 1 | failed |
| QA_B（E2E 旅程） | N/A | 0 | scope=验证-A，本轮未执行 |
| QA_C（回归验证） | N/A | 0 | scope=验证-A，本轮未执行 |
| QA_D（探索性测试） | N/A | 0 | scope=验证-A，本轮未执行 |

## 非执行项记录
| stage_or_obligation | not_executed_reason |
|---------------------|---------------------|
| QA_B | scope=验证-A，本轮未执行 |
| QA_C | scope=验证-A，本轮未执行 |
| QA_D | scope=验证-A，本轮未执行 |

## FAIL 详情
| Issue ID | 阶段 | severity | priority | impact_scope | user_impact | environment_or_build | regression_flag | temporary_workaround | owner_hint | 期望行为 | 实际行为 | 复现命令 |
|----------|------|----------|----------|--------------|-------------|----------------------|-----------------|----------------------|------------|---------|---------|---------|
| QAR-001 | QA_A | S1 | P0 | 核心提测路径 | 用户无法完成提测验收 | build-2026-04-11 | yes | 无 | developer | a | b | c |

## 已排除潜在问题
| # | 潜在问题 | 排除依据 | 证据 |
|---|---------|---------|------|
| 1 | p1 | reason | evidence |
| 2 | p2 | reason | evidence |

RESULT: FAIL
EOF
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_MISSING_RELEASE_ROOT" \
  "session-qa-missing-release" \
  "docs/qa-missing-release/phase-1/qa-report.md\n"
assert_last_check_fails_with "qa report must require release recommendation" 'release_recommendation'

QA_RESULT_ROOT="$HOOK_FIXTURE_ROOT/qa-result"
mkdir -p "$QA_RESULT_ROOT/docs/qa-result/phase-1"
cat > "$QA_RESULT_ROOT/docs/qa-result/phase-1/plan.md" <<'EOF'
## 计划版本
- plan_version: v1
- 版本说明: QA 夹具当前消费的唯一执行基线
EOF
cat > "$QA_RESULT_ROOT/docs/qa-result/phase-1/qa-report.md" <<'EOF'
审查分级: 标准
执行范围: 验证-A
plan_version_ref: plan.md#计划版本
plan_version_value: v1
release_recommendation: 阻塞
residual_risk: 高，当前缺陷阻断放行
uncovered_boundary: 登录失败路径阻断主流程
conditional_release_basis: 无
issue_ledger_anchor: qa-report.md#fail-details

## 验收汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | ISSUE | 1 | failed |
| QA_B（E2E 旅程） | N/A | 0 | scope=验证-A，本轮未执行 |
| QA_C（回归验证） | N/A | 0 | scope=验证-A，本轮未执行 |
| QA_D（探索性测试） | N/A | 0 | scope=验证-A，本轮未执行 |

## 非执行项记录
| stage_or_obligation | not_executed_reason |
|---------------------|---------------------|
| QA_B | scope=验证-A，本轮未执行 |
| QA_C | scope=验证-A，本轮未执行 |
| QA_D | scope=验证-A，本轮未执行 |

## 已排除潜在问题
| # | 潜在问题 | 排除依据 | 证据 |
|---|---------|---------|------|
| 1 | p1 | reason | evidence |
| 2 | p2 | reason | evidence |

## FAIL 详情
| Issue ID | 阶段 | 期望行为 | 实际行为 | 复现命令 |
|----------|------|---------|---------|---------|
| QAR-001 | QA_A | a | b | c |

RESULT: FAIL
EOF
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_RESULT_ROOT" \
  "session-qa-result" \
  "docs/qa-result/phase-1/qa-report.md\n"
assert_last_check_fails_with "qa fail details must include triage fields" 'severity|priority|impact_scope|user_impact'

QA_NOT_EXECUTED_ROOT="$HOOK_FIXTURE_ROOT/qa-not-executed"
mkdir -p "$QA_NOT_EXECUTED_ROOT/docs/qa-not-executed/phase-1"
cat > "$QA_NOT_EXECUTED_ROOT/docs/qa-not-executed/phase-1/plan.md" <<'EOF'
## 计划版本
- plan_version: v1
- 版本说明: QA 夹具当前消费的唯一执行基线
EOF
cat > "$QA_NOT_EXECUTED_ROOT/docs/qa-not-executed/phase-1/qa-report.md" <<'EOF'
审查分级: 标准
执行范围: 验证-A
plan_version_ref: plan.md#计划版本
plan_version_value: v1
release_recommendation: 放行
residual_risk: 低
uncovered_boundary: 无
conditional_release_basis: 无
issue_ledger_anchor: qa-report.md#fail-details

## 验收汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | OK | 0 | passed |
| QA_B（E2E 旅程） | N/A | 0 | na |
| QA_C（回归验证） | N/A | 0 | na |
| QA_D（探索性测试） | N/A | 0 | na |

## 已排除潜在问题
| # | 潜在问题 | 排除依据 | 证据 |
|---|---------|---------|------|
| 1 | p1 | reason | evidence |
| 2 | p2 | reason | evidence |

## FAIL 详情
| Issue ID | 阶段 | severity | priority | impact_scope | user_impact | environment_or_build | regression_flag | temporary_workaround | owner_hint | 期望行为 | 实际行为 | 复现命令 |
|----------|------|----------|----------|--------------|-------------|----------------------|-----------------|----------------------|------------|---------|---------|---------|

RESULT: PASS
EOF
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_NOT_EXECUTED_ROOT" \
  "session-qa-not-executed" \
  "docs/qa-not-executed/phase-1/qa-report.md\n"
assert_last_check_fails_with "qa N/A stages must record not executed reasons" 'not_executed_reason|非执行项'

QA_OBLIGATION_ROOT="$HOOK_FIXTURE_ROOT/qa-obligation-not-executed"
mkdir -p "$QA_OBLIGATION_ROOT/docs/qa-obligation-not-executed/phase-1"
cat > "$QA_OBLIGATION_ROOT/docs/qa-obligation-not-executed/phase-1/plan.md" <<'EOF'
## 计划版本
- plan_version: v1
- 版本说明: QA 夹具当前消费的唯一执行基线
EOF
cat > "$QA_OBLIGATION_ROOT/docs/qa-obligation-not-executed/phase-1/qa-report.md" <<'EOF'
审查分级: 标准
执行范围: 验证-A
plan_version_ref: plan.md#计划版本
plan_version_value: v1
release_recommendation: 放行
residual_risk: 低
uncovered_boundary: 无
conditional_release_basis: 无
issue_ledger_anchor: qa-report.md#fail-details

## 验收汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | OK | 0 | passed |
| QA_B（E2E 旅程） | N/A | 0 | scope=验证-A，本轮未执行 |
| QA_C（回归验证） | N/A | 0 | scope=验证-A，本轮未执行 |
| QA_D（探索性测试） | N/A | 0 | scope=验证-A，本轮未执行 |

## 非执行项记录
| stage_or_obligation | not_executed_reason |
|---------------------|---------------------|
| QA_B | scope=验证-A，本轮未执行 |
| QA_C | scope=验证-A，本轮未执行 |
| QA_D | scope=验证-A，本轮未执行 |

### QA_A 交接义务承接
| UNIT | test_obligation | qa_stage | requiredness | 状态 | evidence | not_executed_reason |
|------|-----------------|----------|--------------|------|----------|---------------------|
| UNIT-1 | 冒烟 | QA_A | REQUIRED | DONE | evidence-1 | N/A |
| UNIT-1 | API/接口 | QA_A | CONDITIONAL | N/A | N/A | |

## 已排除潜在问题
| # | 潜在问题 | 排除依据 | 证据 |
|---|---------|---------|------|
| 1 | p1 | reason | evidence |
| 2 | p2 | reason | evidence |

## FAIL 详情
| Issue ID | 阶段 | severity | priority | impact_scope | user_impact | environment_or_build | regression_flag | temporary_workaround | owner_hint | 期望行为 | 实际行为 | 复现命令 |
|----------|------|----------|----------|--------------|-------------|----------------------|-----------------|----------------------|------------|---------|---------|---------|

RESULT: PASS
EOF
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_OBLIGATION_ROOT" \
  "session-qa-obligation-not-executed" \
  "docs/qa-obligation-not-executed/phase-1/qa-report.md\n"
assert_last_check_fails_with "qa obligation-level N/A must record not executed reasons" 'QA_A 交接义务 API/接口 标记为 N/A，但缺少 not_executed_reason'

QA_CONDITIONAL_RELEASE_ROOT="$HOOK_FIXTURE_ROOT/qa-conditional-release"
mkdir -p "$QA_CONDITIONAL_RELEASE_ROOT/docs/qa-conditional-release/phase-1"
cat > "$QA_CONDITIONAL_RELEASE_ROOT/docs/qa-conditional-release/phase-1/plan.md" <<'EOF'
## 计划版本
- plan_version: v1
- 版本说明: QA 夹具当前消费的唯一执行基线
EOF
cat > "$QA_CONDITIONAL_RELEASE_ROOT/docs/qa-conditional-release/phase-1/qa-report.md" <<'EOF'
审查分级: 完整
执行范围: full
plan_version_ref: plan.md#计划版本
plan_version_value: v1
release_recommendation: 条件放行
residual_risk: 中，需要关注上线后监控
uncovered_boundary: 登录后监控、灰度回滚与告警联动尚未全量演练
issue_ledger_anchor: qa-report.md#fail-details

## 验收汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | OK | 0 | ok |
| QA_B（E2E 旅程） | OK | 0 | ok |
| QA_C（回归验证） | OK | 0 | ok |
| QA_D（探索性测试） | OK | 0 | ok |

## 已排除潜在问题
| # | 潜在问题 | 排除依据 | 证据 |
|---|---------|---------|------|
| 1 | p1 | reason | evidence |
| 2 | p2 | reason | evidence |

## FAIL 详情
| Issue ID | 阶段 | severity | priority | impact_scope | user_impact | environment_or_build | regression_flag | temporary_workaround | owner_hint | 期望行为 | 实际行为 | 复现命令 |
|----------|------|----------|----------|--------------|-------------|----------------------|-----------------|----------------------|------------|---------|---------|---------|

RESULT: PASS
EOF
run_completion_check_with_payload \
  "$QA_CHECK" \
  "$QA_CONDITIONAL_RELEASE_ROOT" \
  "session-qa-conditional-release" \
  "docs/qa-conditional-release/phase-1/qa-report.md\n"
assert_last_check_fails_with "conditional release requires explicit basis" 'release_recommendation=条件放行'

QA_EXCLUDED_ROOT="$HOOK_FIXTURE_ROOT/qa-excluded"
mkdir -p "$QA_EXCLUDED_ROOT/docs/qa-excluded/phase-1"
cat > "$QA_EXCLUDED_ROOT/docs/qa-excluded/phase-1/plan.md" <<'EOF'
## 计划版本
- plan_version: v1
- 版本说明: QA 夹具当前消费的唯一执行基线
EOF
cat > "$QA_EXCLUDED_ROOT/docs/qa-excluded/phase-1/qa-report.md" <<'EOF'
审查分级: 标准
执行范围: 验证-A
plan_version_ref: plan.md#计划版本
plan_version_value: v1
release_recommendation: 阻塞
residual_risk: 高，当前缺陷阻断放行
uncovered_boundary: 主链路仍被阻断
conditional_release_basis: 无
issue_ledger_anchor: qa-report.md#fail-details

## 验收汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | ISSUE | 1 | failed |
| QA_B（E2E 旅程） | N/A | 0 | scope=验证-A，本轮未执行 |
| QA_C（回归验证） | N/A | 0 | scope=验证-A，本轮未执行 |
| QA_D（探索性测试） | N/A | 0 | scope=验证-A，本轮未执行 |

## 非执行项记录
| stage_or_obligation | not_executed_reason |
|---------------------|---------------------|
| QA_B | scope=验证-A，本轮未执行 |
| QA_C | scope=验证-A，本轮未执行 |
| QA_D | scope=验证-A，本轮未执行 |

## FAIL 详情
| Issue ID | 阶段 | severity | priority | impact_scope | user_impact | environment_or_build | regression_flag | temporary_workaround | owner_hint | 期望行为 | 实际行为 | 复现命令 |
|----------|------|----------|----------|--------------|-------------|----------------------|-----------------|----------------------|------------|---------|---------|---------|
| QAR-001 | QA_A | S1 | P0 | 核心路径 | 用户无法提测 | build-1 | yes | 无 | developer | a | b | c |
| QAR-002 | QA_A | S2 | P1 | 非核心路径 | 用户受影响 | build-1 | no | 手工兜底 | developer | a | b | c |

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
