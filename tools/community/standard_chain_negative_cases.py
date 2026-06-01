#!/usr/bin/env python3
"""Run production-readiness negative cases against a canonical pilot."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Callable
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
READINESS_SCRIPT = ROOT / "tools/community/validate_standard_chain_readiness.py"
REQUIRED_BLOCK_KEYS = {
    "status",
    "owner",
    "reason",
    "recovery_condition",
    "signoff_allowed",
}

Mutator = Callable[[Path, Path], None]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pilot", type=Path, required=True)
    parser.add_argument("--catalog", type=Path, required=True)
    return parser.parse_args()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def task_runtime_path(phase_dir: Path, task_id: str, name: str) -> Path:
    return phase_dir / "unit-1" / "tasks" / task_id / name


def latest_registry_entries(phase_dir: Path) -> list[dict]:
    registry = load_json(phase_dir / "artifact-registry.json")
    return registry["revisions"][-1]["entries"]


def update_registry(phase_dir: Path, update: Callable[[list[dict]], None]) -> None:
    registry_path = phase_dir / "artifact-registry.json"
    registry = load_json(registry_path)
    update(registry["revisions"][-1]["entries"])
    write_json(registry_path, registry)


def mutate_remove_baseline_input(feature_dir: Path, _phase_dir: Path) -> None:
    (feature_dir / "brief.json").unlink()


def mutate_director_confirmation_failed(feature_dir: Path, _phase_dir: Path) -> None:
    brief_path = feature_dir / "brief.json"
    brief = load_json(brief_path)
    brief["director_confirmation"]["status"] = "failed"
    write_json(brief_path, brief)


def mutate_director_digest_drift(feature_dir: Path, _phase_dir: Path) -> None:
    brief_path = feature_dir / "brief.json"
    brief = load_json(brief_path)
    brief["root_problem"] = "mutated after Director confirmation"
    write_json(brief_path, brief)


def mutate_mixed_versions(_feature_dir: Path, phase_dir: Path) -> None:
    report_path = task_runtime_path(phase_dir, "T1", "developer-report.json")
    report = load_json(report_path)
    report["active_tasks_version_ref"] = report["active_tasks_version_ref"].replace("tasks-v2", "tasks-v1")
    write_json(report_path, report)


def mutate_plan_tasks_version_mismatch(_feature_dir: Path, phase_dir: Path) -> None:
    tasks_path = phase_dir / "tasks.json"
    tasks = load_json(tasks_path)
    tasks["plan_version"] = "plan-v1"
    write_json(tasks_path, tasks)


def mutate_tasks_unconfirmed(_feature_dir: Path, phase_dir: Path) -> None:
    tasks_path = phase_dir / "tasks.json"
    tasks = load_json(tasks_path)
    tasks["user_confirmation"]["status"] = "PENDING"
    write_json(tasks_path, tasks)


def mutate_task_acceptance_refs_missing(_feature_dir: Path, phase_dir: Path) -> None:
    tasks_path = phase_dir / "tasks.json"
    tasks = load_json(tasks_path)
    tasks["tasks"][0]["test_refs"] = []
    tasks["tasks"][0]["acceptance_targets"] = []
    write_json(tasks_path, tasks)


def mutate_qa_obligation_missing(_feature_dir: Path, phase_dir: Path) -> None:
    qa_path = phase_dir / "qa-result.json"
    qa = load_json(qa_path)
    qa["obligation_results"] = qa.get("obligation_results", [])[1:]
    write_json(qa_path, qa)


def mutate_runtime_evidence_missing(_feature_dir: Path, phase_dir: Path) -> None:
    task_runtime_path(phase_dir, "T1", "developer-report.json").unlink()


def mutate_code_review_blocking(_feature_dir: Path, phase_dir: Path) -> None:
    review_path = phase_dir / "code-review-result.json"
    review = load_json(review_path)
    review["gate_result"] = "FAIL"
    review["review_conclusion"] = "REQUEST_CHANGES"
    review["findings"] = [
        {
            "finding_id": "REV-FM10-001",
            "severity": "S1",
            "summary": "blocking review issue",
            "file_path": "tools/community/validate_standard_chain_readiness.py",
            "line_number": 1,
            "confidence": 95,
            "verification_status": "VERIFIED",
        }
    ]
    write_json(review_path, review)


def mutate_qa_not_pass(_feature_dir: Path, phase_dir: Path) -> None:
    qa_path = phase_dir / "qa-result.json"
    qa = load_json(qa_path)
    qa["gate_result"] = "FAIL"
    qa["release_recommendation"] = "BLOCK"
    write_json(qa_path, qa)


def mutate_consistency_action_unconsumed(_feature_dir: Path, phase_dir: Path) -> None:
    audit_path = phase_dir / "consistency-audit-result.json"
    state_path = phase_dir / "delivery-state.json"
    audit = load_json(audit_path)
    audit["required_owner_action"] = ["ACTION-REBASELINE-001"]
    write_json(audit_path, audit)
    state = load_json(state_path)
    state["owner_action_consumption"] = []
    write_json(state_path, state)


def mutate_registry_inactive_evidence(_feature_dir: Path, phase_dir: Path) -> None:
    def remove_t1_developer(entries: list[dict]) -> None:
        entries[:] = [
            entry
            for entry in entries
            if not (
                entry.get("artifact_type") == "developer-report"
                and entry.get("artifact_id", "").endswith("task-T1.developer-report")
            )
        ]

    update_registry(phase_dir, remove_t1_developer)


def mutate_registry_lifecycle_inactive(_feature_dir: Path, phase_dir: Path) -> None:
    def deactivate_review(entries: list[dict]) -> None:
        entry = next(item for item in entries if item.get("artifact_type") == "code-review-result")
        entry["lifecycle_state"] = "SUPERSEDED"
        entry["active_for_consumption"] = False

    update_registry(phase_dir, deactivate_review)


def mutate_signoff_matrix_missing_row(_feature_dir: Path, phase_dir: Path) -> None:
    signoff_path = phase_dir / "signoff-package.json"
    signoff = load_json(signoff_path)
    signoff["runtime_evidence_matrix"] = [
        row
        for row in signoff.get("runtime_evidence_matrix", [])
        if row.get("artifact_type") != "code-review-result"
    ]
    write_json(signoff_path, signoff)


def mutate_target_change_invalidates_evidence(_feature_dir: Path, phase_dir: Path) -> None:
    signoff = load_json(phase_dir / "signoff-package.json")
    evidence_ref = signoff["runtime_evidence_matrix"][0]["artifact_ref"]
    target = load_json(ROOT / "shared/skills/delivery-owner/templates/target-change.template.json")
    target["baseline_tasks_version_ref"] = signoff["baseline_tasks_version_ref"]
    target["active_tasks_version_ref"] = signoff["active_tasks_version_ref"]
    target["invalidates_refs"] = [evidence_ref]
    target["superseded_evidence_refs"] = [evidence_ref]
    write_json(phase_dir / "target-change.json", target)


def mutate_user_decision_absent(_feature_dir: Path, phase_dir: Path) -> None:
    (phase_dir / "user-decision.json").unlink()


def mutate_delivered_without_commit(_feature_dir: Path, phase_dir: Path) -> None:
    state_path = phase_dir / "delivery-state.json"
    state = load_json(state_path)
    state["status"] = "DELIVERED"
    state["commit_state"] = "NOT_READY"
    state.pop("commit_result_ref", None)
    state.pop("equivalent_delivery_result_ref", None)
    write_json(state_path, state)


CASES: list[tuple[str, str, Mutator]] = [
    ("FM-01", "missing required baseline input", mutate_remove_baseline_input),
    ("FM-02", "director confirmation missing or failed", mutate_director_confirmation_failed),
    ("FM-03", "director lock digest drift", mutate_director_digest_drift),
    ("FM-04", "mixed baseline or tasks version", mutate_mixed_versions),
    ("FM-05", "plan/tasks version mismatch", mutate_plan_tasks_version_mismatch),
    ("FM-06", "tasks not frozen or confirmed", mutate_tasks_unconfirmed),
    ("FM-07", "task acceptance refs missing", mutate_task_acceptance_refs_missing),
    ("FM-08", "qa handoff obligations missing", mutate_qa_obligation_missing),
    ("FM-09", "developer or verify evidence missing", mutate_runtime_evidence_missing),
    ("FM-10", "code review missing stale or blocking", mutate_code_review_blocking),
    ("FM-11", "qa result missing not pass or incomplete", mutate_qa_not_pass),
    ("FM-12", "consistency action not consumed", mutate_consistency_action_unconsumed),
    ("FM-13", "runtime evidence not active in registry", mutate_registry_inactive_evidence),
    ("FM-14", "registry lifecycle inactive", mutate_registry_lifecycle_inactive),
    ("FM-15", "signoff evidence matrix omits coverage", mutate_signoff_matrix_missing_row),
    ("FM-16", "target change invalidates evidence", mutate_target_change_invalidates_evidence),
    ("FM-17", "required user decision absent", mutate_user_decision_absent),
    ("FM-18", "ready for commit treated as delivered", mutate_delivered_without_commit),
]


def find_block_contract(text: str) -> dict | None:
    decoder = json.JSONDecoder()
    matches: list[dict] = []
    for index, char in enumerate(text):
        if char != "{":
            continue
        try:
            payload, _end = decoder.raw_decode(text[index:])
        except json.JSONDecodeError:
            continue
        if isinstance(payload, dict) and REQUIRED_BLOCK_KEYS <= set(payload):
            matches.append(payload)
    return matches[-1] if matches else None


def assert_block_contract(case_id: str, label: str, result: subprocess.CompletedProcess[str]) -> str:
    if result.returncode == 0:
        raise AssertionError(f"{case_id} {label}: readiness unexpectedly passed")
    output = (result.stdout or "") + "\n" + (result.stderr or "")
    payload = find_block_contract(output)
    if payload is None:
        raise AssertionError(
            f"{case_id} {label}: readiness did not expose a JSON block contract; output={output[:400]!r}"
        )
    if payload.get("status") != "BLOCKED":
        raise AssertionError(f"{case_id} {label}: status must be BLOCKED")
    if payload.get("signoff_allowed") is not False:
        raise AssertionError(f"{case_id} {label}: signoff_allowed must be false")
    for key in ("owner", "reason", "recovery_condition"):
        value = payload.get(key)
        if not isinstance(value, str) or not value.strip():
            raise AssertionError(f"{case_id} {label}: {key} must be a non-empty string")
    reason = payload["reason"].strip()
    if reason.startswith("Command '['"):
        raise AssertionError(
            f"{case_id} {label}: reason only proves subprocess failure, not the readiness violation"
        )
    return reason


def run_case(case_id: str, label: str, mutator: Mutator, pilot: Path, catalog: Path, tmp_root: Path) -> str:
    feature_dir = tmp_root / f"{case_id}--{label.replace(' ', '-')}"
    shutil.copytree(pilot, feature_dir)
    phase_dir = feature_dir / "phase-1"
    mutator(feature_dir, phase_dir)
    result = subprocess.run(
        [
            sys.executable,
            str(READINESS_SCRIPT),
            "--phase-dir",
            str(phase_dir),
            "--catalog",
            str(catalog),
        ],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    return assert_block_contract(case_id, label, result)


def main() -> None:
    args = parse_args()
    pilot = args.pilot.resolve()
    catalog = args.catalog.resolve()
    if not (pilot / "phase-1").is_dir():
        raise SystemExit(f"--pilot must point to a feature fixture with phase-1: {pilot}")
    with tempfile.TemporaryDirectory(prefix="standard-chain-negative-") as raw_tmp:
        tmp_root = Path(raw_tmp)
        for case_id, label, mutator in CASES:
            reason = run_case(case_id, label, mutator, pilot, catalog, tmp_root)
            print(f"[PASS] {case_id} {label}: {reason}")


if __name__ == "__main__":
    main()
