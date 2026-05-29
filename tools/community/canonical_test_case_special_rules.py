from __future__ import annotations

import re

from canonical_rule_common import (
    _require_non_empty_list,
    _require_non_empty_string,
    _resolve_dotted_path,
)

SOURCE_REF_RE = re.compile(
    r"^(brief\.json|phase-prd\.json|UNIT-[0-9]+\.json|design\.json)#(.+)$"
)
QA_STAGES = {"QA_A", "QA_B", "QA_C", "QA_D", "NFR"}
SPECIAL_TRIGGER_HANDLINGS = {"TEST_CASE", "QA_HANDOFF", "TYPED_GAP"}
SPECIAL_TRIGGER_TYPES = {
    "quality_attribute",
    "data_architecture",
    "cross_cutting_concern",
}


def assert_qa_handoff_obligation_ids(payload: dict) -> set[str]:
    rows = _require_non_empty_list(payload.get("qa_handoff_contract"), "qa_handoff_contract")
    obligation_ids: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ValueError(f"test-cases qa_handoff_contract[{index}] must be an object")
        obligation_id = row.get("obligation_id")
        _require_non_empty_string(
            obligation_id, f"qa_handoff_contract[{index}].obligation_id"
        )
        if obligation_id in obligation_ids:
            raise ValueError(f"test-cases duplicate qa_handoff obligation_id: {obligation_id}")
        obligation_ids.add(str(obligation_id))
    return obligation_ids


def assert_special_test_triggers(
    payload: dict,
    support: dict[str, dict],
    case_ids: set[str],
    gap_ids: set[str],
    handoff_ids: set[str],
) -> None:
    rows = payload.get("special_test_triggers")
    if not isinstance(rows, list):
        raise ValueError("test-cases special_test_triggers must be an array")
    expected_refs = _expected_special_trigger_refs(support["design.json"])
    actual_refs: set[str] = set()
    seen_ids: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ValueError(f"test-cases special_test_triggers[{index}] must be an object")
        _assert_special_trigger_row(
            row,
            index,
            support,
            case_ids,
            gap_ids,
            handoff_ids,
            actual_refs,
            seen_ids,
        )
    missing = sorted(expected_refs - actual_refs)
    if missing:
        raise ValueError(f"test-cases missing special_test_triggers source refs: {missing}")


def _assert_special_trigger_row(
    row: dict,
    index: int,
    support: dict[str, dict],
    case_ids: set[str],
    gap_ids: set[str],
    handoff_ids: set[str],
    actual_refs: set[str],
    seen_ids: set[str],
) -> None:
    path = f"special_test_triggers[{index}]"
    trigger_id = row.get("trigger_id")
    _require_non_empty_string(trigger_id, f"{path}.trigger_id")
    if trigger_id in seen_ids:
        raise ValueError(f"test-cases duplicate special trigger_id: {trigger_id}")
    seen_ids.add(str(trigger_id))
    trigger_type = _assert_enum(
        row.get("trigger_type"), SPECIAL_TRIGGER_TYPES, f"{path}.trigger_type"
    )
    source_ref = _assert_source_ref(row.get("source_ref"), support, f"{path}.source_ref")
    if not source_ref.startswith("design.json#"):
        raise ValueError(f"test-cases {path}.source_ref must point to design.json")
    actual_refs.add(source_ref)
    _require_non_empty_string(row.get("trigger_rule"), f"{path}.trigger_rule")
    _require_non_empty_string(row.get("threshold_ref"), f"{path}.threshold_ref")
    _assert_enum(row.get("qa_stage"), QA_STAGES, f"{path}.qa_stage")
    handling = _assert_enum(
        row.get("handling"), SPECIAL_TRIGGER_HANDLINGS, f"{path}.handling"
    )
    _assert_special_trigger_backing(row, handling, case_ids, gap_ids, handoff_ids, path)
    _assert_trigger_type_matches_source(trigger_type, source_ref, path)


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


def _expected_special_trigger_refs(design: dict) -> set[str]:
    refs = {
        f"design.json#quality_attributes[{index}]"
        for index, _row in enumerate(design.get("quality_attributes", []))
    }
    if isinstance(design.get("data_architecture"), dict) and design["data_architecture"]:
        refs.add("design.json#data_architecture")
    refs.update(
        f"design.json#cross_cutting_concerns[{index}]"
        for index, _row in enumerate(design.get("cross_cutting_concerns", []))
    )
    return refs


def _assert_special_trigger_backing(
    row: dict,
    handling: str,
    case_ids: set[str],
    gap_ids: set[str],
    handoff_ids: set[str],
    path: str,
) -> None:
    test_refs = _known_optional_refs(row, "test_case_refs", case_ids, path)
    handoff_refs = _known_optional_refs(
        row, "qa_handoff_obligation_refs", handoff_ids, path
    )
    gap_refs = _known_optional_refs(row, "gap_refs", gap_ids, path)
    if handling == "TEST_CASE" and not test_refs:
        raise ValueError(f"test-cases {path}.test_case_refs required for TEST_CASE")
    if handling == "QA_HANDOFF" and not handoff_refs:
        raise ValueError(
            f"test-cases {path}.qa_handoff_obligation_refs required for QA_HANDOFF"
        )
    if handling == "TYPED_GAP" and not gap_refs:
        raise ValueError(f"test-cases {path}.gap_refs required for TYPED_GAP")


def _known_optional_refs(
    row: dict, field: str, allowed: set[str], path: str
) -> list[str]:
    if field not in row:
        return []
    refs = _assert_string_array(row.get(field), f"{path}.{field}")
    unknown = sorted(set(refs) - allowed)
    if unknown:
        raise ValueError(f"test-cases unknown refs in {path}.{field}: {unknown}")
    return refs


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


def _assert_trigger_type_matches_source(
    trigger_type: str, source_ref: str, path: str
) -> None:
    expected_prefix = {
        "quality_attribute": "design.json#quality_attributes[",
        "data_architecture": "design.json#data_architecture",
        "cross_cutting_concern": "design.json#cross_cutting_concerns[",
    }[trigger_type]
    if not source_ref.startswith(expected_prefix):
        raise ValueError(
            f"test-cases {path}.trigger_type does not match source_ref: {trigger_type}"
        )
