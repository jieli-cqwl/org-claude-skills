#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

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
  if rg -n "$pattern" "$file" >/tmp/org_skill_gate_absent.out 2>&1; then
    cat /tmp/org_skill_gate_absent.out >&2
    fail "unexpected pattern in ${file#"$ROOT"/}: $pattern"
  fi
}

assert_json_ok() {
  local file="$1"
  jq empty "$file" >/dev/null 2>&1 || fail "invalid JSON: ${file#"$ROOT"/}"
}

assert_completion_gate_registry_manifest_alignment() {
  python3 - "$ROOT" <<'PY' || fail "skill completion gate registry must mirror manifests"
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
registry = json.loads((root / "shared/hooks/registry.json").read_text(encoding="utf-8"))
failures = []
raw_entries = registry.get("skill_completion_gates", [])
if not isinstance(raw_entries, list):
    raise SystemExit("skill_completion_gates must be an array")

entries = {}
for index, entry in enumerate(raw_entries):
    if not isinstance(entry, dict):
        failures.append(f"registry[{index}]: entry must be an object")
        continue
    skill = entry.get("skill")
    if not isinstance(skill, str) or not skill:
        failures.append(f"registry[{index}]: skill is required")
        continue
    if skill in entries:
        failures.append(f"{skill}: duplicate registry entry")
        continue
    entries[skill] = entry
    for field in (
        "handler_rel",
        "timeout_sec",
        "owner",
        "allowed_args",
        "output_root",
        "failure_state",
    ):
        if field not in entry:
            failures.append(f"{skill}: registry missing {field}")
    if entry.get("owner") != skill:
        failures.append(f"{skill}: registry owner must match skill")
    if not isinstance(entry.get("allowed_args"), list) or not entry.get("allowed_args"):
        failures.append(f"{skill}: registry allowed_args must be a non-empty array")
    handler_rel = entry.get("handler_rel")
    if isinstance(handler_rel, str):
        handler_path = root / "shared" / handler_rel
        if not handler_path.is_file():
            failures.append(f"{skill}: registry handler does not exist: {handler_rel}")
    manifest_path = root / "shared" / "skills" / skill / "scripts" / "manifest.json"
    if not manifest_path.is_file():
        failures.append(f"{skill}: registry completion gate requires scripts/manifest.json")

for manifest_path in sorted((root / "shared/skills").glob("*/scripts/manifest.json")):
    skill = manifest_path.parts[-3]
    skill_file = manifest_path.parent.parent / "SKILL.md"
    if skill_file.is_file():
        skill_text = skill_file.read_text(encoding="utf-8", errors="ignore")
        parts = skill_text.split("---", 2)
        frontmatter = parts[1] if skill_text.startswith("---") and len(parts) > 2 else ""
        if "user-invocable: false" in frontmatter:
            continue
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    scripts = manifest.get("scripts")
    if not isinstance(scripts, list):
        continue
    completion_scripts = [
        item
        for item in scripts
        if isinstance(item, dict)
        and (item.get("path") == "scripts/completion_check.sh" or item.get("id") == "completion-check")
    ]
    if not completion_scripts:
        continue
    if len(completion_scripts) != 1:
        failures.append(f"{skill}: manifest must have exactly one completion script")
        continue
    script = completion_scripts[0]
    entry = entries.get(skill)
    if not entry:
        failures.append(f"{skill}: registry entry missing")
        continue
    expected_handler = f"skills/{skill}/{script.get('path')}"
    checks = {
        "handler_rel": (entry.get("handler_rel"), expected_handler),
        "owner": (entry.get("owner"), script.get("owner")),
        "allowed_args": (entry.get("allowed_args"), script.get("allowed_args")),
        "failure_state": (entry.get("failure_state"), script.get("failure_state")),
        "timeout": (entry.get("timeout_sec"), script.get("timeout_seconds")),
        "output_root": (entry.get("output_root"), script.get("output_root")),
    }
    for field in ("owner", "allowed_args", "output_root", "failure_state", "timeout_seconds"):
        if field not in script:
            failures.append(f"{skill}: manifest completion script missing {field}")
    if script.get("owner") != skill:
        failures.append(f"{skill}: manifest owner must match skill")
    if not isinstance(script.get("allowed_args"), list) or not script.get("allowed_args"):
        failures.append(f"{skill}: manifest allowed_args must be a non-empty array")
    for field, (actual, expected) in checks.items():
        if actual != expected:
            failures.append(f"{skill}: {field} drift registry={actual!r} manifest={expected!r}")
if failures:
    raise SystemExit("\n".join(failures))
PY
}

assert_completion_gate_handlers_help() {
  python3 - "$ROOT" <<'PY' || fail "skill completion gate handlers must support bash --help"
import json
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
registry = json.loads((root / "shared/hooks/registry.json").read_text(encoding="utf-8"))
failures = []
for entry in registry.get("skill_completion_gates", []):
    if not isinstance(entry, dict):
        continue
    skill = entry.get("skill")
    handler_rel = entry.get("handler_rel")
    if not isinstance(skill, str) or not isinstance(handler_rel, str):
        continue
    handler_path = root / "shared" / handler_rel
    result = subprocess.run(
        ["bash", str(handler_path), "--help"],
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=5,
    )
    if result.returncode != 0:
        failures.append(
            f"{skill}: bash {handler_rel} --help exited {result.returncode}; "
            f"stdout={result.stdout[:120]!r}; stderr={result.stderr[:120]!r}"
        )
if failures:
    raise SystemExit("\n".join(failures))
PY
}

assert_completion_gate_handlers_syntax() {
  python3 - "$ROOT" <<'PY' || fail "skill completion gate handlers must pass bash syntax check"
import json
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
registry = json.loads((root / "shared/hooks/registry.json").read_text(encoding="utf-8"))
failures = []
for entry in registry.get("skill_completion_gates", []):
    if not isinstance(entry, dict):
        continue
    skill = entry.get("skill")
    handler_rel = entry.get("handler_rel")
    if not isinstance(skill, str) or not isinstance(handler_rel, str):
        continue
    result = subprocess.run(
        ["bash", "-n", str(root / "shared" / handler_rel)],
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=5,
    )
    if result.returncode != 0:
        failures.append(
            f"{skill}: bash -n {handler_rel} exited {result.returncode}; "
            f"stdout={result.stdout[:120]!r}; stderr={result.stderr[:120]!r}"
        )
if failures:
    raise SystemExit("\n".join(failures))
PY
}

assert_hook_registry_renderable() {
  local rendered
  rendered="$(mktemp "${TMPDIR:-/tmp}/rendered-hooks.XXXXXX")"
  python3 "$ROOT/tools/community/render_hook_registry.py" codex-hooks \
    --registry "$ROOT/shared/hooks/registry.json" \
    --runtime-home /tmp/runtime > "$rendered" || fail "hook registry must render for Codex"
  jq empty "$rendered" >/dev/null 2>&1 || fail "rendered Codex hook registry must be valid JSON"
  rm -f "$rendered"
}

run_hook() {
  local script="$1"
  local workspace="$2"
  local session_id="$3"
  local transcript_entries="$4"
  local tool_name="${5:-}"
  local file_path="${6:-}"
  local payload_cwd="${7:-$workspace}"
  local transcript_path="$workspace/transcript.log"
  local payload status

  printf '%b' "$transcript_entries" > "$transcript_path"
  payload="$(jq -nc \
    --arg cwd "$payload_cwd" \
    --arg sid "$session_id" \
    --arg tp "$transcript_path" \
    --arg tn "$tool_name" \
    --arg fp "$file_path" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp}
      + (if $tn == "" then {} else {tool_name:$tn} end)
      + (if $fp == "" then {} else {tool_input:{file_path:$fp}} end)')"

  if (cd "$payload_cwd" && bash "$script" <<<"$payload") >"$workspace/hook.stdout" 2>"$workspace/hook.stderr"; then
    status=0
  else
    status=$?
  fi
  printf '%s\n' "$status" > "$workspace/hook.status"
}

assert_hook_passed() {
  local workspace="$1"
  local label="$2"
  local status
  status="$(cat "$workspace/hook.status")"
  if [ "$status" != "0" ]; then
    cat "$workspace/hook.stderr" >&2
    fail "$label failed with exit $status"
  fi
  jq -e '.decision == "allow"' "$workspace/hook.stdout" >/dev/null 2>&1 || {
    cat "$workspace/hook.stdout" >&2
    cat "$workspace/hook.stderr" >&2
    fail "$label did not emit allow decision"
  }
}

prepare_workspace() {
  local workspace="$1"
  mkdir -p "$workspace/docs"
  cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$workspace/docs/sample-feature"
}

prepare_git_trace_workspace() {
  local workspace="$1"
  local object_dir

  object_dir="$(git -C "$ROOT" rev-parse --path-format=absolute --git-path objects)"
  (cd "$workspace" && git init -q)
  mkdir -p "$workspace/.git/objects/info"
  printf '%s\n' "$object_dir" > "$workspace/.git/objects/info/alternates"
}

prepare_director_workspace() {
  local workspace="$1"
  prepare_workspace "$workspace"
  mv "$workspace/docs/sample-feature" "$workspace/docs/director-feature"

  jq '
    del(.acceptance_criteria, .design_decisions, .non_functional_requirements, .review_conclusion, .issue_ledger, .delivery_confirmation)
    | .authoritative_fields = ["$.root_problem", "$.user_profile", "$.business_goals", "$.appetite", "$.scope_boundaries", "$.non_goals", "$.feasibility_constraints", "$.risks_and_unknowns", "$.decision_rationale", "$.delivery_plan", "$.director_confirmation"]
  ' "$workspace/docs/director-feature/brief.json" > "$workspace/docs/director-feature/brief.tmp.json"
  mv "$workspace/docs/director-feature/brief.tmp.json" "$workspace/docs/director-feature/brief.json"

  jq '
    .unit_index = []
    | del(.review_conclusion, .issue_ledger, .business_flows, .user_paths, .rule_mappings, .design_decision_candidates)
    | .authoritative_fields = ["$.phase_goal", "$.entry_conditions", "$.exit_conditions", "$.director_confirmation"]
  ' "$workspace/docs/director-feature/phase-1/phase-prd.json" > "$workspace/docs/director-feature/phase-1/phase-prd.tmp.json"
  mv "$workspace/docs/director-feature/phase-1/phase-prd.tmp.json" "$workspace/docs/director-feature/phase-1/phase-prd.json"
}

prepare_director_pm_polluted_workspace() {
  local workspace="$1"
  prepare_director_workspace "$workspace"

  jq '
    .business_flows = ["PM-owned business flow should not appear in Director output"]
    | .user_paths = ["PM-owned user path should not appear in Director output"]
    | .rule_mappings = ["PM-owned rule mapping should not appear in Director output"]
    | .design_decision_candidates = []
  ' "$workspace/docs/director-feature/phase-1/phase-prd.json" > "$workspace/docs/director-feature/phase-1/phase-prd.tmp.json"
  mv "$workspace/docs/director-feature/phase-1/phase-prd.tmp.json" "$workspace/docs/director-feature/phase-1/phase-prd.json"
}

prepare_director_missing_artifact_type_workspace() {
  local workspace="$1"
  prepare_director_workspace "$workspace"

  jq 'del(.artifact_type)' \
    "$workspace/docs/director-feature/brief.json" > "$workspace/docs/director-feature/brief.tmp.json"
  mv "$workspace/docs/director-feature/brief.tmp.json" "$workspace/docs/director-feature/brief.json"
}

prepare_director_template_workspace() {
  local workspace="$1"
  mkdir -p "$workspace/docs/director-template-feature/phase-1"
  cp "$ROOT/shared/skills/product-director/templates/brief.template.json" \
    "$workspace/docs/director-template-feature/brief.json"
  cp "$ROOT/shared/skills/product-director/templates/phase-prd.template.json" \
    "$workspace/docs/director-template-feature/phase-1/phase-prd.json"
}

prepare_manager_unit_placeholder_workspace() {
  local workspace="$1"
  prepare_workspace "$workspace"

  jq '
    .integration_context.business_modules[0] = "tbd"
    | .acceptance_criteria[0].example_input = "todo"
    | .verification_plan[0].business_operation = "n/a"
  ' "$workspace/docs/sample-feature/phase-1/units/UNIT-1.json" > "$workspace/docs/sample-feature/phase-1/units/UNIT-1.tmp.json"
  mv "$workspace/docs/sample-feature/phase-1/units/UNIT-1.tmp.json" "$workspace/docs/sample-feature/phase-1/units/UNIT-1.json"
}

assert_standard_chain_control_contract() {
  assert_present 'phase_delivery_owner: delivery-owner' "$ROOT/contracts/standard-chain.yaml"
  assert_present 'sidecar_dispatch' "$ROOT/contracts/standard-chain.yaml"
  assert_present 'consistency-auditor' "$ROOT/contracts/standard-chain.yaml"
  assert_present 'decision_authority: advisory_only' "$ROOT/contracts/standard-chain.yaml"
  assert_absent 'gate_escalation' "$ROOT/contracts/standard-chain.yaml"

  assert_present '# /delivery-owner -- 交付负责人' "$ROOT/shared/skills/delivery-owner/SKILL.md"
  assert_present '接手 `tech-lead` 已冻结的 plan/tasks' "$ROOT/shared/skills/delivery-owner/SKILL.md"
  assert_present '交付视角 review' "$ROOT/shared/skills/delivery-owner/SKILL.md"
  assert_present '开发/验证或 QA/修复达到 10 轮' "$ROOT/shared/skills/delivery-owner/SKILL.md"
  assert_present '调度 `/commit`' "$ROOT/shared/skills/delivery-owner/SKILL.md"
  assert_present '用户是决策方' "$ROOT/shared/skills/delivery-owner/SKILL.md"
  assert_present 'artifact-registry.json' "$ROOT/shared/skills/delivery-owner/SKILL.md"
  assert_present 'references/followup-loops.md' "$ROOT/shared/skills/delivery-owner/SKILL.md"
  assert_absent 'signoff_ready|control_decision_check|gap_delta|rebaseline_needed' "$ROOT/shared/skills/delivery-owner/SKILL.md"

  assert_present 'planning owner' "$ROOT/shared/skills/tech-lead/SKILL.md"
  assert_present 'Task 实现 owner' "$ROOT/shared/skills/developer/SKILL.md"
  assert_present '独立质量判断 owner' "$ROOT/shared/skills/qa/SKILL.md"
  assert_present 'Manager 阶段评审闭环只写入 `brief\.json\.review_conclusion / issue_ledger`' "$ROOT/shared/skills/product-manager/references/review-orchestration.md"
  assert_absent 'product-manager-review\.md' "$ROOT/shared/skills/product-manager/references/review-orchestration.md"
}

assert_canonical_runtime_artifacts() {
  local file
  for file in \
    "$ROOT/shared/skills/product-director/templates/brief.template.json" \
    "$ROOT/shared/skills/product-director/templates/phase-prd.template.json" \
    "$ROOT/shared/skills/developer/contracts/developer-report.schema.json" \
    "$ROOT/shared/skills/verify/contracts/verify-result.schema.json" \
    "$ROOT/shared/skills/review/contracts/code-review-result.schema.json" \
    "$ROOT/shared/skills/qa/contracts/qa-result.schema.json" \
    "$ROOT/shared/skills/consistency-audit/contracts/consistency-audit-result.schema.json" \
    "$ROOT/shared/skills/fix/contracts/fix-result.schema.json" \
    "$ROOT/shared/skills/developer/templates/developer-report.template.json" \
    "$ROOT/shared/skills/verify/templates/verify-result.template.json" \
    "$ROOT/shared/skills/review/templates/code-review-result.template.json" \
    "$ROOT/shared/skills/qa/templates/qa-result.template.json" \
    "$ROOT/shared/skills/consistency-audit/templates/consistency-audit-result.template.json" \
    "$ROOT/shared/skills/fix/templates/fix-result.template.json"; do
    assert_json_ok "$file"
  done

  assert_present 'consistency-audit-result' "$ROOT/shared/runtime/standard-chain-catalog.json"
  assert_present 'active_plan_version_ref' "$ROOT/shared/skills/developer/contracts/developer-report.schema.json"
  assert_present 'active_tasks_version_ref' "$ROOT/shared/skills/qa/contracts/qa-result.schema.json"
  assert_present 'backward_compatibility' "$ROOT/shared/skills/review/contracts/code-review-result.schema.json"
  assert_present 'backward_compatibility' "$ROOT/shared/skills/review/templates/code-review-result.template.json"
  assert_present 'references/output\.md' "$ROOT/shared/skills/product-director/SKILL.md"
  assert_absent 'references/output\.md#' "$ROOT/shared/skills/product-director/SKILL.md"
  assert_present 'shared/skills/product-director/templates/brief.template.json' "$ROOT/shared/skills/product-director/references/output.md"
  assert_present 'shared/skills/product-director/templates/phase-prd.template.json' "$ROOT/shared/skills/product-director/references/output.md"
  assert_present 'artifact_type' "$ROOT/shared/skills/product-director/references/output.md"
  assert_present 'chain_registry_digest' "$ROOT/shared/skills/product-director/references/output.md"
  assert_present 'locked_field_digest' "$ROOT/shared/skills/product-director/references/output.md"
  assert_absent '历史 product-artifact 兼容校验' "$ROOT/shared/skills/product-director/SKILL.md"
}

assert_canonical_only_scripts() {
  local script
  for script in \
    "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$ROOT/shared/skills/product-manager/scripts/completion_check.sh" \
    "$ROOT/shared/skills/design/scripts/completion_check.sh" \
    "$ROOT/shared/skills/test-design/scripts/completion_check.sh" \
    "$ROOT/shared/skills/tech-lead/scripts/completion_check.sh" \
    "$ROOT/shared/skills/developer/scripts/completion_check.sh" \
    "$ROOT/shared/skills/review/scripts/completion_check.sh" \
    "$ROOT/shared/skills/qa/scripts/completion_check.sh"; do
    bash -n "$script"
    assert_present 'canonical' "$script"
    assert_absent 'ORG_ENABLE_LEGACY_MARKDOWN_HOOKS|legacy markdown|brief\.md|prd\.md|design\.md|plan\.md|test-cases\.md|developer-report-Task|qa-report\.md|code-review-report\.md|product-manager-review\.md' "$script"
    assert_absent 'first_matching_hook_path|grep -oE .*head -1|head -1 \|\| true' "$script"
  done
}

assert_tech_lead_runtime_control_contract() {
  local manifest="$ROOT/shared/skills/tech-lead/scripts/manifest.json"
  local registry="$ROOT/shared/hooks/registry.json"
  local skill="$ROOT/shared/skills/tech-lead/SKILL.md"
  local adapter="$ROOT/codex/agents/tech-lead.toml"

  assert_json_ok "$manifest"
  jq -e '
    .scripts[]
    | select(.path == "scripts/completion_check.sh")
    | .owner == "tech-lead"
      and (.allowed_args | index("hook payload via stdin only") != null)
      and .timeout_seconds == 15
      and .output_root == "$TMPDIR|/tmp"
      and .failure_state == "TECH_LEAD_COMPLETION_GATE_FAILED"
      and (.verification_command | contains("tests/test-skill-output-and-gate-contract.sh"))
  ' "$manifest" >/dev/null || fail "tech-lead manifest must define owner, args, timeout, output root, failure state, and proof command"
  jq -e '
    .scripts[]
    | select(.path == "scripts/planning_preflight.py")
    | .owner == "tech-lead"
      and (.allowed_args | index("--phase-dir") != null)
      and (.allowed_args | index("--require-plan-tasks") != null)
      and .failure_state == "TECH_LEAD_PLANNING_PREFLIGHT_BLOCKED"
  ' "$manifest" >/dev/null || fail "tech-lead manifest must define planning preflight contract"

  python3 - "$manifest" "$registry" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
registry = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
script = next(item for item in manifest["scripts"] if item.get("path") == "scripts/completion_check.sh")
entry = next(item for item in registry["skill_completion_gates"] if item.get("skill") == "tech-lead")
required = {"owner", "allowed_args", "output_root", "failure_state"}
missing = sorted(required - set(entry))
if missing:
    raise SystemExit(f"tech-lead registry missing keys: {missing}")
for field in required:
    if entry[field] != script[field]:
        raise SystemExit(f"tech-lead registry and manifest drift on {field}")
PY

  assert_present '^allowed-tools: .*Bash' "$skill"
  assert_present 'planning_preflight.py' "$skill"
  assert_absent 'TeamCreate' "$skill"
  assert_absent 'references/templates/' "$skill"
  assert_present 'projections/plan-template.md' "$skill"
  assert_absent 'projections/design-review-template.md' "$skill"
  [ ! -d "$ROOT/shared/skills/tech-lead/references/templates" ] \
    || fail "tech-lead human projection templates must not live under active references/"
  for projection in \
    "$ROOT/shared/skills/tech-lead/projections/plan-template.md"; do
    assert_present '人类投影视图|运行时真源|机器真源' "$projection"
    assert_absent '^(Trigger|Read|Expect|Consume|Evidence|Sync):' "$projection"
  done
  assert_present '可用工具：Read, Write, Bash, Glob, Grep。' "$adapter"
  assert_absent 'TeamCreate|三名 reviewer' "$adapter"
  assert_absent '禁止使用 Edit, Bash, WebSearch' "$adapter"
}

assert_planning_projection_context_contract() {
  local pm_skill="$ROOT/shared/skills/product-manager/SKILL.md"
  local pm_review="$ROOT/shared/skills/product-manager/references/review-orchestration.md"
  local design_skill="$ROOT/shared/skills/design/SKILL.md"
  local designer_adapter="$ROOT/codex/agents/designer.toml"

  for skill_dir in product-manager design; do
    [ ! -d "$ROOT/shared/skills/$skill_dir/references/templates" ] \
      || fail "$skill_dir human projection templates must not live under active references/"
    [ -d "$ROOT/shared/skills/$skill_dir/projections" ] \
      || fail "$skill_dir projections directory missing"
  done

  for projection in \
    "$ROOT/shared/skills/product-manager/projections/brief-template.md" \
    "$ROOT/shared/skills/product-manager/projections/phase-prd-template.md" \
    "$ROOT/shared/skills/product-manager/projections/product-manager-review-template.md" \
    "$ROOT/shared/skills/design/projections/design-template.md" \
    "$ROOT/shared/skills/design/projections/adr-spec.md"; do
    assert_present '不得作为下游控制输入|不得反向作为 runtime 真源|不作为 runtime 真源|不产生 runtime 事实|不得反向替代 `design\.json`|不替代 `design\.json`' "$projection"
  done

  assert_present '^allowed-tools: .*Bash' "$pm_skill"
  assert_present 'validate_standard_chain_phase.py' "$pm_skill"
  assert_present '^allowed-tools: .*TeamCreate' "$pm_skill"
  assert_present 'TeamCreate 协作团队' "$pm_skill"
  assert_present 'TeamCreate 协作团队' "$pm_review"

  assert_present '^allowed-tools: .*Bash' "$design_skill"
  assert_present '^allowed-tools: .*Agent' "$design_skill"
  assert_present '^allowed-tools: .*TeamCreate' "$design_skill"
  assert_present 'TeamCreate' "$design_skill"
  assert_present '可用工具：Read, Write, Bash, Glob, Grep, LSP, WebSearch, AskUserQuestion, Agent, TeamCreate。' "$designer_adapter"
  assert_absent '禁止使用 Edit, Bash' "$designer_adapter"
}

assert_canonical_hooks_pass() {
  SKILL_OUTPUT_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/skill-output-canonical.XXXXXX")"
  SKILL_OUTPUT_REPO_FEATURE="$(mktemp -d "$ROOT/docs/skill-output-developer.XXXXXX")"
  trap 'rm -rf "$SKILL_OUTPUT_TMP_ROOT" "$SKILL_OUTPUT_REPO_FEATURE"' EXIT

  prepare_director_workspace "$SKILL_OUTPUT_TMP_ROOT/director"
  run_hook "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/director" "director-canonical" \
    "docs/director-feature/brief.json\ndocs/director-feature/phase-1/phase-prd.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/director" "product-director canonical gate"

  prepare_director_template_workspace "$SKILL_OUTPUT_TMP_ROOT/director-template"
  run_hook "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/director-template" "director-template-canonical" \
    "docs/director-template-feature/brief.json\ndocs/director-template-feature/phase-1/phase-prd.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/director-template" "product-director advertised template gate"

  prepare_director_pm_polluted_workspace "$SKILL_OUTPUT_TMP_ROOT/director-pm-polluted"
  run_hook "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/director-pm-polluted" "director-pm-polluted" \
    "docs/director-feature/brief.json\ndocs/director-feature/phase-1/phase-prd.json\n"
  if [ "$(cat "$SKILL_OUTPUT_TMP_ROOT/director-pm-polluted/hook.status")" = "0" ]; then
    cat "$SKILL_OUTPUT_TMP_ROOT/director-pm-polluted/hook.stdout" >&2
    fail "product-director gate should reject PM-owned phase-prd fields"
  fi
  assert_present 'contains Manager-owned closure, business semantics, design decisions, or non-empty unit_index' "$SKILL_OUTPUT_TMP_ROOT/director-pm-polluted/hook.stderr"

  prepare_director_missing_artifact_type_workspace "$SKILL_OUTPUT_TMP_ROOT/director-missing-artifact-type"
  run_hook "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/director-missing-artifact-type" "director-missing-artifact-type" \
    "docs/director-feature/brief.json\ndocs/director-feature/phase-1/phase-prd.json\n"
  if [ "$(cat "$SKILL_OUTPUT_TMP_ROOT/director-missing-artifact-type/hook.status")" = "0" ]; then
    cat "$SKILL_OUTPUT_TMP_ROOT/director-missing-artifact-type/hook.stdout" >&2
    fail "product-director gate should reject artifacts without canonical artifact_type"
  fi
  assert_present 'missing required canonical field: artifact_type' "$SKILL_OUTPUT_TMP_ROOT/director-missing-artifact-type/hook.stderr"

  prepare_workspace "$SKILL_OUTPUT_TMP_ROOT/manager"
  run_hook "$ROOT/shared/skills/product-manager/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/manager" "manager-canonical" \
    "docs/sample-feature/brief.json\ndocs/sample-feature/phase-1/phase-prd.json\ndocs/sample-feature/phase-1/units/UNIT-1.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/manager" "product-manager canonical gate"

  prepare_manager_unit_placeholder_workspace "$SKILL_OUTPUT_TMP_ROOT/manager-unit-placeholder"
  run_hook "$ROOT/shared/skills/product-manager/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/manager-unit-placeholder" "manager-unit-placeholder" \
    "docs/sample-feature/brief.json\ndocs/sample-feature/phase-1/phase-prd.json\ndocs/sample-feature/phase-1/units/UNIT-1.json\n"
  if [ "$(cat "$SKILL_OUTPUT_TMP_ROOT/manager-unit-placeholder/hook.status")" = "0" ]; then
    cat "$SKILL_OUTPUT_TMP_ROOT/manager-unit-placeholder/hook.stdout" >&2
    fail "product-manager gate should reject UNIT placeholder semantic fields"
  fi
  assert_present 'UNIT.json PM-owned semantic fields are not closed' "$SKILL_OUTPUT_TMP_ROOT/manager-unit-placeholder/hook.stderr"

  prepare_workspace "$SKILL_OUTPUT_TMP_ROOT/design"
  run_hook "$ROOT/shared/skills/design/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/design" "design-canonical" \
    "docs/sample-feature/phase-1/design.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/design" "design canonical gate"

  prepare_workspace "$SKILL_OUTPUT_TMP_ROOT/test-design"
  run_hook "$ROOT/shared/skills/test-design/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/test-design" "test-design-canonical" \
    "docs/sample-feature/phase-1/unit-1/test-cases.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/test-design" "test-design canonical gate"

  prepare_workspace "$SKILL_OUTPUT_TMP_ROOT/tech-lead"
  run_hook "$ROOT/shared/skills/tech-lead/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/tech-lead" "tech-lead-canonical" \
    "docs/sample-feature/phase-1/plan.json\n" \
    "Write" "docs/sample-feature/phase-1/plan.json"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/tech-lead" "tech-lead canonical gate"

  mkdir -p "$SKILL_OUTPUT_TMP_ROOT/developer"
  cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1" \
    "$SKILL_OUTPUT_REPO_FEATURE/phase-1"
  traceable_commit="$(git rev-parse --short HEAD)"
  for report in "$SKILL_OUTPUT_REPO_FEATURE"/phase-1/unit-1/tasks/*/developer-report.json; do
    [ -f "$report" ] || fail "missing developer report fixture: $report"
    developer_report_tmp="$(mktemp "${TMPDIR:-/tmp}/developer-report.XXXXXX")"
    jq --arg commit "$traceable_commit" \
      '(.tdd_evidence_index[]?.commit_sha) = $commit' \
      "$report" > "$developer_report_tmp"
    mv "$developer_report_tmp" "$report"
  done
  developer_report_path="${SKILL_OUTPUT_REPO_FEATURE#"$ROOT"/}/phase-1/unit-1/tasks/T1/developer-report.json"
  run_hook "$ROOT/shared/skills/developer/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/developer" "developer-canonical" \
    "$developer_report_path\n" "" "" "$ROOT"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/developer" "developer canonical gate"

  prepare_workspace "$SKILL_OUTPUT_TMP_ROOT/review"
  run_hook "$ROOT/shared/skills/review/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/review" "review-canonical" \
    "docs/sample-feature/phase-1/code-review-result.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/review" "review canonical gate"

  prepare_workspace "$SKILL_OUTPUT_TMP_ROOT/qa"
  run_hook "$ROOT/shared/skills/qa/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/qa" "qa-canonical" \
    "docs/sample-feature/phase-1/qa-result.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/qa" "qa canonical gate"

  prepare_workspace "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous"
  cp -R "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous/docs/sample-feature" "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous/docs/other-feature"
  run_hook "$ROOT/shared/skills/qa/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous" "qa-ambiguous-canonical" \
    "docs/sample-feature/phase-1/qa-result.json\ndocs/other-feature/phase-1/qa-result.json\n"
  if [ "$(cat "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous/hook.status")" = "0" ]; then
    cat "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous/hook.stdout" >&2
    fail "qa canonical gate should block ambiguous Stop candidates"
  fi
  rg -n 'qa-result.json matched multiple candidates' "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous/hook.stderr" >/dev/null 2>&1 || {
    cat "$SKILL_OUTPUT_TMP_ROOT/qa-ambiguous/hook.stderr" >&2
    fail "qa canonical gate did not explain ambiguous candidates"
  }
}

assert_standard_chain_control_contract
assert_canonical_runtime_artifacts
assert_canonical_only_scripts
assert_completion_gate_registry_manifest_alignment
assert_completion_gate_handlers_help
assert_completion_gate_handlers_syntax
assert_hook_registry_renderable
assert_tech_lead_runtime_control_contract
assert_planning_projection_context_contract
assert_canonical_hooks_pass

printf '[PASS] skill output and gate contract\n'
