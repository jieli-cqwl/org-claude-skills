#!/usr/bin/env bash
# 文件职责：验证 skill-optimizer eval dataset、manifest command id 和结果边界。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="$ROOT/shared/skills/skill-optimizer"
EVALS="$SKILL_DIR/evals/evals.json"
MANIFEST="$SKILL_DIR/scripts/manifest.json"
RUNNER="$SKILL_DIR/scripts/run_evals.py"
VALIDATOR="$SKILL_DIR/scripts/validate_eval_results.py"
FIXTURE_DIR="$ROOT/tests/fixtures/skill-optimizer/evals"
WORK_DIR="$(mktemp -d)"

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
  "$@" >/tmp/skill_optimizer_eval_expected_fail.out 2>/tmp/skill_optimizer_eval_expected_fail.err
  local rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    cat /tmp/skill_optimizer_eval_expected_fail.out
    cat /tmp/skill_optimizer_eval_expected_fail.err >&2
    fail "$label unexpectedly passed"
  fi
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content: $needle"
}

[ -f "$EVALS" ] || fail "missing eval dataset"
[ -x "$RUNNER" ] || fail "missing executable run_evals.py"
[ -x "$VALIDATOR" ] || fail "missing executable validate_eval_results.py"

assert_present '"run-evals"' "$MANIFEST"
assert_present '"validate-eval-results"' "$MANIFEST"

python3 - "$EVALS" "$MANIFEST" <<'PY'
import json
import sys

evals_path, manifest_path = sys.argv[1], sys.argv[2]
dataset = json.load(open(evals_path, encoding="utf-8"))
manifest = json.load(open(manifest_path, encoding="utf-8"))
required = {
    "trigger",
    "non_trigger",
    "neighbor_conflict",
    "missing_argument",
    "wrong_argument",
    "permission_denied",
    "format_injection",
    "migration_compatibility",
    "fork_isolation",
    "subagent_skills_full_preload",
    "pipeline_handoff",
    "conflict_adjudication",
    "dollar_arguments",
    "bang_command",
}
cases = dataset.get("cases", [])
categories = {case.get("category") for case in cases}
missing = sorted(required - categories)
if missing:
    raise SystemExit("missing eval categories: " + ", ".join(missing))
case_by_id = {case.get("case_id"): case for case in cases}
for required_case in ("audit-reference-broken-finding", "audit-minimal-good-no-fail"):
    case = case_by_id.get(required_case)
    if not case:
        raise SystemExit(f"missing audit eval case: {required_case}")
    if case.get("run_command_id") != "audit-skill" or case.get("check_type") != "audit_fixture":
        raise SystemExit(f"{required_case} must execute audit-skill as audit_fixture")
command_ids = {script["id"] for script in manifest.get("scripts", [])}
required_fields = {
    "case_id",
    "category",
    "input",
    "expected_decision",
    "target_skill_ref",
    "neighbor_skill_refs",
    "run_command_id",
    "pass_fail_condition",
}
forbidden_fields = {"observed_decision"}
for case in cases:
    missing_fields = sorted(required_fields - set(case))
    if missing_fields:
        raise SystemExit(f"{case.get('case_id', '<unknown>')} missing fields: {missing_fields}")
    present_forbidden = sorted(forbidden_fields & set(case))
    if present_forbidden:
        raise SystemExit(f"{case.get('case_id', '<unknown>')} forbidden fields: {present_forbidden}")
    if any(field in case for field in ("command", "shell", "raw_command")):
        raise SystemExit(f"{case['case_id']} contains raw shell field")
    command_id = case.get("run_command_id")
    if command_id and command_id not in command_ids:
        raise SystemExit(f"{case['case_id']} uses unknown run_command_id {command_id}")
PY

python3 "$RUNNER" "$EVALS" "$MANIFEST" --out "$WORK_DIR/eval-results.json"
python3 "$VALIDATOR" "$WORK_DIR/eval-results.json" "$MANIFEST"

(
  cd "$ROOT"
  python3 shared/skills/skill-optimizer/scripts/run_evals.py \
    shared/skills/skill-optimizer/evals/evals.json \
    shared/skills/skill-optimizer/scripts/manifest.json \
    --out "$WORK_DIR/eval-results-relative.json"
)
python3 "$VALIDATOR" "$WORK_DIR/eval-results-relative.json" "$MANIFEST"

python3 - "$WORK_DIR/eval-results.json" <<'PY'
import json
import sys

artifact = json.load(open(sys.argv[1], encoding="utf-8"))
if any(result.get("observed_decision") is None for result in artifact.get("results", [])):
    raise SystemExit("eval runner did not derive observed decisions")
draft = artifact.get("verification_result_draft_input", {})
if draft.get("consumer") != "build_verification_result.py":
    raise SystemExit("eval results missing verification-result draft consumer")
evidence = artifact.get("usability_evidence", {}).get("five_ten_thirty", {})
if evidence.get("counts_as_quality_benefit") is not False:
    raise SystemExit("5/10/30 counted as quality benefit")
if artifact.get("quality_benefit"):
    raise SystemExit("quality benefit must not be derived from 5/10/30")
results = {result.get("case_id"): result for result in artifact.get("results", [])}
reference = results.get("audit-reference-broken-finding", {}).get("command_evidence", {})
if "finding-reference-contract" not in reference.get("fail_finding_ids", []):
    raise SystemExit("reference-broken audit eval must emit finding-reference-contract")
minimal = results.get("audit-minimal-good-no-fail", {}).get("command_evidence", {})
if minimal.get("fail_finding_ids"):
    raise SystemExit("minimal-good audit eval must emit no FAIL findings")
PY

expect_fail "raw shell command" python3 "$RUNNER" "$FIXTURE_DIR/raw-shell-command.json" "$MANIFEST" --out "$WORK_DIR/raw.json"
expect_fail "unknown command id" python3 "$RUNNER" "$FIXTURE_DIR/unknown-command-id.json" "$MANIFEST" --out "$WORK_DIR/unknown.json"
expect_fail "unapproved command arg" python3 "$RUNNER" "$FIXTURE_DIR/unapproved-command-arg.json" "$MANIFEST" --out "$WORK_DIR/unapproved-arg.json"
expect_fail "category self certification" python3 "$RUNNER" "$FIXTURE_DIR/category-mismatch-self-cert.json" "$MANIFEST" --out "$WORK_DIR/category-self-cert.json"
expect_fail "missing eval category" python3 "$RUNNER" "$FIXTURE_DIR/missing-category.json" "$MANIFEST" --out "$WORK_DIR/missing-category.json"
expect_fail "5/10/30 quality claim" python3 "$VALIDATOR" "$FIXTURE_DIR/quality-claim-5-10-30.json" "$MANIFEST"

printf '[PASS] skill-optimizer evals\n'
