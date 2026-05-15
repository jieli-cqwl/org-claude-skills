#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg
SKILL="$ROOT/shared/skills/consistency-audit/SKILL.md"
MATRIX="$ROOT/shared/skills/consistency-audit/references/check-matrix.md"
EXTRACT="$ROOT/shared/skills/consistency-audit/scripts/extract-artifacts.sh"
COVERAGE="$ROOT/shared/skills/consistency-audit/scripts/coverage-matrix.sh"
RUNTIME_CHAIN="$ROOT/tools/community/validate_consistency_audit_runtime_chain.py"
AGENT="$ROOT/shared/agents/claude/consistency-auditor.md"
FIXTURE="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/tmp/consistency_audit_absent.out 2>&1; then
    cat /tmp/consistency_audit_absent.out >&2
    fail "unexpected pattern in $file: $pattern"
  fi
}

bash -n "$EXTRACT" "$COVERAGE"
[ -x "$RUNTIME_CHAIN" ] || fail "missing consistency audit runtime-chain validator"

assert_present 'canonical JSON' "$SKILL"
assert_present 'advisory evidence' "$SKILL"
assert_present 'brief.json' "$SKILL"
assert_present 'phase-prd.json' "$SKILL"
assert_present 'artifact-registry.json' "$SKILL"
assert_present 'consistency-audit-result.json' "$SKILL"
assert_present 'tasks.json' "$SKILL"
assert_present 'test-cases.json' "$SKILL"
assert_present 'baseline mode' "$SKILL"
assert_present 'full mode' "$SKILL"
assert_present 'L7' "$SKILL"
assert_absent 'legacy markdown' "$SKILL"
assert_absent '人类投影视图|投影视图模板|projections/consistency-report-template|Markdown 报告' "$SKILL"
assert_absent '/analyze' "$SKILL"

assert_present 'phase-prd.json.unit_index' "$MATRIX"
assert_present 'design.json' "$MATRIX"
assert_present 'tasks.json.tasks' "$MATRIX"
assert_present 'test-cases.json' "$MATRIX"
assert_present 'L7: runtime evidence closure' "$MATRIX"
assert_present 'qa-result.json.obligation_results' "$MATRIX"
assert_absent 'design.md 是否' "$MATRIX"
assert_absent 'plan.md 的 Task' "$MATRIX"
assert_absent 'legacy' "$EXTRACT"
assert_absent 'legacy' "$COVERAGE"
assert_absent 'design.md' "$EXTRACT"
assert_absent 'plan.md' "$EXTRACT"
assert_absent 'test-cases.md' "$COVERAGE"
[ ! -d "$ROOT/shared/skills/consistency-audit/projections" ] \
  || fail "consistency-audit must not retain projections directory"

assert_present '^name: consistency-auditor$' "$AGENT"
assert_present 'skills:' "$AGENT"
assert_present 'consistency-audit' "$AGENT"
assert_present '加载 consistency-audit skill' "$AGENT"
assert_absent 'Write|Edit' "$AGENT"

extract_json="$("$EXTRACT" "$FIXTURE")"
printf '%s\n' "$extract_json" | jq -e '
  (.units | map(.id) | index("UNIT-1")) != null
  and (.tasks | index("T1")) != null
  and (.tasks | index("T2")) != null
  and (.test_cases | index("TC-1")) != null
  and (.artifacts | index("brief.json")) != null
  and (.artifacts | index("phase-1/design.json")) != null
  and (.artifacts | index("phase-1/tasks.json")) != null
  and (.artifacts | index("phase-1/artifact-registry.json")) != null
  and (.artifacts | index("phase-1/unit-1/test-cases.json")) != null
' >/dev/null || fail "extract-artifacts did not recognize canonical fixture"

coverage_json="$(printf '%s\n' "$extract_json" | "$COVERAGE" "$FIXTURE")"
printf '%s\n' "$coverage_json" | jq -e '
  .coverage_rate == 100
  and (.matrix | length) == 1
  and .matrix[0].unit_id == "UNIT-1"
  and .matrix[0].has_design == true
  and .matrix[0].has_plan == true
  and .matrix[0].has_test == true
  and .matrix[0].status == "complete"
' >/dev/null || fail "coverage-matrix did not cover canonical fixture"

"$RUNTIME_CHAIN" --phase-dir "$FIXTURE/phase-1" >/tmp/consistency_audit_runtime_chain.out \
  || fail "runtime-chain validator should accept canonical fixture"

tmp_fixture="$(mktemp -d "${TMPDIR:-/tmp}/consistency-audit-runtime-chain.XXXXXX")"
trap 'rm -rf "$tmp_fixture"' EXIT
cp -R "$FIXTURE" "$tmp_fixture/sample-feature"
python3 - "$tmp_fixture/sample-feature/phase-1/qa-result.json" <<'PY'
import json
import sys
from pathlib import Path

qa_path = Path(sys.argv[1])
payload = json.loads(qa_path.read_text(encoding="utf-8"))
payload["obligation_results"] = []
qa_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if "$RUNTIME_CHAIN" --phase-dir "$tmp_fixture/sample-feature/phase-1" >/tmp/consistency_audit_runtime_chain_negative.out 2>&1; then
  cat /tmp/consistency_audit_runtime_chain_negative.out >&2
  fail "runtime-chain validator should reject uncovered QA handoff obligations"
fi
grep -Eq 'QHO-STATIC-CONTRACT' /tmp/consistency_audit_runtime_chain_negative.out \
  || fail "runtime-chain validator failure should name uncovered obligation ids"

echo "[PASS] consistency-audit canonical agent contract"
