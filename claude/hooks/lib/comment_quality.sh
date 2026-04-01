#!/bin/bash
# hooks/lib/comment_quality.sh — 注释质量检查公共函数
# 统一用于 PreToolUse 与 TaskCompleted 的注释质量校验，避免规则漂移。

comment_normalize_mode() {
    local mode="${1:-warn}"
    mode=$(printf '%s' "$mode" | tr '[:upper:]' '[:lower:]')
    case "$mode" in
        enforce|warn) printf '%s' "$mode" ;;
        *) printf 'warn' ;;
    esac
}

comment_normalize_scope() {
    local scope="${1:-changed}"
    scope=$(printf '%s' "$scope" | tr '[:upper:]' '[:lower:]')
    case "$scope" in
        all|changed) printf '%s' "$scope" ;;
        *) printf 'changed' ;;
    esac
}

comment_is_supported_file() {
    local file_path="$1"
    [[ "$file_path" =~ \.(js|ts|jsx|tsx|vue|py|java|go|rs|cpp|c|cs)$ ]]
}

comment_is_test_file() {
    local file_path="$1"
    [[ "$file_path" =~ (__tests__/|_test\.|\.test\.|\.spec\.|/tests?/|/specs?/|/test_helpers/|/testing/|/fixtures/|/factories/|/conftest\.py$) ]]
}

comment_style_for_file() {
    local file_path="$1"
    case "$file_path" in
        *.py) echo "python" ;;
        *.java) echo "java" ;;
        *.go) echo "go" ;;
        *.js|*.ts|*.jsx|*.tsx|*.vue) echo "js_like" ;;
        *.rs|*.cpp|*.c|*.cs) echo "c_like" ;;
        *) echo "" ;;
    esac
}

comment_kind_label() {
    local kind="$1"
    case "$kind" in
        file) echo "文件" ;;
        function) echo "函数" ;;
        field) echo "字段" ;;
        class) echo "类型" ;;
        *) echo "代码块" ;;
    esac
}

comment_strip_markers() {
    local line="$1"
    line=$(printf '%s' "$line" | tr -d '\r')
    line=$(printf '%s' "$line" | sed -E "s/^[[:space:]]*(#|\/\/|\/\*+|\*+|\*\/)[[:space:]]*//")
    line=$(printf '%s' "$line" | sed -E "s/^[[:space:]]*\"\"\"[[:space:]]*//")
    line=$(printf '%s' "$line" | sed -E "s/^[[:space:]]*'''[[:space:]]*//")
    line=$(printf '%s' "$line" | sed -E "s/[[:space:]]*\*\/[[:space:]]*$//")
    line=$(printf '%s' "$line" | sed -E "s/[[:space:]]*\"\"\"[[:space:]]*$//")
    line=$(printf '%s' "$line" | sed -E "s/[[:space:]]*'''[[:space:]]*$//")
    printf '%s' "$line"
}

comment_is_effective_line() {
    local line text lower len
    line="$1"
    text=$(comment_strip_markers "$line")
    text=$(printf '%s' "$text" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    [ -z "$text" ] && return 1

    lower=$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')
    if printf '%s' "$lower" | grep -qE '^(todo|fixme|tbd|xxx|placeholder|comment|note|说明|注释|待补充|后续补充)$'; then
        return 1
    fi

    len=$(printf '%s' "$text" | awk '{print length($0)}')
    [ "${len:-0}" -lt 6 ] && return 1
    return 0
}

comment_is_comment_line() {
    local style="$1" line="$2" trimmed
    trimmed=$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//')

    if [ "$style" = "python" ]; then
        if [[ "$trimmed" == \#* ]]; then
            return 0
        fi
        if [[ "$trimmed" == "\"\"\""* ]] || [[ "$trimmed" == "'''"* ]]; then
            return 0
        fi
        return 1
    fi

    [[ "$trimmed" =~ ^(//|/\*|\*|\*/) ]]
}

comment_first_meaningful_line() {
    local content="$1"
    printf '%s\n' "$content" | awk '
    BEGIN { saw_shebang = 0 }
    {
        if ($0 ~ /^[[:space:]]*$/) {
            next
        }
        if (!saw_shebang && $0 ~ /^#!/) {
            saw_shebang = 1
            next
        }
        print $0
        exit
    }'
}

comment_collect_candidates() {
    local style="$1" content="$2"
    printf '%s\n' "$content" | awk -v style="$style" '
    function ltrim(s) { sub(/^[ \t]+/, "", s); return s }
    function rtrim(s) { sub(/[ \t]+$/, "", s); return s }
    function trim(s) { return rtrim(ltrim(s)) }
    function is_blank(s) { return s ~ /^[ \t]*$/ }
    function py_doc(s, t) {
        t = ltrim(s)
        return (substr(t, 1, 3) == "\"\"\"" || substr(t, 1, 3) == "\x27\x27\x27")
    }
    function is_comment(s, t) {
        t = ltrim(s)
        if (style == "python") {
            return (t ~ /^#/ || py_doc(t))
        }
        return (t ~ /^\/\// || t ~ /^\/\*/ || t ~ /^\*/ || t ~ /^\*\//)
    }
    function decl_kind(s, t) {
        t = ltrim(s)

        if (style == "python") {
            if (t ~ /^def[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/) {
                return "function"
            }
            if (t ~ /^class[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*[:\(]/) {
                return "class"
            }
            if (t ~ /^[A-Za-z_][A-Za-z0-9_]*[ \t]*:[ \t]*[^=]+(=[^=].*)?$/) {
                return "field"
            }
            return ""
        }

        if (style == "java") {
            if (t ~ /^(public|protected|private)[^;]*\([^\)]*\)[ \t]*\{?[ \t]*$/ && t !~ / class /) {
                return "function"
            }
            if (t ~ /^(public|protected|private)[^()]*;[ \t]*$/ && t !~ / class /) {
                return "field"
            }
            if (t ~ /^(public|protected|private)?[ \t]*class[ \t]+[A-Za-z_][A-Za-z0-9_]*/) {
                return "class"
            }
            return ""
        }

        if (style == "go") {
            if (t ~ /^func[ \t]+(\([^\)]*\)[ \t]*)?[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/) {
                return "function"
            }
            if (t ~ /^type[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]+struct/) {
                return "class"
            }
            return ""
        }

        if (style == "js_like") {
            if (t ~ /^function[ \t]+[A-Za-z_$][A-Za-z0-9_$]*[ \t]*\(/) {
                return "function"
            }
            if (t ~ /^(const|let|var)[ \t]+[A-Za-z_$][A-Za-z0-9_$]*[ \t]*=[ \t]*.*=>/) {
                return "function"
            }
            if (t ~ /^(public|protected|private|readonly|static)[^;]*\([^\)]*\)[ \t]*\{?[ \t]*$/) {
                return "function"
            }
            if (t ~ /^(class|export[ \t]+class)[ \t]+[A-Za-z_$][A-Za-z0-9_$]*/) {
                return "class"
            }
            if (t ~ /^(public|protected|private|readonly|static)[^()]*(:|=)[^;]*;[ \t]*$/) {
                return "field"
            }
            return ""
        }

        if (style == "c_like") {
            if (t ~ /^(class|struct)[ \t]+[A-Za-z_][A-Za-z0-9_]*/) {
                return "class"
            }
            if (t ~ /^(public|protected|private)?[ \t]*[A-Za-z_][A-Za-z0-9_<>\[\]:*& ,]+[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*\([^\)]*\)[ \t]*\{?[ \t]*$/ && t !~ /^(if|for|while|switch|catch)[ \t]*\(/) {
                return "function"
            }
            if (t ~ /^(public|protected|private)?[ \t]*[A-Za-z_][A-Za-z0-9_<>\[\]:*& ,]+[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*;[ \t]*$/ && t !~ /^typedef/) {
                return "field"
            }
            return ""
        }

        return ""
    }
    {
        lines[NR] = $0
    }
    END {
        for (i = 1; i <= NR; i++) {
            kind = decl_kind(lines[i])
            if (kind == "") {
                continue
            }

            decl = trim(lines[i])
            prev = i - 1
            gap = 0
            while (prev >= 1 && is_blank(lines[prev])) {
                prev--
                gap++
            }

            next_idx = i + 1
            while (next_idx <= NR && is_blank(lines[next_idx])) {
                next_idx++
            }

            comment = ""
            if (prev >= 1 && gap == 0 && is_comment(lines[prev])) {
                comment = trim(lines[prev])
            } else if (style == "python" && kind == "function" && next_idx <= NR && py_doc(lines[next_idx])) {
                comment = trim(lines[next_idx])
            }

            print i "\t" kind "\t" decl "\t" comment
        }
    }'
}

comment_check_content() {
    local file_path="$1"
    local content="$2"
    local header_required="${3:-1}"
    local style first_line violations count line_no kind decl comment kind_label

    comment_is_supported_file "$file_path" || return 0
    comment_is_test_file "$file_path" && return 0

    style=$(comment_style_for_file "$file_path")
    [ -z "$style" ] && return 0

    violations=""
    count=0

    if [ "$header_required" = "1" ]; then
        first_line=$(comment_first_meaningful_line "$content")
        if [ -n "$first_line" ]; then
            if ! comment_is_comment_line "$style" "$first_line"; then
                violations+="  - 文件注释缺失：文件头未提供注释（职责/边界说明）\n"
                count=$((count + 1))
            elif ! comment_is_effective_line "$first_line"; then
                violations+="  - 文件注释无效：请避免 TODO/空话，写清业务意图或约束\n"
                count=$((count + 1))
            fi
        fi
    fi

    while IFS=$'\t' read -r line_no kind decl comment; do
        [ -z "$line_no" ] && continue
        kind_label=$(comment_kind_label "$kind")
        if [ -z "$comment" ]; then
            violations+="  - ${kind_label}注释缺失：L${line_no} ${decl}\n"
            count=$((count + 1))
        elif ! comment_is_effective_line "$comment"; then
            violations+="  - ${kind_label}注释无效：L${line_no} ${decl}\n"
            count=$((count + 1))
        fi

        if [ "$count" -ge 10 ]; then
            violations+="  - 仅展示前 10 条注释问题，请先修复后重试\n"
            break
        fi
    done <<< "$(comment_collect_candidates "$style" "$content")"

    printf '%b' "$violations"
}

comment_check_file() {
    local file_path="$1"
    local header_required="${2:-1}"
    [ -f "$file_path" ] || return 0
    comment_check_content "$file_path" "$(cat "$file_path")" "$header_required"
}
