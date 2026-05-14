#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

SKILL="$ROOT/shared/skills/verify/SKILL.md"
REFERENCE_DIR="$ROOT/shared/skills/verify/references"
MANIFEST="$ROOT/shared/skills/verify/scripts/manifest.json"
PREFLIGHT="$ROOT/shared/skills/verify/scripts/preflight_check.sh"
PREFLIGHT_PY="$ROOT/shared/skills/verify/scripts/preflight_check.py"
FIXTURE="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in ${file#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/tmp/org_verify_contract_absent.out 2>&1; then
    cat /tmp/org_verify_contract_absent.out >&2
    fail "unexpected pattern in ${file#"$ROOT"/}: $pattern"
  fi
}

run_preflight() {
  local phase_dir="$1"
  local task_id="$2"
  local output="$3"
  bash "$PREFLIGHT" --phase-dir "$phase_dir" --task-id "$task_id" >"$output"
}

with_fixture() {
  local tmp_root
  tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/verify-preflight.XXXXXX")"
  cp -R "$FIXTURE" "$tmp_root/sample-feature"
  printf '%s\n' "$tmp_root/sample-feature"
}

assert_skill_flow_is_real_verifier_sop() {
  assert_present 'digraph verify_flow' "$SKILL"
  assert_present '`PHASE_DIR` 和 `TASK_ID` 优先来自用户或派发输入' "$SKILL"
  assert_present '\$PHASE_DIR/artifact-registry\.json' "$SKILL"
  assert_present '"Preflight 判定" -> "建立 AC 证据矩阵" \[label="PASS"\]' "$SKILL"
  assert_present '"Preflight 判定" -> "BLOCKED" \[label="FAIL: 输入不可验"\]' "$SKILL"
  assert_present '建立 AC 证据矩阵' "$SKILL"
  assert_present '反证 AC 与范围' "$SKILL"
  assert_present '归因与路由' "$SKILL"
  assert_present 'shared/skills/verify/scripts/preflight_check\.sh --phase-dir "\$PHASE_DIR" --task-id "\$TASK_ID"' "$SKILL"
  assert_present 'shared/skills/verify/templates/verify-result\.template\.json' "$SKILL"
  assert_present 'shared/skills/verify/contracts/verify-result\.schema\.json' "$SKILL"
  assert_absent '"运行 Preflight" ->' "$SKILL"
  assert_absent '^## 前置条件$|^## Scope 参数$|说明模式|默认从 scope registry' "$SKILL"
  assert_absent 'Trigger:|Read:|Expect:|Consume:|Evidence:|Sync:' "$SKILL"
  assert_absent '流程表：|Canonical 必填摘要|运行时模板|projections/verify-report-template\.md' "$SKILL"
}

assert_references_are_consumable_rubrics() {
  local ref
  for ref in "$REFERENCE_DIR"/*.md; do
    assert_absent 'Trigger:|Read:|Expect:|Consume:|Evidence:|Sync:|引用者：' "$ref"
    assert_absent '临界度评分|5 步系统检查|检查清单|直接占位|中等难度|难检测|示例 \|' "$ref"
  done
}

assert_manifest_declares_preflight() {
  jq -e '
    .scripts[]
    | select(.id == "preflight-check")
    | .path == "scripts/preflight_check.sh"
      and .owner == "verify"
      and (.allowed_args | index("--phase-dir") != null)
      and (.allowed_args | index("--task-id") != null)
      and .failure_state == "VERIFY_PREFLIGHT_FAILED"
      and (.verification_command | contains("tests/test-verify-contract-alignment.sh"))
  ' "$MANIFEST" >/dev/null || fail "verify manifest must declare preflight-check"
}

assert_preflight_passes() {
  local workspace phase_dir output
  workspace="$(with_fixture)"
  output="$(mktemp "${TMPDIR:-/tmp}/verify-preflight-pass.XXXXXX")"
  phase_dir="$workspace/phase-1"
  if run_preflight "$phase_dir" T1 "$output"; then
    jq -e '.status == "PASS" and .task_id == "T1" and (.developer_report_path | test("developer-report\\.json$"))' "$output" >/dev/null \
      || fail "verify preflight PASS output missing task/developer report path"
  else
    cat "$output" >&2
    fail "verify preflight should accept complete Task input"
  fi
  rm -rf "$(dirname "$workspace")" "$output"
}

assert_preflight_blocks_missing_developer_report() {
  local workspace phase_dir output report
  workspace="$(with_fixture)"
  output="$(mktemp "${TMPDIR:-/tmp}/verify-preflight-missing-report.XXXXXX")"
  phase_dir="$workspace/phase-1"
  report="$phase_dir/unit-1/tasks/T1/developer-report.json"
  rm "$report"
  if run_preflight "$phase_dir" T1 "$output"; then
    fail "verify preflight should block missing developer-report.json"
  fi
  jq -e '.status == "BLOCKED" and .failure_code == "MISSING_INPUT" and (.reason | contains("developer-report"))' "$output" >/dev/null \
    || fail "missing developer-report block output is not actionable"
  rm -rf "$(dirname "$workspace")" "$output"
}

assert_preflight_blocks_missing_test_refs() {
  local workspace phase_dir output
  workspace="$(with_fixture)"
  output="$(mktemp "${TMPDIR:-/tmp}/verify-preflight-missing-test-refs.XXXXXX")"
  phase_dir="$workspace/phase-1"
  jq '(.tasks[] | select(.task_id == "T1") | .test_refs) = []' "$phase_dir/tasks.json" >"$phase_dir/tasks.tmp.json"
  mv "$phase_dir/tasks.tmp.json" "$phase_dir/tasks.json"
  if run_preflight "$phase_dir" T1 "$output"; then
    fail "verify preflight should block missing test_refs"
  fi
  jq -e '.status == "BLOCKED" and .failure_code == "MISSING_INPUT" and (.reason | contains("test_refs"))' "$output" >/dev/null \
    || fail "missing test_refs block output is not actionable"
  rm -rf "$(dirname "$workspace")" "$output"
}

assert_preflight_blocks_invalid_tdd_evidence() {
  local workspace phase_dir output report
  workspace="$(with_fixture)"
  output="$(mktemp "${TMPDIR:-/tmp}/verify-preflight-invalid-tdd.XXXXXX")"
  phase_dir="$workspace/phase-1"
  report="$phase_dir/unit-1/tasks/T1/developer-report.json"
  jq 'del(.tdd_evidence_index)' "$report" >"$report.tmp"
  mv "$report.tmp" "$report"
  if run_preflight "$phase_dir" T1 "$output"; then
    fail "verify preflight should block invalid developer TDD evidence"
  fi
  jq -e '.status == "BLOCKED" and .failure_code == "DEVELOPER_REPORT_INVALID" and .owner == "developer"' "$output" >/dev/null \
    || fail "invalid TDD evidence block output should route to developer"
  rm -rf "$(dirname "$workspace")" "$output"
}

test -f "$SKILL" || fail "missing verify SKILL"
test -x "$PREFLIGHT" || fail "verify preflight script must be executable"
python3 -m py_compile "$PREFLIGHT_PY"

assert_skill_flow_is_real_verifier_sop
assert_references_are_consumable_rubrics
assert_manifest_declares_preflight
assert_preflight_passes
assert_preflight_blocks_missing_developer_report
assert_preflight_blocks_missing_test_refs
assert_preflight_blocks_invalid_tdd_evidence

printf '[PASS] verify contract alignment\n'
