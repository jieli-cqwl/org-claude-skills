#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$ROOT/shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py"
VALID="$ROOT/tests/fixtures/skill-quality-audit/reports/valid-report.json"
MISSING_REPAIR="$ROOT/tests/fixtures/skill-quality-audit/reports/p1-missing-repair-target.json"
BAD_VERDICT="$ROOT/tests/fixtures/skill-quality-audit/reports/instruction-low-score-invalid-verdict.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

[ -f "$VALIDATOR" ] || fail "missing validate_skill_audit_report.py"
[ -f "$VALID" ] || fail "missing valid report fixture"

python3 "$VALIDATOR" "$VALID"

if python3 "$VALIDATOR" "$MISSING_REPAIR" >"$TMP_DIR/missing-repair.out" 2>&1; then
  fail "P1 finding without repair_target must fail"
fi
grep -Fq "repair_target" "$TMP_DIR/missing-repair.out" \
  || fail "missing repair_target failure should be explicit"

if python3 "$VALIDATOR" "$BAD_VERDICT" >"$TMP_DIR/bad-verdict.out" 2>&1; then
  fail "Instruction Contract score below 5 must force unfit"
fi
grep -Fq "Instruction Contract" "$TMP_DIR/bad-verdict.out" \
  || fail "bad verdict failure should mention Instruction Contract"

python3 - "$VALID" "$TMP_DIR/missing-dimension.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["dimension_scores"] = [
    item
    for item in data["dimension_scores"]
    if item["dimension"] != "Noise And Maintainability"
]
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/missing-dimension.json" >"$TMP_DIR/missing-dimension.out" 2>&1; then
  fail "report missing one required dimension must fail"
fi
grep -Fq "Noise And Maintainability" "$TMP_DIR/missing-dimension.out" \
  || fail "missing dimension failure should name the missing dimension"

python3 - "$VALID" "$TMP_DIR/missing-scope.json" <<'PY'
import json
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])
data = json.loads(src.read_text(encoding="utf-8"))
data["scope_evidence"] = [
    item
    for item in data["scope_evidence"]
    if item["surface"] != "downstream consumers"
]
dst.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$VALIDATOR" "$TMP_DIR/missing-scope.json" >"$TMP_DIR/missing-scope.out" 2>&1; then
  fail "report missing one required scope surface must fail"
fi
grep -Fq "downstream consumers" "$TMP_DIR/missing-scope.out" \
  || fail "missing scope failure should name the missing surface"

printf '[PASS] skill-quality-audit report contract\n'
