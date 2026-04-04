#!/usr/bin/env bash
# review-fix-loop skill completion gate
# 职责：校验 transcript 中是否产出了完整的最终总结块

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMON_SH=""
for candidate in \
  "$SCRIPT_DIR/../../../hooks/lib/common.sh" \
  "$SCRIPT_DIR/../../../../shared/hooks/lib/common.sh"
do
  if [ -f "$candidate" ]; then
    COMMON_SH="$candidate"
    break
  fi
done

if [ -z "$COMMON_SH" ]; then
  echo "review-fix-loop completion_check 缺少 common.sh 依赖" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$COMMON_SH"
hook_init

if [ -z "${TRANSCRIPT_PATH:-}" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  add_failure "缺少 transcript_path，无法校验 review-fix-loop 最终输出"
  output_failures "review-fix-loop 完成校验未通过" ""
  exit 0
fi

LAST_BLOCK_LINE="$(grep -n '^=== 循环结束 ===$' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 | cut -d: -f1 || true)"
if [ -z "$LAST_BLOCK_LINE" ]; then
  add_failure "缺少最终输出块：=== 循环结束 ==="
  output_failures "review-fix-loop 完成校验未通过" ""
  exit 0
fi

FINAL_BLOCK="$(tail -n +"$LAST_BLOCK_LINE" "$TRANSCRIPT_PATH" | sed 's/[[:space:]]*$//' | sed '/^[[:space:]]*$/d')"
FIRST_LINE="$(printf '%s\n' "$FINAL_BLOCK" | sed -n '1p')"
[ "$FIRST_LINE" = '=== 循环结束 ===' ] || add_failure "最终输出块首行必须是：=== 循环结束 ==="

RESULT_LINE=""
RESTORE_LINE=""
HAS_RESULT=0
HAS_ROUNDS=0
HAS_START_SHA=0
HAS_STASH_SHA=0
HAS_NEW_FILES=0
HAS_RESTORE=0

while IFS= read -r line; do
  [ -n "$line" ] || continue
  case "$line" in
    '结果：'*)
      RESULT_LINE="$line"
      HAS_RESULT=1
      ;;
    '总轮次：'*)
      HAS_ROUNDS=1
      ;;
    '起始 SHA：'*)
      HAS_START_SHA=1
      ;;
    '基线 stash SHA：'*)
      HAS_STASH_SHA=1
      ;;
    '恢复命令：'*)
      RESTORE_LINE="$line"
      HAS_RESTORE=1
      ;;
    '循环新增文件：'*)
      HAS_NEW_FILES=1
      ;;
    '错误原因：'*|'剩余问题：'*|'剩余 findings：'*)
      ;;
    *)
      add_failure "最终输出块包含未识别行：$line"
      ;;
  esac
done <<EOF
$(printf '%s\n' "$FINAL_BLOCK" | sed -n '2,$p')
EOF

for field in '结果：' '总轮次：' '起始 SHA：' '基线 stash SHA：' '循环新增文件：'; do
  flag=0
  case "$field" in
    '结果：') flag="$HAS_RESULT" ;;
    '总轮次：') flag="$HAS_ROUNDS" ;;
    '起始 SHA：') flag="$HAS_START_SHA" ;;
    '基线 stash SHA：') flag="$HAS_STASH_SHA" ;;
    '循环新增文件：') flag="$HAS_NEW_FILES" ;;
  esac
  if [ "$flag" -ne 1 ]; then
    add_failure "最终输出缺少字段：$field"
  fi
done

case "$RESULT_LINE" in
  '结果：通过'|'结果：未通过'|'结果：不收敛'|'结果：评审器错误')
    ;;
  *)
    add_failure "结果字段非法，必须是：通过 | 未通过 | 不收敛 | 评审器错误"
    ;;
esac

if [ "$RESULT_LINE" != '结果：通过' ] && [ "$HAS_RESULT" -eq 1 ] && [ "$HAS_RESTORE" -ne 1 ]; then
  add_failure "非通过结果必须包含恢复命令"
fi

if [ "$HAS_RESTORE" -eq 1 ] && printf '%s\n' "$RESTORE_LINE" | grep -q 'git clean' 2>/dev/null; then
  add_failure "恢复命令禁止使用 git clean"
fi

output_failures "review-fix-loop 完成校验未通过" ""
exit 0
