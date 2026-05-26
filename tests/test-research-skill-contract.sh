#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

RESEARCH_SKILL="$ROOT/shared/skills/research/SKILL.md"
ANALYSIS_FRAMEWORK="$ROOT/shared/skills/research/references/analysis-frameworks.md"
EVIDENCE_PACKAGE_GUIDE="$ROOT/shared/skills/research/references/evidence-package-guide.md"
PRESENTATION_FRAMEWORK="$ROOT/shared/skills/research/references/report-presentation-framework.md"
REPORT_TEMPLATE="$ROOT/shared/skills/research/projections/research-report-template.md"
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
assert_present '^allowed-tools: .*SendMessage' "$RESEARCH_SKILL"
assert_present '^allowed-tools: .*TeamDelete' "$RESEARCH_SKILL"
assert_absent '^allowed-tools: .*Agent' "$RESEARCH_SKILL"
assert_present 'agent teams 只用于 Step 2/3/5' "$RESEARCH_SKILL"
assert_present '召集 agent teams' "$RESEARCH_SKILL"
assert_absent 'Agent Team' "$RESEARCH_SKILL"
assert_present 'presentation_profile' "$RESEARCH_SKILL"
assert_present 'report-presentation-framework\.md' "$RESEARCH_SKILL"
assert_present 'evidence-package-guide\.md' "$RESEARCH_SKILL"
assert_present 'research-report-template\.md' "$RESEARCH_SKILL"
assert_absent 'research-(decision|understanding|audit|tech-selection|analysis|discovery|shared-header|shared-audit)-template\.md' "$RESEARCH_SKILL"
assert_absent 'deep-analysis-template\.md' "$RESEARCH_SKILL"

test -f "$PRESENTATION_FRAMEWORK" || fail "missing report-presentation-framework.md"
assert_present 'decision' "$PRESENTATION_FRAMEWORK"
assert_present 'understanding' "$PRESENTATION_FRAMEWORK"
assert_present 'audit' "$PRESENTATION_FRAMEWORK"
assert_present '答案层' "$PRESENTATION_FRAMEWORK"
assert_present '审计层' "$PRESENTATION_FRAMEWORK"

assert_present 'presentation_profile' "$ANALYSIS_FRAMEWORK"
assert_present 'evidence-package-guide\.md' "$ANALYSIS_FRAMEWORK"

test -f "$EVIDENCE_PACKAGE_GUIDE" || fail "missing evidence-package-guide.md"
test ! -e "$ROOT/shared/skills/research/references/deep-analysis-template.md" || fail "legacy deep-analysis-template.md should not exist"
python3 - "$EVIDENCE_PACKAGE_GUIDE" <<'PY'
import sys
from pathlib import Path

guide = Path(sys.argv[1])
text = guide.read_text(encoding="utf-8")
required = {
    "title": "# 证据包整理指南",
    "not_report_template": "不是报告模板",
    "source_targeting": "Source Targeting Package",
    "evidence_qualification": "Evidence Qualification",
    "judgment_calibration": "Judgment Calibration",
}
missing = [name for name, term in required.items() if term not in text]
if missing:
    raise SystemExit("evidence package guide missing contract terms: " + ", ".join(missing))
forbidden = ["Step 3 深度分析", "深度分析模板", "不可省略任何必填节"]
present = [term for term in forbidden if term in text]
if present:
    raise SystemExit("evidence package guide still uses misleading template wording: " + ", ".join(present))
PY

test -f "$REPORT_TEMPLATE" || fail "missing research report template"
python3 - "$ROOT" "$REPORT_TEMPLATE" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
template = Path(sys.argv[2])
projection_dir = template.parent
text = template.read_text(encoding="utf-8")

actual = sorted(path.name for path in projection_dir.glob("*.md"))
expected = ["research-report-template.md"]
if actual != expected:
    raise SystemExit(
        "research projections must collapse to one template; got: "
        + ", ".join(actual)
    )

required = [
    "## 模板使用边界",
    "## 1. 呈现模式头部",
    "### decision",
    "### understanding",
    "### audit",
    "## 2. 调研模式正文",
    "### selection",
    "### analysis",
    "### discovery",
    "## 3. 共享审计附录",
    "Report Self-Review",
    "User Confirmation Gate",
    "The terminal state",
]
missing = [term for term in required if term not in text]
if missing:
    raise SystemExit("research report template missing terms: " + ", ".join(missing))

legacy_names = [
    "research-decision-header-template.md",
    "research-understanding-header-template.md",
    "research-audit-header-template.md",
    "research-tech-selection-template.md",
    "research-analysis-template.md",
    "research-discovery-template.md",
    "research-shared-header-template.md",
    "research-shared-audit-appendix-template.md",
]
present_legacy = [name for name in legacy_names if name in text]
if present_legacy:
    raise SystemExit(
        "research report template still points to legacy split templates: "
        + ", ".join(present_legacy)
    )

if "..." in text:
    raise SystemExit("research report template contains vague ellipsis placeholders")
PY


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
