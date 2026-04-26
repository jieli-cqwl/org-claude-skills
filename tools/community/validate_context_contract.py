#!/usr/bin/env python3
"""Validate active context handoff registry, worklog, refs, and ownership contracts."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from datetime import date
from pathlib import Path
from typing import Any

from runtime_yaml import load_yaml


ACTIVE_STATUSES = {"managed", "migrated"}
PHASES = {"bootstrap", "enforce", "cleanup"}
HANDOFF_STATUSES = {"doing", "blocked", "done"}
SMALL_CHAIN_STAGES = {"entry", "plan", "env", "execute", "verify-preflight", "verify", "integrate", "finish", "blocked"}
STANDARD_CHAIN_STAGES = {"PLANNING", "TASK_DISPATCH", "TASK_EXECUTION", "TASK_VERIFICATION", "PHASE_REVIEW", "PHASE_QA", "SIGNOFF_PENDING", "SIGNOFF_RECORDED", "CLOSED", "BLOCKED", "REPLAN_PENDING"}
WORKLOG_REQUIRED_FIELDS = {"actor", "context_owner", "mode", "stage", "scope_ref", "handoff_status", "state_ref", "next", "next_ref"}
BLOCKED_REQUIRED_FIELDS = {"blocker", "waiting_on", "unblock_condition", "decision_needed"}
CANONICAL_REF = re.compile(r"^canonical:(?P<registry>[^:]+)::artifact://(?P<type>[^/]+)/(?P<id>[^@]+)@(?P<version>[^#]+)#(?P<anchor>.+)$")
RECORD_FIELD = re.compile(r"^- ([a-z_]+):\s*(.*)$")
TASK_ID_RE = re.compile(r"^\s*[-*]\s+\[[ xX]\]\s+(T\d+)\b")
PLAN_ID_RE = re.compile(r"\[(T\d+)\]")


@dataclass
class Finding:
    decision: str
    reason: str
    path: str
    expected: str
    actual: str = ""


def add(findings: list[Finding], reason: str, path: Path | str, expected: str, actual: object = "") -> None:
    findings.append(Finding("block", reason, str(path), expected, str(actual)))


def add_report(findings: list[Finding], reason: str, path: Path | str, expected: str, actual: object = "") -> None:
    findings.append(Finding("report", reason, str(path), expected, str(actual)))


def load_json(path: Path, findings: list[Finding]) -> dict[str, Any] | None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        add(findings, "json_unreadable", path, "valid JSON object", exc)
        return None
    if not isinstance(data, dict):
        add(findings, "json_root_invalid", path, "JSON object")
        return None
    return data


def load_yaml_dict(path: Path, findings: list[Finding]) -> dict[str, Any] | None:
    try:
        data = load_yaml(path)
    except (OSError, ValueError) as exc:
        add(findings, "yaml_unreadable", path, "valid YAML object", exc)
        return None
    if not isinstance(data, dict):
        add(findings, "yaml_root_invalid", path, "YAML object")
        return None
    return data


def registry_status(entry: dict[str, Any]) -> str:
    return str(entry.get("management_status") or entry.get("status") or "")


def validate_registry(root: Path, findings: list[Finding]) -> list[dict[str, Any]]:
    registry_path = root / "contracts" / "active-doc-scope.yaml"
    if not registry_path.is_file():
        add(findings, "scope_registry_missing", registry_path, "contracts/active-doc-scope.yaml")
        return []
    data = load_yaml_dict(registry_path, findings)
    if data is None:
        return []
    if data.get("version") != 2:
        add(findings, "scope_registry_version_invalid", registry_path, "version: 2", data.get("version"))
    if data.get("context_contract_phase") not in PHASES:
        add(findings, "context_contract_phase_invalid", registry_path, "context_contract_phase in bootstrap|enforce|cleanup", data.get("context_contract_phase"))
    entries = data.get("scope_entries") or []
    if not isinstance(entries, list):
        add(findings, "scope_entries_invalid", registry_path, "scope_entries list")
        return []
    active: list[dict[str, Any]] = []
    seen: set[str] = set()
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            add(findings, "scope_entry_invalid", registry_path, f"scope_entries[{index}] object")
            continue
        status = registry_status(entry)
        if status not in ACTIVE_STATUSES:
            continue
        active.append(entry)
        feature_path = str(entry.get("feature_path") or "")
        if feature_path in seen:
            add(findings, "duplicate_active_feature", registry_path, "one active entry per feature_path", feature_path)
        seen.add(feature_path)
        for field in ("feature_path", "mode", "management_status", "layout", "entry_ref", "context_owner"):
            if not str(entry.get(field) or "").strip():
                add(findings, "scope_entry_field_missing", registry_path, f"active entry field {field}", feature_path)
    return active


def parse_latest_worklog(path: Path, findings: list[Finding]) -> tuple[str, dict[str, str]]:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        add(findings, "worklog_unreadable", path, "readable worklog", exc)
        return "", {}
    match = re.search(r"^##\s+(.+?)\s*$", text, flags=re.MULTILINE)
    if not match:
        add(findings, "worklog_record_missing", path, "latest ## timestamp record")
        return "", {}
    start = match.end()
    next_match = re.search(r"^##\s+.+?\s*$", text[start:], flags=re.MULTILINE)
    block = text[start:] if next_match is None else text[start : start + next_match.start()]
    values: dict[str, str] = {}
    for line in block.splitlines():
        field_match = RECORD_FIELD.match(line.strip())
        if field_match:
            values[field_match.group(1)] = field_match.group(2).strip()
    return match.group(1).strip(), values


def strip_anchor(ref: str) -> tuple[str, str]:
    if "#" in ref:
        path, anchor = ref.split("#", 1)
        return path, anchor
    return ref, ""


def parse_tasks(path: Path, findings: list[Finding]) -> set[str]:
    if not path.is_file():
        add(findings, "small_chain_tasks_missing", path, "tasks.md")
        return set()
    ids: set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        match = TASK_ID_RE.match(line)
        if match:
            ids.add(match.group(1))
    if not ids:
        add(findings, "small_chain_tasks_empty", path, "at least one task id")
    return ids


def parse_plan(path: Path, findings: list[Finding]) -> set[str]:
    if not path.is_file():
        add(findings, "small_chain_plan_missing", path, "plan.md")
        return set()
    text = path.read_text(encoding="utf-8")
    ids = set(PLAN_ID_RE.findall(text))
    if not ids:
        add(findings, "small_chain_plan_empty", path, "at least one [Tn] reference")
    return ids


def validate_small_chain_ref(feature_root: Path, ref: str, worklog_path: Path, findings: list[Finding]) -> Path | None:
    ref_path, _anchor = strip_anchor(ref)
    if ref_path.startswith("/") or ".." in Path(ref_path).parts:
        add(findings, "small_chain_ref_invalid", worklog_path, "feature-relative markdown ref", ref)
        return None
    full_path = feature_root / ref_path
    if not full_path.is_file():
        add(findings, "state_ref_unreachable", worklog_path, "reachable state_ref or next_ref", ref)
        return None
    return full_path


def validate_small_chain(feature_root: Path, record: dict[str, str], worklog_path: Path, findings: list[Finding]) -> None:
    state_path = validate_small_chain_ref(feature_root, record["state_ref"], worklog_path, findings)
    next_path = validate_small_chain_ref(feature_root, record["next_ref"], worklog_path, findings)
    candidates = [path for path in (state_path, next_path) if path is not None]
    worksets = {path.parent for path in candidates}
    for workset in worksets:
        tasks = workset / "tasks.md"
        plan = workset / "plan.md"
        if tasks.is_file() or plan.is_file():
            task_ids = parse_tasks(tasks, findings)
            plan_ids = parse_plan(plan, findings)
            if task_ids and plan_ids and task_ids != plan_ids:
                add(findings, "small_chain_task_plan_drift", workset, "tasks.md ids match plan.md ids", f"tasks={sorted(task_ids)} plan={sorted(plan_ids)}")


def active_revision(registry: dict[str, Any], registry_path: Path, findings: list[Finding]) -> dict[str, Any] | None:
    active_id = registry.get("active_revision_id")
    revisions = registry.get("revisions")
    if not isinstance(active_id, str) or not isinstance(revisions, list):
        add(findings, "artifact_registry_invalid", registry_path, "active_revision_id and revisions")
        return None
    for revision in revisions:
        if isinstance(revision, dict) and revision.get("revision_id") == active_id:
            return revision
    add(findings, "artifact_registry_active_revision_missing", registry_path, "active revision exists", active_id)
    return None


def validate_canonical_ref(feature_root: Path, ref: str, worklog_path: Path, findings: list[Finding]) -> None:
    match = CANONICAL_REF.match(ref)
    if not match:
        add(findings, "canonical_ref_invalid", worklog_path, "canonical:{registry_relpath}::artifact://type/id@version#anchor", ref)
        return
    registry_relpath = match.group("registry")
    if registry_relpath.startswith("/") or ".." in Path(registry_relpath).parts:
        add(findings, "canonical_registry_ref_invalid", worklog_path, "feature-relative artifact-registry ref", registry_relpath)
        return
    registry_path = feature_root / registry_relpath
    if registry_path.name != "artifact-registry.json" or not registry_path.is_file():
        add(findings, "canonical_registry_missing", worklog_path, "reachable artifact-registry.json", registry_relpath)
        return
    registry = load_json(registry_path, findings)
    if registry is None:
        return
    revision = active_revision(registry, registry_path, findings)
    if revision is None:
        return
    for entry in revision.get("entries", []):
        if not isinstance(entry, dict) or not entry.get("active_for_consumption"):
            continue
        if entry.get("lifecycle_state") != "FINALIZED":
            add(findings, "canonical_active_entry_not_finalized", registry_path, "active entry lifecycle_state FINALIZED", entry.get("lifecycle_state"))
            return
        if (
            entry.get("artifact_type") == match.group("type")
            and entry.get("artifact_id") == match.group("id")
            and entry.get("version") == match.group("version")
        ):
            artifact_path = feature_root / registry_path.parent.relative_to(feature_root) / str(entry.get("artifact_path", ""))
            if not artifact_path.is_file():
                add(findings, "canonical_artifact_missing", registry_path, "active artifact_path exists", artifact_path)
            return
    add(findings, "canonical_active_ref_missing", registry_path, "active FINALIZED entry for canonical ref", ref)


def validate_standard_chain(feature_root: Path, record: dict[str, str], worklog_path: Path, findings: list[Finding]) -> None:
    validate_canonical_ref(feature_root, record["state_ref"], worklog_path, findings)
    validate_canonical_ref(feature_root, record["next_ref"], worklog_path, findings)
    scope_ref = record.get("scope_ref", "")
    delivery_state = feature_root / scope_ref / "delivery-state.json"
    if delivery_state.is_file():
        payload = load_json(delivery_state, findings)
        if payload and payload.get("current_stage") != record.get("stage"):
            add(findings, "standard_chain_stage_drift", delivery_state, "delivery-state.current_stage equals worklog.stage", record.get("stage"))


def validate_worklog(entry: dict[str, Any], root: Path, findings: list[Finding]) -> None:
    feature_path = str(entry.get("feature_path") or "")
    feature_root = root / feature_path
    if not feature_root.is_dir():
        add(findings, "feature_path_missing", root / "contracts" / "active-doc-scope.yaml", "existing feature_path", feature_path)
        return
    entry_ref = str(entry.get("entry_ref") or "worklog.md")
    worklog_path = feature_root / entry_ref
    if not worklog_path.is_file():
        add(findings, "worklog_missing", worklog_path, "entry_ref points to worklog.md")
        return
    _timestamp, record = parse_latest_worklog(worklog_path, findings)
    missing = sorted(WORKLOG_REQUIRED_FIELDS - set(record))
    if missing:
        add(findings, "worklog_required_field_missing", worklog_path, "required worklog fields", ",".join(missing))
        return
    mode = record["mode"]
    stage = record["stage"]
    if mode != entry.get("mode"):
        add(findings, "worklog_mode_drift", worklog_path, "worklog.mode equals registry mode", mode)
    if record["handoff_status"] not in HANDOFF_STATUSES:
        add(findings, "worklog_handoff_status_invalid", worklog_path, "doing|blocked|done", record["handoff_status"])
    if record["handoff_status"] == "blocked":
        missing_blocked = sorted(BLOCKED_REQUIRED_FIELDS - set(record))
        if missing_blocked:
            add(findings, "blocked_record_field_missing", worklog_path, "blocked fields", ",".join(missing_blocked))
    if mode == "small-chain":
        if stage not in SMALL_CHAIN_STAGES:
            add(findings, "worklog_stage_invalid", worklog_path, "small-chain stage", stage)
        validate_small_chain(feature_root, record, worklog_path, findings)
    elif mode == "standard-chain":
        if stage not in STANDARD_CHAIN_STAGES:
            add(findings, "worklog_stage_invalid", worklog_path, "standard-chain stage", stage)
        validate_standard_chain(feature_root, record, worklog_path, findings)
    else:
        add(findings, "worklog_mode_invalid", worklog_path, "small-chain|standard-chain", mode)


def validate_ownership_contract(root: Path, findings: list[Finding], require: bool = False) -> None:
    path = root / "contracts" / "context-artifact-ownership.yaml"
    if not path.exists():
        if require:
            add(findings, "ownership_contract_missing", path, "contracts/context-artifact-ownership.yaml")
        return
    data = load_yaml_dict(path, findings)
    if data is None:
        return
    artifacts = data.get("artifacts")
    if not isinstance(artifacts, list) or not artifacts:
        add(findings, "ownership_artifacts_missing", path, "non-empty artifacts list")
        return
    for index, artifact in enumerate(artifacts):
        if not isinstance(artifact, dict):
            add(findings, "ownership_artifact_invalid", path, f"artifacts[{index}] object")
            continue
        for field in ("artifact_id", "path", "artifact_owner"):
            if not str(artifact.get(field) or "").strip():
                add(findings, "ownership_artifact_field_missing", path, f"artifact field {field}", artifact.get("artifact_id", index))
        for field in ("update_triggers", "mechanical_checks"):
            value = artifact.get(field)
            if not isinstance(value, list) or not value:
                add(findings, "ownership_artifact_field_missing", path, f"non-empty {field}", artifact.get("artifact_id", index))


def collect_audit_findings(root: Path, active_entries: list[dict[str, Any]], findings: list[Finding]) -> None:
    for entry in active_entries:
        path = worklog_path_for_entry(root, entry)
        if path.is_file():
            latest_at, record = parse_latest_worklog(path, findings)
            if record.get("handoff_status") == "blocked":
                add_report(findings, "audit_long_blocked", path, "blocked item reviewed by owner", latest_at)
    for waiver in root.glob("docs/**/contract-waivers.md"):
        text = waiver.read_text(encoding="utf-8")
        for match in re.finditer(r"expires_at:\s*([0-9]{4}-[0-9]{2}-[0-9]{2})", text):
            expires_at = date.fromisoformat(match.group(1))
            if expires_at < date.today():
                add_report(findings, "audit_expired_waiver", waiver, "unexpired context waiver", match.group(1))
    for supporting in root.glob("docs/**/supporting/*"):
        if not supporting.is_file():
            continue
        text = supporting.read_text(encoding="utf-8")
        if not all(token in text for token in ("purpose:", "serves:", "reason_here:")):
            add_report(findings, "audit_supporting_metadata_missing", supporting, "purpose, serves, reason_here metadata")


def collect_legacy_audit_findings(root: Path, findings: list[Finding]) -> None:
    registry_path = root / "contracts" / "active-doc-scope.yaml"
    data = load_yaml_dict(registry_path, findings)
    if data is None:
        return
    for entry in data.get("scope_entries") or []:
        if not isinstance(entry, dict) or registry_status(entry) != "legacy":
            continue
        archive_ref = str(entry.get("archive_ref") or "")
        archived_at = str(entry.get("archived_at") or "")
        if not archive_ref or not archived_at or not (root / archive_ref).exists():
            add_report(findings, "audit_legacy_drift", registry_path, "legacy entry has archive_ref, archived_at, and existing archive path", entry.get("feature_path"))


def worklog_path_for_entry(root: Path, entry: dict[str, Any]) -> Path:
    return root / str(entry.get("feature_path") or "") / str(entry.get("entry_ref") or "worklog.md")


def validate_repository(root: Path, findings: list[Finding], mode: str = "blocking") -> None:
    active_entries = validate_registry(root, findings)
    validate_ownership_contract(root, findings, require=bool(active_entries))
    for entry in active_entries:
        validate_worklog(entry, root, findings)
    if mode == "audit":
        collect_audit_findings(root, active_entries, findings)
        collect_legacy_audit_findings(root, findings)


def emit_findings(findings: list[Finding], mode: str) -> int:
    if findings:
        decision = "block" if mode == "blocking" else "report"
        print(json.dumps({"decision": decision, "mode": mode, "findings": [asdict(f) for f in findings]}, ensure_ascii=False, indent=2))
        return 1 if mode == "blocking" else 0
    print(json.dumps({"decision": "pass", "mode": mode, "findings": []}, ensure_ascii=False, indent=2))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--mode", choices=["blocking", "audit"], default="blocking")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    findings: list[Finding] = []
    validate_repository(root, findings, mode=args.mode)
    return emit_findings(findings, args.mode)


if __name__ == "__main__":
    raise SystemExit(main())
