#!/bin/bash
# scan/scripts/dependency-stats.sh — 统计项目依赖数量
# 输入: $1 = 项目路径（默认 .）
# 输出: JSON {package_manager, dependencies: {prod: count, dev: count}, total}

set -euo pipefail
source "$(dirname "$0")/../../lib/script-common.sh"

PROJECT_DIR="${1:-.}"
[ -d "$PROJECT_DIR" ] || script_error "Directory not found: $PROJECT_DIR"

pkg_manager="unknown"
prod=0
dev=0

if [ -f "${PROJECT_DIR}/package.json" ]; then
    pkg_manager="npm"
    if command -v jq &>/dev/null; then
        prod=$(jq '.dependencies // {} | length' "${PROJECT_DIR}/package.json" 2>/dev/null || echo 0)
        dev=$(jq '.devDependencies // {} | length' "${PROJECT_DIR}/package.json" 2>/dev/null || echo 0)
    else
        prod=$(grep -c '"[^"]*":' "${PROJECT_DIR}/package.json" 2>/dev/null || echo 0)
    fi
elif [ -f "${PROJECT_DIR}/pyproject.toml" ]; then
    pkg_manager="pip"
    prod=$(sed -n '/^\[project\]/,/^\[/p' "${PROJECT_DIR}/pyproject.toml" \
        | sed -n '/^dependencies/,/^\]/p' \
        | grep -cE '^\s*"' 2>/dev/null || echo 0)
    dev=$(sed -n '/\[project.optional-dependencies\]/,/^\[/p' "${PROJECT_DIR}/pyproject.toml" \
        | grep -cE '^\s*"' 2>/dev/null || echo 0)
elif [ -f "${PROJECT_DIR}/requirements.txt" ]; then
    pkg_manager="pip"
    prod=$(grep -cvE '^\s*$|^\s*#' "${PROJECT_DIR}/requirements.txt" 2>/dev/null || echo 0)
elif [ -f "${PROJECT_DIR}/go.mod" ]; then
    pkg_manager="go"
    prod=$(sed -n '/^require (/,/^)/p' "${PROJECT_DIR}/go.mod" \
        | grep -cvE '^\s*$|^require|^\)' 2>/dev/null || echo 0)
elif [ -f "${PROJECT_DIR}/pom.xml" ]; then
    pkg_manager="maven"
    prod=$(grep -c '<dependency>' "${PROJECT_DIR}/pom.xml" 2>/dev/null || echo 0)
elif [ -f "${PROJECT_DIR}/Cargo.toml" ]; then
    pkg_manager="cargo"
    prod=$(sed -n '/^\[dependencies\]/,/^\[/p' "${PROJECT_DIR}/Cargo.toml" \
        | grep -cE '^[a-zA-Z]' 2>/dev/null || echo 0)
    dev=$(sed -n '/^\[dev-dependencies\]/,/^\[/p' "${PROJECT_DIR}/Cargo.toml" \
        | grep -cE '^[a-zA-Z]' 2>/dev/null || echo 0)
fi

total=$((prod + dev))

if command -v jq &>/dev/null; then
    jq -nc \
        --arg pm "$pkg_manager" \
        --argjson prod "$prod" \
        --argjson dev "$dev" \
        --argjson total "$total" \
        '{package_manager: $pm, dependencies: {prod: $prod, dev: $dev}, total: $total}'
else
    printf '{"package_manager":"%s","dependencies":{"prod":%d,"dev":%d},"total":%d}\n' \
        "$pkg_manager" "$prod" "$dev" "$total"
fi
