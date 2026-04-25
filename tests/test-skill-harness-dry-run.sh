#!/usr/bin/env bash
# File role: prove skill-harness dry-run calibration gates against delivery-owner.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/shared/skills/skill-harness/scripts/check_skill_harness_contract.py"
MANIFEST="$ROOT/shared/skills/skill-harness/scripts/manifest.json"
CASES="$ROOT/tests/fixtures/skill-harness/dry-run"
REPORT="$CASES/delivery-owner-dry-run-report.json"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/skill-harness-dry-run.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

expect_fail() {
  local label="$1"
  local expected="$2"
  shift 2
  local stdout_file
  local stderr_file
  stdout_file="$(mktemp "$TMP_DIR/stdout.XXXXXX")"
  stderr_file="$(mktemp "$TMP_DIR/stderr.XXXXXX")"
  set +e
  "$@" >"$stdout_file" 2>"$stderr_file"
  local rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    cat "$stdout_file"
    cat "$stderr_file" >&2
    fail "$label unexpectedly passed"
  fi
  if ! grep -Fq "$expected" "$stdout_file" "$stderr_file"; then
    cat "$stdout_file"
    cat "$stderr_file" >&2
    fail "$label did not report $expected"
  fi
}

[ -f "$REPORT" ] || fail "missing delivery-owner dry-run report"
python3 - "$MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
roots = []
for script in manifest.get("scripts", []):
    if script.get("id") == "check-contract":
        roots = script.get("allowed_input_roots", [])
        break
required = {
    "tests/fixtures/skill-harness/dry-run",
}
missing = sorted(required - set(roots))
if missing:
    raise SystemExit(f"DRY_RUN_ROOT_MISSING: {missing}")
print("[PASS] dry-run manifest roots")
PY
python3 "$CHECKER" "$CASES/delivery-owner-continue.json"
python3 "$CHECKER" "$REPORT"
expect_fail "abstract stop" "DRY_RUN_STOP" \
  python3 "$CHECKER" "$CASES/delivery-owner-stop-abstract.json"
expect_fail "duplicate stop" "DRY_RUN_STOP" \
  python3 "$CHECKER" "$CASES/delivery-owner-stop-duplicate.json"
expect_fail "invalid proof stop" "invalid-proof-or-gate-ref" \
  python3 "$CHECKER" "$CASES/delivery-owner-stop-invalid-proof.json"
expect_fail "nonscript proof stop" "invalid-proof-or-gate-ref" \
  python3 "$CHECKER" "$CASES/delivery-owner-stop-nonscript-proof.json"
printf '[PASS] skill-harness dry-run\n'
