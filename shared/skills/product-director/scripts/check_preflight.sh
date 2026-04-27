#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ROLE="${SC_PREFLIGHT_ROLE:-$(basename "$(cd "$SCRIPT_DIR/.." && pwd)")}"
PROFILE="$ROOT/shared/runtime/standard-chain-preflight-profiles.json"
# shellcheck source=/dev/null
source "$ROOT/shared/skills/lib/standard-chain-routing.sh"
if [[ -n "${SC_PREFLIGHT_DELAY_SECONDS:-}" ]]; then sleep "$SC_PREFLIGHT_DELAY_SECONDS"; fi
profile_json="$(
  python3 - "$PROFILE" "$ROLE" <<'PY'
import json
import sys
profile_path, role = sys.argv[1:]
try:
    catalog = json.loads(open(profile_path, encoding="utf-8").read())
    profile = catalog["roles"][role]
    payload = {
        "ok": True,
        "stage": profile["stage"],
        "required": profile["required_arguments"],
    }
except Exception as exc:
    payload = {
        "ok": False,
        "stage": f"{role}.preflight",
        "message": f"Preflight profile bootstrap failed: {type(exc).__name__}",
        "evidence_refs": [f"file://{profile_path}"],
    }
print(json.dumps(payload, sort_keys=True))
PY
)"
profile_ok="$(python3 - "$profile_json" <<'PY'
import json
import sys
print("true" if json.loads(sys.argv[1]).get("ok") else "false")
PY
)"
stage="$(python3 - "$profile_json" <<'PY'
import json
import sys
print(json.loads(sys.argv[1])["stage"])
PY
)"
if [[ "$profile_ok" != "true" ]]; then
  profile_message="$(python3 - "$profile_json" <<'PY'
import json
import sys
print(json.loads(sys.argv[1])["message"])
PY
)"
  profile_evidence="$(python3 - "$profile_json" <<'PY'
import json
import sys
print(json.loads(sys.argv[1])["evidence_refs"][0])
PY
)"
  sc_emit_routing_json \
    --stage "$stage" \
    --failure-code MALFORMED_ARTIFACT \
    --user-message "$profile_message" \
    --evidence-ref "$profile_evidence"
  exit 1
fi
required_csv="$(python3 - "$profile_json" <<'PY'
import json
import sys
print(",".join(json.loads(sys.argv[1])["required"]))
PY
)"
allowed_csv="feature,phase-dir,unit,task-id,artifact,scope"
if IFS= read -r -t 0; then
  sc_emit_core_cli_reject "$stage" "Core checkers are argv-only; hook payload stdin must use an adapter." "diagnostic://standard-chain/core-cli/stdin-hook-payload"
  exit 1
fi

if ! sc_validate_core_argv "$stage" "$allowed_csv" "$required_csv" "$@"; then
  exit 1
fi

feature=""; phase_dir=""; unit=""; task_id=""; artifact=""; scope=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature) feature="$2"; shift 2 ;;
    --phase-dir) phase_dir="$2"; shift 2 ;;
    --unit) unit="$2"; shift 2 ;;
    --task-id) task_id="$2"; shift 2 ;;
    --artifact) artifact="$2"; shift 2 ;;
    --scope) scope="$2"; shift 2 ;;
  esac
done
decision="$(
  python3 - "$ROOT" "$PROFILE" "$ROLE" "$feature" "$phase_dir" "$unit" "$task_id" "$artifact" "$scope" <<'PY'
import json
import os
import re
import sys
from pathlib import Path
root = Path(sys.argv[1])
profile_path = Path(sys.argv[2])
role, feature_arg, phase_arg, unit_arg, task_id, artifact_arg, scope_arg = sys.argv[3:10]
catalog = json.loads(profile_path.read_text(encoding="utf-8"))
profile = catalog["roles"][role]
stage = profile["stage"]
def resolve_feature(value):
    candidate = Path(value).expanduser()
    if candidate.is_absolute():
        return candidate.resolve()
    repo_relative = root / candidate
    if repo_relative.exists():
        return repo_relative.resolve()
    if candidate.parts and candidate.parts[0] == "docs":
        return repo_relative.resolve()
    return (root / "docs" / candidate).resolve()
def resolve_phase(feature_dir, value):
    if not value:
        return None
    candidate = Path(value).expanduser()
    if candidate.is_absolute():
        return candidate.resolve()
    repo_relative = root / candidate
    if repo_relative.exists():
        return repo_relative.resolve()
    return (feature_dir / value).resolve()
def unit_slug(unit):
    match = re.search(r"(\d+)$", unit)
    return f"unit-{match.group(1)}" if match else unit.lower()

feature_dir = resolve_feature(feature_arg)
phase_dir = resolve_phase(feature_dir, phase_arg)
unit_dir = phase_dir / unit_slug(unit_arg) if phase_dir and unit_arg else None
def path_for(input_name):
    if input_name == "workspace":
        return feature_dir
    if input_name == "registry-bundle":
        return root / "contracts/canonical/registry-bundle.yaml"
    if input_name == "brief-template":
        return root / "contracts/canonical/templates/planning/director/brief.template.json"
    if input_name == "phase-prd-template":
        return root / "contracts/canonical/templates/planning/director/phase-prd.template.json"
    if input_name == "brief":
        return feature_dir / "brief.json"
    if phase_dir is None:
        return None
    developer_report = (unit_dir / "tasks" / task_id / "developer-report.json") if unit_dir and task_id else next(iter(sorted(phase_dir.glob("unit-*/tasks/*/developer-report.json"))), None)
    verify_result = (unit_dir / "tasks" / task_id / "verify-result.json") if unit_dir and task_id else next(iter(sorted(phase_dir.glob("unit-*/tasks/*/verify-result.json"))), None)
    mapping = {
        "phase-prd": phase_dir / "phase-prd.json",
        "product-review": phase_dir / "phase-prd.json",
        "project-context": phase_dir,
        "unit-definitions": phase_dir / "units",
        "unit-definition": phase_dir / "units" / f"{unit_arg}.json",
        "design": phase_dir / "design.json",
        "test-cases": (unit_dir / "test-cases.json") if unit_dir else next(iter(sorted(phase_dir.glob("unit-*/test-cases.json"))), phase_dir / "unit-1/test-cases.json"),
        "artifact-registry": phase_dir / "artifact-registry.json",
        "plan": phase_dir / "plan.json",
        "tasks": phase_dir / "tasks.json",
        "task-scope": phase_dir / "tasks.json",
        "design-refs": phase_dir / "tasks.json",
        "developer-report": developer_report,
        "verify-result": verify_result,
        "review-scope": phase_dir / "tasks.json",
        "code-review-result": phase_dir / "code-review-result.json",
        "qa-handoff": (unit_dir / "test-cases.json") if unit_dir else next(iter(sorted(phase_dir.glob("unit-*/test-cases.json"))), phase_dir / "unit-1/test-cases.json"),
        "execution-entry": (unit_dir / "test-cases.json") if unit_dir else next(iter(sorted(phase_dir.glob("unit-*/test-cases.json"))), phase_dir / "unit-1/test-cases.json"),
        "director-confirmation": phase_dir / "phase-prd.json",
    }
    return mapping.get(input_name)
loaded = {}
def display_path(path):
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return str(path)
def emit(code, message, evidence):
    print(json.dumps({
        "failure_code": code,
        "message": message,
        "evidence_refs": evidence,
    }, sort_keys=True))
    raise SystemExit(0)
def load_json(path):
    if path in loaded:
        return loaded[path]
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as exc:
        emit("MALFORMED_ARTIFACT", f"Malformed or unreadable canonical artifact: {display_path(path)} ({type(exc).__name__})", [f"file://{path}"])
    loaded[path] = data
    return data
def has_confirmed_status(value):
    if not isinstance(value, dict):
        return False
    status = str(value.get("status", "")).lower()
    return status in {"pass", "passed", "confirm", "confirmed", "ready"}
def flatten_strings(value):
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        result = []
        for item in value:
            result.extend(flatten_strings(item))
        return result
    if isinstance(value, dict):
        result = []
        for item in value.values():
            result.extend(flatten_strings(item))
        return result
    return []
def normalize_scope(value):
    normalized = value.strip().replace("\\", "/")
    while normalized.startswith("./"):
        normalized = normalized[2:]
    return normalized.rstrip("/")
def is_authorized_scope(requested, declared):
    request = normalize_scope(requested)
    if not request or request.startswith("/") or request.startswith("../") or "/../" in request:
        return False
    for item in declared:
        allowed = normalize_scope(item)
        if request == allowed or request.startswith(f"{allowed}/"):
            return True
    return False
def declared_task_scopes(task):
    declared = set()
    for field in ("shared_files", "files", "file_range", "task_scope"):
        for value in flatten_strings(task.get(field)):
            normalized = normalize_scope(value)
            if normalized:
                declared.add(normalized)
    return declared
def check_special(input_name, path):
    data = load_json(path) if path.is_file() and path.suffix == ".json" else None
    if input_name == "director-confirmation":
        if not isinstance(data, dict) or not has_confirmed_status(data.get("director_confirmation")):
            emit("MISSING_HUMAN_CONFIRMATION", "Director confirmation is missing or not confirmed.", [f"file://{path}"])
    if input_name == "product-review":
        review = data.get("review_conclusion") if isinstance(data, dict) else None
        verdict = review.get("verdict") if isinstance(review, dict) else None
        if verdict != "PASS":
            emit("MISSING_HUMAN_CONFIRMATION", "PM product review confirmation is missing or not PASS.", [f"file://{path}"])
    if input_name == "artifact-registry":
        active = data.get("active_revision_id") if isinstance(data, dict) else None
        revisions = data.get("revisions") if isinstance(data, dict) else []
        entries = []
        for revision in revisions if isinstance(revisions, list) else []:
            if isinstance(revision, dict) and revision.get("revision_id") == active:
                entries = revision.get("entries") if isinstance(revision.get("entries"), list) else []
        if not isinstance(active, str) or not entries:
            emit("AMBIGUOUS_TARGET", "Artifact registry has no active dispatch target.", [f"file://{path}"])
        required = {"scope_ref", "artifact_id", "artifact_type", "version", "artifact_path", "lifecycle_state", "produced_by"}
        consumable_entries = 0; active_types = set(); required_types = {"delivery-owner": {"plan", "tasks", "test-cases"}, "qa": {"plan", "tasks", "test-cases", "code-review-result"}}.get(role, set())
        for entry in entries:
            entry_type = entry.get("artifact_type") if isinstance(entry, dict) else None
            active_final = isinstance(entry, dict) and entry.get("active_for_consumption") is True and entry.get("lifecycle_state") == "FINALIZED"
            if active_final and entry_type in required_types and not (isinstance(entry.get("artifact_path"), str) and entry.get("artifact_path")):
                emit("MISSING_ARTIFACT", "Artifact registry target path is missing: artifact_path", [f"file://{path}"])
            has_strings = isinstance(entry, dict) and all(isinstance(entry.get(key), str) and entry.get(key) for key in required)
            if not has_strings or not isinstance(entry.get("active_for_consumption"), bool):
                emit("AMBIGUOUS_TARGET", "Artifact registry active entry is malformed.", [f"file://{path}"])
            if active_final:
                consumable_entries += 1
                active_types.add(entry_type)
                if entry_type in required_types:
                    target = Path(entry["artifact_path"]).expanduser()
                    if target.is_absolute() or ".." in target.parts:
                        emit("UNAUTHORIZED_SCOPE", f"Artifact registry target path escapes the phase: {entry['artifact_path']}", [f"file://{path}"])
                    target = phase_dir / target
                    if phase_dir.resolve() not in target.resolve().parents and target.resolve() != phase_dir.resolve():
                        emit("UNAUTHORIZED_SCOPE", f"Artifact registry target path escapes the phase: {entry['artifact_path']}", [f"file://{path}"])
                    if not target.exists():
                        emit("MISSING_ARTIFACT", f"Artifact registry target path is missing: {entry['artifact_path']}", [f"file://{path}"])
                    if not target.is_file() or target.suffix != ".json":
                        emit("MALFORMED_ARTIFACT", f"Artifact registry target is not a JSON file: {entry['artifact_path']}", [f"file://{path}"])
                    load_json(target)
        if consumable_entries == 0:
            emit("AMBIGUOUS_TARGET", "Artifact registry active revision has no consumable entry.", [f"file://{path}"])
        missing_types = sorted(required_types - active_types)
        if missing_types:
            emit("AMBIGUOUS_TARGET", f"Artifact registry active revision is missing consumable types: {', '.join(missing_types)}", [f"file://{path}"])
    if input_name == "task-scope":
        tasks = data.get("tasks", []) if isinstance(data, dict) else []
        task = next((item for item in tasks if isinstance(item, dict) and item.get("task_id") == task_id), None)
        if not task:
            emit("MISSING_ARTIFACT", f"Task {task_id} is not declared in tasks.json.", [f"file://{path}"])
        if not (task.get("shared_files") or task.get("files") or task.get("file_range") or task.get("task_scope")):
            emit("UNAUTHORIZED_SCOPE", f"Task {task_id} has no declared write scope.", [f"file://{path}"])
        requested = [value for value in (artifact_arg, scope_arg) if value]
        if requested:
            declared = declared_task_scopes(task)
            for value in requested:
                if not is_authorized_scope(value, declared):
                    emit("UNAUTHORIZED_SCOPE", f"Requested scope is not declared for task {task_id}: {value}", [f"file://{path}"])
    if input_name == "design-refs":
        tasks = data.get("tasks", []) if isinstance(data, dict) else []
        task = next((item for item in tasks if isinstance(item, dict) and item.get("task_id") == task_id), None)
        if not task or not task.get("design_refs"):
            emit("MISSING_ARTIFACT", f"Task {task_id} has no design_refs.", [f"file://{path}"])
    if role == "review" and input_name in {"developer-report", "verify-result"}:
        filename = f"{input_name}.json"
        data = load_json(phase_dir / "tasks.json")
        for task in data.get("tasks", []) if isinstance(data, dict) else []:
            current_task_id = task.get("task_id") if isinstance(task, dict) else None
            refs = task.get("unit_refs", []) if isinstance(task, dict) else []
            units = [f"unit-{m.group(1)}" for ref in refs if isinstance(ref, str) for m in [re.search(r"unit[-_](\d+)", ref)] if m]
            if not current_task_id or not units:
                emit("MISSING_ARTIFACT", "Review task evidence cannot resolve declared unit refs.", [f"file://{phase_dir / 'tasks.json'}"])
            for slug in units:
                evidence_path = phase_dir / slug / "tasks" / current_task_id / filename
                if not evidence_path.exists():
                    emit("MISSING_ARTIFACT", f"{filename} is missing for declared task {current_task_id}.", [f"file://{evidence_path}"])
                load_json(evidence_path)
    if input_name == "design":
        if isinstance(data, dict) and data.get("unresolved_decisions"):
            emit("HANDOFF_NOT_READY", "Design artifact still has unresolved decisions.", [f"file://{path}"])
    if input_name == "qa-handoff":
        if not isinstance(data, dict) or not data.get("qa_handoff_contract"):
            emit("HANDOFF_NOT_READY", "QA handoff contract is missing.", [f"file://{path}"])
    if input_name == "execution-entry":
        if not isinstance(data, dict) or not data.get("qa_handoff_contract"):
            emit("HANDOFF_NOT_READY", "QA execution entry conditions are missing.", [f"file://{path}"])
def check_stale_refs() -> None:
    if phase_dir is None:
        return
    plan_path = phase_dir / "plan.json"
    if not plan_path.is_file():
        return
    plan = load_json(plan_path)
    if not isinstance(plan, dict):
        return
    plan_version = plan.get("plan_version")
    if not isinstance(plan_version, str) or not plan_version:
        return
    for path, data in list(loaded.items()):
        if not isinstance(data, dict):
            continue
        for key in ("baseline_plan_version_ref", "active_plan_version_ref"):
            value = data.get(key)
            if isinstance(value, str) and "@" in value:
                version = value.split("@", 1)[1].split("#", 1)[0]
                if version != plan_version:
                    emit("STALE_EVIDENCE", f"{key} points to {version}, expected {plan_version}.", [f"file://{path}"])
for check in profile.get("checks", []):
    for input_name in check.get("required_inputs", []):
        path = path_for(input_name)
        if path is None:
            emit(check["failure_code"], f"Required input {input_name} cannot be resolved.", [f"profile://{role}/{check['check_id']}"])
        if input_name == "workspace":
            if path.exists() and not path.is_dir():
                emit("UNAUTHORIZED_SCOPE", f"Workspace target is not a directory: {path}", [f"file://{path}"])
            parent = path if path.exists() else path.parent
            if not parent.exists():
                emit("UNAUTHORIZED_SCOPE", f"Workspace parent does not exist: {parent}", [f"file://{parent}"])
            if not parent.is_dir():
                emit("UNAUTHORIZED_SCOPE", f"Workspace parent is not a directory: {parent}", [f"file://{parent}"])
            if not os.access(parent, os.W_OK):
                emit("UNAUTHORIZED_SCOPE", f"Workspace parent is not writable: {parent}", [f"file://{parent}"])
            continue
        if not path.exists():
            emit(check["failure_code"], f"Required input {input_name} is missing: {path}", [f"file://{path}"])
        if path.is_file() and path.suffix == ".json":
            load_json(path)
        check_special(input_name, path)
check_stale_refs()
emit("NONE", f"{role} preflight passed.", [f"profile://{role}#{stage}"])
PY
)"
failure_code="$(python3 - "$decision" <<'PY'
import json
import sys
print(json.loads(sys.argv[1])["failure_code"])
PY
)"
message="$(python3 - "$decision" <<'PY'
import json
import sys
print(json.loads(sys.argv[1])["message"])
PY
)"
evidence_refs=()
while IFS= read -r ref; do
  evidence_refs+=("$ref")
done < <(python3 - "$decision" <<'PY'
import json
import sys
for ref in json.loads(sys.argv[1])["evidence_refs"]:
    print(ref)
PY
)
routing_args=(--stage "$stage" --failure-code "$failure_code" --user-message "$message")
if [[ "$failure_code" == "NONE" ]]; then
  routing_args+=(--owner "$ROLE")
fi
for ref in "${evidence_refs[@]}"; do
  routing_args+=(--evidence-ref "$ref")
done
sc_emit_routing_json "${routing_args[@]}"
[[ "$failure_code" == "NONE" ]]
