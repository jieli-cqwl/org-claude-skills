#!/usr/bin/env python3
"""Validate delivery-owner intake inputs for a frozen tech-lead tasks baseline."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

from intake_common import IntakeFailure, load_json, nonempty_strings
from intake_handoff import validate_test_cases


def resolve_runtime_root(script_path: Path) -> Path:
    resolved = script_path.resolve()
    candidates = [
        *resolved.parents[:6],
        Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")),
        Path(os.environ.get("CLAUDE_HOME", Path.home() / ".claude")),
    ]
    for candidate in candidates:
        if (
            candidate / "tools" / "community" / "validate_product_closure.py"
        ).is_file():
            return candidate
    return resolved.parents[4]


RUNTIME_ROOT = resolve_runtime_root(Path(__file__))
sys.path.insert(0, str(RUNTIME_ROOT / "tools" / "community"))

from validate_product_closure import assert_confirmation, assert_director_lock  # noqa: E402


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    return parser.parse_args(argv)


def split_artifact_ref(ref: str) -> tuple[str, str, str, str]:
    try:
        scheme, target = ref.split("://", 1)
        artifact_target, anchor = target.split("#", 1)
        artifact_type, versioned_id = artifact_target.split("/", 1)
        artifact_id, version = versioned_id.rsplit("@", 1)
    except ValueError as exc:
        raise IntakeFailure(
            "INVALID_CANONICAL_REF",
            "NEEDS_BASELINE",
            "tech-lead",
            f"invalid canonical artifact ref: {ref}",
            ["plan.baseline_tasks_version_ref"],
        ) from exc
    if scheme != "artifact":
        raise IntakeFailure(
            "INVALID_CANONICAL_REF",
            "NEEDS_BASELINE",
            "tech-lead",
            f"invalid canonical artifact ref scheme: {ref}",
            ["plan.baseline_tasks_version_ref"],
        )
    return artifact_type, artifact_id, version, anchor


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


def assert_director_lock_intact(payload: dict[str, Any], label: str) -> None:
    try:
        assert_confirmation(payload, "director_confirmation", "passed", label)
        assert_director_lock(payload, label)
    except ValueError as exc:
        raise IntakeFailure(
            "DIRECTOR_LOCK_DRIFT",
            "NEEDS_BASELINE",
            "product-manager",
            str(exc),
            [f"{label}.director_confirmation.locked_field_digest"],
        ) from exc


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


def assert_plan_ready(
    plan_payload: dict[str, Any], tasks_payload: dict[str, Any]
) -> None:
    assert_tech_lead(plan_payload, "plan.json")
    planning_readiness = plan_payload.get("planning_readiness")
    status = (
        planning_readiness.get("status")
        if isinstance(planning_readiness, dict)
        else None
    )
    blocking_gaps = (
        planning_readiness.get("blocking_gaps")
        if isinstance(planning_readiness, dict)
        else None
    )
    if status != "READY" or blocking_gaps:
        raise IntakeFailure(
            "PLAN_NOT_READY",
            "NEEDS_BASELINE",
            "tech-lead",
            "plan planning_readiness.status must be READY with no blocking_gaps",
            ["plan.planning_readiness"],
        )
    confirmation = plan_payload.get("user_confirmation")
    confirmation_status = (
        confirmation.get("status") if isinstance(confirmation, dict) else None
    )
    if str(confirmation_status).upper() not in {"CONFIRMED", "确认"}:
        raise IntakeFailure(
            "PLAN_NOT_CONFIRMED",
            "NEEDS_BASELINE",
            "tech-lead",
            "plan user_confirmation.status must be CONFIRMED before baseline audit",
            ["plan.user_confirmation.status"],
        )
    if plan_payload.get("plan_version") != tasks_payload.get("plan_version"):
        raise IntakeFailure(
            "PLAN_TASK_VERSION_DRIFT",
            "NEEDS_BASELINE",
            "tech-lead",
            "plan.json plan_version must match tasks.json plan_version",
            ["plan.plan_version", "tasks.plan_version"],
        )
    tasks_ref = plan_payload.get("baseline_tasks_version_ref")
    if not isinstance(tasks_ref, str):
        raise IntakeFailure(
            "PLAN_TASK_REF_DRIFT",
            "NEEDS_BASELINE",
            "tech-lead",
            "plan baseline_tasks_version_ref must be a canonical tasks ref",
            ["plan.baseline_tasks_version_ref"],
        )
    ref_type, ref_artifact_id, _ref_version, ref_anchor = split_artifact_ref(tasks_ref)
    if (
        ref_type != "tasks"
        or ref_artifact_id != tasks_payload.get("artifact_id")
        or ref_anchor != "task-registry"
    ):
        raise IntakeFailure(
            "PLAN_TASK_REF_DRIFT",
            "NEEDS_BASELINE",
            "tech-lead",
            "plan baseline_tasks_version_ref must bind the confirmed tasks registry",
            ["plan.baseline_tasks_version_ref"],
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
        "safe_for_baseline_audit": True,
        "safe_to_dispatch": False,
    }


def failure_payload(exc: IntakeFailure) -> dict[str, Any]:
    return {
        "status": "BLOCKED",
        "decision": exc.decision,
        "failure_code": exc.code,
        "owner": exc.owner,
        "reason": exc.reason,
        "missing_inputs": exc.missing_inputs,
        "safe_for_baseline_audit": False,
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
    feature_dir = phase_dir.parent
    brief = load_json(feature_dir / "brief.json", "brief.json")
    phase_prd = load_json(phase_dir / "phase-prd.json", "phase-prd.json")
    assert_director_lock_intact(brief, "brief.json")
    assert_director_lock_intact(phase_prd, "phase-prd.json")
    plan = load_json(phase_dir / "plan.json", "plan.json")
    load_json(phase_dir / "design.json", "design.json")
    tasks = load_json(phase_dir / "tasks.json", "tasks.json")
    registry = load_json(phase_dir / "artifact-registry.json", "artifact-registry.json")
    assert_tech_lead(tasks, "tasks.json")
    assert_confirmed(tasks)
    assert_plan_ready(plan, tasks)
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
