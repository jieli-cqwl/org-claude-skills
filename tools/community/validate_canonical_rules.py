#!/usr/bin/env python3
"""Apply fail-closed rule validation for standard-chain scenarios."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from manage_artifact_registry import assert_active_uniqueness, get_active_revision
from normalize_canonical_artifact import ROOT, collect_artifacts, load_json, load_scenario
from runtime_yaml import load_yaml
from update_delivery_state import assert_task_runtime_alignment

LEGACY_FIELD_DENYLIST = {
    "brief": {"non_functional_req"},
    "developer-report": {"deviation_triggers", "task_status"},
    "verify-result": {"acceptance_status", "issue_ledger", "task_status"},
    "plan": {"coverage_matrix", "goal_fidelity_review"},
    "signoff-package": {"kickoff_status", "release_alignment", "risk_acceptance_basis"},
}


def load_catalog() -> dict:
    return load_json(ROOT / "shared/runtime/standard-chain-catalog.json")


def load_stage_registry() -> dict:
    return load_yaml(ROOT / "contracts/canonical/stage-registry.yaml")


def load_compatibility_matrix() -> dict:
    return load_yaml(ROOT / "contracts/canonical/compatibility-matrix.yaml")


def build_transition_matrix(stage_registry: dict) -> dict[str, set[str]]:
    matrix: dict[str, set[str]] = {}
    for row in stage_registry.get("transitions", []):
        if not row.get("allowed"):
            continue
        matrix.setdefault(row["from"], set()).add(row["to"])
    return matrix


def assert_transition_allowed(current_stage: str, next_stage: str, matrix: dict[str, set[str]], stage_registry: dict) -> None:
    if current_stage in stage_registry.get("terminal_stages", []):
        raise ValueError(f"terminal stage cannot transition: {current_stage}")
    if next_stage == "BLOCKED":
        if "BLOCKED" not in matrix.get("NON_TERMINAL", set()):
            raise ValueError("BLOCKED transition not allowed by registry")
        return
    if next_stage == "REPLAN_PENDING":
        if "REPLAN_PENDING" not in matrix.get("NON_TERMINAL", set()):
            raise ValueError("REPLAN transition not allowed by registry")
        return
    if next_stage not in matrix.get(current_stage, set()):
        raise ValueError(f"illegal transition: {current_stage} -> {next_stage}")


def assert_producer_authority(artifact: dict, catalog: dict) -> None:
    entry = catalog.get("artifacts", {}).get(artifact.get("artifact_type"))
    if entry is None:
        raise ValueError(f"artifact type not registered: {artifact.get('artifact_type')}")
    expected = entry.get("producer")
    if artifact.get("producer") != expected:
        raise ValueError(
            f"producer authority mismatch for {artifact['artifact_type']}: "
            f"{artifact.get('producer')} != {expected}"
        )


def assert_no_legacy_fields(artifact: dict) -> None:
    artifact_type = str(artifact.get("artifact_type", ""))
    denied = sorted(set(artifact) & LEGACY_FIELD_DENYLIST.get(artifact_type, set()))
    if denied:
        raise ValueError(f"{artifact_type} contains legacy fields: {denied}")


def assert_chain_compatibility(artifacts: list[dict], compatibility: dict) -> None:
    pairs = {
        (artifact.get("chain_version"), artifact.get("chain_registry_digest"))
        for artifact in artifacts
    }
    if compatibility.get("active_consumption", {}).get("fail_close_on_multiple_digests") and len(pairs) > 1:
        raise ValueError(f"multiple active chain pairs: {sorted(pairs)}")


def assert_active_versions(artifact: dict, runtime_state: dict | None = None) -> None:
    artifact_type = artifact.get("artifact_type")
    if artifact_type in {"delivery-state", "signoff-package", "user-decision"}:
        if not artifact.get("active_plan_version_ref") or not artifact.get("active_tasks_version_ref"):
            raise ValueError(f"missing active refs for {artifact_type}")
    if artifact_type in {"signoff-package", "user-decision"}:
        if artifact.get("baseline_plan_version_ref") != artifact.get("active_plan_version_ref"):
            raise ValueError(f"baseline/active plan drift for {artifact_type}")
        if artifact.get("baseline_tasks_version_ref") != artifact.get("active_tasks_version_ref"):
            raise ValueError(f"baseline/active tasks drift for {artifact_type}")
    if artifact_type == "qa-result" and runtime_state is not None:
        if artifact.get("baseline_plan_version_ref") != runtime_state.get("active_plan_version_ref"):
            raise ValueError("qa-result baseline plan must match active runtime plan")
        if artifact.get("baseline_tasks_version_ref") != runtime_state.get("active_tasks_version_ref"):
            raise ValueError("qa-result baseline tasks must match active runtime tasks")


def is_superseded_verdict(artifact: dict) -> bool:
    return (
        artifact.get("sign_off_status") == "SUPERSEDED"
        or artifact.get("business_risk_acceptance_status") == "SUPERSEDED"
    )


def assert_signoff_baselines(payload: dict, runtime_state: dict | None) -> None:
    required = [
        "baseline_plan_version_ref",
        "baseline_tasks_version_ref",
        "active_plan_version_ref",
        "active_tasks_version_ref",
    ]
    for key in required:
        if not payload.get(key):
            raise ValueError(f"missing signoff field: {key}")
    if not is_superseded_verdict(payload):
        if payload["baseline_plan_version_ref"] != payload["active_plan_version_ref"]:
            raise ValueError("signoff baseline plan ref must equal active plan ref")
        if payload["baseline_tasks_version_ref"] != payload["active_tasks_version_ref"]:
            raise ValueError("signoff baseline tasks ref must equal active tasks ref")
    if runtime_state is not None and not is_superseded_verdict(payload):
        if payload["active_plan_version_ref"] != runtime_state["active_plan_version_ref"]:
            raise ValueError("signoff active plan baseline is stale")
        if payload["active_tasks_version_ref"] != runtime_state["active_tasks_version_ref"]:
            raise ValueError("signoff active tasks baseline is stale")


def assert_decision_baselines(payload: dict, runtime_state: dict | None) -> None:
    required = [
        "baseline_plan_version_ref",
        "baseline_tasks_version_ref",
        "active_plan_version_ref",
        "active_tasks_version_ref",
        "authority_proof_refs",
        "decision_basis_refs",
        "decision_payload_digest",
    ]
    for key in required:
        if not payload.get(key):
            raise ValueError(f"missing decision field: {key}")
    if payload.get("decision_source") == "SCRIPT":
        raise ValueError("SCRIPT cannot produce finalized user decision")
    if not is_superseded_verdict(payload):
        if payload["baseline_plan_version_ref"] != payload["active_plan_version_ref"]:
            raise ValueError("baseline plan ref must equal active plan ref")
        if payload["baseline_tasks_version_ref"] != payload["active_tasks_version_ref"]:
            raise ValueError("baseline tasks ref must equal active tasks ref")
    if runtime_state is not None and not is_superseded_verdict(payload):
        if payload["active_plan_version_ref"] != runtime_state["active_plan_version_ref"]:
            raise ValueError("decision active plan baseline is stale")
        if payload["active_tasks_version_ref"] != runtime_state["active_tasks_version_ref"]:
            raise ValueError("decision active tasks baseline is stale")


def assert_upstream_closure(closure: dict) -> None:
    if not closure:
        return

    def assert_exactly_once(required_refs: list[str], rows: list[dict], label: str) -> None:
        seen = [row["source_ref"] for row in rows]
        if len(seen) != len(set(seen)):
            raise ValueError(f"duplicate {label} rows")
        missing = set(required_refs) - set(seen)
        extra = set(seen) - set(required_refs)
        if missing or extra:
            raise ValueError(f"{label} closure mismatch: missing={sorted(missing)} extra={sorted(extra)}")

    goals = closure.get("goals", [])
    goal_rows = closure.get("goal_closure", [])
    assert_exactly_once(goals, goal_rows, "goal")

    constraints = closure.get("constraints", [])
    constraint_rows = set(closure.get("constraint_source_refs", []))
    constraint_na = {
        row["source_ref"]
        for row in closure.get("constraint_na", [])
        if row.get("reason_code")
    }
    if set(constraints) != constraint_rows | constraint_na:
        raise ValueError("constraint closure mismatch")

    obligations = set(closure.get("obligations", []))
    obligation_rows = set(closure.get("obligation_source_refs", []))
    if obligations != obligation_rows:
        raise ValueError("obligation closure mismatch")

    gates = set(closure.get("gate_rows", []))
    gate_consumption = set(closure.get("gate_consumption", []))
    if gates != gate_consumption:
        raise ValueError("gate closure mismatch")


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
    transition = scenario.get("transition", {})
    if transition:
        assert_transition_allowed(
            transition["current_stage"],
            transition["next_stage"],
            build_transition_matrix(stage_registry),
            stage_registry,
        )

    artifacts = collect_artifacts(scenario)
    if artifacts:
        assert_chain_compatibility(artifacts, compatibility)
    runtime_state = next(
        (artifact for artifact in artifacts if artifact.get("artifact_type") == "delivery-state"),
        None,
    )
    if runtime_state is None and isinstance(scenario.get("runtime_state"), dict):
        runtime_state = scenario["runtime_state"]
    for artifact in artifacts:
        assert_no_legacy_fields(artifact)
        assert_producer_authority(artifact, catalog)
        assert_active_versions(artifact, runtime_state)
        if artifact.get("artifact_type") == "signoff-package":
            assert_signoff_baselines(artifact, runtime_state)
        if artifact.get("artifact_type") == "user-decision":
            assert_decision_baselines(artifact, runtime_state)
        if artifact.get("artifact_type") == "artifact-registry":
            assert_active_uniqueness(get_active_revision(artifact).get("entries", []))

    tasks_registry = scenario.get("tasks_registry")
    if runtime_state is not None and isinstance(tasks_registry, dict):
        assert_task_runtime_alignment(runtime_state, tasks_registry)

    assert_upstream_closure(scenario.get("upstream_closure", {}))


if __name__ == "__main__":
    main()
