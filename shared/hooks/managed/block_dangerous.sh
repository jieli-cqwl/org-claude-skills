#!/bin/bash
# Codex/Claude shared dangerous command blocker.

set -euo pipefail

INPUT="$(cat || true)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"

[ -n "$COMMAND" ] || exit 0

if printf '%s' "$COMMAND" | grep -qE 'rm\s+(-[rf]+\s+)*/$'; then
    echo "阻止删除根目录" >&2
    exit 2
fi
if printf '%s' "$COMMAND" | grep -qE "rm\\s+(-[rf]+\\s+)*(~|/home/?|/Users/?|\\$HOME/?)(\\s|$)"; then
    echo "阻止删除用户目录" >&2
    exit 2
fi
if printf '%s' "$COMMAND" | grep -qE 'rm\s+(-[rf]+\s+)*/(etc|var|usr)'; then
    echo "阻止删除系统目录" >&2
    exit 2
fi
if printf '%s' "$COMMAND" | grep -qE ':\(\)\s*\{.*\|.*&'; then
    echo "阻止 fork bomb" >&2
    exit 2
fi
if printf '%s' "$COMMAND" | grep -qE '(curl|wget).*\|\s*(bash|sh|zsh)'; then
    echo "阻止远程代码执行" >&2
    exit 2
fi
if printf '%s' "$COMMAND" | grep -qE 'mkfs\.|dd\s+.*of=/dev/|>\s*/dev/sd[a-z]'; then
    echo "阻止磁盘格式化或覆写" >&2
    exit 2
fi

COMMAND_NO_QUOTES="$(printf '%s' "$COMMAND" | sed 's/"[^"]*"//g' | sed "s/'[^']*'//g")"
if printf '%s' "$COMMAND_NO_QUOTES" | grep -qE '(^|\s|;|\||&)(shutdown|reboot|poweroff)(\s|$|;|\||&)|^init\s+[06]'; then
    echo "阻止系统关机或重启命令" >&2
    exit 2
fi
if printf '%s' "$COMMAND" | grep -qE '>\s*/etc/(passwd|shadow|sudoers)'; then
    echo "阻止修改系统关键文件" >&2
    exit 2
fi
if printf '%s' "$COMMAND" | grep -qE 'chmod\s+(-R\s+)?(777|000)\s+/|chmod\s+-R\s+777\s'; then
    echo "阻止危险权限修改" >&2
    exit 2
fi
if printf '%s' "$COMMAND" | grep -qE 'chown\s+(-R\s+)?\S+\s+/(etc|var|usr|bin|sbin|lib|boot)'; then
    echo "阻止修改系统目录所有权" >&2
    exit 2
fi
if printf '%s' "$COMMAND" | grep -qE 'git\s+push\s+.*(--force|-f)\s+.*\s+(main|master)(\s|$)'; then
    echo "阻止 force push 到 main/master" >&2
    exit 2
fi
if printf '%s' "$COMMAND_NO_QUOTES" | grep -qE '(^|\s|;|\||&)git\s+reset\b.*--hard(\s|$|;|\||&)'; then
    echo "阻止 git reset --hard" >&2
    exit 2
fi
if printf '%s' "$COMMAND_NO_QUOTES" | grep -qE '(^|\s|;|\||&)git\s+checkout\s+--\s+\.(\s|$|;|\||&)'; then
    echo "阻止 git checkout -- ." >&2
    exit 2
fi
if printf '%s' "$COMMAND_NO_QUOTES" | grep -qE 'git\s+clean\b.*-[a-zA-Z]*f'; then
    echo "阻止 git clean -f" >&2
    exit 2
fi

exit 0
