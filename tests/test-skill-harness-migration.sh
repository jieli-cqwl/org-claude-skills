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

[ -d "$ROOT/shared/skills/skill-harness" ] || fail "missing active skill-harness source"
[ ! -d "$ROOT/shared/skills/skill-auditor" ] || fail "skill-auditor must not remain active runtime source"
[ -d "$ROOT/docs/archive/skill-auditor/runtime-source-2026-04-19" ] || fail "missing skill-auditor archive"
grep -Fq 'ARCHIVE_ONLY' "$ROOT/docs/archive/skill-auditor/runtime-source-2026-04-19/README.md" || fail "archive must classify legacy source"

python3 - "$ROOT" <<'PY' || fail "legacy skill name leaked into active source"
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
scan_roots = [
    root / "shared" / "skills",
    root / "shared" / "reference",
    root / "install.sh",
    root / "tests",
]
legacy = re.compile(r"skill-auditor|skill-optimizer")
allowed_markers = (
    "! -e",
    "! -d",
    "not install",
    "must not remain",
    "should not",
    "不应存在",
    "archived after",
)
violations = []

for base in scan_roots:
    paths = [base] if base.is_file() else [p for p in base.rglob("*") if p.is_file()]
    for path in paths:
        rel = path.relative_to(root).as_posix()
        if rel.startswith("tests/fixtures/") or rel == "tests/test-skill-harness-migration.sh":
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for lineno, line in enumerate(text.splitlines(), start=1):
            if not legacy.search(line):
                continue
            if any(marker in line for marker in allowed_markers):
                continue
            violations.append(f"{rel}:{lineno}:{line.strip()}")

if violations:
    print("\n".join(violations), file=sys.stderr)
    raise SystemExit(1)
PY

printf '[PASS] skill-harness migration\n'
