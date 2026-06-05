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

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/skill-eval-contracts.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/shared/skills/example/evals"
cat >"$tmp_dir/shared/skills/example/evals/evals.json" <<'JSON'
{
  "skill_name": "example",
  "sample_matrix": [
    {
      "id": "thin"
    }
  ],
  "evals": [
    {
      "id": "case-1",
      "prompt": "Do the thing.",
      "files": []
    }
  ]
}
JSON
if python3 "$VALIDATOR" --repo-root "$tmp_dir" >"$tmp_dir/invalid-sample-matrix.out" 2>&1; then
  fail "sample_matrix entries missing required fields must fail"
fi
grep -Fq "sample_matrix 'thin' missing fields" "$tmp_dir/invalid-sample-matrix.out" \
  || fail "sample_matrix failure should identify missing fields"

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
