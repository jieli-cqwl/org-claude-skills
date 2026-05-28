#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -d "$ROOT/shared/runtime" || fail "missing shared/runtime directory"
test ! -f "$ROOT/shared/runtime/runtime-catalog.json" || fail "runtime-catalog.json should be retired"
test ! -f "$ROOT/tools/community/render_runtime_contract.py" || fail "runtime contract renderer should be retired"

if rg -n 'RUNTIME_(?:ASSISTANT|RULE_[A-Z0-9_]+)_CONTRACT' "$ROOT/shared/assistant.md" "$ROOT/shared/rules" "$ROOT/install.sh" >/dev/null 2>&1; then
  fail "assistant/rules runtime contracts should be inline, not rendered through RUNTIME_*_CONTRACT placeholders"
fi

for path in \
  "reference/协作判断.md" \
  "reference/测试规范.md" \
  "reference/代码复用.md" \
  "reference/完成前验证.md" \
  "reference/设计原则.md" \
  "reference/影响范围分析.md" \
  "reference/系统调试.md" \
  "reference/全栈开发.md" \
  "reference/性能效率.md" \
  "reference/硬编码治理规范.md"; do
  rg -n "\{\{RUNTIME_HOME\}\}/$path" "$ROOT/shared/assistant.md" >/dev/null 2>&1 \
    || fail "missing assistant runtime reference: $path"
done

if rg -n '补充细则：|只提供补充细则|必要时查看|可参考' "$ROOT/shared/assistant.md" >/dev/null 2>&1; then
  fail "assistant runtime references must be direct read instructions, not weak supplement notes"
fi

python3 - "$ROOT/shared/assistant.md" <<'PY' || fail "assistant runtime references must keep one reference per item"
import re
import sys
from pathlib import Path

assistant = Path(sys.argv[1])
text = assistant.read_text(encoding="utf-8")
items = [
    paragraph.strip()
    for paragraph in re.split(r"\n(?=- )", text)
    if "{{RUNTIME_HOME}}/reference/" in paragraph
]

violations = []
for item in items:
    refs = re.findall(r"\{\{RUNTIME_HOME\}\}/reference/[^` )，。；]+\.md", item)
    first_line = item.splitlines()[0]
    if len(refs) != 1:
        violations.append(f"{assistant}: expected one reference in item: {first_line}")

if violations:
    print("\n".join(violations), file=sys.stderr)
    raise SystemExit(1)
PY

if rg -n 'reference.*自动加载|自动加载.*reference|runtime 自动加载内容|依赖自动加载|不需挂载|不做正文挂载' "$ROOT/shared" -g '*.md' >/dev/null 2>&1; then
  fail "shared runtime docs must not describe runtime references as automatically loaded"
fi

collaboration_boundary_sentence="涉及共享文件、共享契约、共享数据写入或同一用户路径时，先验收共享前置任务；无独立边界则串行执行。"
for path in \
  "$ROOT/shared/rules/执行纪律.md" \
  "$ROOT/shared/reference/影响范围分析.md"; do
  rg -F "$collaboration_boundary_sentence" "$path" >/dev/null 2>&1 \
    || fail "missing collaboration boundary sentence: $path"
done

if rg -F '先验收共享前置；无法拆出时串行执行' "$ROOT/shared/rules/执行纪律.md" "$ROOT/shared/reference/影响范围分析.md" >/dev/null 2>&1; then
  fail "collaboration boundary wording must name the shared prerequisite task and independent boundary"
fi

echo "[PASS] runtime contract inline"
