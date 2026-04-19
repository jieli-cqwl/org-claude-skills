#!/usr/bin/env bash
# 文件职责：验证 skill-optimizer 从审计到 verification-result 的端到端证据链。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="$ROOT/shared/skills/skill-optimizer"
E2E_TARGET="$ROOT/tests/fixtures/skill-optimizer/e2e/reference-broken"
WORK_DIR="$(mktemp -d)"
COVERAGE="$ROOT/docs/skill-optimizer/2026-04-16-course-derived-methodology/implementation-coverage.md"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

expect_fail() {
  local label="$1"
  shift
  set +e
  "$@" >"$WORK_DIR/expected-fail.out" 2>"$WORK_DIR/expected-fail.err"
  local rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    cat "$WORK_DIR/expected-fail.out"
    cat "$WORK_DIR/expected-fail.err" >&2
    fail "$label unexpectedly passed"
  fi
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content in $file: $needle"
}

[ -d "$E2E_TARGET" ] || fail "missing e2e target fixture"
[ -f "$SKILL_DIR/schemas/verification-result.schema.json" ] || fail "missing verification-result schema"
[ -x "$SKILL_DIR/scripts/build_verification_result.py" ] || fail "missing executable build_verification_result.py"
[ -f "$COVERAGE" ] || fail "missing implementation coverage"

python3 "$SKILL_DIR/scripts/audit_skill.py" "$E2E_TARGET" --out-dir "$WORK_DIR/audit"
python3 "$SKILL_DIR/scripts/validate_schema.py" "$SKILL_DIR/schemas/skill-audit.schema.json" "$WORK_DIR/audit/skill-audit.json"
python3 "$SKILL_DIR/scripts/validate_semantics.py" "$WORK_DIR/audit/skill-audit.json"
python3 "$SKILL_DIR/scripts/validate_consumers.py" "$SKILL_DIR/schemas/field-consumers.json" "$WORK_DIR/audit/skill-audit.json"

python3 "$SKILL_DIR/scripts/generate_optimization_plan.py" \
  "$WORK_DIR/audit/skill-audit.json" \
  --accept finding-reference-contract \
  --out "$WORK_DIR/optimization-plan.json"
python3 "$SKILL_DIR/scripts/validate_schema.py" "$SKILL_DIR/schemas/optimization-plan.schema.json" "$WORK_DIR/optimization-plan.json"
python3 "$SKILL_DIR/scripts/validate_consumers.py" "$SKILL_DIR/schemas/field-consumers.json" "$WORK_DIR/optimization-plan.json"
python3 "$SKILL_DIR/scripts/validate_plan_consumption.py" "$WORK_DIR/optimization-plan.json"

python3 "$SKILL_DIR/scripts/render_report.py" "$WORK_DIR/audit/skill-audit.json" --out-dir "$WORK_DIR/report"
python3 "$SKILL_DIR/scripts/validate_rendered_views.py" "$WORK_DIR/audit/skill-audit.json"

python3 "$SKILL_DIR/scripts/run_evals.py" "$SKILL_DIR/evals/evals.json" "$SKILL_DIR/scripts/manifest.json" --out "$WORK_DIR/eval-results.json"
python3 "$SKILL_DIR/scripts/validate_eval_results.py" "$WORK_DIR/eval-results.json" "$SKILL_DIR/scripts/manifest.json"

python3 "$SKILL_DIR/scripts/build_verification_result.py" \
  --audit "$WORK_DIR/audit/skill-audit.json" \
  --plan "$WORK_DIR/optimization-plan.json" \
  --eval-results "$WORK_DIR/eval-results.json" \
  --coverage "$COVERAGE" \
  --fresh-command "bash tests/test-skill-optimizer-contract.sh=PASS" \
  --fresh-command "bash tests/test-skill-optimizer-runtime-artifacts.sh=PASS" \
  --fresh-command "bash tests/test-skill-optimizer-evals.sh=PASS" \
  --out "$WORK_DIR/verification-result.json"

python3 "$SKILL_DIR/scripts/validate_schema.py" "$SKILL_DIR/schemas/verification-result.schema.json" "$WORK_DIR/verification-result.json"
python3 "$SKILL_DIR/scripts/validate_consumers.py" "$SKILL_DIR/schemas/field-consumers.json" "$WORK_DIR/verification-result.json"

python3 - "$WORK_DIR/verification-result.json" "$WORK_DIR/verification-result-invalid-nested.json" <<'PY'
import json
import sys

src, dst = sys.argv[1], sys.argv[2]
artifact = json.load(open(src, encoding="utf-8"))
artifact["decision"] = {}
artifact["fresh_commands"] = []
json.dump(artifact, open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
expect_fail "invalid verification-result nested contract" \
  python3 "$SKILL_DIR/scripts/validate_schema.py" "$SKILL_DIR/schemas/verification-result.schema.json" "$WORK_DIR/verification-result-invalid-nested.json"

python3 - "$WORK_DIR/audit/skill-audit.json" "$WORK_DIR/audit/invalid-skill-audit.json" <<'PY'
import json
import sys

src, dst = sys.argv[1], sys.argv[2]
artifact = json.load(open(src, encoding="utf-8"))
artifact["artifact_type"] = "invalid-audit"
artifact["status"] = "blocked"
artifact["findings"] = []
json.dump(artifact, open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
expect_fail "invalid upstream audit artifact" \
  python3 "$SKILL_DIR/scripts/build_verification_result.py" \
    --audit "$WORK_DIR/audit/invalid-skill-audit.json" \
    --plan "$WORK_DIR/optimization-plan.json" \
    --eval-results "$WORK_DIR/eval-results.json" \
    --coverage "$COVERAGE" \
    --fresh-command "bash tests/test-skill-optimizer-contract.sh=PASS" \
    --out "$WORK_DIR/invalid-audit-verification-result.json"

python3 - "$WORK_DIR/audit/skill-audit.json" "$WORK_DIR/audit/semantic-invalid-skill-audit.json" <<'PY'
import json
import sys

src, dst = sys.argv[1], sys.argv[2]
artifact = json.load(open(src, encoding="utf-8"))
artifact["design_anchors"] = ["UNKNOWN-ANCHOR"]
json.dump(artifact, open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
expect_fail "semantic invalid audit artifact" \
  python3 "$SKILL_DIR/scripts/build_verification_result.py" \
    --audit "$WORK_DIR/audit/semantic-invalid-skill-audit.json" \
    --plan "$WORK_DIR/optimization-plan.json" \
    --eval-results "$WORK_DIR/eval-results.json" \
    --coverage "$COVERAGE" \
    --fresh-command "bash tests/test-skill-optimizer-contract.sh=PASS" \
    --fresh-command "bash tests/test-skill-optimizer-runtime-artifacts.sh=PASS" \
    --fresh-command "bash tests/test-skill-optimizer-evals.sh=PASS" \
    --out "$WORK_DIR/semantic-invalid-verification-result.json"

python3 - "$WORK_DIR/optimization-plan.json" "$WORK_DIR/invalid-optimization-plan.json" <<'PY'
import json
import sys

src, dst = sys.argv[1], sys.argv[2]
artifact = json.load(open(src, encoding="utf-8"))
artifact["artifact_type"] = "invalid-plan"
artifact["status"] = "blocked"
artifact["accepted_findings"] = []
json.dump(artifact, open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
expect_fail "invalid upstream optimization plan" \
  python3 "$SKILL_DIR/scripts/build_verification_result.py" \
    --audit "$WORK_DIR/audit/skill-audit.json" \
    --plan "$WORK_DIR/invalid-optimization-plan.json" \
    --eval-results "$WORK_DIR/eval-results.json" \
    --coverage "$COVERAGE" \
    --fresh-command "bash tests/test-skill-optimizer-contract.sh=PASS" \
    --out "$WORK_DIR/invalid-plan-verification-result.json"

python3 - "$WORK_DIR/optimization-plan.json" "$WORK_DIR/plan-missing-boundary.json" <<'PY'
import json
import sys

src, dst = sys.argv[1], sys.argv[2]
artifact = json.load(open(src, encoding="utf-8"))
artifact["file_boundaries"] = []
json.dump(artifact, open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
expect_fail "plan accepted finding missing file boundary" \
  python3 "$SKILL_DIR/scripts/build_verification_result.py" \
    --audit "$WORK_DIR/audit/skill-audit.json" \
    --plan "$WORK_DIR/plan-missing-boundary.json" \
    --eval-results "$WORK_DIR/eval-results.json" \
    --coverage "$COVERAGE" \
    --fresh-command "bash tests/test-skill-optimizer-contract.sh=PASS" \
    --fresh-command "bash tests/test-skill-optimizer-runtime-artifacts.sh=PASS" \
    --fresh-command "bash tests/test-skill-optimizer-evals.sh=PASS" \
    --out "$WORK_DIR/missing-boundary-verification-result.json"

python3 - "$WORK_DIR/optimization-plan.json" "$WORK_DIR/plan-command-not-fresh.json" <<'PY'
import json
import sys

src, dst = sys.argv[1], sys.argv[2]
artifact = json.load(open(src, encoding="utf-8"))
artifact["verification_contracts"][0]["command"] = "bash tests/test-install-smoke.sh"
json.dump(artifact, open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
expect_fail "plan contract command missing fresh evidence" \
  python3 "$SKILL_DIR/scripts/build_verification_result.py" \
    --audit "$WORK_DIR/audit/skill-audit.json" \
    --plan "$WORK_DIR/plan-command-not-fresh.json" \
    --eval-results "$WORK_DIR/eval-results.json" \
    --coverage "$COVERAGE" \
    --fresh-command "bash tests/test-skill-optimizer-contract.sh=PASS" \
    --fresh-command "bash tests/test-skill-optimizer-runtime-artifacts.sh=PASS" \
    --fresh-command "bash tests/test-skill-optimizer-evals.sh=PASS" \
    --out "$WORK_DIR/not-fresh-command-verification-result.json"

expect_fail "fresh command missing coverage evidence" \
  python3 "$SKILL_DIR/scripts/build_verification_result.py" \
    --audit "$WORK_DIR/audit/skill-audit.json" \
    --plan "$WORK_DIR/optimization-plan.json" \
    --eval-results "$WORK_DIR/eval-results.json" \
    --coverage "$COVERAGE" \
    --fresh-command "bash tests/not-a-real-skill-optimizer-check.sh=PASS" \
    --out "$WORK_DIR/fake-command-verification-result.json"

cat > "$WORK_DIR/coverage-no-files.md" <<'EOF'
# Coverage Without Files

Source markers: C09 C10 C11 C12 C13 C14 C99 L O S.
Review decisions: F1 F2 W1 W2 W3 M1.
Design anchors: SO-TRIGGER-01 SO-RUNTIME-01 SO-VALIDATION-01.

- Command: `bash tests/test-skill-optimizer-runtime-artifacts.sh`
  Result: PASS
EOF
expect_fail "invalid verification-result leaves no final artifact" \
  python3 "$SKILL_DIR/scripts/build_verification_result.py" \
    --audit "$WORK_DIR/audit/skill-audit.json" \
    --plan "$WORK_DIR/optimization-plan.json" \
    --eval-results "$WORK_DIR/eval-results.json" \
    --coverage "$WORK_DIR/coverage-no-files.md" \
    --fresh-command "bash tests/test-skill-optimizer-runtime-artifacts.sh=PASS" \
    --out "$WORK_DIR/invalid-final-verification-result.json"
if [ -e "$WORK_DIR/invalid-final-verification-result.json" ]; then
  fail "invalid final verification-result must not be left on disk"
fi

python3 - "$WORK_DIR/verification-result.json" <<'PY'
import json
import sys

artifact = json.load(open(sys.argv[1], encoding="utf-8"))
for field in [
    "schema_validation",
    "semantic_validation",
    "consumer_validation",
    "rendered_view_validation",
    "eval_results",
    "fresh_commands",
    "coverage",
    "decision",
]:
    if field not in artifact:
        raise SystemExit(f"missing verification-result field: {field}")
if artifact["decision"].get("status") != "PASS":
    raise SystemExit("verification decision must be PASS")
if not artifact["fresh_commands"]:
    raise SystemExit("fresh_commands must be nonempty")
PY

for token in C09 C10 C11 C12 C13 C14 C99 L O S F1 F2 W1 W2 W3 M1 SO-TRIGGER-01 SO-RUNTIME-01 SO-VALIDATION-01; do
  assert_present "$token" "$COVERAGE"
done

for token in \
  'shared/skills/skill-optimizer/SKILL.md' \
  'shared/skills/skill-optimizer/scripts/build_verification_result.py' \
  'tests/test-skill-optimizer-end-to-end.sh' \
  'bash tests/test-skill-optimizer-contract.sh' \
  'bash tests/test-skill-optimizer-runtime-artifacts.sh' \
  'bash tests/test-skill-optimizer-evals.sh' \
  'Result: PASS'; do
  assert_present "$token" "$COVERAGE"
done

printf '[PASS] skill-optimizer end-to-end\n'
