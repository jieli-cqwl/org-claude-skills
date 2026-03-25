#!/bin/bash
# api-equiv-diff.sh — 新旧接口行为等价比对工具（bash 3 兼容）
# 用法: bash ~/.claude/skills/equivalence-guard/scripts/api-equiv-diff.sh [work_dir]
# 约定: 输入/输出均位于 {work_dir}/equivalence/

set -euo pipefail

WORK_DIR="${1:-.}"
EQUIV_DIR="$WORK_DIR/equivalence"
MANIFEST_FILE="$EQUIV_DIR/endpoint-manifest.csv"
REQUEST_SET_FILE="$EQUIV_DIR/request-set.jsonl"
SNAPSHOT_FILE="$EQUIV_DIR/snapshot.lock"
CONFIG_FILE="$EQUIV_DIR/equiv-config.yaml"

DIFF_CSV="$EQUIV_DIR/diff-details.csv"
RESULTS_JSONL="$EQUIV_DIR/api-results.jsonl"
SUMMARY_JSON="$EQUIV_DIR/tool-summary.json"
REPORT_MD="$EQUIV_DIR/equivalence-report.md"
EVIDENCE_MD="$EQUIV_DIR/evidence-index.md"

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/api-equiv-diff.XXXXXX")
trap 'rm -rf "$TMP_DIR" 2>/dev/null || true' EXIT

MANIFEST_IDS_FILE="$TMP_DIR/manifest_ids.txt"
VERIFIED_IDS_FILE="$TMP_DIR/verified_ids.txt"
UNVERIFIED_IDS_FILE="$TMP_DIR/unverified_ids.txt"
WHITELIST_FILE="$TMP_DIR/whitelist_pairs.txt"

CURL_TIMEOUT_SECONDS=15
DEFAULT_NORMALIZE_FIELDS='["traceId","requestId","timestamp","nonce"]'

trim() {
    local v="$1"
    v=$(printf '%s' "$v" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    printf '%s' "$v"
}

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: missing command: $cmd" >&2
        exit 2
    fi
}

compute_sha256() {
    local file="$1"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
        return 0
    fi
    sha256sum "$file" | awk '{print $1}'
}

hash_text() {
    local text="$1"
    if command -v shasum >/dev/null 2>&1; then
        printf '%s' "$text" | shasum -a 256 | awk '{print $1}'
        return 0
    fi
    printf '%s' "$text" | sha256sum | awk '{print $1}'
}

read_yaml_list_items() {
    local file="$1" section="$2"
    awk -v target="$section" '
        function trim(s) {
            gsub(/^[ \t]+|[ \t]+$/, "", s)
            return s
        }
        $0 ~ ("^[[:space:]]*" target ":[[:space:]]*$") {in_section=1; next}
        in_section && /^[^[:space:]]/ {in_section=0}
        in_section && /^[[:space:]]*-[[:space:]]*/ {
            item=$0
            sub(/^[[:space:]]*-[[:space:]]*/, "", item)
            sub(/[[:space:]]+#.*$/, "", item)
            item=trim(item)
            gsub(/^["'\'']|["'\'']$/, "", item)
            if (item != "") print item
        }
    ' "$file"
}

load_whitelist_pairs() {
    local file="$1"
    awk '
        function trim(s) {
            gsub(/^[ \t]+|[ \t]+$/, "", s)
            return s
        }
        function clean(s) {
            s=trim(s)
            gsub(/^["'\'']|["'\'']$/, "", s)
            return s
        }
        /^whitelist:[[:space:]]*$/ {in_section=1; next}
        in_section && /^[^[:space:]]/ {in_section=0}
        !in_section {next}
        {
            line=$0
            sub(/^[ \t]+/, "", line)
            if (line ~ /^-[ \t]*api_id:[ \t]*/) {
                if (api_id != "" && field_path != "") print api_id "|" field_path
                sub(/^-[ \t]*api_id:[ \t]*/, "", line)
                api_id=clean(line)
                field_path=""
                next
            }
            if (line ~ /^api_id:[ \t]*/) {
                sub(/^api_id:[ \t]*/, "", line)
                api_id=clean(line)
                next
            }
            if (line ~ /^field_path:[ \t]*/) {
                sub(/^field_path:[ \t]*/, "", line)
                field_path=clean(line)
                if (api_id != "" && field_path != "") {
                    print api_id "|" field_path
                    api_id=""
                    field_path=""
                }
            }
        }
        END {
            if (api_id != "" && field_path != "") print api_id "|" field_path
        }
    ' "$file" > "$WHITELIST_FILE"
}

to_json_value() {
    local raw="$1"
    if printf '%s' "$raw" | jq -ce . >/dev/null 2>&1; then
        printf '%s' "$raw" | jq -c .
    else
        jq -cn --arg v "$raw" '$v'
    fi
}

normalize_json_value() {
    local input_json="$1"
    printf '%s' "$input_json" | jq -c \
        --argjson fields "$NORMALIZE_FIELDS_JSON" \
        --argjson ignore_order "$IGNORE_ORDER_JSON" '
        def scrub($fields):
            if type == "object" then
                with_entries(select(.key as $k | ($fields | index($k) | not)) | .value |= scrub($fields))
            elif type == "array" then
                map(scrub($fields))
            else
                .
            end;
        def sort_json:
            if type == "array" then
                map(sort_json) | sort_by(tostring)
            elif type == "object" then
                with_entries(.value |= sort_json)
            else
                .
            end;
        scrub($fields) | (if $ignore_order then sort_json else . end)
    '
}

value_token() {
    local value_json="$1"
    local h
    if [ "$value_json" = "__MISSING__" ]; then
        printf '%s' "__MISSING__"
        return 0
    fi
    h=$(hash_text "$value_json" | cut -c1-16)
    printf 'masked_%s' "$h"
}

csv_escape() {
    local v="$1"
    v=${v//\"/\"\"}
    printf '"%s"' "$v"
}

build_url() {
    local base_url="$1" path="$2"
    if printf '%s' "$path" | grep -qE '^https?://|^file://'; then
        printf '%s' "$path"
        return 0
    fi
    if [ -z "$base_url" ]; then
        printf '%s' "$path"
        return 0
    fi
    base_url="${base_url%/}"
    if [[ "$path" == /* ]]; then
        printf '%s%s' "$base_url" "$path"
    else
        printf '%s/%s' "$base_url" "$path"
    fi
}

perform_request() {
    local base_url="$1" method="$2" path="$3" headers_json="$4" body_json="$5"
    local url response_file error_file status_code body_text
    local -a curl_args

    url=$(build_url "$base_url" "$path")
    response_file="$TMP_DIR/resp.$RANDOM.json"
    error_file="$TMP_DIR/resp.$RANDOM.err"
    : > "$response_file"
    : > "$error_file"

    curl_args=(-sS --max-time "$CURL_TIMEOUT_SECONDS" -X "$method" "$url" -o "$response_file" -w "%{http_code}")

    if printf '%s' "$headers_json" | jq -e 'type=="object"' >/dev/null 2>&1; then
        while IFS=$'\t' read -r hk hv; do
            [ -n "$hk" ] || continue
            curl_args+=(-H "$hk: $hv")
        done < <(printf '%s' "$headers_json" | jq -r 'to_entries[] | [.key, (.value|tostring)] | @tsv' 2>/dev/null || true)
    fi

    if [ -n "$body_json" ] && [ "$body_json" != "null" ] && [[ "$method" =~ ^(POST|PUT|PATCH|DELETE)$ ]]; then
        curl_args+=(-H "Content-Type: application/json" --data "$body_json")
    fi

    status_code=$(curl "${curl_args[@]}" 2>"$error_file" || true)
    body_text=$(cat "$response_file" 2>/dev/null || true)

    if ! printf '%s' "$status_code" | grep -qE '^[0-9]{3}$'; then
        status_code="000"
        if [ -z "$body_text" ]; then
            body_text=$(cat "$error_file" 2>/dev/null || true)
        fi
    fi

    printf '%s\n%s' "$status_code" "$body_text"
}

load_manifest_ids() {
    awk -F',' '
        function trim(s) {
            gsub(/^[ \t]+|[ \t]+$/, "", s)
            return s
        }
        NR == 1 {next}
        {
            id=trim($1)
            if (id != "") print id
        }
    ' "$MANIFEST_FILE" | sort -u > "$MANIFEST_IDS_FILE"
}

lookup_manifest_by_api() {
    local target="$1"
    awk -F',' -v api_id="$target" '
        function trim(s) {
            gsub(/^[ \t]+|[ \t]+$/, "", s)
            return s
        }
        NR == 1 {next}
        {
            id=trim($1)
            if (id == api_id) {
                method=toupper(trim($2))
                path=trim($3)
                old_base=trim($4)
                new_base=trim($5)
                if (method == "") method="GET"
                print method "\t" path "\t" old_base "\t" new_base
                exit
            }
        }
    ' "$MANIFEST_FILE"
}

lookup_api_by_route() {
    local target_method="$1" target_path="$2"
    awk -F',' -v m="$target_method" -v p="$target_path" '
        function trim(s) {
            gsub(/^[ \t]+|[ \t]+$/, "", s)
            return s
        }
        NR == 1 {next}
        {
            method=toupper(trim($2))
            path=trim($3)
            if (method == m && path == p) {
                print trim($1)
                exit
            }
        }
    ' "$MANIFEST_FILE"
}

add_verified_id() {
    local api_id="$1"
    if ! grep -Fxq "$api_id" "$VERIFIED_IDS_FILE" 2>/dev/null; then
        echo "$api_id" >> "$VERIFIED_IDS_FILE"
    fi
}

is_whitelisted() {
    local api_id="$1" field_path="$2"
    grep -Fxq "${api_id}|${field_path}" "$WHITELIST_FILE" 2>/dev/null
}

write_report_header() {
    printf 'api_id,field_path,old_value_masked,new_value_masked,status\n' > "$DIFF_CSV"
    : > "$RESULTS_JSONL"
    : > "$VERIFIED_IDS_FILE"
}

build_diff_json() {
    local old_json="$1" new_json="$2" output_file="$3"
    jq -n \
        --argjson old "$old_json" \
        --argjson new "$new_json" '
        def pstr($p):
            "$" + ($p | map(if type=="number" then "[" + (tostring) + "]" else "." + . end) | join(""));
        def pick($obj; $p):
            if ($p | length) == 0 then $obj else (try ($obj | getpath($p)) catch "__MISSING__") end;
        (([($old | paths)] + [($new | paths)]) | unique) as $all
        | (if ($all | length) == 0 then [ [] ] else $all end)
        | map({
            field_path: pstr(.),
            old: pick($old; .),
            new: pick($new; .)
          } | select(.old != .new))
    ' > "$output_file"
}

build_unverified_ids() {
    : > "$UNVERIFIED_IDS_FILE"
    while IFS= read -r manifest_id; do
        [ -n "$manifest_id" ] || continue
        if ! grep -Fxq "$manifest_id" "$VERIFIED_IDS_FILE" 2>/dev/null; then
            echo "$manifest_id" >> "$UNVERIFIED_IDS_FILE"
        fi
    done < "$MANIFEST_IDS_FILE"
}

generate_summary_report_and_index() {
    local git_sha run_id generated_at snapshot_id manifest_hash config_hash
    local coverage_percent final_status current_time
    local total_endpoints verified_endpoints total_requests pass_requests
    local failed_requests unresolved_diffs whitelisted_diffs unverified_json
    local unresolved_lines whitelist_lines unverified_lines

    git_sha=$(git -C "$WORK_DIR" rev-parse HEAD 2>/dev/null || git rev-parse HEAD 2>/dev/null || echo "unknown")
    current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    run_id="eq-$(date -u +%Y%m%dT%H%M%SZ)-$$"
    generated_at="$current_time"
    snapshot_id=$(grep -E '^[[:space:]]*snapshot_id:[[:space:]]*' "$SNAPSHOT_FILE" 2>/dev/null | head -1 | sed -E 's/.*:[[:space:]]*//' | sed -E 's/^["'\'']|["'\'']$//g' || true)
    [ -n "$snapshot_id" ] || snapshot_id="unknown"
    manifest_hash=$(compute_sha256 "$MANIFEST_FILE")
    config_hash=$(compute_sha256 "$CONFIG_FILE")

    total_endpoints=$MANIFEST_TOTAL
    verified_endpoints=$VERIFIED_TOTAL
    total_requests=$REQUEST_TOTAL
    pass_requests=$PASS_REQUESTS
    failed_requests=$FAIL_REQUESTS
    unresolved_diffs=$UNRESOLVED_DIFFS
    whitelisted_diffs=$WHITELISTED_DIFFS
    unverified_json=$(jq -Rsc 'split("\n") | map(select(length>0))' "$UNVERIFIED_IDS_FILE")

    coverage_percent=$(awk "BEGIN { if ($total_endpoints == 0) print \"0.00\"; else printf \"%.2f\", ($verified_endpoints / $total_endpoints) * 100 }")
    if [ "$unresolved_diffs" -eq 0 ] && [ "$total_endpoints" -gt 0 ] && [ "$verified_endpoints" -eq "$total_endpoints" ]; then
        final_status="EQUIV_OK"
    else
        final_status="EQUIV_BLOCKED"
    fi

    jq -n \
        --arg status "$final_status" \
        --arg run_id "$run_id" \
        --arg git_sha "$git_sha" \
        --arg manifest_hash "$manifest_hash" \
        --arg config_hash "$config_hash" \
        --arg snapshot_id "$snapshot_id" \
        --arg generated_at "$generated_at" \
        --argjson total_endpoints "$total_endpoints" \
        --argjson verified_endpoints "$verified_endpoints" \
        --argjson total_requests "$total_requests" \
        --argjson pass_requests "$pass_requests" \
        --argjson failed_requests "$failed_requests" \
        --argjson unresolved_diffs "$unresolved_diffs" \
        --argjson whitelisted_diffs "$whitelisted_diffs" \
        --argjson unverified_endpoints "$unverified_json" \
        '{
            status: $status,
            run_id: $run_id,
            git_sha: $git_sha,
            manifest_hash: $manifest_hash,
            config_hash: $config_hash,
            snapshot_id: $snapshot_id,
            generated_at: $generated_at,
            total_endpoints: $total_endpoints,
            verified_endpoints: $verified_endpoints,
            total_requests: $total_requests,
            pass_requests: $pass_requests,
            failed_requests: $failed_requests,
            unresolved_diffs: $unresolved_diffs,
            whitelisted_diffs: $whitelisted_diffs,
            unverified_endpoints: $unverified_endpoints
        }' > "$SUMMARY_JSON"

    {
        echo "# 行为等价报告"
        echo "- 状态: ${final_status}"
        echo "- 生成时间: ${current_time}"
        echo "- run_id: ${run_id}"
        echo "- git_sha: ${git_sha}"
        echo "- manifest_hash: ${manifest_hash}"
        echo "- config_hash: ${config_hash}"
        echo "- snapshot_id: ${snapshot_id}"
        echo "- generated_at: ${generated_at}"
        echo "- 接口总数: ${total_endpoints}"
        echo "- 已验证: ${verified_endpoints} / ${total_endpoints}（覆盖率 ${coverage_percent}%）"
        echo "- 通过: ${pass_requests}"
        echo "- 差异（白名单内）: ${whitelisted_diffs}"
        echo "- 差异（未解决）: ${unresolved_diffs}"
        echo ""
        echo "## 未解决差异"
        echo "| api_id | field_path | old_value_masked | new_value_masked | status |"
        echo "|--------|------------|------------------|------------------|--------|"
        unresolved_lines=$(awk -F',' '
            function unq(s) {
                gsub(/^"|"$/, "", s)
                gsub(/""/, "\"", s)
                return s
            }
            NR > 1 && $5 == "\"FAIL\"" {
                printf "| %s | %s | %s | %s | FAIL |\n", unq($1), unq($2), unq($3), unq($4)
            }
        ' "$DIFF_CSV" || true)
        if [ -n "$unresolved_lines" ]; then
            printf '%s\n' "$unresolved_lines"
        else
            echo "| - | - | - | - | - |"
        fi
        echo ""
        echo "## 白名单差异"
        echo "| api_id | field_path | old_value_masked | new_value_masked | status |"
        echo "|--------|------------|------------------|------------------|--------|"
        whitelist_lines=$(awk -F',' '
            function unq(s) {
                gsub(/^"|"$/, "", s)
                gsub(/""/, "\"", s)
                return s
            }
            NR > 1 && $5 == "\"WHITELISTED\"" {
                printf "| %s | %s | %s | %s | WHITELISTED |\n", unq($1), unq($2), unq($3), unq($4)
            }
        ' "$DIFF_CSV" || true)
        if [ -n "$whitelist_lines" ]; then
            printf '%s\n' "$whitelist_lines"
        else
            echo "| - | - | - | - | - |"
        fi
        echo ""
        echo "## 未验证接口"
        echo "| api_id | reason |"
        echo "|--------|--------|"
        unverified_lines=$(awk '{print "| " $0 " | missing request-set entry |"}' "$UNVERIFIED_IDS_FILE" || true)
        if [ -n "$unverified_lines" ]; then
            printf '%s\n' "$unverified_lines"
        else
            echo "| - | - |"
        fi
    } > "$REPORT_MD"

    {
        echo "# 等价性证据索引"
        echo ""
        echo "| api_id | method | path | old_status | new_status | result | diff_count | verified_at |"
        echo "|--------|--------|------|------------|------------|--------|------------|-------------|"
        if [ -s "$RESULTS_JSONL" ]; then
            while IFS= read -r line; do
                [ -n "$line" ] || continue
                api_id=$(printf '%s' "$line" | jq -r '.api_id // "-"')
                method=$(printf '%s' "$line" | jq -r '.method // "-"')
                path=$(printf '%s' "$line" | jq -r '.path // "-"')
                old_status=$(printf '%s' "$line" | jq -r '.old_status // "-"')
                new_status=$(printf '%s' "$line" | jq -r '.new_status // "-"')
                result=$(printf '%s' "$line" | jq -r '.result // "-"')
                diff_count=$(printf '%s' "$line" | jq -r '.diff_count // 0')
                verified_at=$(printf '%s' "$line" | jq -r '.verified_at // "-"')
                printf '| %s | %s | %s | %s | %s | %s | %s | %s |\n' "$api_id" "$method" "$path" "$old_status" "$new_status" "$result" "$diff_count" "$verified_at"
            done < "$RESULTS_JSONL"
        else
            echo "| - | - | - | - | - | - | 0 | - |"
        fi
    } > "$EVIDENCE_MD"

    printf '%s\n' "$final_status"
}

require_command jq
require_command curl

for f in "$MANIFEST_FILE" "$REQUEST_SET_FILE" "$SNAPSHOT_FILE" "$CONFIG_FILE"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: missing input: $f" >&2
        exit 2
    fi
    if [ ! -s "$f" ]; then
        echo "ERROR: empty input: $f" >&2
        exit 2
    fi
done

normalize_items=$(read_yaml_list_items "$CONFIG_FILE" "normalize_fields" | jq -Rsc 'split("\n") | map(select(length>0))' 2>/dev/null || true)
if [ -n "$normalize_items" ] && [ "$normalize_items" != "[]" ]; then
    NORMALIZE_FIELDS_JSON="$normalize_items"
else
    NORMALIZE_FIELDS_JSON="$DEFAULT_NORMALIZE_FIELDS"
fi

ignore_order_raw=$(grep -E '^[[:space:]]*ignore_order:[[:space:]]*(true|false)' "$CONFIG_FILE" 2>/dev/null | head -1 | sed -E 's/.*:[[:space:]]*//' | tr '[:upper:]' '[:lower:]' || true)
if [ "$ignore_order_raw" = "false" ]; then
    IGNORE_ORDER_JSON="false"
else
    IGNORE_ORDER_JSON="true"
fi

load_whitelist_pairs "$CONFIG_FILE"
load_manifest_ids
write_report_header

MANIFEST_TOTAL=$(wc -l < "$MANIFEST_IDS_FILE" | tr -d ' ')
REQUEST_TOTAL=0
PASS_REQUESTS=0
FAIL_REQUESTS=0
UNRESOLVED_DIFFS=0
WHITELISTED_DIFFS=0

while IFS= read -r request_line || [ -n "$request_line" ]; do
    request_line=$(trim "$request_line")
    [ -n "$request_line" ] || continue
    REQUEST_TOTAL=$((REQUEST_TOTAL + 1))

    if ! printf '%s' "$request_line" | jq -e . >/dev/null 2>&1; then
        echo "WARN: skip invalid jsonl line: $REQUEST_TOTAL" >&2
        FAIL_REQUESTS=$((FAIL_REQUESTS + 1))
        continue
    fi

    api_id=$(printf '%s' "$request_line" | jq -r '.api_id // empty')
    method=$(printf '%s' "$request_line" | jq -r '.method // "GET"' | tr '[:lower:]' '[:upper:]')
    path=$(printf '%s' "$request_line" | jq -r '.path // empty')
    headers_json=$(printf '%s' "$request_line" | jq -c '.headers // {}')
    body_json=$(printf '%s' "$request_line" | jq -c '.body // .request_body // empty')

    if [ -z "$api_id" ] && [ -n "$path" ]; then
        api_id=$(lookup_api_by_route "$method" "$path")
    fi
    if [ -z "$api_id" ]; then
        api_id="UNKNOWN:${REQUEST_TOTAL}"
    fi

    manifest_row=$(lookup_manifest_by_api "$api_id")
    if [ -z "$manifest_row" ] && [ -n "$path" ]; then
        api_from_route=$(lookup_api_by_route "$method" "$path")
        if [ -n "$api_from_route" ]; then
            api_id="$api_from_route"
            manifest_row=$(lookup_manifest_by_api "$api_id")
        fi
    fi

    if [ -z "$manifest_row" ]; then
        unresolved_old=$(value_token "__MISSING__")
        unresolved_new=$(value_token "__MISSING__")
        printf '%s,%s,%s,%s,%s\n' \
            "$(csv_escape "$api_id")" \
            "$(csv_escape '$.endpoint')" \
            "$(csv_escape "$unresolved_old")" \
            "$(csv_escape "$unresolved_new")" \
            "$(csv_escape "FAIL")" >> "$DIFF_CSV"
        FAIL_REQUESTS=$((FAIL_REQUESTS + 1))
        UNRESOLVED_DIFFS=$((UNRESOLVED_DIFFS + 1))
        printf '{"api_id":"%s","method":"%s","path":"%s","old_status":"000","new_status":"000","result":"FAIL","diff_count":1,"verified_at":"%s"}\n' \
            "$api_id" "$method" "$path" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$RESULTS_JSONL"
        continue
    fi

    manifest_method=$(printf '%s' "$manifest_row" | awk -F'\t' '{print $1}')
    manifest_path=$(printf '%s' "$manifest_row" | awk -F'\t' '{print $2}')
    old_base=$(printf '%s' "$manifest_row" | awk -F'\t' '{print $3}')
    new_base=$(printf '%s' "$manifest_row" | awk -F'\t' '{print $4}')
    add_verified_id "$api_id"

    if [ -z "$body_json" ] || [ "$body_json" = "empty" ]; then
        body_json=""
    fi

    old_resp=$(perform_request "$old_base" "$manifest_method" "$manifest_path" "$headers_json" "$body_json")
    old_status=$(printf '%s' "$old_resp" | head -1)
    old_body_raw=$(printf '%s' "$old_resp" | sed '1d')

    new_resp=$(perform_request "$new_base" "$manifest_method" "$manifest_path" "$headers_json" "$body_json")
    new_status=$(printf '%s' "$new_resp" | head -1)
    new_body_raw=$(printf '%s' "$new_resp" | sed '1d')

    old_json=$(to_json_value "$old_body_raw")
    new_json=$(to_json_value "$new_body_raw")
    old_norm=$(normalize_json_value "$old_json")
    new_norm=$(normalize_json_value "$new_json")

    diff_json_file="$TMP_DIR/diff.${REQUEST_TOTAL}.json"
    build_diff_json "$old_norm" "$new_norm" "$diff_json_file"

    request_diff_count=0
    request_fail_count=0
    request_whitelist_count=0

    if [ "$old_status" != "$new_status" ]; then
        request_diff_count=$((request_diff_count + 1))
        if is_whitelisted "$api_id" '$.http_status'; then
            request_whitelist_count=$((request_whitelist_count + 1))
            status_text="WHITELISTED"
            WHITELISTED_DIFFS=$((WHITELISTED_DIFFS + 1))
        else
            request_fail_count=$((request_fail_count + 1))
            status_text="FAIL"
            UNRESOLVED_DIFFS=$((UNRESOLVED_DIFFS + 1))
        fi
        printf '%s,%s,%s,%s,%s\n' \
            "$(csv_escape "$api_id")" \
            "$(csv_escape '$.http_status')" \
            "$(csv_escape "$(value_token "$old_status")")" \
            "$(csv_escape "$(value_token "$new_status")")" \
            "$(csv_escape "$status_text")" >> "$DIFF_CSV"
    fi

    while IFS=$'\t' read -r field_path old_value_json new_value_json; do
        [ -n "$field_path" ] || continue
        request_diff_count=$((request_diff_count + 1))
        if is_whitelisted "$api_id" "$field_path"; then
            request_whitelist_count=$((request_whitelist_count + 1))
            status_text="WHITELISTED"
            WHITELISTED_DIFFS=$((WHITELISTED_DIFFS + 1))
        else
            request_fail_count=$((request_fail_count + 1))
            status_text="FAIL"
            UNRESOLVED_DIFFS=$((UNRESOLVED_DIFFS + 1))
        fi

        printf '%s,%s,%s,%s,%s\n' \
            "$(csv_escape "$api_id")" \
            "$(csv_escape "$field_path")" \
            "$(csv_escape "$(value_token "$old_value_json")")" \
            "$(csv_escape "$(value_token "$new_value_json")")" \
            "$(csv_escape "$status_text")" >> "$DIFF_CSV"
    done < <(jq -r '.[] | [.field_path, (.old | tojson), (.new | tojson)] | @tsv' "$diff_json_file")

    if [ "$request_fail_count" -gt 0 ]; then
        request_result="FAIL"
        FAIL_REQUESTS=$((FAIL_REQUESTS + 1))
    elif [ "$request_diff_count" -gt 0 ]; then
        request_result="WHITELISTED"
        PASS_REQUESTS=$((PASS_REQUESTS + 1))
    else
        request_result="PASS"
        PASS_REQUESTS=$((PASS_REQUESTS + 1))
    fi

    printf '{"api_id":"%s","method":"%s","path":"%s","old_status":"%s","new_status":"%s","result":"%s","diff_count":%s,"verified_at":"%s"}\n' \
        "$api_id" "$manifest_method" "$manifest_path" "$old_status" "$new_status" "$request_result" "$request_diff_count" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        >> "$RESULTS_JSONL"

    printf '%s %s old=%s new=%s diff=%s unresolved=%s\n' \
        "$api_id" "$request_result" "$old_status" "$new_status" "$request_diff_count" "$request_fail_count"
done < "$REQUEST_SET_FILE"

build_unverified_ids
VERIFIED_TOTAL=$(wc -l < "$VERIFIED_IDS_FILE" | tr -d ' ')

final_status=$(generate_summary_report_and_index)
if [ "$final_status" = "EQUIV_OK" ]; then
    exit 0
fi
exit 1
