from __future__ import annotations

from pathlib import Path
from typing import Callable

from readiness_closure_checks import expected_signoff_goal_refs

LoadJson = Callable[[Path], dict]


def assert_task_runtime_identity(
    task_runtime_entries: list[tuple[str, str, Path]],
    phase_dir: Path,
    load_json: LoadJson,
) -> None:
    feature_dir = phase_dir.parent
    runtime_state = load_json(phase_dir / "delivery-state.json")
    tasks_registry = load_json(phase_dir / "tasks.json")
    brief = load_json(feature_dir / "brief.json")
    phase_prd = load_json(phase_dir / "phase-prd.json")
    tasks = tasks_registry.get("tasks", [])
    if not isinstance(tasks, list):
        raise ValueError("tasks.json tasks must be an array")
    expected_task_ids = [
        str(item.get("task_id"))
        for item in tasks
        if isinstance(item, dict) and item.get("task_id")
    ]
    if len(expected_task_ids) != len(set(expected_task_ids)):
        raise ValueError("tasks.json task_id entries must be unique")
    state_tasks = runtime_state.get("tasks", [])
    if not isinstance(state_tasks, list):
        raise ValueError("delivery-state tasks must be an array")
    state_task_ids = [
        str(item.get("task_id"))
        for item in state_tasks
        if isinstance(item, dict) and item.get("task_id")
    ]
    if len(state_task_ids) != len(set(state_task_ids)):
        raise ValueError("delivery-state task_id entries must be unique")
    task_statuses = {
        str(item.get("task_id")): str(item.get("runtime_status", ""))
        for item in state_tasks
        if isinstance(item, dict) and item.get("task_id")
    }
    if set(state_task_ids) != set(expected_task_ids):
        raise ValueError(
            "delivery-state tasks must exactly cover tasks.json task ids: "
            f"missing={sorted(set(expected_task_ids) - set(state_task_ids))} "
            f"extra={sorted(set(state_task_ids) - set(expected_task_ids))}"
        )
    expected_goal_refs = set(expected_signoff_goal_refs(brief, phase_prd))
    developer_report_refs: dict[str, str] = {}
    for artifact_type, task_id, runtime_path in task_runtime_entries:
        if artifact_type != "developer-report":
            continue
        payload = load_json(runtime_path)
        developer_report_refs[task_id] = (
            f"artifact://developer-report/{payload.get('artifact_id')}@v1#tdd-evidence-index"
        )

    for artifact_type, task_id, runtime_path in task_runtime_entries:
        payload = load_json(runtime_path)
        if payload.get("artifact_type") != artifact_type:
            raise ValueError(f"task runtime artifact_type drift: {runtime_path}")
        if payload.get("task_id") != task_id:
            raise ValueError(f"task runtime task_id drift: {runtime_path}")
        expected = f".task-{task_id}."
        if expected not in str(payload.get("artifact_id", "")):
            raise ValueError(f"task runtime artifact_id drift: {runtime_path}")
        if artifact_type == "developer-report":
            status = str(payload.get("runtime_status", ""))
            if status != "VERIFIED":
                raise ValueError(
                    f"developer-report runtime_status must be VERIFIED at readiness: {runtime_path}"
                )
            if task_statuses[task_id] != status:
                raise ValueError(
                    f"developer-report runtime_status drift from delivery-state: {runtime_path}"
                )
        if artifact_type == "verify-result":
            expected_report_ref = developer_report_refs.get(task_id)
            if not expected_report_ref:
                raise ValueError(
                    f"verify-result missing matching developer-report for task: {task_id}"
                )
            if payload.get("developer_report_ref") != expected_report_ref:
                raise ValueError(
                    f"verify-result developer_report_ref drift from matching task developer-report: {runtime_path}"
                )
            if payload.get("baseline_tasks_version_ref") != runtime_state.get(
                "active_tasks_version_ref"
            ):
                raise ValueError(
                    f"verify-result baseline_tasks_version_ref drift from active delivery-state: {runtime_path}"
                )
            if payload.get("gate_result") != "PASS":
                raise ValueError(
                    f"verify-result gate_result must be PASS at readiness: {runtime_path}"
                )
            verdicts = payload.get("phase_verdicts", {})
            expected_verdicts = {
                "spec_review": "SPEC_OK",
                "phase2a": "2A_OK",
                "phase2b": "2B_OK",
                "phase2c": "2C_OK",
            }
            for phase_name, expected_status in expected_verdicts.items():
                if verdicts.get(phase_name, {}).get("status") != expected_status:
                    raise ValueError(
                        f"verify-result {phase_name}.status must be {expected_status}: {runtime_path}"
                    )
            for index, row in enumerate(payload.get("ac_verification", []), start=1):
                if row.get("status") != "PASS":
                    raise ValueError(
                        f"verify-result ac_verification[{index}].status must be PASS: {runtime_path}"
                    )
            goal_closure = payload.get("goal_closure", [])
            if not isinstance(goal_closure, list) or not goal_closure:
                raise ValueError(
                    f"verify-result goal_closure must be non-empty at readiness: {runtime_path}"
                )
            has_met_goal = False
            for index, row in enumerate(goal_closure, start=1):
                if not isinstance(row, dict):
                    raise ValueError(
                        f"verify-result goal_closure[{index}] must be an object: {runtime_path}"
                    )
                goal_ref = str(row.get("goal_ref", ""))
                if goal_ref not in expected_goal_refs:
                    raise ValueError(
                        f"verify-result goal_closure[{index}].goal_ref does not resolve to an upstream goal: {runtime_path}"
                    )
                if row.get("result") not in {"MET", "N_A"}:
                    raise ValueError(
                        f"verify-result goal_closure[{index}].result must be MET or N_A: {runtime_path}"
                    )
                has_met_goal = has_met_goal or row.get("result") == "MET"
            if not has_met_goal:
                raise ValueError(
                    f"verify-result goal_closure must contain at least one MET row at readiness: {runtime_path}"
                )
