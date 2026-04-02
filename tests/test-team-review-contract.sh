#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in ${file#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected pattern in ${file#"$ROOT"/}: $pattern"
  fi
}

assert_count() {
  local expected="$1"
  local pattern="$2"
  local file="$3"
  local actual
  actual="$( (rg -n "$pattern" "$file" 2>/dev/null || true) | wc -l | tr -d ' ' )"
  [ "$actual" = "$expected" ] || fail "unexpected match count in ${file#"$ROOT"/}: $pattern (expected $expected, got $actual)"
}

extract_frontmatter_tools() {
  local file="$1"
  awk '
    /^tools:$/ { in_tools=1; next }
    in_tools && /^  - / { sub(/^  - /, "", $0); print; next }
    in_tools && $0 !~ /^  - / { exit }
  ' "$file"
}

assert_tool_present() {
  local tool="$1"
  local file="$2"
  if ! extract_frontmatter_tools "$file" | rg -n "^${tool}$" >/dev/null 2>&1; then
    fail "missing tool in ${file#"$ROOT"/}: $tool"
  fi
}

assert_tool_absent() {
  local tool="$1"
  local file="$2"
  if extract_frontmatter_tools "$file" | rg -n "^${tool}$" >/dev/null 2>&1; then
    fail "unexpected tool in ${file#"$ROOT"/}: $tool"
  fi
}

extract_allowed_tools() {
  local file="$1"
  sed -nE 's/^allowed-tools:[[:space:]]*(.*)$/\1/p' "$file" \
    | tr ',' '\n' \
    | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' \
    | sed '/^$/d'
}

assert_allowed_tool_present() {
  local tool="$1"
  local file="$2"
  if ! extract_allowed_tools "$file" | rg -n "^${tool}$" >/dev/null 2>&1; then
    fail "missing allowed-tool in ${file#"$ROOT"/}: $tool"
  fi
}

test -f "$ROOT/shared/protocols/team-review-protocol.md" || fail "missing shared/protocols/team-review-protocol.md"
test -f "$ROOT/shared/agents/cross-review-lead.md" || fail "missing shared/agents/cross-review-lead.md"
test -f "$ROOT/shared/agents/cross-reviewer.md" || fail "missing shared/agents/cross-reviewer.md"

assert_present 'R2\.5' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present 'R1' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present 'R2' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present 'R3' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present '仅 FAIL 视角' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present 'fix_mode=user_directed' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present 'AskUserQuestion' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present 'active 视角' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present '回退到单子代理顺序模式' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present '\[FALLBACK-MODE\]' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present 'challenge_result' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present 'challenge_response' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present 'lead_decision' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present 'challenge_id' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present 'target_issue_id' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present 'challenger_perspective' "$ROOT/shared/protocols/team-review-protocol.md"
assert_present 'target_perspective' "$ROOT/shared/protocols/team-review-protocol.md"

assert_tool_present 'Write' "$ROOT/shared/agents/cross-review-lead.md"
assert_tool_present 'SendMessage' "$ROOT/shared/agents/cross-review-lead.md"
assert_tool_present 'TaskGet' "$ROOT/shared/agents/cross-review-lead.md"
assert_tool_present 'TaskList' "$ROOT/shared/agents/cross-review-lead.md"
assert_tool_absent 'Write' "$ROOT/shared/agents/cross-reviewer.md"
assert_tool_present 'SendMessage' "$ROOT/shared/agents/cross-reviewer.md"
assert_tool_present 'TaskGet' "$ROOT/shared/agents/cross-reviewer.md"
assert_present 'challenge_id' "$ROOT/shared/agents/cross-reviewer.md"
assert_present 'target_issue_id' "$ROOT/shared/agents/cross-reviewer.md"

assert_present 'protocols/team-review-protocol.md' "$ROOT/shared/skills/product/SKILL.md"
assert_present 'R2\.5' "$ROOT/shared/skills/product/SKILL.md"
assert_present 'fix_mode=user_directed' "$ROOT/shared/skills/product/SKILL.md"
assert_present 'AskUserQuestion' "$ROOT/shared/skills/product/SKILL.md"
assert_present '仅对 FAIL 视角重审' "$ROOT/shared/skills/product/SKILL.md"
assert_allowed_tool_present 'TeamCreate' "$ROOT/shared/skills/product/SKILL.md"
assert_allowed_tool_present 'TeamDelete' "$ROOT/shared/skills/product/SKILL.md"
assert_allowed_tool_present 'SendMessage' "$ROOT/shared/skills/product/SKILL.md"
assert_allowed_tool_present 'TaskCreate' "$ROOT/shared/skills/product/SKILL.md"
assert_allowed_tool_present 'TaskUpdate' "$ROOT/shared/skills/product/SKILL.md"
assert_allowed_tool_present 'TaskList' "$ROOT/shared/skills/product/SKILL.md"
assert_allowed_tool_present 'TaskGet' "$ROOT/shared/skills/product/SKILL.md"
assert_present 'Team 模式.*发送结构化消息给 Review Lead' "$ROOT/shared/skills/product/references/prd-reviewer-prompt.md"
assert_present 'fallback.*直接写' "$ROOT/shared/skills/product/references/prd-reviewer-prompt.md"
assert_present '\| Issue ID \| Severity \| 状态 \|' "$ROOT/shared/skills/product/references/prd-reviewer-prompt.md"
assert_present 'Team 模式.*发送结构化消息给 Review Lead' "$ROOT/shared/skills/product/references/architect-reviewer-prompt.md"
assert_present 'fallback.*直接写' "$ROOT/shared/skills/product/references/architect-reviewer-prompt.md"
assert_present '\| Issue ID \| Severity \| 状态 \|' "$ROOT/shared/skills/product/references/architect-reviewer-prompt.md"
assert_present 'Team 模式.*发送结构化消息给 Review Lead' "$ROOT/shared/skills/product/references/tester-reviewer-prompt.md"
assert_present 'fallback.*直接写' "$ROOT/shared/skills/product/references/tester-reviewer-prompt.md"
assert_present '\| Issue ID \| Severity \| 状态 \|' "$ROOT/shared/skills/product/references/tester-reviewer-prompt.md"

assert_present 'protocols/team-review-protocol.md' "$ROOT/shared/skills/design/SKILL.md"
assert_present 'R2\.5' "$ROOT/shared/skills/design/SKILL.md"
assert_present 'fix_mode=user_directed' "$ROOT/shared/skills/design/SKILL.md"
assert_present 'AskUserQuestion' "$ROOT/shared/skills/design/SKILL.md"
assert_present '仅对 FAIL 视角重审' "$ROOT/shared/skills/design/SKILL.md"
assert_allowed_tool_present 'TeamCreate' "$ROOT/shared/skills/design/SKILL.md"
assert_allowed_tool_present 'TeamDelete' "$ROOT/shared/skills/design/SKILL.md"
assert_allowed_tool_present 'SendMessage' "$ROOT/shared/skills/design/SKILL.md"
assert_allowed_tool_present 'TaskCreate' "$ROOT/shared/skills/design/SKILL.md"
assert_allowed_tool_present 'TaskUpdate' "$ROOT/shared/skills/design/SKILL.md"
assert_allowed_tool_present 'TaskList' "$ROOT/shared/skills/design/SKILL.md"
assert_allowed_tool_present 'TaskGet' "$ROOT/shared/skills/design/SKILL.md"
assert_present 'Team 模式.*发送结构化消息给 Review Lead' "$ROOT/shared/skills/design/references/design-reviewer-prompt.md"
assert_present 'fallback.*直接写' "$ROOT/shared/skills/design/references/design-reviewer-prompt.md"
assert_present 'fallback.*审查结论' "$ROOT/shared/skills/design/references/design-reviewer-prompt.md"
assert_present '\| Issue ID \| Severity \| 状态 \|' "$ROOT/shared/skills/design/references/design-reviewer-prompt.md"
assert_present 'Team 模式.*发送结构化消息给 Review Lead' "$ROOT/shared/skills/design/references/design-product-reviewer-prompt.md"
assert_present 'fallback.*直接写' "$ROOT/shared/skills/design/references/design-product-reviewer-prompt.md"
assert_present 'fallback.*审查结论' "$ROOT/shared/skills/design/references/design-product-reviewer-prompt.md"
assert_present '\| Issue ID \| Severity \| 状态 \|' "$ROOT/shared/skills/design/references/design-product-reviewer-prompt.md"
assert_present 'Team 模式.*发送结构化消息给 Review Lead' "$ROOT/shared/skills/design/references/design-test-reviewer-prompt.md"
assert_present 'fallback.*直接写' "$ROOT/shared/skills/design/references/design-test-reviewer-prompt.md"
assert_present 'fallback.*审查结论' "$ROOT/shared/skills/design/references/design-test-reviewer-prompt.md"
assert_present '\| Issue ID \| Severity \| 状态 \|' "$ROOT/shared/skills/design/references/design-test-reviewer-prompt.md"

assert_count 3 '^\| Issue ID \| Severity \| 状态 \| 维度 \| 发现 \| 证据 \| 建议承接位置 \|$' "$ROOT/shared/skills/product/references/templates/product-cross-review-template.md"
assert_count 1 '^## 横向质疑记录$' "$ROOT/shared/skills/product/references/templates/product-cross-review-template.md"
assert_count 3 '^\| Issue ID \| Severity \| 状态 \| 维度 \| 发现 \| 证据 \| 建议承接位置 \|$' "$ROOT/shared/skills/design/references/templates/design-cross-review-template.md"
assert_count 1 '^## 横向质疑记录$' "$ROOT/shared/skills/design/references/templates/design-cross-review-template.md"
assert_present '\[DISPUTED\]' "$ROOT/shared/skills/product/references/templates/prd-template.md"
assert_present '\[DISPUTED\]' "$ROOT/shared/skills/design/references/templates/design-template.md"

echo "[PASS] team review contract"
