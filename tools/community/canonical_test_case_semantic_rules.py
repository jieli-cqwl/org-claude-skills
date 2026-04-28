from __future__ import annotations

import re

from canonical_rule_common import (
    _first_artifact,
    _require_non_empty_dict,
    _require_non_empty_list,
    _require_non_empty_string,
    _require_string_list,
    _resolve_dotted_path,
)

SOURCE_REF_RE = re.compile(
    r"^(brief\.json|phase-prd\.json|UNIT-[0-9]+\.json|design\.json)#(.+)$"
)
CASE_TYPES = {"positive", "negative", "boundary", "exclusion", "specialty"}
PRIORITIES = {"P0", "P1", "P2", "P3"}
EXECUTION_MODES = {"browser_required", "non_browser_ok"}
AUTOMATION_LEVELS = {"manual", "automatable", "automated"}
OWNER_STAGES = {"developer", "verify", "qa", "nfr"}
GAP_TYPES = {
    "PRODUCT_GAP",
    "DESIGN_GAP",
    "SCOPE_DRIFT",
    "TRACE_CONFLICT",
    "TESTABILITY_GAP",
    "EQ_GAP",
}
GAP_OWNERS = {
    "product-director",
    "product-manager",
    "design",
    "test-design",
    "qa",
    "delivery-owner",
    "user",
}
COMPOSITION_STATUSES = {"COMPOSABLE", "BLOCKED_GAP"}


def supporting_artifacts(artifacts: list[dict]) -> dict[str, dict]:
    support = {
        "brief.json": _first_artifact(artifacts, "brief"),
        "phase-prd.json": _first_artifact(artifacts, "phase-prd"),
        "design.json": _first_artifact(artifacts, "design"),
    }
    for artifact in artifacts:
        if artifact.get("artifact_type") != "unit-definition":
            continue
        unit_id = artifact.get("unit_id")
        if isinstance(unit_id, str) and unit_id:
            support[f"{unit_id}.json"] = artifact
    return support


def assert_test_case_semantics(payload: dict, support: dict[str, dict]) -> None:
    _assert_test_analysis(payload, support)
    case_ids = _assert_test_cases(payload, support)
    gap_ids = _assert_design_gap_report(payload, support)
    _assert_traceability_matrix(payload, support, case_ids, gap_ids)
    _assert_cross_unit_obligations(payload, support, case_ids, gap_ids)


def _assert_source_ref(ref: object, support: dict[str, dict], path: str) -> str:
    if not isinstance(ref, str):
        raise ValueError(f"test-cases source ref must be a string: {path}")
    match = SOURCE_REF_RE.match(ref)
    if not match:
        raise ValueError(f"test-cases unsupported source ref: {path}={ref}")
    document_name, anchor = match.groups()
    document = support.get(document_name)
    if document is None:
        raise ValueError(f"test-cases source ref artifact missing: {path}={ref}")
    try:
        _resolve_dotted_path(document, anchor)
    except ValueError as exc:
        raise ValueError(
            f"test-cases source ref does not resolve at {path}: {ref} ({exc})"
        ) from exc
    return ref


def _assert_source_refs(value: object, support: dict[str, dict], path: str) -> list[str]:
    refs = _require_string_list(value, path)
    for index, ref in enumerate(refs):
        _assert_source_ref(ref, support, f"{path}[{index}]")
    return refs


def _assert_optional_source_ref(
    row: dict, field: str, support: dict[str, dict], path: str
) -> None:
    if field in row:
        _assert_source_ref(row.get(field), support, f"{path}.{field}")


def _assert_string_array(value: object, path: str) -> list[str]:
    if not isinstance(value, list):
        raise ValueError(f"test-cases field must be an array: {path}")
    if not all(isinstance(row, str) and row for row in value):
        raise ValueError(f"test-cases field requires string refs: {path}")
    return value


def _assert_enum(value: object, allowed: set[str], path: str) -> str:
    if value not in allowed:
        raise ValueError(f"test-cases invalid {path}: {value}")
    return str(value)


def _assert_test_analysis(payload: dict, support: dict[str, dict]) -> None:
    analysis = _require_non_empty_dict(payload.get("test_analysis"), "test_analysis")
    for field in (
        "objectives",
        "in_scope",
        "out_of_scope",
        "environment_assumptions",
        "data_assumptions",
    ):
        _require_string_list(analysis.get(field), f"test_analysis.{field}")
    _assert_risk_model(analysis, support)
    _assert_quality_strategy(analysis)
    _assert_test_flow(analysis, support)


def _assert_risk_model(analysis: dict, support: dict[str, dict]) -> None:
    rows = _require_non_empty_list(analysis.get("risk_model"), "test_analysis.risk_model")
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ValueError(f"test-cases risk_model[{index}] must be an object")
        _assert_source_ref(
            row.get("risk_ref"), support, f"test_analysis.risk_model[{index}].risk_ref"
        )
        for field in ("risk_type", "test_depth"):
            _require_non_empty_string(
                row.get(field), f"test_analysis.risk_model[{index}].{field}"
            )


def _assert_quality_strategy(analysis: dict) -> None:
    rows = _require_non_empty_list(
        analysis.get("strategy_by_quality_area"),
        "test_analysis.strategy_by_quality_area",
    )
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ValueError(f"test-cases strategy_by_quality_area[{index}] must be an object")
        for field in ("quality_area", "strategy"):
            _require_non_empty_string(
                row.get(field),
                f"test_analysis.strategy_by_quality_area[{index}].{field}",
            )


def _assert_test_flow(analysis: dict, support: dict[str, dict]) -> None:
    rows = _require_non_empty_list(analysis.get("test_flow"), "test_analysis.test_flow")
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ValueError(f"test-cases test_flow[{index}] must be an object")
        _require_non_empty_string(
            row.get("checkpoint_id"), f"test_analysis.test_flow[{index}].checkpoint_id"
        )
        _assert_source_refs(
            row.get("source_refs"), support, f"test_analysis.test_flow[{index}].source_refs"
        )
        _require_non_empty_string(
            row.get("expected_checkpoint"),
            f"test_analysis.test_flow[{index}].expected_checkpoint",
        )


def _assert_test_cases(payload: dict, support: dict[str, dict]) -> set[str]:
    rows = _require_non_empty_list(payload.get("test_cases"), "test_cases")
    case_ids: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ValueError(f"test-cases test_cases[{index}] must be an object")
        case_id = row.get("case_id")
        _require_non_empty_string(case_id, f"test_cases[{index}].case_id")
        if case_id in case_ids:
            raise ValueError(f"test-cases duplicate case_id: {case_id}")
        case_ids.add(str(case_id))
        _assert_executable_case(row, support, f"test_cases[{index}]")
    return case_ids


def _assert_executable_case(row: dict, support: dict[str, dict], path: str) -> None:
    _require_non_empty_string(row.get("title"), f"{path}.title")
    _assert_source_refs(row.get("product_refs"), support, f"{path}.product_refs")
    _assert_source_refs(row.get("design_refs"), support, f"{path}.design_refs")
    _assert_enum(row.get("case_type"), CASE_TYPES, f"{path}.case_type")
    _assert_enum(row.get("priority"), PRIORITIES, f"{path}.priority")
    for field in ("preconditions", "test_data", "steps"):
        _require_string_list(row.get(field), f"{path}.{field}")
    for field in ("expected_result", "assertion_target", "evidence_expectation"):
        _require_non_empty_string(row.get(field), f"{path}.{field}")
    _assert_enum(row.get("execution_mode"), EXECUTION_MODES, f"{path}.execution_mode")
    _assert_enum(row.get("automation_level"), AUTOMATION_LEVELS, f"{path}.automation_level")
    _assert_enum(row.get("owner_stage"), OWNER_STAGES, f"{path}.owner_stage")


def _assert_traceability_matrix(
    payload: dict,
    support: dict[str, dict],
    case_ids: set[str],
    gap_ids: set[str],
) -> None:
    rows = _require_non_empty_list(payload.get("traceability_matrix"), "traceability_matrix")
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ValueError(f"test-cases traceability_matrix[{index}] must be an object")
        path = f"traceability_matrix[{index}]"
        for field in ("product_ref", "unit_ref", "ac_ref", "design_ref"):
            _assert_source_ref(row.get(field), support, f"{path}.{field}")
        _assert_optional_source_ref(row, "exclusion_ref", support, path)
        _assert_optional_source_ref(row, "risk_ref", support, path)
        _assert_known_refs(
            _require_string_list(row.get("test_case_refs"), f"{path}.test_case_refs"),
            case_ids,
            f"{path}.test_case_refs",
        )
        _assert_known_refs(
            _assert_string_array(row.get("gap_refs"), f"{path}.gap_refs"),
            gap_ids,
            f"{path}.gap_refs",
        )


def _assert_known_refs(refs: list[str], allowed: set[str], path: str) -> None:
    unknown = sorted(set(refs) - allowed)
    if unknown:
        raise ValueError(f"test-cases unknown refs in {path}: {unknown}")


def _assert_design_gap_report(payload: dict, support: dict[str, dict]) -> set[str]:
    report = _require_non_empty_dict(payload.get("design_gap_report"), "design_gap_report")
    status = _assert_enum(report.get("status"), {"NO_GAPS", "HAS_GAPS"}, "design_gap_report.status")
    gaps = report.get("gaps")
    if not isinstance(gaps, list):
        raise ValueError("test-cases design_gap_report.gaps must be an array")
    if status == "NO_GAPS" and gaps:
        raise ValueError("test-cases NO_GAPS report cannot contain gap rows")
    if status == "HAS_GAPS" and not gaps:
        raise ValueError("test-cases HAS_GAPS report requires gap rows")
    gap_ids: set[str] = set()
    for index, row in enumerate(gaps):
        gap_ids.add(_assert_gap_row(row, support, f"design_gap_report.gaps[{index}]"))
    return gap_ids


def _assert_gap_row(row: object, support: dict[str, dict], path: str) -> str:
    if not isinstance(row, dict):
        raise ValueError(f"test-cases {path} must be an object")
    gap_id = row.get("gap_id")
    _require_non_empty_string(gap_id, f"{path}.gap_id")
    _assert_enum(row.get("gap_type"), GAP_TYPES, f"{path}.gap_type")
    _assert_source_refs(row.get("blocking_refs"), support, f"{path}.blocking_refs")
    _assert_enum(row.get("owner"), GAP_OWNERS, f"{path}.owner")
    _require_non_empty_string(row.get("next_action"), f"{path}.next_action")
    if not isinstance(row.get("blocking"), bool):
        raise ValueError(f"test-cases {path}.blocking must be boolean")
    if row["blocking"]:
        raise ValueError(f"test-cases blocking gap must stop completion: {path}.blocking=true")
    return str(gap_id)


def _assert_cross_unit_obligations(
    payload: dict,
    support: dict[str, dict],
    case_ids: set[str],
    gap_ids: set[str],
) -> None:
    rows = payload.get("cross_unit_obligations")
    if not isinstance(rows, list):
        raise ValueError("test-cases cross_unit_obligations must be an array")
    seen_sequences: dict[str, set[int]] = {}
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ValueError(f"test-cases cross_unit_obligations[{index}] must be an object")
        _assert_cross_unit_row(
            row, support, case_ids, gap_ids, seen_sequences, f"cross_unit_obligations[{index}]"
        )


def _assert_cross_unit_row(
    row: dict,
    support: dict[str, dict],
    case_ids: set[str],
    gap_ids: set[str],
    seen_sequences: dict[str, set[int]],
    path: str,
) -> None:
    journey_id = row.get("journey_id")
    _require_non_empty_string(journey_id, f"{path}.journey_id")
    _require_non_empty_string(row.get("journey_title"), f"{path}.journey_title")
    participant_refs = _assert_source_refs(
        row.get("participant_unit_refs"), support, f"{path}.participant_unit_refs"
    )
    local_ref = _assert_source_ref(row.get("local_unit_ref"), support, f"{path}.local_unit_ref")
    if local_ref not in participant_refs:
        raise ValueError(f"test-cases {path}.local_unit_ref must be in participant_unit_refs")
    sequence_index = row.get("sequence_index")
    if not isinstance(sequence_index, int) or sequence_index < 0:
        raise ValueError(f"test-cases {path}.sequence_index must be a non-negative integer")
    if sequence_index in seen_sequences.setdefault(str(journey_id), set()):
        raise ValueError(f"test-cases duplicate sequence_index for journey: {journey_id}")
    seen_sequences[str(journey_id)].add(sequence_index)
    _assert_known_refs(
        _assert_string_array(row.get("predecessor_case_refs"), f"{path}.predecessor_case_refs"),
        case_ids,
        f"{path}.predecessor_case_refs",
    )
    _assert_known_refs(
        _assert_string_array(row.get("successor_case_refs"), f"{path}.successor_case_refs"),
        case_ids,
        f"{path}.successor_case_refs",
    )
    _require_string_list(row.get("handoff_obligation_refs"), f"{path}.handoff_obligation_refs")
    status = _assert_enum(row.get("composition_status"), COMPOSITION_STATUSES, f"{path}.composition_status")
    gap_refs = _assert_string_array(row.get("gap_refs"), f"{path}.gap_refs")
    _assert_known_refs(gap_refs, gap_ids, f"{path}.gap_refs")
    if status == "BLOCKED_GAP" and not gap_refs:
        raise ValueError(f"test-cases {path}.gap_refs required for BLOCKED_GAP")
