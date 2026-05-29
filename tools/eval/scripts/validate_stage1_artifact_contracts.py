#!/usr/bin/env python3
"""Validate the Stage 1 capability contracts that must not drift silently."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from validate_stage1_docs_contracts import check_stage1_documentation


ROOT = Path(__file__).resolve().parents[3]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_simple_yaml_lists(path: Path) -> dict[str, list[str]]:
    """Parse the simple top-level list shape used by vocabulary-registry.yaml."""

    result: dict[str, list[str]] = {}
    current_key: str | None = None
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if not raw_line.startswith(" ") and line.endswith(":"):
            current_key = line[:-1]
            result[current_key] = []
            continue
        if current_key and line.startswith("- "):
            result[current_key].append(line[2:])
    return result


def require(checks: list[str], condition: bool, message: str) -> None:
    if not condition:
        checks.append(message)


def required_set(schema_fragment: dict[str, Any]) -> set[str]:
    values = schema_fragment.get("required", [])
    return {str(value) for value in values if isinstance(value, str)}


def enum_set(schema_fragment: dict[str, Any]) -> set[str]:
    values = schema_fragment.get("enum", [])
    return {str(value) for value in values if isinstance(value, str)}


def make_check(contract: str, failures: list[str], details: dict[str, Any]) -> dict[str, Any]:
    return {
        "contract": contract,
        "status": "fail" if failures else "pass",
        "failures": failures,
        "details": details,
    }


def check_typed_gap(repo_root: Path) -> dict[str, Any]:
    failures: list[str] = []
    schema = load_json(repo_root / "shared/skills/test-design/contracts/test-cases.schema.json")
    local_schema = schema["allOf"][1]
    gap_types = enum_set(local_schema["$defs"]["gapType"])
    gap_item = local_schema["properties"]["design_gap_report"]["properties"]["gaps"]["items"]
    gap_required = required_set(gap_item)
    owner_enum = enum_set(gap_item["properties"]["owner"])

    expected_required = {
        "gap_id",
        "gap_type",
        "blocking_refs",
        "owner",
        "next_action",
        "blocking",
    }
    expected_gap_types = {"PRODUCT_GAP", "DESIGN_GAP", "TESTABILITY_GAP", "SCOPE_DRIFT", "TRACE_CONFLICT"}
    expected_owners = {
        "product-director",
        "product-manager",
        "design",
        "test-design",
        "qa",
        "delivery-owner",
        "user",
    }

    require(
        failures,
        expected_required <= gap_required,
        f"typed_gap required fields missing: {sorted(expected_required - gap_required)}",
    )
    require(
        failures,
        expected_gap_types <= gap_types,
        f"typed_gap gap_type enum missing: {sorted(expected_gap_types - gap_types)}",
    )
    require(
        failures,
        expected_owners <= owner_enum,
        f"typed_gap owner enum missing: {sorted(expected_owners - owner_enum)}",
    )
    require(
        failures,
        gap_item.get("additionalProperties") is False,
        "typed_gap gap item must reject unknown fields",
    )

    return make_check(
        "typed_gap",
        failures,
        {
            "schema": "shared/skills/test-design/contracts/test-cases.schema.json",
            "required_fields": sorted(gap_required),
            "gap_types": sorted(gap_types),
            "owners": sorted(owner_enum),
        },
    )


def check_design_interface(repo_root: Path) -> dict[str, Any]:
    failures: list[str] = []
    schema = load_json(repo_root / "shared/skills/design/contracts/design.schema.json")
    local_schema = schema["allOf"][1]
    root_required = required_set(local_schema)
    interface_item = local_schema["properties"]["interfaces"]["items"]
    interface_required = required_set(interface_item)
    input_item = interface_item["properties"]["input_params"]["items"]
    output_item = interface_item["properties"]["output_params"]["items"]
    error_item = interface_item["properties"]["error_codes"]["items"]

    expected_interface_required = {
        "interface_id",
        "owner",
        "error_modes",
        "input_params",
        "output_params",
        "error_codes",
        "boundary_behaviors",
    }
    expected_input_required = {"name", "type", "required", "validation", "description"}
    expected_output_required = {"name", "type", "description"}
    expected_error_required = {"code", "condition", "user_message"}
    expected_execution_fields = {
        "quality_attributes",
        "verification_mapping",
        "rollback_plan",
        "migration_plan",
        "impact_scope",
        "planning_constraints",
    }

    require(
        failures,
        expected_interface_required <= interface_required,
        f"design_interface required fields missing: {sorted(expected_interface_required - interface_required)}",
    )
    require(
        failures,
        expected_input_required <= required_set(input_item),
        f"design_interface input fields missing: {sorted(expected_input_required - required_set(input_item))}",
    )
    require(
        failures,
        expected_output_required <= required_set(output_item),
        f"design_interface output fields missing: {sorted(expected_output_required - required_set(output_item))}",
    )
    require(
        failures,
        expected_error_required <= required_set(error_item),
        f"design_interface error fields missing: {sorted(expected_error_required - required_set(error_item))}",
    )
    require(
        failures,
        expected_execution_fields <= root_required,
        f"design execution support fields missing: {sorted(expected_execution_fields - root_required)}",
    )

    return make_check(
        "design_interface",
        failures,
        {
            "schema": "shared/skills/design/contracts/design.schema.json",
            "interface_required": sorted(interface_required),
            "execution_support_fields": sorted(expected_execution_fields),
        },
    )


def check_task_packet(repo_root: Path) -> dict[str, Any]:
    failures: list[str] = []
    schema = load_json(repo_root / "shared/skills/tech-lead/contracts/tasks.schema.json")
    local_schema = schema["allOf"][1]
    task_item = local_schema["properties"]["tasks"]["items"]
    task_required = required_set(task_item)
    task_packet_check = repo_root / "shared/skills/delivery-owner/scripts/task_packet_check.py"
    dispatch_packet_ref = repo_root / "shared/skills/delivery-owner/references/dispatch-packet.md"

    expected_task_fields = {
        "task_id",
        "task_title",
        "phase_ref",
        "unit_refs",
        "scope_item_refs",
        "design_refs",
        "test_refs",
        "depends_on",
        "shared_files",
        "batch",
        "acceptance_targets",
        "proving_command",
        "real_dependency_refs",
        "evidence_target",
        "mock_boundary",
    }
    require(
        failures,
        expected_task_fields <= task_required,
        f"task_packet required fields missing: {sorted(expected_task_fields - task_required)}",
    )
    require(failures, task_packet_check.is_file(), "task_packet validator script missing")
    require(failures, dispatch_packet_ref.is_file(), "task_packet dispatch reference missing")
    if task_packet_check.is_file():
        script_text = task_packet_check.read_text(encoding="utf-8")
        require(failures, "def validate(packet" in script_text, "task_packet validator must expose validate(packet)")
        require(failures, "DISPATCH_READY" in script_text, "task_packet validator must produce DISPATCH_READY")
    if dispatch_packet_ref.is_file():
        ref_text = dispatch_packet_ref.read_text(encoding="utf-8")
        require(
            failures,
            "task_packet_check.sh --packet" in ref_text,
            "task_packet reference must document deterministic check command",
        )

    return make_check(
        "task_packet",
        failures,
        {
            "schema": "shared/skills/tech-lead/contracts/tasks.schema.json",
            "validator": "shared/skills/delivery-owner/scripts/task_packet_check.py",
            "reference": "shared/skills/delivery-owner/references/dispatch-packet.md",
            "required_fields": sorted(task_required),
        },
    )


def check_signoff_gate(repo_root: Path) -> dict[str, Any]:
    failures: list[str] = []
    signoff_schema = load_json(repo_root / "shared/skills/delivery-owner/contracts/signoff-package.schema.json")
    shared_core = load_json(repo_root / "shared/skills/lib/contracts/shared-core.schema.json")
    vocabulary = load_simple_yaml_lists(repo_root / "contracts/canonical/vocabulary-registry.yaml")
    local_schema = signoff_schema["allOf"][1]
    signoff_required = required_set(local_schema)

    expected_required = {
        "artifact_type",
        "current_stage",
        "release_recommendation",
        "sign_off_status",
        "business_risk_acceptance_status",
        "goal_closure",
        "waiver_entries",
        "last_observed_at",
        "runtime_snapshot",
        "active_blocker",
        "blocker_owner",
        "decision_basis_refs",
        "baseline_tasks_version_ref",
        "active_tasks_version_ref",
    }
    expected_vocab = {
        "release_recommendation": ["ALLOW", "CONDITIONAL_ALLOW", "BLOCK", "DEFER"],
        "sign_off_status": ["PENDING", "SIGNED_OFF", "REJECTED", "SUPERSEDED"],
        "business_risk_acceptance_status": ["NOT_REQUIRED", "PENDING", "ACCEPTED", "REJECTED", "SUPERSEDED"],
    }

    require(
        failures,
        expected_required <= signoff_required,
        f"signoff_gate required fields missing: {sorted(expected_required - signoff_required)}",
    )
    for field_name, expected_values in expected_vocab.items():
        core_values = list(shared_core["properties"][field_name]["enum"])
        registry_values = vocabulary.get(field_name)
        require(
            failures,
            core_values == expected_values,
            f"shared-core {field_name} enum mismatch: {core_values}",
        )
        require(
            failures,
            registry_values == expected_values,
            f"vocabulary {field_name} enum mismatch: {registry_values}",
        )

    return make_check(
        "signoff_gate",
        failures,
        {
            "schema": "shared/skills/delivery-owner/contracts/signoff-package.schema.json",
            "shared_core_schema": "shared/skills/lib/contracts/shared-core.schema.json",
            "vocabulary_registry": "contracts/canonical/vocabulary-registry.yaml",
            "required_fields": sorted(signoff_required),
        },
    )


def check_terminology_registry(repo_root: Path) -> dict[str, Any]:
    failures: list[str] = []
    vocabulary = load_simple_yaml_lists(repo_root / "contracts/canonical/vocabulary-registry.yaml")
    expected_terms = {
        "status",
        "gate_result",
        "release_recommendation",
        "control_action",
        "decision",
        "severity",
        "priority",
        "runtime_status",
        "sign_off_status",
        "business_risk_acceptance_status",
        "goal_closure_result",
    }
    require(
        failures,
        expected_terms <= set(vocabulary),
        f"terminology registry missing keys: {sorted(expected_terms - set(vocabulary))}",
    )
    for key in expected_terms:
        values = vocabulary.get(key, [])
        require(failures, len(values) == len(set(values)), f"terminology registry has duplicate values: {key}")
        require(failures, bool(values), f"terminology registry key has no values: {key}")

    return make_check(
        "terminology_registry",
        failures,
        {
            "registry": "contracts/canonical/vocabulary-registry.yaml",
            "keys": sorted(vocabulary),
        },
    )


def validate(repo_root: Path) -> dict[str, Any]:
    checks = [
        check_typed_gap(repo_root),
        check_task_packet(repo_root),
        check_design_interface(repo_root),
        check_signoff_gate(repo_root),
        check_terminology_registry(repo_root),
        check_stage1_documentation(repo_root),
    ]
    failed_checks = [
        f"{check['contract']}: {failure}"
        for check in checks
        for failure in check["failures"]
    ]
    return {
        "status": "fail" if failed_checks else "pass",
        "failed_checks": failed_checks,
        "checks": checks,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=ROOT)
    args = parser.parse_args()
    payload = validate(args.repo_root.resolve())
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if payload["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
