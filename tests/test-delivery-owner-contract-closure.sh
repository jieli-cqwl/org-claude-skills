#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

CHECK_SCRIPT="$ROOT/shared/skills/delivery-owner/scripts/completion_check.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

run_gate() {
  local root_dir="$1"
  local feature_name="$2"
  local session_id="$3"
  local transcript_path="$4"
  local file_path="$5"
  local payload

  payload="$(jq -nc \
    --arg cwd "$root_dir" \
    --arg sid "$session_id" \
    --arg tp "$transcript_path" \
    --arg fp "$file_path" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp, tool_name:"Write", tool_input:{file_path:$fp}}')"

  LAST_CHECK_STDOUT="$(mktemp "${TMPDIR:-/tmp}/pm-contract.stdout.XXXXXX")"
  LAST_CHECK_STDERR="$(mktemp "${TMPDIR:-/tmp}/pm-contract.stderr.XXXXXX")"
  LAST_CHECK_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/pm-contract.output.XXXXXX")"

  if bash "$CHECK_SCRIPT" >"$LAST_CHECK_STDOUT" 2>"$LAST_CHECK_STDERR" <<<"$payload"; then
    LAST_CHECK_STATUS=0
  else
    LAST_CHECK_STATUS=$?
  fi
  cat "$LAST_CHECK_STDOUT" "$LAST_CHECK_STDERR" >"$LAST_CHECK_OUTPUT"
}

create_base_fixture() {
  local root_dir="$1"
  local feature_name="$2"

  create_project_manager_fixture \
    "$root_dir" \
    "$feature_name" \
    "valid" \
    "valid" \
    "valid" \
    "valid" \
    "valid" \
    "valid" \
    "n_a" \
    "valid"
}

copy_fixture() {
  local src="$1"
  local dst="$2"
  cp -R "$src" "$dst"
}

write_transcript() {
  local transcript_path="$1"
  local feature_name="$2"

  cat > "$transcript_path" <<EOF
docs/${feature_name}/phase-1/unit-1/dev-report.md
docs/${feature_name}/phase-1/plan.md
docs/${feature_name}/phase-1/design.md
docs/${feature_name}/phase-1/qa-report.md
EOF
}

expect_pass() {
  local root_dir="$1"
  local feature_name="$2"
  local label="$3"
  local transcript_path="$4"
  local file_path="$5"

  run_gate "$root_dir" "$feature_name" "$label" "$transcript_path" "$file_path"
  if [ "$LAST_CHECK_STATUS" -ne 0 ]; then
    cat "$LAST_CHECK_OUTPUT" >&2
    fail "$label: expected completion_check to pass"
  fi
}

expect_fail_with() {
  local root_dir="$1"
  local feature_name="$2"
  local label="$3"
  local transcript_path="$4"
  local file_path="$5"
  local pattern="$6"

  run_gate "$root_dir" "$feature_name" "$label" "$transcript_path" "$file_path"
  if [ "$LAST_CHECK_STATUS" -eq 0 ]; then
    fail "$label: expected completion_check to fail"
  fi
  assert_present "$pattern" "$LAST_CHECK_OUTPUT"
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/pm-contract.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

HELPER_SOURCE="$TMP_ROOT/pm-contract-helpers.sh"
awk '
  /^create_tech_lead_fixture\(\) \{$/ {
    capture=1
  }
  capture {
    if ($0 ~ /^run_tech_lead_completion_check\(\) \{$/) {
      exit
    }
    print
  }
' "$ROOT/tests/test-skill-output-and-gate-contract.sh" > "$HELPER_SOURCE"
# shellcheck source=/dev/null
. "$HELPER_SOURCE"

FEATURE_NAME="pm-contract-closure"
BASE_ROOT="$TMP_ROOT/base"
mkdir -p "$BASE_ROOT"
create_base_fixture "$BASE_ROOT" "$FEATURE_NAME"
perl -0pi -e 's/- residual_risk: 低，残余风险可接受/- residual_risk: 低，残余风险可接受\n- uncovered_boundary: 无\n- conditional_release_basis: 无\n- not_executed_reason: QA_B\/QA_D 未触发，见 qa-report.md#验收汇总/' "$BASE_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md"

BASE_TRANSCRIPT="$BASE_ROOT/transcript.log"
write_transcript "$BASE_TRANSCRIPT" "$FEATURE_NAME"
BASE_ACCEPTANCE="$BASE_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md"

expect_pass "$BASE_ROOT" "$FEATURE_NAME" "baseline-valid" "$BASE_TRANSCRIPT" "$BASE_ACCEPTANCE"

PARAPHRASE_ROOT="$TMP_ROOT/paraphrase"
copy_fixture "$BASE_ROOT" "$PARAPHRASE_ROOT"
write_transcript "$PARAPHRASE_ROOT/transcript.log" "$FEATURE_NAME"
perl -0pi -e 's{\| 登录旅程完成 \| brief\.md#目标与成功标准 \| plan\.md#计划版本 \| dev-report\.md#task-1 \+ qa-report\.md#qa_a-unit-1 \| 已达成 \| 无 \|}{| 目标一：登录体验达成 | brief.md#目标与成功标准 | plan.md#计划版本 | dev-report.md#task-1 + qa-report.md#qa_a-unit-1 | 已达成 | 无 |}g; s{\| 探索可行性验证 \| prd\.md#阶段目标 \| unit-1/test-cases\.md#QA-交接契约 \| qa-report\.md#qa_a-unit-1 \+ dev-report\.md#task-1 \| 已达成 \| 无 \|}{| 阶段目标已承接 | prd.md#阶段目标 | unit-1/test-cases.md#QA-交接契约 | qa-report.md#qa_a-unit-1 + dev-report.md#task-1 | 已达成 | 无 |}g' "$PARAPHRASE_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md"
expect_pass "$PARAPHRASE_ROOT" "$FEATURE_NAME" "goal-paraphrase" "$PARAPHRASE_ROOT/transcript.log" "$PARAPHRASE_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md"

DUPLICATE_ROW_ROOT="$TMP_ROOT/duplicate-row"
copy_fixture "$BASE_ROOT" "$DUPLICATE_ROW_ROOT"
write_transcript "$DUPLICATE_ROW_ROOT/transcript.log" "$FEATURE_NAME"
perl -0pi -e 's{\| 探索可行性验证 \| prd\.md#阶段目标 \| unit-1/test-cases\.md#QA-交接契约 \| qa-report\.md#qa_a-unit-1 \+ dev-report\.md#task-1 \| 已达成 \| 无 \|}{| 登录旅程完成 | brief.md#目标与成功标准 | unit-1/test-cases.md#QA-交接契约 | qa-report.md#qa_a-unit-1 + dev-report.md#task-1 | 已达成 | 无 |\n| 探索可行性验证 | prd.md#阶段目标 | unit-1/test-cases.md#QA-交接契约 | qa-report.md#qa_a-unit-1 + dev-report.md#task-1 | 已达成 | 无 |}g' "$DUPLICATE_ROW_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md"
expect_pass "$DUPLICATE_ROW_ROOT" "$FEATURE_NAME" "goal-duplicate-row" "$DUPLICATE_ROW_ROOT/transcript.log" "$DUPLICATE_ROW_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md"

MISSING_GOAL_ROOT="$TMP_ROOT/missing-goal"
copy_fixture "$BASE_ROOT" "$MISSING_GOAL_ROOT"
write_transcript "$MISSING_GOAL_ROOT/transcript.log" "$FEATURE_NAME"
perl -0pi -e 's{\n\| 探索可行性验证 \| prd\.md#阶段目标 \| unit-1/test-cases\.md#QA-交接契约 \| qa-report\.md#qa_a-unit-1 \+ dev-report\.md#task-1 \| 已达成 \| 无 \|\n}{\n}g' "$MISSING_GOAL_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md"
expect_fail_with "$MISSING_GOAL_ROOT" "$FEATURE_NAME" "goal-coverage" "$MISSING_GOAL_ROOT/transcript.log" "$MISSING_GOAL_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md" '目标闭环|未完整承接|行数与 brief/phase 目标数不一致'

MISSING_SECOND_SAME_COUNT_ROOT="$TMP_ROOT/missing-second-same-count"
copy_fixture "$BASE_ROOT" "$MISSING_SECOND_SAME_COUNT_ROOT"
write_transcript "$MISSING_SECOND_SAME_COUNT_ROOT/transcript.log" "$FEATURE_NAME"
perl -0pi -e 's{\| 登录旅程完成 \| 用户可以完成登录并得到正确反馈 \| QA_A 通过 \+ acceptance-summary 目标闭环收口 \|}{| 登录旅程完成 | 用户可以完成登录并得到正确反馈 | QA_A 通过 + acceptance-summary 目标闭环收口 |\n| 二次校验完成 | 用户可以在登录后完成二次校验 | QA_A 通过 + acceptance-summary 目标闭环收口 |}g' "$MISSING_SECOND_SAME_COUNT_ROOT/docs/$FEATURE_NAME/brief.md"
perl -0pi -e 's{\| 探索可行性验证 \| prd\.md#阶段目标 \| unit-1/test-cases\.md#QA-交接契约 \| qa-report\.md#qa_a-unit-1 \+ dev-report\.md#task-1 \| 已达成 \| 无 \|}{| 登录旅程完成 | brief.md#目标与成功标准 | unit-1/test-cases.md#QA-交接契约 | qa-report.md#qa_a-unit-1 + dev-report.md#task-1 | 已达成 | 无 |\n| 探索可行性验证 | prd.md#阶段目标 | unit-1/test-cases.md#QA-交接契约 | qa-report.md#qa_a-unit-1 + dev-report.md#task-1 | 已达成 | 无 |}g' "$MISSING_SECOND_SAME_COUNT_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md"
expect_fail_with "$MISSING_SECOND_SAME_COUNT_ROOT" "$FEATURE_NAME" "goal-missing-second-same-count" "$MISSING_SECOND_SAME_COUNT_ROOT/transcript.log" "$MISSING_SECOND_SAME_COUNT_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md" 'brief 目标未完整承接|二次校验完成'

ANCHOR_ROOT="$TMP_ROOT/anchor"
copy_fixture "$BASE_ROOT" "$ANCHOR_ROOT"
write_transcript "$ANCHOR_ROOT/transcript.log" "$FEATURE_NAME"
perl -0pi -e 's/- decision_basis: dev-report\.md#执行编排状态 \+ qa-report\.md#qa_a-unit-1 \+ plan\.md#计划版本/- decision_basis: qa-report.md#missing-anchor/g' "$ANCHOR_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md"
perl -0pi -e 's/- decision_basis: plan\.md#计划版本 \+ dev-report\.md#task-1 \+ qa-report\.md#qa_a-unit-1/- decision_basis: dev-report.md#missing-anchor/g; s/- replan_request: 无/- replan_request: dev-report.md#missing-replan-anchor/g; s/- batch_freeze_reason: 无/- batch_freeze_reason: 需要冻结当前批次等待再计划/g; s/- unlock_resolution: 无/- unlock_resolution: 解除冻结后继续执行/g; s/- next_action: REQUEST_REVIEW/- next_action: REPLAN_REQUEST/g' "$ANCHOR_ROOT/docs/$FEATURE_NAME/phase-1/unit-1/dev-report.md"
expect_fail_with "$ANCHOR_ROOT" "$FEATURE_NAME" "runtime-anchor" "$ANCHOR_ROOT/transcript.log" "$ANCHOR_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md" 'decision_basis|replan_request'

STALENESS_ROOT="$TMP_ROOT/staleness"
copy_fixture "$BASE_ROOT" "$STALENESS_ROOT"
write_transcript "$STALENESS_ROOT/transcript.log" "$FEATURE_NAME"
cat > "$STALENESS_ROOT/docs/$FEATURE_NAME/phase-1/stale-plan.md" <<'EOF'
# plan.md

## 计划版本
- plan_version: v0
EOF
perl -0pi -e 's{\| 登录旅程完成 \| brief\.md#目标与成功标准 \| plan\.md#计划版本 \| dev-report\.md#task-1 \+ qa-report\.md#qa_a-unit-1 \| 已达成 \| 无 \|}{| 登录旅程完成 | brief.md#目标与成功标准 | stale-plan.md#计划版本 | dev-report.md#task-1 + qa-report.md#qa_a-unit-1 | 已达成 | 无 |}g' "$STALENESS_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md"
expect_fail_with "$STALENESS_ROOT" "$FEATURE_NAME" "stale-plan" "$STALENESS_ROOT/transcript.log" "$STALENESS_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md" 'execution_basis_ref.*design\.md / plan\.md / test-cases\.md'

SELF_EVIDENCE_ROOT="$TMP_ROOT/self-evidence"
copy_fixture "$BASE_ROOT" "$SELF_EVIDENCE_ROOT"
write_transcript "$SELF_EVIDENCE_ROOT/transcript.log" "$FEATURE_NAME"
perl -0pi -e 's/qa-report\.md#qa_a-unit-1 \+ dev-report\.md#task-1/qa-report.md#qa_a-unit-1 + acceptance-summary.md#质量门禁/' "$SELF_EVIDENCE_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md"
expect_fail_with "$SELF_EVIDENCE_ROOT" "$FEATURE_NAME" "goal-self-evidence" "$SELF_EVIDENCE_ROOT/transcript.log" "$SELF_EVIDENCE_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md" 'evidence.*dev-report\.md / qa-report\.md / preflight-evidence\.md'

RISK_ROOT="$TMP_ROOT/risk"
copy_fixture "$BASE_ROOT" "$RISK_ROOT"
write_transcript "$RISK_ROOT/transcript.log" "$FEATURE_NAME"
sed -i.bak \
  -e '/^- uncovered_boundary:/d' \
  -e '/^- conditional_release_basis:/d' \
  -e '/^- not_executed_reason:/d' \
  "$RISK_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md"
rm -f "$RISK_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md.bak"
expect_fail_with "$RISK_ROOT" "$FEATURE_NAME" "qa-risk-package" "$RISK_ROOT/transcript.log" "$RISK_ROOT/docs/$FEATURE_NAME/phase-1/acceptance-summary.md" 'uncovered_boundary|conditional_release_basis|not_executed_reason'

echo "[PASS] delivery-owner contract closure cases"
