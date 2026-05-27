"""Repository-level context contract validation."""

from __future__ import annotations

import re
from pathlib import Path

from context_contract_common import SUPPORTING_REQUIRED, block
from context_contract_registry import load_registry, validate_registry_entries
from context_contract_worklog import validate_worklog, validate_worklog_at
from runtime_yaml import load_yaml


def validate_legacy_entry(root: Path, entry: dict) -> None:
    archive_ref = entry.get("archive_ref")
    if not archive_ref or not entry.get("archived_at"):
        block(
            "archive_lifecycle_incomplete",
            "contracts/active-doc-scope.yaml",
            "legacy entry has archive_ref and archived_at",
            entry,
            "complete archive lifecycle fields",
        )
    archive_path = root / str(archive_ref)
    if not archive_path.is_dir():
        block(
            "archive_ref_unreachable",
            "contracts/active-doc-scope.yaml",
            "reachable archive_ref",
            archive_ref,
            "restore archive or update archive_ref",
        )
    validate_worklog_at(root, archive_path, entry)


def validate_owner_keys(path: Path, owners: dict) -> None:
    for owner in [
        "context_registry_owner",
        "context_contract_owner",
        "context_validator_owner",
    ]:
        if not owners.get(owner):
            block(
                "ownership_contract_invalid",
                path,
                f"repo owner {owner}",
                "missing",
                "add repo owner",
            )


def validate_owned_artifact(
    root: Path, path: Path, owners: dict, artifact: dict
) -> None:
    if artifact.get("artifact_owner") not in owners:
        block(
            "ownership_contract_invalid",
            path,
            "artifact_owner resolves",
            artifact,
            "use repo owner key",
        )
    if not artifact.get("path") or not (root / str(artifact["path"])).exists():
        block(
            "ownership_contract_invalid",
            path,
            "artifact path exists",
            artifact.get("path"),
            "restore artifact path",
        )
    for field in ["update_triggers", "mechanical_checks"]:
        if not isinstance(artifact.get(field), list) or not artifact[field]:
            block(
                "ownership_contract_invalid",
                path,
                f"{field} non-empty",
                artifact,
                f"add {field}",
            )


def validate_ownership(root: Path) -> None:
    path = root / "contracts" / "context-artifact-ownership.yaml"
    if not path.is_file():
        block(
            "ownership_contract_missing",
            path,
            "ownership contract",
            "missing",
            "create context-artifact-ownership.yaml",
        )
    try:
        data = load_yaml(path)
    except Exception as exc:
        block(
            "ownership_contract_invalid",
            path,
            "parseable ownership yaml",
            exc,
            "repair ownership contract",
        )
    owners = data.get("repo_owners")
    artifacts = data.get("artifacts")
    if (
        data.get("version") != 1
        or not isinstance(owners, dict)
        or not isinstance(artifacts, list)
    ):
        block(
            "ownership_contract_invalid",
            path,
            "version, repo_owners, artifacts",
            data,
            "repair ownership contract",
        )
    validate_owner_keys(path, owners)
    for artifact in artifacts:
        if not isinstance(artifact, dict):
            block(
                "ownership_contract_invalid",
                path,
                "artifact object",
                artifact,
                "repair artifact entry",
            )
        validate_owned_artifact(root, path, owners, artifact)


def validate_supporting_docs(root: Path) -> None:
    docs_root = root / "docs"
    if not docs_root.exists():
        return
    for path in docs_root.glob("feature--*/supporting/**/*.md"):
        text = path.read_text(encoding="utf-8")
        for field in SUPPORTING_REQUIRED:
            if re.search(rf"(^|\n)-\s*{field}:", text) is None:
                block(
                    "supporting_metadata_missing",
                    path,
                    f"supporting doc has {field}",
                    "missing",
                    "add purpose/serves/reason_here metadata",
                )


def validate_repo(root: Path) -> None:
    registry = load_registry(root)
    active_entries, legacy_entries = validate_registry_entries(root, registry)
    for entry in legacy_entries:
        validate_legacy_entry(root, entry)
    validate_ownership(root)
    for entry in active_entries:
        validate_worklog(root, entry)
    validate_supporting_docs(root)
