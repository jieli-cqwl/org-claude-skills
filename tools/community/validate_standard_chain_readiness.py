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

from manage_artifact_registry import load_json as load_registry_json
from normalize_canonical_artifact import ROOT, load_json
from validate_standard_chain_phase import PIPELINE, assert_canonical_only_layout, assert_catalog_contract
from validate_product_closure import validate_product_artifact
from delivery_owner_optional_artifacts import (
    assert_optional_fix_result_freshness,
    collect_optional_validation_artifact_paths,
)
from delivery_owner_freshness import assert_signoff_evidence_freshness
from standard_chain_readiness_rollback import assert_fixture_rollback_contract
from validate_readiness_contract import (
    assert_active_registry_matches_artifacts,
    assert_authority_proof,
    assert_code_review_pass,
    assert_signoff_closure,
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
    if audit.get("decision_authority") != "advisory_only":
        raise ValueError("consistency-audit-result decision_authority must be advisory_only")
    if audit.get("consumer") != "delivery-owner":
        raise ValueError("consistency-audit-result consumer must be delivery-owner at readiness")
    if audit.get("mode") != "full":
        raise ValueError("consistency-audit-result mode must be full at readiness")
    if audit.get("blocked_layers"):
        raise ValueError("consistency-audit-result blocked_layers must be empty at readiness")
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
                subprocess.run(
                    [sys.executable, str(script), "--phase-dir", str(phase_dir)],
                    check=True,
                )
                continue
            subprocess.run(
                [sys.executable, str(script), "--fixture", str(fixture)],
                check=True,
            )


def run_replay_validator(phase_dir: Path, profiles: Path) -> None:
    script = Path(__file__).resolve().parent / "replay_canonical_phase.py"
    oracle = phase_dir / "replay/phase-operational.replay-oracle.json"
    subprocess.run(
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
        check=True,
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
    assert_task_runtime_identity(iter_required_task_runtime_files(phase_dir), phase_dir)
    assert_code_review_pass(phase_dir)
    assert_browser_required_evidence(phase_dir)
    assert_fail_triage_completeness(phase_dir)
    assert_qa_stage_results(phase_dir)
    assert_consistency_audit_allows_signoff(phase_dir)
    assert_optional_fix_result_freshness(phase_dir)
    assert_signoff_evidence_freshness(phase_dir)
    registry = load_registry_json(phase_dir / "artifact-registry.json")
    assert_active_registry_matches_artifacts(phase_dir, collect_validation_artifact_paths(phase_dir), registry)
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
    main()
