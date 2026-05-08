#!/usr/bin/env python3
"""Validate active context handoff contracts."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path

from canonical_ref_resolver import resolve_artifact_ref
from runtime_yaml import load_yaml


ACTIVE_STATUSES = {"managed", "migrated"}
PHASES = {"bootstrap", "enforce", "cleanup"}
STANDARD_STAGES = {
    "PLANNING",
    "TASK_DISPATCH",
    "TASK_EXECUTION",
    "TASK_VERIFICATION",
    "PHASE_REVIEW",
    "PHASE_QA",
    "SIGNOFF_PENDING",
    "SIGNOFF_RECORDED",
    "CLOSED",
    "BLOCKED",
    "REPLAN_PENDING",
}
WORKLOG_REQUIRED = [
    "actor",
    "context_owner",
    "mode",
    "stage",
    "scope_ref",
    "handoff_status",
    "state_ref",
    "next",
    "next_ref",
]
SUPPORTING_REQUIRED = ["purpose", "serves", "reason_here"]


@dataclass
class ContractFailure(Exception):
    reason: str
    path: str
    expected: str
    actual: str
    next_action: str


def block(reason: str, path: Path | str, expected: str, actual: object, next_action: str) -> None:
    raise ContractFailure(reason, str(path), expected, str(actual), next_action)


def emit_failure(error: ContractFailure) -> None:
    print("decision: block")
    print(f"reason: {error.reason}")
    print(f"path: {error.path}")
    print(f"expected: {error.expected}")
    print(f"actual: {error.actual}")
    print(f"next_action: {error.next_action}")


def load_registry(root: Path) -> dict:
    path = root / "contracts" / "active-doc-scope.yaml"
    if not path.is_file():
        block("scope_registry_missing", path, "readable scope registry", "missing", "create contracts/active-doc-scope.yaml")
    try:
        registry = load_yaml(path)
    except Exception as exc:
        block("scope_registry_unreadable", path, "parseable yaml", exc, "repair scope registry yaml")
    if registry.get("version") != 2:
        block("scope_registry_schema_invalid", path, "version: 2", registry.get("version"), "migrate registry to version 2")
    phase = registry.get("context_contract_phase")
    if phase not in PHASES:
        block("context_contract_phase_invalid", path, "bootstrap/enforce/cleanup", phase, "set context_contract_phase")
    if not isinstance(registry.get("scope_entries"), list):
        block("scope_registry_schema_invalid", path, "scope_entries list", "missing", "add scope_entries")
    return registry


def entry_status(entry: dict, phase: str) -> str | None:
    target = entry.get("management_status")
    compat = entry.get("status")
    if target and compat and target != compat and phase != "bootstrap":
        block("registry_compat_field_conflict", "contracts/active-doc-scope.yaml", "status matches management_status", f"{compat} != {target}", "align target and compatibility fields")
    return target or (compat if phase == "bootstrap" else None)


def validate_registry_entries(root: Path, registry: dict) -> list[dict]:
    phase = str(registry["context_contract_phase"])
    active: list[dict] = []
    seen: set[str] = set()
    for entry in registry["scope_entries"]:
        if not isinstance(entry, dict):
            block("scope_registry_schema_invalid", "contracts/active-doc-scope.yaml", "entry object", entry, "repair scope entry")
        status = entry_status(entry, phase)
        if status == "legacy":
            validate_legacy_entry(root, entry)
            continue
        if status not in ACTIVE_STATUSES:
            continue
        feature_path = entry.get("feature_path")
        if not isinstance(feature_path, str) or not feature_path:
            block("scope_registry_schema_invalid", "contracts/active-doc-scope.yaml", "feature_path", feature_path, "add feature_path")
        if feature_path in seen:
            block("duplicate_active_feature", "contracts/active-doc-scope.yaml", "one active entry per feature_path", feature_path, "archive or merge duplicate active entry")
        seen.add(feature_path)
        validate_active_entry(root, entry)
        active.append(entry)
    return active


def validate_active_entry(root: Path, entry: dict) -> None:
    path = root / str(entry["feature_path"])
    if not path.is_dir():
        block("feature_path_unreachable", "contracts/active-doc-scope.yaml", "existing feature_path", entry["feature_path"], "restore feature path or update registry")
    for field in ["mode", "layout", "entry_ref", "context_owner"]:
        if not entry.get(field):
            block("scope_registry_schema_invalid", "contracts/active-doc-scope.yaml", f"entry has {field}", entry, f"add {field}")
    if entry["mode"] != "standard-chain":
        block("scope_registry_schema_invalid", "contracts/active-doc-scope.yaml", "valid mode", entry["mode"], "use standard-chain")
    entry_path = path / str(entry["entry_ref"])
    if not entry_path.is_file():
        block("entry_ref_unreachable", entry_path, "reachable worklog entry", "missing", "restore worklog or update entry_ref")


def validate_legacy_entry(root: Path, entry: dict) -> None:
    archive_ref = entry.get("archive_ref")
    if not archive_ref or not entry.get("archived_at"):
        block("archive_lifecycle_incomplete", "contracts/active-doc-scope.yaml", "legacy entry has archive_ref and archived_at", entry, "complete archive lifecycle fields")
    archive_path = root / str(archive_ref)
    if not archive_path.is_dir():
        block("archive_ref_unreachable", "contracts/active-doc-scope.yaml", "reachable archive_ref", archive_ref, "restore archive or update archive_ref")
    validate_worklog_at(root, archive_path, entry)


def parse_latest_worklog(path: Path) -> dict:
    lines = path.read_text(encoding="utf-8").splitlines()
    start = next((i for i, line in enumerate(lines) if line.startswith("## ")), None)
    if start is None:
        block("worklog_block_missing", path, "latest ## timestamp block", "missing", "append a valid worklog block")
    fields: dict[str, str] = {}
    for line in lines[start + 1 :]:
        if line.startswith("## "):
            break
        match = re.match(r"^-\s+([A-Za-z_]+):\s*(.*)$", line)
        if match:
            fields[match.group(1)] = match.group(2).strip()
    return fields


def validate_worklog(root: Path, entry: dict) -> None:
    feature_dir = root / str(entry["feature_path"])
    validate_worklog_at(root, feature_dir, entry)


def validate_worklog_at(root: Path, feature_dir: Path, entry: dict) -> None:
    worklog_path = feature_dir / str(entry.get("entry_ref", "worklog.md"))
    if not worklog_path.is_file():
        block("entry_ref_unreachable", worklog_path, "reachable worklog entry", "missing", "restore worklog or update entry_ref")
    fields = parse_latest_worklog(worklog_path)
    validate_worklog_fields(worklog_path, entry, fields)
    validate_worklog_refs(root, feature_dir, entry, fields)


def validate_worklog_fields(worklog_path: Path, entry: dict, fields: dict) -> None:
    for field in WORKLOG_REQUIRED:
        if not fields.get(field):
            block("worklog_required_field_missing", worklog_path, f"required field {field}", "missing", "append correction worklog record")
    if fields["mode"] != entry["mode"]:
        block("worklog_mode_mismatch", worklog_path, "worklog mode matches registry", fields["mode"], "append correction worklog record")
    if fields["handoff_status"] not in {"doing", "blocked", "done"}:
        block("worklog_enum_invalid", worklog_path, "handoff_status doing/blocked/done", fields["handoff_status"], "append correction worklog record")
    if fields["stage"] not in STANDARD_STAGES:
        block("worklog_enum_invalid", worklog_path, "valid standard-chain stage", fields["stage"], "append correction worklog record")
    if fields["handoff_status"] == "blocked":
        for field in ["blocker", "waiting_on", "unblock_condition"]:
            if not fields.get(field):
                block("blocked_field_missing", worklog_path, f"blocked record has {field}", "missing", "append complete blocked record")
    if fields["handoff_status"] == "done" and not fields.get("next_ref"):
        block("done_next_ref_missing", worklog_path, "done record keeps next_ref", "missing", "append correction record with next_ref")


def validate_worklog_refs(root: Path, feature_dir: Path, entry: dict, fields: dict) -> None:
    resolve_standard_ref(feature_dir, fields["state_ref"], "state_ref", fields["stage"])
    resolve_standard_ref(feature_dir, fields["next_ref"], "next_ref", fields["stage"])


def split_repo_ref(ref: str) -> tuple[str, str | None]:
    if "#" not in ref:
        return ref, None
    relpath, anchor = ref.split("#", 1)
    return relpath, anchor


def markdown_anchor_exists(path: Path, anchor: str | None) -> bool:
    if not anchor:
        return True
    text = path.read_text(encoding="utf-8")
    if re.search(rf"\b{re.escape(anchor)}\b", text):
        return True
    slug = anchor.lower().replace("-", " ")
    return any(line.startswith("#") and slug in line.lower().replace("-", " ") for line in text.splitlines())


def resolve_standard_ref(feature_dir: Path, ref: str, field: str, stage: str) -> None:
    if not ref.startswith("canonical:") or "::" not in ref:
        block("standard_ref_grammar_invalid", feature_dir / "worklog.md", "canonical:<registry>::artifact://...", ref, "use canonical active artifact ref")
    registry_rel, artifact_ref = ref.removeprefix("canonical:").split("::", 1)
    registry_path = feature_dir / registry_rel
    if registry_path.name != "artifact-registry.json" or not registry_path.is_file():
        block("canonical_ref_unreachable", feature_dir / "worklog.md", "reachable artifact-registry", ref, "restore artifact-registry or append corrected worklog")
    try:
        artifact_rel = resolve_artifact_ref(artifact_ref, registry_path)
    except Exception as exc:
        block("canonical_ref_unreachable", feature_dir / "worklog.md", "active finalized artifact ref", exc, "restore active revision or update canonical ref")
    artifact_path = registry_path.parent / artifact_rel
    if not artifact_path.is_file():
        block("canonical_ref_unreachable", feature_dir / "worklog.md", "reachable active artifact path", artifact_path, "restore active artifact")
    delivery_state = registry_path.parent / "delivery-state.json"
    if delivery_state.is_file():
        state = json.loads(delivery_state.read_text(encoding="utf-8"))
        if state.get("current_stage") != stage:
            block("standard_stage_drift", feature_dir / "worklog.md", "worklog.stage matches delivery-state.current_stage", state.get("current_stage"), "append correction worklog record")


def validate_ownership(root: Path) -> None:
    path = root / "contracts" / "context-artifact-ownership.yaml"
    if not path.is_file():
        block("ownership_contract_missing", path, "ownership contract", "missing", "create context-artifact-ownership.yaml")
    try:
        data = load_yaml(path)
    except Exception as exc:
        block("ownership_contract_invalid", path, "parseable ownership yaml", exc, "repair ownership contract")
    owners = data.get("repo_owners")
    artifacts = data.get("artifacts")
    if data.get("version") != 1 or not isinstance(owners, dict) or not isinstance(artifacts, list):
        block("ownership_contract_invalid", path, "version, repo_owners, artifacts", data, "repair ownership contract")
    for owner in ["context_registry_owner", "context_contract_owner", "context_validator_owner"]:
        if not owners.get(owner):
            block("ownership_contract_invalid", path, f"repo owner {owner}", "missing", "add repo owner")
    for artifact in artifacts:
        if not isinstance(artifact, dict):
            block("ownership_contract_invalid", path, "artifact object", artifact, "repair artifact entry")
        if artifact.get("artifact_owner") not in owners:
            block("ownership_contract_invalid", path, "artifact_owner resolves", artifact, "use repo owner key")
        if not artifact.get("path") or not (root / str(artifact["path"])).exists():
            block("ownership_contract_invalid", path, "artifact path exists", artifact.get("path"), "restore artifact path")
        for field in ["update_triggers", "mechanical_checks"]:
            if not isinstance(artifact.get(field), list) or not artifact[field]:
                block("ownership_contract_invalid", path, f"{field} non-empty", artifact, f"add {field}")


def validate_supporting_docs(root: Path) -> None:
    docs_root = root / "docs"
    if not docs_root.exists():
        return
    for path in docs_root.glob("feature--*/supporting/**/*.md"):
        text = path.read_text(encoding="utf-8")
        for field in SUPPORTING_REQUIRED:
            if re.search(rf"(^|\n)-\s*{field}:", text) is None:
                block("supporting_metadata_missing", path, f"supporting doc has {field}", "missing", "add purpose/serves/reason_here metadata")


def validate_repo(root: Path) -> None:
    registry = load_registry(root)
    active_entries = validate_registry_entries(root, registry)
    validate_ownership(root)
    for entry in active_entries:
        validate_worklog(root, entry)
    validate_supporting_docs(root)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        validate_repo(args.repo_root.resolve())
    except ContractFailure as error:
        emit_failure(error)
        return 1
    except Exception as exc:
        emit_failure(
            ContractFailure(
                "validator_unavailable",
                str(args.repo_root),
                "context validator completes blocking checks",
                str(exc),
                "fix validator error before continuing",
            )
        )
        return 1
    print("[PASS] context contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
