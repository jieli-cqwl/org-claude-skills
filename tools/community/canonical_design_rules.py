from __future__ import annotations

import re

import canonical_design_errors as err
from canonical_design_confirmation_rules import assert_design_confirmations
from canonical_rule_common import (
    _require_non_empty_dict,
    _require_non_empty_list,
    _require_non_empty_string,
    _require_string_list,
    _resolve_dotted_path,
)

DESIGN_REQUIRED_CONCERNS = {"auth", "error", "log", "config"}
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
        raise ValueError(err.missing_unit_artifacts(missing_units, sorted(unit_map)))
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
        raise ValueError(err.manager_ref_not_string(path, ref))
    match = DESIGN_MANAGER_REF_RE.match(ref)
    if not match:
        array_fields = sorted(k for k, v in phase_prd.items() if isinstance(v, list))
        raise ValueError(err.manager_ref_bad_format(path, ref, array_fields))
    _artifact_name, field, raw_index = match.groups()
    values = phase_prd.get(field)
    if not isinstance(values, list):
        array_fields = sorted(k for k, v in phase_prd.items() if isinstance(v, list))
        raise ValueError(err.manager_ref_not_array(path, ref, field, array_fields))
    if int(raw_index) >= len(values):
        raise ValueError(err.manager_ref_out_of_range(path, ref, field, len(values)))


def _assert_handoff_ref(ref: object, documents: dict[str, dict], path: str) -> None:
    if not isinstance(ref, str):
        raise ValueError(err.handoff_ref_not_string(path, ref))
    match = DESIGN_HANDOFF_REF_RE.match(ref)
    if not match:
        raise ValueError(err.handoff_ref_bad_format(path, ref))
    document_name, anchor = match.groups()
    document = documents.get(document_name)
    if document is None:
        raise ValueError(err.handoff_ref_document_missing(path, ref, document_name))
    if not _anchor_exists(document, anchor):
        raise ValueError(
            err.handoff_ref_anchor_missing(path, ref, document_name, sorted(document))
        )


def _assert_design_top_level_ref(ref: object, payload: dict, path: str) -> None:
    if not isinstance(ref, str):
        raise ValueError(err.design_ref_not_string(path, ref))
    if not ref.startswith("design.json#"):
        raise ValueError(err.design_ref_wrong_prefix(path, ref))
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
    boundary_behaviors = _require_non_empty_list(
        interface.get("boundary_behaviors"),
        f"interfaces[{index}].boundary_behaviors",
    )
    for behavior_index, behavior in enumerate(boundary_behaviors):
        if not isinstance(behavior, dict):
            raise ValueError(
                f"design interfaces[{index}].boundary_behaviors[{behavior_index}] must be an object"
            )
        for field in ("scenario", "expected_behavior", "verification_ref"):
            _require_non_empty_string(
                behavior.get(field),
                f"interfaces[{index}].boundary_behaviors[{behavior_index}].{field}",
            )


def _assert_design_confirmations(payload: dict) -> None:
    assert_design_confirmations(payload, _assert_design_top_level_ref)


def _collect_option_analysis(payload: dict) -> dict[str, set[str]]:
    options_by_decision: dict[str, set[str]] = {}
    seen_option_ids: set[str] = set()
    for option_index, option in enumerate(
        _require_non_empty_list(payload.get("option_analysis"), "option_analysis")
    ):
        if not isinstance(option, dict):
            raise ValueError(
                f"design option_analysis[{option_index}] must be an object"
            )
        for field in ("option_id", "decision_ref", "summary", "tradeoff", "verdict"):
            _require_non_empty_string(
                option.get(field), f"option_analysis[{option_index}].{field}"
            )
        fact_refs = _require_string_list(
            option.get("fact_refs"), f"option_analysis[{option_index}].fact_refs"
        )
        for ref_index, ref in enumerate(fact_refs):
            _assert_design_top_level_ref(
                ref, payload, f"option_analysis[{option_index}].fact_refs[{ref_index}]"
            )
        option_id = option["option_id"]
        if option_id in seen_option_ids:
            raise ValueError(
                f"design option_analysis option_id duplicated: {option_id}"
            )
        seen_option_ids.add(option_id)
        options_by_decision.setdefault(option["decision_ref"], set()).add(option_id)
    return options_by_decision


def _assert_frozen_decision(
    decision: object,
    index: int,
    options_by_decision: dict[str, set[str]],
    payload: dict,
) -> None:
    if not isinstance(decision, dict):
        raise ValueError(f"design key_decisions[{index}] must be an object")
    for field in (
        "decision_id",
        "summary",
        "verdict",
        "option_ref",
        "user_confirmation",
    ):
        _require_non_empty_string(
            decision.get(field), f"key_decisions[{index}].{field}"
        )
    if decision.get("decision_state") != "已冻结":
        raise ValueError(
            err.decision_state_not_frozen(index, decision.get("decision_state"))
        )
    decision_id = decision["decision_id"]
    decision_options = options_by_decision.get(decision_id, set())
    if len(decision_options) < 2:
        raise ValueError(
            err.decision_options_too_few(index, decision_id, sorted(decision_options))
        )
    option_ref = decision.get("option_ref")
    if option_ref not in decision_options:
        raise ValueError(
            err.decision_option_ref_mismatch(
                index, option_ref, decision_id, sorted(decision_options)
            )
        )
    fact_refs = _require_string_list(
        decision.get("fact_refs"), f"key_decisions[{index}].fact_refs"
    )
    for ref_index, ref in enumerate(fact_refs):
        _assert_design_top_level_ref(
            ref, payload, f"key_decisions[{index}].fact_refs[{ref_index}]"
        )


def _assert_key_decisions(payload: dict) -> None:
    options_by_decision = _collect_option_analysis(payload)
    decisions = _require_non_empty_list(payload.get("key_decisions"), "key_decisions")
    for index, decision in enumerate(decisions):
        _assert_frozen_decision(decision, index, options_by_decision, payload)


def _assert_design_interfaces(payload: dict) -> None:
    interfaces = payload.get("interfaces")
    if not isinstance(interfaces, list):
        raise ValueError("design interfaces must be an array")
    boundary = _require_non_empty_list(payload.get("interface_boundary"), "interface_boundary")
    for index, row in enumerate(boundary):
        _require_non_empty_string(row, f"interface_boundary[{index}]")
    for index, interface in enumerate(interfaces):
        _assert_design_interface(interface, index)


def _assert_runtime_facts(payload: dict) -> None:
    facts = _require_string_list(payload.get("runtime_facts"), "runtime_facts")
    for index, fact in enumerate(facts):
        if "evidence=" not in fact or "observed_at=" not in fact:
            raise ValueError(err.runtime_fact_missing_tokens(index, fact))


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
            err.cross_cutting_missing_concerns(
                missing_concerns,
                sorted(DESIGN_REQUIRED_CONCERNS),
                sorted(n for n in concern_names if isinstance(n, str)),
            )
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


def _assert_quality_attributes(payload: dict) -> None:
    attributes = _require_non_empty_list(
        payload.get("quality_attributes"), "quality_attributes"
    )
    for index, attribute in enumerate(attributes):
        if not isinstance(attribute, dict):
            raise ValueError(f"design quality_attributes[{index}] must be an object")
        for field in ("attribute", "priority"):
            _require_non_empty_string(
                attribute.get(field), f"quality_attributes[{index}].{field}"
            )
        for field in (
            "key_scenarios",
            "target_metrics",
            "tradeoff_points",
            "verification_refs",
        ):
            _require_string_list(
                attribute.get(field), f"quality_attributes[{index}].{field}"
            )
