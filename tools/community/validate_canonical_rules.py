#!/usr/bin/env python3
"""Apply fail-closed rule validation for standard-chain scenarios."""

from __future__ import annotations

import argparse
from pathlib import Path

from canonical_design_rules import (
    _assert_cross_cutting_concerns,
    _assert_data_architecture,
    _assert_design_confirmations,
    _assert_design_interfaces,
    _assert_key_decisions,
    _assert_quality_attributes,
    _assert_runtime_facts,
    _design_ref_sets,
    _unit_ac_map,
)
from canonical_design_trace_rules import assert_design_traceability
from canonical_rule_common import (
    assert_active_versions,
    assert_chain_compatibility,
    assert_decision_baselines,
    assert_no_legacy_fields,
    assert_no_process_leakage,
    assert_producer_authority,
    assert_signoff_baselines,
    assert_transition_allowed,
    assert_upstream_closure,
    build_transition_matrix,
    load_catalog,
    load_compatibility_matrix,
    load_stage_registry,
)
from canonical_test_case_rules import assert_test_cases_contract
from manage_artifact_registry import assert_active_uniqueness, get_active_revision
from normalize_canonical_artifact import collect_artifacts, load_scenario
from update_delivery_state import assert_task_runtime_alignment

TASK_ALLOWED_FIELDS = {
    "task_id",
    "task_title",
    "task_state",
    "phase_ref",
    "unit_refs",
    "scope_item_refs",
    "design_refs",
    "test_refs",
    "file_range",
    "depends_on",
    "shared_files",
    "batch",
    "acceptance_targets",
    "proving_command",
    "real_dependency_note",
    "evidence_target",
    "mock_boundary_note",
    "wbs_ref",
    "critical_path_role",
    "supersedes_task_refs",
    "derived_task_refs",
    "carry_forward_strategy",
}


def assert_design_contract(payload: dict, artifacts: list[dict]) -> None:
    if payload.get("artifact_type") != "design":
        return

    brief = _first_artifact(artifacts, "brief")
    phase_prd = _first_artifact(artifacts, "phase-prd")
    unit_map = _unit_ac_map(artifacts, phase_prd)
    _assert_design_confirmations(payload)
    _assert_key_decisions(payload)
    _assert_runtime_facts(payload)
    _assert_design_interfaces(payload)
    module_ids, interface_ids = _design_ref_sets(payload)
    design_refs = module_ids | interface_ids
    _assert_data_architecture(payload)
    _assert_quality_attributes(payload)
    _assert_cross_cutting_concerns(payload)
    assert_design_traceability(
        payload,
        brief,
        phase_prd,
        unit_map,
        module_ids,
        design_refs,
    )


def assert_tasks_contract(payload: dict) -> None:
    if payload.get("artifact_type") != "tasks":
        return

    tasks = payload.get("tasks")
    if not isinstance(tasks, list) or not tasks:
        raise ValueError("tasks artifact must contain non-empty tasks")

    task_ids: list[str] = []
    for index, task in enumerate(tasks):
        if not isinstance(task, dict):
            raise ValueError(f"tasks[{index}] must be an object")
        task_id = task.get("task_id")
        if not isinstance(task_id, str) or not task_id:
            raise ValueError(f"tasks[{index}] missing task_id")
        task_ids.append(task_id)
        extra = sorted(
            key
            for key in task
            if key not in TASK_ALLOWED_FIELDS and not str(key).startswith("x_")
        )
        if extra:
            raise ValueError(f"task {task_id} contains unsupported fields: {extra}")
        for field in ("scope_item_refs", "acceptance_targets", "file_range"):
            values = task.get(field)
            if not isinstance(values, list) or not any(
                isinstance(item, str) and item.strip() for item in values
            ):
                raise ValueError(f"task {task_id} must contain non-empty {field}")

    known = set(task_ids)
    for task in tasks:
        task_id = str(task.get("task_id"))
        for dependency in _string_list(task.get("depends_on")):
            if dependency not in known:
                raise ValueError(f"task {task_id} depends_on unknown task: {dependency}")

    _assert_no_dependency_cycles(tasks)


def _string_list(value: object) -> list[str]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, str) and item.strip()]


def _assert_no_dependency_cycles(tasks: list[dict]) -> None:
    graph = {
        str(task.get("task_id")): _string_list(task.get("depends_on"))
        for task in tasks
        if isinstance(task, dict)
    }
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(task_id: str, path: list[str]) -> None:
        if task_id in visited:
            return
        if task_id in visiting:
            cycle = path[path.index(task_id) :] + [task_id]
            raise ValueError(f"tasks depends_on cycle detected: {' -> '.join(cycle)}")
        visiting.add(task_id)
        for dependency in graph.get(task_id, []):
            visit(dependency, [*path, dependency])
        visiting.remove(task_id)
        visited.add(task_id)

    for task_id in graph:
        visit(task_id, [task_id])


def _first_artifact(artifacts: list[dict], artifact_type: str) -> dict:
    for artifact in artifacts:
        if artifact.get("artifact_type") == artifact_type:
            return artifact
    raise ValueError(f"design contract missing supporting artifact: {artifact_type}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--phase-dir", type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    scenario, _phase_root = load_scenario(args.fixture, args.phase_dir)
    catalog = load_catalog()
    stage_registry = load_stage_registry()
    compatibility = load_compatibility_matrix()
    _assert_transition_if_requested(scenario, stage_registry)

    artifacts = collect_artifacts(scenario)
    if artifacts:
        assert_chain_compatibility(artifacts, compatibility)
    runtime_state = _runtime_state_from(scenario, artifacts)
    for artifact in artifacts:
        _assert_artifact_rules(artifact, artifacts, catalog, runtime_state)

    tasks_registry = scenario.get("tasks_registry")
    if runtime_state is not None and isinstance(tasks_registry, dict):
        assert_task_runtime_alignment(runtime_state, tasks_registry)

    assert_upstream_closure(scenario.get("upstream_closure", {}))


def _assert_transition_if_requested(scenario: dict, stage_registry: dict) -> None:
    transition = scenario.get("transition", {})
    if transition:
        assert_transition_allowed(
            transition["current_stage"],
            transition["next_stage"],
            build_transition_matrix(stage_registry),
            stage_registry,
        )


def _runtime_state_from(scenario: dict, artifacts: list[dict]) -> dict | None:
    runtime_state = next(
        (
            artifact
            for artifact in artifacts
            if artifact.get("artifact_type") == "delivery-state"
        ),
        None,
    )
    if runtime_state is None and isinstance(scenario.get("runtime_state"), dict):
        runtime_state = scenario["runtime_state"]
    return runtime_state


def _assert_artifact_rules(
    artifact: dict,
    artifacts: list[dict],
    catalog: dict,
    runtime_state: dict | None,
) -> None:
    assert_no_legacy_fields(artifact)
    assert_no_process_leakage(artifact)
    assert_producer_authority(artifact, catalog)
    assert_active_versions(artifact, runtime_state)
    assert_design_contract(artifact, artifacts)
    assert_tasks_contract(artifact)
    assert_test_cases_contract(artifact, artifacts)
    if artifact.get("artifact_type") == "signoff-package":
        assert_signoff_baselines(artifact, runtime_state)
    if artifact.get("artifact_type") == "user-decision":
        assert_decision_baselines(artifact, runtime_state)
    if artifact.get("artifact_type") == "artifact-registry":
        assert_active_uniqueness(get_active_revision(artifact).get("entries", []))


if __name__ == "__main__":
    try:
        main()
    except ValueError as exc:
        raise SystemExit(str(exc)) from None
