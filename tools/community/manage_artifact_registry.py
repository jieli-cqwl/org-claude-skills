#!/usr/bin/env python3
"""Validate and evolve append-only artifact-registry snapshots for runtime consumption."""

from __future__ import annotations

import argparse
import copy
import json
import sys
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


def entry_identity(entry: dict) -> tuple[str, str, str]:
    return (
        entry["artifact_type"],
        entry["artifact_id"],
        entry["version"],
    )


def assert_active_uniqueness(entries: list[dict]) -> None:
    seen: set[tuple[str, str]] = set()
    for entry in entries:
        if not entry.get("active_for_consumption"):
            continue
        if entry.get("lifecycle_state") != "FINALIZED":
            raise ValueError(f"active entry must be FINALIZED: {entry.get('artifact_id')}")
        key = (entry["artifact_type"], entry["artifact_id"], entry["scope_ref"])
        if key in seen:
            raise ValueError(f"duplicate active entry: {key}")
        seen.add(key)


def assert_append_only(registry: dict) -> None:
    revisions = registry.get("revisions")
    active_revision_id = registry.get("active_revision_id")
    if not isinstance(revisions, list) or not revisions:
        raise ValueError("artifact-registry missing revisions")
    revision_ids: list[str] = []
    previous_id: str | None = None
    for revision in revisions:
        revision_id = revision.get("revision_id")
        if not isinstance(revision_id, str):
            raise ValueError("revision_id 必须存在")
        if revision_id in revision_ids:
            raise ValueError(f"duplicate revision_id: {revision_id}")
        if previous_id is not None and revision.get("parent_revision_id") != previous_id:
            raise ValueError(f"revision {revision_id} parent is not append-only")
        revision_ids.append(revision_id)
        previous_id = revision_id
    if active_revision_id != revision_ids[-1]:
        raise ValueError("active_revision_id must point to last revision")


def entry_tuple(entry: dict) -> tuple[str, str, str, str, str, bool]:
    return (
        entry["artifact_type"],
        entry["artifact_id"],
        entry["version"],
        entry["artifact_path"],
        entry["lifecycle_state"],
        entry["active_for_consumption"],
    )


def restore_tuple(entry: dict) -> tuple[str, str, str, tuple[str, ...]]:
    return (
        entry["artifact_type"],
        entry["artifact_id"],
        entry["version"],
        tuple(entry.get("restore_basis_refs", [])),
    )


def append_revision(registry: dict, new_entries: list[dict], appended_at: str) -> dict:
    result = copy.deepcopy(registry)
    assert_append_only(result)
    next_revision_id = f"rev-{len(result['revisions']) + 1}"
    assert_active_uniqueness(new_entries)
    snapshot = {
        "revision_id": next_revision_id,
        "parent_revision_id": result["active_revision_id"],
        "appended_at": appended_at,
        "entries": new_entries,
    }
    result["revisions"].append(snapshot)
    result["active_revision_id"] = next_revision_id
    result["registry_revision"] = next_revision_id
    result["produced_at"] = appended_at
    return result


def restore_quarantined_entries(
    registry: dict,
    restored_entries: list[dict],
    restore_basis_refs: list[str],
    appended_at: str,
) -> dict:
    if not restore_basis_refs:
        raise ValueError("restore_basis_refs 不能为空")

    current_entries = copy.deepcopy(get_active_revision(registry).get("entries", []))
    current_quarantined = {
        entry_identity(entry)
        for entry in current_entries
        if entry.get("lifecycle_state") == "QUARANTINED"
    }
    index_by_key = {
        entry_identity(entry): idx
        for idx, entry in enumerate(current_entries)
    }
    for restored in restored_entries:
        key = entry_identity(restored)
        if key not in current_quarantined:
            raise ValueError(f"restore target is not currently quarantined: {key}")
        entry = copy.deepcopy(restored)
        entry["lifecycle_state"] = "FINALIZED"
        entry["active_for_consumption"] = True
        entry["restore_basis_refs"] = restore_basis_refs
        if key in index_by_key:
            current_entries[index_by_key[key]] = entry
        else:
            current_entries.append(entry)
    return append_revision(registry, current_entries, appended_at)


def assert_restore_result(
    result: dict,
    expected_active_revision_id: str,
    expected_tuples: list[list],
    expected_restore_tuples: list[list],
) -> None:
    if result.get("active_revision_id") != expected_active_revision_id:
        raise ValueError("restore 后 active_revision_id 不符合预期")
    last_revision = result["revisions"][-1]
    actual = [list(entry_tuple(entry)) for entry in last_revision["entries"] if entry.get("restore_basis_refs")]
    if actual != expected_tuples:
        raise ValueError(f"restore entry tuples mismatch: {actual} != {expected_tuples}")
    actual_restore = [
        [artifact_type, artifact_id, version, list(restore_basis_refs)]
        for artifact_type, artifact_id, version, restore_basis_refs in (
            restore_tuple(entry)
            for entry in last_revision["entries"]
            if entry.get("restore_basis_refs")
        )
    ]
    if actual_restore != expected_restore_tuples:
        raise ValueError(
            f"restore basis tuples mismatch: {actual_restore} != {expected_restore_tuples}"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--check-active", action="store_true")
    parser.add_argument("--check-append-only", action="store_true")
    parser.add_argument("--check-restore", action="store_true")
    parser.add_argument("--apply-restore", action="store_true")
    return parser.parse_args()


def dump_json(document: dict) -> None:
    json.dump(document, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")


def main() -> None:
    args = parse_args()
    enabled = [
        args.check_active,
        args.check_append_only,
        args.check_restore,
        args.apply_restore,
    ]
    if sum(bool(flag) for flag in enabled) != 1:
        raise SystemExit("必须且只能选择一个检查模式")

    payload = load_json(args.fixture.resolve())
    if args.check_active:
        assert_active_uniqueness(get_active_revision(payload).get("entries", []))
        return
    if args.check_append_only:
        assert_append_only(payload)
        return
    result = restore_quarantined_entries(
        payload["registry"],
        payload["restored_entries"],
        payload["restore_basis_refs"],
        payload["appended_at"],
    )
    if args.apply_restore:
        dump_json(result)
        return
    assert_restore_result(
        result,
        payload["expected_active_revision_id"],
        payload["expected_restore_entry_tuples"],
        payload["expected_restore_basis_tuples"],
    )


if __name__ == "__main__":
    main()
