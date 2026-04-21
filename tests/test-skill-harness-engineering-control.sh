#!/usr/bin/env bash
# File role: prove skill-harness scripts declare controlled engineering boundaries.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/shared/skills/skill-harness/scripts/manifest.json"
FIELD="$ROOT/shared/skills/skill-harness/schemas/field-consumers.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$MANIFEST" ] || fail "missing manifest"
[ -f "$FIELD" ] || fail "missing field-consumers"

python3 - "$MANIFEST" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
required = {
    "id",
    "path",
    "owner",
    "allowed_args",
    "timeout_seconds",
    "output_root",
    "allowed_input_roots",
    "failure_state",
}
required_roots = {
    "tests/fixtures/skill-harness/cases",
    "tests/fixtures/skill-harness/field-consumers",
    "tests/fixtures/skill-harness/legacy-assets",
    "shared/skills/skill-harness/schemas",
}

for script in data.get("scripts", []):
    missing = sorted(required - script.keys())
    if missing:
        raise SystemExit(f"manifest script missing keys: {missing}")
    if not script["owner"] or not script["failure_state"]:
        raise SystemExit(f"incomplete manifest script: {script.get('id')}")
    if not isinstance(script["timeout_seconds"], int) or script["timeout_seconds"] <= 0:
        raise SystemExit(f"invalid timeout for manifest script: {script.get('id')}")
    roots = set(script.get("allowed_input_roots", []))
    missing_roots = sorted(required_roots - roots)
    if missing_roots:
        raise SystemExit(f"manifest script missing allowed input roots: {missing_roots}")

print("[PASS] manifest engineering control")
PY

bash "$ROOT/tests/test-skill-harness-field-consumers.sh"
bash "$ROOT/tests/test-skill-harness-directory-capability.sh"
printf '[PASS] skill-harness engineering control\n'
