#!/bin/bash
# 等价性报告完整性自动检查脚本
# 触发时机: equivalence-guard skill-local Stop
# 功能: 检查 equivalence 工件的输入完整性、证据指纹与状态一致性

set -euo pipefail

source "$(cd "$(dirname "$0")/../../../hooks/lib" && pwd)/common.sh"
hook_init
export HOOK_STRICT_BLOCK=1

EQUIV_REPORT=""

trim() {
    local v="$1"
    v=$(printf '%s' "$v" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    printf '%s' "$v"
}

extract_report_field() {
    local report_file="$1" key="$2"
    local line value

    line=$(grep -E "^[[:space:]]*[-*]?[[:space:]]*${key}[[:space:]]*[:：][[:space:]]*" "$report_file" 2>/dev/null | head -1 || true)
    value=$(printf '%s' "$line" | sed -E "s/^[[:space:]]*[-*]?[[:space:]]*${key}[[:space:]]*[:：][[:space:]]*//")
    value=$(trim "$value")
    printf '%s' "$value"
}

is_placeholder_value() {
    local v
    v=$(trim "$1")
    if [ -z "$v" ]; then
        return 0
    fi
    if printf '%s' "$v" | grep -qiE '^(待补|TBD|TODO|N/?A|无|未填写|\[.*\]|\{.*\}|-|—)$'; then
        return 0
    fi
    return 1
}

compute_sha256() {
    local file="$1"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" 2>/dev/null | awk '{print $1}'
        return 0
    fi
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" 2>/dev/null | awk '{print $1}'
        return 0
    fi
    printf '%s' ""
}

parse_epoch_utc() {
    local ts="$1"
    local epoch=""

    if epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null); then
        printf '%s' "$epoch"
        return 0
    fi

    if epoch=$(date -u -d "$ts" +%s 2>/dev/null); then
        printf '%s' "$epoch"
        return 0
    fi

    printf '%s' ""
}

# --- 报告文件定位 ---
if [ -n "${TRANSCRIPT_PATH:-}" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    EQUIV_REPORT=$(grep -oE '([^"[:space:]{}]+/)?equivalence/equivalence-report\.md' "$TRANSCRIPT_PATH" 2>/dev/null \
        | sed -E '/\{[^}]+\}/d' | sort -u | tail -1 || true)
fi

if [ -z "$EQUIV_REPORT" ] || [ ! -f "$EQUIV_REPORT" ]; then
    EQUIV_REPORT=$(find . -type f -path '*/equivalence/equivalence-report.md' 2>/dev/null | sort -r | head -1 || true)
fi

if [ -z "$EQUIV_REPORT" ] || [ ! -f "$EQUIV_REPORT" ]; then
    add_failure "EG1: 未找到 equivalence/equivalence-report.md"
    output_failures "等价性报告完整性检查未通过" ""
    exit 0
fi

if [ ! -s "$EQUIV_REPORT" ]; then
    add_failure "EG1: 等价性报告为空：$EQUIV_REPORT"
    output_failures "等价性报告完整性检查未通过" "$EQUIV_REPORT"
    exit 0
fi

EQUIV_DIR=$(dirname "$EQUIV_REPORT")
WORK_DIR=$(dirname "$EQUIV_DIR")
MANIFEST_FILE="$EQUIV_DIR/endpoint-manifest.csv"
REQUEST_SET_FILE="$EQUIV_DIR/request-set.jsonl"
SNAPSHOT_FILE="$EQUIV_DIR/snapshot.lock"
CONFIG_FILE="$EQUIV_DIR/equiv-config.yaml"
DIFF_FILE="$EQUIV_DIR/diff-details.csv"
EVIDENCE_INDEX="$EQUIV_DIR/evidence-index.md"
SUMMARY_FILE="$EQUIV_DIR/tool-summary.json"
MAX_AGE_SECONDS=$((24 * 60 * 60))

# --- EG2: 输入完整性 ---
for f in "$MANIFEST_FILE" "$REQUEST_SET_FILE" "$SNAPSHOT_FILE" "$CONFIG_FILE"; do
    if [ ! -f "$f" ]; then
        add_failure "EG2: 缺少输入文件：$f"
    elif [ ! -s "$f" ]; then
        add_failure "EG2: 输入文件为空：$f"
    fi
done

# --- EG3: 输出完整性 ---
for f in "$DIFF_FILE" "$EVIDENCE_INDEX"; do
    if [ ! -f "$f" ]; then
        add_failure "EG3: 缺少输出文件：$f"
    elif [ ! -s "$f" ]; then
        add_failure "EG3: 输出文件为空：$f"
    fi
done

if [ -f "$DIFF_FILE" ] && [ -s "$DIFF_FILE" ]; then
    header=$(head -1 "$DIFF_FILE")
    if ! printf '%s' "$header" | grep -qE '^api_id,field_path,old_value_masked,new_value_masked,status$'; then
        add_failure "EG3: diff-details.csv 表头不符合契约（api_id,field_path,old_value_masked,new_value_masked,status）"
    fi
fi

# --- EG4: 状态与证据指纹 ---
status_value=$(extract_report_field "$EQUIV_REPORT" "状态")
if [ -z "$status_value" ]; then
    status_value=$(extract_report_field "$EQUIV_REPORT" "status")
fi

if [ "$status_value" != "EQUIV_OK" ] && [ "$status_value" != "EQUIV_BLOCKED" ]; then
    add_failure "EG4: 状态非法（应为 EQUIV_OK 或 EQUIV_BLOCKED）：${status_value:-missing}"
fi

run_id=$(extract_report_field "$EQUIV_REPORT" "run_id")
git_sha=$(extract_report_field "$EQUIV_REPORT" "git_sha")
manifest_hash=$(extract_report_field "$EQUIV_REPORT" "manifest_hash")
config_hash=$(extract_report_field "$EQUIV_REPORT" "config_hash")
snapshot_id=$(extract_report_field "$EQUIV_REPORT" "snapshot_id")
generated_at=$(extract_report_field "$EQUIV_REPORT" "generated_at")

for kv in \
    "run_id:$run_id" \
    "git_sha:$git_sha" \
    "manifest_hash:$manifest_hash" \
    "config_hash:$config_hash" \
    "snapshot_id:$snapshot_id" \
    "generated_at:$generated_at"; do
    key="${kv%%:*}"
    value="${kv#*:}"
    if is_placeholder_value "$value"; then
        add_failure "EG4: 报告缺少有效证据字段 ${key}"
    fi
done

# --- EG5: 哈希/时间/结果一致性 ---
if [ -f "$MANIFEST_FILE" ] && [ -n "$manifest_hash" ]; then
    actual_manifest_hash=$(compute_sha256 "$MANIFEST_FILE")
    if [ -n "$actual_manifest_hash" ] && [ "$manifest_hash" != "$actual_manifest_hash" ]; then
        add_failure "EG5: manifest_hash 与 endpoint-manifest.csv 不一致"
    fi
fi

if [ -f "$CONFIG_FILE" ] && [ -n "$config_hash" ]; then
    actual_config_hash=$(compute_sha256 "$CONFIG_FILE")
    if [ -n "$actual_config_hash" ] && [ "$config_hash" != "$actual_config_hash" ]; then
        add_failure "EG5: config_hash 与 equiv-config.yaml 不一致"
    fi
fi

if [ -n "$generated_at" ]; then
    report_epoch=$(parse_epoch_utc "$generated_at")
    now_epoch=$(date -u +%s 2>/dev/null || echo "")
    if [ -z "$report_epoch" ]; then
        add_failure "EG5: generated_at 不是可解析 UTC 时间（示例 2026-03-23T10:00:00Z）"
    elif [ -n "$now_epoch" ]; then
        age=$((now_epoch - report_epoch))
        if [ "$age" -lt 0 ]; then
            add_failure "EG5: generated_at 晚于当前时间"
        elif [ "$age" -gt "$MAX_AGE_SECONDS" ]; then
            add_failure "EG5: 报告已过期（>${MAX_AGE_SECONDS}s）"
        fi
    fi
fi

if [ -f "$SUMMARY_FILE" ] && command -v jq >/dev/null 2>&1; then
    unresolved=$(jq -r '.unresolved_diffs // -1' "$SUMMARY_FILE" 2>/dev/null || echo "-1")
    total_endpoints=$(jq -r '.total_endpoints // 0' "$SUMMARY_FILE" 2>/dev/null || echo "0")
    verified_endpoints=$(jq -r '.verified_endpoints // 0' "$SUMMARY_FILE" 2>/dev/null || echo "0")

    if [ "$status_value" = "EQUIV_OK" ]; then
        if [ "$unresolved" != "0" ]; then
            add_failure "EG5: EQUIV_OK 但 unresolved_diffs != 0（${unresolved}）"
        fi
        if [ "$total_endpoints" != "$verified_endpoints" ]; then
            add_failure "EG5: EQUIV_OK 但覆盖不全（verified=${verified_endpoints}, total=${total_endpoints}）"
        fi
    fi
fi

output_failures "等价性报告完整性检查未通过" "$WORK_DIR"
exit 0
