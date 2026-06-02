#!/usr/bin/env bash
# PostCompact Hook: compaction 后记录摘要证据，并注入最小恢复契约。
# stdout 必须只输出 Claude Code hook JSON；compact_summary 只落本地文件，不回灌上下文。
# 版本: v2.3 2026-06-02

set -euo pipefail
umask 077

normalize_positive_int() {
  local value="$1"
  local fallback="$2"

  case "$value" in
    ''|*[!0-9]*)
      printf '%s\n' "$fallback"
      return 0
      ;;
  esac

  if [ "$value" -lt 1 ]; then
    printf '%s\n' "$fallback"
    return 0
  fi

  printf '%s\n' "$value"
}

json_value() {
  local filter="$1"
  jq -r "$filter" <<<"$PAYLOAD_JSON"
}

INPUT="$(cat)"
if [ -z "$INPUT" ]; then
  INPUT='{}'
fi

PAYLOAD_JSON="$(jq -c '.' <<<"$INPUT")"
TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
STATE_DIR="${CLAUDE_POST_COMPACT_STATE_DIR:-$HOME/.claude/hooks/state/post-compact}"
LOG_FILE="${CLAUDE_POST_COMPACT_LOG_FILE:-$HOME/.claude/hooks/post_compact.log}"
EVENT_RETENTION="$(normalize_positive_int "${CLAUDE_POST_COMPACT_EVENT_RETENTION:-100}" "100")"
LATEST_MAX_AGE_DAYS="$(normalize_positive_int "${CLAUDE_POST_COMPACT_LATEST_MAX_AGE_DAYS:-14}" "14")"

SESSION_ID="$(json_value '.session_id // .sessionId // "unknown-session"')"
TRIGGER="$(json_value '.trigger // "unknown"')"
SAFE_SESSION_ID="$(printf '%s' "$SESSION_ID" | tr -c '[:alnum:]_.-' '_')"
if [ -z "$SAFE_SESSION_ID" ]; then
  SAFE_SESSION_ID="unknown-session"
fi

mkdir -p "$STATE_DIR" "$(dirname "$LOG_FILE")"

STATE_FILE="$STATE_DIR/latest-$SAFE_SESSION_ID.json"
EVENTS_FILE="$STATE_DIR/events.jsonl"
LOCK_DIR="$STATE_DIR/.lock"

# 多个 Claude Code 会话可能同时 compact；锁住共享 events.jsonl，保证审计流不交叉写坏。
lock_attempts=50
until mkdir "$LOCK_DIR" 2>/dev/null; do
  lock_attempts=$((lock_attempts - 1))
  if [ "$lock_attempts" -le 0 ]; then
    printf '[%s] PostCompact hook failed: state lock timeout state_dir=%s\n' "$TIMESTAMP" "$STATE_DIR" >> "$LOG_FILE"
    exit 1
  fi
  sleep 0.1
done
trap 'rm -rf "$LOCK_DIR"' EXIT

EVENT_JSON="$(jq -nc \
  --arg recorded_at "$TIMESTAMP" \
  --arg compact_summary_ref "$STATE_FILE" \
  --argjson payload "$PAYLOAD_JSON" \
  '{
    schema_version: "1.0",
    recorded_at: $recorded_at,
    hook_event_name: ($payload.hook_event_name // $payload.hookEventName // "PostCompact"),
    session_id: ($payload.session_id // $payload.sessionId // "unknown-session"),
    transcript_path: ($payload.transcript_path // $payload.transcriptPath // ""),
    cwd: ($payload.cwd // ""),
    trigger: ($payload.trigger // "unknown"),
    compact_summary: ($payload.compact_summary // ""),
    summary_length: (($payload.compact_summary // "") | length),
    compact_summary_ref: $compact_summary_ref
  }')"

printf '%s\n' "$EVENT_JSON" > "$STATE_FILE"
printf '%s\n' "$EVENT_JSON" >> "$EVENTS_FILE"

if [ "$(wc -l < "$EVENTS_FILE" | tr -d ' ')" -gt "$EVENT_RETENTION" ]; then
  EVENTS_TMP="$(mktemp "$STATE_DIR/events.XXXXXX")"
  tail -n "$EVENT_RETENTION" "$EVENTS_FILE" > "$EVENTS_TMP"
  mv "$EVENTS_TMP" "$EVENTS_FILE"
fi

find "$STATE_DIR" -type f -name 'latest-*.json' -mtime +"$LATEST_MAX_AGE_DAYS" -delete

printf '[%s] PostCompact hook triggered trigger=%s session_id=%s state=%s\n' \
  "$TIMESTAMP" "$TRIGGER" "$SESSION_ID" "$STATE_FILE" >> "$LOG_FILE"

ADDITIONAL_CONTEXT="$(cat <<EOF
[PostCompact 上下文恢复]

Compaction 是有损压缩。不要假设你还记得压缩前细节。

本次 compact summary 已本地落盘：
- compact_summary_ref: $STATE_FILE
- trigger: $TRIGGER
- session_id: $SESSION_ID

按以下顺序恢复最小上下文（非全量重读）：

1. Read ~/.claude/rules/ 下所有规则文件
2. 如果正在执行 Skill：
   a. Read 该 Skill 的 SKILL.md（仅 SKILL.md，不读 references）
   b. 确认当前步骤编号和状态
3. 优先读取最新接手入口（如 worklog.md），确认：
   - mode / stage / status / scope_ref / state_ref / next_ref / blocker / decision_needed
4. 做新鲜度检查：
   - 如果 goal / owner / lane / phase 已变化，先回源纠偏，不继续执行
   - 如果 state_ref / next_ref 缺失、过期或冲突，先修锚点
5. 最小回源：
   - 只 Read state_ref、next_ref、当前步骤需要的输入文档与 reference
   - 如果 compact 后摘要不足以恢复，再 Read compact_summary_ref
   - 如果在 Plan Mode 中：Read 当前计划文件（plans/ 目录）
   - supporting/ 只作补充，不作真源
6. 继续或阻塞：
   - 信息足够：继续未完成的步骤
   - 信息不足：进入 blocked / waiting_on / unblock_condition / decision_needed
7. readiness / uncertainty 场景额外允许保留最多 3 条理由胶囊：
   - 当前缺少哪个前提或证据
   - 当前优先证明什么
   - 失败后需要谁裁决

FORBIDDEN:
- 不要重读 docs/{feature}/ 下的所有文档——只读当前步骤需要的
- 不要重读已完成步骤的 reference 文件
- 不要在对话中复述恢复的内容——直接继续工作
- 不要把恢复提示或 compact_summary_ref 当成真源
- 不要凭印象补全细节——不确定就 Read 确认
EOF
)"

jq -n --arg additionalContext "$ADDITIONAL_CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "PostCompact",
    additionalContext: $additionalContext
  }
}'
