#!/usr/bin/env python3
"""Resolve canonical artifact refs through the active artifact-registry snapshot only."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def load_json(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path} 顶层必须是对象")
    return data


def get_active_revision(registry: dict) -> dict:
    active_revision_id = registry.get("active_revision_id")
    revisions = registry.get("revisions")
    if not isinstance(active_revision_id, str) or not isinstance(revisions, list):
        raise ValueError("artifact-registry 缺少 active_revision_id 或 revisions")
    for revision in revisions:
        if revision.get("revision_id") == active_revision_id:
            return revision
    raise ValueError(f"找不到 active revision: {active_revision_id}")


def split_artifact_ref(ref: str) -> tuple[str, str, str, str]:
    try:
        scheme, target = ref.split("://", 1)
        artifact_target, anchor = target.split("#", 1)
        artifact_type, versioned_id = artifact_target.split("/", 1)
        artifact_id, version = versioned_id.rsplit("@", 1)
    except ValueError as exc:
        raise ValueError(f"非法 canonical ref: {ref}") from exc
    if scheme != "artifact":
        raise ValueError(f"非法 ref scheme: {ref}")
    return artifact_type, artifact_id, version, anchor


def resolve_artifact_ref(ref: str, registry_path: Path) -> Path:
    registry = load_json(registry_path)
    artifact_type, artifact_id, version, _anchor = split_artifact_ref(ref)
    active_revision = get_active_revision(registry)
    active_revision_id = active_revision.get(
        "revision_id", registry.get("active_revision_id")
    )
    target = f"{artifact_type}/{artifact_id}@{version}"
    for entry in active_revision.get("entries", []):
        if not entry.get("active_for_consumption"):
            continue
        if entry.get("lifecycle_state") != "FINALIZED":
            raise ValueError(
                f"active entry must be FINALIZED: {entry.get('artifact_id')}"
            )
        if (
            entry["artifact_type"] == artifact_type
            and entry["artifact_id"] == artifact_id
            and entry["version"] == version
        ):
            return Path(entry["artifact_path"])
    raise FileNotFoundError(
        f"{target} not found in active revision {active_revision_id}"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", type=Path, required=True)
    parser.add_argument("--ref", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    resolved = resolve_artifact_ref(args.ref, args.registry.resolve())
    print(resolved.as_posix())


if __name__ == "__main__":
    main()
