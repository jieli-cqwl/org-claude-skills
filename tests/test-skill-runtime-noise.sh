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

python3 - "$ROOT" <<'PY' || fail "skill runtime noise contract violated"
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
violations = []
global_docs = {
    "rules/交付验收底线.md",
    "rules/代码规范.md",
    "rules/执行纪律.md",
    "rules/文档管理.md",
    "reference/测试规范.md",
    "reference/代码复用.md",
    "reference/完成前验证.md",
    "reference/设计原则.md",
    "reference/影响范围分析.md",
    "reference/系统调试.md",
    "reference/全栈开发.md",
    "reference/技术选型.md",
    "reference/性能效率.md",
    "reference/硬编码治理规范.md",
    "reference/Skill质量标准.md",
}
path_pattern = re.compile(
    r'(?:\{\{RUNTIME_HOME\}\}/|\.claude/|\.codex/)'
    r'((?:rules|reference)/[^"\'` )(]+\.md)'
)
runtime_noise_patterns = [
    ("legacy mapping section", re.compile(r'\bLegacy Mapping\b')),
    ("legacy dimension migration note", re.compile(r'旧\s*D[0-9](?:-D[0-9])?.*迁移对照')),
    ("removable runtime note", re.compile(r'本(?:表|节|段|section).*可删除')),
    ("v2 quality-standard wording", re.compile(r'\b(?:v2 quality|quality standard v2|invalid v2 dimension)\b', re.I)),
]


def iter_paragraphs(text: str):
    lines = []
    in_frontmatter = False
    frontmatter_seen = False
    in_code_block = False

    def flush():
        nonlocal lines
        if lines:
            yield "\n".join(lines)
            lines = []

    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        stripped = line.strip()

        if stripped == "---" and not frontmatter_seen and not lines:
            in_frontmatter = True
            frontmatter_seen = True
            continue
        if stripped == "---" and in_frontmatter:
            in_frontmatter = False
            continue
        if in_frontmatter:
            continue

        if stripped.startswith("```"):
            in_code_block = not in_code_block
            continue
        if in_code_block:
            continue

        if not stripped:
            yield from flush()
            continue

        lines.append(line)

    yield from flush()


def referenced_global_docs(paragraph: str) -> set[str]:
    return {
        match.group(1)
        for match in path_pattern.finditer(paragraph)
        if match.group(1) in global_docs
    }


def assert_self_checks() -> None:
    valid_samples = [
        "当进入诊断阶段时：\n→ 读取 `{{RUNTIME_HOME}}/reference/系统调试.md` 获取四阶段根因分析流程",
        "- [ ] MUST 条款符合 `{{RUNTIME_HOME}}/rules/代码规范.md`",
    ]
    invalid_samples = [
        "自动加载（不展开）：`{{RUNTIME_HOME}}/rules/交付验收底线.md` + `{{RUNTIME_HOME}}/rules/代码规范.md` + `{{RUNTIME_HOME}}/reference/测试规范.md`",
        "顶层规范：默认遵循 `{{RUNTIME_HOME}}/rules/交付验收底线.md`\n同时参考 `{{RUNTIME_HOME}}/rules/代码规范.md`\n必要时查看 `{{RUNTIME_HOME}}/reference/测试规范.md`",
    ]

    for sample in valid_samples:
        if len(referenced_global_docs(sample)) >= 2:
            raise SystemExit(f"self-check falsely flagged valid sample: {sample}")

    for sample in invalid_samples:
        if len(referenced_global_docs(sample)) < 2:
            raise SystemExit(f"self-check failed to catch invalid sample: {sample}")


assert_self_checks()

for skill_file in (root / "shared" / "skills").glob("*/SKILL.md"):
    text = skill_file.read_text(encoding="utf-8")
    paragraphs = list(iter_paragraphs(text))
    for paragraph in paragraphs:
        docs = sorted(referenced_global_docs(paragraph))
        if len(docs) >= 2:
            first_line = paragraph.splitlines()[0].strip()
            violations.append(
                f"{skill_file}: duplicate top-level global runtime docs {docs}: {first_line}"
            )

runtime_doc_roots = [
    root / "shared" / "skills",
    root / "shared" / "reference",
    root / "shared" / "rules",
    root / "shared" / "protocols",
]

for doc_root in runtime_doc_roots:
    for path in doc_root.rglob("*.md"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        for lineno, line in enumerate(text.splitlines(), start=1):
            for label, pattern in runtime_noise_patterns:
                if pattern.search(line):
                    violations.append(f"{path}:{lineno}: {label}: {line.strip()}")

if violations:
    print("\n".join(violations), file=sys.stderr)
    raise SystemExit(1)
PY

echo "[PASS] skill runtime noise"
