#!/bin/bash
# 代码安全硬拦截脚本
# 触发时机: PreToolUse:Write|Edit
# 职责: fail-fast 拦截（安全漏洞、占位符）+ 注释质量检查（warn/enforce）
# 版本: v3.2 2026-04-01
# 变更: SQL 注入检测扩展 f-string/template literal/String.format/.format()/%s 变体

INPUT=$(cat)
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/comment_quality.sh"

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null)

if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
    exit 0
fi

FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null)

# 只检查代码文件
if [[ ! "$FILE_PATH" =~ \.(js|ts|jsx|tsx|vue|py|java|go|rs|cpp|c|cs)$ ]]; then
    exit 0
fi

# 排除测试文件和测试基础设施
if [[ "$FILE_PATH" =~ (__tests__/|_test\.|\.test\.|\.spec\.|/tests?/|/specs?/|/test_helpers/|/testing/|/fixtures/|/factories/|/conftest\.py$) ]]; then
    exit 0
fi

# 提取内容
if [[ "$TOOL_NAME" == "Write" ]]; then
    CONTENT=$(echo "$TOOL_INPUT" | jq -r '.content // empty' 2>/dev/null)
else
    CONTENT=$(echo "$TOOL_INPUT" | jq -r '.new_string // empty' 2>/dev/null)
fi

[[ -z "$CONTENT" ]] && exit 0

IS_PYTHON=false
IS_JAVA=false
[[ "$FILE_PATH" =~ \.py$ ]] && IS_PYTHON=true
[[ "$FILE_PATH" =~ \.java$ ]] && IS_JAVA=true

COMMENT_MODE=$(comment_normalize_mode "${COMMENT_CHECK_MODE:-warn}")
VIOLATIONS=""

# ========== 安全类（硬拦截） ==========

# 硬编码密钥/密码（排除注释行）
CODE_ONLY=$(echo "$CONTENT" | grep -vE '^\s*(#|//|/\*|\*)')
if echo "$CODE_ONLY" | grep -qiE "(api_key|secret_key|password|token|private_key)\s*=\s*['\"][^'\"]{8,}['\"]" && ! echo "$FILE_PATH" | grep -qiE "(test|example|template|fixture)"; then
    VIOLATIONS+="❌ 硬编码密钥/密码 - 应使用环境变量或配置文件\n"
fi
# 拼接式硬编码（如 api_key = "sk-" + "xxxx"）
if echo "$CODE_ONLY" | grep -qiE "(api_key|secret_key|password|token|private_key)\s*=\s*['\"][^'\"]+['\"]\s*\+\s*['\"][^'\"]+['\"]" && ! echo "$FILE_PATH" | grep -qiE "(test|example|template|fixture)"; then
    VIOLATIONS+="❌ 拼接式硬编码密钥/密码 - 应使用环境变量或配置文件\n"
fi
# 环境变量默认值硬编码（如 os.environ.get(\"KEY\", \"sk-...\")）
if echo "$CODE_ONLY" | grep -qiE "os\.environ\.(get|getenv)\([^,]+,\s*['\"]sk-[^'\"]{8,}['\"]\s*\)" && ! echo "$FILE_PATH" | grep -qiE "(test|example|template|fixture)"; then
    VIOLATIONS+="❌ 环境变量默认值含硬编码密钥 - 生产密钥不得内置默认值\n"
fi

# SQL 注入风险 - 字符串拼接/插值 SQL
# 1) 通用：字符串拼接 SQL（"SELECT ..." + var 或 var + "SELECT ..."）
if echo "$CONTENT" | grep -qiE "[\"'\`].*\b(SELECT|INSERT|UPDATE|DELETE)\b.*[\"'\`]\s*\+|[\"'\`]\s*\+\s*[\"'\`].*\b(SELECT|INSERT|UPDATE|DELETE)\b"; then
    VIOLATIONS+="❌ 字符串拼接 SQL - SQL 注入风险！使用参数化查询\n"
fi
# 2) Python f-string（f"SELECT ... {var}"）
if $IS_PYTHON && echo "$CONTENT" | grep -qiE "f[\"'].*\b(SELECT|INSERT|UPDATE|DELETE)\b.*\{|f[\"'].*\{.*\b(SELECT|INSERT|UPDATE|DELETE)\b"; then
    VIOLATIONS+="❌ f-string SQL - SQL 注入风险！使用参数化查询\n"
fi
# 3) Python .format() / % 格式化
if $IS_PYTHON && echo "$CONTENT" | grep -qiE "[\"'].*\b(SELECT|INSERT|UPDATE|DELETE)\b.*[\"']\s*\.(format)\s*\(|[\"'].*\b(SELECT|INSERT|UPDATE|DELETE)\b.*[\"']\s*%\s*[(\"]"; then
    VIOLATIONS+="❌ .format()/%s SQL - SQL 注入风险！使用参数化查询\n"
fi
# 4) JS/TS template literal（`SELECT ... ${var}`）
if [[ "$FILE_PATH" =~ \.(js|ts|jsx|tsx|vue)$ ]] && echo "$CONTENT" | grep -qiE "\`[^\`]*\b(SELECT|INSERT|UPDATE|DELETE)\b[^\`]*\\\$\{"; then
    VIOLATIONS+="❌ Template literal SQL - SQL 注入风险！使用参数化查询\n"
fi
# 5) Java String.format
if $IS_JAVA && echo "$CONTENT" | grep -qiE "String\.format\s*\(\s*[\"'].*\b(SELECT|INSERT|UPDATE|DELETE)\b" && ! echo "$CONTENT" | grep -qiE "(@Param|PreparedStatement|JdbcTemplate|NamedParameterJdbcTemplate)"; then
    VIOLATIONS+="❌ String.format SQL - SQL 注入风险！使用参数化查询\n"
fi
# 6) Java 字符串拼接（无参数化查询保护）
if $IS_JAVA && echo "$CONTENT" | grep -qiE "[\"'].*\b(SELECT|INSERT|UPDATE|DELETE)\b.*[\"']\s*\+" && ! echo "$CONTENT" | grep -qiE "(@Param|PreparedStatement|JdbcTemplate|NamedParameterJdbcTemplate)"; then
    VIOLATIONS+="❌ 字符串拼接 SQL - SQL 注入风险！\n"
fi

# ========== Mock 检测（铁律：禁止用 Mock 伪造验收） ==========
# 注意：铁律禁止的是"用 Mock 伪造验收结论"，不是禁止所有 Mock。
# 测试辅助文件（conftest.py 等）已在上方路径排除中处理。
# 此处仅对业务代码中直接引入 Mock 发出警告，由开发者判断是否为伪造验收。

if echo "$CONTENT" | grep -qiE "(from unittest\.mock|from unittest import mock|import mock\b|MagicMock|@patch|jest\.mock|vi\.mock|@MockBean|mockk\()"; then
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo -e "Mock 使用提醒：$(basename "$FILE_PATH")" >&2
    echo -e "铁律要求验收结论必须基于真实依赖，禁止用 Mock 伪造验收。" >&2
    echo -e "如果此 Mock 用于单元测试隔离（非验收），可忽略此提醒。" >&2
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    # 降级为 warn，不再硬拦截。验收阶段的 Mock 伪造由 completion_check 检查。
fi

# ========== 占位符代码（硬拦截） ==========

# NotImplementedError
if echo "$CONTENT" | grep -qiE "(throw.*Error.*not.?implement|raise.*NotImplementedError)"; then
    VIOLATIONS+="❌ NotImplementedError - 请实现实际功能\n"
fi

# 明确的占位符标记
if echo "$CONTENT" | grep -qiE "(not\s+implement|todo:\s*implement|placeholder)" || echo "$CONTENT" | grep -qwi "stub"; then
    VIOLATIONS+="❌ 占位符代码 - 请实现实际功能\n"
fi

# ========== Python 可变默认参数（硬拦截） ==========

if $IS_PYTHON && echo "$CONTENT" | grep -qE "def\s+\w+\s*\([^)]*=\s*(\[\]|\{\}|set\(\))"; then
    VIOLATIONS+="❌ 可变默认参数 [] 或 {} - 应使用 None 作为默认值\n"
fi

# ========== 注释质量（增量检查） ==========

COMMENT_HEADER_REQUIRED=0
if [[ "$TOOL_NAME" == "Write" ]]; then
    COMMENT_HEADER_REQUIRED=1
fi

COMMENT_VIOLATIONS=$(comment_check_content "$FILE_PATH" "$CONTENT" "$COMMENT_HEADER_REQUIRED")
if [[ -n "$COMMENT_VIOLATIONS" ]]; then
    if [[ "$COMMENT_MODE" == "enforce" ]]; then
        VIOLATIONS+="❌ 注释质量不达标：\n$COMMENT_VIOLATIONS\n"
    else
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo -e "注释质量提醒：$(basename "$FILE_PATH")" >&2
        echo -e "模式：warn（可通过 COMMENT_CHECK_MODE=enforce 启用硬拦截）" >&2
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo -e "$COMMENT_VIOLATIONS" >&2
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    fi
fi

# 输出结果
if [[ -n "$VIOLATIONS" ]]; then
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo -e "代码安全检查：$(basename "$FILE_PATH")" >&2
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo -e "$VIOLATIONS" >&2
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    exit 2
fi

exit 0
