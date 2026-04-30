#!/usr/bin/env python3
"""Validate delivery-owner intake inputs for a frozen tech-lead plan."""

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


def task_scope(task: dict[str, Any]) -> list[str]:
    scope: list[str] = []
    for key in ("file_range", "files", "task_scope", "scope"):
        value = task.get(key)
        if isinstance(value, str) and value.strip():
            scope.append(value)
        else:
            scope.extend(nonempty_strings(value))
    return sorted(set(scope))


def acceptance_basis(task: dict[str, Any]) -> list[str]:
    basis: list[str] = []
    for key in ("test_refs", "acceptance_targets", "ac_refs", "acceptance_criteria"):
        value = task.get(key)
        if isinstance(value, str) and value.strip():
            basis.append(value)
        else:
            basis.extend(nonempty_strings(value))
    return sorted(set(basis))


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


def assert_confirmed(plan: dict[str, Any]) -> None:
    confirmation = plan.get("user_confirmation")
    status = confirmation.get("status") if isinstance(confirmation, dict) else None
    if str(status).upper() not in {"CONFIRMED", "确认"}:
        raise IntakeFailure(
            "BASELINE_NOT_CONFIRMED",
            "NEEDS_BASELINE",
            "tech-lead",
            "plan user_confirmation.status must be CONFIRMED before delivery control",
            ["plan.user_confirmation.status"],
        )


def validate_tasks(plan: dict[str, Any], tasks_payload: dict[str, Any]) -> dict[str, Any]:
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
    missing_scope: list[str] = []
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
        if not task_scope(task):
            missing_scope.append(task_id)
        if not acceptance_basis(task):
            missing_acceptance.append(task_id)

    known = set(task_ids)
    for task in tasks:
        for dependency in nonempty_strings(task.get("depends_on")):
            if dependency not in known:
                dependency_errors.append(f"{task.get('task_id')}->{dependency}")

    plan_task_list = nonempty_strings(plan.get("task_list"))
    missing_from_tasks = sorted(set(plan_task_list) - known)
    if missing_from_tasks:
        raise IntakeFailure(
            "TASK_LIST_DRIFT",
            "NEEDS_BASELINE",
            "tech-lead",
            f"plan.task_list references missing task ids: {', '.join(missing_from_tasks)}",
            ["plan.task_list", "tasks"],
        )
    if dependency_errors:
        raise IntakeFailure(
            "DEPENDENCY_DRIFT",
            "NEEDS_BASELINE",
            "tech-lead",
            f"task dependencies reference unknown task ids: {', '.join(dependency_errors)}",
            ["tasks.depends_on"],
        )
    if missing_scope:
        raise IntakeFailure(
            "MISSING_SCOPE",
            "NEEDS_BASELINE",
            "tech-lead",
            f"tasks missing writable scope: {', '.join(missing_scope)}",
            ["task.scope"],
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


def success_payload(phase_dir: Path, plan: dict[str, Any], task_summary: dict[str, Any]) -> dict[str, Any]:
    return {
        "status": "PASS",
        "decision": "ACCEPTED",
        "phase_dir": str(phase_dir),
        "plan_version": plan.get("plan_version"),
        "task_count": task_summary["task_count"],
        "task_ids": task_summary["task_ids"],
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
    plan = load_json(phase_dir / "plan.json", "plan.json")
    tasks = load_json(phase_dir / "tasks.json", "tasks.json")
    assert_tech_lead(plan, "plan.json")
    assert_tech_lead(tasks, "tasks.json")
    assert_confirmed(plan)
    task_summary = validate_tasks(plan, tasks)
    return success_payload(phase_dir, plan, task_summary)


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
