#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

RESEARCH_SKILL="$ROOT/shared/skills/research/SKILL.md"
ANALYSIS_FRAMEWORK="$ROOT/shared/skills/research/references/analysis-frameworks.md"
PRESENTATION_FRAMEWORK="$ROOT/shared/skills/research/references/report-presentation-framework.md"
DECISION_TEMPLATE="$ROOT/shared/skills/research/projections/research-decision-header-template.md"
UNDERSTANDING_TEMPLATE="$ROOT/shared/skills/research/projections/research-understanding-header-template.md"
AUDIT_TEMPLATE="$ROOT/shared/skills/research/projections/research-audit-header-template.md"
LEGACY_SHARED_HEADER_TEMPLATE="$ROOT/shared/skills/research/projections/research-shared-header-template.md"
SHARED_AUDIT_APPENDIX_TEMPLATE="$ROOT/shared/skills/research/projections/research-shared-audit-appendix-template.md"
RESEARCH_CHECK="$ROOT/shared/skills/research/scripts/completion_check.sh"

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

run_check() {
  local fixture_root="$1"
  local transcript_path="$fixture_root/transcript.log"
  local payload

  payload="$(jq -nc \
    --arg cwd "$fixture_root" \
    --arg sid "research-test" \
    --arg tp "$transcript_path" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp}')"

  CHECK_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/org-research-check.XXXXXX")"
  if bash "$RESEARCH_CHECK" >"$CHECK_OUTPUT" 2>&1 <<<"$payload"; then
    CHECK_STATUS=0
  else
    CHECK_STATUS=$?
  fi
}

assert_check_passes() {
  local label="$1"
  if [ "${CHECK_STATUS:-1}" -ne 0 ]; then
    cat "$CHECK_OUTPUT" >&2
    fail "${label}: expected completion_check to pass"
  fi
}

assert_check_fails_with() {
  local label="$1"
  local pattern="$2"
  if [ "${CHECK_STATUS:-0}" -eq 0 ]; then
    cat "$CHECK_OUTPUT" >&2
    fail "${label}: expected completion_check to fail"
  fi
  rg -n "$pattern" "$CHECK_OUTPUT" >/dev/null 2>&1 || {
    cat "$CHECK_OUTPUT" >&2
    fail "${label}: missing failure pattern: $pattern"
  }
}

FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/org-research-fixture.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT" "${CHECK_OUTPUT:-}"' EXIT

test -f "$RESEARCH_SKILL" || fail "missing research skill"
assert_present '^allowed-tools: .*TeamCreate' "$RESEARCH_SKILL"
assert_absent '^allowed-tools: .*Agent' "$RESEARCH_SKILL"
assert_present 'TeamCreate 只用于 Step 2/3/5' "$RESEARCH_SKILL"
assert_present '召集 TeamCreate 协作团队' "$RESEARCH_SKILL"
assert_absent 'Agent Team' "$RESEARCH_SKILL"
assert_present 'presentation_profile' "$RESEARCH_SKILL"
assert_present '调研目的' "$RESEARCH_SKILL"
assert_present '目标读者' "$RESEARCH_SKILL"
assert_present '读后动作' "$RESEARCH_SKILL"
assert_present 'report-presentation-framework\.md' "$RESEARCH_SKILL"
assert_present 'research-decision-header-template\.md' "$RESEARCH_SKILL"
assert_present 'research-understanding-header-template\.md' "$RESEARCH_SKILL"
assert_present 'research-audit-header-template\.md' "$RESEARCH_SKILL"
assert_present 'research-shared-audit-appendix-template\.md' "$RESEARCH_SKILL"
assert_absent "模板见 \`references/templates/research-shared-header-template\\.md\` 及对应模式模板" "$RESEARCH_SKILL"

test -f "$PRESENTATION_FRAMEWORK" || fail "missing report-presentation-framework.md"
assert_present 'decision' "$PRESENTATION_FRAMEWORK"
assert_present 'understanding' "$PRESENTATION_FRAMEWORK"
assert_present 'audit' "$PRESENTATION_FRAMEWORK"
assert_present '答案层' "$PRESENTATION_FRAMEWORK"
assert_present '审计层' "$PRESENTATION_FRAMEWORK"

assert_present 'presentation_profile' "$ANALYSIS_FRAMEWORK"

for template in "$DECISION_TEMPLATE" "$UNDERSTANDING_TEMPLATE" "$AUDIT_TEMPLATE"; do
  test -f "$template" || fail "missing template: ${template#"$ROOT"/}"
done
test -f "$LEGACY_SHARED_HEADER_TEMPLATE" || fail "missing legacy shared header template"
test -f "$SHARED_AUDIT_APPENDIX_TEMPLATE" || fail "missing shared audit appendix template"

assert_present '^## 这次要回答的问题$' "$DECISION_TEMPLATE"
assert_present '^## 当前判断$' "$DECISION_TEMPLATE"
assert_present '^## 决定性理由$' "$DECISION_TEMPLATE"
assert_present '^## 最大风险与保留意见$' "$DECISION_TEMPLATE"
assert_present '^## 建议动作$' "$DECISION_TEMPLATE"

assert_present '^## 这是什么$' "$UNDERSTANDING_TEMPLATE"
assert_present '^## 为什么值得关注$' "$UNDERSTANDING_TEMPLATE"
assert_present '^## 核心机制与关键差异$' "$UNDERSTANDING_TEMPLATE"
assert_present '^## 适用边界$' "$UNDERSTANDING_TEMPLATE"
assert_present '^## 如果只记住三件事$' "$UNDERSTANDING_TEMPLATE"

assert_present '^## 当前判断$' "$AUDIT_TEMPLATE"
assert_present '^## 关键论点挑战表$' "$AUDIT_TEMPLATE"
assert_present '^## 覆盖证明摘要$' "$AUDIT_TEMPLATE"
assert_absent '^## 独立挑战记录$' "$AUDIT_TEMPLATE"
assert_absent '^## 检索路径与覆盖证明$' "$AUDIT_TEMPLATE"

assert_present '兼容入口' "$LEGACY_SHARED_HEADER_TEMPLATE"
assert_present 'report-presentation-framework\.md' "$LEGACY_SHARED_HEADER_TEMPLATE"
assert_absent "默认按 \`audit\`" "$LEGACY_SHARED_HEADER_TEMPLATE"
assert_absent '^> 呈现模式：audit$' "$LEGACY_SHARED_HEADER_TEMPLATE"

assert_present '^## 独立挑战记录$' "$SHARED_AUDIT_APPENDIX_TEMPLATE"
assert_present '^## 检索路径与覆盖证明$' "$SHARED_AUDIT_APPENDIX_TEMPLATE"
assert_present '^## 项目上下文$' "$SHARED_AUDIT_APPENDIX_TEMPLATE"

test -f "$RESEARCH_CHECK" || fail "missing research completion_check.sh"

mkdir -p \
  "$FIXTURE_ROOT/docs/research-decision-valid" \
  "$FIXTURE_ROOT/docs/research-decision-invalid" \
  "$FIXTURE_ROOT/docs/research-understanding-valid" \
  "$FIXTURE_ROOT/docs/research-understanding-invalid" \
  "$FIXTURE_ROOT/docs/research-audit-valid" \
  "$FIXTURE_ROOT/docs/research-audit-invalid"
printf '%s\n' 'docs/research-decision-valid/research-report.md' > "$FIXTURE_ROOT/transcript.log"

cat > "$FIXTURE_ROOT/docs/research-decision-valid/research-report.md" <<'EOF'
# 示例调研报告

> 调研模式：analysis
> 呈现模式：decision

## 这次要回答的问题
- 核心问题：是否值得采用

## 当前判断
- 当前结论：条件推荐

## 决定性理由
- 理由 1：与当前目标直接匹配

## 最大风险与保留意见
- 最大风险：证据还需补强

## 建议动作
- 现在该做什么：小范围试点

## 独立挑战记录
- 挑战点：证据样本仍偏少

## 检索路径与覆盖证明
- 已排除候选：无

## 项目上下文
- 技术栈：shell + markdown
EOF

run_check "$FIXTURE_ROOT"
assert_check_passes "valid decision report"

printf '%s\n' 'docs/research-decision-invalid/research-report.md' > "$FIXTURE_ROOT/transcript.log"
cat > "$FIXTURE_ROOT/docs/research-decision-invalid/research-report.md" <<'EOF'
# 示例调研报告

> 调研模式：analysis
> 呈现模式：decision

## 这次要回答的问题
- 核心问题：是否值得采用

## 检索路径与覆盖证明
- 已排除候选：无

## 当前判断
- 当前结论：条件推荐
EOF

run_check "$FIXTURE_ROOT"
assert_check_fails_with "invalid decision order" '建议动作|章节顺序'

printf '%s\n' 'docs/research-understanding-valid/research-report.md' > "$FIXTURE_ROOT/transcript.log"
cat > "$FIXTURE_ROOT/docs/research-understanding-valid/research-report.md" <<'EOF'
# 示例调研报告

> 调研模式：discovery
> 呈现模式：understanding

## 这是什么
- 当前对象/主题：Hermes Agent

## 为什么值得关注
- 关键价值：帮助理解对象定位

## 核心机制与关键差异
| 维度 | 内容 |
|------|------|
| 核心机制 | 多信号交叉定位 |

## 适用边界
- 适用场景：需要先建立认知

## 如果只记住三件事
- 它不是通用代码助手

## 独立挑战记录
- 挑战点：名称仍可能混淆

## 检索路径与覆盖证明
- 已查对象类型：repo / skill

## 项目上下文
- 技术栈：shell + markdown
EOF

run_check "$FIXTURE_ROOT"
assert_check_passes "valid understanding report"

printf '%s\n' 'docs/research-understanding-invalid/research-report.md' > "$FIXTURE_ROOT/transcript.log"
cat > "$FIXTURE_ROOT/docs/research-understanding-invalid/research-report.md" <<'EOF'
# 示例调研报告

> 调研模式：discovery
> 呈现模式：understanding

## 这是什么
- 当前对象/主题：Hermes Agent

## 为什么值得关注
- 关键价值：帮助理解对象定位

## 适用边界
- 适用场景：需要先建立认知

## 核心机制与关键差异
| 维度 | 内容 |
|------|------|
| 核心机制 | 多信号交叉定位 |

## 如果只记住三件事
- 它不是通用代码助手

## 独立挑战记录
- 挑战点：名称仍可能混淆

## 检索路径与覆盖证明
- 已查对象类型：repo / skill

## 项目上下文
- 技术栈：shell + markdown
EOF

run_check "$FIXTURE_ROOT"
assert_check_fails_with "invalid understanding order" '核心机制与关键差异|章节顺序'

printf '%s\n' 'docs/research-audit-valid/research-report.md' > "$FIXTURE_ROOT/transcript.log"
cat > "$FIXTURE_ROOT/docs/research-audit-valid/research-report.md" <<'EOF'
# 示例调研报告

> 调研模式：selection
> 呈现模式：audit

## 当前判断
- 当前结论：条件推荐

## 关键论点挑战表
| 对象/论点 | 最强支持证据 | 最强反方挑战 | 当前判断 | 结论稳健性 |
|-----------|-------------|-------------|---------|-----------|
| A | 生产样例 | 独立验证偏少 | 条件推荐 | 中 |

## 独立挑战记录
- 挑战点：社区案例仍不足

## 检索路径与覆盖证明
- 已查入口：官方文档 / 仓库

## 项目上下文
- 技术栈：shell + markdown
EOF

run_check "$FIXTURE_ROOT"
assert_check_passes "valid audit report"

printf '%s\n' 'docs/research-audit-invalid/research-report.md' > "$FIXTURE_ROOT/transcript.log"
cat > "$FIXTURE_ROOT/docs/research-audit-invalid/research-report.md" <<'EOF'
# 示例调研报告

> 调研模式：selection
> 呈现模式：audit

## 当前判断
- 当前结论：条件推荐

## 关键论点挑战表
| 对象/论点 | 最强支持证据 | 最强反方挑战 | 当前判断 | 结论稳健性 |
|-----------|-------------|-------------|---------|-----------|
| A | 生产样例 | 独立验证偏少 | 条件推荐 | 中 |

## 检索路径与覆盖证明
- 已查入口：官方文档 / 仓库

## 项目上下文
- 技术栈：shell + markdown
EOF

run_check "$FIXTURE_ROOT"
assert_check_fails_with "invalid audit missing challenge log" '独立挑战记录'

echo "[PASS] research skill contract"
