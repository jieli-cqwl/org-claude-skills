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
test -f "$ROOT/shared/rules/completion-claims.md" || fail "missing completion verification rule"
test -f "$ROOT/shared/rules/code-changes.md" || fail "missing code changes rule"
test ! -f "$ROOT/shared/rules/交付验收底线.md" || fail "legacy delivery acceptance rule should be retired"
test ! -f "$ROOT/shared/rules/完成前验证.md" || fail "legacy Chinese completion rule filename should be retired"
test ! -f "$ROOT/shared/rules/代码规范.md" || fail "legacy Chinese code rule filename should be retired"
test ! -f "$ROOT/shared/reference/completion-claims.md" || fail "completion verification should be a rule, not a reference"
test ! -f "$ROOT/shared/reference/性能效率.md" || fail "legacy Chinese performance reference filename should be retired"
test ! -f "$ROOT/shared/reference/硬编码治理规范.md" || fail "legacy Chinese constants reference filename should be retired"

python3 - "$ROOT/shared/rules/completion-claims.md" <<'PY' || fail "completion verification rule shape contract violated"
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

semantic_checks = [
    (
        "current-direct-evidence",
        text.find("current") >= 0 and text.find("direct") >= 0 and text.find("evidence") >= 0,
    ),
    (
        "acceptance-scope-derivation",
        text.find("derive the acceptance scope") >= 0
        and text.find("success criteria") >= 0
        and text.find("impact analysis") >= 0
        and text.find("triggered validation dimensions") >= 0
        and text.find("risk surfaces") >= 0
        and text.find("real dependencies") >= 0
        and text.find("affected user paths") >= 0,
    ),
    (
        "user-verification-not-scope-shrink",
        text.find("User-specified verification") >= 0
        and text.find("adds evidence requirements") >= 0
        and text.find("does not shrink") >= 0
        and text.find("explicitly limits the acceptance scope") >= 0,
    ),
    (
        "consumer-class-real-entry",
        text.find("consumer class") >= 0 and text.find("real entry") >= 0,
    ),
    (
        "accepted-residual-risk-boundary",
        text.find("unaccepted risk") >= 0
        and text.find("Accepted residual risks") >= 0
        and text.find("reported separately") >= 0,
    ),
    (
        "same-level-scope",
        text.find("user paths") >= 0 and text.find("same level") >= 0,
    ),
    (
        "mock-boundary",
        text.find("Mock/") >= 0 and text.find("Stub/") >= 0 and text.find("Fake") >= 0,
    ),
    (
        "skip-xfail-delete-checks",
        text.find("skip" + "ping") >= 0
        and text.find("xfail" + "-ing") >= 0
        and text.find("delet" + "ing checks") >= 0,
    ),
    (
        "weaker-evidence",
        text.find("weaker " + "evidence") >= 0,
    ),
    (
        "blocked-evidence-states",
        text.find("un" + "run") >= 0
        and text.find("failed") >= 0
        and text.find("blocked") >= 0
        and text.find("missing " + "evidence") >= 0,
    ),
]
missing_semantics = [label for label, present in semantic_checks if not present]
if missing_semantics:
    raise SystemExit(
        "rule missing completion-claim failure semantics: "
        + ", ".join(missing_semantics)
    )

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

python3 - "$ROOT/shared/rules/code-changes.md" <<'PY' || fail "code changes rule shape contract violated"
import re
import sys
from pathlib import Path

rule = Path(sys.argv[1])
text = rule.read_text(encoding="utf-8")
lines = text.splitlines()
if not lines or lines[0] != "# Code Changes":
    raise SystemExit("rule must use the Code Changes title")
if any(line.startswith("## ") for line in lines):
    raise SystemExit("rule must stay flat; detailed guidance belongs in reference files")
if "TODO" in text or "TBD" in text:
    raise SystemExit("rule must not contain placeholders")
if any(term in text for term in ("MUST（必须遵守）", "复用治理规范", "复杂度约束", "硬编码规范")):
    raise SystemExit("rule must not regress to the old handbook structure")

first_bullet = next((index for index, line in enumerate(lines) if line.startswith("- ")), None)
if first_bullet is None:
    raise SystemExit("rule must contain bullet constraints")
lead = [line for line in lines[1:first_bullet] if line.strip()]
if len(lead) != 1:
    raise SystemExit("rule must have exactly one lead sentence before constraints")

bullets = [line for line in lines if line.startswith("- ")]
if not 18 <= len(bullets) <= 26:
    raise SystemExit(f"rule should stay concise: got {len(bullets)} bullets")
if sum(1 for line in bullets if line.startswith("- Test: ")) != 1:
    raise SystemExit("rule must include exactly one explicit self-test bullet")
long_lines = [str(index) for index, line in enumerate(lines, start=1) if len(line) > 220]
if long_lines:
    raise SystemExit(f"rule lines are too long: {', '.join(long_lines)}")

refs = set(re.findall(r"\{\{RUNTIME_HOME\}\}/reference/[^`]+\.md", text))
expected_refs = {
    "{{RUNTIME_HOME}}/reference/code-structure-reuse.md",
    "{{RUNTIME_HOME}}/reference/code-comments.md",
    "{{RUNTIME_HOME}}/reference/error-handling.md",
    "{{RUNTIME_HOME}}/reference/constants-and-configuration.md",
    "{{RUNTIME_HOME}}/reference/performance-and-efficiency.md",
}
if refs != expected_refs:
    raise SystemExit(f"unexpected reference set: {sorted(refs)}")

allowed_lines = {"", "# Code Changes", *lead, *bullets}
unexpected = [
    f"{index}: {line}"
    for index, line in enumerate(lines, start=1)
    if line not in allowed_lines
]
if unexpected:
    raise SystemExit("rule must remain one lead sentence plus bullets:\n" + "\n".join(unexpected))
PY

python3 - "$ROOT" <<'PY' || fail "code changes baseline scenario coverage violated"
import sys
from pathlib import Path

root = Path(sys.argv[1])
required_terms = {
    "shared/rules/code-changes.md": [
        "current change",
        "blocking current correctness/build/verification",
    ],
    "shared/reference/code-structure-reuse.md": [
        "senior engineer perspective",
        "maintainability",
        "evolvability",
    ],
    "shared/reference/code-comments.md": [
        "adding or changing database schema",
        "columns",
        "constraints",
    ],
    "shared/reference/performance-and-efficiency.md": [
        "CPU-intensive",
        "user paths",
        "high-frequency queries",
    ],
}

missing = []
for relative_path, terms in required_terms.items():
    text = (root / relative_path).read_text(encoding="utf-8")
    for term in terms:
        if term not in text:
            missing.append(f"{relative_path}: {term}")

if missing:
    raise SystemExit("missing baseline scenario terms:\n" + "\n".join(missing))
PY

if rg -n 'RUNTIME_(?:ASSISTANT|RULE_[A-Z0-9_]+)_CONTRACT' "$ROOT/shared/assistant.md" "$ROOT/shared/rules" "$ROOT/install.sh" >/dev/null 2>&1; then
  fail "assistant/rules runtime contracts should be inline, not rendered through RUNTIME_*_CONTRACT placeholders"
fi

for path in \
  "reference/协作判断.md" \
  "reference/code-structure-reuse.md" \
  "reference/code-comments.md" \
  "reference/error-handling.md" \
  "reference/测试规范.md" \
  "reference/设计原则.md" \
  "reference/影响范围分析.md" \
  "reference/系统调试.md" \
  "reference/全栈开发.md" \
  "reference/performance-and-efficiency.md" \
  "reference/constants-and-configuration.md"; do
  rg -n "\{\{RUNTIME_HOME\}\}/$path" "$ROOT/shared/assistant.md" >/dev/null 2>&1 \
    || fail "missing assistant runtime reference: $path"
done

rg -n "\{\{RUNTIME_HOME\}\}/rules/completion-claims\.md" "$ROOT/shared/assistant.md" >/dev/null 2>&1 \
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

collaboration_boundary_marker="contract:collaboration-boundary:shared-before-parallel"
for path in \
  "$ROOT/shared/rules/执行纪律.md" \
  "$ROOT/shared/reference/影响范围分析.md"; do
  rg -F "$collaboration_boundary_marker" "$path" >/dev/null 2>&1 \
    || fail "missing collaboration boundary contract marker: $path"
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

required_topics = {"technical_evidence": ("impact_files",)}
missing_topics = [
    name for name, terms in required_topics.items()
    if not all(term in text for term in terms)
]
if missing_topics:
    raise SystemExit(f"missing topics: {', '.join(missing_topics)}")
PY

echo "[PASS] runtime contract inline"
