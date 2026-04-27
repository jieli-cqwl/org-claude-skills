#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ROLE="${SC_COMPLETION_ROLE:-$(basename "$(cd "$SCRIPT_DIR/.." && pwd)")}"
PROFILE="$ROOT/shared/runtime/standard-chain-completion-profiles.json"
# shellcheck source=/dev/null
source "$ROOT/shared/skills/lib/standard-chain-routing.sh"
if [[ -n "${SC_COMPLETION_DELAY_SECONDS:-}" ]]; then sleep "$SC_COMPLETION_DELAY_SECONDS"; fi

profile_json="$(
  python3 - "$PROFILE" "$ROLE" <<'PY'
import json, sys
profile_path, role = sys.argv[1:]
try:
    catalog = json.loads(open(profile_path, encoding="utf-8").read())
    profile = catalog["roles"][role]
    payload = {"ok": True, "stage": profile["stage"], "required": profile["required_arguments"]}
except Exception as exc:
    payload = {"ok": False, "stage": f"{role}.completion", "message": f"Completion profile bootstrap failed: {type(exc).__name__}", "evidence_refs": [f"file://{profile_path}"]}
print(json.dumps(payload, sort_keys=True))
PY
)"
profile_ok="$(python3 - "$profile_json" <<'PY'
import json, sys
print("true" if json.loads(sys.argv[1]).get("ok") else "false")
PY
)"
stage="$(python3 - "$profile_json" <<'PY'
import json, sys
print(json.loads(sys.argv[1])["stage"])
PY
)"
if [[ "$profile_ok" != "true" ]]; then
  message="$(python3 - "$profile_json" <<'PY'
import json, sys
print(json.loads(sys.argv[1])["message"])
PY
)"
  sc_emit_routing_json --stage "$stage" --failure-code MALFORMED_ARTIFACT --user-message "$message" --evidence-ref "file://$PROFILE"
  exit 1
fi
required_csv="$(python3 - "$profile_json" <<'PY'
import json, sys
print(",".join(json.loads(sys.argv[1])["required"]))
PY
)"
if IFS= read -r -t 0; then
  sc_emit_core_cli_reject "$stage" "Core checkers are argv-only; hook payload stdin must use an adapter." "diagnostic://standard-chain/completion-core/stdin-hook-payload"
  exit 1
fi
if ! sc_validate_core_argv "$stage" "feature,phase-dir,unit,task-id" "$required_csv" "$@"; then
  exit 1
fi

feature=""; phase_dir=""; unit=""; task_id=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature) feature="$2"; shift 2 ;;
    --phase-dir) phase_dir="$2"; shift 2 ;;
    --unit) unit="$2"; shift 2 ;;
    --task-id) task_id="$2"; shift 2 ;;
  esac
done

decision="$(
  python3 - "$ROOT" "$PROFILE" "$ROLE" "$feature" "$phase_dir" "$unit" "$task_id" <<'PY'
import json, re, sys
from pathlib import Path
root, profile_path, role, feature_arg, phase_arg, unit_arg, task_id = sys.argv[1:]
profile = json.loads(Path(profile_path).read_text(encoding="utf-8"))["roles"][role]
stage = profile["stage"]

def emit(code, message, evidence):
    print(json.dumps({"failure_code": code, "message": message, "evidence_refs": evidence}, sort_keys=True))
    raise SystemExit(0)

def resolve_feature(value):
    candidate = Path(value).expanduser()
    if candidate.is_absolute():
        return candidate.resolve()
    repo_relative = Path(root) / candidate
    if repo_relative.exists() or (candidate.parts and candidate.parts[0] == "docs"):
        return repo_relative.resolve()
    return (Path(root) / "docs" / candidate).resolve()

def resolve_phase(feature_dir, value):
    candidate = Path(value).expanduser()
    if candidate.is_absolute():
        return candidate.resolve()
    repo_relative = Path(root) / candidate
    if repo_relative.exists():
        return repo_relative.resolve()
    return (feature_dir / value).resolve()

def unit_slug(value):
    match = re.search(r"(\d+)$", value or "UNIT-1")
    return f"unit-{match.group(1)}" if match else value.lower()

feature_dir = resolve_feature(feature_arg)
phase_dir = resolve_phase(feature_dir, phase_arg)
unit_dir = phase_dir / unit_slug(unit_arg or "UNIT-1")
task = task_id or "T1"

def path_for(name):
    mapping = {
        "brief": feature_dir / "brief.json",
        "phase-prd": phase_dir / "phase-prd.json",
        "unit-definitions": phase_dir / "units" / f"{unit_arg or 'UNIT-1'}.json",
        "design": phase_dir / "design.json",
        "test-cases": unit_dir / "test-cases.json",
        "qa-handoff": unit_dir / "test-cases.json",
        "plan": phase_dir / "plan.json",
        "tasks": phase_dir / "tasks.json",
        "developer-report": unit_dir / "tasks" / task / "developer-report.json",
        "verify-result": unit_dir / "tasks" / task / "verify-result.json",
        "code-review-result": phase_dir / "code-review-result.json",
        "qa-result": phase_dir / "qa-result.json",
        "delivery-state": phase_dir / "delivery-state.json",
        "signoff-package": phase_dir / "signoff-package.json",
        "user-decision": phase_dir / "user-decision.json",
        "product-review": feature_dir / "brief.json",
        "delivery-confirmation": feature_dir / "brief.json",
        "verification-plan": phase_dir / "units" / f"{unit_arg or 'UNIT-1'}.json",
        "director-confirmation": phase_dir / "phase-prd.json",
        "locked-field-digest": phase_dir / "phase-prd.json",
        "design-final-confirmation": phase_dir / "design.json",
        "design-review": phase_dir / "plan.json",
        "proving-command": phase_dir / "plan.json",
        "plan-confirmation": phase_dir / "plan.json",
        "fresh-proof": unit_dir / "tasks" / task / "developer-report.json",
        "qa-triage": phase_dir / "qa-result.json",
    }
    return mapping.get(name)

loaded = {}
def load_json(path, code="MALFORMED_ARTIFACT"):
    if not path.exists():
        emit("MISSING_ARTIFACT", f"Required completion artifact is missing: {path}", [f"file://{path}"])
    if not path.is_file() or path.suffix != ".json":
        emit("MALFORMED_ARTIFACT", f"Completion artifact is not a JSON file: {path}", [f"file://{path}"])
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as exc:
        emit("MALFORMED_ARTIFACT", f"Malformed or unreadable completion artifact: {path} ({type(exc).__name__})", [f"file://{path}"])
    loaded[path] = data
    return data

def nonempty(value):
    return value not in (None, "", [], {})

def require(data, keys, path, code="MISSING_ARTIFACT"):
    missing = [key for key in keys if not nonempty(data.get(key))]
    if missing:
        emit(code, f"Completion artifact missing required fields: {', '.join(missing)}", [f"file://{path}"])

def confirmed(value):
    if not isinstance(value, dict):
        return False
    return str(value.get("status") or value.get("verdict") or value.get("decision") or "").lower() in {"pass", "passed", "confirm", "confirmed", "ready", "approve", "approved"}

def require_confirmation(value, path):
    if not confirmed(value) or not nonempty(value.get("confirmation_basis")):
        emit("MISSING_HUMAN_CONFIRMATION", "Delegated confirmation basis is missing or unconfirmed.", [f"file://{path}"])

def positive(value):
    if isinstance(value, str):
        return value.lower() in {"pass", "passed", "confirm", "confirmed", "ready", "approve", "approved", "allow", "signed_off"}
    if isinstance(value, dict):
        return positive(value.get("status") or value.get("verdict") or value.get("decision") or value.get("release_recommendation"))
    return isinstance(value, list) and len(value) > 0

def require_positive(value, path, label):
    if not positive(value):
        emit("HANDOFF_NOT_READY", f"{label} is not ready for handoff.", [f"file://{path}"])

def plan_refs():
    plan_path, tasks_path = phase_dir / "plan.json", phase_dir / "tasks.json"
    plan, tasks = load_json(plan_path), load_json(tasks_path)
    return plan.get("baseline_plan_version_ref") or tasks.get("baseline_plan_version_ref"), plan.get("baseline_tasks_version_ref") or tasks.get("artifact_id")

def check_refs(data, path):
    plan_ref, tasks_ref = plan_refs()
    active_plan = data.get("active_plan_version_ref") or data.get("baseline_plan_version_ref")
    active_tasks = data.get("active_tasks_version_ref") or data.get("baseline_tasks_version_ref")
    if not active_plan or not active_tasks:
        emit("STALE_EVIDENCE", "Completion artifact is missing active or baseline plan/tasks refs.", [f"file://{path}"])
    if active_plan != plan_ref:
        emit("STALE_EVIDENCE", "Completion artifact active_plan_version_ref is stale.", [f"file://{path}"])
    if active_tasks != tasks_ref:
        emit("STALE_EVIDENCE", "Completion artifact active_tasks_version_ref is stale.", [f"file://{path}"])

def role_checks():
    if role == "product-director":
        brief_path, prd_path = path_for("brief"), path_for("phase-prd")
        brief, prd = load_json(brief_path), load_json(prd_path)
        require(brief, ["artifact_type", "director_confirmation"], brief_path)
        require(prd, ["artifact_type", "director_confirmation"], prd_path)
        require_confirmation(prd["director_confirmation"], prd_path)
    elif role == "product-manager":
        brief, unit = load_json(path_for("brief")), load_json(path_for("unit-definitions"))
        require(brief, ["delivery_confirmation", "review_conclusion"], path_for("brief"), "HANDOFF_NOT_READY")
        require_confirmation(brief["delivery_confirmation"], path_for("brief"))
        require_positive(brief["review_conclusion"], path_for("brief"), "Product review")
        require(unit, ["verification_plan", "acceptance_criteria"], path_for("unit-definitions"))
    elif role == "design":
        data = load_json(path_for("design"))
        require(data, ["final_confirmation", "product_handoff", "interfaces", "verification_plan"], path_for("design"), "HANDOFF_NOT_READY")
        require_positive(data["final_confirmation"], path_for("design"), "Design final confirmation")
        require_positive(data["product_handoff"], path_for("design"), "Design product handoff")
    elif role == "test-design":
        data = load_json(path_for("test-cases"))
        require(data, ["test_cases", "qa_handoff_contract", "review_conclusion"], path_for("test-cases"), "HANDOFF_NOT_READY")
        require_positive(data["review_conclusion"], path_for("test-cases"), "Test design review")
        require_positive(data["qa_handoff_contract"], path_for("test-cases"), "QA handoff contract")
    elif role == "tech-lead":
        plan, tasks = load_json(path_for("plan")), load_json(path_for("tasks"))
        require(plan, ["design_review", "user_confirmation"], path_for("plan"))
        require(tasks, ["tasks"], path_for("tasks"))
        require_confirmation(plan["user_confirmation"], path_for("plan"))
    elif role == "developer":
        data, path = load_json(path_for("developer-report")), path_for("developer-report")
        require(data, ["task_scope", "file_changes", "self_testing", "tdd_evidence_index", "evidence_refs"], path, "HANDOFF_NOT_READY")
        check_refs(data, path)
    elif role == "verify":
        data, path = load_json(path_for("verify-result")), path_for("verify-result")
        require(data, ["gate_result", "phase_verdicts", "ac_verification", "evidence_refs"], path, "HANDOFF_NOT_READY")
        if data.get("gate_result") != "PASS":
            emit("HANDOFF_NOT_READY", "Verify result is not PASS.", [f"file://{path}"])
        check_refs(data, path)
    elif role == "review":
        developer_data, developer_path = load_json(path_for("developer-report")), path_for("developer-report")
        data, path = load_json(path_for("code-review-result")), path_for("code-review-result")
        verify_data, verify_path = load_json(path_for("verify-result")), path_for("verify-result")
        require(developer_data, ["active_plan_version_ref", "active_tasks_version_ref"], developer_path, "STALE_EVIDENCE")
        check_refs(developer_data, developer_path)
        require(verify_data, ["gate_result", "baseline_plan_version_ref", "baseline_tasks_version_ref"], verify_path, "HANDOFF_NOT_READY")
        if verify_data.get("gate_result") != "PASS":
            emit("HANDOFF_NOT_READY", "Verify result is not PASS.", [f"file://{verify_path}"])
        check_refs(verify_data, verify_path)
        require(data, ["gate_result", "dimension_verdicts", "review_conclusion"], path, "HANDOFF_NOT_READY")
        if data.get("gate_result") != "PASS" or data.get("review_conclusion") != "APPROVE":
            emit("HANDOFF_NOT_READY", "Code review result is not ready for QA.", [f"file://{path}"])
        check_refs(data, path)
    elif role == "qa":
        data, path = load_json(path_for("qa-result")), path_for("qa-result")
        require(data, ["gate_result", "release_recommendation", "stage_results", "ruled_out_issues"], path, "HANDOFF_NOT_READY")
        if data.get("gate_result") != "PASS" or data.get("release_recommendation") != "ALLOW":
            emit("HANDOFF_NOT_READY", "QA result is not ready for delivery-owner.", [f"file://{path}"])
        check_refs(data, path)
    elif role == "delivery-owner":
        for name in ["delivery-state", "signoff-package", "code-review-result", "qa-result", "user-decision"]:
            data, path = load_json(path_for(name)), path_for(name)
            require(data, ["artifact_type"], path)
        signoff, user_decision = load_json(path_for("signoff-package")), load_json(path_for("user-decision"))
        if signoff.get("sign_off_status") != "SIGNED_OFF" or user_decision.get("decision") != "APPROVE":
            emit("HANDOFF_NOT_READY", "Delivery closeout is not signed off.", [f"file://{path_for('signoff-package')}"])

for check in profile.get("checks", []):
    for output in check.get("required_outputs", []):
        path = path_for(output)
        if path is None:
            emit(check["failure_code"], f"Required output {output} cannot be resolved.", [f"profile://{role}/{check['check_id']}"])
        load_json(path, check["failure_code"])
role_checks()
emit("NONE", f"{role} completion passed.", [f"profile://{role}#{stage}"])
PY
)"
failure_code="$(python3 - "$decision" <<'PY'
import json, sys
print(json.loads(sys.argv[1])["failure_code"])
PY
)"
message="$(python3 - "$decision" <<'PY'
import json, sys
print(json.loads(sys.argv[1])["message"])
PY
)"
evidence_refs=()
while IFS= read -r ref; do evidence_refs+=("$ref"); done < <(python3 - "$decision" <<'PY'
import json, sys
for ref in json.loads(sys.argv[1])["evidence_refs"]:
    print(ref)
PY
)
routing_args=(--stage "$stage" --failure-code "$failure_code" --user-message "$message")
[[ "$failure_code" == "NONE" ]] && routing_args+=(--owner "$ROLE")
for ref in "${evidence_refs[@]}"; do routing_args+=(--evidence-ref "$ref"); done
sc_emit_routing_json "${routing_args[@]}"
[[ "$failure_code" == "NONE" ]]
