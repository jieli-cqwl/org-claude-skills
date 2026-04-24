#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

PASS=0
FAIL=0

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  FAIL=$((FAIL + 1))
}

pass() {
  printf '[PASS] %s\n' "$*"
  PASS=$((PASS + 1))
}

assert_present() {
  local desc="$1" pattern="$2" file="$3"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    pass "$desc"
  else
    fail "$desc — missing pattern '$pattern' in $file"
  fi
}

assert_absent() {
  local desc="$1" pattern="$2" file="$3"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "$desc — unexpected pattern '$pattern' found in $file"
  else
    pass "$desc"
  fi
}

assert_non_git_gate_blocks_fake_sha() {
  local tmp_root report transcript payload stdout_file stderr_file output_file rc

  tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/developer-gate.XXXXXX")"
  stdout_file="$(mktemp "${TMPDIR:-/tmp}/developer-gate.stdout.XXXXXX")"
  stderr_file="$(mktemp "${TMPDIR:-/tmp}/developer-gate.stderr.XXXXXX")"
  output_file="$(mktemp "${TMPDIR:-/tmp}/developer-gate.output.XXXXXX")"

  cleanup_non_git_gate_fixture() {
    rm -rf "$tmp_root" "$stdout_file" "$stderr_file" "$output_file"
  }
  trap cleanup_non_git_gate_fixture RETURN

  mkdir -p "$tmp_root/docs/demo/phase-1/unit-1/tasks/T1"
  report="$tmp_root/docs/demo/phase-1/unit-1/tasks/T1/developer-report.json"
  transcript="$tmp_root/transcript.log"

  cat > "$report" <<'EOF'
{
  "artifact_type": "developer-report",
  "artifact_id": "demo.phase-1.unit-1.task-T1.developer-report",
  "schema_version": "1.0.0",
  "producer": "developer",
  "produced_at": "2026-04-24T00:00:00Z",
  "chain_version": "standard-chain/v1",
  "chain_registry_digest": "sha256:306668c17650b323b74a7d4aa616b029e8c2b17ee9bd960f15f89321bffc8bd3",
  "authority_scope": "artifact",
  "authoritative_fields": [
    "$.runtime_status",
    "$.active_plan_version_ref",
    "$.active_tasks_version_ref",
    "$.evidence_refs",
    "$.reviewable_anchor",
    "$.tdd_evidence_index"
  ],
  "evidence_refs": [
    "artifact://evidence/demo.phase-1.task-T1.log@ev-1#log-root"
  ],
  "active_plan_version_ref": "artifact://plan/demo.phase-1.plan@plan-v1#plan-version",
  "active_tasks_version_ref": "artifact://tasks/demo.phase-1.tasks@tasks-v1#task-registry",
  "task_id": "T1",
  "runtime_status": "VERIFIED",
  "summary_text": "demo report",
  "reviewable_anchor": "artifact://developer-report/demo.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index",
  "file_changes": [
    "src/demo.ts"
  ],
  "tdd_evidence_index": [
    {
      "phase": "RED",
      "commit_sha": "abc1111",
      "test_ref": "tests/demo.test.ts",
      "result": "FAIL_EXPECTED",
      "ac_refs": [
        "artifact://test-cases/demo.phase-1.unit-1.test-cases@v1#AC-001"
      ]
    },
    {
      "phase": "GREEN",
      "commit_sha": "abc2222",
      "test_ref": "tests/demo.test.ts",
      "result": "PASS",
      "ac_refs": [
        "artifact://test-cases/demo.phase-1.unit-1.test-cases@v1#AC-001"
      ]
    }
  ],
  "task_scope": [
    "src/demo.ts"
  ]
}
EOF

  cat > "$transcript" <<'EOF'
Write docs/demo/phase-1/unit-1/tasks/T1/developer-report.json
EOF

  payload="$(jq -nc \
    --arg cwd "$tmp_root" \
    --arg sid "session-developer-nongit" \
    --arg tp "$transcript" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp}')"

  if bash "$ROOT/shared/skills/developer/scripts/completion_check.sh" >"$stdout_file" 2>"$stderr_file" <<<"$payload"; then
    rc=0
  else
    rc=$?
  fi
  cat "$stdout_file" "$stderr_file" >"$output_file"

  if [ "$rc" -eq 0 ]; then
    fail "developer gate 在非 Git 环境不应接受伪造 Commit SHA"
    return
  fi

  if ! grep -Fq '"decision":"block"' "$stdout_file"; then
    fail "developer gate 非 Git 阻断时必须输出 block decision"
    return
  fi

  if ! rg -n '非 Git 环境|Commit SHA.*无法验证|可追溯的 Commit SHA' "$output_file" >/dev/null 2>&1; then
    fail "developer gate 非 Git 阻断信息必须明确说明 Commit SHA 无法验证"
    return
  fi

  pass "developer gate 在非 Git 环境阻断伪造 Commit SHA"
}

assert_canonical_json_report_passes() {
  local tmp_feature report transcript stdout_file stderr_file payload rc

  tmp_feature="$(mktemp -d "$ROOT/docs/developer-canonical.XXXXXX")"
  stdout_file="$(mktemp "${TMPDIR:-/tmp}/developer-canonical.stdout.XXXXXX")"
  stderr_file="$(mktemp "${TMPDIR:-/tmp}/developer-canonical.stderr.XXXXXX")"

  cleanup_canonical_json_report_fixture() {
    rm -rf "$tmp_feature" "$stdout_file" "$stderr_file"
  }
  trap cleanup_canonical_json_report_fixture RETURN

  mkdir -p "$tmp_feature/phase-1/unit-1/tasks/T1"
  report="$tmp_feature/phase-1/unit-1/tasks/T1/developer-report.json"
  cp "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json" "$report"
  transcript="$tmp_feature/transcript.log"
  printf 'Write %s\n' "${report#"$ROOT"/}" > "$transcript"

  payload="$(jq -nc \
    --arg cwd "$ROOT" \
    --arg sid "session-developer-canonical-json" \
    --arg tp "$transcript" \
    --arg fp "${report#"$ROOT"/}" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp, tool_name:"Write", tool_input:{file_path:$fp}}')"

  if bash "$ROOT/shared/skills/developer/scripts/completion_check.sh" >"$stdout_file" 2>"$stderr_file" <<<"$payload"; then
    rc=0
  else
    rc=$?
  fi

  if [ "$rc" -ne 0 ]; then
    cat "$stdout_file" "$stderr_file" >&2
    fail "developer gate 应接受 canonical developer-report.json"
    return
  fi

  pass "developer gate 接受 canonical developer-report.json"
}

assert_canonical_json_report_rejects_mutation() {
  local label="$1"
  local jq_filter="$2"
  local expected_pattern="$3"
  local tmp_feature report transcript stdout_file stderr_file output_file payload rc

  tmp_feature="$(mktemp -d "$ROOT/docs/developer-canonical-negative.XXXXXX")"
  stdout_file="$(mktemp "${TMPDIR:-/tmp}/developer-canonical-negative.stdout.XXXXXX")"
  stderr_file="$(mktemp "${TMPDIR:-/tmp}/developer-canonical-negative.stderr.XXXXXX")"
  output_file="$(mktemp "${TMPDIR:-/tmp}/developer-canonical-negative.output.XXXXXX")"

  cleanup_canonical_negative_fixture() {
    rm -rf "$tmp_feature" "$stdout_file" "$stderr_file" "$output_file"
  }
  trap cleanup_canonical_negative_fixture RETURN

  mkdir -p "$tmp_feature/phase-1/unit-1/tasks/T1"
  report="$tmp_feature/phase-1/unit-1/tasks/T1/developer-report.json"
  jq "$jq_filter" \
    "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json" \
    > "$report"
  transcript="$tmp_feature/transcript.log"
  printf 'Write %s\n' "${report#"$ROOT"/}" > "$transcript"

  payload="$(jq -nc \
    --arg cwd "$ROOT" \
    --arg sid "session-developer-canonical-negative" \
    --arg tp "$transcript" \
    --arg fp "${report#"$ROOT"/}" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp, tool_name:"Write", tool_input:{file_path:$fp}}')"

  if bash "$ROOT/shared/skills/developer/scripts/completion_check.sh" >"$stdout_file" 2>"$stderr_file" <<<"$payload"; then
    rc=0
  else
    rc=$?
  fi
  cat "$stdout_file" "$stderr_file" > "$output_file"

  if [ "$rc" -eq 0 ]; then
    cat "$output_file" >&2
    fail "developer gate 应拒绝 canonical developer-report.json：$label"
    return
  fi
  if ! rg -n "$expected_pattern" "$output_file" >/dev/null 2>&1; then
    cat "$output_file" >&2
    fail "developer gate 拒绝信息未命中：$label"
    return
  fi

  pass "developer gate 拒绝 canonical developer-report.json：$label"
}

DEV_SKILL="$ROOT/shared/skills/developer/SKILL.md"
DEV_AGENT="$ROOT/shared/agents/developer.md"
DEV_SELF_TEST="$ROOT/shared/skills/developer/references/self-testing-methodology.md"
DEV_SELF_REVIEW="$ROOT/shared/skills/developer/references/self-review-methodology.md"
DEV_TEMPLATE="$ROOT/shared/skills/developer/references/templates/developer-report-template.md"
DEV_CHECK="$ROOT/shared/skills/developer/scripts/completion_check.sh"

assert_present \
  "developer SKILL 规定 design.json 必须显式入文件范围" \
  'design\.json.*显式.*列入.*Task 文件范围' \
  "$DEV_SKILL"

assert_present \
  "developer agent 保持极薄角色启动语" \
  '^你是 developer。' \
  "$DEV_AGENT"

assert_present \
  "developer SKILL 要求 design_refs 在 design.json 内解析" \
  'design_refs.*design\.json' \
  "$DEV_SKILL"

assert_present \
  "developer agent 只承接单个 Task" \
  '单个 Task' \
  "$DEV_AGENT"

assert_absent \
  "developer SKILL 不再要求读取 MOD markdown 投影" \
  'design/MOD-\*\.md|MOD 文档' \
  "$DEV_SKILL"

assert_absent \
  "developer agent 不再要求读取 MOD markdown 投影" \
  'design/MOD-\*\.md|MOD 文档' \
  "$DEV_AGENT"

assert_present \
  "developer SKILL 对既有失败给出 BLOCKED 口径" \
  '既有失败.*BLOCKED' \
  "$DEV_SKILL"

assert_present \
  "developer SKILL 对既有失败给出部分完成口径" \
  '既有失败.*部分完成' \
  "$DEV_SKILL"

assert_present \
  "developer SKILL 仍要求全量测试 PASS 才能完成" \
  '全量测试 PASS' \
  "$DEV_SKILL"

assert_present \
  "self-testing 方法论对既有失败给出 BLOCKED 口径" \
  '既有失败.*BLOCKED' \
  "$DEV_SELF_TEST"

assert_present \
  "self-testing 方法论对既有失败给出部分完成口径" \
  '既有失败.*部分完成' \
  "$DEV_SELF_TEST"

assert_absent \
  "developer SKILL 不再残留 PM" \
  '(^|[^A-Za-z])PM([^A-Za-z]|$)|项目经理' \
  "$DEV_SKILL"

assert_absent \
  "developer agent 不再残留 PM" \
  '(^|[^A-Za-z])PM([^A-Za-z]|$)|项目经理' \
  "$DEV_AGENT"

assert_absent \
  "developer 模板不再残留 PM" \
  '(^|[^A-Za-z])PM([^A-Za-z]|$)|项目经理' \
  "$DEV_TEMPLATE"

assert_present \
  "developer 模板改为 delivery-owner/verify 引用说明" \
  'delivery-owner/verify' \
  "$DEV_TEMPLATE"

assert_present \
  "self-review 标题修正为 7 维度" \
  '^## 7 维度结构化自审$' \
  "$DEV_SELF_REVIEW"

assert_present \
  "developer 模板仍固定 Commit SHA 字段" \
  '^\| 阶段 \| Commit SHA \| 测试文件 \| 结果 \|$' \
  "$DEV_TEMPLATE"

assert_present \
  "developer gate 显式支持 canonical developer-report.json" \
  'developer-report\.json' \
  "$DEV_CHECK"

assert_present \
  "developer gate 使用 canonical schema validator" \
  'validate_canonical_schema\.py' \
  "$DEV_CHECK"

assert_non_git_gate_blocks_fake_sha
assert_canonical_json_report_passes
assert_canonical_json_report_rejects_mutation \
  "Commit SHA 不存在" \
  '.tdd_evidence_index[0].commit_sha = "deadbee"' \
  'Commit SHA.*不存在|Commit SHA'
assert_canonical_json_report_rejects_mutation \
  "RED 结果不是 FAIL_EXPECTED" \
  '.tdd_evidence_index[0].result = "PASS"' \
  'RED.*FAIL_EXPECTED|GREEN.*PASS'

printf '\n── Summary ──\n'
printf 'PASS: %d  FAIL: %d\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
