#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

QA_SKILL="$ROOT/shared/skills/qa/SKILL.md"
QA_TEMPLATE="$ROOT/shared/skills/qa/references/templates/qa-report-template.md"
QA_CHECK="$ROOT/shared/skills/qa/scripts/completion_check.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in ${file#"$ROOT"/}: $pattern"
}

create_fixture() {
  local feature_dir="$1"
  local phase_dir="$feature_dir/phase-1"
  local unit_dir="$phase_dir/unit-1"

  mkdir -p "$phase_dir/units" "$unit_dir"

  cat > "$feature_dir/brief.md" <<'EOF'
# Brief

## 交付计划
- phase-1: QA browser gate contract regression
EOF

  cat > "$phase_dir/plan.md" <<'EOF'
# Plan

## 计划版本
- plan_version: v1
EOF

  cat > "$phase_dir/prd.md" <<'EOF'
# PRD

## 阶段目标
- 验证 QA 浏览器门禁合同。
EOF

  cat > "$phase_dir/units/UNIT-1.md" <<'EOF'
# UNIT-1

## 目标
- 覆盖 QA_B 浏览器门禁触发。
EOF

  cat > "$unit_dir/test-cases.md" <<'EOF'
# Test Cases

## QA 交接契约

| test_obligation | trigger_source | qa_stage | requiredness | execution_mode | skip_rule | evidence_expectation |
|-----------------|----------------|----------|--------------|----------------|-----------|----------------------|
| E2E | Web/H5 登录后页面反馈 | QA_B | REQUIRED | browser_required | 未触发时必须写未触发原因 | 旅程表 + 浏览器证据 |
EOF

  cat > "$phase_dir/qa-report.md" <<'EOF'
# qa-report.md

> Phase 级 QA 汇总报告。`QA_A` 按 UNIT 执行并汇总到本报告；`qa-report.md` 的唯一权威落点为 `phase_dir/qa-report.md`。

> 强门禁矩阵：轻量=`QA_A`；标准=`QA_A + QA_C`；完整=`QA_A + QA_B + QA_C + QA_D`。

审查分级: 标准
执行范围: 验证-B
plan_version_ref: plan.md#计划版本
plan_version_value: v1
release_recommendation: 放行
residual_risk: 仍需保留浏览器门禁回归，防止 QA_B 旅程自报降级绕过契约。
uncovered_boundary: 无
conditional_release_basis: 无
issue_ledger_anchor: qa-report.md#fail-details

## 审查轮次记录
| 轮次 | 审查 commit SHA | FAIL 数 | delta |
|------|----------------|---------|-------|
| R1 | abc1234 | 0 | — |

## 输入分析
- Phase 输入：brief.md + phase-1/prd.md + phase-1/units/UNIT-1.md
- QA_A 当前输入：unit-1 + unit-1/test-cases.md
- QA_B/C/D 输入：unit-1 + unit-1/test-cases.md
- 交接契约：来自 test_cases_ref 的 QA 交接契约

## 决策
{验收方法：QA_B 按 test_cases_ref 执行并回写 Phase 报告}

## 产出
INFRA_ERROR: no

## 验收汇总

| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | N/A | 0 | scope=验证-B，本轮未执行 |
| QA_B（E2E 旅程） | OK | 0 | 旅程完成，但未写入浏览器信息 |
| QA_C（回归验证） | N/A | 0 | scope=验证-B，本轮未执行 |
| QA_D（探索性测试） | N/A | 0 | scope=验证-B，本轮未执行 |

## 非执行项记录
| stage_or_obligation | not_executed_reason |
|---------------------|---------------------|
| QA_A | scope=验证-B，本轮未执行 |
| QA_C | scope=验证-B，本轮未执行 |
| QA_D | scope=验证-B，本轮未执行 |

---

## 验证-B: E2E 用户旅程
### 覆盖范围
- UNIT 集合: UNIT-1
- test_cases_refs: {`unit-1/test-cases.md`}

### 旅程设计
| # | 旅程名称 | 类型 | 涉及 AC | execution_mode | 步骤数 |
|---|---------|------|---------|----------------|--------|
| 1 | 浏览器门禁绕过 | E2E | AC-1 | non_browser_ok | 3 |

### 旅程执行
#### 旅程 1: 浏览器门禁绕过
| 步骤 | 操作 | 输入 | 期望输出 | 实际输出 | 状态 |
|------|------|------|---------|---------|------|
| 1 | 打开页面 | /login | 页面可见 | 页面可见 | DONE |
| 2 | 提交表单 | demo/demo | 完成登录 | 完成登录 | DONE |
| 3 | 观察反馈 | 成功提示 | 浏览器内反馈可见 | 浏览器内反馈可见 | DONE |

#### 数据流转验证
| 步骤 | 前序输出 | 后续输入 | 一致性 |
|------|---------|---------|--------|
| 1 | /login | demo/demo | 一致 |
| 2 | 登录成功 | 成功提示 | 一致 |

#### UX / 异常恢复检查点
| obligation | 检查点 | 状态 | 证据 | not_executed_reason |
|------------|--------|------|------|---------------------|
| UX | 反馈清晰可见 | DONE | 截图锚点 screenshot=qa-browser-success.png | N/A |
| 异常恢复 | 错误后可继续操作 | DONE | 录屏锚点 video=qa-browser-retry.mp4 | N/A |

### 验证-B 结论
QA_B_OK

## 已排除潜在问题
| # | 潜在问题 | 排除依据 | 证据 |
|---|---------|---------|------|
| 1 | QA_A/QA_C/QA_D 误判为未执行 | scope=验证-B，已在非执行项记录说明 | 非执行项记录 |
| 2 | 结果字段缺失导致门禁失败 | 相关字段已补齐 | qa-report.md |

## FAIL 详情
| Issue ID | 阶段 | severity | priority | impact_scope | user_impact | environment_or_build | regression_flag | temporary_workaround | owner_hint | 期望行为 | 实际行为 | 复现命令 |
|----------|------|----------|----------|--------------|-------------|----------------------|-----------------|----------------------|------------|---------|---------|---------|

## 结果
RESULT: PASS
EOF

  printf '%s\n' "$phase_dir/qa-report.md" > "$feature_dir/transcript.log"
}

run_gate() {
  local feature_dir="$1"
  local transcript_path="$feature_dir/transcript.log"
  local payload stdout stderr

  payload="$(jq -nc \
    --arg cwd "$ROOT" \
    --arg sid "qa-browser-gate-contract" \
    --arg tp "$transcript_path" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp}')"

  stdout="$(mktemp "${TMPDIR:-/tmp}/qa-browser-gate.stdout.XXXXXX")"
  stderr="$(mktemp "${TMPDIR:-/tmp}/qa-browser-gate.stderr.XXXXXX")"
  if bash "$QA_CHECK" >"$stdout" 2>"$stderr" <<<"$payload"; then
    GATE_STATUS=0
  else
    GATE_STATUS=$?
  fi
  GATE_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/qa-browser-gate.output.XXXXXX")"
  cat "$stdout" "$stderr" >"$GATE_OUTPUT"
}

assert_present 'plan_version_ref' "$QA_SKILL"
assert_present 'plan_version_value' "$QA_SKILL"
assert_present 'issue_ledger_anchor' "$QA_SKILL"
assert_present 'browser_required 只能由 test_cases_ref 的 QA 交接契约触发' "$QA_SKILL"
assert_present '仅当 test_cases_ref 的 QA 交接契约触发 `browser_required` 时必填' "$QA_TEMPLATE"
assert_present 'issue_ledger_anchor' "$QA_TEMPLATE"
assert_present 'browser_required_handoffs=.*extract_browser_required_handoffs.*test_case_refs' "$QA_CHECK"
assert_present 'test_cases_ref 交接契约已触发 browser_required' "$QA_CHECK"
assert_present 'issue_ledger_anchor' "$QA_CHECK"

FEATURE_DIR="$(mktemp -d "$ROOT/docs/qa-browser-gate-contract.XXXXXX")"
trap 'rm -rf "$FEATURE_DIR"' EXIT

create_fixture "$FEATURE_DIR"
run_gate "$FEATURE_DIR"

if [ "$GATE_STATUS" -eq 0 ]; then
  fail "qa completion gate should block when test_cases_ref requires browser_required but qa-report.md self-declares non_browser_ok"
fi

assert_present 'browser_required' "$GATE_OUTPUT"
assert_present 'test_cases_ref 交接契约已触发 browser_required' "$GATE_OUTPUT"
assert_present 'browser_tool' "$GATE_OUTPUT"
assert_present 'browser_evidence' "$GATE_OUTPUT"

echo "[PASS] qa browser gate contract"
