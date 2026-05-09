#!/bin/bash
# skills/lib/script-common.sh — Skill 脚本公共函数库
# 使用方法: source "$(dirname "$0")/../../lib/script-common.sh"

set -euo pipefail

# --- 忽略目录 ---
IGNORE_DIRS="node_modules|dist|build|target|__pycache__|.venv|.git|vendor|.next|.nuxt|.worktrees"

# --- 构建 find 排除参数 ---
build_find_excludes() {
    local IFS='|'
    local excludes=""
    for dir in $IGNORE_DIRS; do
        excludes="$excludes -not -path '*/${dir}/*'"
    done
    echo "$excludes"
}

# --- 检测项目主语言 ---
detect_language() {
    local project_dir="${1:-.}"
    if [ -f "${project_dir}/pom.xml" ] || [ -f "${project_dir}/build.gradle" ]; then
        echo "java"
    elif [ -f "${project_dir}/package.json" ]; then
        if [ -f "${project_dir}/tsconfig.json" ]; then
            echo "typescript"
        else
            echo "javascript"
        fi
    elif [ -f "${project_dir}/pyproject.toml" ] || [ -f "${project_dir}/requirements.txt" ]; then
        echo "python"
    elif [ -f "${project_dir}/go.mod" ]; then
        echo "go"
    elif [ -f "${project_dir}/Cargo.toml" ]; then
        echo "rust"
    else
        echo "unknown"
    fi
}

# --- JSON 格式化输出 ---
json_output() {
    local key="$1" value="$2"
    if command -v jq &>/dev/null; then
        jq -nc --arg k "$key" --arg v "$value" '{($k): $v}'
    else
        printf '{\"%s\": \"%s\"}\n' "$key" "$value"
    fi
}

# --- 错误时输出 JSON ---
script_error() {
    local msg="$1"
    if command -v jq &>/dev/null; then
        jq -nc --arg m "$msg" '{"error": $m, "fallback": true}'
    else
        printf '{"error": "%s", "fallback": true}\n' "$msg"
    fi
    exit 1
}

# --- 文件数上限保护 ---
MAX_FILES=10000
check_file_limit() {
    local count="$1"
    if [ "$count" -gt "$MAX_FILES" ]; then
        echo "WARNING: File count ($count) exceeds limit ($MAX_FILES), sampling enabled" >&2
        return 1
    fi
    return 0
}
