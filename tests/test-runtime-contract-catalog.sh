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
test -f "$ROOT/shared/rules/完成前验证.md" || fail "missing completion verification rule"
test ! -f "$ROOT/shared/rules/交付验收底线.md" || fail "legacy delivery acceptance rule should be retired"
test ! -f "$ROOT/shared/reference/完成前验证.md" || fail "completion verification should be a rule, not a reference"

python3 - "$ROOT/shared/rules/完成前验证.md" <<'PY' || fail "completion verification rule contract violated"
import re
import sys
from pathlib import Path

rule = Path(sys.argv[1])
text = rule.read_text(encoding="utf-8")
headings = set(re.findall(r"^## (.+)$", text, flags=re.MULTILINE))
required_headings = {
    "完成声明",
    "验收范围",
    "证据标准",
    "失败处理",
    "完成汇报",
}
missing_headings = sorted(required_headings - headings)
if missing_headings:
    raise SystemExit(f"missing headings: {', '.join(missing_headings)}")

bullet_text = "\n".join(line for line in text.splitlines() if line.startswith("- "))
topics = {
    "structured_status": ("PASS", "VERIFIED", "ALLOW", "SIGNED_OFF", "CLOSED"),
    "acceptance_scope": ("用户目标", "成功标准", "AC", "任务合同"),
    "current_evidence": ("当前工作区", "本次执行结果"),
    "blocked_states": ("未执行", "失败", "证据不足", "待裁决"),
    "real_implementation": ("真实实现", "部分实现", "单端完成"),
    "evidence_bypass": ("Mock/Stub/Fake", "日志摘要", "report 自引用"),
    "failure_bypass": ("skip", "xfail", "放宽断言", "改写验收口径"),
    "failure_boundary": ("目标内", "目标外", "用户裁决"),
}
missing_topics = [name for name, terms in topics.items() if not all(term in bullet_text for term in terms)]
if missing_topics:
    raise SystemExit(f"missing topics: {', '.join(missing_topics)}")
PY

if rg -n 'RUNTIME_(?:ASSISTANT|RULE_[A-Z0-9_]+)_CONTRACT' "$ROOT/shared/assistant.md" "$ROOT/shared/rules" "$ROOT/install.sh" >/dev/null 2>&1; then
  fail "assistant/rules runtime contracts should be inline, not rendered through RUNTIME_*_CONTRACT placeholders"
fi

for path in \
  "reference/协作判断.md" \
  "reference/测试规范.md" \
  "reference/设计原则.md" \
  "reference/影响范围分析.md" \
  "reference/系统调试.md" \
  "reference/全栈开发.md" \
  "reference/性能效率.md" \
  "reference/硬编码治理规范.md"; do
  rg -n "\{\{RUNTIME_HOME\}\}/$path" "$ROOT/shared/assistant.md" >/dev/null 2>&1 \
    || fail "missing assistant runtime reference: $path"
done

rg -n "\{\{RUNTIME_HOME\}\}/rules/完成前验证\.md" "$ROOT/shared/assistant.md" >/dev/null 2>&1 \
  || fail "missing assistant completion rule reference"

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

echo "[PASS] runtime contract inline"
