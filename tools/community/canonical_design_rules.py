from __future__ import annotations

import re

from canonical_rule_common import (
    _require_non_empty_dict,
    _require_non_empty_list,
    _require_non_empty_string,
    _require_string_list,
    _resolve_dotted_path,
)

DESIGN_REQUIRED_CONCERNS = {"auth", "error", "log", "config"}
DESIGN_REQUIRED_CO_CREATION_STAGES = {"S3", "S4", "S5", "S6", "S7", "S8"}
DESIGN_MANAGER_REF_RE = re.compile(r"^(phase-prd)\.([A-Za-z_][A-Za-z0-9_]*)\[(\d+)\]$")
DESIGN_HANDOFF_REF_RE = re.compile(r"^(brief\.json|phase-prd\.json)#(.+)$")


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
    missing_units = sorted(set(phase_prd.get("unit_index", [])) - set(unit_map))
    if missing_units:
        raise ValueError(
            f"design contract missing unit-definition artifacts: {missing_units}"
        )
    return unit_map


def _anchor_exists(document: dict, anchor: str) -> bool:
    if anchor.startswith("/"):
        current: object = document
        for raw_part in anchor.strip("/").split("/"):
            part = raw_part.replace("~1", "/").replace("~0", "~")
            if isinstance(current, dict) and part in current:
                current = current[part]
                continue
            if (
                isinstance(current, list)
                and part.isdigit()
                and int(part) < len(current)
            ):
                current = current[int(part)]
                continue
            return False
        return True
    field = anchor.split(".", 1)[0].split("[", 1)[0]
    return field in document


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
    if int(raw_index) >= len(values):
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


def _assert_design_top_level_ref(ref: object, payload: dict, path: str) -> None:
    if not isinstance(ref, str):
        raise ValueError(f"design contract ref must be a string: {path}")
    if not ref.startswith("design.json#"):
        raise ValueError(f"design contract ref must target design.json: {path}={ref}")
    _resolve_dotted_path(payload, ref.removeprefix("design.json#"))


def _assert_design_input_param(
    param: object, interface_index: int, param_index: int
) -> None:
    path = f"interfaces[{interface_index}].input_params[{param_index}]"
    if not isinstance(param, dict):
        raise ValueError(f"design {path} must be an object")
    for field in ("name", "type", "validation", "description"):
        _require_non_empty_string(param.get(field), f"{path}.{field}")
    if not isinstance(param.get("required"), bool):
        raise ValueError(f"design {path}.required must be boolean")


def _assert_design_output_param(
    param: object, interface_index: int, param_index: int
) -> None:
    path = f"interfaces[{interface_index}].output_params[{param_index}]"
    if not isinstance(param, dict):
        raise ValueError(f"design {path} must be an object")
    for field in ("name", "type", "description"):
        _require_non_empty_string(param.get(field), f"{path}.{field}")


def _assert_design_error_code(
    error_code: object, interface_index: int, code_index: int
) -> None:
    path = f"interfaces[{interface_index}].error_codes[{code_index}]"
    if not isinstance(error_code, dict):
        raise ValueError(f"design {path} must be an object")
    for field in ("code", "condition", "user_message"):
        _require_non_empty_string(error_code.get(field), f"{path}.{field}")


def _assert_design_interface(interface: object, index: int) -> None:
    if not isinstance(interface, dict):
        raise ValueError(f"design interfaces[{index}] must be an object")
    for field in ("interface_id", "owner", "contract_summary"):
        _require_non_empty_string(interface.get(field), f"interfaces[{index}].{field}")
    _require_string_list(
        interface.get("error_modes"), f"interfaces[{index}].error_modes"
    )
    input_params = _require_non_empty_list(
        interface.get("input_params"), f"interfaces[{index}].input_params"
    )
    output_params = _require_non_empty_list(
        interface.get("output_params"), f"interfaces[{index}].output_params"
    )
    error_codes = _require_non_empty_list(
        interface.get("error_codes"), f"interfaces[{index}].error_codes"
    )
    for param_index, param in enumerate(input_params):
        _assert_design_input_param(param, index, param_index)
    for param_index, param in enumerate(output_params):
        _assert_design_output_param(param, index, param_index)
    for code_index, error_code in enumerate(error_codes):
        _assert_design_error_code(error_code, index, code_index)


def _assert_design_confirmations(payload: dict) -> None:
    _assert_design_co_creation(payload)
    _assert_constraint_inheritance_confirmation(payload)
    _assert_final_confirmation(payload)


def _assert_design_co_creation(payload: dict) -> None:
    co_creation = _require_non_empty_list(
        payload.get("co_creation_summary"), "co_creation_summary"
    )
    seen_stages: set[str] = set()
    for index, row in enumerate(co_creation):
        if not isinstance(row, dict):
            raise ValueError(f"design co_creation_summary[{index}] must be an object")
        stage_id = row.get("stage_id")
        _require_non_empty_string(stage_id, f"co_creation_summary[{index}].stage_id")
        seen_stages.add(stage_id)
        for field in ("stage_name", "question_or_focus", "user_response_summary"):
            _require_non_empty_string(
                row.get(field), f"co_creation_summary[{index}].{field}"
            )
        refs = _require_string_list(
            row.get("decision_refs"), f"co_creation_summary[{index}].decision_refs"
        )
        for ref_index, ref in enumerate(refs):
            _assert_design_top_level_ref(
                ref, payload, f"co_creation_summary[{index}].decision_refs[{ref_index}]"
            )
    missing_stages = sorted(DESIGN_REQUIRED_CO_CREATION_STAGES - seen_stages)
    if missing_stages:
        raise ValueError(f"design co_creation_summary missing stages: {missing_stages}")


def _assert_constraint_inheritance_confirmation(payload: dict) -> None:
    inheritance = _require_non_empty_dict(
        payload.get("constraint_inheritance_confirmation"),
        "constraint_inheritance_confirmation",
    )
    if inheritance.get("status") != "confirmed":
        raise ValueError(
            "design constraint_inheritance_confirmation.status must be confirmed"
        )
    _require_non_empty_string(
        inheritance.get("confirmed_at"),
        "constraint_inheritance_confirmation.confirmed_at",
    )
    _require_string_list(
        inheritance.get("source_refs"),
        "constraint_inheritance_confirmation.source_refs",
    )
    _require_string_list(
        inheritance.get("inherited_constraints"),
        "constraint_inheritance_confirmation.inherited_constraints",
    )
    if not isinstance(inheritance.get("rejected_constraints"), list):
        raise ValueError(
            "design constraint_inheritance_confirmation.rejected_constraints must be an array"
        )
    _require_non_empty_string(
        inheritance.get("confirmation_summary"),
        "constraint_inheritance_confirmation.confirmation_summary",
    )


def _assert_final_confirmation(payload: dict) -> None:
    final = _require_non_empty_dict(
        payload.get("final_confirmation"), "final_confirmation"
    )
    if final.get("status") != "confirmed":
        raise ValueError("design final_confirmation.status must be confirmed")
    for field in ("confirmed_by", "confirmed_at", "summary"):
        _require_non_empty_string(final.get(field), f"final_confirmation.{field}")
    accepted_refs = _require_string_list(
        final.get("accepted_refs"), "final_confirmation.accepted_refs"
    )
    for index, ref in enumerate(accepted_refs):
        _assert_design_top_level_ref(
            ref, payload, f"final_confirmation.accepted_refs[{index}]"
        )


def _assert_design_interfaces(payload: dict) -> None:
    interfaces = _require_non_empty_list(payload.get("interfaces"), "interfaces")
    for index, interface in enumerate(interfaces):
        _assert_design_interface(interface, index)


def _design_ref_sets(payload: dict) -> tuple[set[str], set[str]]:
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
    return module_ids, interface_ids


def _assert_data_architecture(payload: dict) -> None:
    data_architecture = _require_non_empty_dict(
        payload.get("data_architecture"), "data_architecture"
    )
    for field in ("summary", "consistency_strategy"):
        _require_non_empty_string(
            data_architecture.get(field), f"data_architecture.{field}"
        )
    for field in ("storage_decisions", "data_flows"):
        _require_non_empty_list(
            data_architecture.get(field), f"data_architecture.{field}"
        )


def _assert_cross_cutting_concerns(payload: dict) -> None:
    concerns = _require_non_empty_list(
        payload.get("cross_cutting_concerns"), "cross_cutting_concerns"
    )
    concern_names = {
        concern.get("concern") for concern in concerns if isinstance(concern, dict)
    }
    missing_concerns = sorted(DESIGN_REQUIRED_CONCERNS - concern_names)
    if missing_concerns:
        raise ValueError(
            f"design cross_cutting_concerns missing required concerns: {missing_concerns}"
        )
    for index, concern in enumerate(concerns):
        if not isinstance(concern, dict):
            raise ValueError(
                f"design cross_cutting_concerns[{index}] must be an object"
            )
        _require_non_empty_string(
            concern.get("decision"), f"cross_cutting_concerns[{index}].decision"
        )
        _require_non_empty_string(
            concern.get("owner"), f"cross_cutting_concerns[{index}].owner"
        )
        _require_non_empty_list(
            concern.get("verification_refs"),
            f"cross_cutting_concerns[{index}].verification_refs",
        )
