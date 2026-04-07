#!/usr/bin/env bash
# 文档格式规范自动检查
# 验证 shared/reference/文档规范.md 中可自动化的规则已下沉为可执行检查
# 规则源: shared/reference/文档规范.md

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

PASS=0
WARN=0
TOTAL=0

pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf '[PASS] %s\n' "$*"; }
warn() { WARN=$((WARN + 1)); TOTAL=$((TOTAL + 1)); printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

# --- 规则 1: ** 结构性滥用检测（SKILL.md + references/） ---
# 禁止用 ** 承担结构职责：如 **定义**：、**示例**：、1. **步骤**：

BOLD_ABUSE_FILES=""
for skill_dir in "$ROOT"/shared/skills/*/; do
    [ -d "$skill_dir" ] || continue

    # 检查 SKILL.md 和 references/ 下的 .md 文件
    while IFS= read -r md_file; do
        [ -f "$md_file" ] || continue
        # 在代码围栏外检测 **标签**：模式
        abuse_lines=$(awk '
            BEGIN { in_fence = 0 }
            /^```/ { in_fence = !in_fence; next }
            in_fence { next }
            /\*\*[^*]+\*\*[：:]/ {
                # 排除表格中的合理加粗（如 | **PASS** | ）
                if ($0 ~ /^\|/) next
                print NR ":" $0
            }
        ' "$md_file" 2>/dev/null || true)

        if [ -n "$abuse_lines" ]; then
            rel_path="${md_file#"$ROOT"/}"
            BOLD_ABUSE_FILES="${BOLD_ABUSE_FILES:+$BOLD_ABUSE_FILES
}${rel_path}"
        fi
    done < <(find "$skill_dir" -name '*.md' -not -path '*/templates/*' -type f 2>/dev/null)
done

if [ -z "$BOLD_ABUSE_FILES" ]; then
    pass "** 结构性滥用：skill 文档无结构性加粗"
else
    abuse_count=$(printf '%s\n' "$BOLD_ABUSE_FILES" | sed '/^$/d' | wc -l | tr -d ' ')
    warn "** 结构性滥用：${abuse_count} 个 skill 文档存在 **标签**：模式"
fi

# --- 规则 2: 报告文件命名格式 ---
# 报告文件应为 YYYY-MM-DD_报告类型.md

REPORT_DIR="$ROOT/docs/reports"
BAD_NAMES=""
if [ -d "$REPORT_DIR" ]; then
    while IFS= read -r report_file; do
        [ -f "$report_file" ] || continue
        basename_file=$(basename "$report_file")
        # 跳过 README 等非报告文件
        [[ "$basename_file" == "README"* ]] && continue
        if ! printf '%s' "$basename_file" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}_.*\.md$'; then
            BAD_NAMES="${BAD_NAMES:+$BAD_NAMES
}${basename_file}"
        fi
    done < <(find "$REPORT_DIR" -maxdepth 2 -name '*.md' -type f 2>/dev/null)
fi

if [ -z "$BAD_NAMES" ]; then
    pass "报告命名规范：所有报告文件符合 YYYY-MM-DD_类型.md 格式"
else
    bad_count=$(printf '%s\n' "$BAD_NAMES" | sed '/^$/d' | wc -l | tr -d ' ')
    warn "报告命名规范：${bad_count} 个报告文件不符合 YYYY-MM-DD_类型.md 格式"
fi

# --- 规则 3: 术语一致性（排除项 vs 本期不交付 不混用） ---
# 在 PRD 的 ## 排除项 章节中不应出现 "本期不交付"

TERM_VIOLATIONS=""
while IFS= read -r prd_file; do
    [ -f "$prd_file" ] || continue
    # 提取排除项章节内容
    exclusion_section=$(awk '
        /^## 全局排除项/ { in_section=1; next }
        in_section && /^## / { exit }
        in_section { print }
    ' "$prd_file" 2>/dev/null || true)

    if [ -n "$exclusion_section" ]; then
        if printf '%s\n' "$exclusion_section" | grep -q '本期不交付' 2>/dev/null; then
            rel_path="${prd_file#"$ROOT"/}"
            TERM_VIOLATIONS="${TERM_VIOLATIONS:+$TERM_VIOLATIONS
}${rel_path}"
        fi
    fi
done < <(find "$ROOT/docs" -name 'prd.md' -type f 2>/dev/null)

if [ -z "$TERM_VIOLATIONS" ]; then
    pass "术语一致性：排除项章节无「本期不交付」混用"
else
    violation_count=$(printf '%s\n' "$TERM_VIOLATIONS" | sed '/^$/d' | wc -l | tr -d ' ')
    warn "术语一致性：${violation_count} 个 PRD 在排除项章节混用「本期不交付」"
fi

# --- 汇总 ---
echo ""
echo "文档格式规范检查：${PASS} pass, ${WARN} warn / ${TOTAL} total"
if [ "$WARN" -gt 0 ]; then
    echo "(warn 项为软预算提醒，不阻断)"
fi
