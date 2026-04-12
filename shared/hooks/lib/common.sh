#!/bin/bash
# hooks/lib/common.sh — Completion Hook 公共函数库
# 所有 completion hook 共享的初始化、定位、解析和输出函数
# 使用方法: source "$(dirname "$0")/lib/common.sh"

# --- JSON 解析 ---

json_get() {
    printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null || true
}

json_escape() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

emit_decision_json() {
    local decision="$1"
    local reason="$2"
    printf '{"decision":"%s","reason":"%s"}\n' "$decision" "$(json_escape "$reason")"
}

hook_block_init_error() {
    local message="$1"
    export HOOK_STRICT_BLOCK=1
    SESSION_ID="${SESSION_ID:-init-$$}"
    FAILURES=""
    add_failure "$message"
    output_failures "Completion hook 初始化失败" ""
}

# --- 初始化（读取 stdin + 定位仓库根目录） ---

hook_init() {
    if ! command -v jq >/dev/null 2>&1; then
        hook_block_init_error "缺少 jq，无法解析 hook payload"
    fi

    INPUT=$(cat || true)

    if [ -z "$INPUT" ]; then
        hook_block_init_error "stdin 为空，无法解析 hook 上下文"
    fi

    if ! printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1; then
        hook_block_init_error "stdin 不是有效 JSON，无法解析 hook 上下文"
    fi

    CWD=$(json_get '.cwd')
    SESSION_ID=$(json_get '.session_id // .sessionId')
    TRANSCRIPT_PATH=$(json_get '.transcript_path // .transcriptPath')
    TOOL_NAME=$(json_get '.tool_name // .toolName')
    TOOL_INPUT=$(printf '%s' "$INPUT" | jq -c '.tool_input // .toolInput // {}' 2>/dev/null || printf '{}')
    TOOL_FILE_PATH=$(printf '%s' "${TOOL_INPUT:-{}}" | jq -r '.file_path // empty' 2>/dev/null || true)

    if [ -z "$CWD" ]; then
        hook_block_init_error "hook payload 缺少 cwd"
    fi
    if [ ! -d "$CWD" ]; then
        hook_block_init_error "hook payload 中的 cwd 不存在：$CWD"
    fi
    cd "$CWD" || hook_block_init_error "无法进入 hook payload 指定的 cwd：$CWD"

    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        REPO_ROOT=$(git rev-parse --show-toplevel)
    else
        REPO_ROOT="$CWD"
    fi

    cd "$REPO_ROOT" || hook_block_init_error "无法进入仓库根目录：$REPO_ROOT"
}

tool_input_get() {
    printf '%s' "${TOOL_INPUT:-{}}" | jq -r "$1 // empty" 2>/dev/null || true
}

# --- 占位符检测 ---

# 检测值是否为占位符文本（空值、TBD、日期格式模板等）
# 返回 0 = 是占位符，1 = 不是
is_placeholder_text() {
    local value
    value=$(printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    if [ -z "$value" ]; then
        return 0
    fi
    if printf '%s' "$value" | grep -qiE '^(待补|TBD|TODO|N/?A|无|未填写|\[.*\]|\{.*\}|-|—)$'; then
        return 0
    fi
    if printf '%s' "$value" | grep -qiE '^Y{2,}[-/]M{1,2}[-/]D{1,2}([[:space:]]+H{1,2}:[m]{1,2}(:[s]{1,2})?)?$'; then
        return 0
    fi
    if printf '%s' "$value" | grep -qiE '^(日期|时间|待确认时间|请填写时间)$'; then
        return 0
    fi
    if printf '%s' "$value" | grep -qiE '^(YYYY|MM|DD|HH|hh|mm|ss|[[:space:]]|[-/:])+$'; then
        return 0
    fi
    return 1
}

# 验证确认时间格式（YYYY-MM-DD HH:mm）且非占位符
# 返回 0 = 有效，1 = 无效
is_valid_confirmation_time() {
    local value
    value=$(printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    if is_placeholder_text "$value"; then
        return 1
    fi
    if ! printf '%s' "$value" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]+[0-9]{2}:[0-9]{2}$'; then
        return 1
    fi
    return 0
}

# --- Failure 收集 ---

FAILURES=""

add_failure() {
    FAILURES+="  - $1\n"
}

add_failure_with_hint() {
    local message="$1"
    local hint="${2:-}"
    if [ -n "$hint" ]; then
        FAILURES+="  - ${message}\n    期望格式: ${hint}\n"
    else
        FAILURES+="  - ${message}\n"
    fi
}

# --- Feature 目录定位（参数化） ---
# $1: transcript grep 正则（匹配 transcript 中的文件路径）
# $2: git anchor 文件名（如 plan.md、code-review-report.md）
# $3: git anchor glob 前缀（默认 'docs/*'，refactor 用 'docs/重构-*'）

find_feature_dir() {
    local transcript_pattern="$1"
    local anchor_file="$2"
    local glob_prefix="${3:-docs/*}"
    local transcript_candidates="" git_candidates="" intersection

    if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        transcript_candidates=$(grep -oE "$transcript_pattern" "$TRANSCRIPT_PATH" 2>/dev/null \
            | sed -E '/\{[^}]+\}/d' \
            | sed -E 's#^(docs/[^/]+)/.*#\1#' \
            | sort -u || true)
    fi

    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        local escaped_anchor
        escaped_anchor=$(printf '%s' "$anchor_file" | sed 's/[.[\*^$()+?{|\\]/\\&/g')
        git_candidates=$({
            git diff --name-only HEAD -- "${glob_prefix}/${anchor_file}" 2>/dev/null || true
            git ls-files --others --exclude-standard -- "${glob_prefix}/${anchor_file}" 2>/dev/null || true
        } | grep -E "/${escaped_anchor}$" | sed -E "s#/${escaped_anchor}\$##" | sed -E 's#^(docs/[^/]+)/.*#\1#' | sort -u || true)
    fi

    if [ -n "$transcript_candidates" ] && [ -n "$git_candidates" ]; then
        intersection=$(comm -12 \
            <(printf '%s\n' "$transcript_candidates" | sort) \
            <(printf '%s\n' "$git_candidates" | sort))
        if [ -n "$intersection" ]; then
            printf '%s\n' "$intersection"
            return 0
        fi
    fi

    if [ -n "$transcript_candidates" ]; then
        local tc_count
        tc_count=$(printf '%s\n' "$transcript_candidates" | sed '/^$/d' | wc -l | tr -d ' ')
        # Multiple candidates without git: tiebreak by anchor file modification time
        if [ "$tc_count" -gt 1 ] && [ -z "$git_candidates" ]; then
            # Build search bases: current dir, original CWD, parent of CWD
            local -a bases=(".")
            [ -n "$CWD" ] && [ "$CWD" != "$(pwd)" ] && bases+=("$CWD")
            [ -n "$CWD" ] && bases+=("$(dirname "$CWD")")
            local latest="" latest_ts=0
            while IFS= read -r candidate; do
                [ -n "$candidate" ] || continue
                local base
                for base in "${bases[@]}"; do
                    local f
                    f=$(find "${base}/${candidate}" -maxdepth 4 -name "$anchor_file" -type f 2>/dev/null \
                        | while read -r match; do
                            local mtime
                            mtime=$(stat -f %m "$match" 2>/dev/null || stat -c %Y "$match" 2>/dev/null || echo 0)
                            echo "$mtime $match"
                        done | sort -rn | head -1 | cut -d' ' -f2-)
                    if [ -n "$f" ] && [ -f "$f" ]; then
                        local ts
                        ts=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
                        if [ "$ts" -gt "$latest_ts" ]; then
                            latest_ts=$ts
                            latest="$candidate"
                        fi
                        break
                    fi
                done
            done <<< "$transcript_candidates"
            if [ -n "$latest" ]; then
                printf '%s\n' "$latest"
                return 0
            fi
        fi
        printf '%s\n' "$transcript_candidates"
        return 0
    fi

    if [ -n "$git_candidates" ]; then
        printf '%s\n' "$git_candidates"
    fi

    return 0
}

# --- 从 brief.md 交付计划解析当前 Phase 上下文 ---
# $1: feature 目录路径
# 设置全局变量:
#   CURRENT_PHASE_REL
#   CURRENT_PHASE_WORK_DIR
#   CURRENT_PHASE_UNIT_RELS
#   CURRENT_PHASE_UNIT_WORK_DIRS

resolve_current_phase_context() {
    local feature_dir="$1"
    local brief_file="${feature_dir}/brief.md"
    local plan_section parsed

    CURRENT_PHASE_REL=""
    CURRENT_PHASE_WORK_DIR=""
    CURRENT_PHASE_UNIT_RELS=""
    CURRENT_PHASE_UNIT_WORK_DIRS=""

    [ -f "$brief_file" ] || return 0

    # 优先从 TOOL_FILE_PATH 提取 Phase 编号
    local tool_phase=""
    if [ -n "${TOOL_FILE_PATH:-}" ]; then
        tool_phase=$(printf '%s' "$TOOL_FILE_PATH" | grep -oE 'phase-[0-9]+' | head -1 || true)
    fi

    plan_section=$(sed -n '/## 交付计划/,/^## [^#]/p' "$brief_file")
    [ -n "$plan_section" ] || return 0

    parsed=$(printf '%s\n' "$plan_section" | awk -v tool_phase="$tool_phase" '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        function append_unit(unit_rel) {
            if (unit_rel == "") return
            if (phase_units == "") {
                phase_units = unit_rel
                return
            }
            if (index("\n" phase_units "\n", "\n" unit_rel "\n") == 0) {
                phase_units = phase_units "\n" unit_rel
            }
        }
        function flush(    normalized_status) {
            if (!in_phase || phase_rel == "") return
            normalized_status = toupper(trim(phase_status))
            if (selected_phase == "" && normalized_status != "" && normalized_status != "DONE") {
                selected_phase = phase_rel
                selected_units = phase_units
            }
            if (tool_phase != "" && phase_rel == tool_phase) {
                tool_selected_phase = phase_rel
                tool_selected_units = phase_units
            }
            if (fallback_phase == "") {
                fallback_phase = phase_rel
                fallback_units = phase_units
            }
        }
        /^### Phase[[:space:]]+[0-9]+/ {
            flush()
            in_phase = 1
            phase_status = ""
            phase_units = ""
            phase_rel = ""
            phase_num = $0
            sub(/^### Phase[[:space:]]+/, "", phase_num)
            sub(/[^0-9].*$/, "", phase_num)
            if (phase_num ~ /^[0-9]+$/) {
                phase_rel = "phase-" phase_num
            }
            next
        }
        in_phase {
            line = trim($0)
            if (line ~ /^-[[:space:]]*状态[[:space:]]*[:：]/) {
                sub(/^-[[:space:]]*状态[[:space:]]*[:：][[:space:]]*/, "", line)
                phase_status = trim(line)
            }

            line_rest = $0
            while (match(line_rest, /phase-[0-9]+\/unit-[0-9]+\/?/)) {
                unit_rel = substr(line_rest, RSTART, RLENGTH)
                sub(/\/$/, "", unit_rel)
                if (phase_rel != "" && index(unit_rel, phase_rel "/") == 1) {
                    append_unit(unit_rel)
                }
                line_rest = substr(line_rest, RSTART + RLENGTH)
            }
        }
        END {
            flush()

            # 优先使用从 TOOL_FILE_PATH 提取的 Phase
            if (tool_selected_phase != "") {
                print "PHASE|" tool_selected_phase
                count = split(tool_selected_units, units, /\n/)
                for (i = 1; i <= count; i++) {
                    if (units[i] != "") print "UNIT|" units[i]
                }
                exit
            }

            if (selected_phase != "") {
                print "PHASE|" selected_phase
                count = split(selected_units, units, /\n/)
                for (i = 1; i <= count; i++) {
                    if (units[i] != "") print "UNIT|" units[i]
                }
                exit
            }

            if (fallback_phase != "") {
                print "PHASE|" fallback_phase
                count = split(fallback_units, units, /\n/)
                for (i = 1; i <= count; i++) {
                    if (units[i] != "") print "UNIT|" units[i]
                }
            }
        }
    ')

    CURRENT_PHASE_REL=$(printf '%s\n' "$parsed" | sed -nE 's/^PHASE\|(.+)$/\1/p' | head -1)
    CURRENT_PHASE_UNIT_RELS=$(printf '%s\n' "$parsed" | sed -nE 's/^UNIT\|(.+)$/\1/p')

    if [ -z "$CURRENT_PHASE_REL" ]; then
        CURRENT_PHASE_REL=$(printf '%s\n' "$plan_section" | grep -oE 'phase-[0-9]+/' | head -1 | sed 's#/$##' || true)
        if [ -n "$CURRENT_PHASE_REL" ]; then
            CURRENT_PHASE_UNIT_RELS=$(printf '%s\n' "$plan_section" \
                | grep -oE 'phase-[0-9]+/unit-[0-9]+/?' \
                | grep "^${CURRENT_PHASE_REL}/" \
                | sed 's#/$##' \
                | sort -u || true)
        fi
    fi

    if [ -n "$CURRENT_PHASE_REL" ]; then
        CURRENT_PHASE_WORK_DIR="${feature_dir}/${CURRENT_PHASE_REL}"
    fi

    while IFS= read -r unit_rel; do
        [ -n "$unit_rel" ] || continue
        CURRENT_PHASE_UNIT_WORK_DIRS="${CURRENT_PHASE_UNIT_WORK_DIRS:+${CURRENT_PHASE_UNIT_WORK_DIRS}
}${feature_dir}/${unit_rel}"
    done <<< "$CURRENT_PHASE_UNIT_RELS"
}

find_unit_dirs_in_phase_dir() {
    local phase_dir="$1"
    [ -n "$phase_dir" ] || return 0
    [ -d "$phase_dir" ] || return 0

    find "$phase_dir" -mindepth 1 -maxdepth 1 -type d -name 'unit-*' 2>/dev/null | sort || true
}

newline_list_contains_literal() {
    local list="$1"
    local target="$2"
    local line

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        [ "$line" = "$target" ] && return 0
    done <<EOF
$list
EOF

    return 1
}

filter_newline_list_by_literal_prefix() {
    local list="$1"
    local prefix="$2"
    local line

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        case "$line" in
            "$prefix"*)
                printf '%s\n' "$line"
                ;;
        esac
    done <<EOF
$list
EOF
}

# --- 从 brief.md 交付计划解析当前 UNIT 工作区 ---
# $1: feature 目录路径
# $2: 锚定文件名（如 design.md、plan.md）
# 设置全局变量: UNIT_WORK_DIR（当前 UNIT 的工作区路径）

resolve_work_dir() {
    local feature_dir="$1" anchor_file="$2"
    UNIT_WORK_DIR=""

    resolve_current_phase_context "$feature_dir"

    if [ -n "$CURRENT_PHASE_UNIT_WORK_DIRS" ]; then
        local candidates=""
        while IFS= read -r unit_dir; do
            [ -n "$unit_dir" ] || continue
            if [ -f "${unit_dir}/${anchor_file}" ]; then
                candidates="${candidates:+$candidates
}${unit_dir}"
            fi
        done <<< "$CURRENT_PHASE_UNIT_WORK_DIRS"

        if [ -n "$candidates" ]; then
            local count
            count=$(printf '%s\n' "$candidates" | sed '/^$/d' | wc -l | tr -d ' ')
            if [ "$count" = "1" ]; then
                UNIT_WORK_DIR=$(printf '%s\n' "$candidates" | head -1)
                return 0
            fi

            local latest="" latest_ts=0
            while IFS= read -r cand; do
                [ -n "$cand" ] || continue
                local f="${cand}/${anchor_file}"
                local ts
                ts=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
                if [ "$ts" -gt "$latest_ts" ]; then
                    latest_ts=$ts
                    latest="$cand"
                fi
            done <<< "$candidates"
            [ -n "$latest" ] && UNIT_WORK_DIR="$latest" && return 0
        fi

        UNIT_WORK_DIR=$(printf '%s\n' "$CURRENT_PHASE_UNIT_WORK_DIRS" | head -1)
        return 0
    fi

    local found_dirs
    found_dirs=$(find_unit_dirs_in_phase_dir "$CURRENT_PHASE_WORK_DIR")
    if [ -n "$CURRENT_PHASE_WORK_DIR" ] && [ -z "$found_dirs" ]; then
        UNIT_WORK_DIR="$CURRENT_PHASE_WORK_DIR"
        return 0
    fi
    if [ -z "$found_dirs" ]; then
        found_dirs=$(find "$feature_dir" -mindepth 2 -maxdepth 2 -type d -path '*/phase-*/unit-*' 2>/dev/null | sort)
    fi
    if [ -n "$found_dirs" ]; then
        local candidates=""
        while IFS= read -r dir; do
            [ -n "$dir" ] || continue
            if [ -f "${dir}/${anchor_file}" ]; then
                candidates="${candidates:+$candidates
}$dir"
            fi
        done <<< "$found_dirs"

        if [ -n "$candidates" ]; then
            local count
            count=$(printf '%s\n' "$candidates" | sed '/^$/d' | wc -l | tr -d ' ')
            if [ "$count" = "1" ]; then
                UNIT_WORK_DIR=$(printf '%s\n' "$candidates" | head -1)
            else
                local latest="" latest_ts=0
                while IFS= read -r cand; do
                    [ -n "$cand" ] || continue
                    local f="${cand}/${anchor_file}"
                    local ts
                    ts=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
                    if [ "$ts" -gt "$latest_ts" ]; then
                        latest_ts=$ts
                        latest="$cand"
                    fi
                done <<< "$candidates"
                [ -n "$latest" ] && UNIT_WORK_DIR="$latest"
            fi
        else
            UNIT_WORK_DIR=$(printf '%s\n' "$found_dirs" | head -1)
        fi
        return 0
    fi

    UNIT_WORK_DIR="$feature_dir"
}

# --- 从 brief.md 交付计划解析当前 Phase 的全部 UNIT 工作区 ---
# $1: feature 目录路径
# 设置全局变量: ALL_UNIT_WORK_DIRS（当前 Phase 的 UNIT 工作区路径，换行分隔）

resolve_all_unit_work_dirs() {
    local feature_dir="$1"
    ALL_UNIT_WORK_DIRS=""

    resolve_current_phase_context "$feature_dir"
    if [ -n "$CURRENT_PHASE_UNIT_WORK_DIRS" ]; then
        ALL_UNIT_WORK_DIRS="$CURRENT_PHASE_UNIT_WORK_DIRS"
        return 0
    fi

    local found_dirs first_phase_dir
    found_dirs=$(find_unit_dirs_in_phase_dir "$CURRENT_PHASE_WORK_DIR")
    if [ -n "$found_dirs" ]; then
        ALL_UNIT_WORK_DIRS="$found_dirs"
        return 0
    fi
    if [ -n "$CURRENT_PHASE_WORK_DIR" ]; then
        return 0
    fi

    found_dirs=$(find "$feature_dir" -mindepth 2 -maxdepth 2 -type d -path '*/phase-*/unit-*' 2>/dev/null | sort)
    if [ -z "$found_dirs" ]; then
        return 0
    fi

    first_phase_dir=$(printf '%s\n' "$found_dirs" | head -1 | sed -E 's#(.*/phase-[0-9]+)/unit-[0-9]+$#\1#')
    ALL_UNIT_WORK_DIRS=$(filter_newline_list_by_literal_prefix "$found_dirs" "${first_phase_dir}/unit-")
}

# --- 从 UNIT 工作区路径派生 Phase 目录 ---
# 输入: docs/feature/phase-N/unit-M → 输出: docs/feature/phase-N
# 非 phase/unit 结构时原样返回

derive_phase_dir() {
    local dir="$1"
    if [[ "$dir" =~ ^(.*/phase-[0-9]+)/unit-[0-9]+/?$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        printf '%s' "$dir"
    fi
}

# --- 从 brief.md 交付计划解析当前 Phase 工作区 ---
# $1: feature 目录路径
# $2: 锚定文件名（如 design.md）——在 phase-{N}/ 级别查找
# 设置全局变量: PHASE_WORK_DIR

resolve_phase_work_dir() {
    local feature_dir="$1" anchor_file="$2"
    PHASE_WORK_DIR=""

    resolve_current_phase_context "$feature_dir"
    if [ -n "$CURRENT_PHASE_WORK_DIR" ]; then
        PHASE_WORK_DIR="$CURRENT_PHASE_WORK_DIR"
        return 0
    fi

    local found_phases
    found_phases=$(find "$feature_dir" -mindepth 1 -maxdepth 1 -type d -name 'phase-*' 2>/dev/null | sort)
    if [ -n "$found_phases" ]; then
        while IFS= read -r dir; do
            [ -n "$dir" ] || continue
            if [ -f "${dir}/${anchor_file}" ]; then
                PHASE_WORK_DIR="$dir"
                return 0
            fi
        done <<< "$found_phases"
        PHASE_WORK_DIR=$(printf '%s\n' "$found_phases" | head -1)
        return 0
    fi

    PHASE_WORK_DIR="$feature_dir"
}

# --- Feature 目录解析（定位 + 唯一性校验） ---
# $1: 锚定文件描述标签（如 "docs/*/plan.md"）
# $2: transcript grep 正则
# $3: git anchor 文件名
# $4: git anchor glob 前缀（可选，默认 'docs/*'）
# 设置全局变量: FEATURE_DIR, FEATURE_CANDIDATES

resolve_feature_dir() {
    local label="$1" transcript_pattern="$2" anchor_file="$3" glob_prefix="${4:-docs/*}"

    FEATURE_CANDIDATES=$(find_feature_dir "$transcript_pattern" "$anchor_file" "$glob_prefix" | sed '/^$/d')
    local count
    count=$(printf '%s\n' "$FEATURE_CANDIDATES" | sed '/^$/d' | wc -l | tr -d ' ')

    if [ "$count" = "0" ]; then
        add_failure "无法定位当前 feature：transcript_path=${TRANSCRIPT_PATH:-<empty>}，session_id=${SESSION_ID:-<empty>}，且工作树中不存在唯一的 ${label} 候选"
    elif [ "$count" != "1" ]; then
        add_failure "当前 feature 候选不唯一，请只保留一个 ${label} 变更或确保 transcript 只包含当前 feature：$(printf '%s' "$FEATURE_CANDIDATES" | tr '\n' ' ')"
    fi

    FEATURE_DIR=$(printf '%s\n' "$FEATURE_CANDIDATES" | head -1)

    # Resolve to absolute path if relative FEATURE_DIR doesn't exist from REPO_ROOT
    if [ -n "$FEATURE_DIR" ] && [ ! -d "$FEATURE_DIR" ]; then
        local -a search_bases=("$CWD" "$(dirname "$CWD")")
        local base
        for base in "${search_bases[@]}"; do
            if [ -d "${base}/${FEATURE_DIR}" ]; then
                FEATURE_DIR="${base}/${FEATURE_DIR}"
                break
            fi
        done
    fi
}

# --- 报告文件定位（按目录 + 文件名模式） ---
# $1: 目录路径
# $2: find 文件名模式（如 '*.md'）
# 返回最新的匹配文件路径

find_report_by_pattern() {
    local dir="$1" pattern="$2"
    [ -d "$dir" ] || return 0
    find "$dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null | sort -r | head -1
}

# --- Markdown 解析 ---

parse_review_header() {
    local file="$1" key="$2"
    [ -f "$file" ] || return 0
    case "$key" in
        verdict)
            sed -nE 's/^[[:space:]]*Verdict[[:space:]]*:[[:space:]]*(PASS|WARN|FAIL)[[:space:]]*$/\1/p' "$file" 2>/dev/null | head -1 || true
            ;;
        issue_count)
            sed -nE 's/^[[:space:]]*Issue Count[[:space:]]*:[[:space:]]*([0-9]+)[[:space:]]*$/\1/p' "$file" 2>/dev/null | head -1 || true
            ;;
    esac
}

extract_issue_ids() {
    local file="$1" prefix="$2"
    grep -oE "${prefix}-[0-9]{3,}" "$file" 2>/dev/null | sort -u || true
}

extract_markdown_section() {
    local file="$1" heading="$2"
    [ -f "$file" ] || return 0
    awk -v heading="$heading" '
        $0 == heading { in_section=1; next }
        in_section && /^## / { exit }
        in_section { print }
    ' "$file"
}

extract_section_content() {
    local file="$1" heading="$2" level="$3"
    awk -v heading="$heading" -v level="$level" '
        $0 == heading { in_section=1; next }
        in_section && /^#{1,}[[:space:]]/ {
            match($0, /^#+/)
            if (RLENGTH <= level) exit
        }
        in_section { print }
    ' "$file"
}

has_substance() {
    local content="$1"
    local lines
    lines=$(printf '%s\n' "$content" | grep -cvE '^[[:space:]]*$' 2>/dev/null || true)
    [ "$lines" -gt 0 ]
}

# --- 规范化章节匹配 ---
# 容忍: # 级别差异、尾部括号附加文本、首尾空格
# $1: 文件路径
# $2..N: 标题文本（不含 # 前缀），多个为别名关系（任一匹配即可）
# 返回: 0=找到, 1=未找到

match_section_heading() {
    local file="$1"
    shift
    [ -f "$file" ] || return 1

    local heading
    for heading in "$@"; do
        local text
        text=$(printf '%s' "$heading" | sed -E 's/^#{1,}[[:space:]]*//')
        local escaped
        escaped=$(printf '%s' "$text" | sed 's/[.[\*^$()+?{|\\]/\\&/g')
        if grep -qE "^#{1,}[[:space:]]+${escaped}([[:space:]]*[（(].*[)）])?[[:space:]]*$" "$file" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

# 基于规范化匹配的章节内容提取
# $1: 文件路径
# $2: 标题文本（不含 # 前缀）
# $3: 标题级别（用于确定章节结束边界，默认 2）
# $4..N: 可选别名

extract_section_by_name() {
    local file="$1" heading="$2" level="${3:-2}"
    shift 3 2>/dev/null || true
    local -a aliases=("$heading" "$@")

    [ -f "$file" ] || return 0

    local text
    for text in "${aliases[@]}"; do
        text=$(printf '%s' "$text" | sed -E 's/^#{1,}[[:space:]]*//')
        local escaped
        escaped=$(printf '%s' "$text" | sed 's/[.[\*^$()+?{|\\]/\\&/g')
        local content
        content=$(awk -v pattern="$escaped" -v level="$level" '
            !in_section && /^#{1,}[[:space:]]/ {
                line = $0
                gsub(/^#{1,}[[:space:]]+/, "", line)
                gsub(/[[:space:]]*[（(].*[)）][[:space:]]*$/, "", line)
                gsub(/[[:space:]]+$/, "", line)
                if (line == pattern || match(line, "^" pattern "$")) {
                    in_section = 1
                    next
                }
            }
            in_section && /^#{1,}[[:space:]]/ {
                match($0, /^#+/)
                if (RLENGTH <= level) exit
            }
            in_section { print }
        ' "$file" 2>/dev/null)
        if [ -n "$content" ]; then
            printf '%s\n' "$content"
            return 0
        fi
    done
}

# --- 表格按列名解析 ---
# 从 markdown 表格内容中按列名动态提取数据，替代硬编码 $N
# $1: 表格所在的文本内容（通常由 extract_section_content 提取）
# $2..N: 请求的列名（支持 "列名A|列名B" 别名语法）
# 输出: 每行一条数据行，各列值以 TAB 分隔，列序与参数顺序一致
# 未找到的列输出空字符串

parse_table_by_header() {
    local content="$1"
    shift
    local cols_joined
    cols_joined=$(printf '%s\n' "$@" | tr '\n' '|' | sed 's/|$//')

    printf '%s\n' "$content" | awk -F'|' -v requested="$cols_joined" '
        BEGIN {
            n = split(requested, req_raw, "|")
            # 展开别名：每个 req_raw 可能含 "A|B" 但已被 | 拆开
            # 重新组装：按参数传入的换行分隔的组来处理
            # 简化处理：直接用 requested 中的所有名称尝试匹配
        }
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); gsub(/\*\*/, "", s); return s }

        # 寻找表头行
        !found_header && /^\|/ {
            is_sep = 1
            for (i = 2; i < NF; i++) {
                v = trim($i)
                if (v != "" && v !~ /^[-:]+$/) { is_sep = 0; break }
            }
            if (!is_sep) {
                found_header = 1
                for (i = 2; i <= NF; i++) {
                    hdr = trim($i)
                    header_idx[hdr] = i
                }
                # 建立请求列 -> 实际列号的映射
                for (j = 1; j <= n; j++) {
                    col_idx[j] = 0
                    name = trim(req_raw[j])
                    # 支持别名：用 / 分隔（非 | 避免与 awk FS 冲突）
                    m = split(name, aliases, "/")
                    for (k = 1; k <= m; k++) {
                        a = trim(aliases[k])
                        if (a in header_idx) {
                            col_idx[j] = header_idx[a]
                            break
                        }
                    }
                }
                next
            }
        }

        # 跳过分隔行
        found_header && /^\|/ {
            v = trim($2)
            if (v ~ /^[-:]+$/) next
            if (v == "") next

            result = ""
            for (j = 1; j <= n; j++) {
                if (j > 1) result = result "\t"
                if (col_idx[j] > 0 && col_idx[j] <= NF) {
                    result = result trim($col_idx[j])
                }
            }
            print result
        }
    '
}

# --- 主文档内嵌审查区块解析 ---

extract_review_summary_row() {
    local file="$1" view_label="$2"
    [ -f "$file" ] || return 0

    local summary_section summary_rows
    summary_section=$(extract_section_content "$file" "### 审查汇总" 3)
    [ -n "$summary_section" ] || return 0

    summary_rows=$(parse_table_by_header "$summary_section" "视角" "Verdict" "Issue Count")
    printf '%s\n' "$summary_rows" | awk -F'\t' -v target="$view_label" '
        function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
        {
            view = trim($1)
            if (view == target) {
                print trim($1) "\t" trim($2) "\t" trim($3)
                exit
            }
        }
    '
}

extract_review_issue_ledger_rows() {
    local file="$1"
    [ -f "$file" ] || return 0

    local ledger_section
    ledger_section=$(extract_section_content "$file" "### 审查问题台账" 3)
    [ -n "$ledger_section" ] || return 0

    parse_table_by_header \
        "$ledger_section" \
        "Issue ID" \
        "视角" \
        "Severity" \
        "Status" \
        "Evidence Anchor" \
        "Handoff Target" \
        "Review Round" \
        "处理摘要"
}

extract_convergence_rows() {
    local file="$1"
    [ -f "$file" ] || return 0

    local convergence_section
    convergence_section=$(extract_section_content "$file" "### 收敛轮次摘要" 3)
    [ -n "$convergence_section" ] || return 0

    parse_table_by_header "$convergence_section" "轮次" "结果" "说明"
}

extract_convergence_policy_rows() {
    local file="$1"
    [ -f "$file" ] || return 0

    local convergence_section
    convergence_section=$(extract_section_content "$file" "### 收敛轮次摘要" 3)
    [ -n "$convergence_section" ] || return 0

    parse_table_by_header \
        "$convergence_section" \
        "轮次" \
        "结果" \
        "FAIL数" \
        "未关闭 Issue IDs" \
        "控制动作" \
        "说明"
}

extract_review_user_decision_rows() {
    local file="$1"
    [ -f "$file" ] || return 0

    local decision_section
    decision_section=$(extract_section_content "$file" "### 用户裁决记录" 3)
    [ -n "$decision_section" ] || return 0

    parse_table_by_header \
        "$decision_section" \
        "触发轮次" \
        "控制动作" \
        "用户决定" \
        "关联 Issue IDs" \
        "记录时间" \
        "说明"
}

extract_issue_ids_from_text() {
    local text="$1"
    printf '%s\n' "$text" | grep -oE '[A-Z]{1,5}-[0-9]{3,}' | sort -u || true
}

normalize_issue_ids_from_text() {
    local text="$1"
    extract_issue_ids_from_text "$text" | paste -sd, - 2>/dev/null || true
}

count_issue_ids_in_text() {
    local text="$1"
    extract_issue_ids_from_text "$text" | sed '/^$/d' | wc -l | tr -d ' '
}

contains_issue_id_in_text() {
    local text="$1" issue_id="$2"
    extract_issue_ids_from_text "$text" | grep -qx "$issue_id"
}

issue_id_sets_match() {
    local expected="$1" actual="$2"
    [ "$(normalize_issue_ids_from_text "$expected")" = "$(normalize_issue_ids_from_text "$actual")" ]
}

count_review_user_decision_rows() {
    local decision_rows="$1" trigger_round="$2" trigger_action="$3"
    printf '%s\n' "$decision_rows" | awk -F'\t' -v target_round="$trigger_round" -v target_action="$trigger_action" '
        $1 == target_round && $2 == target_action { count++ }
        END { print count + 0 }
    '
}

find_review_user_decision_row() {
    local decision_rows="$1" trigger_round="$2" trigger_action="$3"
    printf '%s\n' "$decision_rows" | awk -F'\t' -v target_round="$trigger_round" -v target_action="$trigger_action" '
        $1 == target_round && $2 == target_action { print; exit }
    '
}

is_unlocking_user_decision() {
    case "$1" in
        继续修复|回退上游)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_review_issue_closed_status() {
    case "$1" in
        RESOLVED|RESOLVED-BY-LEAD|VERIFIED|CLOSED)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

validate_review_convergence_policy() {
    local file="$1" doc_label="$2" total_stable_issues="${3:-0}"
    local policy_rows ledger_rows decision_rows
    local row_count prev_round_num prev_fail_count
    local latest_round latest_action
    local pending_gate_round pending_gate_action pending_gate_ids
    local round result fail_count unresolved_ids action note
    local round_num unresolved_count
    local decision_row decision_count user_decision decision_issue_ids decision_time decision_note
    local ledger_issue_ids duplicate_issue_ids issue_id issue_count_in_ledger
    local policy_action policy_issue_ids
    local allowed_empty_pattern policy_row

    policy_rows=$(extract_convergence_policy_rows "$file")
    if [ -z "$policy_rows" ]; then
        add_failure "${doc_label}「审查结论」缺少「收敛轮次摘要」或数据行为空"
        return 0
    fi
    decision_rows=$(extract_review_user_decision_rows "$file")

    row_count=0
    prev_round_num=0
    prev_fail_count=""
    latest_round=""
    latest_action=""
    pending_gate_round=""
    pending_gate_action=""
    pending_gate_ids=""
    allowed_empty_pattern='^(无|NONE|N/A|-|—)?$'

    while IFS=$'\t' read -r round result fail_count unresolved_ids action note; do
        [ -n "$round" ] || continue
        row_count=$((row_count + 1))

        if [ -n "$pending_gate_round" ]; then
            decision_count=$(count_review_user_decision_rows "$decision_rows" "$pending_gate_round" "$pending_gate_action")
            if [ "$decision_count" -eq 0 ]; then
                add_failure "${doc_label} 收敛轮次 ${pending_gate_round} 已触发 ${pending_gate_action}，缺少用户裁决记录，不得继续后续轮次"
            else
                if [ "$decision_count" -gt 1 ]; then
                    add_failure "${doc_label}「用户裁决记录」中 ${pending_gate_round}/${pending_gate_action} 存在重复记录"
                fi
                decision_row=$(find_review_user_decision_row "$decision_rows" "$pending_gate_round" "$pending_gate_action")
                IFS=$'\t' read -r _ _ user_decision decision_issue_ids decision_time decision_note <<EOF
$decision_row
EOF
                if ! printf '%s' "$user_decision" | grep -qE '^(继续修复|回退上游|终止当前阶段|保持阻断)$'; then
                    add_failure "${doc_label}「用户裁决记录」${pending_gate_round}/${pending_gate_action} 的用户决定非法：${user_decision}"
                elif ! is_unlocking_user_decision "$user_decision"; then
                    add_failure "${doc_label} 收敛轮次 ${pending_gate_round} 的 ${pending_gate_action} 用户决定为 ${user_decision}，不得继续后续轮次"
                fi
                if ! is_valid_confirmation_time "$decision_time"; then
                    add_failure "${doc_label}「用户裁决记录」${pending_gate_round}/${pending_gate_action} 缺少有效记录时间（需使用 YYYY-MM-DD HH:mm）"
                fi
                if is_placeholder_text "$decision_note"; then
                    add_failure "${doc_label}「用户裁决记录」${pending_gate_round}/${pending_gate_action} 缺少说明"
                fi
                if ! issue_id_sets_match "$pending_gate_ids" "$decision_issue_ids"; then
                    add_failure "${doc_label}「用户裁决记录」${pending_gate_round}/${pending_gate_action} 的关联 Issue IDs 与触发轮次未关闭 Issue IDs 不一致"
                fi
            fi
            pending_gate_round=""
            pending_gate_action=""
            pending_gate_ids=""
        fi

        if ! printf '%s' "$round" | grep -qE '^R[0-9]+$'; then
            add_failure "${doc_label}「收敛轮次摘要」存在非法轮次标识：${round}（需为 R1/R2/...）"
            continue
        fi

        round_num=${round#R}
        if [ "$prev_round_num" -ne 0 ] && [ "$round_num" -ne $((prev_round_num + 1)) ]; then
            add_failure "${doc_label}「收敛轮次摘要」轮次不连续：${round} 之前应为 R$((round_num - 1))"
        fi
        prev_round_num=$round_num

        if ! printf '%s' "$result" | grep -qE '^(PASS|WARN|FAIL)$'; then
            add_failure "${doc_label}「收敛轮次摘要」${round} 的结果非法：${result}（需为 PASS/WARN/FAIL）"
        fi

        if ! printf '%s' "$fail_count" | grep -qE '^[0-9]+$'; then
            add_failure "${doc_label}「收敛轮次摘要」${round} 的 FAIL数非法：${fail_count}"
            fail_count=0
        fi

        if ! printf '%s' "$action" | grep -qE '^(CONTINUE|CONFIRMATION|ASK_USER|BLOCKED)$'; then
            add_failure "${doc_label}「收敛轮次摘要」${round} 的控制动作非法：${action}（需为 CONTINUE/CONFIRMATION/ASK_USER/BLOCKED）"
        fi

        if is_placeholder_text "$note"; then
            add_failure "${doc_label}「收敛轮次摘要」${round} 缺少说明"
        fi

        unresolved_count=$(count_issue_ids_in_text "$unresolved_ids")
        if [ "$fail_count" -eq 0 ]; then
            if [ "$unresolved_count" -ne 0 ] || ! printf '%s' "$unresolved_ids" | grep -qE "$allowed_empty_pattern"; then
                add_failure "${doc_label}「收敛轮次摘要」${round} 的 FAIL数为 0 时，未关闭 Issue IDs 必须为「无」"
            fi
            if [ "$result" = "FAIL" ]; then
                add_failure "${doc_label}「收敛轮次摘要」${round} 的 FAIL数为 0 时，结果不能为 FAIL"
            fi
        else
            if [ "$unresolved_count" -eq 0 ]; then
                add_failure "${doc_label}「收敛轮次摘要」${round} 的 FAIL数=${fail_count}，但未关闭 Issue IDs 为空"
            fi
            if [ "$unresolved_count" -ne "$fail_count" ]; then
                add_failure "${doc_label}「收敛轮次摘要」${round} 的 FAIL数=${fail_count} 与未关闭 Issue IDs 数量=${unresolved_count} 不一致"
            fi
            if [ "$result" != "FAIL" ]; then
                add_failure "${doc_label}「收敛轮次摘要」${round} 的 FAIL数>0 时，结果必须为 FAIL"
            fi
        fi

        if [ -n "$prev_fail_count" ] && [ "$prev_fail_count" -gt 0 ] && [ "$fail_count" -ge "$prev_fail_count" ]; then
            if [ "$action" != "ASK_USER" ] && [ "$action" != "BLOCKED" ]; then
                add_failure "${doc_label} 连续 2 轮 FAIL 数未减少，${round} 的控制动作必须为 ASK_USER 或 BLOCKED"
            fi
        fi
        prev_fail_count="$fail_count"
        latest_round="$round"
        latest_action="$action"

        if [ "$action" = "ASK_USER" ] || [ "$action" = "BLOCKED" ]; then
            pending_gate_round="$round"
            pending_gate_action="$action"
            pending_gate_ids="$unresolved_ids"
        fi
    done <<< "$policy_rows"

    if [ "$row_count" -eq 0 ]; then
        add_failure "${doc_label}「审查结论」缺少「收敛轮次摘要」或数据行为空"
        return 0
    fi

    if [ "$total_stable_issues" -eq 0 ] && [ "$row_count" -lt 2 ]; then
        add_failure "${doc_label} 首轮全 PASS 仍需确认轮，收敛轮次摘要至少保留 2 轮记录"
    fi

    while IFS=$'\t' read -r round action user_decision decision_issue_ids decision_time decision_note; do
        [ -n "$round" ] || continue

        if ! printf '%s' "$round" | grep -qE '^R[0-9]+$'; then
            add_failure "${doc_label}「用户裁决记录」存在非法触发轮次：${round}（需为 R1/R2/...）"
            continue
        fi
        if ! printf '%s' "$action" | grep -qE '^(ASK_USER|BLOCKED)$'; then
            add_failure "${doc_label}「用户裁决记录」${round} 的控制动作非法：${action}（需为 ASK_USER/BLOCKED）"
        fi
        if ! printf '%s' "$user_decision" | grep -qE '^(继续修复|回退上游|终止当前阶段|保持阻断)$'; then
            add_failure "${doc_label}「用户裁决记录」${round}/${action} 的用户决定非法：${user_decision}"
        fi
        if [ "$(count_issue_ids_in_text "$decision_issue_ids")" -eq 0 ]; then
            add_failure "${doc_label}「用户裁决记录」${round}/${action} 缺少关联 Issue IDs"
        fi
        if ! is_valid_confirmation_time "$decision_time"; then
            add_failure "${doc_label}「用户裁决记录」${round}/${action} 缺少有效记录时间（需使用 YYYY-MM-DD HH:mm）"
        fi
        if is_placeholder_text "$decision_note"; then
            add_failure "${doc_label}「用户裁决记录」${round}/${action} 缺少说明"
        fi

        decision_count=$(count_review_user_decision_rows "$decision_rows" "$round" "$action")
        if [ "$decision_count" -gt 1 ]; then
            add_failure "${doc_label}「用户裁决记录」中 ${round}/${action} 存在重复记录"
        fi

        policy_row=$(printf '%s\n' "$policy_rows" | awk -F'\t' -v target="$round" '$1 == target { print; exit }')
        if [ -z "$policy_row" ]; then
            add_failure "${doc_label}「用户裁决记录」${round}/${action} 未在收敛轮次摘要中找到对应轮次"
            continue
        fi

        policy_action=$(printf '%s\n' "$policy_row" | awk -F'\t' '{print $5}')
        policy_issue_ids=$(printf '%s\n' "$policy_row" | awk -F'\t' '{print $4}')
        if [ "$policy_action" != "$action" ]; then
            add_failure "${doc_label}「用户裁决记录」${round}/${action} 与收敛轮次摘要控制动作=${policy_action} 不一致"
        fi
        if ! issue_id_sets_match "$policy_issue_ids" "$decision_issue_ids"; then
            add_failure "${doc_label}「用户裁决记录」${round}/${action} 的关联 Issue IDs 与收敛轮次摘要不一致"
        fi
    done <<< "$decision_rows"

    ledger_rows=$(extract_review_issue_ledger_rows "$file")
    ledger_issue_ids=$(printf '%s\n' "$ledger_rows" | awk -F'\t' '{print $1}' | sed '/^$/d')
    duplicate_issue_ids=$(printf '%s\n' "$ledger_issue_ids" | sort | uniq -d)
    while IFS= read -r issue_id; do
        [ -n "$issue_id" ] || continue
        add_failure "${doc_label}「审查问题台账」存在重复 Issue ID：${issue_id}"
    done <<< "$duplicate_issue_ids"

    while IFS=$'\t' read -r issue_id _view _severity issue_status _evidence_anchor _handoff_target review_round _resolution; do
        [ -n "$issue_id" ] || continue
        policy_row=$(printf '%s\n' "$policy_rows" | awk -F'\t' -v target="$review_round" '$1 == target { print; exit }')
        if [ -z "$policy_row" ]; then
            add_failure "${doc_label}「审查问题台账」${issue_id} 的 Review Round=${review_round} 未在收敛轮次摘要中登记"
            continue
        fi

        unresolved_ids=$(printf '%s\n' "$policy_row" | awk -F'\t' '{print $4}')
        if is_review_issue_closed_status "$issue_status"; then
            if contains_issue_id_in_text "$unresolved_ids" "$issue_id"; then
                add_failure "${doc_label}「审查问题台账」${issue_id} 状态为 ${issue_status}，但仍出现在 ${review_round} 的未关闭 Issue IDs"
            fi
        else
            if ! contains_issue_id_in_text "$unresolved_ids" "$issue_id"; then
                add_failure "${doc_label}「审查问题台账」${issue_id} 状态为 ${issue_status}，但未出现在 ${review_round} 的未关闭 Issue IDs"
            fi
        fi
    done <<< "$ledger_rows"

    while IFS=$'\t' read -r round _result _fail_count unresolved_ids _action _note; do
        [ -n "$round" ] || continue
        while IFS= read -r issue_id; do
            [ -n "$issue_id" ] || continue
            issue_count_in_ledger=$(printf '%s\n' "$ledger_issue_ids" | grep -xc "$issue_id" || true)
            if [ "$issue_count_in_ledger" -eq 0 ]; then
                add_failure "${doc_label}「收敛轮次摘要」${round} 的未关闭 Issue IDs 包含 ${issue_id}，但未在审查问题台账登记"
            elif [ "$issue_count_in_ledger" -gt 1 ]; then
                add_failure "${doc_label}「收敛轮次摘要」${round} 的未关闭 Issue IDs 包含重复登记的 ${issue_id}"
            fi
        done <<< "$(extract_issue_ids_from_text "$unresolved_ids")"
    done <<< "$policy_rows"

    streak_violations=$(printf '%s\n' "$policy_rows" | awk -F'\t' '
        function normalize_ids(raw, tmp) {
            tmp = raw
            gsub(/，|；|;|\//, ",", tmp)
            gsub(/[[:space:]]+/, "", tmp)
            return tmp
        }
        {
            round = $1
            action = $5
            ids = normalize_ids($4)
            if (round !~ /^R[0-9]+$/) next
            round_num = substr(round, 2) + 0
            n = split(ids, arr, /,/)
            for (i = 1; i <= n; i++) {
                id = arr[i]
                if (id !~ /^[A-Z]{1,5}-[0-9]{3,}$/) continue
                if ((id in prev_round) && prev_round[id] == round_num - 1) {
                    streak[id]++
                } else {
                    streak[id] = 1
                }
                prev_round[id] = round_num
                if (streak[id] >= 3 && action != "BLOCKED") {
                    print id "\t" round
                }
            }
        }
    ')
    while IFS=$'\t' read -r issue_id blocked_round; do
        [ -n "$issue_id" ] || continue
        add_failure "${doc_label} 中 ${issue_id} 已连续 3 轮未关闭，但 ${blocked_round} 的控制动作不是 BLOCKED"
    done <<< "$streak_violations"

    if [ "$latest_action" = "ASK_USER" ]; then
        add_failure "${doc_label} 收敛轮次 ${latest_round} 已触发 ASK_USER，需用户裁决后才能完成"
    fi
    if [ "$latest_action" = "BLOCKED" ]; then
        add_failure "${doc_label} 收敛轮次 ${latest_round} 已标记 BLOCKED，需先解除阻塞后才能完成"
    fi

    return 0
}

# --- 承接验证 ---

validate_handoff_entry() {
    local issue_id="$1" handoff_content="$2"
    local line
    line=$(printf '%s\n' "$handoff_content" | { grep -F "$issue_id" || true; } | head -1)
    [ -n "$line" ] || return 1

    local after_id
    after_id=$(printf '%s' "$line" | sed -E "s/.*${issue_id}[^:：]*([:：])?[[:space:]]*//" | sed -E 's/^[[:space:]`]+//' | sed -E 's/[[:space:]`]+$//')
    [ -z "$after_id" ] && return 1

    if printf '%s' "$after_id" | grep -qiE '^(已查看|已阅|待处理|后续处理|TBD|TODO|N\/A|无|—|-)$'; then
        return 1
    fi

    return 0
}

# --- 审查文件基础校验 ---

check_review_file() {
    local file="$1" label="$2" prefix="$3"
    local verdict issue_count issue_ids issue_id_count

    if [ ! -f "$file" ]; then
        add_failure "${label}审查文件不存在：$file"
        return
    fi

    if [ ! -s "$file" ]; then
        add_failure "${label}审查文件为空：$file"
        return
    fi

    verdict=$(parse_review_header "$file" verdict)
    issue_count=$(parse_review_header "$file" issue_count)

    [ -n "$verdict" ] || add_failure "${label}审查文件缺少可解析的 Verdict：$file"
    [ -n "$issue_count" ] || add_failure "${label}审查文件缺少可解析的 Issue Count：$file"

    issue_ids=$(extract_issue_ids "$file" "$prefix")
    issue_id_count=$(printf '%s\n' "$issue_ids" | sed '/^$/d' | wc -l | tr -d ' ')

    if [ -n "$verdict" ] && [ -n "$issue_count" ]; then
        if [ "$verdict" = "PASS" ] && [ "$issue_count" != "0" ]; then
            add_failure "${label}审查 Verdict=PASS 时 Issue Count 必须为 0：$file"
        fi
        if [ "$verdict" != "PASS" ] && [ "$issue_count" = "0" ]; then
            add_failure "${label}审查 Verdict=${verdict} 时 Issue Count 不得为 0：$file"
        fi
    fi

    if [ "$issue_id_count" = "0" ] && [ -n "$issue_count" ] && [ "$issue_count" != "0" ]; then
        add_failure "${label}审查存在问题但未给出稳定 issue id（${prefix}-NNN）：$file"
    fi

    if [ "$verdict" = "FAIL" ]; then
        add_failure "${label}审查存在 FAIL 结论：$file"
    fi
}


# --- 标准输出 ---

output_failures() {
    local title="$1" context="${2:-}"

    if [ -n "$FAILURES" ]; then
        # 熔断器默认仍然 fail-close；仅在显式声明 HOOK_ALLOW_FAIL_OPEN=1 时才允许 warn 放行
        local max_retries=3
        local strict_block="${HOOK_STRICT_BLOCK:-1}"
        local allow_fail_open="${HOOK_ALLOW_FAIL_OPEN:-0}"
        local counter_file="${TMPDIR:-/tmp}/claude_hook_${SESSION_ID:-unknown}_retry"
        local count=0
        [ -f "$counter_file" ] && count=$(cat "$counter_file" 2>/dev/null || echo 0)
        count=$((count + 1))
        printf '%s' "$count" > "$counter_file" 2>/dev/null || true

        if [ "$count" -gt "$max_retries" ] && [ "$strict_block" != "1" ] && [ "$allow_fail_open" = "1" ]; then
            echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
            echo -e "[WARN] ${title}（已连续失败 ${count} 次，熔断放行）：" >&2
            echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
            [ -n "$context" ] && echo -e "Target：$context" >&2
            echo -e "$FAILURES" >&2
            echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
            emit_decision_json "allow" "${title}
${FAILURES}"
            # 不删除计数器文件——保持高值使后续调用持续放行
            exit 0
        fi

        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo -e "${title}：" >&2
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        [ -n "$context" ] && echo -e "Target：$context" >&2
        echo -e "$FAILURES" >&2
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

        # stdout JSON block decision: 让 Stop hook 真正阻止 Claude 停止
        local reason
        reason=$(printf '%s\n%s' "$title" "$FAILURES")
        emit_decision_json "block" "$reason"

        exit 2
    else
        # 成功时重置计数器
        local counter_file="${TMPDIR:-/tmp}/claude_hook_${SESSION_ID:-unknown}_retry"
        rm -f "$counter_file" 2>/dev/null || true
    fi
}
