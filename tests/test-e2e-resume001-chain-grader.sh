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

SCRIPT="$ROOT/tools/eval/scripts/grade_e2e_resume001_chain.py"
CHAIN_DIR="$ROOT/tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/e2e-resume-001"

[ -f "$SCRIPT" ] || fail "missing E2E-RESUME-001 chain grader"
[ -d "$CHAIN_DIR" ] || fail "missing E2E-RESUME-001 dry-run directory"

TMP_OUTPUT="$(mktemp)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -f "$TMP_OUTPUT"; rm -rf "$TMP_ROOT"' EXIT

python3 "$SCRIPT" --repo-root "$ROOT" >"$TMP_OUTPUT" || fail "E2E-RESUME-001 chain grader should pass"

python3 - "$TMP_OUTPUT" <<'PY' || fail "E2E-RESUME-001 grader output mismatch"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit(payload)
if payload.get("failed_checks"):
    raise SystemExit(payload["failed_checks"])
expected_roles = [
    "product-director",
    "product-manager",
    "design",
    "test-design",
    "tech-lead",
    "delivery-owner",
]
if payload.get("roles") != expected_roles:
    raise SystemExit(f"role order mismatch: {payload.get('roles')}")
PY

BROKEN_DIR="$TMP_ROOT/e2e-resume-001"
cp -R "$CHAIN_DIR" "$BROKEN_DIR"
python3 - "$BROKEN_DIR/chain-output.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("resume_condition", "missing_resume_condition", 1), encoding="utf-8")
PY

if python3 "$SCRIPT" \
  --input "$BROKEN_DIR/input.md" \
  --output "$BROKEN_DIR/chain-output.md" \
  --evaluator "$BROKEN_DIR/evaluator-output.md" \
  --decision "$BROKEN_DIR/decision.md" \
  >"$TMP_ROOT/broken-output.json"; then
  fail "E2E-RESUME-001 grader should fail when resume_condition is missing"
fi
rg -q "resume_condition" "$TMP_ROOT/broken-output.json" \
  || fail "resume_condition failure should be explicit"

printf '[PASS] E2E-RESUME-001 chain grader\n'
