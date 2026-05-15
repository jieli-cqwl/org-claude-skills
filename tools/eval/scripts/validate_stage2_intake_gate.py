#!/usr/bin/env python3
"""Validate the Stage 2 intake facts required before real qft-pai discovery."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_INTAKE = ROOT / "docs/feature--agent-delivery-operating-system/stage-2-intake-facts.example.json"
PLACEHOLDERS = {"", "todo", "tbd", "待补充", "待确认", "<fill>", "<填写>"}
EXAMPLE_FILENAME = "stage-2-intake-facts.example.json"
TEMPLATE_FILENAME = "stage-2-intake-facts.template.json"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def dotted_get(payload: dict[str, Any], path: str) -> Any:
    current: Any = payload
    for part in path.split("."):
        if not isinstance(current, dict):
            return None
        current = current.get(part)
    return current


def is_filled(value: Any) -> bool:
    if isinstance(value, str):
        return value.strip().lower() not in PLACEHOLDERS
    if isinstance(value, list):
        return bool(value) and all(is_filled(item) for item in value)
    if isinstance(value, bool):
        return True
    return value is not None


def add_failure(failures: list[str], field: str, reason: str = "missing or placeholder") -> None:
    failures.append(f"{field}: {reason}")


def require_fields(payload: dict[str, Any], fields: list[str]) -> list[str]:
    failures: list[str] = []
    for field in fields:
        if not is_filled(dotted_get(payload, field)):
            add_failure(failures, field)
    return failures


def make_check(name: str, failures: list[str]) -> dict[str, Any]:
    return {"check": name, "status": "fail" if failures else "pass", "failures": failures}


def check_business_sample(payload: dict[str, Any]) -> dict[str, Any]:
    return make_check(
        "business_sample",
        require_fields(
            payload,
            [
                "business_sample.sample_name",
                "business_sample.business_owner",
                "business_sample.real_user",
                "business_sample.scenario",
                "business_sample.current_pain",
                "business_sample.target_outcome",
            ],
        ),
    )


def check_intake_provenance(payload: dict[str, Any], kind: str) -> dict[str, Any]:
    failures = require_fields(
        payload,
        [
            "intake_provenance.source_type",
            "intake_provenance.filled_by",
            "intake_provenance.confirmed_by",
            "intake_provenance.confirmed_at",
            "intake_provenance.confirmation_basis",
            "intake_provenance.fact_source_refs",
        ],
    )
    source_type = dotted_get(payload, "intake_provenance.source_type")
    not_copied = dotted_get(payload, "intake_provenance.not_copied_from_example")
    source_refs = dotted_get(payload, "intake_provenance.fact_source_refs") or []
    joined_refs = "\n".join(str(ref) for ref in source_refs)
    if kind == "example":
        if source_type != "example":
            add_failure(failures, "intake_provenance.source_type", "example file must declare source_type=example")
        if not any(str(ref).startswith("fixture://") for ref in source_refs):
            add_failure(failures, "intake_provenance.fact_source_refs", "example file must use fixture:// source refs")
        if not_copied is not False:
            add_failure(failures, "intake_provenance.not_copied_from_example", "example file must remain false")
    elif kind == "real_intake_candidate":
        if source_type != "human_business_owner_input":
            add_failure(
                failures,
                "intake_provenance.source_type",
                "real facts must declare source_type=human_business_owner_input",
            )
        if not_copied is not True:
            add_failure(
                failures,
                "intake_provenance.not_copied_from_example",
                "real facts must explicitly confirm they are not a renamed example",
            )
        allowed_prefixes = ("human://", "meeting://", "ticket://", "doc://", "evidence://", "repo://")
        if not any(str(ref).startswith(allowed_prefixes) for ref in source_refs):
            add_failure(
                failures,
                "intake_provenance.fact_source_refs",
                "real facts must include at least one human/meeting/ticket/doc/evidence/repo source ref",
            )
        if "fixture://" in joined_refs or "example" in joined_refs.lower():
            add_failure(
                failures,
                "intake_provenance.fact_source_refs",
                "real facts must not reuse fixture/example source refs",
            )
    return make_check("intake_provenance", failures)


def check_acceptance_owner(payload: dict[str, Any]) -> dict[str, Any]:
    return make_check(
        "acceptance_owner",
        require_fields(
            payload,
            [
                "acceptance_owner.name",
                "acceptance_owner.role",
                "acceptance_owner.decision_authority",
                "acceptance_owner.acceptance_method",
            ],
        ),
    )


def check_success_metrics(payload: dict[str, Any]) -> dict[str, Any]:
    failures: list[str] = []
    metrics = payload.get("success_metrics")
    if not isinstance(metrics, list) or not metrics:
        add_failure(failures, "success_metrics")
        return make_check("success_metrics", failures)
    for index, metric in enumerate(metrics):
        if not isinstance(metric, dict):
            add_failure(failures, f"success_metrics[{index}]", "must be object")
            continue
        for field in ["metric_id", "name", "threshold", "measurement_source", "owner"]:
            if not is_filled(metric.get(field)):
                add_failure(failures, f"success_metrics[{index}].{field}")
    return make_check("success_metrics", failures)


def check_execution_environment(payload: dict[str, Any]) -> dict[str, Any]:
    failures = require_fields(
        payload,
        [
            "execution_environment.qft_pai_repo_path",
            "execution_environment.environment_name",
            "execution_environment.access_owner",
            "execution_environment.external_dependencies",
        ],
    )
    path = dotted_get(payload, "execution_environment.qft_pai_repo_path")
    if path != "/Users/lijieli/project/qft-pai":
        add_failure(failures, "execution_environment.qft_pai_repo_path", "must target /Users/lijieli/project/qft-pai")
    if dotted_get(payload, "execution_environment.available_for_discovery") is not True:
        add_failure(failures, "execution_environment.available_for_discovery", "must be true")
    return make_check("execution_environment", failures)


def check_qft_pai_scope(payload: dict[str, Any]) -> dict[str, Any]:
    return make_check(
        "qft_pai_scope",
        require_fields(
            payload,
            [
                "qft_pai_scope.phase1_boundary",
                "qft_pai_scope.in_scope_flow",
                "qft_pai_scope.out_of_scope",
                "qft_pai_scope.non_goals",
            ],
        ),
    )


def check_integration_boundaries(payload: dict[str, Any]) -> dict[str, Any]:
    failures = require_fields(
        payload,
        [
            "integration_boundaries.entrypoints",
            "integration_boundaries.third_party_callbacks",
            "integration_boundaries.data_sources",
            "integration_boundaries.manual_handoff",
            "integration_boundaries.auto_send_policy",
        ],
    )
    if dotted_get(payload, "integration_boundaries.auto_send_allowed") is not False:
        add_failure(failures, "integration_boundaries.auto_send_allowed", "must remain false at intake")
    return make_check("integration_boundaries", failures)


def check_gray_rollback(payload: dict[str, Any]) -> dict[str, Any]:
    return make_check(
        "gray_rollback",
        require_fields(
            payload,
            [
                "gray_rollback.gray_strategy",
                "gray_rollback.gray_owner",
                "gray_rollback.rollback_strategy",
                "gray_rollback.rollback_owner",
                "gray_rollback.stop_conditions",
            ],
        ),
    )


def check_risk_acceptance(payload: dict[str, Any]) -> dict[str, Any]:
    failures = require_fields(
        payload,
        [
            "risk_acceptance.business_owner",
            "risk_acceptance.risk_acceptance_policy",
            "risk_acceptance.authorization_level",
            "risk_acceptance.not_allowed_actions",
        ],
    )
    if dotted_get(payload, "risk_acceptance.authorization_level") != "DISCOVERY_ONLY":
        add_failure(failures, "risk_acceptance.authorization_level", "must be DISCOVERY_ONLY at intake")
    forbidden = set(dotted_get(payload, "risk_acceptance.not_allowed_actions") or [])
    for action in ["真实提交", "真实上线", "自动外发"]:
        if action not in forbidden:
            add_failure(failures, "risk_acceptance.not_allowed_actions", f"must include {action}")
    return make_check("risk_acceptance", failures)


def check_stage2_non_goals(payload: dict[str, Any]) -> dict[str, Any]:
    failures = require_fields(payload, ["stage2_non_goals"])
    non_goals = dotted_get(payload, "stage2_non_goals") or []
    required_terms = ["Stage 1", "standard-chain", "语言选型", "风险"]
    joined = "\n".join(str(item) for item in non_goals)
    for term in required_terms:
        if term not in joined:
            add_failure(failures, "stage2_non_goals", f"must mention {term}")
    return make_check("stage2_non_goals", failures)


def intake_kind(path: Path) -> str:
    if path.name == EXAMPLE_FILENAME:
        return "example"
    if path.name == TEMPLATE_FILENAME:
        return "template"
    return "real_intake_candidate"


def readiness_for(kind: str, failed_checks: list[str]) -> tuple[str, bool]:
    if failed_checks:
        return "blocked", False
    if kind == "example":
        return "materials_verified_not_authorization", False
    if kind == "template":
        return "blocked", False
    return "intake_complete_for_discovery", True


def route_for(kind: str, failed_checks: list[str]) -> dict[str, Any]:
    blocked_actions = [
        "language_selection",
        "architecture_finalization",
        "code_changes",
        "commit",
        "deploy",
        "auto_send",
        "business_risk_acceptance",
    ]
    if failed_checks:
        return {
            "next_standard_chain_role": None,
            "required_owner_action": "fix_stage2_intake_facts",
            "allowed_actions": ["fix_intake_facts"],
            "blocked_actions": blocked_actions,
            "handoff_input": None,
        }
    if kind == "real_intake_candidate":
        return {
            "next_standard_chain_role": "product-director",
            "required_owner_action": "start_product_director_confirmed_brief",
            "allowed_actions": [
                "real_qft_pai_discovery",
                "confirmed_brief_drafting",
                "phase1_boundary_freeze",
            ],
            "blocked_actions": blocked_actions,
            "handoff_input": "stage-2-intake-facts",
        }
    return {
        "next_standard_chain_role": None,
        "required_owner_action": "fill_real_stage2_intake_facts",
        "allowed_actions": ["fill_real_stage2_intake_facts"],
        "blocked_actions": blocked_actions,
        "handoff_input": None,
    }


def validate(payload: dict[str, Any], kind: str) -> dict[str, Any]:
    checks = [
        make_check("envelope", require_fields(payload, ["artifact_type", "stage", "intake_owner"])),
        check_intake_provenance(payload, kind),
        check_business_sample(payload),
        check_acceptance_owner(payload),
        check_success_metrics(payload),
        check_execution_environment(payload),
        check_qft_pai_scope(payload),
        check_integration_boundaries(payload),
        check_gray_rollback(payload),
        check_risk_acceptance(payload),
        check_stage2_non_goals(payload),
    ]
    failed_checks = [
        failure
        for check in checks
        for failure in check["failures"]
    ]
    readiness, discovery_allowed = readiness_for(kind, failed_checks)
    return {
        "status": "fail" if failed_checks else "pass",
        "intake_kind": kind,
        "stage2_readiness": readiness,
        "stage2_discovery_entry_allowed": discovery_allowed,
        "stage2_route": route_for(kind, failed_checks),
        "failed_checks": failed_checks,
        "checks": checks,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=ROOT, help="Repository root.")
    parser.add_argument("--intake", type=Path, default=None, help="Stage 2 intake facts JSON.")
    args = parser.parse_args()

    intake = args.intake or args.repo_root.resolve() / DEFAULT_INTAKE.relative_to(ROOT)
    payload = validate(load_json(intake), intake_kind(intake))
    print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if payload["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
