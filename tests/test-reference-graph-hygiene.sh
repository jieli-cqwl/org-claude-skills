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

python3 - "$ROOT" <<'PY' || fail "reference graph hygiene contract violated"
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
pattern = re.compile(
    r'(?<![A-Za-z0-9_])'
    r'(?:\{\{RUNTIME_HOME\}\}/|\.claude/|\.codex/|\./|\.\./|shared/)?'
    r'rules/[^"\'` )(]+\.md'
)


def find_rule_backlinks(text: str) -> list[str]:
    return [match.group(0) for match in pattern.finditer(text)]


def assert_self_checks() -> None:
    invalid_samples = [
        "{{RUNTIME_HOME}}/rules/代码规范.md",
        ".claude/rules/交付验收底线.md",
        ".codex/rules/执行纪律.md",
        "./rules/文档管理.md",
        "../rules/代码规范.md",
        "shared/rules/代码规范.md",
        "rules/代码规范.md",
    ]
    valid_samples = [
        "规则源以代码规范中的 MUST 条款为准。",
        "shared/rules 与 shared/reference 的目录职责不同。",
        "这里只描述边界，不再给出规则文件路径。",
    ]

    for sample in invalid_samples:
        if not find_rule_backlinks(sample):
            raise SystemExit(f"self-check failed to catch invalid sample: {sample}")

    for sample in valid_samples:
        if find_rule_backlinks(sample):
            raise SystemExit(f"self-check falsely flagged valid sample: {sample}")


assert_self_checks()

violations = []
for path in sorted((root / "shared" / "reference").rglob("*.md")):
    text = path.read_text(encoding="utf-8", errors="ignore")
    for lineno, line in enumerate(text.splitlines(), start=1):
        matches = find_rule_backlinks(line)
        if matches:
            violations.append(f"{path}:{lineno}:{matches[0]}")

if violations:
    print("\n".join(violations), file=sys.stderr)
    raise SystemExit(1)
PY

echo "[PASS] reference graph hygiene"
