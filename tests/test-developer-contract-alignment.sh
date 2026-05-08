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

assert_allowed_tools_exact() {
  local desc="$1" file="$2" expected_csv="$3"
  if python3 - "$file" "$expected_csv" <<'PY'; then
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected = [item.strip() for item in sys.argv[2].split(",") if item.strip()]
actual = None
for line in path.read_text(encoding="utf-8").splitlines():
    if line.startswith("allowed-tools:"):
        actual = [item.strip() for item in line.split(":", 1)[1].split(",") if item.strip()]
        break
if actual is None:
    raise SystemExit("missing allowed-tools")
if sorted(actual) != sorted(expected):
    raise SystemExit(f"actual={actual}, expected={expected}")
PY
    pass "$desc"
  else
    fail "$desc"
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
    "$.tdd_evidence_index",
    "$.self_testing",
    "$.fresh_proof"
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
  ],
  "self_testing": {
    "coverage_review": {
      "status": "PASS",
      "evidence_ref": "artifact://developer-report/demo.phase-1.unit-1.task-T1.developer-report@v1#coverage-review"
    },
    "full_regression": {
      "status": "PASS",
      "command": "bash tests/demo.test.ts",
      "evidence_ref": "artifact://developer-report/demo.phase-1.unit-1.task-T1.developer-report@v1#full-regression"
    },
    "static_analysis": {
      "lint": {
        "status": "PASS",
        "evidence_ref": "artifact://developer-report/demo.phase-1.unit-1.task-T1.developer-report@v1#lint"
      },
      "type_check": {
        "status": "PASS",
        "evidence_ref": "artifact://developer-report/demo.phase-1.unit-1.task-T1.developer-report@v1#type-check"
      },
      "build": {
        "status": "PASS",
        "evidence_ref": "artifact://developer-report/demo.phase-1.unit-1.task-T1.developer-report@v1#build"
      }
    },
    "smoke": {
      "status": "NOT_APPLICABLE",
      "evidence_ref": "artifact://developer-report/demo.phase-1.unit-1.task-T1.developer-report@v1#smoke",
      "reason": "non git commit validation fixture has no service"
    },
    "e2e": {
      "status": "NOT_APPLICABLE",
      "evidence_ref": "artifact://developer-report/demo.phase-1.unit-1.task-T1.developer-report@v1#e2e",
      "reason": "non git commit validation fixture has no browser flow"
    }
  },
  "fresh_proof": {
    "current_evidence_refs": [
      "artifact://developer-report/demo.phase-1.unit-1.task-T1.developer-report@v1#fresh-proof-current-output"
    ],
    "proving_commands": [
      {
        "command": "bash tests/demo.test.ts",
        "current_output_ref": "artifact://developer-report/demo.phase-1.unit-1.task-T1.developer-report@v1#fresh-proof-current-output",
        "result": "PASS"
      }
    ]
  }
}
EOF

  cat > "$transcript" <<'EOF'
Write docs/demo/phase-1/unit-1/tasks/T1/developer-report.json
EOF

  prepare_runtime_context "$report"
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

run_developer_report_gate() {
  local report="$1" session_id="$2" stdout_file="$3" stderr_file="$4"
  local transcript payload rc

  prepare_runtime_context "$report"
  transcript="$(mktemp "${TMPDIR:-/tmp}/developer-canonical.transcript.XXXXXX")"
  printf 'Write %s\n' "${report#"$ROOT"/}" > "$transcript"
  payload="$(jq -nc \
    --arg cwd "$ROOT" \
    --arg sid "$session_id" \
    --arg tp "$transcript" \
    --arg fp "${report#"$ROOT"/}" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp, tool_name:"Write", tool_input:{file_path:$fp}}')"

  if bash "$ROOT/shared/skills/developer/scripts/completion_check.sh" >"$stdout_file" 2>"$stderr_file" <<<"$payload"; then
    rc=0
  else
    rc=$?
  fi
  rm -f "$transcript"
  return "$rc"
}

prepare_runtime_context() {
  local report="$1"
  local phase_dir unit_dir

  unit_dir="$(dirname "$(dirname "$(dirname "$report")")")"
  phase_dir="$(dirname "$unit_dir")"
  mkdir -p "$phase_dir"
  jq -n '{artifact_type:"design", artifact_id:"developer-runtime-test.design", schema_version:"1.0.0"}' \
    > "$phase_dir/design.json"
  jq -n --slurpfile report "$report" '
    $report[0] as $r
    | {
        artifact_type: "tasks",
        artifact_id: "developer-runtime-test.tasks",
        schema_version: "1.0.0",
        active_plan_version_ref: $r.active_plan_version_ref,
        active_tasks_version_ref: $r.active_tasks_version_ref,
        tasks: [
          {
            task_id: $r.task_id,
            design_refs: [],
            test_refs: (($r.tdd_evidence_index // []) | map(.ac_refs[]?) | unique)
          }
        ]
      }
  ' > "$phase_dir/tasks.json"
  jq -n --slurpfile report "$report" '
    {
      artifact_type: "test-cases",
      artifact_id: "developer-runtime-test.test-cases",
      schema_version: "1.0.0",
      ac_coverage_matrix: (($report[0].tdd_evidence_index // [])
        | map(.ac_refs[]? | split("#")[-1])
        | unique
        | map({ac_id: .})),
      test_cases: []
    }
  ' > "$unit_dir/test-cases.json"
  jq -n --slurpfile report "$report" '
    def parts($ref):
      ($ref | capture("^artifact://(?<artifact_type>[^/]+)/(?<artifact_id>[^@]+)@(?<version>[^#]+)#(?<anchor>.+)$"));
    def artifact_path($p):
      if $p.artifact_type == "plan" then "plan.json"
      elif $p.artifact_type == "tasks" then "tasks.json"
      elif $p.artifact_type == "design" then "design.json"
      elif $p.artifact_type == "test-cases" then "unit-1/test-cases.json"
      else "artifacts/" + $p.artifact_type + "/" + $p.artifact_id + "@" + $p.version + ".json"
      end;
    $report[0] as $r
    | [
        $r.active_plan_version_ref,
        $r.active_tasks_version_ref,
        (($r.tdd_evidence_index // [])[]?.ac_refs[]?)
      ]
    | map(select(type == "string" and length > 0))
    | unique
    | map(parts(.) as $p | {
        scope_ref: "artifact://phase-prd/developer-runtime-test.phase-1.prd@v1#phase-goal",
        artifact_id: $p.artifact_id,
        artifact_type: $p.artifact_type,
        version: $p.version,
        artifact_path: artifact_path($p),
        lifecycle_state: "FINALIZED",
        active_for_consumption: true,
        produced_by: "test-fixture",
        restore_basis_refs: []
      })
    | {
        artifact_type: "artifact-registry",
        artifact_id: "developer-runtime-test.artifact-registry",
        schema_version: "1.0.0",
        producer: "delivery-owner",
        produced_at: "2026-04-28T00:00:00Z",
        chain_version: "standard-chain/v1",
        chain_registry_digest: "sha256:306668c17650b323b74a7d4aa616b029e8c2b17ee9bd960f15f89321bffc8bd3",
        authority_scope: "phase",
        scope_ref: "artifact://phase-prd/developer-runtime-test.phase-1.prd@v1#phase-goal",
        registry_revision: "rev-1",
        active_revision_id: "rev-1",
        revisions: [
          {
            revision_id: "rev-1",
            appended_at: "2026-04-28T00:00:00Z",
            entries: .
          }
        ]
      }
  ' > "$phase_dir/artifact-registry.json"
}

assert_canonical_json_report_passes() {
  local tmp_feature report stdout_file stderr_file rc

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

  if run_developer_report_gate "$report" "session-developer-canonical-json" "$stdout_file" "$stderr_file"; then
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
  local tmp_feature report stdout_file stderr_file output_file rc

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

  if run_developer_report_gate "$report" "session-developer-canonical-negative" "$stdout_file" "$stderr_file"; then
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

assert_canonical_json_report_accepts_mutation() {
  local label="$1"
  local jq_filter="$2"
  local tmp_feature report stdout_file stderr_file rc

  tmp_feature="$(mktemp -d "$ROOT/docs/developer-canonical-positive.XXXXXX")"
  stdout_file="$(mktemp "${TMPDIR:-/tmp}/developer-canonical-positive.stdout.XXXXXX")"
  stderr_file="$(mktemp "${TMPDIR:-/tmp}/developer-canonical-positive.stderr.XXXXXX")"

  cleanup_canonical_positive_fixture() {
    rm -rf "$tmp_feature" "$stdout_file" "$stderr_file"
  }
  trap cleanup_canonical_positive_fixture RETURN

  mkdir -p "$tmp_feature/phase-1/unit-1/tasks/T1"
  report="$tmp_feature/phase-1/unit-1/tasks/T1/developer-report.json"
  jq "$jq_filter" \
    "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json" \
    > "$report"

  if run_developer_report_gate "$report" "session-developer-canonical-positive" "$stdout_file" "$stderr_file"; then
    rc=0
  else
    rc=$?
  fi

  if [ "$rc" -ne 0 ]; then
    cat "$stdout_file" "$stderr_file" >&2
    fail "developer gate 应接受 canonical developer-report.json：$label"
    return
  fi

  pass "developer gate 接受 canonical developer-report.json：$label"
}

assert_developer_manifest_contract() {
  local registry="$ROOT/shared/hooks/registry.json"
  local manifest="$ROOT/shared/skills/developer/scripts/manifest.json"

  if python3 - "$manifest" "$registry" <<'PY'; then
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
registry = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
scripts = [item for item in manifest["scripts"] if item.get("id") == "completion-check"]
if len(scripts) != 1:
    raise SystemExit("developer manifest must have exactly one completion-check script")
script = scripts[0]
entries = [item for item in registry["skill_completion_gates"] if item.get("skill") == "developer"]
if len(entries) != 1:
    raise SystemExit("developer registry must have exactly one entry")
entry = entries[0]
expected_handler = f"skills/developer/{script['path']}"
if entry.get("handler_rel") != expected_handler:
    raise SystemExit("developer registry and manifest drift on handler_rel")
if entry.get("codex", {}).get("supported") is not True:
    raise SystemExit("developer registry must enable codex hook dispatch")
if entry.get("claude", {}).get("event") != "Stop":
    raise SystemExit("developer registry must bind claude Stop hook")
comparisons = {
    "owner": "owner",
    "allowed_args": "allowed_args",
    "output_root": "output_root",
    "failure_state": "failure_state",
}
for registry_field, manifest_field in comparisons.items():
    if entry.get(registry_field) != script.get(manifest_field):
        raise SystemExit(f"developer registry and manifest drift on {registry_field}")
if entry.get("timeout_sec") != script.get("timeout_seconds"):
    raise SystemExit("developer registry and manifest drift on timeout")
PY
    pass "developer registry 声明唯一 handler/owner/args/timeout/output/failure_state"
  else
    fail "developer registry 缺少唯一 handler/owner/args/timeout/output/failure_state"
  fi

  if jq -e '
    .scripts[]
    | select(.id == "completion-check")
    | .owner == "developer"
      and .timeout_seconds == 30
      and .failure_state == "DEVELOPER_COMPLETION_GATE_FAILED"
      and .verification_command == "bash tests/test-developer-contract-alignment.sh && bash tests/test-developer-runtime-failure-matrix.sh"
      and (.allowed_args | index("--help") != null)
      and (.allowed_args | index("-h") != null)
      and (.allowed_output_roots | index("/tmp") != null)
  ' "$manifest" >/dev/null 2>&1; then
    pass "developer manifest 声明 owner/args/timeout/output/failure_state/verification"
  else
    fail "developer manifest 缺少 owner/args/timeout/output/failure_state/verification"
  fi

  if jq -e '
    .scripts[]
    | select(.id == "preflight-check")
    | .owner == "developer"
      and .timeout_seconds == 15
      and .failure_state == "DEVELOPER_PREFLIGHT_FAILED"
      and (.allowed_args | index("--phase-dir") != null)
      and (.allowed_args | index("--task-id") != null)
  ' "$manifest" >/dev/null 2>&1; then
    pass "developer manifest 声明 preflight-check 入口"
  else
    fail "developer manifest 缺少 preflight-check 入口"
  fi
}

assert_developer_preflight_passes() {
  local tmp_root phase_dir out

  tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/developer-preflight.XXXXXX")"
  out="$(mktemp "${TMPDIR:-/tmp}/developer-preflight.out.XXXXXX")"
  cleanup_developer_preflight_pass() {
    rm -rf "$tmp_root" "$out"
  }
  trap cleanup_developer_preflight_pass RETURN

  mkdir -p "$tmp_root"
  cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1" "$tmp_root/phase-1"
  phase_dir="$tmp_root/phase-1"

  if bash "$ROOT/shared/skills/developer/scripts/preflight_check.sh" --phase-dir "$phase_dir" --task-id T1 >"$out"; then
    if rg -n '"status": "PASS".*"task_id": "T1"|\"task_id\": \"T1\".*\"status\": \"PASS\"' "$out" >/dev/null 2>&1; then
      pass "developer preflight 接受完整 Task 输入"
    else
      fail "developer preflight 输出缺少 PASS/T1"
    fi
  else
    cat "$out" >&2 || true
    fail "developer preflight 应接受完整 Task 输入"
  fi
}

assert_developer_preflight_blocks_missing_registry() {
  local tmp_root phase_dir out

  tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/developer-preflight.XXXXXX")"
  out="$(mktemp "${TMPDIR:-/tmp}/developer-preflight.out.XXXXXX")"
  cleanup_developer_preflight_block() {
    rm -rf "$tmp_root" "$out"
  }
  trap cleanup_developer_preflight_block RETURN

  mkdir -p "$tmp_root"
  cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1" "$tmp_root/phase-1"
  phase_dir="$tmp_root/phase-1"
  rm -f "$phase_dir/artifact-registry.json"

  if bash "$ROOT/shared/skills/developer/scripts/preflight_check.sh" --phase-dir "$phase_dir" --task-id T1 >"$out"; then
    fail "developer preflight 应阻断缺失 artifact-registry.json"
  elif rg -n '"failure_code": "MISSING_INPUT"|artifact-registry\.json' "$out" >/dev/null 2>&1; then
    pass "developer preflight 阻断缺失 artifact-registry.json"
  else
    cat "$out" >&2 || true
    fail "developer preflight 阻断输出缺少 MISSING_INPUT"
  fi
}

DEV_SKILL="$ROOT/shared/skills/developer/SKILL.md"
DEV_AGENT="$ROOT/shared/agents/developer.md"
DEV_SELF_TEST="$ROOT/shared/skills/developer/references/self-testing-methodology.md"
DEV_SELF_REVIEW="$ROOT/shared/skills/developer/references/self-review-methodology.md"
DEV_CHECK="$ROOT/shared/skills/developer/scripts/completion_check.sh"
DEV_PREFLIGHT="$ROOT/shared/skills/developer/scripts/preflight_check.sh"

assert_allowed_tools_exact \
  "developer SKILL 声明实现型 allowed-tools" \
  "$DEV_SKILL" \
  "Read,Write,Edit,Bash,Glob,Grep,LSP"

assert_present \
  "developer SKILL 保留 HARD-GATE" \
  '^## HARD-GATE$' \
  "$DEV_SKILL"

assert_present \
  "developer SKILL 聚焦 Task 实现 owner" \
  'Task 实现 owner' \
  "$DEV_SKILL"

assert_present \
  "developer SKILL 使用输入识别而不是前置条件表" \
  '^## 输入识别$' \
  "$DEV_SKILL"

assert_present \
  "developer SKILL 默认输出 developer-report" \
  '默认输出是当前 Task 的 `developer-report\.json`' \
  "$DEV_SKILL"

assert_present \
  "developer SKILL 要求对话回复不能替代报告" \
  '对话回复只摘要报告路径、变更、验证结果和风险，不能替代报告' \
  "$DEV_SKILL"

assert_present \
  "developer SKILL 缺报告路径时阻断补派发信息" \
  '缺少报告路径时，先停止并要求补齐派发信息' \
  "$DEV_SKILL"

assert_absent \
  "developer SKILL 不承载 hook/gate 调用说明" \
  'hooks 运行面|shared/hooks/registry\.json|developer entry|completion gate|shared/skills/developer/scripts/completion_check\.sh|hook payload|gate validator|gate 结果' \
  "$DEV_SKILL"

assert_present \
  "developer SKILL 标明 preflight 输入校验入口" \
  'shared/skills/developer/scripts/preflight_check\.sh --phase-dir "\$PHASE_DIR" --task-id "\$TASK_ID"' \
  "$DEV_SKILL"

assert_present \
  "developer SKILL 限定 preflight 为输入校验" \
  '只校验 Task、Scope、design/test refs 和 `assertion_target`；失败则停止' \
  "$DEV_SKILL"

test -x "$DEV_PREFLIGHT" || fail "developer preflight script must be executable"

assert_present \
  "developer SKILL 使用流程支撑可执行步骤" \
  '^## 流程$' \
  "$DEV_SKILL"

assert_present \
  "developer SKILL 流程图命名为 developer_flow" \
  'digraph developer_flow' \
  "$DEV_SKILL"

assert_present \
  "developer SKILL 将 test-cases 作为 TDD 输入而非运行面 gate" \
  'test-cases\.json.*test_refs.*assertion_target' \
  "$DEV_SKILL"

assert_present \
  "developer SKILL 发现 design.json 范围外需求时停止" \
  '需要改 `design\.json`.*先停止|design\.json.*范围外' \
  "$DEV_SKILL"

assert_present \
  "developer agent 保持极薄角色启动语" \
  '^你是 developer。' \
  "$DEV_AGENT"

assert_present \
  "developer agent 只承接单个 Task" \
  '单个 Task' \
  "$DEV_AGENT"

assert_absent \
  "developer SKILL 不再要求读取 MOD markdown 投影" \
  'design/MOD-\*\.md|MOD 文档' \
  "$DEV_SKILL"

assert_absent \
  "developer SKILL 不再承载 runtime-layering 标准正文" \
  '^## Runtime Layering Contract$|Runtime Inputs And Authority|^## 流程合规输出合同$|^## 失败路由合同$' \
  "$DEV_SKILL"

assert_absent \
  "developer SKILL 不再新增独立工具边界章节" \
  '^## 工具边界$' \
  "$DEV_SKILL"

assert_absent \
  "developer SKILL 不再新增前置条件章节" \
  '^## 前置条件$' \
  "$DEV_SKILL"

assert_absent \
  "developer SKILL 不再把派发物存在性写成 LLM 职责说明" \
  '只用于理解 AC|常用证据组包括|projections/developer-report-template\.md|你不负责：|scope registry|worklog\.md|canonical: active refs|确定性 preflight' \
  "$DEV_SKILL"

assert_absent \
  "developer SKILL 不再保留流程状态表" \
  '^### 流程状态表$' \
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

assert_present \
  "self-review 标题修正为 7 维度" \
  '^## 7 维度结构化自审$' \
  "$DEV_SELF_REVIEW"

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
assert_canonical_json_report_rejects_mutation \
  "某 AC 缺 RED" \
  'del(.tdd_evidence_index[0])' \
  '每个 AC.*RED FAIL_EXPECTED.*GREEN PASS|RED.*FAIL_EXPECTED'
assert_canonical_json_report_rejects_mutation \
  "某 AC 缺 GREEN" \
  'del(.tdd_evidence_index[1])' \
  '每个 AC.*RED FAIL_EXPECTED.*GREEN PASS|GREEN.*PASS'
assert_canonical_json_report_rejects_mutation \
  "RED/GREEN AC 集合不一致" \
  '.tdd_evidence_index[1].ac_refs = ["artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-OTHER"]' \
  '每个 AC.*RED FAIL_EXPECTED.*GREEN PASS'
assert_canonical_json_report_rejects_mutation \
  "缺 self_testing" \
  'del(.self_testing)' \
  'self_testing|canonical schema validation failed'
assert_canonical_json_report_rejects_mutation \
  "缺 full regression 证据" \
  'del(.self_testing.full_regression)' \
  'full_regression|canonical schema validation failed'
assert_canonical_json_report_rejects_mutation \
  "缺 static analysis 证据" \
  'del(.self_testing.static_analysis.build)' \
  'static_analysis|canonical schema validation failed'
assert_canonical_json_report_rejects_mutation \
  "缺 fresh proof 证据" \
  'del(.fresh_proof)' \
  'fresh_proof|canonical schema validation failed'
assert_canonical_json_report_rejects_mutation \
  "fresh proof 只有命令字符串" \
  'del(.fresh_proof.current_evidence_refs) | .fresh_proof.proving_commands[0].current_output_ref = ""' \
  'fresh_proof|current_output_ref|canonical schema validation failed'
assert_canonical_json_report_rejects_mutation \
  "VERIFIED 不允许空 file_changes" \
  '.file_changes = []' \
  'VERIFIED.*file_changes|canonical schema validation failed'
assert_canonical_json_report_rejects_mutation \
  "VERIFIED 不允许 file_changes 超出 developer task_scope" \
  '.file_changes = ["src/outside.ts"]' \
  'OUT_OF_SCOPE_CHANGE|outside task scope|范围外'
assert_canonical_json_report_rejects_mutation \
  "BLOCKED 缺阻断原因" \
  '.runtime_status = "BLOCKED" | .task_scope = [] | .file_changes = [] | del(.blocked_reason) | del(.missing_inputs)' \
  'BLOCKED.*blocked_reason|canonical schema validation failed'
assert_canonical_json_report_accepts_mutation \
  "BLOCKED 允许空 scope 和 file_changes 且有阻断信息" \
  '.runtime_status = "BLOCKED" | .task_scope = [] | .file_changes = [] | .blocked_reason = "canonical inputs are missing" | .missing_inputs = ["design.json"] | .failure_contract = {"status":"BLOCKED","failure_code":"MISSING_INPUT","reason":"canonical inputs are missing","owner":"delivery-owner","safe_to_continue":false,"next_action":"redispatch with canonical inputs","evidence_refs":["artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#blocked"],"user_message":"缺少 developer 前置输入，已阻断真实代码修改。"} | .self_testing.full_regression.status = "BLOCKED" | .self_testing.full_regression.reason = "canonical inputs are missing" | .self_testing.static_analysis.lint.status = "BLOCKED" | .self_testing.static_analysis.lint.reason = "canonical inputs are missing" | .self_testing.static_analysis.type_check.status = "BLOCKED" | .self_testing.static_analysis.type_check.reason = "canonical inputs are missing" | .self_testing.static_analysis.build.status = "BLOCKED" | .self_testing.static_analysis.build.reason = "canonical inputs are missing" | .tdd_evidence_index = []'
assert_developer_manifest_contract
assert_developer_preflight_passes
assert_developer_preflight_blocks_missing_registry

printf '\n── Summary ──\n'
printf 'PASS: %d  FAIL: %d\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
