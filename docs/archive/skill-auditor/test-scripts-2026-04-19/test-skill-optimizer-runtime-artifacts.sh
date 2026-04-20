#!/usr/bin/env bash
# 文件职责：验证 skill-optimizer runtime JSON artifact 的 schema、语义和消费者合同。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="$ROOT/shared/skills/skill-optimizer"
FIXTURE_DIR="$ROOT/tests/fixtures/skill-optimizer/runtime"
TARGET_DIR="$ROOT/tests/fixtures/skill-optimizer/target-skills"
SCHEMA="$SKILL_DIR/schemas/skill-audit.schema.json"
PLAN_SCHEMA="$SKILL_DIR/schemas/optimization-plan.schema.json"
CONSUMERS="$SKILL_DIR/schemas/field-consumers.json"
WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content: $needle"
}

expect_fail() {
  local label="$1"
  shift
  set +e
  "$@" >/tmp/skill_optimizer_expected_fail.out 2>/tmp/skill_optimizer_expected_fail.err
  local rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    cat /tmp/skill_optimizer_expected_fail.out
    cat /tmp/skill_optimizer_expected_fail.err >&2
    fail "$label unexpectedly passed"
  fi
}

[ -f "$SCHEMA" ] || fail "missing schema: $SCHEMA"
[ -f "$SKILL_DIR/schemas/state-vocabulary.json" ] || fail "missing state vocabulary"
[ -f "$CONSUMERS" ] || fail "missing field consumers"
[ -x "$SKILL_DIR/scripts/validate_schema.py" ] || fail "missing executable validate_schema.py"
[ -x "$SKILL_DIR/scripts/validate_semantics.py" ] || fail "missing executable validate_semantics.py"
[ -x "$SKILL_DIR/scripts/validate_consumers.py" ] || fail "missing executable validate_consumers.py"
[ -f "$PLAN_SCHEMA" ] || fail "missing optimization plan schema"
[ -x "$SKILL_DIR/scripts/audit_skill.py" ] || fail "missing executable audit_skill.py"
[ -x "$SKILL_DIR/scripts/render_report.py" ] || fail "missing executable render_report.py"
[ -x "$SKILL_DIR/scripts/generate_optimization_plan.py" ] || fail "missing executable generate_optimization_plan.py"
[ -x "$SKILL_DIR/scripts/validate_plan_consumption.py" ] || fail "missing executable validate_plan_consumption.py"
[ -x "$SKILL_DIR/scripts/validate_rendered_views.py" ] || fail "missing executable validate_rendered_views.py"
[ -f "$SKILL_DIR/scripts/manifest.json" ] || fail "missing script manifest"
[ -x "$SKILL_DIR/scripts/validate_manifest.py" ] || fail "missing executable validate_manifest.py"
[ -f "$SKILL_DIR/references/hook-adapter-contract.md" ] || fail "missing hook adapter contract"
[ -f "$SKILL_DIR/templates/audit-report.md.tmpl" ] || fail "missing markdown report template"
[ -f "$SKILL_DIR/templates/audit-report.html.tmpl" ] || fail "missing html report template"

python3 "$SKILL_DIR/scripts/validate_schema.py" "$SCHEMA" "$FIXTURE_DIR/valid-skill-audit.json"
python3 "$SKILL_DIR/scripts/validate_semantics.py" "$FIXTURE_DIR/valid-skill-audit.json"
python3 "$SKILL_DIR/scripts/validate_consumers.py" "$CONSUMERS" "$FIXTURE_DIR/valid-skill-audit.json"

expect_fail "missing finding dimension" python3 "$SKILL_DIR/scripts/validate_schema.py" "$SCHEMA" "$FIXTURE_DIR/missing-dimension.json"
expect_fail "missing finding impact" python3 "$SKILL_DIR/scripts/validate_schema.py" "$SCHEMA" "$FIXTURE_DIR/missing-impact.json"
expect_fail "missing finding verification" python3 "$SKILL_DIR/scripts/validate_schema.py" "$SCHEMA" "$FIXTURE_DIR/missing-verification.json"
expect_fail "legacy finding dimension" python3 "$SKILL_DIR/scripts/validate_schema.py" "$SCHEMA" "$FIXTURE_DIR/legacy-dimension.json"
expect_fail "missing evidence refs" python3 "$SKILL_DIR/scripts/validate_semantics.py" "$FIXTURE_DIR/missing-evidence-fail.json"
expect_fail "E5 hard gate" python3 "$SKILL_DIR/scripts/validate_semantics.py" "$FIXTURE_DIR/e5-hard-gate.json"
expect_fail "unknown state" python3 "$SKILL_DIR/scripts/validate_schema.py" "$SCHEMA" "$FIXTURE_DIR/unknown-state.json"
expect_fail "missing design anchor" python3 "$SKILL_DIR/scripts/validate_semantics.py" "$FIXTURE_DIR/missing-design-anchor.json"
expect_fail "field without consumer" python3 "$SKILL_DIR/scripts/validate_consumers.py" "$CONSUMERS" "$FIXTURE_DIR/field-without-consumer.json"
expect_fail "markdown fact source" python3 "$SKILL_DIR/scripts/validate_semantics.py" "$FIXTURE_DIR/markdown-fact-source.json"

python3 "$SKILL_DIR/scripts/audit_skill.py" "$TARGET_DIR/minimal-good" --out-dir "$WORK_DIR/minimal-good"
python3 "$SKILL_DIR/scripts/validate_schema.py" "$SCHEMA" "$WORK_DIR/minimal-good/skill-audit.json"
python3 "$SKILL_DIR/scripts/validate_semantics.py" "$WORK_DIR/minimal-good/skill-audit.json"
python3 "$SKILL_DIR/scripts/validate_consumers.py" "$CONSUMERS" "$WORK_DIR/minimal-good/skill-audit.json"
python3 - "$WORK_DIR/minimal-good/skill-audit.json" <<'PY'
import json
import sys

artifact = json.load(open(sys.argv[1], encoding="utf-8"))
scope = artifact.get("scope", {})
if scope.get("mode") != "deterministic-smoke":
    raise SystemExit("audit script scope must declare deterministic-smoke mode")
required = {"D1", "D3", "D5", "D7", "D8"}
if set(scope.get("requires_manual_review_for", [])) != required:
    raise SystemExit("audit script scope must declare manual review dimensions")
PY

python3 "$SKILL_DIR/scripts/audit_skill.py" "$TARGET_DIR/reference-broken" --out-dir "$WORK_DIR/reference-broken"
python3 - "$WORK_DIR/reference-broken/skill-audit.json" <<'PY'
import json
import sys
artifact = json.load(open(sys.argv[1], encoding="utf-8"))
matches = [
    finding for finding in artifact["findings"]
    if finding["severity"] == "FAIL"
    and finding.get("file_ref")
    and finding.get("evidence_refs")
    and "SO-REFERENCE-01" in finding.get("design_anchors", [])
]
if not matches:
    raise SystemExit("missing reference-broken FAIL finding")
PY

python3 "$SKILL_DIR/scripts/audit_skill.py" "$TARGET_DIR/audit-broken" --out-dir "$WORK_DIR/audit-broken"
python3 "$SKILL_DIR/scripts/validate_schema.py" "$SCHEMA" "$WORK_DIR/audit-broken/skill-audit.json"
python3 "$SKILL_DIR/scripts/validate_semantics.py" "$WORK_DIR/audit-broken/skill-audit.json"
python3 - "$WORK_DIR/audit-broken/skill-audit.json" <<'PY'
import json
import sys
artifact = json.load(open(sys.argv[1], encoding="utf-8"))
dimensions = {
    finding.get("dimension")
    for finding in artifact["findings"]
    if finding.get("severity") == "FAIL"
}
if {"D4", "D6"} - dimensions:
    raise SystemExit("missing audit-broken D4/D6 FAIL findings")
PY

python3 "$SKILL_DIR/scripts/generate_optimization_plan.py" \
  "$WORK_DIR/reference-broken/skill-audit.json" \
  --accept finding-reference-contract \
  --out "$WORK_DIR/reference-broken/optimization-plan.json"
python3 "$SKILL_DIR/scripts/validate_schema.py" "$PLAN_SCHEMA" "$WORK_DIR/reference-broken/optimization-plan.json"
python3 "$SKILL_DIR/scripts/validate_consumers.py" "$CONSUMERS" "$WORK_DIR/reference-broken/optimization-plan.json"
python3 "$SKILL_DIR/scripts/validate_plan_consumption.py" "$WORK_DIR/reference-broken/optimization-plan.json"
expect_fail "plan missing success standard" python3 "$SKILL_DIR/scripts/validate_plan_consumption.py" "$FIXTURE_DIR/plan-missing-success-standard.json"

python3 "$SKILL_DIR/scripts/render_report.py" "$WORK_DIR/reference-broken/skill-audit.json" --out-dir "$WORK_DIR/reference-broken/report"
[ -f "$WORK_DIR/reference-broken/report/audit-report.md" ] || fail "missing rendered markdown report"
[ -f "$WORK_DIR/reference-broken/report/audit-report.html" ] || fail "missing rendered html report"
python3 "$SKILL_DIR/scripts/validate_rendered_views.py" "$WORK_DIR/reference-broken/skill-audit.json"

python3 - "$WORK_DIR/reference-broken/skill-audit.json" "$WORK_DIR/reference-broken/stale-skill-audit.json" <<'PY'
import json
import sys
src, dst = sys.argv[1], sys.argv[2]
artifact = json.load(open(src, encoding="utf-8"))
artifact["rendered_views"][0]["source_artifact_hash"] = "sha256:stale"
json.dump(artifact, open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
expect_fail "stale rendered view" python3 "$SKILL_DIR/scripts/validate_rendered_views.py" "$WORK_DIR/reference-broken/stale-skill-audit.json"

python3 "$SKILL_DIR/scripts/validate_manifest.py" "$SKILL_DIR/scripts/manifest.json"
expect_fail "manifest missing timeout" python3 "$SKILL_DIR/scripts/validate_manifest.py" "$ROOT/tests/fixtures/skill-optimizer/manifest/missing-timeout.json"
expect_fail "manifest missing output limit" python3 "$SKILL_DIR/scripts/validate_manifest.py" "$ROOT/tests/fixtures/skill-optimizer/manifest/missing-output-limit.json"
expect_fail "manifest missing output roots" python3 "$SKILL_DIR/scripts/validate_manifest.py" "$ROOT/tests/fixtures/skill-optimizer/manifest/missing-output-roots.json"
expect_fail "manifest output root escape" python3 "$SKILL_DIR/scripts/validate_manifest.py" "$ROOT/tests/fixtures/skill-optimizer/manifest/output-root-escape.json"
expect_fail "manifest missing denied args" python3 "$SKILL_DIR/scripts/validate_manifest.py" "$ROOT/tests/fixtures/skill-optimizer/manifest/missing-denied-args.json"
expect_fail "manifest missing exit code meanings" python3 "$SKILL_DIR/scripts/validate_manifest.py" "$ROOT/tests/fixtures/skill-optimizer/manifest/missing-exit-code-meanings.json"
expect_fail "manifest missing shell strategy" python3 "$SKILL_DIR/scripts/validate_manifest.py" "$ROOT/tests/fixtures/skill-optimizer/manifest/missing-shell-strategy.json"
expect_fail "manifest path escape" python3 "$SKILL_DIR/scripts/validate_manifest.py" "$ROOT/tests/fixtures/skill-optimizer/manifest/path-escape.json"
expect_fail "manifest bad verification command" python3 "$SKILL_DIR/scripts/validate_manifest.py" "$ROOT/tests/fixtures/skill-optimizer/manifest/bad-verification-command.json"

for hook_field in phase trigger input_artifact allowed_action output_artifact failure_state owner rollback; do
  assert_present "$hook_field" "$SKILL_DIR/references/hook-adapter-contract.md"
done
if [ -f "$ROOT/shared/hooks/registry.json" ] && grep -Fq 'skill-optimizer' "$ROOT/shared/hooks/registry.json"; then
  fail "skill-optimizer must not be registered in global hooks registry"
fi

printf '[PASS] skill-optimizer runtime artifacts\n'
