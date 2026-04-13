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
  sed -n "${start_line},${end_line}p" "$file" | grep -q "$pattern"
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

validate_rollout_gate() {
  local pilot_file="$1"
  local base_dir
  local pilot_object plan_version_ref plan_version_value acceptance_summary_ref qa_report_ref fresh_proving_output_ref rubric_ref rubric_score residual_risk_ref
  local acceptance_file qa_file dev_file rubric_file
  local acceptance_plan_value qa_plan_value dev_plan_value dev_plan_ref total boundary_score kickoff_score deviation_score escalation_score goal_score evidence_score usability_score

  base_dir="$(cd "$(dirname "$pilot_file")" && pwd)"
  pilot_object="$(extract_scalar_field "$pilot_file" "pilot_object")"
  plan_version_ref="$(extract_scalar_field "$pilot_file" "plan_version_ref")"
  plan_version_value="$(extract_scalar_field "$pilot_file" "plan_version_value")"
  acceptance_summary_ref="$(extract_scalar_field "$pilot_file" "acceptance_summary_ref")"
  qa_report_ref="$(extract_scalar_field "$pilot_file" "qa_report_ref")"
  fresh_proving_output_ref="$(extract_scalar_field "$pilot_file" "fresh_proving_output_ref")"
  rubric_ref="$(extract_scalar_field "$pilot_file" "rubric_ref")"
  rubric_score="$(extract_scalar_field "$pilot_file" "rubric_score")"
  residual_risk_ref="$(extract_scalar_field "$pilot_file" "residual_risk_ref")"

  [ -n "$pilot_object" ] || fail "pilot_object 不能为空"
  printf '%s\n' "$plan_version_ref" | grep -qiE '(^|.*/)plan\.md#计划版本$' || fail "plan_version_ref 必须指向 plan.md#计划版本"
  [ -n "$plan_version_value" ] || fail "plan_version_value 不能为空"
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

  anchor_block_contains "$rubric_file" "$(extract_ref_anchor "$rubric_ref")" 'Full rollout' || fail "rubric_ref 未指向带 Full rollout 阈值的锚点块"
  anchor_block_contains "$dev_file" "$(extract_ref_anchor "$fresh_proving_output_ref")" 'Fresh proving command:' || fail "fresh_proving_output_ref 未指向真实 fresh proving output"
  anchor_block_contains "$(resolve_ref_file_path "$residual_risk_ref" "$base_dir")" "$(extract_ref_anchor "$residual_risk_ref")" 'residual_risk:' || fail "residual_risk_ref 未指向已冻结残余风险结论"

  total="$(parse_score_from_rubric "$rubric_score" "total")"
  boundary_score="$(parse_score_from_rubric "$rubric_score" "角色边界")"
  kickoff_score="$(parse_score_from_rubric "$rubric_score" "Kickoff")"
  deviation_score="$(parse_score_from_rubric "$rubric_score" "偏差治理")"
  escalation_score="$(parse_score_from_rubric "$rubric_score" "动态升档")"
  goal_score="$(parse_score_from_rubric "$rubric_score" "目标闭环")"
  evidence_score="$(parse_score_from_rubric "$rubric_score" "证据卫生")"
  usability_score="$(parse_score_from_rubric "$rubric_score" "团队可用性")"

  [ -n "$total" ] || fail "rubric_score 缺少 total"
  [ "$total" -ge 30 ] || fail "Full rollout 要求 total >= 30，当前=${total}"
  for score in "$boundary_score" "$kickoff_score" "$deviation_score" "$escalation_score" "$goal_score" "$evidence_score" "$usability_score"; do
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
  cat > "$dir/acceptance-summary.md" <<EOF
## 发布建议对齐
- qa_report_release_recommendation: 放行
- acceptance_release_recommendation: 放行
<a id="residual-risk"></a>
- residual_risk: 低

## 最新状态摘要
- current_plan_version_ref: plan.md#计划版本
- current_plan_version_value: ${acceptance_plan_version}
EOF
  cat > "$dir/qa-report.md" <<EOF
审查分级: 标准
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
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | OK | 0 | ok |
| QA_B（E2E 旅程） | OK | 0 | ok |
| QA_C（回归验证） | OK | 0 | ok |
| QA_D（探索性测试） | OK | 0 | ok |

## FAIL 详情
| Issue ID | 阶段 | severity | priority | impact_scope | user_impact | environment_or_build | regression_flag | temporary_workaround | owner_hint | 期望行为 | 实际行为 | 复现命令 |
|----------|------|----------|----------|--------------|-------------|----------------------|-----------------|----------------------|------------|---------|---------|---------|
EOF
  cat > "$dir/dev-report.md" <<EOF
plan_version_ref: plan.md#计划版本
plan_version_value: ${dev_plan_version}

<a id="summary-anchor"></a>
执行摘要

## Task-1
<a id="${dev_anchor}"></a>
Fresh proving command:
\`\`\`text
bash tests/run-all.sh
1 passing
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

create_rollout_fixture "$TMP_ROOT/valid" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 动态升档=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
validate_rollout_gate "$TMP_ROOT/valid/pilot-evidence.md"

create_rollout_fixture "$TMP_ROOT/mixed-version" "v1" "v2" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 动态升档=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
expect_rollout_gate_fail "$TMP_ROOT/mixed-version/pilot-evidence.md" "mixed-version pilot package should fail rollout gate"

create_rollout_fixture "$TMP_ROOT/missing-anchor" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 动态升档=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/fresh_proving_output_ref: dev-report\.md#fresh-proving-output-task-1/fresh_proving_output_ref: dev-report.md#missing-fresh-anchor/' "$TMP_ROOT/missing-anchor/pilot-evidence.md"
expect_rollout_gate_fail "$TMP_ROOT/missing-anchor/pilot-evidence.md" "missing fresh proving anchor should fail rollout gate"

create_rollout_fixture "$TMP_ROOT/low-score" "v1" "v1" "v1" "v1" "total=28; 角色边界=4; Kickoff=4; 偏差治理=4; 动态升档=4; 目标闭环=4; 证据卫生=4; 团队可用性=4"
expect_rollout_gate_fail "$TMP_ROOT/low-score/pilot-evidence.md" "low rollout score should fail rollout gate"

create_rollout_fixture "$TMP_ROOT/dev-mixed-version" "v2" "v2" "v2" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 动态升档=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
expect_rollout_gate_fail "$TMP_ROOT/dev-mixed-version/pilot-evidence.md" "dev-report mixed-version pilot package should fail rollout gate"

create_rollout_fixture "$TMP_ROOT/wrong-fresh-anchor" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 动态升档=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/fresh_proving_output_ref: dev-report\.md#fresh-proving-output-task-1/fresh_proving_output_ref: dev-report.md#summary-anchor/' "$TMP_ROOT/wrong-fresh-anchor/pilot-evidence.md"
expect_rollout_gate_fail "$TMP_ROOT/wrong-fresh-anchor/pilot-evidence.md" "wrong existing fresh proving anchor should fail rollout gate"

create_rollout_fixture "$TMP_ROOT/wrong-rubric-anchor" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 动态升档=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/rubric_ref: quality-rubric\.md#准入阈值/rubric_ref: quality-rubric.md#历史记录/' "$TMP_ROOT/wrong-rubric-anchor/pilot-evidence.md"
expect_rollout_gate_fail "$TMP_ROOT/wrong-rubric-anchor/pilot-evidence.md" "wrong existing rubric anchor should fail rollout gate"

create_rollout_fixture "$TMP_ROOT/wrong-risk-anchor" "v1" "v1" "v1" "v1" "total=30; 角色边界=4; Kickoff=4; 偏差治理=4; 动态升档=4; 目标闭环=5; 证据卫生=5; 团队可用性=4"
perl -0pi -e 's/residual_risk_ref: acceptance-summary\.md#residual-risk/residual_risk_ref: acceptance-summary.md#最新状态摘要/' "$TMP_ROOT/wrong-risk-anchor/pilot-evidence.md"
expect_rollout_gate_fail "$TMP_ROOT/wrong-risk-anchor/pilot-evidence.md" "wrong existing residual risk anchor should fail rollout gate"

validate_rollout_gate "$ROOT/docs/delivery-owner-role-20260411/pilot-evidence.md"

echo "[PASS] delivery-owner rollout gate contract"
