#!/bin/bash
# 任务完成验证脚本（监工 - 机械检查层）
# 触发时机: TaskCompleted
# 功能: 跑测试 + lint + 复杂度 + 注释质量 + 占位符扫描，未通过则阻止任务完成
# 版本: v1.2 2026-03-24

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/comment_quality.sh"

[ -z "$CWD" ] || [ ! -d "$CWD" ] && exit 0

cd "$CWD" || exit 0

# 非 git 仓库跳过
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    exit 0
fi

# 无代码改动跳过（含未跟踪文件）
CODE_DIFF=$({
    git diff --name-only HEAD 2>/dev/null || true
    git diff --name-only 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null || true
} | grep -E '\.(py|js|ts|jsx|tsx|vue|go|rs|java|cpp|c|cs)$' | sort -u)
[ -z "$CODE_DIFF" ] && exit 0

FAILURES=""

# ========== 测试 ==========

run_tests() {
    if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "setup.cfg" ]; then
        local -a PYTEST_CMD=()

        if command -v pytest >/dev/null 2>&1 && PYTHONDONTWRITEBYTECODE=1 pytest --version >/dev/null 2>&1; then
            PYTEST_CMD=(pytest)
        elif command -v python3 >/dev/null 2>&1 && PYTHONDONTWRITEBYTECODE=1 python3 -B -m pytest --version >/dev/null 2>&1; then
            PYTEST_CMD=(python3 -B -m pytest)
        elif command -v python >/dev/null 2>&1 && PYTHONDONTWRITEBYTECODE=1 python -B -m pytest --version >/dev/null 2>&1; then
            PYTEST_CMD=(python -B -m pytest)
        else
            return
        fi

        TEST_OUTPUT=$(PYTHONDONTWRITEBYTECODE=1 "${PYTEST_CMD[@]}" --tb=short -q -p no:cacheprovider 2>&1)
        if [ $? -ne 0 ]; then
            FAILURES+="测试失败:\n$TEST_OUTPUT\n\n"
        fi
        return
    fi

    if [ -f "package.json" ]; then
        if grep -q '"test"' package.json 2>/dev/null; then
            TEST_OUTPUT=$(npm test -- --watchAll=false 2>&1)
            if [ $? -ne 0 ]; then
                FAILURES+="测试失败:\n$(echo "$TEST_OUTPUT" | tail -30)\n\n"
            fi
            return
        fi
    fi

    if [ -f "go.mod" ]; then
        if command -v go >/dev/null 2>&1; then
            TEST_OUTPUT=$(go test ./... 2>&1)
            if [ $? -ne 0 ]; then
                FAILURES+="测试失败:\n$TEST_OUTPUT\n\n"
            fi
            return
        fi
    fi

    if [ -f "Cargo.toml" ]; then
        if command -v cargo >/dev/null 2>&1; then
            TEST_OUTPUT=$(cargo test 2>&1)
            if [ $? -ne 0 ]; then
                FAILURES+="测试失败:\n$(echo "$TEST_OUTPUT" | tail -30)\n\n"
            fi
            return
        fi
    fi

    if [ -f "pom.xml" ]; then
        if command -v mvn >/dev/null 2>&1; then
            TEST_OUTPUT=$(mvn test -q 2>&1)
            if [ $? -ne 0 ]; then
                FAILURES+="测试失败（Maven）:\n$(echo "$TEST_OUTPUT" | tail -30)\n\n"
            fi
            return
        fi
    fi

    if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
        if command -v gradle >/dev/null 2>&1; then
            TEST_OUTPUT=$(gradle test --quiet 2>&1)
            if [ $? -ne 0 ]; then
                FAILURES+="测试失败（Gradle）:\n$(echo "$TEST_OUTPUT" | tail -30)\n\n"
            fi
            return
        fi
    fi
}

run_tests

# ========== Lint ==========

run_lint() {
    # Python
    if echo "$CODE_DIFF" | grep -qE '\.py$'; then
        if command -v ruff >/dev/null 2>&1; then
            LINT_OUTPUT=$(ruff check . 2>&1)
            if [ $? -ne 0 ]; then
                FAILURES+="Lint 失败（ruff）:\n$(echo "$LINT_OUTPUT" | head -20)\n\n"
            fi
        fi
    fi

    # JS/TS
    if echo "$CODE_DIFF" | grep -qE '\.(js|ts|jsx|tsx|vue)$'; then
        if [ -f "node_modules/.bin/eslint" ]; then
            LINT_OUTPUT=$(node_modules/.bin/eslint . 2>&1)
            if [ $? -ne 0 ]; then
                FAILURES+="Lint 失败（eslint）:\n$(echo "$LINT_OUTPUT" | head -20)\n\n"
            fi
        fi
    fi

    # Java（编译检查）
    if echo "$CODE_DIFF" | grep -qE '\.java$'; then
        if [ -f "pom.xml" ] && command -v mvn >/dev/null 2>&1; then
            COMPILE_OUTPUT=$(mvn compile -q 2>&1)
            if [ $? -ne 0 ]; then
                FAILURES+="编译失败（Maven）:\n$(echo "$COMPILE_OUTPUT" | head -20)\n\n"
            fi
        elif { [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; } && command -v gradle >/dev/null 2>&1; then
            COMPILE_OUTPUT=$(gradle compileJava --quiet 2>&1)
            if [ $? -ne 0 ]; then
                FAILURES+="编译失败（Gradle）:\n$(echo "$COMPILE_OUTPUT" | head -20)\n\n"
            fi
        fi
    fi

    # Go
    if echo "$CODE_DIFF" | grep -qE '\.go$'; then
        if command -v go >/dev/null 2>&1; then
            VET_OUTPUT=$(go vet ./... 2>&1)
            if [ $? -ne 0 ]; then
                FAILURES+="Lint 失败（go vet）:\n$VET_OUTPUT\n\n"
            fi
        fi
    fi
}

run_lint

# ========== 复杂度检查 ==========

complexity_collect_files() {
    local scope="$1"
    local files file

    if [ "$scope" = "all" ]; then
        files=$(git ls-files | grep -E '\.(py|js|ts|jsx|tsx|vue|java)$' || true)
    else
        files="$CODE_DIFF"
    fi

    [ -z "$files" ] && return

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        [ -f "$file" ] || continue
        comment_is_test_file "$file" && continue
        if echo "$file" | grep -qE '\.(py|js|ts|jsx|tsx|vue|java)$'; then
            echo "$file"
        fi
    done <<< "$files" | sort -u
}

complexity_report_violation() {
    local mode="$1"
    local label="$2"
    local output="$3"

    if [ "$mode" = "enforce" ]; then
        FAILURES+="复杂度检查失败（${label}）:\n$(echo "$output" | head -30)\n\n"
    else
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo -e "复杂度提醒：${label}（warn 模式）" >&2
        echo -e "可通过 COMPLEXITY_CHECK_MODE=enforce 启用硬拦截" >&2
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo -e "$(echo "$output" | head -30)" >&2
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    fi
}

complexity_report_missing_tool() {
    local mode="$1"
    local allow_missing="$2"
    local label="$3"
    local reason="$4"

    if [ "$mode" = "enforce" ] && [ "$allow_missing" != "1" ]; then
        FAILURES+="复杂度检查不可执行（${label}）:\n${reason}\n可临时设置 COMPLEXITY_ALLOW_MISSING_TOOLS=1 以告警放行\n\n"
    else
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo -e "复杂度提醒：${label} 缺少工具/配置（warn 或已豁免）" >&2
        echo -e "$reason" >&2
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    fi
}

complexity_is_tooling_issue() {
    local label="$1"
    local output="$2"

    case "$label" in
        "JS/TS CC(eslint complexity)")
            if echo "$output" | grep -qiE "couldn't find.*configuration|no configuration found|configuration file.*not found|could not find config|No ESLint configuration found"; then
                return 0
            fi
            ;;
        "Java CC(PMD)")
            if echo "$output" | grep -qiE "No plugin found for prefix 'pmd'|Could not find goal .*pmd|Plugin .*maven-pmd-plugin.* not found|Unknown lifecycle phase .*pmd:check"; then
                return 0
            fi
            ;;
        "Java CC(Gradle PMD)")
            if echo "$output" | grep -qiE "Task 'pmdMain' not found|Plugin with id 'pmd' not found|Could not find method pmd"; then
                return 0
            fi
            ;;
    esac

    return 1
}

run_complexity_quality() {
    local complexity_mode complexity_scope allow_missing
    local complexity_files py_files js_files java_files
    local output rc old_ifs
    local -a py_arr js_arr
    local -a eslint_cmd=()

    complexity_mode=$(comment_normalize_mode "${COMPLEXITY_CHECK_MODE:-warn}")
    complexity_scope=$(comment_normalize_scope "${COMPLEXITY_SCOPE:-changed}")
    allow_missing="${COMPLEXITY_ALLOW_MISSING_TOOLS:-0}"

    complexity_files=$(complexity_collect_files "$complexity_scope")
    [ -z "$complexity_files" ] && return

    py_files=$(printf '%s\n' "$complexity_files" | grep -E '\.py$' || true)
    js_files=$(printf '%s\n' "$complexity_files" | grep -E '\.(js|ts|jsx|tsx|vue)$' || true)
    java_files=$(printf '%s\n' "$complexity_files" | grep -E '\.java$' || true)

    # Python: CC <= 10（ruff C901）
    if [ -n "$py_files" ]; then
        if command -v ruff >/dev/null 2>&1; then
            old_ifs="$IFS"
            IFS=$'\n'
            py_arr=($py_files)
            IFS="$old_ifs"
            output=$(ruff check --select C901 "${py_arr[@]}" 2>&1)
            rc=$?
            if [ $rc -ne 0 ]; then
                complexity_report_violation "$complexity_mode" "Python CC(C901)" "$output"
            fi
        else
            complexity_report_missing_tool "$complexity_mode" "$allow_missing" "Python CC(C901)" "未检测到 ruff，可安装后重试。"
        fi
    fi

    # JS/TS: CC <= 10（eslint complexity）
    if [ -n "$js_files" ]; then
        if [ -x "node_modules/.bin/eslint" ]; then
            eslint_cmd=("node_modules/.bin/eslint")
        elif command -v eslint >/dev/null 2>&1; then
            eslint_cmd=("eslint")
        else
            eslint_cmd=()
        fi

        if [ ${#eslint_cmd[@]} -eq 0 ]; then
            complexity_report_missing_tool "$complexity_mode" "$allow_missing" "JS/TS CC(eslint complexity)" "未检测到 eslint，可安装后重试。"
        else
            old_ifs="$IFS"
            IFS=$'\n'
            js_arr=($js_files)
            IFS="$old_ifs"
            output=$("${eslint_cmd[@]}" "${js_arr[@]}" --rule 'complexity: [error, 10]' --no-error-on-unmatched-pattern 2>&1)
            rc=$?
            if [ $rc -ne 0 ]; then
                if complexity_is_tooling_issue "JS/TS CC(eslint complexity)" "$output"; then
                    complexity_report_missing_tool "$complexity_mode" "$allow_missing" "JS/TS CC(eslint complexity)" "eslint 可执行，但缺少可用配置。"
                else
                    complexity_report_violation "$complexity_mode" "JS/TS CC(eslint complexity)" "$output"
                fi
            fi
        fi
    fi

    # Java: CC <= 10（PMD）
    if [ -n "$java_files" ]; then
        if [ -f "pom.xml" ] && command -v mvn >/dev/null 2>&1; then
            output=$(mvn -q -DskipTests pmd:check 2>&1)
            rc=$?
            if [ $rc -ne 0 ]; then
                if complexity_is_tooling_issue "Java CC(PMD)" "$output"; then
                    complexity_report_missing_tool "$complexity_mode" "$allow_missing" "Java CC(PMD)" "Maven 可执行，但未接入可用 PMD 能力。"
                else
                    complexity_report_violation "$complexity_mode" "Java CC(PMD)" "$output"
                fi
            fi
        elif { [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; } && command -v gradle >/dev/null 2>&1; then
            if grep -qE "(id[[:space:]]*\\(?[[:space:]]*['\"]pmd['\"][[:space:]]*\\)?|apply[[:space:]]+plugin:[[:space:]]*['\"]pmd['\"])" build.gradle build.gradle.kts 2>/dev/null; then
                output=$(gradle pmdMain --quiet 2>&1)
                rc=$?
                if [ $rc -ne 0 ]; then
                    if complexity_is_tooling_issue "Java CC(Gradle PMD)" "$output"; then
                        complexity_report_missing_tool "$complexity_mode" "$allow_missing" "Java CC(Gradle PMD)" "Gradle 可执行，但未接入可用 PMD 能力。"
                    else
                        complexity_report_violation "$complexity_mode" "Java CC(Gradle PMD)" "$output"
                    fi
                fi
            else
                complexity_report_missing_tool "$complexity_mode" "$allow_missing" "Java CC(Gradle PMD)" "检测到 Gradle 项目但未配置 PMD 插件。"
            fi
        else
            complexity_report_missing_tool "$complexity_mode" "$allow_missing" "Java CC(PMD)" "检测到 Java 改动，但未发现可用的 Maven/Gradle PMD 检查能力。"
        fi
    fi
}

run_complexity_quality

# ========== 注释质量检查 ==========

run_comment_quality() {
    local comment_mode comment_scope comment_files reports file file_report

    comment_mode=$(comment_normalize_mode "${COMMENT_CHECK_MODE:-warn}")
    comment_scope=$(comment_normalize_scope "${COMMENT_SCOPE:-changed}")

    if [ "$comment_scope" = "all" ]; then
        comment_files=$(git ls-files | grep -E '\.(py|js|ts|jsx|tsx|vue|go|rs|java|cpp|c|cs)$' || true)
    else
        comment_files="$CODE_DIFF"
    fi
    [ -z "$comment_files" ] && return

    reports=""
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        [ -f "$file" ] || continue
        comment_is_supported_file "$file" || continue
        comment_is_test_file "$file" && continue

        file_report=$(comment_check_file "$file" 1)
        if [ -n "$file_report" ]; then
            reports+="[$file]\n${file_report}\n"
        fi
    done <<< "$comment_files"

    [ -z "$reports" ] && return

    if [ "$comment_mode" = "enforce" ]; then
        FAILURES+="注释质量检查失败：\n$reports\n"
    else
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo -e "注释质量提醒：TaskCompleted 阶段发现注释问题（warn 模式）" >&2
        echo -e "可通过 COMMENT_CHECK_MODE=enforce 切换为硬拦截" >&2
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo -e "$reports" >&2
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    fi
}

run_comment_quality

# ========== 占位符扫描 ==========

PLACEHOLDER_HITS=$(git diff HEAD 2>/dev/null | grep -E '^\+' | grep -iE '(raise NotImplementedError|NotImplementedError\(\)|TODO:\s*implement|pass\s*#\s*placeholder|FIXME:\s*implement|stub\b)' | head -10)
if [ -n "$PLACEHOLDER_HITS" ]; then
    FAILURES+="占位符代码:\n$PLACEHOLDER_HITS\n\n"
fi

# ========== 结果 ==========

if [ -n "$FAILURES" ]; then
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo -e "任务验证未通过，请修复后重试：" >&2
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo -e "$FAILURES" >&2
    exit 2
fi

exit 0
