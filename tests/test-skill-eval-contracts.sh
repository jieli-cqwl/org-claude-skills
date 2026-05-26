#!/usr/bin/env bash
set -euo pipefail

# File responsibility: validate first-party skill eval metadata without prose-output contracts.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$ROOT/tools/community/validate_skill_evals.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$VALIDATOR" || fail "missing skill eval validator: $VALIDATOR"

python3 "$VALIDATOR" --repo-root "$ROOT"

python3 - "$ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
violations = []
for path in sorted((root / "shared" / "skills").glob("*/evals/evals.json")):
    text = path.read_text(encoding="utf-8")
    if '"expected_output"' in text:
        violations.append(str(path.relative_to(root)))
if violations:
    raise SystemExit("first-party skill evals must not define expected_output:\n" + "\n".join(violations))
PY

printf '[PASS] skill eval contracts\n'
