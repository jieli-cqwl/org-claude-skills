#!/bin/bash
# hooks/lib/common.sh — Completion Hook 公共函数库
# 所有 completion hook 共享的初始化、定位、解析和输出函数
# 使用方法: source "$(dirname "$0")/lib/common.sh"

# --- JSON 解析 ---

json_get() {
    printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null || true
}

# --- 初始化（读取 stdin + 定位仓库根目录） ---

hook_init() {
    INPUT=$(cat || true)

    CWD=$(json_get '.cwd')
    SESSION_ID=$(json_get '.session_id // .sessionId')
    TRANSCRIPT_PATH=$(json_get '.transcript_path // .transcriptPath')

    [ -n "$CWD" ] && [ -d "$CWD" ] || exit 0
    cd "$CWD" || exit 0

    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        REPO_ROOT=$(git rev-parse --show-toplevel)
    else
        REPO_ROOT="$CWD"
    fi

    cd "$REPO_ROOT" || exit 0
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

# --- 从 PRD 交付计划解析当前 Phase 上下文 ---
# $1: feature 目录路径
# 设置全局变量:
#   CURRENT_PHASE_REL
#   CURRENT_PHASE_WORK_DIR
#   CURRENT_PHASE_UNIT_RELS
#   CURRENT_PHASE_UNIT_WORK_DIRS

resolve_current_phase_context_from_prd() {
    local feature_dir="$1"
    local prd_file="${feature_dir}/prd.md"
    local plan_section parsed

    CURRENT_PHASE_REL=""
    CURRENT_PHASE_WORK_DIR=""
    CURRENT_PHASE_UNIT_RELS=""
    CURRENT_PHASE_UNIT_WORK_DIRS=""

    [ -f "$prd_file" ] || return 0

    plan_section=$(sed -n '/## 交付计划/,/^## [^#]/p' "$prd_file")
    [ -n "$plan_section" ] || return 0

    parsed=$(printf '%s\n' "$plan_section" | awk '
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

# --- 从 PRD 交付计划解析当前 UNIT 工作区 ---
# $1: feature 目录路径
# $2: 锚定文件名（如 design.md、plan.md）
# 设置全局变量: UNIT_WORK_DIR（当前 UNIT 的工作区路径）

resolve_work_dir_from_prd() {
    local feature_dir="$1" anchor_file="$2"
    UNIT_WORK_DIR=""

    resolve_current_phase_context_from_prd "$feature_dir"

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

# --- 从 PRD 交付计划解析当前 Phase 的全部 UNIT 工作区 ---
# $1: feature 目录路径
# 设置全局变量: ALL_UNIT_WORK_DIRS（当前 Phase 的 UNIT 工作区路径，换行分隔）

resolve_all_unit_work_dirs() {
    local feature_dir="$1"
    ALL_UNIT_WORK_DIRS=""

    resolve_current_phase_context_from_prd "$feature_dir"
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

    found_dirs=$(find "$feature_dir" -mindepth 2 -maxdepth 2 -type d -path '*/phase-*/unit-*' 2>/dev/null | sort)
    if [ -z "$found_dirs" ]; then
        return 0
    fi

    first_phase_dir=$(printf '%s\n' "$found_dirs" | head -1 | sed -E 's#(.*/phase-[0-9]+)/unit-[0-9]+$#\1#')
    ALL_UNIT_WORK_DIRS=$(printf '%s\n' "$found_dirs" | grep "^${first_phase_dir}/unit-" || true)
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

# --- 从 PRD 交付计划解析当前 Phase 工作区 ---
# $1: feature 目录路径
# $2: 锚定文件名（如 design.md）——在 phase-{N}/ 级别查找
# 设置全局变量: PHASE_WORK_DIR

resolve_phase_work_dir_from_prd() {
    local feature_dir="$1" anchor_file="$2"
    PHASE_WORK_DIR=""

    resolve_current_phase_context_from_prd "$feature_dir"
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

# --- codex-doc-review 上下文解析 ---
# 目标：从 transcript / 已写报告中解析 reviewed docs、scope、显式 work_dir，
# 并推导唯一 canonical work_dir，避免复用 PRD->unit 的旧解析逻辑。

sanitize_inline_value() {
    printf '%s' "$1" | tr -d '\`"' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

normalize_codex_doc_review_doc_path() {
    local raw="$1"
    raw=$(sanitize_inline_value "$raw")
    raw="${raw%/}"

    case "$raw" in
        "$REPO_ROOT"/docs/*)
            printf '%s\n' "${raw#$REPO_ROOT/}"
            ;;
        docs/*)
            printf '%s\n' "$raw"
            ;;
    esac
}

extract_codex_doc_review_doc_paths_from_file() {
    local file="$1"
    [ -f "$file" ] || return 0

    grep -Eo '(/[^`"[:space:]]+)?docs/[^`"[:space:]]+\.md' "$file" 2>/dev/null \
        | while IFS= read -r raw; do
            normalize_codex_doc_review_doc_path "$raw"
        done \
        | sed '/^$/d; /codex-doc-review-report\.md$/d' \
        | sort -u || true
}

extract_codex_doc_review_scope_from_file() {
    local file="$1"
    [ -f "$file" ] || return 0

    grep -Eo '((scope|stage)|审查阶段([[:space:]]*\(stage\))?)[[:space:]]*[:=][[:space:]]*[^,[:space:]]+' "$file" 2>/dev/null \
        | tail -1 \
        | sed -E 's/^.*[:=][[:space:]]*//' || true
}

extract_codex_doc_review_work_dir_from_file() {
    local file="$1"
    [ -f "$file" ] || return 0

    grep -Eo 'work_dir[[:space:]]*[:=][[:space:]]*[^,[:space:]]+' "$file" 2>/dev/null \
        | tail -1 \
        | sed -E 's/^[^:=]+[:=][[:space:]]*//' || true
}

normalize_codex_doc_review_scope_family() {
    local raw
    raw=$(sanitize_inline_value "$1" | tr '[:upper:]' '[:lower:]')

    case "$raw" in
        product*) printf '%s\n' "product" ;;
        design*) printf '%s\n' "design" ;;
        test-design*|test_design*|test-cases*|testcases*) printf '%s\n' "test-design" ;;
        tech-lead*|tech_lead*|techlead*|plan*) printf '%s\n' "tech-lead" ;;
        *) printf '%s\n' "" ;;
    esac
}

infer_codex_doc_review_scope_family_from_docs() {
    local docs="$1"

    if printf '%s\n' "$docs" | grep -qE '^docs/[^/]+/(prd\.md|product-cross-review\.md|units/UNIT-[0-9]+\.md)$'; then
        printf '%s\n' "product"
        return 0
    fi

    if printf '%s\n' "$docs" | grep -qE '/design\.md$'; then
        printf '%s\n' "design"
        return 0
    fi

    if printf '%s\n' "$docs" | grep -qE '/(test-cases|test-design)\.md$'; then
        printf '%s\n' "test-design"
        return 0
    fi

    if printf '%s\n' "$docs" | grep -qE '/(plan|tech-lead)\.md$'; then
        printf '%s\n' "tech-lead"
        return 0
    fi

    printf '%s\n' ""
}

normalize_codex_doc_review_work_dir() {
    local raw="$1"
    raw=$(sanitize_inline_value "$raw")
    [ -n "$raw" ] || return 0

    python3 - "$raw" "$CWD" "$REPO_ROOT" <<'PY'
import os
import sys

raw, cwd, repo = sys.argv[1:]
if not raw:
    print("")
    raise SystemExit(0)

base = repo if raw.startswith("docs/") else (cwd or repo)
path = raw if os.path.isabs(raw) else os.path.join(base, raw)
print(os.path.realpath(path).rstrip("/"))
PY
}

find_codex_doc_review_reports_for_feature() {
    local feature_rel="$1"
    local report docs report_features count

    find "$REPO_ROOT" -type f -name 'codex-doc-review-report.md' 2>/dev/null \
        | while IFS= read -r report; do
            case "$report" in
                "$REPO_ROOT/$feature_rel"/*|"$REPO_ROOT/$feature_rel/codex-doc-review-report.md")
                    printf '%s\n' "$report"
                    continue
                    ;;
                "$REPO_ROOT/codex-doc-review-report.md")
                    docs=$(extract_codex_doc_review_doc_paths_from_file "$report")
                    report_features=$(printf '%s\n' "$docs" | sed -nE 's#^(docs/[^/]+)/.*#\1#p' | sort -u)
                    count=$(printf '%s\n' "$report_features" | sed '/^$/d' | wc -l | tr -d ' ')
                    if [ "$count" = "1" ] && [ "$(printf '%s\n' "$report_features" | head -1)" = "$feature_rel" ]; then
                        printf '%s\n' "$report"
                    fi
                    ;;
            esac
        done \
        | sort -u
}

# 设置全局变量：
# FEATURE_DIR
# CODEX_DOC_REVIEW_DOCS
# CODEX_DOC_REVIEW_SCOPE
# CODEX_DOC_REVIEW_SCOPE_FAMILY
# CODEX_DOC_REVIEW_EXPLICIT_WORK_DIR
# CODEX_DOC_REVIEW_CANONICAL_WORK_DIR
# CODEX_DOC_REVIEW_REPORT_CANDIDATES
resolve_codex_doc_review_context() {
    CODEX_DOC_REVIEW_DOCS=""
    CODEX_DOC_REVIEW_SCOPE=""
    CODEX_DOC_REVIEW_SCOPE_FAMILY=""
    CODEX_DOC_REVIEW_EXPLICIT_WORK_DIR=""
    CODEX_DOC_REVIEW_CANONICAL_WORK_DIR=""
    CODEX_DOC_REVIEW_REPORT_CANDIDATES=""
    FEATURE_DIR=""

    local transcript_docs="" transcript_scope="" explicit_work_dir="" docs="" feature_roots="" feature_count feature_rel

    if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        transcript_docs=$(extract_codex_doc_review_doc_paths_from_file "$TRANSCRIPT_PATH")
        transcript_scope=$(extract_codex_doc_review_scope_from_file "$TRANSCRIPT_PATH")
        explicit_work_dir=$(extract_codex_doc_review_work_dir_from_file "$TRANSCRIPT_PATH")
    fi

    docs=$(printf '%s\n' "$transcript_docs" | sed '/^$/d' | sort -u)

    if [ -z "$docs" ]; then
        local report
        while IFS= read -r report; do
            [ -f "$report" ] || continue
            docs=$(printf '%s\n%s\n' "$docs" "$(extract_codex_doc_review_doc_paths_from_file "$report")" | sed '/^$/d' | sort -u)
            [ -n "$transcript_scope" ] || transcript_scope=$(extract_codex_doc_review_scope_from_file "$report")
        done < <(find "$REPO_ROOT" -type f -name 'codex-doc-review-report.md' 2>/dev/null | sort)
    fi

    if [ -z "$docs" ]; then
        add_failure "无法从 transcript 或现有报告解析被审查文档列表（缺少 docs/.../*.md 证据）"
        return 0
    fi

    feature_roots=$(printf '%s\n' "$docs" | sed -nE 's#^(docs/[^/]+)/.*#\1#p' | sort -u)
    feature_count=$(printf '%s\n' "$feature_roots" | sed '/^$/d' | wc -l | tr -d ' ')
    if [ "$feature_count" = "0" ]; then
        add_failure "被审查文档不在 docs/{feature}/ 下，无法定位 feature：$(printf '%s' "$docs" | tr '\n' ' ')"
        return 0
    fi
    if [ "$feature_count" != "1" ]; then
        add_failure "被审查文档跨多个 feature，禁止一次审查混用：$(printf '%s' "$feature_roots" | tr '\n' ' ')"
        return 0
    fi

    feature_rel=$(printf '%s\n' "$feature_roots" | head -1)
    FEATURE_DIR="$REPO_ROOT/$feature_rel"
    CODEX_DOC_REVIEW_DOCS="$docs"
    CODEX_DOC_REVIEW_SCOPE="$transcript_scope"
    CODEX_DOC_REVIEW_SCOPE_FAMILY=$(normalize_codex_doc_review_scope_family "$transcript_scope")
    CODEX_DOC_REVIEW_EXPLICIT_WORK_DIR=$(normalize_codex_doc_review_work_dir "$explicit_work_dir")

    if [ -z "$CODEX_DOC_REVIEW_SCOPE_FAMILY" ]; then
        CODEX_DOC_REVIEW_SCOPE_FAMILY=$(infer_codex_doc_review_scope_family_from_docs "$docs")
    fi
    if [ -z "$CODEX_DOC_REVIEW_SCOPE_FAMILY" ]; then
        add_failure "无法解析 codex-doc-review 的 scope，请显式指定 product*/design*/test-design*/tech-lead*"
        return 0
    fi

    local phases="" units="" count canonical=""
    case "$CODEX_DOC_REVIEW_SCOPE_FAMILY" in
        product)
            if printf '%s\n' "$docs" | grep -qE '^docs/[^/]+/phase-[0-9]+/'; then
                add_failure "product 审查不允许包含 phase/unit 级文档，请拆分为独立 design/test-design/tech-lead 审查"
                return 0
            fi
            canonical="$FEATURE_DIR"
            ;;
        design|tech-lead)
            phases=$(printf '%s\n' "$docs" | sed -nE 's#^(docs/[^/]+/phase-[0-9]+)/.*#\1#p' | sort -u)
            count=$(printf '%s\n' "$phases" | sed '/^$/d' | wc -l | tr -d ' ')
            if [ "$count" = "0" ]; then
                add_failure "${CODEX_DOC_REVIEW_SCOPE_FAMILY} 审查必须绑定唯一 phase 目录，但当前输入未指向 phase 文档"
                return 0
            fi
            if [ "$count" != "1" ]; then
                add_failure "${CODEX_DOC_REVIEW_SCOPE_FAMILY} 审查跨多个 phase，必须拆分执行：$(printf '%s' "$phases" | tr '\n' ' ')"
                return 0
            fi
            canonical="$REPO_ROOT/$(printf '%s\n' "$phases" | head -1)"
            ;;
        test-design)
            units=$(printf '%s\n' "$docs" | sed -nE 's#^(docs/[^/]+/phase-[0-9]+/unit-[0-9]+)/.*#\1#p' | sort -u)
            count=$(printf '%s\n' "$units" | sed '/^$/d' | wc -l | tr -d ' ')
            if [ "$count" = "0" ]; then
                add_failure "test-design 审查必须绑定唯一 unit 目录，但当前输入未指向 unit 文档"
                return 0
            fi
            if [ "$count" != "1" ]; then
                add_failure "test-design 审查跨多个 unit，必须拆分执行：$(printf '%s' "$units" | tr '\n' ' ')"
                return 0
            fi
            canonical="$REPO_ROOT/$(printf '%s\n' "$units" | head -1)"
            ;;
    esac

    CODEX_DOC_REVIEW_CANONICAL_WORK_DIR="$canonical"
    CODEX_DOC_REVIEW_REPORT_CANDIDATES=$(find_codex_doc_review_reports_for_feature "$feature_rel")

    if [ -n "$CODEX_DOC_REVIEW_EXPLICIT_WORK_DIR" ] && [ "$CODEX_DOC_REVIEW_EXPLICIT_WORK_DIR" != "$CODEX_DOC_REVIEW_CANONICAL_WORK_DIR" ]; then
        add_failure "显式 work_dir 与 canonical 目录不一致：传入=${CODEX_DOC_REVIEW_EXPLICIT_WORK_DIR}，canonical=${CODEX_DOC_REVIEW_CANONICAL_WORK_DIR}"
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

# --- 审查迭代轮次检查 ---

check_review_iteration() {
    local file="$1" label="$2"
    local verdict issue_count round1_new round2_new delta_new

    [ -f "$file" ] && [ -s "$file" ] || return 0

    # 检查覆盖自评段（兼容 ## 和 ### 标题级别）
    if ! grep -qE '^#{2,3} 覆盖自评' "$file"; then
        add_failure "${label}审查文件缺少「覆盖自评」段（未执行覆盖评估）：$file"
    fi

    # 检查审查轮次标记（兼容 ## 和 ### 标题级别）
    if ! grep -qE '(#{2,3} 审查轮次|Round [0-9])' "$file"; then
        add_failure "${label}审查文件缺少审查轮次标记（未执行多轮迭代审查）：$file"
    fi

    # Verdict=PASS 且 Issue Count=0 时，检查是否有 Round 2 确认声明
    verdict=$(parse_review_header "$file" verdict)
    issue_count=$(parse_review_header "$file" issue_count)
    round1_new=$(sed -nE 's/^\|[[:space:]]*Round[[:space:]]*1[[:space:]]*\|[[:space:]]*[^|]+\|[[:space:]]*([0-9]+)[[:space:]]*\|.*$/\1/p' "$file" | head -1 || true)
    round2_new=$(sed -nE 's/^\|[[:space:]]*Round[[:space:]]*2[[:space:]]*\|[[:space:]]*[^|]+\|[[:space:]]*([0-9]+)[[:space:]]*\|.*$/\1/p' "$file" | head -1 || true)
    delta_new=$(sed -nE 's/^- 新增发现:[[:space:]]*([0-9]+)[[:space:]]*条[[:space:]]*$/\1/p' "$file" | head -1 || true)

    [ -n "$round1_new" ] || add_failure "${label}审查文件缺少 Round 1 新增发现数（审查轮次表不完整）：$file"
    [ -n "$round2_new" ] || add_failure "${label}审查文件缺少 Round 2 新增发现数（审查轮次表不完整）：$file"
    [ -n "$delta_new" ] || add_failure "${label}审查文件缺少 Delta 声明中的“新增发现”计数：$file"

    if [ "$verdict" = "PASS" ] && [ "$issue_count" = "0" ]; then
        if ! grep -qE "(经 Round 2 确认|经对抗审查确认|Round 2.*收敛)" "$file"; then
            add_failure "${label}审查 Verdict=PASS 且 Issue Count=0，但缺少 Round 2 确认声明（疑似 shallow pass）：$file"
        fi
        [ -n "$round2_new" ] && [ "$round2_new" = "0" ] || add_failure "${label}审查 Verdict=PASS 且 Issue Count=0，但 Round 2 新增发现数不为 0：$file"
        [ -n "$delta_new" ] && [ "$delta_new" = "0" ] || add_failure "${label}审查 Verdict=PASS 且 Issue Count=0，但 Delta 声明新增发现不为 0：$file"
    fi
}

# --- 标准输出 ---

output_failures() {
    local title="$1" context="${2:-}"

    if [ -n "$FAILURES" ]; then
        # 熔断器：同一 session 连续失败超过阈值后降级为 warn（exit 0），防止死循环
        local max_retries=3
        local strict_block="${HOOK_STRICT_BLOCK:-0}"
        local counter_file="${TMPDIR:-/tmp}/claude_hook_${SESSION_ID:-unknown}_retry"
        local count=0
        [ -f "$counter_file" ] && count=$(cat "$counter_file" 2>/dev/null || echo 0)
        count=$((count + 1))
        printf '%s' "$count" > "$counter_file" 2>/dev/null || true

        if [ "$count" -gt "$max_retries" ] && [ "$strict_block" != "1" ]; then
            echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
            echo -e "[WARN] ${title}（已连续失败 ${count} 次，熔断放行）：" >&2
            echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
            [ -n "$context" ] && echo -e "Target：$context" >&2
            echo -e "$FAILURES" >&2
            echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
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
        jq -nc --arg r "$reason" '{"decision":"block","reason":$r}'

        exit 2
    else
        # 成功时重置计数器
        local counter_file="${TMPDIR:-/tmp}/claude_hook_${SESSION_ID:-unknown}_retry"
        rm -f "$counter_file" 2>/dev/null || true
    fi
}
