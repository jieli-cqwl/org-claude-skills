#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

trim() {
  printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

extract_scalar_field() {
  local file="$1" key="$2"
  local line value
  line="$(grep -E "^[[:space:]]*[-*]?[[:space:]]*${key}:[[:space:]]*" "$file" 2>/dev/null | head -1 || true)"
  value="$(printf '%s' "$line" | sed -E "s/^[[:space:]]*[-*]?[[:space:]]*${key}:[[:space:]]*//")"
  trim "$value"
}

extract_ref_anchor() {
  local ref="$1"
  if [ "${ref#*#}" = "$ref" ]; then
    printf '%s' ""
    return 0
  fi
  printf '%s' "${ref#*#}"
}

normalize_anchor_slug() {
  local value="$1"
  value="$(trim "$value")"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  value="$(printf '%s' "$value" | sed -E 's/[`"'\''‘’“”]//g; s/[[:space:]_]+/-/g; s/[^[:alnum:][:space:]\x80-\xFF-]+/-/g; s/-+/-/g; s/^-+//; s/-+$//')"
  printf '%s' "$value"
}

resolve_ref_file_path() {
  local ref="$1" base_dir="$2"
  local path="${ref%%#*}"
  local dir base
  if [[ "$path" != /* ]]; then
    path="${base_dir}/$(printf '%s' "$path" | sed -E 's#^\./##')"
  fi
  dir="$(dirname "$path")"
  base="$(basename "$path")"
  if [ -d "$dir" ]; then
    dir="$(cd "$dir" 2>/dev/null && pwd)"
    printf '%s/%s' "$dir" "$base"
  else
    printf '%s' "$path"
  fi
}

file_has_heading_anchor_slug() {
  local file="$1" expected_anchor="$2"
  local expected_slug heading heading_slug
  expected_slug="$(normalize_anchor_slug "$expected_anchor")"
  [ -n "$expected_slug" ] || return 1
  while IFS= read -r heading; do
    heading="$(printf '%s' "$heading" | sed -E 's/^#{1,6}[[:space:]]*//')"
    heading_slug="$(normalize_anchor_slug "$heading")"
    if [ "$heading_slug" = "$expected_slug" ]; then
      return 0
    fi
  done < <(grep -E '^#{1,6}[[:space:]]+' "$file" 2>/dev/null || true)
  return 1
}

file_has_special_anchor_alias() {
  local file="$1" anchor="$2" slug
  slug="$(normalize_anchor_slug "$anchor")"
  case "$slug" in
    fresh-proving-output-task-*)
      grep -qF "<a id=\"$anchor\">" "$file" 2>/dev/null || grep -qF "<a id='$anchor'>" "$file" 2>/dev/null
      return
      ;;
  esac
  return 1
}

ref_anchor_exists_in_file() {
  local file="$1" anchor="$2"
  [ -f "$file" ] || return 1
  [ -n "$anchor" ] || return 1
  if grep -qF "<a id=\"$anchor\">" "$file" 2>/dev/null || grep -qF "<a id='$anchor'>" "$file" 2>/dev/null; then
    return 0
  fi
  if file_has_special_anchor_alias "$file" "$anchor"; then
    return 0
  fi
  if file_has_heading_anchor_slug "$file" "$anchor"; then
    return 0
  fi
  return 1
}

find_ref_anchor_line_number() {
  local file="$1" anchor="$2"
  local line expected_slug heading heading_slug
  line="$(grep -nF "<a id=\"$anchor\">" "$file" 2>/dev/null | head -1 | cut -d: -f1 || true)"
  if [ -n "$line" ]; then
    printf '%s' "$line"
    return 0
  fi
  line="$(grep -nF "<a id='$anchor'>" "$file" 2>/dev/null | head -1 | cut -d: -f1 || true)"
  if [ -n "$line" ]; then
    printf '%s' "$line"
    return 0
  fi
  expected_slug="$(normalize_anchor_slug "$anchor")"
  while IFS=: read -r line heading; do
    heading="$(printf '%s' "$heading" | sed -E 's/^#{1,6}[[:space:]]*//')"
    heading_slug="$(normalize_anchor_slug "$heading")"
    if [ "$heading_slug" = "$expected_slug" ]; then
      printf '%s' "$line"
      return 0
    fi
  done < <(grep -nE '^#{1,6}[[:space:]]+' "$file" 2>/dev/null || true)
  return 1
}

anchor_block_contains() {
  local file="$1" anchor="$2" pattern="$3"
  local start_line next_marker end_line
  start_line="$(find_ref_anchor_line_number "$file" "$anchor" || true)"
  [ -n "$start_line" ] || return 1
  next_marker="$(awk -v start="$start_line" 'NR > start && ($0 ~ /^#{1,6}[[:space:]]+/ || index($0, "<a id=") > 0) { print NR; exit }' "$file")"
  if [ -n "$next_marker" ]; then
    end_line=$((next_marker - 1))
  else
    end_line="$(wc -l < "$file" | tr -d ' ')"
  fi
  sed -n "${start_line},${end_line}p" "$file" | grep -Fq "$pattern"
}

parse_score_from_rubric() {
  local score_line="$1" key="$2"
  printf '%s\n' "$score_line" | awk -F';' -v key="$key" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    {
      for (i = 1; i <= NF; i++) {
        entry = trim($i)
        if (entry ~ ("^" key "=")) {
          sub("^" key "=", "", entry)
          print trim(entry)
          exit
        }
      }
    }
  '
}

validate_ref_exists() {
  local ref="$1" base_dir="$2" label="$3"
  local file anchor
  file="$(resolve_ref_file_path "$ref" "$base_dir")"
  anchor="$(extract_ref_anchor "$ref")"
  [ -f "$file" ] || fail "${label} 指向的文件不存在：${file}"
  ref_anchor_exists_in_file "$file" "$anchor" || fail "${label} 指向的锚点不存在：${ref}"
}

assert_scalar_present() {
  local file="$1" key="$2" label="$3"
  local value
  value="$(extract_scalar_field "$file" "$key")"
  [ -n "$value" ] || fail "${label} 缺少 ${key}"
}

extract_non_executed_rows() {
  local file="$1"
  awk -F'|' '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    /^## 非执行项记录$/ { in_section=1; next }
    /^## / && in_section { exit }
    in_section && /^\|/ {
      stage = trim($2)
      reason = trim($3)
      if (stage == "" || stage == "stage_or_obligation" || stage ~ /^-+$/) next
      if (stage == "无" && reason == "无") next
      print stage "\t" reason
    }
  ' "$file"
}

validate_rollout_qa_report() {
  local qa_file="$1" base_dir="$2"
  local scope qa_dir test_cases_file browser_required browser_tool entry_url browser_evidence

  qa_dir="$(cd "$(dirname "$qa_file")" && pwd)"
  test_cases_file="$qa_dir/test-cases.md"

  scope="$(extract_scalar_field "$qa_file" "执行范围")"
  [ "$scope" = "full" ] || fail "repo pilot qa-report 必须是 full 执行范围"
  assert_scalar_present "$qa_file" "plan_version_ref" "repo pilot qa-report"
  assert_scalar_present "$qa_file" "plan_version_value" "repo pilot qa-report"
  assert_scalar_present "$qa_file" "release_recommendation" "repo pilot qa-report"
  assert_scalar_present "$qa_file" "residual_risk" "repo pilot qa-report"
  assert_scalar_present "$qa_file" "uncovered_boundary" "repo pilot qa-report"
  assert_scalar_present "$qa_file" "conditional_release_basis" "repo pilot qa-report"
  assert_scalar_present "$qa_file" "issue_ledger_anchor" "repo pilot qa-report"
  grep -Fq 'issue_ledger_anchor: qa-report.md#fail-details' "$qa_file" || fail "repo pilot qa-report 的 issue_ledger_anchor 必须固定指向 qa-report.md#fail-details"
  grep -Fq '## 验收汇总' "$qa_file" || fail "repo pilot qa-report 缺少验收汇总"
  grep -Fq '## 非执行项记录' "$qa_file" || fail "repo pilot qa-report 缺少非执行项记录"
  grep -Fq '### QA_A UNIT 执行汇总' "$qa_file" || fail "repo pilot qa-report 缺少 QA_A UNIT 执行汇总"
  grep -Fq '### QA_A 交接义务承接' "$qa_file" || fail "repo pilot qa-report 缺少 QA_A 交接义务承接"
  grep -Fq '## 验证-B: E2E 用户旅程' "$qa_file" || fail "repo pilot qa-report 缺少验证-B 章节"
  grep -Fq '## 验证-C: 回归验证' "$qa_file" || fail "repo pilot qa-report 缺少验证-C 章节"
  grep -Fq '## 验证-D: 探索性测试' "$qa_file" || fail "repo pilot qa-report 缺少验证-D 章节"
  grep -Fq '## 已排除潜在问题' "$qa_file" || fail "repo pilot qa-report 缺少已排除潜在问题"
  grep -Fq '## FAIL 详情' "$qa_file" || fail "repo pilot qa-report 缺少 FAIL 详情"
  grep -Fq 'RESULT: PASS' "$qa_file" || fail "repo pilot qa-report 必须给出 RESULT: PASS"

  for stage in 'QA_A（AC 验收）' 'QA_B（E2E 旅程）' 'QA_C（回归验证）' 'QA_D（探索性测试）'; do
    grep -Fq "| ${stage} | OK |" "$qa_file" || fail "repo pilot qa-report 在 full 范围下必须让 ${stage} 为 OK"
  done

  [ -f "$test_cases_file" ] || fail "repo pilot 缺少 test-cases.md，无法校验 QA 交接契约"
  browser_required="$(extract_scalar_field "$test_cases_file" "browser_required")"
  if [ "$browser_required" = "yes" ]; then
    browser_tool="$(extract_scalar_field "$qa_file" "browser_tool")"
    entry_url="$(extract_scalar_field "$qa_file" "entry_url")"
    browser_evidence="$(extract_scalar_field "$qa_file" "browser_evidence")"
    [ -n "$browser_tool" ] || fail "repo pilot qa-report 命中 browser_required 时缺少 browser_tool"
    [ -n "$entry_url" ] || fail "repo pilot qa-report 命中 browser_required 时缺少 entry_url"
    [ -n "$browser_evidence" ] || fail "repo pilot qa-report 命中 browser_required 时缺少 browser_evidence"
    printf '%s\n' "$browser_evidence" | grep -qiE '(screenshot|trace|video|browser[ _-]?log|playwright|webapp-testing)' || fail "repo pilot qa-report 的 browser_evidence 必须是浏览器证据"
  fi
}

validate_goal_closure_refs() {
  local acceptance_file="$1" base_dir="$2" acceptance_dir
  local rows

  acceptance_dir="$(cd "$(dirname "$acceptance_file")" && pwd)"

  rows="$(awk -F'|' '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    /^## 目标闭环$/ { in_section=1; next }
    /^## / && in_section { exit }
    in_section && /^\|/ {
      if (trim($2) == "目标" || $0 ~ /^\|[-|[:space:]]+\|$/) next
      print trim($3) "\t" trim($4) "\t" trim($5)
    }
  ' "$acceptance_file")"

  [ -n "$(printf '%s\n' "$rows" | sed '/^$/d')" ] || fail "repo pilot acceptance-summary 缺少目标闭环数据行"
  while IFS=$'\t' read -r goal_ref execution_ref evidence_ref; do
    [ -n "$goal_ref" ] || fail "repo pilot acceptance-summary 的 goal_source_ref 不能为空"
    [ -n "$execution_ref" ] || fail "repo pilot acceptance-summary 的 execution_basis_ref 不能为空"
    [ -n "$evidence_ref" ] || fail "repo pilot acceptance-summary 的 evidence_ref 不能为空"
    validate_ref_exists "$goal_ref" "$acceptance_dir" "goal_source_ref"
    validate_ref_exists "$execution_ref" "$acceptance_dir" "execution_basis_ref"
    while IFS= read -r evidence_item; do
      [ -n "$evidence_item" ] || continue
      validate_ref_exists "$evidence_item" "$acceptance_dir" "evidence_ref"
    done <<EOF
$(printf '%s\n' "$evidence_ref" | tr '+' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
EOF
  done <<<"$rows"
}

validate_rollout_acceptance_summary() {
  local acceptance_file="$1" qa_file="$2" base_dir="$3"
  local qa_release acceptance_qa_release qa_residual acceptance_residual qa_uncovered acceptance_uncovered qa_conditional acceptance_conditional qa_non_executed acceptance_non_executed

  for heading in '## 交付范围' '## Kickoff 状态' '## 最新状态摘要' '## Task 执行进度' '## AC 验收状态' '## 前置约束验收状态' '## 质量门禁' '## 发布建议对齐' '## 目标闭环' '## 已知问题' '## 豁免' '## 签收记录'; do
    grep -Fq "$heading" "$acceptance_file" || fail "repo pilot acceptance-summary 缺少章节：${heading}"
  done

  for key in kickoff_status plan_version_ref preflight_evidence_ref last_observed_at runtime_snapshot current_plan_version_ref current_plan_version_value qa_report_release_recommendation acceptance_release_recommendation residual_risk uncovered_boundary conditional_release_basis not_executed_reason sign_off_status business_risk_acceptance_status; do
    assert_scalar_present "$acceptance_file" "$key" "repo pilot acceptance-summary"
  done

  grep -Fq '| 目标 | goal_source_ref | execution_basis_ref | evidence_ref | result | remaining_gap_text |' "$acceptance_file" || fail "repo pilot acceptance-summary 缺少目标闭环表头"
  validate_goal_closure_refs "$acceptance_file" "$base_dir"

  qa_release="$(extract_scalar_field "$qa_file" "release_recommendation")"
  acceptance_qa_release="$(extract_scalar_field "$acceptance_file" "qa_report_release_recommendation")"
  qa_residual="$(extract_scalar_field "$qa_file" "residual_risk")"
  acceptance_residual="$(extract_scalar_field "$acceptance_file" "residual_risk")"
  qa_uncovered="$(extract_scalar_field "$qa_file" "uncovered_boundary")"
  acceptance_uncovered="$(extract_scalar_field "$acceptance_file" "uncovered_boundary")"
  qa_conditional="$(extract_scalar_field "$qa_file" "conditional_release_basis")"
  acceptance_conditional="$(extract_scalar_field "$acceptance_file" "conditional_release_basis")"
  qa_non_executed="$(extract_non_executed_rows "$qa_file")"
  acceptance_non_executed="$(extract_scalar_field "$acceptance_file" "not_executed_reason")"

  [ "$acceptance_qa_release" = "$qa_release" ] || fail "repo pilot acceptance-summary 的 qa_report_release_recommendation 必须与 qa-report 一致"
  [ "$acceptance_residual" = "$qa_residual" ] || fail "repo pilot acceptance-summary 的 residual_risk 必须与 qa-report 一致"
  [ "$acceptance_uncovered" = "$qa_uncovered" ] || fail "repo pilot acceptance-summary 的 uncovered_boundary 必须与 qa-report 一致"
  [ "$acceptance_conditional" = "$qa_conditional" ] || fail "repo pilot acceptance-summary 的 conditional_release_basis 必须与 qa-report 一致"
  if [ -n "$qa_non_executed" ]; then
    while IFS=$'\t' read -r stage reason; do
      [ -n "$stage" ] || continue
      printf '%s\n' "$acceptance_non_executed" | grep -Fq "$stage" || fail "repo pilot acceptance-summary 的 not_executed_reason 必须承接 ${stage}"
    done <<< "$qa_non_executed"
  else
    [ "$acceptance_non_executed" = "无" ] || fail "repo pilot acceptance-summary 在 qa-report 无非执行项时必须将 not_executed_reason 记为 无"
  fi
}

validate_rollout_gate() {
  local pilot_file="$1"
  local base_dir
  local pilot_object plan_version_ref plan_version_value mixed_version_rejected acceptance_summary_ref qa_report_ref fresh_proving_output_ref rubric_ref rubric_score residual_risk_ref
  local acceptance_file qa_file dev_file rubric_file
  local acceptance_plan_value qa_plan_value dev_plan_value dev_plan_ref total boundary_score kickoff_score deviation_score full_gate_score goal_score evidence_score usability_score
  local proving_executed_at proving_exit_code

  base_dir="$(cd "$(dirname "$pilot_file")" && pwd)"
  pilot_object="$(extract_scalar_field "$pilot_file" "pilot_object")"
  plan_version_ref="$(extract_scalar_field "$pilot_file" "plan_version_ref")"
  plan_version_value="$(extract_scalar_field "$pilot_file" "plan_version_value")"
  mixed_version_rejected="$(extract_scalar_field "$pilot_file" "mixed_version_rejected")"
  acceptance_summary_ref="$(extract_scalar_field "$pilot_file" "acceptance_summary_ref")"
  qa_report_ref="$(extract_scalar_field "$pilot_file" "qa_report_ref")"
  fresh_proving_output_ref="$(extract_scalar_field "$pilot_file" "fresh_proving_output_ref")"
  rubric_ref="$(extract_scalar_field "$pilot_file" "rubric_ref")"
  rubric_score="$(extract_scalar_field "$pilot_file" "rubric_score")"
  residual_risk_ref="$(extract_scalar_field "$pilot_file" "residual_risk_ref")"

  [ -n "$pilot_object" ] || fail "pilot_object 不能为空"
  printf '%s\n' "$plan_version_ref" | grep -qiE '(^|.*/)plan\.md#计划版本$' || fail "plan_version_ref 必须指向 plan.md#计划版本"
  [ -n "$plan_version_value" ] || fail "plan_version_value 不能为空"
  [ "$mixed_version_rejected" = "yes" ] || fail "mixed_version_rejected 必须为 yes"
  [ -n "$acceptance_summary_ref" ] || fail "acceptance_summary_ref 不能为空"
  [ -n "$qa_report_ref" ] || fail "qa_report_ref 不能为空"
  [ -n "$fresh_proving_output_ref" ] || fail "fresh_proving_output_ref 不能为空"
  [ -n "$rubric_ref" ] || fail "rubric_ref 不能为空"
  [ -n "$rubric_score" ] || fail "rubric_score 不能为空"
  [ -n "$residual_risk_ref" ] || fail "residual_risk_ref 不能为空"

  validate_ref_exists "$plan_version_ref" "$base_dir" "plan_version_ref"
  validate_ref_exists "$acceptance_summary_ref" "$base_dir" "acceptance_summary_ref"
  validate_ref_exists "$qa_report_ref" "$base_dir" "qa_report_ref"
  validate_ref_exists "$fresh_proving_output_ref" "$base_dir" "fresh_proving_output_ref"
  validate_ref_exists "$rubric_ref" "$base_dir" "rubric_ref"
  validate_ref_exists "$residual_risk_ref" "$base_dir" "residual_risk_ref"

  acceptance_file="$(resolve_ref_file_path "$acceptance_summary_ref" "$base_dir")"
  qa_file="$(resolve_ref_file_path "$qa_report_ref" "$base_dir")"
  dev_file="$(resolve_ref_file_path "$fresh_proving_output_ref" "$base_dir")"
  rubric_file="$(resolve_ref_file_path "$rubric_ref" "$base_dir")"

  acceptance_plan_value="$(extract_scalar_field "$acceptance_file" "current_plan_version_value")"
  qa_plan_value="$(extract_scalar_field "$qa_file" "plan_version_value")"
  dev_plan_ref="$(extract_scalar_field "$dev_file" "plan_version_ref")"
  dev_plan_value="$(extract_scalar_field "$dev_file" "plan_version_value")"
  [ "$acceptance_plan_value" = "$plan_version_value" ] || fail "pilot 包混版本：acceptance-summary plan_version_value=${acceptance_plan_value}, pilot=${plan_version_value}"
  [ "$qa_plan_value" = "$plan_version_value" ] || fail "pilot 包混版本：qa-report plan_version_value=${qa_plan_value}, pilot=${plan_version_value}"
  printf '%s\n' "$dev_plan_ref" | grep -qiE '(^|.*/)plan\.md#计划版本$' || fail "dev-report 缺少有效的 plan_version_ref"
  [ -n "$dev_plan_value" ] || fail "dev-report 缺少有效的 plan_version_value"
  [ "$dev_plan_value" = "$plan_version_value" ] || fail "pilot 包混版本：dev-report plan_version_value=${dev_plan_value}, pilot=${plan_version_value}"
  proving_executed_at="$(extract_scalar_field "$dev_file" "Fresh proving executed at")"
  proving_exit_code="$(extract_scalar_field "$dev_file" "Fresh proving exit code")"
  [ -n "$proving_executed_at" ] || fail "dev-report 缺少 Fresh proving executed at"
  [ "$proving_exit_code" = "0" ] || fail "dev-report 的 Fresh proving exit code 必须为 0"

  anchor_block_contains "$rubric_file" "$(extract_ref_anchor "$rubric_ref")" 'Full rollout' || fail "rubric_ref 未指向带 Full rollout 阈值的锚点块"
  anchor_block_contains "$dev_file" "$(extract_ref_anchor "$fresh_proving_output_ref")" 'Fresh proving command:' || fail "fresh_proving_output_ref 未指向真实 fresh proving output"
  anchor_block_contains "$dev_file" "$(extract_ref_anchor "$fresh_proving_output_ref")" 'Fresh proving executed at:' || fail "fresh_proving_output_ref 必须记录 Fresh proving executed at"
  anchor_block_contains "$dev_file" "$(extract_ref_anchor "$fresh_proving_output_ref")" 'Fresh proving exit code: 0' || fail "fresh_proving_output_ref 必须记录 Fresh proving exit code: 0"
  anchor_block_contains "$dev_file" "$(extract_ref_anchor "$fresh_proving_output_ref")" 'bash tests/test-delivery-owner-rollout-gate.sh' || fail "fresh_proving_output_ref 必须指向 full rollout gate 的 proving command"
  anchor_block_contains "$dev_file" "$(extract_ref_anchor "$fresh_proving_output_ref")" '[PASS] delivery-owner rollout gate contract' || fail "fresh_proving_output_ref 必须记录 full rollout gate 的 PASS 输出"
  anchor_block_contains "$(resolve_ref_file_path "$residual_risk_ref" "$base_dir")" "$(extract_ref_anchor "$residual_risk_ref")" 'residual_risk:' || fail "residual_risk_ref 未指向已冻结残余风险结论"
  validate_rollout_qa_report "$qa_file" "$base_dir"
  validate_rollout_acceptance_summary "$acceptance_file" "$qa_file" "$base_dir"

  total="$(parse_score_from_rubric "$rubric_score" "total")"
  boundary_score="$(parse_score_from_rubric "$rubric_score" "角色边界")"
  kickoff_score="$(parse_score_from_rubric "$rubric_score" "Kickoff")"
  deviation_score="$(parse_score_from_rubric "$rubric_score" "偏差治理")"
  full_gate_score="$(parse_score_from_rubric "$rubric_score" "完整门禁")"
  goal_score="$(parse_score_from_rubric "$rubric_score" "目标闭环")"
  evidence_score="$(parse_score_from_rubric "$rubric_score" "证据卫生")"
  usability_score="$(parse_score_from_rubric "$rubric_score" "团队可用性")"

  [ -n "$total" ] || fail "rubric_score 缺少 total"
  [ "$total" -ge 30 ] || fail "Full rollout 要求 total >= 30，当前=${total}"
  for score in "$boundary_score" "$kickoff_score" "$deviation_score" "$full_gate_score" "$goal_score" "$evidence_score" "$usability_score"; do
    [ -n "$score" ] || fail "rubric_score 缺少单项分数"
    [ "$score" -ge 4 ] || fail "Full rollout 要求无单项低于 4"
  done
}

expect_rollout_gate_fail() {
  local pilot_file="$1" label="$2"
  if ( validate_rollout_gate "$pilot_file" ) >/tmp/delivery-owner-rollout-gate.out 2>&1; then
    fail "$label"
  fi
}

create_rollout_fixture() {
  local dir="$1" plan_version="$2" qa_plan_version="$3" acceptance_plan_version="$4" dev_plan_version="$5" score_line="$6" dev_anchor="${7:-fresh-proving-output-task-1}"
  mkdir -p "$dir"
  cat > "$dir/plan.md" <<EOF
## 计划版本
- plan_version: ${plan_version}
EOF
  cat > "$dir/preflight-evidence.md" <<'EOF'
## preflight-con-001
- status: OK
EOF
  cat > "$dir/brief.md" <<'EOF'
# brief.md

## 目标与成功标准
| 目标 | 成功标准 | 度量方式 |
|------|---------|---------|
| rollout gate full 覆盖 | 试点证据包具备可抽查的目标、QA、签收与 proving 证据 | rollout gate contract 通过 |
EOF
  cat > "$dir/prd.md" <<'EOF'
# prd.md

## 阶段目标
| 阶段目标 | 验收口径 |
|----------|----------|
| 试点包可作为 Full rollout 证据 | QA/acceptance/pilot evidence 全链路自洽 |
EOF
  cat > "$dir/test-cases.md" <<'EOF'
# test-cases.md

## QA-交接契约
- browser_required: yes
- obligations: QA_A, QA_B, QA_C, QA_D
EOF
  cat > "$dir/acceptance-summary.md" <<EOF
## 交付范围
- Feature: rollout gate pilot
- PRD: prd.md
- Plan: plan.md
- Task 数: 1（完成: 1，BLOCKED: 0）

## Kickoff 状态
- kickoff_status: READY
- plan_version_ref: plan.md#计划版本
- preflight_evidence_ref: preflight-evidence.md#preflight-con-001
- environment_ready: yes
- dependency_ready: yes
- risk_owner_ready: yes
- qa_handoff_ready: yes
- readiness_waiver: 无

## 最新状态摘要
- last_observed_at: 2026-04-12T10:00:00+08:00
- runtime_snapshot: full rollout pilot ready
- active_blocker: 无
- blocker_owner: 无
- takeover_note: 无
- decision_basis: dev-report.md#${dev_anchor} + qa-report.md#验收汇总 + plan.md#计划版本
- current_plan_version_ref: plan.md#计划版本
- current_plan_version_value: ${acceptance_plan_version}

## Task 执行进度
| Task | 预标复杂度 | 实际复杂度 | 预期轮次 | 实际轮次 | 状态 |
|------|-----------|-----------|---------|---------|------|
| Task-1 | M | M | 1 | 1 | DONE |

## AC 验收状态
| UNIT | test_ref 来源 | 聚合来源 | AC 总数 | 通过 | 失败 | 覆盖率 |
|------|--------------|----------|---------|------|------|--------|
| UNIT-1 | test-cases.md | qa-report.md#qa-a-unit-summary | 2 | 2 | 0 | 100% |

## 前置约束验收状态
| Constraint ID | 类型 | Plan 状态 | preflight_ref | test_ref | 验收结果 | 证据 | 备注 |
|---------------|------|-----------|---------------|----------|----------|------|------|
| CON-001 | env | VERIFIED | preflight-evidence.md#preflight-con-001 | test-cases.md#QA-交接契约 | OK | qa-report.md#qa-a-unit-summary | 环境准备完成 |

## 质量门禁
| 门禁 | 状态 |
|------|------|
| TDD 证据 | PASS |
| Code Review (REVIEW_A) | OK |
| Code Review (REVIEW_B) | N/A |
| QA_A | OK |
| QA_B | OK |
| QA_C | OK |
| QA_D | OK |
| 全量测试 | PASS |

## 发布建议对齐
- qa_report_release_recommendation: 放行
- acceptance_release_recommendation: 放行
<a id="residual-risk"></a>
- residual_risk: 低
- uncovered_boundary: 无
- conditional_release_basis: 无
- not_executed_reason: 无
- risk_acceptance_basis: 无

## 目标闭环
| 目标 | goal_source_ref | execution_basis_ref | evidence_ref | result | remaining_gap_text |
|------|-----------------|---------------------|--------------|--------|--------------------|
| rollout gate full 覆盖 | brief.md#目标与成功标准 | plan.md#计划版本 | dev-report.md#${dev_anchor} + qa-report.md#qa-a-unit-summary | 已达成 | 无 |
| 试点包可作为 Full rollout 证据 | prd.md#阶段目标 | test-cases.md#QA-交接契约 | qa-report.md#qa-summary + dev-report.md#fresh-proving-output-task-1 | 已达成 | 无 |

## 已知问题
| Issue ID | 来源 | 描述 | 严重度 | 处置 |
|----------|------|------|--------|------|

## 豁免
| Waiver ID | 检查项 | 关联 Issue | 到期时间 |
|-----------|--------|-----------|---------|

## 签收记录
- sign_off_status: 确认
- sign_off_by: user
- sign_off_at: 2026-04-12T10:05:00+08:00
- business_risk_acceptance_status: 不适用
- business_risk_acceptance_by: 无
- business_risk_acceptance_at: 无
EOF
  cat > "$dir/qa-report.md" <<EOF
固定完整门禁: REVIEW_A + REVIEW_B + REVIEW_C + QA_A + QA_B + QA_C + QA_D
执行范围: full
plan_version_ref: plan.md#计划版本
plan_version_value: ${qa_plan_version}
release_recommendation: 放行
<a id="residual-risk"></a>
residual_risk: 低
uncovered_boundary: 无
conditional_release_basis: 无
issue_ledger_anchor: qa-report.md#fail-details

## 验收汇总
<a id="qa-summary"></a>
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | OK | 0 | ok |
| QA_B（E2E 旅程） | OK | 0 | ok |
| QA_C（回归验证） | OK | 0 | ok |
| QA_D（探索性测试） | OK | 0 | ok |

## 非执行项记录
| stage_or_obligation | not_executed_reason |
|---------------------|---------------------|
| 无 | 无 |

## 验证-A: AC 验收

### QA_A UNIT 执行汇总
<a id="qa-a-unit-summary"></a>
| UNIT | unit_work_dir | test_cases_ref | 状态 | issue_ids | 说明 |
|------|---------------|----------------|------|-----------|------|
| UNIT-1 | unit-1 | test-cases.md | OK | - | pilot AC 全通过 |

### QA_A 交接义务承接
| UNIT | test_obligation | qa_stage | requiredness | 状态 | evidence | not_executed_reason |
|------|-----------------|----------|--------------|------|----------|---------------------|
| UNIT-1 | 冒烟 | QA_A | REQUIRED | DONE | qa-report.md#qa-a-unit-summary | N/A |
| UNIT-1 | API/接口 | QA_A | CONDITIONAL | DONE | qa-report.md#qa-a-unit-summary | N/A |

### 验证-A 结论
QA_A_OK

## 验证-B: E2E 用户旅程
### 覆盖范围
- UNIT 集合: UNIT-1
- test_cases_refs: test-cases.md

### 浏览器执行信息
browser_tool: webapp-testing
entry_url: http://localhost:3000/pilot
browser_evidence: trace=pilot-trace.zip

### 验证-B 结论
QA_B_OK

## 验证-C: 回归验证
### 全量测试结果
TEST_CMD: bash tests/test-delivery-owner-rollout-gate.sh
通过: 1 / 失败: 0 / 跳过: 0

### 验证-C 结论
QA_C_OK

## 验证-D: 探索性测试
### 探索发现
| # | 探索方向 | 操作描述 | 发现 | 严重度 | 状态 |
|---|---------|---------|------|--------|------|
| 1 | 负向输入 | 空输入提交 | 无异常 | Minor | OBSERVATION |

### 验证-D 结论
QA_D_OK

## FAIL 详情
<a id="fail-details"></a>
| Issue ID | 阶段 | severity | priority | impact_scope | user_impact | environment_or_build | regression_flag | temporary_workaround | owner_hint | 期望行为 | 实际行为 | 复现命令 |
|----------|------|----------|----------|--------------|-------------|----------------------|-----------------|----------------------|------------|---------|---------|---------|

## 已排除潜在问题
| # | 潜在问题 | 排除依据 | 证据 |
|---|---------|---------|------|
| 1 | 目标闭环误映射 | rollout gate 对 goal/evidence anchor 已做抽查 | qa-report.md#qa-summary |
| 2 | 版本串包 | plan/qa/acceptance/dev 版本一致 | plan.md#计划版本 |

## 结果
RESULT: PASS
EOF
  cat > "$dir/dev-report.md" <<EOF
plan_version_ref: plan.md#计划版本
plan_version_value: ${dev_plan_version}

<a id="summary-anchor"></a>
执行摘要

## Task-1
<a id="${dev_anchor}"></a>
Fresh proving executed at: 2026-04-12T10:02:00+08:00
Fresh proving exit code: 0
Fresh proving command:
\`\`\`text
bash tests/test-delivery-owner-rollout-gate.sh
[PASS] delivery-owner rollout gate contract
\`\`\`
EOF
  cat > "$dir/quality-rubric.md" <<'EOF'
# Team Rollout Quality Rubric

## 准入阈值

- Pilot：总分 `>= 24`
- Full rollout：总分 `>= 30`，且无单项低于 `4`

## 历史记录

- v0: legacy rollout note
EOF
  cat > "$dir/pilot-evidence.md" <<EOF
pilot_object: delivery-owner-T5
plan_version_ref: plan.md#计划版本
plan_version_value: ${plan_version}
mixed_version_rejected: yes
acceptance_summary_ref: acceptance-summary.md#发布建议对齐
qa_report_ref: qa-report.md#验收汇总
fresh_proving_output_ref: dev-report.md#${dev_anchor}
rubric_ref: quality-rubric.md#准入阈值
rubric_score: ${score_line}
residual_risk_ref: acceptance-summary.md#residual-risk
EOF
}

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/delivery-owner-rollout.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

create_rollout_fixture "$TMP_ROOT/valid" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
validate_rollout_gate "$TMP_ROOT/valid/pilot-evidence.md"

create_rollout_fixture "$TMP_ROOT/mixed-version" "v1" "v2" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
expect_rollout_gate_fail "$TMP_ROOT/mixed-version/pilot-evidence.md" "mixed-version pilot package should fail rollout gate"

create_rollout_fixture "$TMP_ROOT/mixed-version-flag-off" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/mixed_version_rejected: yes/mixed_version_rejected: no/' "$TMP_ROOT/mixed-version-flag-off/pilot-evidence.md"
expect_rollout_gate_fail "$TMP_ROOT/mixed-version-flag-off/pilot-evidence.md" "mixed-version rejection flag must be yes"

create_rollout_fixture "$TMP_ROOT/missing-anchor" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/fresh_proving_output_ref: dev-report\.md#fresh-proving-output-task-1/fresh_proving_output_ref: dev-report.md#missing-fresh-anchor/' "$TMP_ROOT/missing-anchor/pilot-evidence.md"
expect_rollout_gate_fail "$TMP_ROOT/missing-anchor/pilot-evidence.md" "missing fresh proving anchor should fail rollout gate"

create_rollout_fixture "$TMP_ROOT/low-score" "v1" "v1" "v1" "v1" "total=28; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=4; 证据卫生=4; 团队可用性=4"
expect_rollout_gate_fail "$TMP_ROOT/low-score/pilot-evidence.md" "low rollout score should fail rollout gate"

create_rollout_fixture "$TMP_ROOT/dev-mixed-version" "v2" "v2" "v2" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
expect_rollout_gate_fail "$TMP_ROOT/dev-mixed-version/pilot-evidence.md" "dev-report mixed-version pilot package should fail rollout gate"

create_rollout_fixture "$TMP_ROOT/wrong-fresh-anchor" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/fresh_proving_output_ref: dev-report\.md#fresh-proving-output-task-1/fresh_proving_output_ref: dev-report.md#summary-anchor/' "$TMP_ROOT/wrong-fresh-anchor/pilot-evidence.md"
expect_rollout_gate_fail "$TMP_ROOT/wrong-fresh-anchor/pilot-evidence.md" "wrong existing fresh proving anchor should fail rollout gate"

create_rollout_fixture "$TMP_ROOT/wrong-rubric-anchor" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/rubric_ref: quality-rubric\.md#准入阈值/rubric_ref: quality-rubric.md#历史记录/' "$TMP_ROOT/wrong-rubric-anchor/pilot-evidence.md"
expect_rollout_gate_fail "$TMP_ROOT/wrong-rubric-anchor/pilot-evidence.md" "wrong existing rubric anchor should fail rollout gate"

create_rollout_fixture "$TMP_ROOT/wrong-risk-anchor" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/residual_risk_ref: acceptance-summary\.md#residual-risk/residual_risk_ref: acceptance-summary.md#最新状态摘要/' "$TMP_ROOT/wrong-risk-anchor/pilot-evidence.md"
expect_rollout_gate_fail "$TMP_ROOT/wrong-risk-anchor/pilot-evidence.md" "wrong existing residual risk anchor should fail rollout gate"

create_rollout_fixture "$TMP_ROOT/delivery-gate-proof" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's#bash tests/test-delivery-owner-rollout-gate\.sh#bash tests/test-delivery-owner-gate-contract.sh#; s#\[PASS\] delivery-owner rollout gate contract#[PASS] delivery-owner gate contract#' "$TMP_ROOT/delivery-gate-proof/dev-report.md"
expect_rollout_gate_fail "$TMP_ROOT/delivery-gate-proof/pilot-evidence.md" "delivery gate proving output should fail rollout gate"

create_rollout_fixture "$TMP_ROOT/full-run-na" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
python3 - "$TMP_ROOT/full-run-na/qa-report.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
old = "| QA_D（探索性测试） | OK | 0 | ok |"
new = "| QA_D（探索性测试） | N/A | 0 | skipped |"
if old not in text:
    raise SystemExit("missing QA_D OK row")
path.write_text(text.replace(old, new, 1))
PY
expect_rollout_gate_fail "$TMP_ROOT/full-run-na/pilot-evidence.md" "full rollout pilot package cannot keep QA_D as N/A"

create_rollout_fixture "$TMP_ROOT/missing-goal-closure" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/\n## 目标闭环[\s\S]*?\n## 签收记录/\n## 签收记录/' "$TMP_ROOT/missing-goal-closure/acceptance-summary.md"
expect_rollout_gate_fail "$TMP_ROOT/missing-goal-closure/pilot-evidence.md" "rollout pilot package must include goal closure section"

create_rollout_fixture "$TMP_ROOT/invalid-goal-source" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/brief\.md#目标与成功标准/brief.md#missing-goal-anchor/' "$TMP_ROOT/invalid-goal-source/acceptance-summary.md"
expect_rollout_gate_fail "$TMP_ROOT/invalid-goal-source/pilot-evidence.md" "invalid goal_source_ref should fail rollout gate"

create_rollout_fixture "$TMP_ROOT/missing-qa-details" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/\n## 已排除潜在问题[\s\S]*?\n## 结果/\n## 结果/' "$TMP_ROOT/missing-qa-details/qa-report.md"
expect_rollout_gate_fail "$TMP_ROOT/missing-qa-details/pilot-evidence.md" "repo pilot qa-report must include excluded issues section"

create_rollout_fixture "$TMP_ROOT/browser-required-missing-evidence" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/^browser_evidence:.*\n//m' "$TMP_ROOT/browser-required-missing-evidence/qa-report.md"
expect_rollout_gate_fail "$TMP_ROOT/browser-required-missing-evidence/pilot-evidence.md" "repo pilot qa-report must include browser evidence when browser_required=yes"

create_rollout_fixture "$TMP_ROOT/acceptance-risk-drift" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/- uncovered_boundary: 无/- uncovered_boundary: rollout gate 风险包未承接/' "$TMP_ROOT/acceptance-risk-drift/acceptance-summary.md"
expect_rollout_gate_fail "$TMP_ROOT/acceptance-risk-drift/pilot-evidence.md" "repo pilot acceptance-summary must fully inherit qa risk package"

create_rollout_fixture "$TMP_ROOT/acceptance-residual-drift" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/- residual_risk: 低/- residual_risk: rollout gate residual risk drift/' "$TMP_ROOT/acceptance-residual-drift/acceptance-summary.md"
expect_rollout_gate_fail "$TMP_ROOT/acceptance-residual-drift/pilot-evidence.md" "repo pilot acceptance-summary must inherit qa residual risk"

create_rollout_fixture "$TMP_ROOT/missing-proving-metadata" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 完整门禁=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/^Fresh proving executed at:.*\n//m; s/^Fresh proving exit code:.*\n//m' "$TMP_ROOT/missing-proving-metadata/dev-report.md"
expect_rollout_gate_fail "$TMP_ROOT/missing-proving-metadata/pilot-evidence.md" "fresh proving metadata is required for rollout gate"

validate_rollout_gate "$ROOT/docs/archive/delivery-owner-role-20260411/pilot-evidence.md"

echo "[PASS] delivery-owner rollout gate contract"
