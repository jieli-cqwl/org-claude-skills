#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=shared/hooks/lib/common.sh
source "$ROOT/shared/hooks/lib/common.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_failure_contains() {
  local label="$1"
  local pattern="$2"
  if ! printf '%b' "$LAST_FAILURES" | grep -Eq "$pattern"; then
    printf '%b\n' "$LAST_FAILURES" >&2
    fail "${label}: missing failure pattern: $pattern"
  fi
}

assert_has_failures() {
  local label="$1"
  if [ -z "${LAST_FAILURES:-}" ]; then
    fail "${label}: expected failures"
  fi
}

assert_no_failures() {
  local label="$1"
  if [ -n "${LAST_FAILURES:-}" ]; then
    printf '%b\n' "$LAST_FAILURES" >&2
    fail "${label}: expected no failures"
  fi
}

run_policy_case() {
  local total_stable_issues="$1"
  local ledger_rows="$2"
  local convergence_rows="$3"
  local user_decision_rows="${4:-}"
  local tmp_file

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/org-review-convergence.XXXXXX.md")"
  cat > "$tmp_file" <<EOF
## 审查结论
### 审查问题台账

| Issue ID | 视角 | Severity | Status | Evidence Anchor | Handoff Target | Review Round | 处理摘要 |
|----------|------|----------|--------|-----------------|----------------|--------------|---------|
${ledger_rows}

### 收敛轮次摘要

| 轮次 | 结果 | FAIL数 | 未关闭 Issue IDs | 控制动作 | 说明 |
|------|------|-------|------------------|----------|------|
${convergence_rows}

### 用户裁决记录

| 触发轮次 | 控制动作 | 用户决定 | 关联 Issue IDs | 记录时间 | 说明 |
|----------|----------|----------|----------------|----------|------|
${user_decision_rows}
EOF

  FAILURES=""
  validate_review_convergence_policy "$tmp_file" "review.md" "$total_stable_issues" || true
  LAST_FAILURES="$FAILURES"
  rm -f "$tmp_file"
}

run_policy_case \
  "0" \
  "" \
  "| R1 | PASS | 0 | 无 | CONTINUE | 首轮无问题 |"
assert_has_failures "confirmation round required"
assert_failure_contains "confirmation round required" '首轮全 PASS 仍需确认轮'

run_policy_case \
  "1" \
  "| PR-001 | 产品 | P1 | BLOCKED | brief.md#影响范围 | design.md#待计划约束 | R2 | 待用户裁决 |" \
  "| R1 | FAIL | 1 | PR-001 | CONTINUE | 首轮发现阻断问题 |
| R2 | FAIL | 1 | PR-001 | CONTINUE | 第二轮仍未收敛 |"
assert_has_failures "non-converging rounds must pause"
assert_failure_contains "non-converging rounds must pause" '连续 2 轮 FAIL 数未减少'

run_policy_case \
  "1" \
  "| PR-001 | 产品 | P1 | BLOCKED | brief.md#影响范围 | design.md#待计划约束 | R2 | 等待用户决定是否继续 |" \
  "| R1 | FAIL | 1 | PR-001 | CONTINUE | 首轮发现阻断问题 |
| R2 | FAIL | 1 | PR-001 | ASK_USER | 已触发暂停，等待用户裁决 |"
assert_has_failures "latest ask_user must block completion"
assert_failure_contains "latest ask_user must block completion" '已触发 ASK_USER'

run_policy_case \
  "0" \
  "| PR-001 | 产品 | P1 | RESOLVED | brief.md#影响范围 | design.md#待计划约束 | R3 | 用户同意继续后已修复 |" \
  "| R1 | FAIL | 1 | PR-001 | CONTINUE | 首轮发现阻断问题 |
| R2 | FAIL | 1 | PR-001 | ASK_USER | 第二轮未收敛，已暂停 |
| R3 | PASS | 0 | 无 | CONTINUE | 未补用户裁决就直接继续 |"
assert_has_failures "ask_user must stay sticky without user decision"
assert_failure_contains "ask_user must stay sticky without user decision" 'ASK_USER.*缺少用户裁决记录'

run_policy_case \
  "0" \
  "| PR-001 | 产品 | P1 | RESOLVED | brief.md#影响范围 | design.md#待计划约束 | R3 | 用户同意继续后已修复 |" \
  "| R1 | FAIL | 1 | PR-001 | CONTINUE | 首轮发现阻断问题 |
| R2 | FAIL | 1 | PR-001 | ASK_USER | 第二轮未收敛，已暂停 |
| R3 | PASS | 0 | 无 | CONTINUE | 用户裁决后完成修复 |
| R4 | PASS | 0 | 无 | CONFIRMATION | 确认轮再次通过 |" \
  "| R2 | ASK_USER | 继续修复 | PR-001 | 2026-04-11 10:30 | 用户同意继续修复 |"
assert_no_failures "ask_user may continue after explicit user decision"

run_policy_case \
  "1" \
  "| PR-001 | 产品 | P1 | BLOCKED | brief.md#影响范围 | design.md#待计划约束 | R3 | 连续 3 轮未关闭 |" \
  "| R1 | FAIL | 1 | PR-001 | CONTINUE | 首轮发现阻断问题 |
| R2 | FAIL | 1 | PR-001 | ASK_USER | 第二轮未收敛，已暂停 |
| R3 | FAIL | 1 | PR-001 | CONTINUE | 第三轮仍未关闭，但未熔断 |"
assert_has_failures "three-round unresolved issue must block"
assert_failure_contains "three-round unresolved issue must block" '连续 3 轮未关闭'

run_policy_case \
  "1" \
  "| PR-001 | 产品 | P1 | BLOCKED | brief.md#影响范围 | design.md#待计划约束 | R3 | 已正式阻断 |" \
  "| R1 | FAIL | 1 | PR-001 | CONTINUE | 首轮发现阻断问题 |
| R2 | FAIL | 1 | PR-001 | ASK_USER | 第二轮未收敛，已暂停 |
| R3 | FAIL | 1 | PR-001 | BLOCKED | 第三轮仍未关闭，正式熔断 |"
assert_has_failures "latest blocked must block completion"
assert_failure_contains "latest blocked must block completion" '已标记 BLOCKED'

run_policy_case \
  "0" \
  "| PR-001 | 产品 | P1 | RESOLVED | brief.md#影响范围 | design.md#待计划约束 | R2 | 修复完成 |" \
  "| R1 | FAIL | 1 | PR-001 | CONTINUE | 首轮发现问题并修复 |
| R2 | PASS | 0 | 无 | CONTINUE | 修复后通过 |
| R3 | PASS | 0 | 无 | CONFIRMATION | 确认轮再次通过 |"
assert_no_failures "resolved issues with confirmation should pass"

run_policy_case \
  "0" \
  "| PR-001 | 产品 | P1 | RESOLVED | brief.md#影响范围 | design.md#待计划约束 | R4 | 用户裁决后已修复 |" \
  "| R1 | FAIL | 1 | PR-001 | CONTINUE | 首轮发现阻断问题 |
| R2 | FAIL | 1 | PR-001 | ASK_USER | 第二轮未收敛，已暂停 |
| R3 | FAIL | 1 | PR-001 | BLOCKED | 第三轮仍未关闭，正式熔断 |
| R4 | PASS | 0 | 无 | CONTINUE | 未补用户裁决就直接继续 |"
assert_has_failures "blocked must stay sticky without user decision"
assert_failure_contains "blocked must stay sticky without user decision" 'BLOCKED.*缺少用户裁决记录'

run_policy_case \
  "0" \
  "| PR-001 | 产品 | P1 | RESOLVED | brief.md#影响范围 | design.md#待计划约束 | R4 | 用户裁决后已修复 |" \
  "| R1 | FAIL | 1 | PR-001 | CONTINUE | 首轮发现阻断问题 |
| R2 | FAIL | 1 | PR-001 | ASK_USER | 第二轮未收敛，已暂停 |
| R3 | FAIL | 1 | PR-001 | BLOCKED | 第三轮仍未关闭，正式熔断 |
| R4 | PASS | 0 | 无 | CONTINUE | 用户允许继续修复 |
| R5 | PASS | 0 | 无 | CONFIRMATION | 确认轮再次通过 |" \
  "| R2 | ASK_USER | 继续修复 | PR-001 | 2026-04-11 10:30 | 用户同意继续修复 |
| R3 | BLOCKED | 继续修复 | PR-001 | 2026-04-11 10:45 | 用户授权人工继续处置 |"
assert_no_failures "blocked may continue after explicit user decision"

run_policy_case \
  "1" \
  "| PR-001 | 产品 | P1 | BLOCKED | brief.md#影响范围 | design.md#待计划约束 | R2 | 仍在阻断 |" \
  "| R1 | FAIL | 1 | PR-001 | CONTINUE | 首轮发现问题 |
| R2 | FAIL | 1 | AR-001 | ASK_USER | 第二轮登记了错误的未关闭 issue |"
assert_has_failures "ledger and unresolved issue ids must align"
assert_failure_contains "ledger and unresolved issue ids must align" '状态为 BLOCKED，但未出现在 R2 的未关闭 Issue IDs'

run_policy_case \
  "0" \
  "| PR-001 | 产品 | P1 | RESOLVED | brief.md#影响范围 | design.md#待计划约束 | R2 | 已修复真实问题 |" \
  "| R1 | FAIL | 2 | PR-001,AR-999 | CONTINUE | 首轮多登记了一个不存在的 issue |
| R2 | PASS | 0 | 无 | CONFIRMATION | 确认轮通过 |"
assert_has_failures "ghost issue ids must be rejected"
assert_failure_contains "ghost issue ids must be rejected" '未关闭 Issue IDs.*AR-999.*未在审查问题台账登记'

echo "[PASS] review convergence gates"
