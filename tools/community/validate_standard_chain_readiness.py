#!/usr/bin/env python3
"""Validate canonical-only readiness and cutover rollback contracts."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from manage_artifact_registry import assert_append_only, load_json as load_registry_json
from normalize_canonical_artifact import ROOT, load_json
from validate_standard_chain_phase import PIPELINE, assert_canonical_only_layout, assert_catalog_contract
from validate_product_closure import validate_product_artifact
from delivery_owner_optional_artifacts import (
    assert_optional_fix_result_freshness,
    collect_optional_validation_artifact_paths,
)
from delivery_owner_freshness import assert_signoff_evidence_freshness
from readiness_closure_checks import (
    assert_delivery_state_closeout,
    assert_target_change_signoff_freshness,
)
from standard_chain_readiness_rollback import assert_fixture_rollback_contract
from validate_consistency_audit_runtime_chain import assert_runtime_chain_closed
from validate_readiness_contract import (
    assert_active_registry_matches_artifacts,
    assert_authority_proof,
    assert_code_review_pass,
    assert_signoff_closure,
    assert_signoff_runtime_evidence_matrix,
    assert_task_runtime_identity,
)

REQUIRED_PHASE_FILES = [
    "phase-prd.json",
    "artifact-registry.json",
    "code-review-result.json",
    "consistency-audit-result.json",
    "delivery-state.json",
    "design.json",
    "plan.json",
    "tasks.json",
    "qa-result.json",
    "signoff-package.json",
    "user-decision.json",
    "views/phase-operational.html",
    "views/phase-operational.projection-manifest.json",
    "replay/phase-operational.replay-oracle.json",
]
REQUIRED_FEATURE_FILES = ["brief.json"]
REQUIRED_PHASE_GLOBS = {
    "unit-definition": "units/UNIT-*.json",
    "test-cases": "unit-*/test-cases.json",
}
REQUIRED_TASK_RUNTIME_FILES = {
    "developer-report": "unit-*/tasks/{task_id}/developer-report.json",
    "verify-result": "unit-*/tasks/{task_id}/verify-result.json",
}
NON_ARTIFACT_PHASE_FILES = {"replay/phase-operational.replay-oracle.json"}
BROWSER_TOOL_ALLOW_RE = re.compile(
    r"playwright|browser|chrom(?:e|ium)|firefox|webkit|safari|puppeteer|cypress|selenium|webapp-testing|devtools", re.IGNORECASE
)
BROWSER_TOOL_BLOCK_RE = re.compile(
    r"(^|[^a-z0-9])(curl|wget|httpie|grpcurl|postman|axios|requests?|api|fetch)($|[^a-z0-9])", re.IGNORECASE
)
BROWSER_EVIDENCE_ALLOW_RE = re.compile(
    r"playwright|browser|screenshot|screen recording|video|trace|dom|locator|click|page|navigation|console|network|webapp-testing", re.IGNORECASE
)
BROWSER_EVIDENCE_BLOCK_RE = re.compile(r"curl|wget|httpie|grpcurl|postman|api response|axios|requests|fetch\(", re.IGNORECASE)
FAIL_TRIAGE_REQUIRED_FIELDS = {
    "severity",
    "priority",
    "impact_scope",
    "user_impact",
    "environment_or_build",
    "regression_flag",
    "temporary_workaround",
    "owner_hint",
    "expected_behavior",
    "actual_behavior",
    "reproduction",
}
REQUIRED_QA_STAGES = {"QA_A", "QA_B", "QA_C", "QA_D"}
QA_RELEASE_PAIR = ("PASS", "ALLOW")
CONFIRMED_STATUSES = {"CONFIRMED", "APPROVED"}
BLOCK_CONTRACT_KEYS = {
    "status",
    "owner",
    "reason",
    "recovery_condition",
    "signoff_allowed",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-dir", type=Path)
    parser.add_argument("--fixture", type=Path)
    parser.add_argument(
        "--catalog",
        type=Path,
        default=ROOT / "shared/runtime/standard-chain-catalog.json",
    )
    parser.add_argument(
        "--profiles",
        type=Path,
        default=ROOT / "shared/runtime/replay-profiles.json",
    )
    parser.add_argument("--expect-freeze-quarantine", action="store_true")
    return parser.parse_args()


def assert_required_phase_files(phase_dir: Path) -> None:
    for relative_path in REQUIRED_PHASE_FILES:
        candidate = phase_dir / relative_path
        if not candidate.is_file():
            raise FileNotFoundError(candidate)


def assert_required_feature_files(feature_dir: Path) -> None:
    for relative_path in REQUIRED_FEATURE_FILES:
        candidate = feature_dir / relative_path
        if not candidate.is_file():
            raise FileNotFoundError(candidate)
        load_json(candidate)


def collect_required_glob_files(phase_dir: Path) -> list[Path]:
    matched_files: list[Path] = []
    for label, pattern in REQUIRED_PHASE_GLOBS.items():
        matches = sorted(phase_dir.glob(pattern))
        if not matches:
            raise FileNotFoundError(f"{phase_dir / pattern} ({label})")
        matched_files.extend(matches)
    return matched_files


def collect_required_task_runtime_files(phase_dir: Path) -> list[Path]:
    return [path for _artifact_type, _task_id, path in iter_required_task_runtime_files(phase_dir)]


def iter_required_task_runtime_files(phase_dir: Path) -> list[tuple[str, str, Path]]:
    tasks_registry = load_json(phase_dir / "tasks.json")
    tasks = tasks_registry.get("tasks")
    if not isinstance(tasks, list):
        raise ValueError("tasks.json missing tasks array")

    matched_files: list[tuple[str, str, Path]] = []
    for task in tasks:
        if not isinstance(task, dict):
            raise ValueError("tasks.json task entry must be an object")
        task_id = str(task.get("task_id", "")).strip()
        if not task_id:
            raise ValueError("tasks.json task entry missing task_id")
        for artifact_type, pattern in REQUIRED_TASK_RUNTIME_FILES.items():
            matches = sorted(phase_dir.glob(pattern.format(task_id=task_id)))
            if not matches:
                raise FileNotFoundError(
                    f"{phase_dir / pattern.format(task_id=task_id)} ({artifact_type}:{task_id})"
                )
            matched_files.extend((artifact_type, task_id, match) for match in matches)
    return matched_files


def collect_validation_artifact_paths(phase_dir: Path) -> list[Path]:
    feature_dir = phase_dir.parent
    artifact_paths = [feature_dir / "brief.json"]
    artifact_paths.extend(
        phase_dir / relative_path
        for relative_path in REQUIRED_PHASE_FILES
        if relative_path.endswith(".json") and relative_path not in NON_ARTIFACT_PHASE_FILES
    )
    artifact_paths.extend(collect_required_glob_files(phase_dir))
    artifact_paths.extend(collect_required_task_runtime_files(phase_dir))
    artifact_paths.extend(collect_optional_validation_artifact_paths(phase_dir))
    return artifact_paths


def phase_requires_browser_evidence(phase_dir: Path) -> bool:
    for test_cases_path in sorted(phase_dir.glob("unit-*/test-cases.json")):
        payload = load_json(test_cases_path)
        rows = payload.get("qa_handoff_contract")
        if not isinstance(rows, list):
            continue
        for row in rows:
            if not isinstance(row, dict):
                continue
            if str(row.get("qa_stage", "")).strip() == "QA_B" and str(row.get("execution_mode", "")).strip() == "browser_required":
                return True
    return False


def browser_tool_looks_browser_native(browser_tool: str) -> bool:
    browser_tool = browser_tool.strip()
    return bool(browser_tool) and not BROWSER_TOOL_BLOCK_RE.search(browser_tool) and bool(BROWSER_TOOL_ALLOW_RE.search(browser_tool))


def browser_evidence_looks_browser_native(browser_evidence: object) -> bool:
    if not isinstance(browser_evidence, list) or not browser_evidence:
        return False
    saw_positive = False
    for item in browser_evidence:
        if not isinstance(item, str):
            return False
        text = item.strip()
        if not text:
            return False
        if BROWSER_EVIDENCE_BLOCK_RE.search(text) and not BROWSER_EVIDENCE_ALLOW_RE.search(text):
            return False
        if BROWSER_EVIDENCE_ALLOW_RE.search(text):
            saw_positive = True
    return saw_positive


def assert_browser_required_evidence(phase_dir: Path) -> None:
    if not phase_requires_browser_evidence(phase_dir):
        return
    qa_result = load_json(phase_dir / "qa-result.json")
    browser_tool = str(qa_result.get("browser_tool", "")).strip()
    entry_url = str(qa_result.get("entry_url", "")).strip()
    browser_evidence = qa_result.get("browser_evidence")
    if not browser_tool_looks_browser_native(browser_tool):
        raise ValueError("browser_required QA obligations must use a browser-native browser_tool")
    if not re.match(r"^https?://\S+$", entry_url):
        raise ValueError("browser_required QA obligations must include an http(s) entry_url")
    if not browser_evidence_looks_browser_native(browser_evidence):
        raise ValueError("browser_required QA obligations must include browser-native browser_evidence")


def assert_plan_tasks_alignment(phase_dir: Path) -> None:
    plan = load_json(phase_dir / "plan.json")
    tasks_registry = load_json(phase_dir / "tasks.json")
    delivery_state = load_json(phase_dir / "delivery-state.json")
    if plan.get("plan_version") != tasks_registry.get("plan_version"):
        raise ValueError(
            "plan/tasks version mismatch: plan.plan_version must match tasks.plan_version"
        )
    active_tasks_ref = delivery_state.get("active_tasks_version_ref")
    if plan.get("baseline_tasks_version_ref") != active_tasks_ref:
        raise ValueError(
            "plan baseline_tasks_version_ref must match delivery-state active_tasks_version_ref"
        )
    for label, payload in (("plan", plan), ("tasks", tasks_registry)):
        confirmation = payload.get("user_confirmation")
        if not isinstance(confirmation, dict):
            raise ValueError(f"{label}.user_confirmation is required before readiness")
        if confirmation.get("status") not in CONFIRMED_STATUSES:
            raise ValueError(
                f"{label}.user_confirmation.status must be CONFIRMED or APPROVED before readiness"
            )


def assert_task_acceptance_refs(phase_dir: Path) -> None:
    tasks_registry = load_json(phase_dir / "tasks.json")
    tasks = tasks_registry.get("tasks")
    if not isinstance(tasks, list) or not tasks:
        raise ValueError("tasks.json tasks must be a non-empty array")
    task_scope_refs: set[str] = set()
    for index, task in enumerate(tasks, start=1):
        if not isinstance(task, dict):
            raise ValueError(f"tasks.json tasks[{index}] must be an object")
        task_id = str(task.get("task_id", "")).strip() or f"#{index}"
        for field in ("scope_item_refs", "test_refs", "acceptance_targets"):
            value = task.get(field)
            if not isinstance(value, list) or not value:
                raise ValueError(
                    f"tasks.json task {task_id} must include non-empty {field} before readiness"
                )
        task_scope_refs.update(str(ref).strip() for ref in task.get("scope_item_refs", []))
    missing_brief_ac_refs = sorted(collect_brief_acceptance_refs(phase_dir) - task_scope_refs)
    if missing_brief_ac_refs:
        raise ValueError(
            "tasks scope_item_refs must cover brief acceptance_criteria: "
            + ", ".join(missing_brief_ac_refs)
        )


def collect_brief_acceptance_refs(phase_dir: Path) -> set[str]:
    brief_path = phase_dir.parent / "brief.json"
    if not brief_path.is_file():
        return set()
    brief = load_json(brief_path)
    criteria = brief.get("acceptance_criteria")
    if not isinstance(criteria, list) or not criteria:
        return set()
    artifact_id = str(brief.get("artifact_id", "")).strip()
    if not artifact_id:
        raise ValueError("brief artifact_id is required for acceptance criteria refs")
    return {
        f"artifact://brief/{artifact_id}@v1#ac-{index:03d}"
        for index, _item in enumerate(criteria, start=1)
    }


def unit_acceptance_ref(unit_file: Path, index: int) -> str:
    return f"{unit_file.name}#acceptance_criteria[{index}].ac_id"


def collect_unit_acceptance_source_map(phase_dir: Path) -> dict[str, set[str]]:
    source_to_unit_ac_ids: dict[str, set[str]] = {}
    for unit_path in sorted((phase_dir / "units").glob("*.json")):
        unit = load_json(unit_path)
        criteria = unit.get("acceptance_criteria")
        if not isinstance(criteria, list):
            raise ValueError(f"{unit_path.relative_to(phase_dir)} acceptance_criteria must be an array")
        for index, row in enumerate(criteria):
            if not isinstance(row, dict):
                raise ValueError(
                    f"{unit_path.relative_to(phase_dir)} acceptance_criteria[{index}] must be an object"
                )
            ac_id = str(row.get("ac_id", "")).strip()
            if not ac_id:
                raise ValueError(
                    f"{unit_path.relative_to(phase_dir)} acceptance_criteria[{index}] missing ac_id"
                )
            source_refs = row.get("source_refs")
            if not isinstance(source_refs, list) or not any(str(ref).strip() for ref in source_refs):
                raise ValueError(
                    f"{unit_path.relative_to(phase_dir)} acceptance_criteria[{index}] source_refs must be non-empty"
                )
            for source_ref in source_refs:
                ref = str(source_ref).strip()
                if ref:
                    source_to_unit_ac_ids.setdefault(ref, set()).add(ac_id)
    return source_to_unit_ac_ids


def resolve_traceability_unit_ac_id(phase_dir: Path, ac_ref: str) -> str:
    match = re.match(r"^([^/#]+\.json)#acceptance_criteria\[(\d+)\]\.ac_id$", ac_ref)
    if not match:
        return ac_ref
    unit_path = phase_dir / "units" / match.group(1)
    unit = load_json(unit_path)
    criteria = unit.get("acceptance_criteria")
    index = int(match.group(2))
    if not isinstance(criteria, list) or index >= len(criteria) or not isinstance(criteria[index], dict):
        raise ValueError(f"test-cases traceability_matrix ac_ref points at missing UNIT AC: {ac_ref}")
    return str(criteria[index].get("ac_id", "")).strip()


def collect_test_design_unit_ac_refs(phase_dir: Path) -> tuple[dict[str, set[str]], dict[str, set[str]]]:
    ac_coverage_refs: dict[str, set[str]] = {}
    traceability_refs: dict[str, set[str]] = {}
    for test_cases_path in sorted(phase_dir.glob("unit-*/test-cases.json")):
        payload = load_json(test_cases_path)
        for row in payload.get("ac_coverage_matrix", []):
            if not isinstance(row, dict):
                continue
            ac_id = str(row.get("ac_id", "")).strip()
            if ac_id:
                ac_coverage_refs.setdefault(ac_id, set()).add(test_cases_obligation_ref(payload, ac_id))
        for index, row in enumerate(payload.get("traceability_matrix", []), start=1):
            if not isinstance(row, dict):
                continue
            ac_ref = str(row.get("ac_ref", "")).strip()
            if not ac_ref:
                continue
            ac_id = resolve_traceability_unit_ac_id(phase_dir, ac_ref)
            if ac_id:
                traceability_refs.setdefault(ac_id, set()).add(
                    test_cases_obligation_ref(payload, f"traceability_matrix:{index}")
                )
    return ac_coverage_refs, traceability_refs


def assert_brief_acceptance_test_design_coverage(phase_dir: Path) -> None:
    brief_ac_refs = collect_brief_acceptance_refs(phase_dir)
    if not brief_ac_refs:
        return
    source_to_unit_ac_ids = collect_unit_acceptance_source_map(phase_dir)
    missing_unit_refs = sorted(brief_ac_refs - set(source_to_unit_ac_ids))
    if missing_unit_refs:
        raise ValueError(
            "brief acceptance_criteria must map through UNIT and test-design coverage: missing UNIT source_refs for "
            + ", ".join(missing_unit_refs)
        )
    required_unit_ac_ids = {
        ac_id
        for brief_ref in brief_ac_refs
        for ac_id in source_to_unit_ac_ids.get(brief_ref, set())
    }
    ac_coverage_refs, traceability_refs = collect_test_design_unit_ac_refs(phase_dir)
    task_refs = {
        str(ref).strip()
        for task in load_json(phase_dir / "tasks.json").get("tasks", [])
        if isinstance(task, dict)
        for ref in task.get("test_refs", [])
        if str(ref).strip()
    }
    missing_test_design: list[str] = []
    missing_task_refs: list[str] = []
    for ac_id in sorted(required_unit_ac_ids):
        expected_refs = set()
        expected_refs.update(ac_coverage_refs.get(ac_id, set()))
        expected_refs.update(traceability_refs.get(ac_id, set()))
        if not ac_coverage_refs.get(ac_id) or not traceability_refs.get(ac_id):
            missing_test_design.append(ac_id)
            continue
        absent = sorted(expected_refs - task_refs)
        if absent:
            missing_task_refs.extend(absent)
    if missing_test_design:
        raise ValueError(
            "brief acceptance_criteria must map through UNIT and test-design coverage: missing test-design coverage for "
            + ", ".join(missing_test_design)
        )
    if missing_task_refs:
        raise ValueError(
            "brief acceptance_criteria must map through UNIT and task test_refs: "
            + ", ".join(sorted(set(missing_task_refs)))
        )


def test_cases_obligation_ref(payload: dict, anchor: str) -> str:
    artifact_id = str(payload.get("artifact_id", "")).strip()
    if not artifact_id:
        raise ValueError("test-cases artifact_id is required for obligation refs")
    return f"artifact://test-cases/{artifact_id}@v1#{anchor}"


def collect_test_design_obligation_refs(phase_dir: Path) -> set[str]:
    refs: set[str] = set()
    for test_cases_path in sorted(phase_dir.glob("unit-*/test-cases.json")):
        payload = load_json(test_cases_path)
        ac_rows = payload.get("ac_coverage_matrix")
        if not isinstance(ac_rows, list):
            raise ValueError(f"{test_cases_path.relative_to(phase_dir)} ac_coverage_matrix must be an array")
        for index, row in enumerate(ac_rows, start=1):
            if not isinstance(row, dict):
                raise ValueError(
                    f"{test_cases_path.relative_to(phase_dir)} ac_coverage_matrix[{index}] must be an object"
                )
            ac_id = str(row.get("ac_id", "")).strip()
            if not ac_id:
                raise ValueError(
                    f"{test_cases_path.relative_to(phase_dir)} ac_coverage_matrix[{index}] missing ac_id"
                )
            refs.add(test_cases_obligation_ref(payload, ac_id))
        traceability_rows = payload.get("traceability_matrix")
        if not isinstance(traceability_rows, list):
            raise ValueError(f"{test_cases_path.relative_to(phase_dir)} traceability_matrix must be an array")
        for index, row in enumerate(traceability_rows, start=1):
            if not isinstance(row, dict):
                raise ValueError(
                    f"{test_cases_path.relative_to(phase_dir)} traceability_matrix[{index}] must be an object"
                )
            refs.add(test_cases_obligation_ref(payload, f"traceability_matrix:{index}"))
        handoff_rows = payload.get("qa_handoff_contract")
        if not isinstance(handoff_rows, list):
            raise ValueError(f"{test_cases_path.relative_to(phase_dir)} qa_handoff_contract must be an array")
        for index, row in enumerate(handoff_rows, start=1):
            if not isinstance(row, dict):
                raise ValueError(
                    f"{test_cases_path.relative_to(phase_dir)} qa_handoff_contract[{index}] must be an object"
                )
            if row.get("requiredness") != "REQUIRED":
                continue
            obligation_id = str(row.get("obligation_id", "")).strip()
            if not obligation_id:
                raise ValueError(
                    f"{test_cases_path.relative_to(phase_dir)} qa_handoff_contract[{index}] missing obligation_id"
                )
            refs.add(test_cases_obligation_ref(payload, f"qa_handoff_contract:{obligation_id}"))
        cross_unit_rows = payload.get("cross_unit_obligations")
        if not isinstance(cross_unit_rows, list):
            raise ValueError(f"{test_cases_path.relative_to(phase_dir)} cross_unit_obligations must be an array")
        for index, row in enumerate(cross_unit_rows, start=1):
            if not isinstance(row, dict):
                raise ValueError(
                    f"{test_cases_path.relative_to(phase_dir)} cross_unit_obligations[{index}] must be an object"
                )
            journey_id = str(row.get("journey_id", "")).strip()
            if not journey_id:
                raise ValueError(
                    f"{test_cases_path.relative_to(phase_dir)} cross_unit_obligations[{index}] missing journey_id"
                )
            refs.add(test_cases_obligation_ref(payload, f"cross_unit_obligations:{journey_id}"))
    if not refs:
        raise ValueError("test-design obligations must produce consumable refs")
    return refs


def assert_tech_lead_consumes_test_design_obligations(phase_dir: Path) -> None:
    expected_refs = collect_test_design_obligation_refs(phase_dir)
    plan = load_json(phase_dir / "plan.json")
    plan_refs = {
        str(ref).strip()
        for ref in plan.get("obligation_source_refs", [])
        if str(ref).strip()
    }
    missing_plan_refs = sorted(expected_refs - plan_refs)
    if missing_plan_refs:
        raise ValueError(
            "plan obligation_source_refs must consume required test-design obligations: "
            + ", ".join(missing_plan_refs)
        )

    tasks_registry = load_json(phase_dir / "tasks.json")
    task_refs = {
        str(ref).strip()
        for task in tasks_registry.get("tasks", [])
        if isinstance(task, dict)
        for ref in task.get("test_refs", [])
        if str(ref).strip()
    }
    missing_task_refs = sorted(expected_refs - task_refs)
    if missing_task_refs:
        raise ValueError(
            "tasks test_refs must consume required test-design obligations: "
            + ", ".join(missing_task_refs)
        )


def collect_required_qa_obligations(phase_dir: Path) -> set[str]:
    required: set[str] = set()
    for test_cases_path in sorted(phase_dir.glob("unit-*/test-cases.json")):
        payload = load_json(test_cases_path)
        rows = payload.get("qa_handoff_contract")
        if not isinstance(rows, list):
            raise ValueError(f"{test_cases_path.relative_to(phase_dir)} qa_handoff_contract must be an array")
        for index, row in enumerate(rows, start=1):
            if not isinstance(row, dict):
                raise ValueError(
                    f"{test_cases_path.relative_to(phase_dir)} qa_handoff_contract[{index}] must be an object"
                )
            if row.get("requiredness") != "REQUIRED":
                continue
            obligation_id = str(row.get("obligation_id", "")).strip()
            if not obligation_id:
                raise ValueError(
                    f"{test_cases_path.relative_to(phase_dir)} qa_handoff_contract[{index}] missing obligation_id"
                )
            required.add(obligation_id)
    if not required:
        raise ValueError("qa_handoff_contract must declare at least one REQUIRED obligation")
    return required


def assert_qa_obligation_coverage(phase_dir: Path) -> None:
    required = collect_required_qa_obligations(phase_dir)
    qa_result = load_json(phase_dir / "qa-result.json")
    results = qa_result.get("obligation_results")
    if not isinstance(results, list) or not results:
        raise ValueError("qa-result obligation_results must cover REQUIRED qa_handoff_contract obligations")
    covered: set[str] = set()
    for index, row in enumerate(results, start=1):
        if not isinstance(row, dict):
            raise ValueError(f"qa-result obligation_results[{index}] must be an object")
        obligation_id = str(row.get("obligation_id", "")).strip()
        if obligation_id not in required:
            continue
        evidence_refs = row.get("evidence_refs")
        if row.get("gate_result") != "PASS":
            raise ValueError(
                f"qa-result obligation_results[{index}] must PASS for required obligation {obligation_id}"
            )
        if not isinstance(evidence_refs, list) or not evidence_refs:
            raise ValueError(
                f"qa-result obligation_results[{index}] must include evidence_refs for {obligation_id}"
            )
        covered.add(obligation_id)
    missing = sorted(required - covered)
    if missing:
        raise ValueError(
            "qa-result obligation_results missing required QA obligations: "
            + ", ".join(missing)
        )


def assert_fail_triage_completeness(phase_dir: Path) -> None:
    qa_result = load_json(phase_dir / "qa-result.json")
    if str(qa_result.get("gate_result", "")).strip() != "FAIL":
        return
    issue_ledger = qa_result.get("issue_ledger")
    if not isinstance(issue_ledger, list) or not issue_ledger:
        raise ValueError("FAIL qa-result must include a non-empty issue_ledger")
    for index, item in enumerate(issue_ledger, start=1):
        if not isinstance(item, dict):
            raise ValueError(f"FAIL qa-result issue_ledger[{index}] must be an object")
        missing = [
            field
            for field in sorted(FAIL_TRIAGE_REQUIRED_FIELDS)
            if not isinstance(item.get(field), str) or not item.get(field, "").strip()
        ]
        if missing:
            raise ValueError(
                f"FAIL qa-result issue_ledger[{index}] missing triage fields: {', '.join(missing)}"
            )


def assert_qa_release_route_allows_readiness(phase_dir: Path) -> None:
    qa_result = load_json(phase_dir / "qa-result.json")
    route_pair = (
        str(qa_result.get("gate_result", "")).strip(),
        str(qa_result.get("release_recommendation", "")).strip(),
    )
    if route_pair != QA_RELEASE_PAIR:
        raise ValueError(
            "QA route matrix blocks readiness: "
            f"qa-result gate_result={route_pair[0]} release_recommendation={route_pair[1]}; "
            "only PASS + ALLOW may enter closeout"
        )


def assert_qa_stage_results(phase_dir: Path) -> None:
    qa_result = load_json(phase_dir / "qa-result.json")
    stage_results = qa_result.get("stage_results")
    if not isinstance(stage_results, list):
        raise ValueError("qa-result stage_results must be an array")
    seen = set()
    for index, item in enumerate(stage_results, start=1):
        if not isinstance(item, dict):
            raise ValueError(f"qa-result stage_results[{index}] must be an object")
        qa_stage = str(item.get("qa_stage", "")).strip()
        seen.add(qa_stage)
        if str(item.get("gate_result", "")).strip() != "PASS":
            raise ValueError(f"qa-result stage_results[{index}] must PASS at readiness")
        evidence_refs = item.get("evidence_refs")
        if not isinstance(evidence_refs, list) or not evidence_refs:
            raise ValueError(f"qa-result stage_results[{index}] must include evidence_refs")
    missing = sorted(REQUIRED_QA_STAGES - seen)
    if missing:
        raise ValueError(f"qa-result stage_results missing required QA stages: {', '.join(missing)}")


def assert_consistency_audit_allows_signoff(phase_dir: Path) -> None:
    audit = load_json(phase_dir / "consistency-audit-result.json")
    delivery_state = load_json(phase_dir / "delivery-state.json")
    if audit.get("decision_authority") != "advisory_only":
        raise ValueError("consistency-audit-result decision_authority must be advisory_only")
    if audit.get("consumer") != "delivery-owner":
        raise ValueError("consistency-audit-result consumer must be delivery-owner at readiness")
    if audit.get("audit_scope") != "full":
        raise ValueError("consistency-audit-result audit_scope must be full at readiness")
    if audit.get("mode") != "full":
        raise ValueError("consistency-audit-result mode must be full at readiness")
    if audit.get("blocked_layers"):
        raise ValueError("consistency-audit-result blocked_layers must be empty at readiness")
    runtime_chain = audit.get("runtime_chain")
    if not isinstance(runtime_chain, dict) or runtime_chain.get("status") != "CLOSED":
        raise ValueError("consistency-audit-result runtime_chain.status must be CLOSED at readiness")
    if runtime_chain.get("uncovered_obligation_ids"):
        raise ValueError("consistency-audit-result runtime_chain must not leave uncovered obligations at readiness")
    required_owner_actions = [
        str(action).strip()
        for action in audit.get("required_owner_action", [])
        if str(action).strip()
    ]
    consumed_actions = {
        str(action.get("action_id", "")).strip()
        for action in delivery_state.get("owner_action_consumption", [])
        if isinstance(action, dict)
    }
    missing_actions = sorted(set(required_owner_actions) - consumed_actions)
    if missing_actions:
        raise ValueError(
            "consistency-audit-result required_owner_action must be consumed by delivery-state: "
            + ", ".join(missing_actions)
        )
    for index, finding in enumerate(audit.get("findings", []), start=1):
        if isinstance(finding, dict) and finding.get("severity") == "CRITICAL":
            raise ValueError(f"consistency-audit-result finding[{index}] blocks readiness")


def assert_product_closure(feature_dir: Path, phase_dir: Path) -> None:
    validate_product_artifact(feature_dir / "brief.json", require_delivery=True, require_review=True)
    validate_product_artifact(phase_dir / "phase-prd.json", require_delivery=False, require_review=True)


def build_phase_scenario(phase_dir: Path) -> dict:
    manifest = load_json(phase_dir / "views/phase-operational.projection-manifest.json")
    artifact_paths = collect_validation_artifact_paths(phase_dir)
    return {
        "artifacts": [load_json(path) for path in artifact_paths],
        "tasks_registry": load_json(phase_dir / "tasks.json"),
        "projection": {
            "manifest_artifact_id": manifest["artifact_id"],
            "rendered_artifact_path": "views/phase-operational.html",
            "available_source_refs": manifest["source_artifact_refs"],
        },
    }


def extract_subprocess_failure_reason(
    completed: subprocess.CompletedProcess[str], label: str
) -> str:
    output = "\n".join(
        part for part in (completed.stdout, completed.stderr) if part
    ).strip()
    decoder = json.JSONDecoder()
    for index, char in enumerate(output):
        if char != "{":
            continue
        try:
            payload, _end = decoder.raw_decode(output[index:])
        except json.JSONDecodeError:
            continue
        if (
            isinstance(payload, dict)
            and BLOCK_CONTRACT_KEYS.issubset(payload)
            and str(payload.get("reason", "")).strip()
        ):
            return str(payload["reason"])
    for line in reversed(output.splitlines()):
        stripped = line.strip()
        if stripped and not stripped.startswith("Traceback"):
            return stripped
    return f"{label} failed with exit code {completed.returncode}"


def run_validator_command(command: list[str], label: str) -> None:
    completed = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        reason = extract_subprocess_failure_reason(completed, label)
        raise ValueError(f"{label}: {reason}")


def run_phase_validator(phase_dir: Path, catalog: Path) -> None:
    tools_dir = Path(__file__).resolve().parent
    scenario = build_phase_scenario(phase_dir)
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_root = Path(tmp_dir)
        fixture = tmp_root / "scenario.json"
        rendered_dir = tmp_root / "views"
        rendered_dir.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(
            phase_dir / "views/phase-operational.html",
            rendered_dir / "phase-operational.html",
        )
        fixture.write_text(json.dumps(scenario, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        for script_name in PIPELINE:
            script = tools_dir / script_name
            if script_name == "validate_projection_manifest.py":
                run_validator_command(
                    [sys.executable, str(script), "--phase-dir", str(phase_dir)],
                    script_name,
                )
                continue
            run_validator_command(
                [sys.executable, str(script), "--fixture", str(fixture)],
                script_name,
            )


def run_replay_validator(phase_dir: Path, profiles: Path) -> None:
    script = Path(__file__).resolve().parent / "replay_canonical_phase.py"
    oracle = phase_dir / "replay/phase-operational.replay-oracle.json"
    run_validator_command(
        [
            sys.executable,
            str(script),
            "--phase-dir",
            str(phase_dir),
            "--profiles",
            str(profiles.resolve()),
            "--oracle",
            str(oracle),
        ],
        "replay_canonical_phase.py",
    )


def validate_phase_dir(phase_dir: Path, catalog: Path, profiles: Path) -> None:
    phase_dir = phase_dir.resolve()
    feature_dir = phase_dir.parent
    assert_catalog_contract(catalog.resolve())
    assert_canonical_only_layout(phase_dir)
    assert_required_feature_files(feature_dir)
    assert_required_phase_files(phase_dir)
    assert_product_closure(feature_dir, phase_dir)
    collect_required_glob_files(phase_dir)
    assert_plan_tasks_alignment(phase_dir)
    assert_task_acceptance_refs(phase_dir)
    assert_brief_acceptance_test_design_coverage(phase_dir)
    assert_tech_lead_consumes_test_design_obligations(phase_dir)
    assert_task_runtime_identity(iter_required_task_runtime_files(phase_dir), phase_dir)
    assert_code_review_pass(phase_dir)
    assert_browser_required_evidence(phase_dir)
    assert_fail_triage_completeness(phase_dir)
    assert_qa_release_route_allows_readiness(phase_dir)
    assert_qa_obligation_coverage(phase_dir)
    assert_qa_stage_results(phase_dir)
    assert_runtime_chain_closed(phase_dir)
    assert_consistency_audit_allows_signoff(phase_dir)
    assert_optional_fix_result_freshness(phase_dir)
    assert_signoff_evidence_freshness(phase_dir)
    assert_delivery_state_closeout(phase_dir, load_json)
    assert_target_change_signoff_freshness(phase_dir, load_json)
    registry = load_registry_json(phase_dir / "artifact-registry.json")
    assert_append_only(registry)
    assert_active_registry_matches_artifacts(phase_dir, collect_validation_artifact_paths(phase_dir), registry)
    assert_signoff_runtime_evidence_matrix(phase_dir, registry)
    assert_authority_proof(phase_dir)
    assert_signoff_closure(feature_dir, phase_dir)
    run_phase_validator(phase_dir, catalog)
    run_replay_validator(phase_dir, profiles)


def validate_fixture(fixture: Path, expect_freeze_quarantine: bool) -> None:
    payload = load_json(fixture.resolve())
    if not isinstance(payload.get("artifact_registry"), dict):
        raise ValueError("fixture missing artifact_registry")
    if not isinstance(payload.get("delivery_state"), dict):
        raise ValueError("fixture missing delivery_state")
    assert_fixture_rollback_contract(payload, expect_freeze_quarantine)


def main() -> None:
    args = parse_args()
    if bool(args.phase_dir) == bool(args.fixture):
        raise SystemExit("必须且只能选择 --phase-dir 或 --fixture")
    if args.phase_dir is not None:
        validate_phase_dir(args.phase_dir, args.catalog, args.profiles)
        return
    validate_fixture(args.fixture, args.expect_freeze_quarantine)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(
            json.dumps(
                {
                    "status": "BLOCKED",
                    "owner": "delivery-owner",
                    "reason": str(exc),
                    "recovery_condition": "resolve the reported readiness contract violation and rerun validate_standard_chain_readiness.py",
                    "signoff_allowed": False,
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        raise SystemExit(1) from None
