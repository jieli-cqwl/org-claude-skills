#!/bin/bash
# overview/scripts/project-detect.sh — 检测项目类型、框架、入口文件和配置文件
# 输入: $1 = 项目路径（默认 .）
# 输出: JSON {project_type, language, framework, entry_files: [...], config_files: [...]}

set -euo pipefail
source "$(dirname "$0")/../../lib/script-common.sh"

PROJECT_DIR="${1:-.}"
[ -d "$PROJECT_DIR" ] || script_error "Directory not found: $PROJECT_DIR"

LANG=$(detect_language "$PROJECT_DIR")
framework="unknown"
entry_files=""
config_files=""

# 框架检测
case "$LANG" in
    java)
        if grep -q 'spring-boot' "${PROJECT_DIR}/pom.xml" 2>/dev/null || \
           grep -q 'spring-boot' "${PROJECT_DIR}/build.gradle" 2>/dev/null; then
            framework="spring-boot"
            entry_files=$(find "$PROJECT_DIR" -name "*Application.java" -type f 2>/dev/null | head -5)
        fi
        config_files=$(find "$PROJECT_DIR" -name "application*.yml" -o -name "application*.yaml" -o -name "application*.properties" 2>/dev/null | head -5)
        ;;
    typescript|javascript)
        if [ -f "${PROJECT_DIR}/next.config.js" ] || [ -f "${PROJECT_DIR}/next.config.mjs" ] || [ -f "${PROJECT_DIR}/next.config.ts" ]; then
            framework="nextjs"
        elif [ -f "${PROJECT_DIR}/nuxt.config.ts" ] || [ -f "${PROJECT_DIR}/nuxt.config.js" ]; then
            framework="nuxt"
        elif [ -f "${PROJECT_DIR}/vue.config.js" ] || [ -f "${PROJECT_DIR}/vite.config.ts" ] || [ -f "${PROJECT_DIR}/vite.config.js" ]; then
            if grep -q '"vue"' "${PROJECT_DIR}/package.json" 2>/dev/null; then
                framework="vue"
            else
                framework="vite"
            fi
        elif [ -f "${PROJECT_DIR}/angular.json" ]; then
            framework="angular"
        elif grep -q '"express"' "${PROJECT_DIR}/package.json" 2>/dev/null; then
            framework="express"
        elif grep -q '"nestjs"' "${PROJECT_DIR}/package.json" 2>/dev/null || \
             grep -q '"@nestjs/core"' "${PROJECT_DIR}/package.json" 2>/dev/null; then
            framework="nestjs"
        fi
        entry_files=$(find "$PROJECT_DIR" -maxdepth 3 \( -name "main.ts" -o -name "main.js" -o -name "index.ts" -o -name "index.js" -o -name "app.ts" -o -name "app.js" -o -name "App.vue" -o -name "App.tsx" \) -type f -not -path "*/node_modules/*" 2>/dev/null | head -5)
        config_files=$(find "$PROJECT_DIR" -maxdepth 1 \( -name "package.json" -o -name "tsconfig.json" -o -name "vite.config.*" -o -name "next.config.*" -o -name ".env*" \) -type f 2>/dev/null | head -5)
        ;;
    python)
        if [ -f "${PROJECT_DIR}/manage.py" ]; then
            framework="django"
            entry_files="${PROJECT_DIR}/manage.py"
        elif grep -q 'fastapi' "${PROJECT_DIR}/pyproject.toml" 2>/dev/null || \
             grep -q 'fastapi' "${PROJECT_DIR}/requirements.txt" 2>/dev/null; then
            framework="fastapi"
            entry_files=$(find "$PROJECT_DIR" -maxdepth 3 -name "main.py" -type f -not -path "*/.venv/*" 2>/dev/null | head -5)
        elif grep -q 'flask' "${PROJECT_DIR}/pyproject.toml" 2>/dev/null || \
             grep -q 'flask' "${PROJECT_DIR}/requirements.txt" 2>/dev/null; then
            framework="flask"
            entry_files=$(find "$PROJECT_DIR" -maxdepth 3 \( -name "app.py" -o -name "main.py" \) -type f -not -path "*/.venv/*" 2>/dev/null | head -5)
        fi
        config_files=$(find "$PROJECT_DIR" -maxdepth 1 \( -name "pyproject.toml" -o -name "requirements.txt" -o -name ".env*" -o -name "setup.py" -o -name "setup.cfg" \) -type f 2>/dev/null | head -5)
        ;;
    go)
        framework="go"
        entry_files=$(find "$PROJECT_DIR" -maxdepth 3 -name "main.go" -type f -not -path "*/vendor/*" 2>/dev/null | head -5)
        config_files=$(find "$PROJECT_DIR" -maxdepth 1 \( -name "go.mod" -o -name "go.sum" -o -name ".env*" \) -type f 2>/dev/null | head -5)
        ;;
    rust)
        framework="rust"
        entry_files=$(find "$PROJECT_DIR" -maxdepth 3 \( -name "main.rs" -o -name "lib.rs" \) -type f -not -path "*/target/*" 2>/dev/null | head -5)
        config_files=$(find "$PROJECT_DIR" -maxdepth 1 \( -name "Cargo.toml" -o -name ".env*" \) -type f 2>/dev/null | head -5)
        ;;
esac

# 构建 JSON
if command -v jq &>/dev/null; then
    entry_json=$(echo "$entry_files" | sed '/^$/d' | jq -Rnc '[inputs | select(length>0)]')
    config_json=$(echo "$config_files" | sed '/^$/d' | jq -Rnc '[inputs | select(length>0)]')
    jq -nc \
        --arg pt "$LANG" \
        --arg lang "$LANG" \
        --arg fw "$framework" \
        --argjson entry "$entry_json" \
        --argjson config "$config_json" \
        '{project_type: $pt, language: $lang, framework: $fw, entry_files: $entry, config_files: $config}'
else
    printf '{"project_type":"%s","language":"%s","framework":"%s","entry_files":[],"config_files":[]}\n' \
        "$LANG" "$LANG" "$framework"
fi
