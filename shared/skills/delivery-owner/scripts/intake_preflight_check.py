#!/usr/bin/env python3
"""Validate delivery-owner intake inputs for a frozen tech-lead tasks baseline."""

from __future__ import annotations

import argparse
import json
import sys
from json import JSONDecodeError
from pathlib import Path
from typing import Any


class IntakeFailure(Exception):
    def __init__(
        self,
        code: str,
        decision: str,
        owner: str,
        reason: str,
        missing_inputs: list[str] | None = None,
    ) -> None:
        super().__init__(reason)
        self.code = code
        self.decision = decision
        self.owner = owner
        self.reason = reason
        self.missing_inputs = missing_inputs or []


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    return parser.parse_args(argv)


def load_json(path: Path, missing_name: str) -> dict[str, Any]:
    if not path.is_file():
        raise IntakeFailure(
            "MISSING_INPUT",
            "NEEDS_INPUT",
            "delivery-owner",
            f"missing required file: {path}",
            [missing_name],
        )
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError as exc:
        raise IntakeFailure(
            "INVALID_JSON",
            "NEEDS_INPUT",
            "delivery-owner",
            f"malformed JSON: {path}: {exc}",
            [missing_name],
        ) from exc
    if not isinstance(payload, dict):
        raise IntakeFailure(
            "INVALID_JSON",
            "NEEDS_INPUT",
            "delivery-owner",
            f"top-level JSON must be an object: {path}",
            [missing_name],
        )
    return payload


def nonempty_strings(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, str) and item.strip()]


def acceptance_basis(task: dict[str, Any]) -> list[str]:
    basis: list[str] = []
    for key in ("test_refs", "acceptance_targets", "ac_refs", "acceptance_criteria"):
        value = task.get(key)
        if isinstance(value, str) and value.strip():
            basis.append(value)
        else:
            basis.extend(nonempty_strings(value))
    return sorted(set(basis))


def active_registry_entries(registry: dict[str, Any]) -> list[dict[str, Any]]:
    active_revision_id = registry.get("active_revision_id")
    revisions = registry.get("revisions")
    if not isinstance(active_revision_id, str) or not isinstance(revisions, list):
        raise IntakeFailure(
            "INVALID_ARTIFACT_REGISTRY",
            "NEEDS_INPUT",
            "delivery-owner",
            "artifact-registry.json must contain active_revision_id and revisions",
            ["artifact-registry.json"],
        )
    for revision in revisions:
        if (
            isinstance(revision, dict)
            and revision.get("revision_id") == active_revision_id
        ):
            entries = revision.get("entries")
            if isinstance(entries, list):
                return [entry for entry in entries if isinstance(entry, dict)]
    raise IntakeFailure(
        "INVALID_ARTIFACT_REGISTRY",
        "NEEDS_INPUT",
        "delivery-owner",
        f"artifact-registry active revision not found: {active_revision_id}",
        ["artifact-registry.active_revision_id"],
    )


def active_test_case_paths(phase_dir: Path, registry: dict[str, Any]) -> list[Path]:
    paths: list[Path] = []
    for entry in active_registry_entries(registry):
        if (
            entry.get("artifact_type") != "test-cases"
            or entry.get("active_for_consumption") is not True
        ):
            continue
        artifact_path = entry.get("artifact_path")
        if isinstance(artifact_path, str) and artifact_path.strip():
            paths.append(phase_dir / artifact_path)
    if not paths:
        paths = sorted(phase_dir.glob("unit-*/test-cases.json"))
    if not paths:
        raise IntakeFailure(
            "MISSING_QA_HANDOFF",
            "NEEDS_BASELINE",
            "test-design",
            "no test-cases artifact found for QA handoff",
            ["test-cases"],
        )
    return paths


def validate_test_cases(phase_dir: Path, registry: dict[str, Any]) -> int:
    handoff_count = 0
    for path in active_test_case_paths(phase_dir, registry):
        payload = load_json(path, str(path.relative_to(phase_dir)))
        design_gap_report = payload.get("design_gap_report")
        gaps = (
            design_gap_report.get("gaps") if isinstance(design_gap_report, dict) else []
        )
        if isinstance(gaps, list):
            blocking = [
                gap.get("gap_id", "<unknown>")
                for gap in gaps
                if isinstance(gap, dict) and gap.get("blocking") is True
            ]
            if blocking:
                raise IntakeFailure(
                    "BLOCKING_DESIGN_GAP",
                    "NEEDS_BASELINE",
                    "design",
                    f"test-cases has blocking design gaps: {', '.join(map(str, blocking))}",
                    ["test-cases.design_gap_report"],
                )
        qa_handoff = payload.get("qa_handoff_contract")
        if not isinstance(qa_handoff, list) or not qa_handoff:
            raise IntakeFailure(
                "MISSING_QA_HANDOFF",
                "NEEDS_BASELINE",
                "test-design",
                f"{path.relative_to(phase_dir)} must contain non-empty qa_handoff_contract",
                ["test-cases.qa_handoff_contract"],
            )
        handoff_count += len(qa_handoff)
    return handoff_count


def assert_tech_lead(payload: dict[str, Any], artifact: str) -> None:
    producer = payload.get("producer")
    if producer != "tech-lead":
        raise IntakeFailure(
            "BASELINE_NOT_TECH_LEAD",
            "NEEDS_BASELINE",
            "tech-lead",
            f"{artifact} must be produced by tech-lead",
            [artifact],
        )


def assert_confirmed(tasks_payload: dict[str, Any]) -> None:
    confirmation = tasks_payload.get("user_confirmation")
    status = confirmation.get("status") if isinstance(confirmation, dict) else None
    if str(status).upper() not in {"CONFIRMED", "确认"}:
        raise IntakeFailure(
            "BASELINE_NOT_CONFIRMED",
            "NEEDS_BASELINE",
            "tech-lead",
            "tasks user_confirmation.status must be CONFIRMED before delivery control",
            ["tasks.user_confirmation.status"],
        )


def validate_tasks(tasks_payload: dict[str, Any]) -> dict[str, Any]:
    tasks = tasks_payload.get("tasks")
    if not isinstance(tasks, list) or not tasks:
        raise IntakeFailure(
            "NO_TASKS",
            "NEEDS_BASELINE",
            "tech-lead",
            "tasks.json must contain a non-empty tasks array",
            ["tasks"],
        )

    task_ids: list[str] = []
    dependency_errors: list[str] = []
    missing_acceptance: list[str] = []
    for index, task in enumerate(tasks):
        if not isinstance(task, dict):
            raise IntakeFailure(
                "INVALID_TASK",
                "NEEDS_BASELINE",
                "tech-lead",
                f"task at index {index} must be an object",
                [f"tasks[{index}]"],
            )
        task_id = task.get("task_id")
        if not isinstance(task_id, str) or not task_id.strip():
            raise IntakeFailure(
                "INVALID_TASK",
                "NEEDS_BASELINE",
                "tech-lead",
                f"task at index {index} has no task_id",
                [f"tasks[{index}].task_id"],
            )
        task_ids.append(task_id)
        if not acceptance_basis(task):
            missing_acceptance.append(task_id)

    known = set(task_ids)
    for task in tasks:
        for dependency in nonempty_strings(task.get("depends_on")):
            if dependency not in known:
                dependency_errors.append(f"{task.get('task_id')}->{dependency}")
    if dependency_errors:
        raise IntakeFailure(
            "DEPENDENCY_DRIFT",
            "NEEDS_BASELINE",
            "tech-lead",
            f"task dependencies reference unknown task ids: {', '.join(dependency_errors)}",
            ["tasks.depends_on"],
        )
    if missing_acceptance:
        raise IntakeFailure(
            "MISSING_ACCEPTANCE",
            "NEEDS_BASELINE",
            "tech-lead",
            f"tasks missing acceptance basis: {', '.join(missing_acceptance)}",
            ["task.acceptance_basis"],
        )
    return {"task_count": len(tasks), "task_ids": task_ids}


def success_payload(
    phase_dir: Path,
    tasks_payload: dict[str, Any],
    task_summary: dict[str, Any],
    qa_handoff_count: int,
) -> dict[str, Any]:
    return {
        "status": "PASS",
        "decision": "ACCEPTED",
        "phase_dir": str(phase_dir),
        "plan_version": tasks_payload.get("plan_version"),
        "task_count": task_summary["task_count"],
        "task_ids": task_summary["task_ids"],
        "qa_handoff_count": qa_handoff_count,
        "safe_to_dispatch": True,
    }


def failure_payload(exc: IntakeFailure) -> dict[str, Any]:
    return {
        "status": "BLOCKED",
        "decision": exc.decision,
        "failure_code": exc.code,
        "owner": exc.owner,
        "reason": exc.reason,
        "missing_inputs": exc.missing_inputs,
        "safe_to_dispatch": False,
    }


def validate(args: argparse.Namespace) -> dict[str, Any]:
    phase_dir = args.phase_dir
    if not phase_dir.is_dir():
        raise IntakeFailure(
            "MISSING_PHASE_DIR",
            "NEEDS_INPUT",
            "delivery-owner",
            f"phase-dir not found: {phase_dir}",
            ["phase-dir"],
        )
    tasks = load_json(phase_dir / "tasks.json", "tasks.json")
    registry = load_json(phase_dir / "artifact-registry.json", "artifact-registry.json")
    assert_tech_lead(tasks, "tasks.json")
    assert_confirmed(tasks)
    task_summary = validate_tasks(tasks)
    qa_handoff_count = validate_test_cases(phase_dir, registry)
    return success_payload(phase_dir, tasks, task_summary, qa_handoff_count)


def emit(payload: dict[str, Any], output: Path | None) -> None:
    text = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    if output:
        output.write_text(text + "\n", encoding="utf-8")
    print(text)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        payload = validate(args)
    except IntakeFailure as exc:
        emit(failure_payload(exc), args.output)
        return 1
    emit(payload, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
