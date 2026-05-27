"""Scope registry validation for active context contracts."""

from __future__ import annotations

from pathlib import Path

from context_contract_common import ACTIVE_STATUSES, PHASES, block
from runtime_yaml import load_yaml


def load_registry(root: Path) -> dict:
    path = root / "contracts" / "active-doc-scope.yaml"
    if not path.is_file():
        block(
            "scope_registry_missing",
            path,
            "readable scope registry",
            "missing",
            "create contracts/active-doc-scope.yaml",
        )
    try:
        registry = load_yaml(path)
    except Exception as exc:
        block(
            "scope_registry_unreadable",
            path,
            "parseable yaml",
            exc,
            "repair scope registry yaml",
        )
    if registry.get("version") != 2:
        block(
            "scope_registry_schema_invalid",
            path,
            "version: 2",
            registry.get("version"),
            "migrate registry to version 2",
        )
    phase = registry.get("context_contract_phase")
    if phase not in PHASES:
        block(
            "context_contract_phase_invalid",
            path,
            "bootstrap/enforce/cleanup",
            phase,
            "set context_contract_phase",
        )
    if not isinstance(registry.get("scope_entries"), list):
        block(
            "scope_registry_schema_invalid",
            path,
            "scope_entries list",
            "missing",
            "add scope_entries",
        )
    return registry


def entry_status(entry: dict, phase: str) -> str | None:
    target = entry.get("management_status")
    compat = entry.get("status")
    if target and compat and target != compat and phase != "bootstrap":
        block(
            "registry_compat_field_conflict",
            "contracts/active-doc-scope.yaml",
            "status matches management_status",
            f"{compat} != {target}",
            "align target and compatibility fields",
        )
    return target or (compat if phase == "bootstrap" else None)


def validate_active_entry(root: Path, entry: dict) -> None:
    path = root / str(entry["feature_path"])
    if not path.is_dir():
        block(
            "feature_path_unreachable",
            "contracts/active-doc-scope.yaml",
            "existing feature_path",
            entry["feature_path"],
            "restore feature path or update registry",
        )
    for field in ["mode", "layout", "entry_ref", "context_owner"]:
        if not entry.get(field):
            block(
                "scope_registry_schema_invalid",
                "contracts/active-doc-scope.yaml",
                f"entry has {field}",
                entry,
                f"add {field}",
            )
    if entry["mode"] != "standard-chain":
        block(
            "scope_registry_schema_invalid",
            "contracts/active-doc-scope.yaml",
            "valid mode",
            entry["mode"],
            "use standard-chain",
        )
    entry_path = path / str(entry["entry_ref"])
    if not entry_path.is_file():
        block(
            "entry_ref_unreachable",
            entry_path,
            "reachable worklog entry",
            "missing",
            "restore worklog or update entry_ref",
        )


def validate_registry_entries(
    root: Path, registry: dict
) -> tuple[list[dict], list[dict]]:
    phase = str(registry["context_contract_phase"])
    active: list[dict] = []
    legacy: list[dict] = []
    seen: set[str] = set()
    for entry in registry["scope_entries"]:
        if not isinstance(entry, dict):
            block(
                "scope_registry_schema_invalid",
                "contracts/active-doc-scope.yaml",
                "entry object",
                entry,
                "repair scope entry",
            )
        status = entry_status(entry, phase)
        if status == "legacy":
            legacy.append(entry)
            continue
        if status not in ACTIVE_STATUSES:
            continue
        feature_path = entry.get("feature_path")
        if not isinstance(feature_path, str) or not feature_path:
            block(
                "scope_registry_schema_invalid",
                "contracts/active-doc-scope.yaml",
                "feature_path",
                feature_path,
                "add feature_path",
            )
        if feature_path in seen:
            block(
                "duplicate_active_feature",
                "contracts/active-doc-scope.yaml",
                "one active entry per feature_path",
                feature_path,
                "archive or merge duplicate active entry",
            )
        seen.add(feature_path)
        validate_active_entry(root, entry)
        active.append(entry)
    return active, legacy
