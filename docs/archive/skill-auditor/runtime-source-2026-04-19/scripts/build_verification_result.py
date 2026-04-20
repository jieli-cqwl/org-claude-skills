#!/usr/bin/env python3
"""Aggregate skill-auditor runtime evidence into verification-result.json."""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
SCHEMA_DIR = SKILL_DIR / "schemas"
MANIFEST_PATH = SCRIPT_DIR / "manifest.json"

REQUIRED_COVERAGE_TOKENS = {
    "C09",
    "C10",
    "C11",
    "C12",
    "C13",
    "C14",
    "C99",
    "L",
    "O",
    "S",
    "F1",
    "F2",
    "W1",
    "W2",
    "W3",
    "M1",
    "SO-TRIGGER-01",
    "SO-RUNTIME-01",
    "SO-VALIDATION-01",
}


def fail(message: str) -> None:
    """Print a stable aggregation failure and exit nonzero."""
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path) -> dict[str, Any]:
    """Load a JSON object from disk."""
    try:
        with path.open(encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        fail(f"file not found: {path}")
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON in {path}: {exc}")
    if not isinstance(data, dict):
        fail(f"top-level JSON must be object: {path}")
    return data


def sha256_file(path: Path) -> str:
    """Hash a file for artifact provenance."""
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def validator_entry(name: str, artifact: dict[str, Any], path: Path) -> dict[str, str]:
    """Create a PASS validation row after a validator exits cleanly."""
    return {"name": name, "artifact_id": str(artifact.get("artifact_id", path.name)), "path": str(path), "result": "PASS"}


def run_validator(name: str, artifact: dict[str, Any], path: Path, args: list[str]) -> dict[str, str]:
    """Run one local validator and return a PASS row only after exit zero."""
    command = [sys.executable, str(SCRIPT_DIR / args[0]), *args[1:]]
    result = subprocess.run(command, cwd=str(SKILL_DIR), capture_output=True, text=True, timeout=30, check=False)
    if result.returncode != 0:
        details = (result.stderr or result.stdout or "").strip()
        fail(f"{name} failed for {path}: {details}")
    return validator_entry(name, artifact, path)


def parse_fresh_command(raw: str) -> dict[str, str]:
    """Parse a command=result evidence argument."""
    if "=" not in raw:
        fail(f"fresh command missing result separator: {raw}")
    command, result = raw.rsplit("=", 1)
    command = command.strip()
    result = result.strip()
    if not command or not result:
        fail("fresh command requires command and result")
    if result != "PASS":
        fail(f"fresh command is not PASS: {command}")
    return {"command": command, "result": result}


def read_text(path: Path, label: str) -> str:
    """Read a UTF-8 text input with a stable user-facing failure."""
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"{label} file not found: {path}")


def validate_coverage(path: Path, text: str, plan_trace: dict[str, Any]) -> dict[str, Any]:
    """Validate coverage text contains required traceability tokens."""
    missing = sorted(token for token in REQUIRED_COVERAGE_TOKENS if token not in text)
    if missing:
        fail("coverage missing tokens: " + ", ".join(missing))
    implemented_files = [
        line.strip()[3:-1]
        for line in text.splitlines()
        if line.strip().startswith("- `") and line.strip().endswith("`")
    ]
    return {
        "path": str(path),
        "hash": sha256_file(path),
        "source_markers": sorted(token for token in REQUIRED_COVERAGE_TOKENS if token.startswith("C") or token in {"L", "O", "S"}),
        "review_decisions": ["F1", "F2", "W1", "W2", "W3", "M1"],
        "implemented_files": implemented_files,
        "accepted_findings": plan_trace["accepted_findings"],
        "file_boundaries": plan_trace["file_boundaries"],
        "verification_contracts": plan_trace["verification_contracts"],
    }


def require_nonempty_list(artifact: dict[str, Any], field: str, label: str) -> list[Any]:
    """Return a nonempty list field from an upstream artifact."""
    value = artifact.get(field)
    if not isinstance(value, list) or not value:
        fail(f"{label} requires nonempty {field}")
    return value


def validate_audit_artifact(audit: dict[str, Any]) -> None:
    """Validate upstream skill-audit evidence before certification."""
    if audit.get("artifact_type") != "skill-audit":
        fail("audit artifact_type must be skill-audit")
    if audit.get("status") != "audited":
        fail("audit status must be audited")
    require_nonempty_list(audit, "evidence_refs", "audit")
    findings = require_nonempty_list(audit, "findings", "audit")
    rendered_views = require_nonempty_list(audit, "rendered_views", "audit")
    for view in rendered_views:
        if not isinstance(view, dict) or view.get("stale") is not False:
            fail("audit rendered views must be fresh")
    for finding in findings:
        if not isinstance(finding, dict):
            fail("audit findings must be objects")
        if finding.get("evidence_level") == "E5":
            fail(f"audit finding {finding.get('id', '<unknown>')} uses forbidden E5 evidence")
        if finding.get("severity") == "FAIL":
            for field in ("file_ref", "evidence_refs", "design_anchors"):
                if not finding.get(field):
                    fail(f"audit FAIL finding {finding.get('id', '<unknown>')} missing {field}")


def validate_plan_artifact(plan: dict[str, Any]) -> dict[str, Any]:
    """Validate upstream optimization-plan evidence before certification."""
    if plan.get("artifact_type") != "optimization-plan":
        fail("plan artifact_type must be optimization-plan")
    if plan.get("status") != "planned":
        fail("plan status must be planned")
    accepted = require_nonempty_list(plan, "accepted_findings", "plan")
    accepted_ids = {str(item) for item in accepted if str(item).strip()}
    if len(accepted_ids) != len(accepted):
        fail("plan accepted_findings must be nonempty strings")
    boundaries = require_nonempty_list(plan, "file_boundaries", "plan")
    contracts = require_nonempty_list(plan, "verification_contracts", "plan")
    boundary_trace = []
    boundary_ids = set()
    for boundary in boundaries:
        if not isinstance(boundary, dict):
            fail("plan file_boundaries entries must be objects")
        finding_id = str(boundary.get("finding_id", "")).strip()
        path = str(boundary.get("path", "")).strip()
        mode = str(boundary.get("mode", "")).strip()
        if not finding_id or not path or not mode:
            fail("plan file_boundaries entries require finding_id, path, and mode")
        boundary_ids.add(finding_id)
        boundary_trace.append({"finding_id": finding_id, "path": path, "mode": mode})
    allowed_dimensions = {"D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8"}
    contract_trace = []
    contract_ids = set()
    for contract in contracts:
        if not isinstance(contract, dict):
            fail("plan verification_contracts entries must be objects")
        finding_id = str(contract.get("finding_id", "")).strip()
        dimension = contract.get("dimension")
        success_ref = str(contract.get("success_standard_ref", "")).strip()
        expected_behavior = str(contract.get("expected_behavior", "")).strip()
        command = str(contract.get("command", "")).strip()
        expected_output = str(contract.get("expected_output", "")).strip()
        if not finding_id:
            fail("plan verification contract missing finding_id")
        if dimension not in allowed_dimensions:
            fail(f"plan verification contract {finding_id} invalid dimension")
        if not success_ref.startswith(f"{finding_id}:"):
            fail(f"plan verification contract {finding_id} success_standard_ref must bind finding id")
        if not expected_behavior or not command or not expected_output:
            fail(f"plan verification contract {finding_id} missing expected behavior, command, or output")
        contract_ids.add(finding_id)
        contract_trace.append(
            {
                "finding_id": finding_id,
                "dimension": str(dimension),
                "success_standard_ref": success_ref,
                "expected_behavior": expected_behavior,
                "command": command,
                "expected_output": expected_output,
            }
        )
    missing_boundary = sorted(accepted_ids - boundary_ids)
    missing_contract = sorted(accepted_ids - contract_ids)
    extra_boundary = sorted(boundary_ids - accepted_ids)
    extra_contract = sorted(contract_ids - accepted_ids)
    if missing_boundary:
        fail("plan accepted findings without file boundaries: " + ", ".join(missing_boundary))
    if missing_contract:
        fail("plan accepted findings without verification contracts: " + ", ".join(missing_contract))
    if extra_boundary:
        fail("plan file boundaries outside accepted findings: " + ", ".join(extra_boundary))
    if extra_contract:
        fail("plan verification contracts outside accepted findings: " + ", ".join(extra_contract))
    return {
        "accepted_findings": sorted(accepted_ids),
        "file_boundaries": boundary_trace,
        "verification_contracts": contract_trace,
    }


def validate_eval_artifact(eval_results: dict[str, Any]) -> dict[str, Any]:
    """Validate upstream eval-results evidence before certification."""
    if eval_results.get("artifact_type") != "eval-results":
        fail("eval artifact_type must be eval-results")
    if eval_results.get("status") != "evaluated":
        fail("eval status must be evaluated")
    summary = eval_results.get("summary")
    if not isinstance(summary, dict):
        fail("eval summary must be object")
    total = summary.get("total")
    passed = summary.get("passed")
    failed = summary.get("failed")
    if not isinstance(total, int) or not isinstance(passed, int) or not isinstance(failed, int):
        fail("eval summary counts must be integers")
    if total <= 0 or failed != 0 or passed != total:
        fail("eval summary must report every case passing")
    return summary


def validate_fresh_commands(fresh_commands: list[dict[str, str]], coverage_text: str) -> None:
    """Require every command proof to be present in coverage with PASS."""
    lines = coverage_text.splitlines()
    for entry in fresh_commands:
        command = entry["command"]
        matched = False
        for index, line in enumerate(lines):
            if f"Command: `{command}`" in line or f"Command: {command}" in line:
                window = "\n".join(lines[index : index + 3])
                matched = "Result: PASS" in window
                break
        if not matched:
            fail(f"fresh command lacks coverage PASS evidence: {command}")


def validate_plan_commands(plan_trace: dict[str, Any], fresh_commands: list[dict[str, str]]) -> None:
    """Require every accepted finding contract to have fresh command evidence."""
    fresh_command_set = {entry["command"] for entry in fresh_commands}
    missing = sorted(
        contract["command"]
        for contract in plan_trace["verification_contracts"]
        if contract["command"] not in fresh_command_set
    )
    if missing:
        fail("plan verification contract missing fresh command evidence: " + ", ".join(missing))


def run_upstream_validations(
    audit_path: Path,
    audit: dict[str, Any],
    plan_path: Path,
    plan: dict[str, Any],
    eval_path: Path,
    eval_results: dict[str, Any],
) -> dict[str, list[dict[str, str]]]:
    """Run validators that verification-result claims as PASS evidence."""
    return {
        "schema_validation": [
            run_validator("skill-audit schema", audit, audit_path, ["validate_schema.py", str(SCHEMA_DIR / "skill-audit.schema.json"), str(audit_path)]),
            run_validator("optimization-plan schema", plan, plan_path, ["validate_schema.py", str(SCHEMA_DIR / "optimization-plan.schema.json"), str(plan_path)]),
        ],
        "semantic_validation": [
            run_validator("skill-audit semantic", audit, audit_path, ["validate_semantics.py", str(audit_path)]),
        ],
        "consumer_validation": [
            run_validator("skill-audit consumers", audit, audit_path, ["validate_consumers.py", str(SCHEMA_DIR / "field-consumers.json"), str(audit_path)]),
            run_validator("optimization-plan consumers", plan, plan_path, ["validate_consumers.py", str(SCHEMA_DIR / "field-consumers.json"), str(plan_path)]),
        ],
        "rendered_view_validation": [
            run_validator("rendered views", audit, audit_path, ["validate_rendered_views.py", str(audit_path)]),
        ],
        "eval_validation": [
            run_validator("eval results", eval_results, eval_path, ["validate_eval_results.py", str(eval_path), str(MANIFEST_PATH)]),
        ],
    }


def build(args: argparse.Namespace) -> dict[str, Any]:
    """Build a verification-result artifact from runtime evidence."""
    audit_path = Path(args.audit)
    plan_path = Path(args.plan)
    eval_path = Path(args.eval_results)
    coverage_path = Path(args.coverage)
    audit = load_json(audit_path)
    plan = load_json(plan_path)
    eval_results = load_json(eval_path)
    validations = run_upstream_validations(audit_path, audit, plan_path, plan, eval_path, eval_results)
    fresh_commands = [parse_fresh_command(raw) for raw in args.fresh_command]
    if not fresh_commands:
        fail("fresh command evidence is required")
    validate_audit_artifact(audit)
    plan_trace = validate_plan_artifact(plan)
    eval_summary = validate_eval_artifact(eval_results)
    coverage_text = read_text(coverage_path, "coverage")
    validate_plan_commands(plan_trace, fresh_commands)
    coverage = validate_coverage(coverage_path, coverage_text, plan_trace)
    validate_fresh_commands(fresh_commands, coverage_text)
    anchors = sorted(set(audit.get("design_anchors", [])) | set(plan.get("design_anchors", [])) | {"SO-VALIDATION-01"})
    return {
        "artifact_type": "verification-result",
        "schema_version": "1.0.0",
        "artifact_id": "verification-result:skill-auditor",
        "producer": {"name": "build_verification_result.py", "command": "build_verification_result.py"},
        "inputs": [
            {"path": str(audit_path), "role": "skill_audit", "hash": sha256_file(audit_path)},
            {"path": str(plan_path), "role": "optimization_plan", "hash": sha256_file(plan_path)},
            {"path": str(eval_path), "role": "eval_results", "hash": sha256_file(eval_path)},
            {"path": str(coverage_path), "role": "implementation_coverage", "hash": coverage["hash"]},
        ],
        "status": "verified",
        "design_anchors": anchors,
        "evidence_refs": audit.get("evidence_refs", []) + plan.get("evidence_refs", []),
        "rendered_views": audit.get("rendered_views", []),
        "schema_validation": validations["schema_validation"] + [
            {"name": "verification-result schema", "artifact_id": "verification-result:skill-auditor", "path": str(args.out), "result": "PASS"},
        ],
        "semantic_validation": validations["semantic_validation"],
        "consumer_validation": validations["consumer_validation"],
        "rendered_view_validation": validations["rendered_view_validation"],
        "eval_results": {
            "artifact_id": eval_results.get("artifact_id"),
            "status": eval_results.get("status"),
            "summary": eval_summary,
        },
        "fresh_commands": fresh_commands,
        "coverage": coverage,
        "decision": {"status": "PASS", "reason": "schema, semantic, consumer, render, eval, command, and coverage evidence present"},
    }


def main() -> None:
    """Parse arguments and write verification-result JSON."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--audit", required=True)
    parser.add_argument("--plan", required=True)
    parser.add_argument("--eval-results", required=True)
    parser.add_argument("--coverage", required=True)
    parser.add_argument("--fresh-command", action="append", default=[])
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    artifact = build(args)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    temp = out.with_name(f".{out.name}.tmp")
    try:
        temp.write_text(json.dumps(artifact, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        run_validator(
            "verification-result schema",
            artifact,
            temp,
            ["validate_schema.py", str(SCHEMA_DIR / "verification-result.schema.json"), str(temp)],
        )
        temp.replace(out)
    except Exception:
        if temp.exists():
            temp.unlink()
        raise


if __name__ == "__main__":
    main()
