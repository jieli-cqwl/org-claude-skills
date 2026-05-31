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

python3 - "$ROOT/shared/rules/完成前验证.md" <<'PY' || fail "completion verification rule shape contract violated"
import sys
from pathlib import Path

rule = Path(sys.argv[1])
text = rule.read_text(encoding="utf-8")
lines = text.splitlines()
if not lines or lines[0] != "# Completion Claims":
    raise SystemExit("rule must use the Completion Claims title")
if any(line.startswith("## ") for line in lines):
    raise SystemExit("rule must stay flat; prose sections make it too easy to skim past constraints")
if "TODO" in text or "TBD" in text:
    raise SystemExit("rule must not contain placeholders")

nonempty = [line for line in lines if line.strip()]
first_bullet = next((index for index, line in enumerate(lines) if line.startswith("- ")), None)
if first_bullet is None:
    raise SystemExit("rule must contain bullet constraints")
lead = [line for line in lines[1:first_bullet] if line.strip()]
if len(lead) != 1:
    raise SystemExit("rule must have exactly one lead sentence before constraints")

bullets = [line for line in lines if line.startswith("- ")]
if not 14 <= len(bullets) <= 22:
    raise SystemExit(f"rule should stay concise: got {len(bullets)} bullets")
if sum(1 for line in bullets if line.startswith("- Test: ")) != 1:
    raise SystemExit("rule must include exactly one explicit self-test bullet")
long_lines = [str(index) for index, line in enumerate(lines, start=1) if len(line) > 220]
if long_lines:
    raise SystemExit(f"rule lines are too long: {', '.join(long_lines)}")

allowed_lines = {"", "# Completion Claims", *lead, *bullets}
unexpected = [
    f"{index}: {line}"
    for index, line in enumerate(lines, start=1)
    if line not in allowed_lines
]
if unexpected:
    raise SystemExit("rule must remain one lead sentence plus bullets:\n" + "\n".join(unexpected))

if len(nonempty) != 1 + len(lead) + len(bullets):
    raise SystemExit("rule contains unexpected non-empty content")
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

python3 - "$ROOT/shared/reference/影响范围分析.md" <<'PY' || fail "impact analysis reference contract violated"
import re
import sys
from pathlib import Path

reference = Path(sys.argv[1])
text = reference.read_text(encoding="utf-8")
headings = set(re.findall(r"^## (.+)$", text, flags=re.MULTILINE))
required_headings = {
    "三步识别法",
    "必查维度",
    "功能影响项",
    "并行安全",
    "影响记录",
    "分析结果",
}
missing_headings = sorted(required_headings - headings)
if missing_headings:
    raise SystemExit(f"missing headings: {', '.join(missing_headings)}")

required_topics = {
    "impact_scope": ("功能影响", "技术影响", "回归验证项", "覆盖盲区", "待裁决风险"),
    "functional_item": ("功能点", "影响原因", "技术触点", "验证与风险"),
    "technical_evidence": ("impact_files", "技术影响证据", "不替代功能影响结论"),
    "negative_evidence": ("无额外影响", "功能影响", "技术触点", "业务规则", "验证范围", "覆盖盲区"),
    "closure": ("功能影响项", "完成前验证", "未关闭项"),
}
missing_topics = [
    name for name, terms in required_topics.items()
    if not all(term in text for term in terms)
]
if missing_topics:
    raise SystemExit(f"missing topics: {', '.join(missing_topics)}")
PY

echo "[PASS] runtime contract inline"
