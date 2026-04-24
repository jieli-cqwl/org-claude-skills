#!/usr/bin/env python3
"""Apply fail-closed rule validation for standard-chain scenarios."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from manage_artifact_registry import assert_active_uniqueness, get_active_revision
from normalize_canonical_artifact import ROOT, collect_artifacts, load_json, load_scenario
from runtime_yaml import load_yaml
from update_delivery_state import assert_task_runtime_alignment

LEGACY_FIELD_DENYLIST = {
    "brief": {"non_functional_req"},
    "developer-report": {"deviation_triggers", "task_status"},
    "verify-result": {"acceptance_status", "issue_ledger", "task_status"},
    "plan": {"coverage_matrix"},
    "signoff-package": {"kickoff_status", "release_alignment", "risk_acceptance_basis"},
}
PROCESS_LEAK_ARTIFACT_TYPES = {"plan", "tasks"}
PROCESS_LEAK_KEY_TOKENS = ("draft", "candidate", "unresolved", "intermediate", "recovered")
PROCESS_LEAK_VALUE_MARKERS = (
    "Draft Agent",
    "草稿 agent",
    "草稿agent",
    "候选字段",
    "未收敛多版本",
    "中间态痕迹",
    "RECOVERED",
)
DESIGN_REQUIRED_CONCERNS = {"auth", "error", "log", "config"}
DESIGN_MANAGER_REF_RE = re.compile(r"^(phase-prd)\.([A-Za-z_][A-Za-z0-9_]*)\[(\d+)\]$")
DESIGN_HANDOFF_REF_RE = re.compile(r"^(brief\.json|phase-prd\.json)#(.+)$")
TEST_DESIGN_REF_RE = re.compile(r"^design\.json#(.+)$")


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


def assert_no_process_leakage(artifact: dict) -> None:
    artifact_type = str(artifact.get("artifact_type", ""))
    if artifact_type not in PROCESS_LEAK_ARTIFACT_TYPES:
        return

    leaks: list[str] = []

    def scan(value: object, path: str) -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                key_path = f"{path}.{key}"
                normalized_key = str(key).replace("-", "_").lower()
                if any(token in normalized_key for token in PROCESS_LEAK_KEY_TOKENS):
                    leaks.append(key_path)
                scan(child, key_path)
            return
        if isinstance(value, list):
            for index, child in enumerate(value):
                scan(child, f"{path}[{index}]")
            return
        if isinstance(value, str) and any(marker in value for marker in PROCESS_LEAK_VALUE_MARKERS):
            leaks.append(path)

    scan(artifact, "$")
    if leaks:
        raise ValueError(f"{artifact_type} contains draft/candidate process leakage: {sorted(set(leaks))}")


def assert_chain_compatibility(artifacts: list[dict], compatibility: dict) -> None:
    pairs = {
        (artifact.get("chain_version"), artifact.get("chain_registry_digest"))
        for artifact in artifacts
    }
    if compatibility.get("active_consumption", {}).get("fail_close_on_multiple_digests") and len(pairs) > 1:
        raise ValueError(f"multiple active chain pairs: {sorted(pairs)}")


def assert_active_versions(artifact: dict, runtime_state: dict | None = None) -> None:
    artifact_type = artifact.get("artifact_type")
    if artifact_type in {
        "developer-report",
        "verify-result",
        "code-review-result",
        "qa-result",
        "delivery-state",
        "consistency-audit-result",
        "signoff-package",
        "user-decision",
    }:
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


def _require_non_empty_string(value: object, path: str) -> None:
    if not isinstance(value, str) or not value:
        raise ValueError(f"design contract missing non-empty string: {path}")


def _require_non_empty_list(value: object, path: str) -> list:
    if not isinstance(value, list) or not value:
        raise ValueError(f"design contract missing non-empty array: {path}")
    return value


def _require_non_empty_dict(value: object, path: str) -> dict:
    if not isinstance(value, dict) or not value:
        raise ValueError(f"design contract missing object: {path}")
    return value


def _first_artifact(artifacts: list[dict], artifact_type: str) -> dict:
    for artifact in artifacts:
        if artifact.get("artifact_type") == artifact_type:
            return artifact
    raise ValueError(f"design contract missing supporting artifact: {artifact_type}")


def _unit_ac_map(artifacts: list[dict], phase_prd: dict) -> dict[str, set[str]]:
    unit_map: dict[str, set[str]] = {}
    for artifact in artifacts:
        if artifact.get("artifact_type") != "unit-definition":
            continue
        unit_id = artifact.get("unit_id")
        if not isinstance(unit_id, str) or not unit_id:
            continue
        unit_map[unit_id] = {
            row.get("ac_id")
            for row in artifact.get("acceptance_criteria", [])
            if isinstance(row, dict) and isinstance(row.get("ac_id"), str)
        }
    expected_units = set(phase_prd.get("unit_index", []))
    missing_units = sorted(expected_units - set(unit_map))
    if missing_units:
        raise ValueError(f"design contract missing unit-definition artifacts: {missing_units}")
    return unit_map


def _anchor_exists(document: dict, anchor: str) -> bool:
    if anchor.startswith("/"):
        current: object = document
        for raw_part in anchor.strip("/").split("/"):
            part = raw_part.replace("~1", "/").replace("~0", "~")
            if isinstance(current, dict) and part in current:
                current = current[part]
                continue
            if isinstance(current, list) and part.isdigit() and int(part) < len(current):
                current = current[int(part)]
                continue
            return False
        return True
    field = anchor.split(".", 1)[0].split("[", 1)[0]
    return field in document


def _resolve_dotted_path(document: dict, anchor: str) -> object:
    current: object = document
    for raw_part in anchor.split("."):
        match = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*)(?:\[(\d+)\])?", raw_part)
        if not match:
            raise ValueError(f"unsupported design source ref anchor: {anchor}")
        field, raw_index = match.groups()
        if not isinstance(current, dict) or field not in current:
            raise ValueError(f"design source ref does not resolve: {anchor}")
        current = current[field]
        if raw_index is not None:
            if not isinstance(current, list):
                raise ValueError(f"design source ref field is not an array: {anchor}")
            index = int(raw_index)
            if index >= len(current):
                raise ValueError(f"design source ref index out of range: {anchor}")
            current = current[index]
    return current


def _assert_manager_ref(ref: object, phase_prd: dict, path: str) -> None:
    if not isinstance(ref, str):
        raise ValueError(f"design contract manager ref must be a string: {path}")
    match = DESIGN_MANAGER_REF_RE.match(ref)
    if not match:
        raise ValueError(f"design contract unsupported manager ref: {path}={ref}")
    _artifact_name, field, raw_index = match.groups()
    values = phase_prd.get(field)
    if not isinstance(values, list):
        raise ValueError(f"design contract manager ref field is not an array: {ref}")
    index = int(raw_index)
    if index >= len(values):
        raise ValueError(f"design contract manager ref out of range: {ref}")


def _assert_handoff_ref(ref: object, documents: dict[str, dict], path: str) -> None:
    if not isinstance(ref, str):
        raise ValueError(f"design contract handoff ref must be a string: {path}")
    match = DESIGN_HANDOFF_REF_RE.match(ref)
    if not match:
        raise ValueError(f"design contract unsupported handoff ref: {path}={ref}")
    document_name, anchor = match.groups()
    document = documents.get(document_name)
    if document is None or not _anchor_exists(document, anchor):
        raise ValueError(f"design contract handoff ref does not resolve: {ref}")


def _assert_design_source_ref(ref: object, design: dict, path: str) -> str:
    if not isinstance(ref, str):
        raise ValueError(f"test-cases design source ref must be a string: {path}")
    match = TEST_DESIGN_REF_RE.match(ref)
    if not match:
        raise ValueError(f"test-cases unsupported design source ref: {path}={ref}")
    anchor = match.group(1)
    _resolve_dotted_path(design, anchor)
    return ref


def assert_design_contract(payload: dict, artifacts: list[dict]) -> None:
    if payload.get("artifact_type") != "design":
        return

    brief = _first_artifact(artifacts, "brief")
    phase_prd = _first_artifact(artifacts, "phase-prd")
    unit_map = _unit_ac_map(artifacts, phase_prd)
    modules = _require_non_empty_list(payload.get("modules"), "modules")
    module_ids = {
        row.get("module_id")
        for row in modules
        if isinstance(row, dict) and isinstance(row.get("module_id"), str)
    }
    interface_ids = {
        row.get("interface_id")
        for row in payload.get("interfaces", [])
        if isinstance(row, dict) and isinstance(row.get("interface_id"), str)
    }
    design_refs = module_ids | interface_ids
    data_architecture = _require_non_empty_dict(payload.get("data_architecture"), "data_architecture")
    for field in ("summary", "consistency_strategy"):
        _require_non_empty_string(data_architecture.get(field), f"data_architecture.{field}")
    for field in ("storage_decisions", "data_flows"):
        _require_non_empty_list(data_architecture.get(field), f"data_architecture.{field}")

    concerns = _require_non_empty_list(payload.get("cross_cutting_concerns"), "cross_cutting_concerns")
    concern_names = {
        concern.get("concern")
        for concern in concerns
        if isinstance(concern, dict)
    }
    missing_concerns = sorted(DESIGN_REQUIRED_CONCERNS - concern_names)
    if missing_concerns:
        raise ValueError(f"design cross_cutting_concerns missing required concerns: {missing_concerns}")
    for index, concern in enumerate(concerns):
        if not isinstance(concern, dict):
            raise ValueError(f"design cross_cutting_concerns[{index}] must be an object")
        _require_non_empty_string(concern.get("decision"), f"cross_cutting_concerns[{index}].decision")
        _require_non_empty_string(concern.get("owner"), f"cross_cutting_concerns[{index}].owner")
        _require_non_empty_list(concern.get("verification_refs"), f"cross_cutting_concerns[{index}].verification_refs")

    verification_mapping = _require_non_empty_list(payload.get("verification_mapping"), "verification_mapping")
    for index, mapping in enumerate(verification_mapping):
        if not isinstance(mapping, dict):
            raise ValueError(f"design verification_mapping[{index}] must be an object")
        for field in ("manager_vp_ref", "design_validation", "test_obligation", "evidence_ref"):
            _require_non_empty_string(mapping.get(field), f"verification_mapping[{index}].{field}")
        _assert_manager_ref(mapping.get("manager_vp_ref"), phase_prd, f"verification_mapping[{index}].manager_vp_ref")

    unit_coverage = _require_non_empty_list(payload.get("unit_coverage"), "unit_coverage")
    for index, row in enumerate(unit_coverage):
        if not isinstance(row, dict):
            raise ValueError(f"design unit_coverage[{index}] must be an object")
        unit_id = row.get("unit_id")
        _require_non_empty_string(unit_id, f"unit_coverage[{index}].unit_id")
        if unit_id not in unit_map:
            raise ValueError(f"design unit_coverage references unknown unit: {unit_id}")
        unknown_acs = sorted(set(_require_non_empty_list(row.get("ac_refs"), f"unit_coverage[{index}].ac_refs")) - unit_map[unit_id])
        if unknown_acs:
            raise ValueError(f"design unit_coverage references unknown ACs for {unit_id}: {unknown_acs}")
        unknown_design_refs = sorted(set(_require_non_empty_list(row.get("design_refs"), f"unit_coverage[{index}].design_refs")) - design_refs)
        if unknown_design_refs:
            raise ValueError(f"design unit_coverage references unknown design refs: {unknown_design_refs}")

    impact_scope = _require_non_empty_list(payload.get("impact_scope"), "impact_scope")
    seen_scope_ids: set[str] = set()
    for index, row in enumerate(impact_scope):
        if not isinstance(row, dict):
            raise ValueError(f"design impact_scope[{index}] must be an object")
        scope_item_id = row.get("scope_item_id")
        _require_non_empty_string(scope_item_id, f"impact_scope[{index}].scope_item_id")
        if scope_item_id in seen_scope_ids:
            raise ValueError(f"design impact_scope duplicate scope_item_id: {scope_item_id}")
        seen_scope_ids.add(scope_item_id)
        unknown_modules = sorted(set(_require_non_empty_list(row.get("affected_modules"), f"impact_scope[{index}].affected_modules")) - module_ids)
        if unknown_modules:
            raise ValueError(f"design impact_scope references unknown modules: {unknown_modules}")
        _require_non_empty_string(row.get("impact"), f"impact_scope[{index}].impact")
        _require_non_empty_list(row.get("verification_refs"), f"impact_scope[{index}].verification_refs")

    planning_constraints = _require_non_empty_list(payload.get("planning_constraints"), "planning_constraints")
    seen_constraint_ids: set[str] = set()
    for index, row in enumerate(planning_constraints):
        if not isinstance(row, dict):
            raise ValueError(f"design planning_constraints[{index}] must be an object")
        constraint_id = row.get("constraint_id")
        _require_non_empty_string(constraint_id, f"planning_constraints[{index}].constraint_id")
        if constraint_id in seen_constraint_ids:
            raise ValueError(f"design planning_constraints duplicate constraint_id: {constraint_id}")
        seen_constraint_ids.add(constraint_id)
        for field in ("constraint_type", "description", "owner"):
            _require_non_empty_string(row.get(field), f"planning_constraints[{index}].{field}")

    product_handoff = _require_non_empty_dict(payload.get("product_handoff"), "product_handoff")
    if product_handoff.get("status") != "READY":
        raise ValueError("design product_handoff.status must be READY")
    accepted_refs = _require_non_empty_list(product_handoff.get("accepted_refs"), "product_handoff.accepted_refs")
    handoff_documents = {"brief.json": brief, "phase-prd.json": phase_prd}
    for index, ref in enumerate(accepted_refs):
        _assert_handoff_ref(ref, handoff_documents, f"product_handoff.accepted_refs[{index}]")
    open_failures = product_handoff.get("open_failures")
    if not isinstance(open_failures, list) or open_failures:
        raise ValueError("design product_handoff.open_failures must be an empty array")

    risk_ids = {
        risk.get("risk_id")
        for risk in _require_non_empty_list(payload.get("risks"), "risks")
        if isinstance(risk, dict)
    }
    responses = _require_non_empty_list(payload.get("risk_response"), "risk_response")
    response_ids = {
        response.get("risk_id")
        for response in responses
        if isinstance(response, dict)
    }
    missing_responses = sorted(risk_ids - response_ids)
    if missing_responses:
        raise ValueError(f"design risk_response missing risk ids: {missing_responses}")
    for index, response in enumerate(responses):
        if not isinstance(response, dict):
            raise ValueError(f"design risk_response[{index}] must be an object")
        _require_non_empty_string(response.get("architecture_response"), f"risk_response[{index}].architecture_response")
        verification_refs = response.get("verification_refs")
        escalation_path = response.get("escalation_path")
        if (not isinstance(verification_refs, list) or not verification_refs) and not escalation_path:
            raise ValueError(f"design risk_response[{index}] must include verification_refs or escalation_path")


def assert_test_cases_contract(payload: dict, artifacts: list[dict]) -> None:
    if payload.get("artifact_type") != "test-cases":
        return

    design = _first_artifact(artifacts, "design")
    expected_manager_refs = {
        f"design.json#verification_mapping[{index}].manager_vp_ref"
        for index, _mapping in enumerate(_require_non_empty_list(design.get("verification_mapping"), "design.verification_mapping"))
    }
    actual_refs: set[str] = set()
    for index, row in enumerate(_require_non_empty_list(payload.get("qa_handoff_contract"), "qa_handoff_contract")):
        if not isinstance(row, dict):
            raise ValueError(f"test-cases qa_handoff_contract[{index}] must be an object")
        refs = _require_non_empty_list(row.get("design_source_refs"), f"qa_handoff_contract[{index}].design_source_refs")
        for ref_index, ref in enumerate(refs):
            actual_refs.add(_assert_design_source_ref(ref, design, f"qa_handoff_contract[{index}].design_source_refs[{ref_index}]"))
    missing_manager_refs = sorted(expected_manager_refs - actual_refs)
    if missing_manager_refs:
        raise ValueError(f"test-cases design_source_refs missing manager refs: {missing_manager_refs}")


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

    tasks_registry = scenario.get("tasks_registry")
    if runtime_state is not None and isinstance(tasks_registry, dict):
        assert_task_runtime_alignment(runtime_state, tasks_registry)

    assert_upstream_closure(scenario.get("upstream_closure", {}))


if __name__ == "__main__":
    main()
