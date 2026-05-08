#!/usr/bin/env python3
"""Validate developer task inputs."""

from __future__ import annotations

import argparse
import json
import sys
from json import JSONDecodeError
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPO_ROOT / "tools" / "community"))

from canonical_ref_resolver import get_active_revision, split_artifact_ref  # noqa: E402


FAILURE_OWNER = {
    "MISSING_INPUT": "delivery-owner",
    "AMBIGUOUS_SCOPE": "delivery-owner",
    "UNRESOLVED_REF": "delivery-owner",
    "SCHEMA_FAILURE": "developer",
}


class PreflightFailure(Exception):
    def __init__(self, code: str, reason: str):
        super().__init__(reason)
        self.code = code
        self.reason = reason


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-dir", type=Path, required=True)
    parser.add_argument("--task-id", required=True)
    return parser.parse_args(argv)


def load_json(path: Path, failure_code: str = "MISSING_INPUT") -> dict[str, Any]:
    if not path.is_file():
        raise PreflightFailure(failure_code, f"missing required file: {path}")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError as exc:
        raise PreflightFailure(
            "SCHEMA_FAILURE", f"malformed JSON: {path}: {exc}"
        ) from exc
    if not isinstance(payload, dict):
        raise PreflightFailure(
            "SCHEMA_FAILURE", f"top-level JSON must be an object: {path}"
        )
    return payload


def failure_payload(exc: PreflightFailure) -> dict[str, Any]:
    return {
        "status": "BLOCKED",
        "failure_code": exc.code,
        "owner": FAILURE_OWNER[exc.code],
        "reason": exc.reason,
    }


def find_task(tasks: dict[str, Any], task_id: str) -> dict[str, Any]:
    for task in tasks.get("tasks", []):
        if isinstance(task, dict) and task.get("task_id") == task_id:
            return task
    raise PreflightFailure("MISSING_INPUT", f"task not found in tasks.json: {task_id}")


def string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, str) and item]


def active_entries(
    registry: dict[str, Any],
) -> dict[tuple[str, str, str], dict[str, Any]]:
    try:
        revision = get_active_revision(registry)
    except ValueError as exc:
        raise PreflightFailure(
            "UNRESOLVED_REF",
            f"artifact-registry active revision is not resolvable: {exc}",
        ) from exc
    entries = revision.get("entries")
    if not isinstance(entries, list) or not entries:
        raise PreflightFailure(
            "UNRESOLVED_REF", "artifact-registry active revision has no entries"
        )
    result: dict[tuple[str, str, str], dict[str, Any]] = {}
    for entry in entries:
        if not isinstance(entry, dict) or not entry.get("active_for_consumption"):
            continue
        if entry.get("lifecycle_state") != "FINALIZED":
            continue
        key = (
            entry.get("artifact_type"),
            entry.get("artifact_id"),
            entry.get("version"),
        )
        if all(isinstance(part, str) and part for part in key):
            result[key] = entry
    if not result:
        raise PreflightFailure(
            "UNRESOLVED_REF", "artifact-registry has no FINALIZED active entries"
        )
    return result


def resolve_ref(
    ref: str, index: dict[tuple[str, str, str], dict[str, Any]]
) -> dict[str, Any]:
    try:
        artifact_type, artifact_id, version, anchor = split_artifact_ref(ref)
    except ValueError as exc:
        raise PreflightFailure(
            "UNRESOLVED_REF", f"invalid artifact ref: {ref}"
        ) from exc
    entry = index.get((artifact_type, artifact_id, version))
    if entry is None:
        raise PreflightFailure(
            "UNRESOLVED_REF", f"ref not found in active artifact-registry: {ref}"
        )
    return {**entry, "anchor": anchor, "ref": ref}


def load_ref_artifact(phase_dir: Path, entry: dict[str, Any]) -> dict[str, Any]:
    artifact_path = entry.get("artifact_path")
    if not isinstance(artifact_path, str) or not artifact_path:
        raise PreflightFailure(
            "UNRESOLVED_REF",
            f"active artifact has no artifact_path: {entry.get('ref')}",
        )
    return load_json(phase_dir / artifact_path)


def validate_test_ref(phase_dir: Path, entry: dict[str, Any]) -> None:
    test_cases = load_ref_artifact(phase_dir, entry)
    anchor = entry.get("anchor")
    known_ac = {
        row.get("ac_id")
        for row in test_cases.get("ac_coverage_matrix", [])
        if isinstance(row, dict) and isinstance(row.get("ac_id"), str)
    }
    known_cases = {
        row.get("case_id")
        for row in test_cases.get("test_cases", [])
        if isinstance(row, dict) and isinstance(row.get("case_id"), str)
    }
    if anchor and anchor not in known_ac and anchor not in known_cases:
        raise PreflightFailure(
            "UNRESOLVED_REF", f"test_ref anchor not found: {entry.get('ref')}"
        )
    assertions = [
        row.get("assertion_target")
        for row in test_cases.get("test_cases", [])
        if isinstance(row, dict)
    ]
    if not any(isinstance(item, str) and item.strip() for item in assertions):
        raise PreflightFailure(
            "MISSING_INPUT", "test-cases.json lacks assertion_target"
        )


def validate(args: argparse.Namespace) -> dict[str, Any]:
    phase_dir = args.phase_dir
    if not phase_dir.is_dir():
        raise PreflightFailure("MISSING_INPUT", f"phase-dir not found: {phase_dir}")
    registry = load_json(phase_dir / "artifact-registry.json")
    load_json(phase_dir / "design.json")
    tasks = load_json(phase_dir / "tasks.json")
    task = find_task(tasks, args.task_id)
    index = active_entries(registry)
    refs = string_list(task.get("design_refs")) + string_list(task.get("test_refs"))
    if not refs:
        raise PreflightFailure(
            "MISSING_INPUT", f"task has no design_refs or test_refs: {args.task_id}"
        )
    resolved = [resolve_ref(ref, index) for ref in refs]
    for entry in resolved:
        if entry.get("artifact_type") == "test-cases":
            validate_test_ref(phase_dir, entry)
    return {
        "status": "PASS",
        "task_id": args.task_id,
    }


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        result = validate(args)
    except PreflightFailure as exc:
        print(json.dumps(failure_payload(exc), ensure_ascii=False, sort_keys=True))
        return 1
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
