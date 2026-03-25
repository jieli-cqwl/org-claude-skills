#!/bin/bash
# 危险命令阻止脚本
# 触发时机: PreToolUse:Bash
# 功能: 阻止可能导致系统损坏的危险命令
# 版本: v1.0 2026-01-28

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[ -z "$COMMAND" ] && exit 0

# 危险模式列表（只阻止真正危险的命令）
# 注意：项目内的 rm -rf ./build/* 等清理操作是合理的，不阻止

# 1. 系统目录删除
if echo "$COMMAND" | grep -qE 'rm\s+(-[rf]+\s+)*/$'; then
    echo "🛑 阻止删除根目录" >&2
    exit 2
fi
if echo "$COMMAND" | grep -qE 'rm\s+(-[rf]+\s+)*(~|/home/?|/Users/?|\$HOME/?)(\s|$)'; then
    echo "🛑 阻止删除用户目录" >&2
    exit 2
fi
if echo "$COMMAND" | grep -qE 'rm\s+(-[rf]+\s+)*/(etc|var|usr)'; then
    echo "🛑 阻止删除系统目录" >&2
    exit 2
fi

# 2. Fork bomb
if echo "$COMMAND" | grep -qE ':\(\)\s*\{.*\|.*&'; then
    echo "🛑 阻止 fork bomb" >&2
    exit 2
fi

# 3. 远程代码执行
if echo "$COMMAND" | grep -qE '(curl|wget).*\|\s*(bash|sh|zsh)'; then
    echo "🛑 阻止远程代码执行" >&2
    exit 2
fi

# 4. 磁盘格式化/覆写
if echo "$COMMAND" | grep -qE 'mkfs\.|dd\s+.*of=/dev/|>\s*/dev/sd[a-z]'; then
    echo "🛑 阻止磁盘格式化/写入" >&2
    exit 2
fi

# 5. 系统关机/重启（防止误操作）
# 只匹配作为命令执行的情况，不匹配字符串内容
# 排除引号内的内容（如 grep "shutdown"、pkill -f "Application"）
COMMAND_NO_QUOTES=$(echo "$COMMAND" | sed 's/"[^"]*"//g' | sed "s/'[^']*'//g")
if echo "$COMMAND_NO_QUOTES" | grep -qE '(^|\s|;|\||&)(shutdown|reboot|poweroff)(\s|$|;|\||&)|^init\s+[06]'; then
    echo "🛑 阻止系统关机/重启命令" >&2
    exit 2
fi

# 6. 修改系统关键文件
if echo "$COMMAND" | grep -qE '>\s*/etc/(passwd|shadow|sudoers)'; then
    echo "🛑 阻止修改系统关键文件" >&2
    exit 2
fi

# 7. 危险的 chmod
if echo "$COMMAND" | grep -qE 'chmod\s+(-R\s+)?(777|000)\s+/|chmod\s+-R\s+777\s'; then
    echo "🛑 阻止危险的权限修改" >&2
    exit 2
fi

# 8. chown -R 系统目录
if echo "$COMMAND" | grep -qE 'chown\s+(-R\s+)?\S+\s+/(etc|var|usr|bin|sbin|lib|boot)'; then
    echo "🛑 阻止修改系统目录所有权" >&2
    exit 2
fi

# 9. git push --force 到 main/master
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*(--force|-f)\s+.*\s+(main|master)(\s|$)'; then
    echo "🛑 阻止 force push 到 main/master" >&2
    exit 2
fi

# 10. 清空历史（可能是攻击者行为）
if echo "$COMMAND" | grep -qE 'history\s+-c|>\s*~/\.(bash_history|zsh_history)'; then
    echo "⚠️ 检测到清空历史命令，请确认意图" >&2
    # 不阻止，只警告
fi

exit 0
