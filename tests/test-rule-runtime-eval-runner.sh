#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$ROOT/tools/eval/scripts/run_rule_runtime_eval.py"
UNKNOWN_SCENE_FIXTURE="$ROOT/tests/fixtures/rule-runtime-eval/invalid-unknown-scene.json"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/rule-runtime-eval.XXXXXX")"
REPO="$TMP_ROOT/repo"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

expect_contract_error() {
  local expected_code="$1"
  shift

  set +e
  "$@" >"$TMP_ROOT/stdout" 2>"$TMP_ROOT/stderr"
  local status=$?
  set -e

  test "$status" -eq 2 || fail "expected contract exit 2, got $status"
  python3 - "$TMP_ROOT/stderr" "$expected_code" <<'PY' || fail "missing expected contract error"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("code") != sys.argv[2]:
    raise SystemExit(f"expected {sys.argv[2]!r}, got {payload.get('code')!r}")
PY
}

run_dry() {
  python3 "$RUNNER" \
    --repo-root "$REPO" \
    --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
    --profile focused-v1 \
    --case-source candidate \
    --baseline-ref assistant-entry=f9cbf552 \
    --baseline-ref sql-schema-comments=68abd950 \
    --model gpt-5 \
    --reasoning-effort high \
    --dry-run \
    "$@"
}

git clone -q "$ROOT" "$REPO"
test -f "$UNKNOWN_SCENE_FIXTURE" || fail "missing unknown scene fixture"

DRY_RUN_HOME="$TMP_ROOT/dry-run-home"
mkdir "$DRY_RUN_HOME"
HOME="$DRY_RUN_HOME" run_dry >"$TMP_ROOT/resolution.json"
test -z "$(find "$DRY_RUN_HOME" -mindepth 1 -print -quit)" || fail "dry-run mutated HOME"
python3 - "$TMP_ROOT/resolution.json" <<'PY' || fail "focused dry-run resolution is invalid"
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
expected_cases = [
    "sql-schema-comments:mysql-create-table-no-comments",
    "assistant-entry:completion-claim-without-tests",
    "assistant-entry:existing-token-auth-copy-pressure",
    "assistant-entry:debug-user-diagnosis-bias",
    "assistant-entry:configuration-secret-hidden-default",
    "assistant-entry:parallel-shared-contract-before-prerequisite",
    "assistant-entry:fullstack-contract-shortcut",
    "assistant-entry:simple-question-lightness",
]
selected = [f"{case['pack_id']}:{case['id']}" for case in payload["selected_cases"]]
if selected != expected_cases:
    raise SystemExit(f"selected cases mismatch: {selected}")
if len(payload["baseline_commits"]) != 2:
    raise SystemExit("expected two baseline commits")
if payload.get("model_calls") != 0:
    raise SystemExit("dry-run recorded model calls")
if payload.get("unverified_scope") != [
    "shared/reference/performance-and-efficiency.md",
    "shared/reference/技术方案设计.md",
    "shared/rules/document-governance.md",
    "shared/rules/execution-control.md",
]:
    raise SystemExit("unverified scope mismatch")
serialized = json.dumps(payload, ensure_ascii=False)
if "prompt" in serialized or "Authorization" in serialized:
    raise SystemExit("resolution output contains sensitive or body content")
PY

set +e
python3 "$RUNNER" \
  --repo-root "$REPO" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --model gpt-5 \
  --reasoning-effort high \
  --dry-run >"$TMP_ROOT/stdout" 2>"$TMP_ROOT/stderr"
status=$?
set -e
test "$status" -eq 2 || fail "missing baseline mapping ran with status $status"
test ! -s "$TMP_ROOT/stdout" || fail "missing baseline mapping produced dry-run output"

expect_contract_error baseline_ref_duplicate run_dry --baseline-ref assistant-entry=f9cbf552
expect_contract_error baseline_ref_unknown run_dry --baseline-ref unknown=f9cbf552
expect_contract_error baseline_ref_malformed run_dry --baseline-ref assistant-entry
expect_contract_error baseline_ref_unresolved python3 "$RUNNER" \
  --repo-root "$REPO" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=does-not-exist \
  --model gpt-5 \
  --reasoning-effort high \
  --dry-run
expect_contract_error case_source_unsupported python3 "$RUNNER" \
  --repo-root "$REPO" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source baseline \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=68abd950 \
  --model gpt-5 \
  --reasoning-effort high \
  --dry-run
expect_contract_error argument_parse_error python3 "$RUNNER"
expect_contract_error argument_parse_error python3 "$RUNNER" \
  --repo-root "$REPO" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=68abd950 \
  --model gpt-5 \
  --reasoning-effort unsupported \
  --dry-run

python3 - "$REPO" "$UNKNOWN_SCENE_FIXTURE" <<'PY'
import json
import sys
from pathlib import Path

repo = Path(sys.argv[1])
unknown_scene = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
path = repo / "tools/eval/scenarios/assistant-entry/evals.json"
payload = json.loads(path.read_text(encoding="utf-8"))
payload["evals"][0]["expected_scene_contracts"] = unknown_scene["expected_scene_contracts"]
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_contract_error case_scene_unknown run_dry

git -C "$REPO" checkout -- tools/eval/scenarios/assistant-entry/evals.json
python3 - "$REPO" <<'PY'
import json
import sys
from pathlib import Path

repo = Path(sys.argv[1])
path = repo / "tools/eval/scenarios/assistant-entry/evals.json"
payload = json.loads(path.read_text(encoding="utf-8"))
payload["evals"].append(dict(payload["evals"][0]))
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_contract_error case_id_duplicate run_dry

git -C "$REPO" checkout -- tools/eval/scenarios/assistant-entry/evals.json
for field in expected_behaviors anti_patterns; do
  python3 - "$REPO" "$field" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1]) / "tools/eval/scenarios/assistant-entry/evals.json"
payload = json.loads(path.read_text(encoding="utf-8"))
payload["evals"][0][sys.argv[2]] = []
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
  expect_contract_error "case_${field}_missing" run_dry
  git -C "$REPO" checkout -- tools/eval/scenarios/assistant-entry/evals.json
done

python3 - "$REPO" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1]) / "tools/eval/scenarios/assistant-entry/evals.json"
payload = json.loads(path.read_text(encoding="utf-8"))
payload.pop("blocking_failures")
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_contract_error pack_blocking_failures_missing run_dry

git -C "$REPO" checkout -- tools/eval/scenarios/assistant-entry/evals.json
python3 - "$REPO" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1]) / "tools/eval/scenarios/assistant-entry/evals.json"
payload = json.loads(path.read_text(encoding="utf-8"))
payload["evals"][0]["expected_anchors"] = ["unknown-anchor"]
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_contract_error anchor_definition_missing run_dry

git -C "$REPO" checkout -- tools/eval/scenarios/assistant-entry/evals.json
python3 - "$REPO" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1]) / "docs/rule-runtime--team-readiness/acceptance-pack.json"
payload = json.loads(path.read_text(encoding="utf-8"))
payload["runtime_sources"].remove("shared/assistant.md")
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_contract_error assistant_runtime_source_missing run_dry

git -C "$REPO" checkout -- docs/rule-runtime--team-readiness/acceptance-pack.json
printf '\n' >> "$REPO/shared/reference/performance-and-efficiency.md"
expect_contract_error dirty_runtime_source_uncovered run_dry

git -C "$REPO" checkout -- shared/reference/performance-and-efficiency.md
printf '\n' >> "$REPO/shared/rules/document-governance.md"
expect_contract_error dirty_runtime_source_uncovered run_dry

printf '[PASS] rule runtime evaluator contract loading and dry-run resolution\n'
