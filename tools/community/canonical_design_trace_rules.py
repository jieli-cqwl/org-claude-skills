from __future__ import annotations

from canonical_design_rules import _assert_handoff_ref, _assert_manager_ref
from canonical_rule_common import (
    _require_non_empty_dict,
    _require_non_empty_list,
    _require_non_empty_string,
)


def assert_design_traceability(
    payload: dict,
    brief: dict,
    phase_prd: dict,
    unit_map: dict[str, set[str]],
    module_ids: set[str],
    design_refs: set[str],
) -> None:
    _assert_verification_mapping(payload, phase_prd)
    _assert_verification_refs_resolve(payload)
    _assert_unit_coverage(payload, unit_map, design_refs)
    _assert_impact_scope(payload, module_ids)
    _assert_planning_constraints(payload)
    _assert_product_handoff(payload, brief, phase_prd)
    _assert_risk_response(payload)


def _assert_verification_mapping(payload: dict, phase_prd: dict) -> None:
    mappings = _require_non_empty_list(
        payload.get("verification_mapping"), "verification_mapping"
    )
    for index, mapping in enumerate(mappings):
        if not isinstance(mapping, dict):
            raise ValueError(f"design verification_mapping[{index}] must be an object")
        for field in (
            "manager_vp_ref",
            "design_validation",
            "test_obligation",
            "evidence_ref",
        ):
            _require_non_empty_string(
                mapping.get(field), f"verification_mapping[{index}].{field}"
            )
        _assert_manager_ref(
            mapping.get("manager_vp_ref"),
            phase_prd,
            f"verification_mapping[{index}].manager_vp_ref",
        )


def _assert_verification_refs_resolve(payload: dict) -> None:
    evidence_refs = {
        mapping.get("evidence_ref")
        for mapping in _require_non_empty_list(
            payload.get("verification_mapping"), "verification_mapping"
        )
        if isinstance(mapping, dict) and isinstance(mapping.get("evidence_ref"), str)
    }
    for collection in (
        "quality_attributes",
        "cross_cutting_concerns",
        "impact_scope",
        "risk_response",
    ):
        rows = payload.get(collection, [])
        if not isinstance(rows, list):
            continue
        for row_index, row in enumerate(rows):
            if not isinstance(row, dict):
                continue
            refs = row.get("verification_refs")
            if refs is None:
                continue
            if not isinstance(refs, list):
                raise ValueError(
                    f"design {collection}[{row_index}].verification_refs must be an array"
                )
            missing = sorted(ref for ref in refs if ref not in evidence_refs)
            if missing:
                raise ValueError(
                    f"design {collection}[{row_index}].verification_refs unresolved refs: {missing}"
                )


def _assert_unit_coverage(
    payload: dict, unit_map: dict[str, set[str]], design_refs: set[str]
) -> None:
    coverage_rows = _require_non_empty_list(
        payload.get("unit_coverage"), "unit_coverage"
    )
    for index, row in enumerate(coverage_rows):
        if not isinstance(row, dict):
            raise ValueError(f"design unit_coverage[{index}] must be an object")
        unit_id = row.get("unit_id")
        _require_non_empty_string(unit_id, f"unit_coverage[{index}].unit_id")
        if unit_id not in unit_map:
            raise ValueError(f"design unit_coverage references unknown unit: {unit_id}")
        _assert_unit_ac_refs(row, index, unit_id, unit_map)
        _assert_unit_design_refs(row, index, design_refs)


def _assert_unit_ac_refs(
    row: dict, index: int, unit_id: str, unit_map: dict[str, set[str]]
) -> None:
    unknown_acs = sorted(
        set(
            _require_non_empty_list(
                row.get("ac_refs"), f"unit_coverage[{index}].ac_refs"
            )
        )
        - unit_map[unit_id]
    )
    if unknown_acs:
        raise ValueError(
            f"design unit_coverage references unknown ACs for {unit_id}: {unknown_acs}"
        )


def _assert_unit_design_refs(row: dict, index: int, design_refs: set[str]) -> None:
    unknown_refs = sorted(
        set(
            _require_non_empty_list(
                row.get("design_refs"), f"unit_coverage[{index}].design_refs"
            )
        )
        - design_refs
    )
    if unknown_refs:
        raise ValueError(
            f"design unit_coverage references unknown design refs: {unknown_refs}"
        )


def _assert_impact_scope(payload: dict, module_ids: set[str]) -> None:
    impact_scope = _require_non_empty_list(payload.get("impact_scope"), "impact_scope")
    seen_scope_ids: set[str] = set()
    for index, row in enumerate(impact_scope):
        if not isinstance(row, dict):
            raise ValueError(f"design impact_scope[{index}] must be an object")
        scope_item_id = row.get("scope_item_id")
        _require_non_empty_string(scope_item_id, f"impact_scope[{index}].scope_item_id")
        if scope_item_id in seen_scope_ids:
            raise ValueError(
                f"design impact_scope duplicate scope_item_id: {scope_item_id}"
            )
        seen_scope_ids.add(scope_item_id)
        _assert_impact_modules(row, index, module_ids)
        _require_non_empty_string(row.get("impact"), f"impact_scope[{index}].impact")
        _require_non_empty_list(
            row.get("verification_refs"), f"impact_scope[{index}].verification_refs"
        )


def _assert_impact_modules(row: dict, index: int, module_ids: set[str]) -> None:
    unknown_modules = sorted(
        set(
            _require_non_empty_list(
                row.get("affected_modules"), f"impact_scope[{index}].affected_modules"
            )
        )
        - module_ids
    )
    if unknown_modules:
        raise ValueError(
            f"design impact_scope references unknown modules: {unknown_modules}"
        )


def _assert_planning_constraints(payload: dict) -> None:
    rows = _require_non_empty_list(
        payload.get("planning_constraints"), "planning_constraints"
    )
    seen_constraint_ids: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ValueError(f"design planning_constraints[{index}] must be an object")
        constraint_id = row.get("constraint_id")
        _require_non_empty_string(
            constraint_id, f"planning_constraints[{index}].constraint_id"
        )
        if constraint_id in seen_constraint_ids:
            raise ValueError(
                f"design planning_constraints duplicate constraint_id: {constraint_id}"
            )
        seen_constraint_ids.add(constraint_id)
        for field in ("constraint_type", "description", "owner"):
            _require_non_empty_string(
                row.get(field), f"planning_constraints[{index}].{field}"
            )


def _assert_product_handoff(payload: dict, brief: dict, phase_prd: dict) -> None:
    product_handoff = _require_non_empty_dict(
        payload.get("product_handoff"), "product_handoff"
    )
    if product_handoff.get("status") != "READY":
        raise ValueError("design product_handoff.status must be READY")
    accepted_refs = _require_non_empty_list(
        product_handoff.get("accepted_refs"), "product_handoff.accepted_refs"
    )
    handoff_documents = {"brief.json": brief, "phase-prd.json": phase_prd}
    for index, ref in enumerate(accepted_refs):
        _assert_handoff_ref(
            ref, handoff_documents, f"product_handoff.accepted_refs[{index}]"
        )
    open_failures = product_handoff.get("open_failures")
    if not isinstance(open_failures, list) or open_failures:
        raise ValueError("design product_handoff.open_failures must be an empty array")


def _assert_risk_response(payload: dict) -> None:
    risk_ids = {
        risk.get("risk_id")
        for risk in _require_non_empty_list(payload.get("risks"), "risks")
        if isinstance(risk, dict)
    }
    responses = _require_non_empty_list(payload.get("risk_response"), "risk_response")
    response_ids = {
        response.get("risk_id") for response in responses if isinstance(response, dict)
    }
    missing_responses = sorted(risk_ids - response_ids)
    if missing_responses:
        raise ValueError(f"design risk_response missing risk ids: {missing_responses}")
    for index, response in enumerate(responses):
        _assert_single_risk_response(response, index)


def _assert_single_risk_response(response: object, index: int) -> None:
    if not isinstance(response, dict):
        raise ValueError(f"design risk_response[{index}] must be an object")
    _require_non_empty_string(
        response.get("architecture_response"),
        f"risk_response[{index}].architecture_response",
    )
    verification_refs = response.get("verification_refs")
    escalation_path = response.get("escalation_path")
    if (
        not isinstance(verification_refs, list) or not verification_refs
    ) and not escalation_path:
        raise ValueError(
            f"design risk_response[{index}] must include verification_refs or escalation_path"
        )
