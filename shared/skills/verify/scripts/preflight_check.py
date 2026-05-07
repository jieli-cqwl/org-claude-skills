#!/usr/bin/env python3
"""Validate verify task inputs."""

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
    "DEVELOPER_REPORT_INVALID": "developer",
    "SCHEMA_FAILURE": "delivery-owner",
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
        raise PreflightFailure("SCHEMA_FAILURE", f"malformed JSON: {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise PreflightFailure("SCHEMA_FAILURE", f"top-level JSON must be an object: {path}")
    return payload


def failure_payload(exc: PreflightFailure) -> dict[str, Any]:
    return {
        "status": "BLOCKED",
        "failure_code": exc.code,
        "owner": FAILURE_OWNER[exc.code],
        "reason": exc.reason,
    }


def string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, str) and item]


def find_task(tasks: dict[str, Any], task_id: str) -> dict[str, Any]:
    for task in tasks.get("tasks", []):
        if isinstance(task, dict) and task.get("task_id") == task_id:
            return task
    raise PreflightFailure("MISSING_INPUT", f"task not found in tasks.json: {task_id}")


def task_scope(task: dict[str, Any]) -> list[str]:
    return sorted(set(string_list(task.get("file_range"))))


def active_entries(registry: dict[str, Any]) -> dict[tuple[str, str, str], dict[str, Any]]:
    try:
        revision = get_active_revision(registry)
    except ValueError as exc:
        raise PreflightFailure("UNRESOLVED_REF", f"artifact-registry active revision is not resolvable: {exc}") from exc
    entries = revision.get("entries")
    if not isinstance(entries, list) or not entries:
        raise PreflightFailure("UNRESOLVED_REF", "artifact-registry active revision has no entries")
    result: dict[tuple[str, str, str], dict[str, Any]] = {}
    for entry in entries:
        if not isinstance(entry, dict) or not entry.get("active_for_consumption"):
            continue
        if entry.get("lifecycle_state") != "FINALIZED":
            continue
        key = (entry.get("artifact_type"), entry.get("artifact_id"), entry.get("version"))
        if all(isinstance(part, str) and part for part in key):
            result[key] = entry
    if not result:
        raise PreflightFailure("UNRESOLVED_REF", "artifact-registry has no FINALIZED active entries")
    return result


def resolve_ref(ref: str, index: dict[tuple[str, str, str], dict[str, Any]]) -> dict[str, Any]:
    try:
        artifact_type, artifact_id, version, anchor = split_artifact_ref(ref)
    except ValueError as exc:
        raise PreflightFailure("UNRESOLVED_REF", f"invalid artifact ref: {ref}") from exc
    entry = index.get((artifact_type, artifact_id, version))
    if entry is None:
        raise PreflightFailure("UNRESOLVED_REF", f"ref not found in active artifact-registry: {ref}")
    return {**entry, "anchor": anchor, "ref": ref}


def load_ref_artifact(phase_dir: Path, entry: dict[str, Any]) -> dict[str, Any]:
    artifact_path = entry.get("artifact_path")
    if not isinstance(artifact_path, str) or not artifact_path:
        raise PreflightFailure("UNRESOLVED_REF", f"active artifact has no artifact_path: {entry.get('ref')}")
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
        raise PreflightFailure("UNRESOLVED_REF", f"test_ref anchor not found: {entry.get('ref')}")
    cases = [row for row in test_cases.get("test_cases", []) if isinstance(row, dict)]
    if not any(isinstance(row.get("assertion_target"), str) and row["assertion_target"].strip() for row in cases):
        raise PreflightFailure("MISSING_INPUT", "test-cases.json lacks assertion_target")
    if not any(isinstance(row.get("evidence_expectation"), str) and row["evidence_expectation"].strip() for row in cases):
        raise PreflightFailure("MISSING_INPUT", "test-cases.json lacks evidence_expectation")


def find_developer_report_entry(
    index: dict[tuple[str, str, str], dict[str, Any]], task_id: str
) -> dict[str, Any]:
    matches = []
    task_anchor = f"#task-{task_id}"
    task_path_suffix = f"/tasks/{task_id}/developer-report.json"
    task_id_fragment = f"task-{task_id}"
    for entry in index.values():
        if entry.get("artifact_type") != "developer-report":
            continue
        artifact_path = entry.get("artifact_path")
        scope_ref = entry.get("scope_ref")
        artifact_id = entry.get("artifact_id")
        if (
            isinstance(scope_ref, str)
            and scope_ref.endswith(task_anchor)
            or isinstance(artifact_path, str)
            and artifact_path.endswith(task_path_suffix)
            or isinstance(artifact_id, str)
            and task_id_fragment in artifact_id
        ):
            matches.append(entry)
    if not matches:
        raise PreflightFailure("MISSING_INPUT", f"developer-report not found for task: {task_id}")
    if len(matches) > 1:
        raise PreflightFailure("AMBIGUOUS_SCOPE", f"multiple developer-report entries found for task: {task_id}")
    return matches[0]


def validate_developer_report(report: dict[str, Any], task_id: str) -> None:
    if report.get("task_id") != task_id:
        raise PreflightFailure("DEVELOPER_REPORT_INVALID", f"developer-report task_id does not match: {task_id}")
    for key in ("reviewable_anchor", "active_tasks_version_ref"):
        if not isinstance(report.get(key), str) or not report[key].strip():
            raise PreflightFailure("DEVELOPER_REPORT_INVALID", f"developer-report missing {key}")
    if not string_list(report.get("file_changes")):
        raise PreflightFailure("DEVELOPER_REPORT_INVALID", "developer-report missing file_changes")
    rows = report.get("tdd_evidence_index")
    if not isinstance(rows, list) or len(rows) < 2:
        raise PreflightFailure("DEVELOPER_REPORT_INVALID", "developer-report missing TDD evidence index")
    phases = {row.get("phase") for row in rows if isinstance(row, dict)}
    if "RED" not in phases or "GREEN" not in phases:
        raise PreflightFailure("DEVELOPER_REPORT_INVALID", "developer-report TDD evidence must include RED and GREEN")
    for row in rows:
        if not isinstance(row, dict):
            raise PreflightFailure("DEVELOPER_REPORT_INVALID", "developer-report TDD evidence row must be an object")
        if row.get("phase") not in {"RED", "GREEN"}:
            raise PreflightFailure("DEVELOPER_REPORT_INVALID", "developer-report TDD phase must be RED or GREEN")
        if not isinstance(row.get("commit_sha"), str) or len(row["commit_sha"]) < 7:
            raise PreflightFailure("DEVELOPER_REPORT_INVALID", "developer-report TDD row missing commit_sha")
        if not isinstance(row.get("test_ref"), str) or not row["test_ref"].strip():
            raise PreflightFailure("DEVELOPER_REPORT_INVALID", "developer-report TDD row missing test_ref")
        if not string_list(row.get("ac_refs")):
            raise PreflightFailure("DEVELOPER_REPORT_INVALID", "developer-report TDD row missing ac_refs")


def validate(args: argparse.Namespace) -> dict[str, Any]:
    phase_dir = args.phase_dir
    if not phase_dir.is_dir():
        raise PreflightFailure("MISSING_INPUT", f"phase-dir not found: {phase_dir}")
    registry = load_json(phase_dir / "artifact-registry.json")
    load_json(phase_dir / "plan.json")
    tasks = load_json(phase_dir / "tasks.json")
    task = find_task(tasks, args.task_id)
    if not task_scope(task):
        raise PreflightFailure("AMBIGUOUS_SCOPE", f"task has no writable scope: {args.task_id}")
    index = active_entries(registry)
    refs = string_list(task.get("design_refs")) + string_list(task.get("test_refs"))
    if not string_list(task.get("test_refs")):
        raise PreflightFailure("MISSING_INPUT", f"task has no test_refs: {args.task_id}")
    resolved = [resolve_ref(ref, index) for ref in refs]
    for entry in resolved:
        if entry.get("artifact_type") == "test-cases":
            validate_test_ref(phase_dir, entry)
    developer_entry = find_developer_report_entry(index, args.task_id)
    report = load_ref_artifact(phase_dir, {**developer_entry, "ref": developer_entry.get("artifact_id")})
    validate_developer_report(report, args.task_id)
    resolve_ref(report["active_tasks_version_ref"], index)
    return {
        "status": "PASS",
        "task_id": args.task_id,
        "developer_report_path": developer_entry.get("artifact_path"),
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
