#!/bin/bash
# 自动格式化 + lint 反馈脚本
# 触发时机: PostToolUse:Edit|Write
# 功能: 格式化代码 + 运行 lint 并反馈问题
# 版本: v3.0 2026-03-05
# 变更: 增加 lint 反馈、移除 PIPELINE_DISABLE_HOOKS

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

[ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ] && exit 0

# 检查文件是否在 git 仓库且有改动
if command -v git >/dev/null 2>&1; then
    GIT_ROOT=$(git -C "$(dirname "$FILE_PATH")" rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$GIT_ROOT" ]; then
        RELATIVE_PATH="${FILE_PATH#"$GIT_ROOT"/}"
        if ! git -C "$GIT_ROOT" diff --name-only HEAD 2>/dev/null | grep -qF "$RELATIVE_PATH" && \
           ! git -C "$GIT_ROOT" diff --name-only 2>/dev/null | grep -qF "$RELATIVE_PATH" && \
           ! git -C "$GIT_ROOT" status --porcelain 2>/dev/null | grep -qF "$RELATIVE_PATH"; then
            if git -C "$GIT_ROOT" ls-files --error-unmatch "$RELATIVE_PATH" >/dev/null 2>&1; then
                exit 0
            fi
        fi
    fi
fi

# 5 秒内不重复格式化同一文件
FORMAT_CACHE="$HOME/.claude/.format_cache"
CACHE_KEY=$(echo "$FILE_PATH" | md5 -q 2>/dev/null || echo "$FILE_PATH" | md5sum 2>/dev/null | cut -d' ' -f1)
NOW=$(date +%s)

if [ -f "$FORMAT_CACHE" ]; then
    LAST_FORMAT=$(grep "^$CACHE_KEY " "$FORMAT_CACHE" 2>/dev/null | tail -1 | cut -d' ' -f2)
    if [ -n "$LAST_FORMAT" ] && [ $((NOW - LAST_FORMAT)) -lt 5 ]; then
        exit 0
    fi
fi

mkdir -p "$(dirname "$FORMAT_CACHE")"
echo "$CACHE_KEY $NOW" >> "$FORMAT_CACHE"

# 定期清理缓存
CACHE_LINES=$(wc -l < "$FORMAT_CACHE" 2>/dev/null || echo 0)
if [ "$CACHE_LINES" -gt 100 ]; then
    ONE_DAY_AGO=$((NOW - 86400))
    awk -v threshold="$ONE_DAY_AGO" '$2 > threshold' "$FORMAT_CACHE" > "$FORMAT_CACHE.tmp" 2>/dev/null
    if [ -s "$FORMAT_CACHE.tmp" ]; then
        mv "$FORMAT_CACHE.tmp" "$FORMAT_CACHE"
    else
        tail -50 "$FORMAT_CACHE" > "$FORMAT_CACHE.tmp" && mv "$FORMAT_CACHE.tmp" "$FORMAT_CACHE"
    fi
fi

PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$PROJECT_DIR" ] && PROJECT_DIR=$(dirname "$FILE_PATH")

FORMAT_FAILED=0

run_formatter() {
    local name="$1"
    shift
    if ! "$@" 2>/dev/null; then
        echo "auto_format: ${name} 失败 -> $FILE_PATH" >&2
        FORMAT_FAILED=1
    fi
}

# Python: 格式化 + lint
if [[ "$FILE_PATH" == *.py ]]; then
    if command -v ruff >/dev/null 2>&1; then
        run_formatter "ruff format" ruff format "$FILE_PATH" --quiet
        run_formatter "ruff check --fix" ruff check "$FILE_PATH" --fix --quiet
        # lint 反馈（报告剩余问题）
        LINT_OUTPUT=$(ruff check "$FILE_PATH" 2>&1)
        if [ -n "$LINT_OUTPUT" ] && [ "$LINT_OUTPUT" != "All checks passed!" ]; then
            echo "lint 问题（ruff）:" >&2
            echo "$LINT_OUTPUT" >&2
        fi
    elif command -v black >/dev/null 2>&1; then
        run_formatter "black" black "$FILE_PATH" --quiet
    fi
    exit "$FORMAT_FAILED"
fi

# TypeScript/JavaScript: 格式化 + lint
if [[ "$FILE_PATH" =~ \.(ts|tsx|js|jsx|mjs|cjs)$ ]]; then
    if [ -f "$PROJECT_DIR/node_modules/.bin/prettier" ]; then
        run_formatter "prettier(local)" "$PROJECT_DIR/node_modules/.bin/prettier" --write "$FILE_PATH" --log-level error
    elif command -v prettier >/dev/null 2>&1; then
        run_formatter "prettier(global)" prettier --write "$FILE_PATH" --log-level error
    fi
    # eslint 反馈
    if [ -f "$PROJECT_DIR/node_modules/.bin/eslint" ]; then
        LINT_OUTPUT=$("$PROJECT_DIR/node_modules/.bin/eslint" "$FILE_PATH" 2>&1)
        if [ $? -ne 0 ] && [ -n "$LINT_OUTPUT" ]; then
            echo "lint 问题（eslint）:" >&2
            echo "$LINT_OUTPUT" >&2
        fi
    fi
    exit "$FORMAT_FAILED"
fi

# Vue 文件
if [[ "$FILE_PATH" == *.vue ]]; then
    if [ -f "$PROJECT_DIR/node_modules/.bin/prettier" ]; then
        run_formatter "prettier(vue)" "$PROJECT_DIR/node_modules/.bin/prettier" --write "$FILE_PATH" --log-level error
    fi
    if [ -f "$PROJECT_DIR/node_modules/.bin/eslint" ]; then
        LINT_OUTPUT=$("$PROJECT_DIR/node_modules/.bin/eslint" "$FILE_PATH" 2>&1)
        if [ $? -ne 0 ] && [ -n "$LINT_OUTPUT" ]; then
            echo "lint 问题（eslint）:" >&2
            echo "$LINT_OUTPUT" >&2
        fi
    fi
    exit "$FORMAT_FAILED"
fi

# Java: google-java-format
if [[ "$FILE_PATH" == *.java ]]; then
    if command -v google-java-format >/dev/null 2>&1; then
        run_formatter "google-java-format" google-java-format --replace "$FILE_PATH"
    fi
    exit "$FORMAT_FAILED"
fi

# Go: 格式化 + vet
if [[ "$FILE_PATH" == *.go ]]; then
    if command -v gofmt >/dev/null 2>&1; then
        run_formatter "gofmt" gofmt -w "$FILE_PATH"
    fi
    if command -v go >/dev/null 2>&1; then
        GO_DIR=$(dirname "$FILE_PATH")
        VET_OUTPUT=$(cd "$GO_DIR" && go vet ./... 2>&1)
        if [ $? -ne 0 ] && [ -n "$VET_OUTPUT" ]; then
            echo "lint 问题（go vet）:" >&2
            echo "$VET_OUTPUT" >&2
        fi
    fi
    exit "$FORMAT_FAILED"
fi

# Rust
if [[ "$FILE_PATH" == *.rs ]]; then
    if command -v rustfmt >/dev/null 2>&1; then
        run_formatter "rustfmt" rustfmt "$FILE_PATH"
    fi
    exit "$FORMAT_FAILED"
fi

# JSON
if [[ "$FILE_PATH" == *.json ]]; then
    if command -v jq >/dev/null 2>&1; then
        TMP_FILE=$(mktemp)
        trap 'rm -f "$TMP_FILE"' EXIT
        if jq '.' "$FILE_PATH" > "$TMP_FILE" 2>/dev/null; then
            mv "$TMP_FILE" "$FILE_PATH"
        else
            rm -f "$TMP_FILE"
            echo "auto_format: jq 解析失败 -> $FILE_PATH" >&2
            FORMAT_FAILED=1
        fi
    fi
    exit "$FORMAT_FAILED"
fi

# YAML
if [[ "$FILE_PATH" =~ \.(yaml|yml)$ ]]; then
    if [ -f "$PROJECT_DIR/node_modules/.bin/prettier" ]; then
        run_formatter "prettier(yaml)" "$PROJECT_DIR/node_modules/.bin/prettier" --write "$FILE_PATH" --log-level error
    fi
    exit "$FORMAT_FAILED"
fi

# Markdown
if [[ "$FILE_PATH" =~ \.(md|mdx)$ ]]; then
    if [ -f "$PROJECT_DIR/node_modules/.bin/prettier" ]; then
        run_formatter "prettier(markdown)" "$PROJECT_DIR/node_modules/.bin/prettier" --write "$FILE_PATH" --log-level error
    fi
    exit "$FORMAT_FAILED"
fi

exit 0
