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
DESIGN_CANDIDATE_ONLY_FIELDS = {
    "candidate_design_json",
    "open_warns",
    "handoff_summary",
    "co_creation_confirmations",
    "source_refs",
}
DESIGN_WARN_TARGETS = {
    "design.json#planning_constraints",
    "design.json#risk_response",
    "design.json#verification_mapping",
    "design.json#product_handoff",
}


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
    _assert_design_canonical_cleanup(payload)
    _assert_design_co_creation(payload)
    _assert_constraint_inheritance_confirmation(payload)
    _assert_review_closure(payload)
    _assert_final_confirmation(payload)


def _walk_values(value: object):
    yield value
    if isinstance(value, dict):
        for child in value.values():
            yield from _walk_values(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_values(child)


def _assert_design_canonical_cleanup(payload: dict) -> None:
    leaked_fields = sorted(DESIGN_CANDIDATE_ONLY_FIELDS & set(payload))
    if leaked_fields:
        raise ValueError(
            f"design contract contains candidate-package-only fields: {leaked_fields}"
        )
    for value in _walk_values(payload):
        if isinstance(value, str) and re.search(r"<[^>]+>", value):
            raise ValueError(f"design contract contains unresolved placeholder: {value}")


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
    for field in ("source_refs", "inherited_constraints", "rejected_constraints"):
        values = inheritance.get(field)
        if not isinstance(values, list):
            raise ValueError(
                f"design constraint_inheritance_confirmation.{field} must be an array"
            )
        for index, value in enumerate(values):
            _require_non_empty_string(
                value, f"constraint_inheritance_confirmation.{field}[{index}]"
            )
    _require_non_empty_string(
        inheritance.get("confirmation_summary"),
        "constraint_inheritance_confirmation.confirmation_summary",
    )


def _assert_review_closure(payload: dict) -> None:
    review = _require_non_empty_dict(payload.get("review_closure"), "review_closure")
    digest = review.get("candidate_digest")
    if not isinstance(digest, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise ValueError("design review_closure.candidate_digest must be sha256 digest")
    _require_non_empty_string(review.get("reviewed_at"), "review_closure.reviewed_at")

    reviewers = _require_non_empty_list(review.get("reviewers"), "review_closure.reviewers")
    reviewer_names: set[str] = set()
    warn_finding_refs: set[str] = set()
    for index, reviewer in enumerate(reviewers):
        if not isinstance(reviewer, dict):
            raise ValueError(f"design review_closure.reviewers[{index}] must be an object")
        name = reviewer.get("reviewer")
        if name not in {"architecture", "product", "test"}:
            raise ValueError(f"design review_closure.reviewers[{index}].reviewer invalid")
        reviewer_names.add(name)
        if reviewer.get("verdict") not in {"PASS", "WARN"}:
            raise ValueError(f"design review_closure.reviewers[{index}].verdict must be PASS or WARN")
        if reviewer.get("reviewed_candidate_digest") != digest:
            raise ValueError(
                f"design review_closure.reviewers[{index}].reviewed_candidate_digest must match candidate_digest"
            )
        finding_refs = reviewer.get("finding_refs")
        if not isinstance(finding_refs, list):
            raise ValueError(f"design review_closure.reviewers[{index}].finding_refs must be an array")
        for ref_index, finding_ref in enumerate(finding_refs):
            _require_non_empty_string(
                finding_ref,
                f"review_closure.reviewers[{index}].finding_refs[{ref_index}]",
            )
            if reviewer.get("verdict") == "WARN":
                warn_finding_refs.add(finding_ref)
    missing_reviewers = sorted({"architecture", "product", "test"} - reviewer_names)
    if missing_reviewers:
        raise ValueError(f"design review_closure missing reviewers: {missing_reviewers}")

    resolved_failures = review.get("resolved_failures")
    if not isinstance(resolved_failures, list):
        raise ValueError("design review_closure.resolved_failures must be an array")
    for index, row in enumerate(resolved_failures):
        if not isinstance(row, dict):
            raise ValueError(f"design review_closure.resolved_failures[{index}] must be an object")
        for field in ("finding_id", "evidence_ref"):
            _require_non_empty_string(
                row.get(field), f"review_closure.resolved_failures[{index}].{field}"
            )

    warn_followups = review.get("warn_followups")
    if not isinstance(warn_followups, list):
        raise ValueError("design review_closure.warn_followups must be an array")
    followup_ids: set[str] = set()
    for index, row in enumerate(warn_followups):
        if not isinstance(row, dict):
            raise ValueError(f"design review_closure.warn_followups[{index}] must be an object")
        for field in ("finding_id", "target", "summary"):
            _require_non_empty_string(
                row.get(field), f"review_closure.warn_followups[{index}].{field}"
            )
        followup_ids.add(row.get("finding_id"))
        if row.get("target") not in DESIGN_WARN_TARGETS:
            raise ValueError(
                f"design review_closure.warn_followups[{index}].target unsupported: {row.get('target')}"
            )
    missing_followups = sorted(warn_finding_refs - followup_ids)
    if missing_followups:
        raise ValueError(
            f"design review_closure missing warn_followups for WARN findings: {missing_followups}"
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


def _assert_key_decisions(payload: dict) -> None:
    options_by_decision: dict[str, set[str]] = {}
    seen_option_ids: set[str] = set()
    for option_index, option in enumerate(
        _require_non_empty_list(payload.get("option_analysis"), "option_analysis")
    ):
        if not isinstance(option, dict):
            raise ValueError(f"design option_analysis[{option_index}] must be an object")
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
            raise ValueError(f"design option_analysis option_id duplicated: {option_id}")
        seen_option_ids.add(option_id)
        options_by_decision.setdefault(option["decision_ref"], set()).add(option_id)

    decisions = _require_non_empty_list(payload.get("key_decisions"), "key_decisions")
    for index, decision in enumerate(decisions):
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
            raise ValueError(f"design key_decisions[{index}].decision_state must be 已冻结")
        decision_id = decision["decision_id"]
        decision_options = options_by_decision.get(decision_id, set())
        if len(decision_options) < 2:
            raise ValueError(
                f"design key_decisions[{index}] must have at least two options: {decision_id}"
            )
        option_ref = decision.get("option_ref")
        if option_ref not in decision_options:
            raise ValueError(
                "design key_decisions[{index}].option_ref does not resolve "
                "within decision_ref group: {option_ref}".format(
                    index=index, option_ref=option_ref
                )
            )
        fact_refs = _require_string_list(
            decision.get("fact_refs"), f"key_decisions[{index}].fact_refs"
        )
        for ref_index, ref in enumerate(fact_refs):
            _assert_design_top_level_ref(
                ref, payload, f"key_decisions[{index}].fact_refs[{ref_index}]"
            )


def _assert_design_interfaces(payload: dict) -> None:
    interfaces = _require_non_empty_list(payload.get("interfaces"), "interfaces")
    for index, interface in enumerate(interfaces):
        _assert_design_interface(interface, index)


def _assert_runtime_facts(payload: dict) -> None:
    facts = _require_string_list(payload.get("runtime_facts"), "runtime_facts")
    for index, fact in enumerate(facts):
        if "evidence=" not in fact or "observed_at=" not in fact:
            raise ValueError(
                "design runtime_facts[{index}] must include evidence= and observed_at=".format(
                    index=index
                )
            )


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
