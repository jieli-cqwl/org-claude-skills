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


def assert_design_contract(payload: dict, artifacts: list[dict]) -> None:
    if payload.get("artifact_type") != "design":
        return

    brief = _first_artifact(artifacts, "brief")
    phase_prd = _first_artifact(artifacts, "phase-prd")
    unit_map = _unit_ac_map(artifacts, phase_prd)
    _assert_design_confirmations(payload)
    _assert_design_interfaces(payload)
    module_ids, interface_ids = _design_ref_sets(payload)
    design_refs = module_ids | interface_ids
    _assert_data_architecture(payload)
    _assert_cross_cutting_concerns(payload)
    assert_design_traceability(
        payload,
        brief,
        phase_prd,
        unit_map,
        module_ids,
        design_refs,
    )


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
