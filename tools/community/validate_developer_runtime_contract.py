#!/usr/bin/env python3
"""Validate developer-report runtime semantics that JSON Schema cannot prove."""

from __future__ import annotations

import argparse
import json
import sys
from json import JSONDecodeError
from pathlib import Path
from typing import Any

from canonical_ref_resolver import get_active_revision, split_artifact_ref


FAILURE_OWNER = {
    "MISSING_INPUT": "delivery-owner",
    "AMBIGUOUS_SCOPE": "delivery-owner",
    "UNRESOLVED_REF": "delivery-owner",
    "OWNER_MISMATCH": "delivery-owner",
    "SCHEMA_FAILURE": "developer",
    "GATE_FAILURE": "developer",
    "OUT_OF_SCOPE_CHANGE": "delivery-owner",
    "STALE_STATE_REPLAY": "standard-chain-runtime-owner",
    "FRESH_PROOF_GAP": "developer",
}

USER_MESSAGE = {
    "MISSING_INPUT": "缺少 developer 运行输入，已阻断真实代码修改。",
    "AMBIGUOUS_SCOPE": "developer 文件范围不明确，已阻断真实代码修改。",
    "UNRESOLVED_REF": "developer 报告引用了无法解析的 canonical ref。",
    "OWNER_MISMATCH": "阻断原因的 owner 与 failure_code 不匹配。",
    "SCHEMA_FAILURE": "developer-report.json 结构无效。",
    "GATE_FAILURE": "developer completion gate 未通过。",
    "OUT_OF_SCOPE_CHANGE": "developer 试图修改派发范围外文件。",
    "STALE_STATE_REPLAY": "developer 报告引用了过期状态。",
    "FRESH_PROOF_GAP": "developer 完成证据缺少当前执行输出。",
}


class DeveloperRuntimeFailure(Exception):
    def __init__(self, code: str, reason: str, evidence_refs: list[str] | None = None):
        super().__init__(reason)
        self.code = code
        self.reason = reason
        self.evidence_refs = evidence_refs or ["developer-runtime-validator"]


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-dir", type=Path, required=True)
    parser.add_argument("--task-id", required=True)
    parser.add_argument("--report", type=Path, required=True)
    return parser.parse_args(argv)


def load_json(path: Path, failure_code: str = "MISSING_INPUT") -> dict[str, Any]:
    if not path.is_file():
        raise DeveloperRuntimeFailure(
            failure_code, f"missing required file: {path}", [str(path)]
        )
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError as exc:
        raise DeveloperRuntimeFailure(
            "SCHEMA_FAILURE", f"malformed JSON: {path}: {exc}", [str(path)]
        ) from exc
    if not isinstance(data, dict):
        raise DeveloperRuntimeFailure(
            "SCHEMA_FAILURE", f"top-level JSON must be an object: {path}", [str(path)]
        )
    return data


def failure_payload(code: str, reason: str, evidence_refs: list[str]) -> dict[str, Any]:
    owner = FAILURE_OWNER[code]
    return {
        "runtime_status": "BLOCKED",
        "failure_contract": {
            "status": "BLOCKED",
            "failure_code": code,
            "reason": reason,
            "owner": owner,
            "safe_to_continue": False,
            "next_action": f"route to {owner} to repair {code.lower()}",
            "evidence_refs": evidence_refs,
            "user_message": USER_MESSAGE[code],
        },
    }


def find_task(tasks_artifact: dict[str, Any], task_id: str) -> dict[str, Any]:
    for task in tasks_artifact.get("tasks", []):
        if isinstance(task, dict) and task.get("task_id") == task_id:
            return task
    raise DeveloperRuntimeFailure(
        "MISSING_INPUT", f"task not found in tasks.json: {task_id}", ["tasks.json"]
    )


def string_set(value: Any) -> set[str]:
    if not isinstance(value, list):
        return set()
    return {item for item in value if isinstance(item, str) and item}


def validate_required_inputs(report: dict[str, Any], phase_dir: Path) -> None:
    missing: list[str] = []
    for filename in ("artifact-registry.json", "design.json", "tasks.json"):
        if not (phase_dir / filename).is_file():
            missing.append(filename)
    for field in (
        "active_plan_version_ref",
        "active_tasks_version_ref",
        "task_id",
        "evidence_refs",
    ):
        if not report.get(field):
            missing.append(field)
    if missing:
        raise DeveloperRuntimeFailure(
            "MISSING_INPUT",
            "missing developer runtime inputs: " + ", ".join(sorted(missing)),
        )


def active_registry_index(registry: dict[str, Any]) -> set[tuple[str, str, str]]:
    try:
        active_revision = get_active_revision(registry)
    except ValueError as exc:
        raise DeveloperRuntimeFailure(
            "UNRESOLVED_REF",
            f"artifact-registry active revision is not resolvable: {exc}",
            ["artifact-registry.json"],
        ) from exc
    entries = active_revision.get("entries")
    if not isinstance(entries, list) or not entries:
        raise DeveloperRuntimeFailure(
            "UNRESOLVED_REF",
            "artifact-registry active revision has no entries",
            ["artifact-registry.json"],
        )
    index: set[tuple[str, str, str]] = set()
    invalid: list[str] = []
    for entry in entries:
        if not isinstance(entry, dict):
            invalid.append("non-object entry")
            continue
        if not entry.get("active_for_consumption"):
            continue
        if entry.get("lifecycle_state") != "FINALIZED":
            invalid.append(str(entry.get("artifact_id") or "unknown"))
            continue
        artifact_type = entry.get("artifact_type")
        artifact_id = entry.get("artifact_id")
        version = entry.get("version")
        if not all(
            isinstance(item, str) and item
            for item in (artifact_type, artifact_id, version)
        ):
            invalid.append(str(entry.get("artifact_id") or "unknown"))
            continue
        index.add((artifact_type, artifact_id, version))
    if invalid:
        raise DeveloperRuntimeFailure(
            "UNRESOLVED_REF",
            "artifact-registry has invalid active entries: "
            + ", ".join(sorted(invalid)),
            ["artifact-registry.json"],
        )
    if not index:
        raise DeveloperRuntimeFailure(
            "UNRESOLVED_REF",
            "artifact-registry has no FINALIZED active entries",
            ["artifact-registry.json"],
        )
    return index


def collect_runtime_refs(report: dict[str, Any], task: dict[str, Any]) -> list[str]:
    refs: list[str] = []
    for field in ("active_plan_version_ref", "active_tasks_version_ref"):
        value = report.get(field)
        if isinstance(value, str) and value:
            refs.append(value)
    refs.extend(string_set(task.get("design_refs")))
    refs.extend(string_set(task.get("test_refs")))
    for row in report.get("tdd_evidence_index", []):
        if isinstance(row, dict):
            refs.extend(string_set(row.get("ac_refs")))
    return refs


def validate_registry_refs(registry: dict[str, Any], refs: list[str]) -> None:
    index = active_registry_index(registry)
    unresolved: list[str] = []
    for ref in sorted(set(refs)):
        try:
            artifact_type, artifact_id, version, _anchor = split_artifact_ref(ref)
        except ValueError:
            unresolved.append(ref)
            continue
        if (artifact_type, artifact_id, version) not in index:
            unresolved.append(ref)
    if unresolved:
        raise DeveloperRuntimeFailure(
            "UNRESOLVED_REF",
            "refs not found in active artifact-registry: " + ", ".join(unresolved),
            unresolved,
        )


def validate_owner_contract(report: dict[str, Any]) -> None:
    contract = report.get("failure_contract")
    if not isinstance(contract, dict):
        return
    code = contract.get("failure_code")
    expected_owner = FAILURE_OWNER.get(code)
    if expected_owner and contract.get("owner") != expected_owner:
        raise DeveloperRuntimeFailure(
            "OWNER_MISMATCH",
            f"failure_code {code} must route to {expected_owner}, got {contract.get('owner')}",
            list(string_set(contract.get("evidence_refs"))) or ["failure_contract"],
        )


def validate_blocked_report(report: dict[str, Any], task_id: str) -> bool:
    if report.get("runtime_status") != "BLOCKED":
        return False
    if report.get("task_id") != task_id:
        raise DeveloperRuntimeFailure(
            "MISSING_INPUT", f"blocked report task_id must match {task_id}", ["task_id"]
        )
    if not report.get("evidence_refs"):
        raise DeveloperRuntimeFailure(
            "MISSING_INPUT",
            "blocked report must include evidence_refs",
            ["evidence_refs"],
        )
    contract = report.get("failure_contract")
    if not isinstance(contract, dict):
        raise DeveloperRuntimeFailure(
            "SCHEMA_FAILURE",
            "blocked report must include failure_contract",
            ["failure_contract"],
        )
    required_fields = {
        "status",
        "failure_code",
        "reason",
        "owner",
        "safe_to_continue",
        "next_action",
        "evidence_refs",
        "user_message",
    }
    missing = sorted(field for field in required_fields if field not in contract)
    if missing:
        raise DeveloperRuntimeFailure(
            "SCHEMA_FAILURE",
            "failure_contract missing fields: " + ", ".join(missing),
            ["failure_contract"],
        )
    if contract.get("failure_code") not in FAILURE_OWNER:
        raise DeveloperRuntimeFailure(
            "SCHEMA_FAILURE",
            f"unknown failure_code: {contract.get('failure_code')}",
            ["failure_contract"],
        )
    if contract.get("safe_to_continue") is not False:
        raise DeveloperRuntimeFailure(
            "SCHEMA_FAILURE",
            "failure_contract.safe_to_continue must be false",
            ["failure_contract"],
        )
    validate_owner_contract(report)
    return True


def within_allowed_scope(path: str, allowed: set[str]) -> bool:
    return any(
        path == item or path.startswith(item.rstrip("/") + "/") for item in allowed
    )


def validate_scope(report: dict[str, Any]) -> None:
    scope = string_set(report.get("task_scope"))
    if not scope:
        raise DeveloperRuntimeFailure(
            "AMBIGUOUS_SCOPE", "developer task_scope is missing"
        )
    outside = sorted(
        path
        for path in string_set(report.get("file_changes"))
        if not within_allowed_scope(path, scope)
    )
    if outside:
        raise DeveloperRuntimeFailure(
            "OUT_OF_SCOPE_CHANGE",
            "file changes outside developer-reported task_scope: " + ", ".join(outside),
            outside,
        )


def collect_ac_ids(test_cases: dict[str, Any]) -> set[str]:
    ids: set[str] = set()
    for row in test_cases.get("ac_coverage_matrix", []):
        if isinstance(row, dict) and isinstance(row.get("ac_id"), str):
            ids.add(row["ac_id"])
    return ids


def ac_fragment(ref: str) -> str:
    return ref.rsplit("#", 1)[-1]


def validate_ac_refs(report: dict[str, Any], test_cases: dict[str, Any]) -> None:
    known = collect_ac_ids(test_cases)
    unknown: list[str] = []
    for row in report.get("tdd_evidence_index", []):
        if not isinstance(row, dict):
            continue
        for ref in row.get("ac_refs", []):
            if isinstance(ref, str) and ac_fragment(ref) not in known:
                unknown.append(ref)
    if unknown:
        raise DeveloperRuntimeFailure(
            "UNRESOLVED_REF", "unknown AC refs: " + ", ".join(sorted(unknown)), unknown
        )


def validate_stale_state(
    report: dict[str, Any], tasks_artifact: dict[str, Any]
) -> None:
    expected_plan = tasks_artifact.get("active_plan_version_ref") or tasks_artifact.get(
        "baseline_plan_version_ref"
    )
    expected_tasks = tasks_artifact.get("active_tasks_version_ref")
    if expected_plan and report.get("active_plan_version_ref") != expected_plan:
        raise DeveloperRuntimeFailure(
            "STALE_STATE_REPLAY",
            "active_plan_version_ref does not match current tasks.json",
            ["tasks.json"],
        )
    if expected_tasks and report.get("active_tasks_version_ref") != expected_tasks:
        raise DeveloperRuntimeFailure(
            "STALE_STATE_REPLAY",
            "active_tasks_version_ref does not match current tasks.json",
            ["tasks.json"],
        )


def validate_fresh_proof(report: dict[str, Any]) -> None:
    if report.get("runtime_status") != "VERIFIED":
        return
    proof = report.get("fresh_proof")
    if not isinstance(proof, dict) or not proof.get("current_evidence_refs"):
        raise DeveloperRuntimeFailure(
            "FRESH_PROOF_GAP", "verified report lacks current fresh proof evidence"
        )
    for row in proof.get("proving_commands", []):
        if not isinstance(row, dict):
            continue
        if row.get("command") and not row.get("current_output_ref"):
            raise DeveloperRuntimeFailure(
                "FRESH_PROOF_GAP", "proving command lacks current_output_ref"
            )


def test_cases_path(phase_dir: Path, report_path: Path) -> Path:
    unit_candidate = report_path.parent.parent.parent / "test-cases.json"
    if unit_candidate.is_file():
        return unit_candidate
    return phase_dir / "test-cases.json"


def validate(args: argparse.Namespace) -> dict[str, Any]:
    report = load_json(args.report, "SCHEMA_FAILURE")
    if validate_blocked_report(report, args.task_id):
        return {"status": "PASS", "task_id": args.task_id, "report": str(args.report)}
    validate_required_inputs(report, args.phase_dir)
    registry = load_json(args.phase_dir / "artifact-registry.json")
    tasks_artifact = load_json(args.phase_dir / "tasks.json")
    test_cases = load_json(test_cases_path(args.phase_dir, args.report))
    task = find_task(tasks_artifact, args.task_id)
    validate_owner_contract(report)
    validate_scope(report)
    validate_stale_state(report, tasks_artifact)
    validate_registry_refs(registry, collect_runtime_refs(report, task))
    validate_ac_refs(report, test_cases)
    validate_fresh_proof(report)
    return {"status": "PASS", "task_id": args.task_id, "report": str(args.report)}


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        result = validate(args)
    except DeveloperRuntimeFailure as exc:
        print(
            json.dumps(
                failure_payload(exc.code, exc.reason, exc.evidence_refs),
                ensure_ascii=False,
                sort_keys=True,
            )
        )
        return 1
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
