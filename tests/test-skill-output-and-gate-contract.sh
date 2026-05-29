#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCOPE="all"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: bash tests/test-skill-output-and-gate-contract.sh [--scope all|static|runtime]
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --scope)
      [ "$#" -ge 2 ] || fail "--scope 缺少参数"
      SCOPE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "未知参数: $1"
      ;;
  esac
done

case "$SCOPE" in
  all|static|runtime) ;;
  *) fail "未知 skill output gate scope: $SCOPE" ;;
esac

should_run_scope() {
  [ "$SCOPE" = "all" ] || [ "$SCOPE" = "$1" ]
}

# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

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

assert_projection_source_contract() {
  local projection="$1"
  case "$projection" in
    */product-manager/projections/brief-template.md)
      assert_present 'brief\.json' "$projection"
      ;;
    */product-manager/projections/phase-prd-template.md)
      assert_present 'phase-prd\.json' "$projection"
      assert_present 'units/UNIT-\*\.json' "$projection"
      ;;
    */product-manager/projections/product-manager-review-template.md)
      assert_present 'review_conclusion' "$projection"
      assert_present 'issue_ledger' "$projection"
      ;;
    */design/projections/design-template.md | */design/projections/adr-spec.md)
      assert_present 'design\.json' "$projection"
      ;;
    *)
      fail "missing projection source contract case: ${projection#"$ROOT"/}"
      ;;
  esac
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

assert_delivery_owner_control_terms() {
  python3 - "$ROOT/shared/skills/delivery-owner/SKILL.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
requirements = {
    "frozen_tasks": ["tech-lead", "tasks"],
    "delivery_review": ["交付", "review"],
    "loop_limit": ["10 轮"],
    "commit_dispatch": ["/commit"],
    "user_decision": ["用户", "决策方"],
}
missing = [name for name, terms in requirements.items() if not all(term in text for term in terms)]
if missing:
    raise SystemExit(f"{path}: missing delivery-owner control terms: {', '.join(missing)}")
PY
}

assert_hook_registry_renderable() {
  local rendered
  rendered="$(mktemp "${TMPDIR:-/tmp}/rendered-hooks.XXXXXX")"
  python3 "$ROOT/tools/community/render_hook_registry.py" codex-hooks \
    --registry "$ROOT/shared/hooks/registry.json" \
    --runtime-home /tmp/runtime > "$rendered" || fail "hook registry must render for Codex"
  jq empty "$rendered" >/dev/null 2>&1 || fail "rendered Codex hook registry must be valid JSON"
  jq -e '
    ._org_skills.allowed_events == [
      "SessionStart",
      "PreToolUse",
      "PermissionRequest",
      "PostToolUse",
      "UserPromptSubmit",
      "Stop"
    ]
  ' "$rendered" >/dev/null 2>&1 || fail "Codex hook registry should expose the current official Codex event surface"
  jq -e '._org_skills.managed_only_events == ["UserPromptSubmit"]' "$rendered" >/dev/null 2>&1 \
    || fail "Codex hook registry should reserve only internal UserPromptSubmit hooks for managed handlers"
  jq -e '.hooks | has("PostCompact") | not' "$rendered" >/dev/null 2>&1 \
    || fail "Codex hook registry should not render Claude-only PostCompact"
  jq -e '.hooks | has("TaskCompleted") | not' "$rendered" >/dev/null 2>&1 \
    || fail "Codex hook registry should not render Claude-only TaskCompleted"
  jq -e '
    any(.hooks.PostToolUse[]?;
      (.matcher == "Write|Edit")
      and any(.hooks[]?; (.command | contains("context_contract_validator.py")))
    )
  ' "$rendered" >/dev/null 2>&1 || fail "Codex PostToolUse should run context validator for Write/Edit edits"
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

assert_hook_noop_allowed() {
  local workspace="$1"
  local label="$2"
  local status
  status="$(cat "$workspace/hook.status")"
  if [ "$status" != "0" ]; then
    cat "$workspace/hook.stderr" >&2
    fail "$label failed with exit $status"
  fi
  jq -e 'type == "object" and length == 0' "$workspace/hook.stdout" >/dev/null 2>&1 || {
    cat "$workspace/hook.stdout" >&2
    cat "$workspace/hook.stderr" >&2
    fail "$label did not emit empty no-op decision"
  }
}

prepare_workspace() {
  local workspace="$1"
  mkdir -p "$workspace/docs"
  cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature" "$workspace/docs/sample-feature"
}

write_product_director_ledger() {
  local feature_dir="$1"
  local finalization_status="${2:-confirmed}"

  python3 - "$feature_dir" "$finalization_status" <<'PY'
import json
import sys
from pathlib import Path

feature_dir = Path(sys.argv[1])
finalization_status = sys.argv[2]
step_summaries = {
    "D-S2": "Root problem confirmed: operations specialists miss merchant onboarding handoffs because checklist status is split across spreadsheets and tools.",
    "D-S3": "Success signal confirmed: missed onboarding handoffs move from 4 per month to zero in a 30-day observation window.",
    "D-S4": "Business semantics confirmed: onboarding record comes from the existing approval system; configuration handoff means operations can transfer accepted setup responsibility.",
    "D-S5": "Scope confirmed: intake review, configuration handoff, and status visibility are in; CRM replacement, rule builders, and analytics are out.",
    "D-S5.5": "Risk confirmed: existing approval status supports Phase 1; status model drift returns to risk review before finalization.",
    "D-S6": "Phase confirmed: one 14-day value slice closes operations handoff visibility before automation expansion.",
    "D-G1": "Finalization confirmed: ledger, brief, and phase-prd result payloads are ready for Director completion.",
}
confirmations = []
for index, (step, summary) in enumerate(step_summaries.items(), start=1):
    checkpoint_id = f"PD-{index:02d}"
    confirmations.append(
        {
            "checkpoint_id": checkpoint_id,
            "step": step,
            "subject_ref": f"{feature_dir.name}:{step}",
            "confirmed_at": f"2026-04-14T02:{index:02d}:00Z",
            "decision_summary": summary,
            "source_refs": [f"docs/{feature_dir.name}/brief.json"],
            "output_refs": [
                f"docs/{feature_dir.name}/brief.json",
                f"docs/{feature_dir.name}/phase-1/phase-prd.json",
            ],
        }
    )

payload = {
    "artifact_type": "co-creation-ledger",
    "schema_version": "1.0.0",
    "producer": "product-director",
    "scope_ref": f"docs/{feature_dir.name}",
    "current_state": {
        "summary": "Director baseline finalized for detail work",
        "source_refs": [f"docs/{feature_dir.name}/brief.json"],
        "next_step": "ready for product and technical detail work",
    },
    "latest_checkpoint_id": confirmations[-1]["checkpoint_id"],
    "confirmations": confirmations,
    "open_questions": [],
    "supersedes": [],
    "handoff_refs": [
        f"docs/{feature_dir.name}/brief.json",
        f"docs/{feature_dir.name}/phase-1/phase-prd.json",
    ],
    "finalization_basis": {
        "status": finalization_status,
        "confirmed_at": "2026-04-14T02:30:00Z",
        "summary": "Director ledger finalized after all required checkpoints",
        "accepted_checkpoint_ids": [item["checkpoint_id"] for item in confirmations],
    },
}
feature_dir.mkdir(parents=True, exist_ok=True)
(feature_dir / "product-director-ledger.json").write_text(
    json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY
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
  mkdir -p "$workspace/docs/director-feature/phase-1"
  cp "$ROOT/shared/skills/product-director/templates/brief.template.json" \
    "$workspace/docs/director-feature/brief.json"
  cp "$ROOT/shared/skills/product-director/templates/phase-prd.template.json" \
    "$workspace/docs/director-feature/phase-1/phase-prd.json"
  write_product_director_ledger "$workspace/docs/director-feature"
}

prepare_director_downstream_phase_workspace() {
  local workspace="$1"
  prepare_director_workspace "$workspace"

  jq '
    .business_flows = ["产品经理同事负责的 business flow 不应出现在 Director 产物中"]
    | .user_paths = ["产品经理同事负责的 user path 不应出现在 Director 产物中"]
    | .rule_mappings = ["产品经理同事负责的 rule mapping 不应出现在 Director 产物中"]
    | .unit_priority_order = [{"unit_id": "UNIT-1", "priority": "P0"}]
    | .semantic_draft = {"note": "Director 不应冻结语义草稿"}
    | .business_semantics_draft = {"note": "Director 不应冻结业务语义草稿"}
    | .semantics_gaps = [{"gap": "Director 不应携带 PM 语义缺口"}]
    | .design_decision_candidates = []
  ' "$workspace/docs/director-feature/phase-1/phase-prd.json" > "$workspace/docs/director-feature/phase-1/phase-prd.tmp.json"
  mv "$workspace/docs/director-feature/phase-1/phase-prd.tmp.json" "$workspace/docs/director-feature/phase-1/phase-prd.json"
}

prepare_director_downstream_brief_workspace() {
  local workspace="$1"
  prepare_director_workspace "$workspace"

  jq '
    .business_flows = ["产品经理同事负责的 business flow 不应出现在 Director brief 中"]
    | .user_paths = ["产品经理同事负责的 user path 不应出现在 Director brief 中"]
    | .rule_mappings = ["产品经理同事负责的 rule mapping 不应出现在 Director brief 中"]
    | .semantic_draft = {"note": "Director brief 不应冻结语义草稿"}
    | .business_semantics_draft = {"note": "Director brief 不应冻结业务语义草稿"}
    | .semantics_gaps = [{"gap": "Director brief 不应携带 PM 语义缺口"}]
  ' "$workspace/docs/director-feature/brief.json" > "$workspace/docs/director-feature/brief.tmp.json"
  mv "$workspace/docs/director-feature/brief.tmp.json" "$workspace/docs/director-feature/brief.json"
}

prepare_director_runtime_noise_workspace() {
  local workspace="$1"
  prepare_director_workspace "$workspace"

  jq '.unit_index = []' \
    "$workspace/docs/director-feature/phase-1/phase-prd.json" > "$workspace/docs/director-feature/phase-1/phase-prd.tmp.json"
  mv "$workspace/docs/director-feature/phase-1/phase-prd.tmp.json" "$workspace/docs/director-feature/phase-1/phase-prd.json"
}

prepare_director_missing_ledger_workspace() {
  local workspace="$1"
  prepare_director_workspace "$workspace"
  rm -f "$workspace/docs/director-feature/product-director-ledger.json"
}

prepare_director_unfinalized_ledger_workspace() {
  local workspace="$1"
  prepare_director_workspace "$workspace"
  write_product_director_ledger "$workspace/docs/director-feature" "draft"
}

prepare_director_weak_content_workspace() {
  local workspace="$1"
  prepare_director_workspace "$workspace"

  jq '
    .root_problem = "Improve billing reminder efficiency."
    | .business_goals = ["make the process better"]
  ' "$workspace/docs/director-feature/brief.json" > "$workspace/docs/director-feature/brief.tmp.json"
  mv "$workspace/docs/director-feature/brief.tmp.json" "$workspace/docs/director-feature/brief.json"

  jq '
    .entry_conditions = ["director baseline confirmed"]
    | .exit_conditions = ["finish the 10-day timebox"]
  ' "$workspace/docs/director-feature/phase-1/phase-prd.json" > "$workspace/docs/director-feature/phase-1/phase-prd.tmp.json"
  mv "$workspace/docs/director-feature/phase-1/phase-prd.tmp.json" "$workspace/docs/director-feature/phase-1/phase-prd.json"

}

prepare_director_template_workspace() {
  local workspace="$1"
  mkdir -p "$workspace/docs/director-template-feature/phase-1"
  cp "$ROOT/shared/skills/product-director/templates/brief.template.json" \
    "$workspace/docs/director-template-feature/brief.json"
  cp "$ROOT/shared/skills/product-director/templates/phase-prd.template.json" \
    "$workspace/docs/director-template-feature/phase-1/phase-prd.json"
  write_product_director_ledger "$workspace/docs/director-template-feature"
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

assert_refactor_gate_ignores_non_refactor_context() {
  local workspace
  workspace="$(mktemp -d "${TMPDIR:-/tmp}/refactor-gate-non-refactor.XXXXXX")"
  trap 'rm -rf "$workspace"' RETURN

  run_hook "$ROOT/shared/skills/refactor/scripts/completion_check.sh" \
    "$workspace" "refactor-non-refactor" \
    "shared/skills/cli-updater/SKILL.md\ntests/test-install-runtime-smoke.sh\n"
  assert_hook_noop_allowed "$workspace" "refactor gate should ignore non-refactor Stop context"
}

assert_refactor_gate_ignores_placeholder_transcript_candidates() {
  local workspace
  workspace="$(mktemp -d "${TMPDIR:-/tmp}/refactor-gate-placeholders.XXXXXX")"
  trap 'rm -rf "$workspace"' RETURN

  run_hook "$ROOT/shared/skills/refactor/scripts/completion_check.sh" \
    "$workspace" "refactor-placeholder-candidates" \
    "docs/refactor--{模块名}/plan.md\ndocs/refactor--demo/plan.md\ndocs/refactor--xxx/plan.md\n"
  assert_hook_noop_allowed "$workspace" "refactor gate should ignore placeholder Stop candidates"
}

assert_standard_chain_control_contract() {
  assert_present 'phase_delivery_owner: delivery-owner' "$ROOT/contracts/standard-chain.yaml"
  assert_present 'sidecar_dispatch' "$ROOT/contracts/standard-chain.yaml"
  assert_present 'consistency-auditor' "$ROOT/contracts/standard-chain.yaml"
  assert_present 'decision_authority: advisory_only' "$ROOT/contracts/standard-chain.yaml"
  assert_absent 'gate_escalation' "$ROOT/contracts/standard-chain.yaml"

  assert_delivery_owner_control_terms
  assert_present 'artifact-registry.json' "$ROOT/shared/skills/delivery-owner/SKILL.md"
  assert_present 'references/followup-loops.md' "$ROOT/shared/skills/delivery-owner/SKILL.md"
  assert_absent 'signoff_ready|control_decision_check|gap_delta|rebaseline_needed' "$ROOT/shared/skills/delivery-owner/SKILL.md"

  assert_present 'planning owner' "$ROOT/shared/skills/tech-lead/SKILL.md"
  assert_present 'brief\.json\.review_conclusion' "$ROOT/shared/skills/product-manager/references/review-orchestration.md"
  assert_present 'issue_ledger' "$ROOT/shared/skills/product-manager/references/review-orchestration.md"
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
  assert_present 'active_tasks_version_ref' "$ROOT/shared/skills/developer/contracts/developer-report.schema.json"
  assert_present 'active_tasks_version_ref' "$ROOT/shared/skills/qa/contracts/qa-result.schema.json"
  assert_present 'backward_compatibility' "$ROOT/shared/skills/review/contracts/code-review-result.schema.json"
  assert_present 'backward_compatibility' "$ROOT/shared/skills/review/templates/code-review-result.template.json"
  assert_present 'references/final-artifacts\.md' "$ROOT/shared/skills/product-director/SKILL.md"
  assert_absent 'references/output\.md#' "$ROOT/shared/skills/product-director/SKILL.md"
  assert_present 'shared/skills/product-director/templates/brief.template.json' "$ROOT/shared/skills/product-director/references/final-artifacts.md"
  assert_present 'shared/skills/product-director/templates/phase-prd.template.json' "$ROOT/shared/skills/product-director/references/final-artifacts.md"
  assert_present 'canonical envelope' "$ROOT/shared/skills/product-director/references/final-artifacts.md"
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
    if [ "$script" = "$ROOT/shared/skills/product-director/scripts/completion_check.sh" ]; then
      assert_present 'Director result baseline gate' "$script"
      assert_present 'canonical' "$script"
    else
      assert_present 'canonical' "$script"
    fi
    assert_absent 'ORG_ENABLE_LEGACY_MARKDOWN_HOOKS|legacy markdown|brief\.md|prd\.md|design\.md|plan\.md|test-cases\.md|developer-report-Task|qa-report\.md|code-review-report\.md|product-manager-review\.md' "$script"
    assert_absent 'first_matching_hook_path|grep -oE .*head -1|head -1 \|\| true' "$script"
  done
}

assert_tech_lead_runtime_control_contract() {
  local manifest="$ROOT/shared/skills/tech-lead/scripts/manifest.json"
  local registry="$ROOT/shared/hooks/registry.json"
  local skill="$ROOT/shared/skills/tech-lead/SKILL.md"
  local projection="$ROOT/shared/skills/tech-lead/projections/plan-template.md"

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
      and (.allowed_args | index("--require-tasks") != null)
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
  assert_absent '^(Trigger|Read|Expect|Consume|Evidence|Sync):' "$projection"
  [ ! -e "$ROOT/codex/agents/tech-lead.toml" ] \
    || fail "tech-lead should remain a manual skill, not a delivery-owner dispatch agent"
}

assert_planning_projection_context_contract() {
  local pm_skill="$ROOT/shared/skills/product-manager/SKILL.md"
  local pm_evals="$ROOT/shared/skills/product-manager/evals/evals.json"
  local design_skill="$ROOT/shared/skills/design/SKILL.md"

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
    assert_projection_source_contract "$projection"
  done

  assert_present '^allowed-tools: .*Bash' "$pm_skill"
  assert_present 'validate_standard_chain_phase.py' "$pm_skill"
  assert_present '^allowed-tools: .*TeamCreate' "$pm_skill"
  assert_present '^allowed-tools: .*SendMessage' "$pm_skill"
  assert_present '^allowed-tools: .*TeamDelete' "$pm_skill"
  assert_present '"id": "canonical-review-required"' "$pm_evals"
  assert_present 'PM owner 自检通过后' "$pm_evals"
  assert_present 'reviewed_bundle_digest' "$pm_skill"

  assert_present '^allowed-tools: .*Bash' "$design_skill"
  assert_present '^allowed-tools: .*Agent' "$design_skill"
  assert_present '^allowed-tools: .*TeamCreate' "$design_skill"
  assert_present '^allowed-tools: .*SendMessage' "$design_skill"
  assert_present '^allowed-tools: .*TeamDelete' "$design_skill"
  [ ! -e "$ROOT/codex/agents/designer.toml" ] \
    || fail "designer should remain a manual skill, not a delivery-owner dispatch agent"
  [ ! -e "$ROOT/codex/agents/test-designer.toml" ] \
    || fail "test-designer should remain a manual skill, not a delivery-owner dispatch agent"
}

assert_canonical_hooks_pass() {
  SKILL_OUTPUT_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/skill-output-gates.XXXXXX")"
  SKILL_OUTPUT_REPO_FEATURE="$(mktemp -d "$ROOT/docs/skill-output-developer.XXXXXX")"
  trap 'rm -rf "$SKILL_OUTPUT_TMP_ROOT" "$SKILL_OUTPUT_REPO_FEATURE"' EXIT

  prepare_director_workspace "$SKILL_OUTPUT_TMP_ROOT/director"
  run_hook "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/director" "director-result" \
    "docs/director-feature/brief.json\ndocs/director-feature/phase-1/phase-prd.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/director" "product-director result gate"

  prepare_director_template_workspace "$SKILL_OUTPUT_TMP_ROOT/director-template"
  run_hook "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/director-template" "director-template-result" \
    "docs/director-template-feature/brief.json\ndocs/director-template-feature/phase-1/phase-prd.json\n"
  assert_hook_passed "$SKILL_OUTPUT_TMP_ROOT/director-template" "product-director advertised template gate"

  prepare_director_missing_ledger_workspace "$SKILL_OUTPUT_TMP_ROOT/director-missing-ledger"
  run_hook "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/director-missing-ledger" "director-missing-ledger" \
    "docs/director-feature/brief.json\ndocs/director-feature/phase-1/phase-prd.json\n"
  if [ "$(cat "$SKILL_OUTPUT_TMP_ROOT/director-missing-ledger/hook.status")" = "0" ]; then
    cat "$SKILL_OUTPUT_TMP_ROOT/director-missing-ledger/hook.stdout" >&2
    fail "product-director gate should reject missing product-director-ledger.json"
  fi
  assert_present 'product-director-ledger.json finalized validation failed' "$SKILL_OUTPUT_TMP_ROOT/director-missing-ledger/hook.stderr"
  assert_present 'ledger not found' "$SKILL_OUTPUT_TMP_ROOT/director-missing-ledger/hook.stderr"

  prepare_director_unfinalized_ledger_workspace "$SKILL_OUTPUT_TMP_ROOT/director-unfinalized-ledger"
  run_hook "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/director-unfinalized-ledger" "director-unfinalized-ledger" \
    "docs/director-feature/brief.json\ndocs/director-feature/phase-1/phase-prd.json\n"
  if [ "$(cat "$SKILL_OUTPUT_TMP_ROOT/director-unfinalized-ledger/hook.status")" = "0" ]; then
    cat "$SKILL_OUTPUT_TMP_ROOT/director-unfinalized-ledger/hook.stdout" >&2
    fail "product-director gate should reject non-finalized product-director-ledger.json"
  fi
  assert_present 'finalization_basis.status must be confirmed' "$SKILL_OUTPUT_TMP_ROOT/director-unfinalized-ledger/hook.stderr"

  prepare_director_weak_content_workspace "$SKILL_OUTPUT_TMP_ROOT/director-weak-content"
  run_hook "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/director-weak-content" "director-weak-content" \
    "docs/director-feature/brief.json\ndocs/director-feature/phase-1/phase-prd.json\n"
  if [ "$(cat "$SKILL_OUTPUT_TMP_ROOT/director-weak-content/hook.status")" = "0" ]; then
    cat "$SKILL_OUTPUT_TMP_ROOT/director-weak-content/hook.stdout" >&2
    fail "product-director gate should reject weak content quality"
  fi
  assert_present 'product-director content quality validation failed' "$SKILL_OUTPUT_TMP_ROOT/director-weak-content/hook.stderr"
  assert_present 'phase entry conditions must be business facts' "$SKILL_OUTPUT_TMP_ROOT/director-weak-content/hook.stderr"

  prepare_director_downstream_phase_workspace "$SKILL_OUTPUT_TMP_ROOT/director-downstream-phase"
  run_hook "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/director-downstream-phase" "director-downstream-phase" \
    "docs/director-feature/brief.json\ndocs/director-feature/phase-1/phase-prd.json\n"
  if [ "$(cat "$SKILL_OUTPUT_TMP_ROOT/director-downstream-phase/hook.status")" = "0" ]; then
    cat "$SKILL_OUTPUT_TMP_ROOT/director-downstream-phase/hook.stdout" >&2
    fail "product-director gate should reject PM-owned downstream phase-prd fields"
  fi
  assert_present 'phase-prd.json contains PM-owned downstream fields' "$SKILL_OUTPUT_TMP_ROOT/director-downstream-phase/hook.stderr"

  prepare_director_downstream_brief_workspace "$SKILL_OUTPUT_TMP_ROOT/director-downstream-brief"
  run_hook "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/director-downstream-brief" "director-downstream-brief" \
    "docs/director-feature/brief.json\ndocs/director-feature/phase-1/phase-prd.json\n"
  if [ "$(cat "$SKILL_OUTPUT_TMP_ROOT/director-downstream-brief/hook.status")" = "0" ]; then
    cat "$SKILL_OUTPUT_TMP_ROOT/director-downstream-brief/hook.stdout" >&2
    fail "product-director gate should reject PM-owned downstream brief fields"
  fi
  assert_present 'brief.json contains PM-owned downstream fields' "$SKILL_OUTPUT_TMP_ROOT/director-downstream-brief/hook.stderr"

  prepare_director_runtime_noise_workspace "$SKILL_OUTPUT_TMP_ROOT/director-runtime-noise"
  run_hook "$ROOT/shared/skills/product-director/scripts/completion_check.sh" \
    "$SKILL_OUTPUT_TMP_ROOT/director-runtime-noise" "director-runtime-noise" \
    "docs/director-feature/brief.json\ndocs/director-feature/phase-1/phase-prd.json\n"
  if [ "$(cat "$SKILL_OUTPUT_TMP_ROOT/director-runtime-noise/hook.status")" = "0" ]; then
    cat "$SKILL_OUTPUT_TMP_ROOT/director-runtime-noise/hook.stdout" >&2
    fail "product-director gate should reject PM-owned downstream fields"
  fi
  assert_present 'phase-prd.json contains PM-owned downstream fields' "$SKILL_OUTPUT_TMP_ROOT/director-runtime-noise/hook.stderr"

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
    "docs/sample-feature/phase-1/tasks.json\n" \
    "Write" "docs/sample-feature/phase-1/tasks.json"
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

if should_run_scope static; then
  assert_refactor_gate_ignores_non_refactor_context
  assert_refactor_gate_ignores_placeholder_transcript_candidates
  assert_standard_chain_control_contract
  assert_canonical_runtime_artifacts
  assert_canonical_only_scripts
  assert_completion_gate_registry_manifest_alignment
  assert_completion_gate_handlers_help
  assert_completion_gate_handlers_syntax
  assert_hook_registry_renderable
  assert_tech_lead_runtime_control_contract
  assert_planning_projection_context_contract
fi

if should_run_scope runtime; then
  assert_canonical_hooks_pass
fi

printf '[PASS] skill output and gate contract\n'
