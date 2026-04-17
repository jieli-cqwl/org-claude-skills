#!/usr/bin/env python3
"""Run skill-optimizer seed evals with manifest-approved commands."""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


RAW_COMMAND_FIELDS = {"command", "shell", "raw_command"}
SUPPORTED_CATEGORIES = {
    "trigger", "non_trigger", "neighbor_conflict", "missing_argument",
    "wrong_argument", "permission_denied", "format_injection", "migration_compatibility",
    "fork_isolation", "subagent_skills_full_preload", "pipeline_handoff",
    "conflict_adjudication", "dollar_arguments", "bang_command",
}


def fail(message: str) -> None:
    """Print a stable eval failure and exit nonzero."""
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


def manifest_index(manifest: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Build a manifest script index keyed by id."""
    scripts = manifest.get("scripts")
    if not isinstance(scripts, list) or not scripts:
        fail("manifest scripts must be a nonempty list")
    index: dict[str, dict[str, Any]] = {}
    for script in scripts:
        if not isinstance(script, dict) or not isinstance(script.get("id"), str):
            fail("manifest script id invalid")
        index[script["id"]] = script
    return index


def required_categories(dataset: dict[str, Any]) -> set[str]:
    """Read required eval categories from the dataset."""
    categories = dataset.get("required_categories")
    if not isinstance(categories, list) or not categories:
        fail("required_categories must be nonempty")
    if any(not isinstance(category, str) or not category for category in categories):
        fail("required_categories entries must be strings")
    return set(categories)


def validate_case_shape(case: Any, command_ids: set[str]) -> None:
    """Validate case fields before running checks."""
    if not isinstance(case, dict):
        fail("eval case must be object")
    if RAW_COMMAND_FIELDS & set(case):
        fail(f"{case.get('case_id', '<unknown>')} contains raw shell field")
    required = {
        "case_id",
        "category",
        "input",
        "expected_decision",
        "target_skill_ref",
        "neighbor_skill_refs",
        "run_command_id",
        "pass_fail_condition",
    }
    missing = sorted(required - set(case))
    if missing:
        fail(f"{case.get('case_id', '<unknown>')} missing fields: {', '.join(missing)}")
    if "observed_decision" in case:
        fail(f"{case['case_id']} must not provide observed_decision")
    if not isinstance(case["neighbor_skill_refs"], list):
        fail(f"{case['case_id']} neighbor_skill_refs must be list")
    command_id = case.get("run_command_id")
    if command_id is not None and command_id not in command_ids:
        fail(f"{case['case_id']} unknown run_command_id: {command_id}")
    if command_id is None and case.get("check_type") != "fixture":
        fail(f"{case['case_id']} requires fixture check_type")
    category = case.get("category")
    if category not in SUPPORTED_CATEGORIES:
        fail(f"{case['case_id']} unsupported category: {category}")


def validate_dataset(dataset: dict[str, Any], command_ids: set[str]) -> list[dict[str, Any]]:
    """Validate dataset shape, category coverage, and evidence boundary."""
    if dataset.get("artifact_type") != "skill-optimizer-evals":
        fail("artifact_type must be skill-optimizer-evals")
    cases = dataset.get("cases")
    if not isinstance(cases, list) or not cases:
        fail("cases must be nonempty")
    for case in cases:
        validate_case_shape(case, command_ids)
    missing = sorted(required_categories(dataset) - {case["category"] for case in cases})
    if missing:
        fail("missing eval categories: " + ", ".join(missing))
    five_ten_thirty = dataset.get("usability_evidence", {}).get("five_ten_thirty", {})
    if five_ten_thirty.get("counts_as_quality_benefit") is not False:
        fail("5/10/30 must remain usability evidence")
    if dataset.get("quality_benefit"):
        fail("quality benefit must not be derived from eval dataset")
    return cases


def argument_allowed(arg: str, allowed_args: list[str]) -> bool:
    """Check one manifest command argument against the declared allowlist."""
    if arg == "$DATASET":
        return "evals.json" in allowed_args
    if arg == "$MANIFEST":
        return "manifest.json" in allowed_args
    if arg == "$TARGET_SKILL":
        return "$TARGET_SKILL" in allowed_args
    if arg == "$CASE_OUT_DIR":
        return "$CASE_OUT_DIR" in allowed_args
    if arg.startswith("-"):
        return arg in allowed_args
    return arg in allowed_args


def repo_root_from_skill_dir(skill_dir: Path) -> Path:
    """Return the repository root for a bundled skill directory."""
    try:
        return skill_dir.parents[2]
    except IndexError:
        fail(f"cannot resolve repository root from {skill_dir}")


def resolve_target_skill(case: dict[str, Any], repo_root: Path) -> Path:
    """Resolve the target skill path for fixture-backed command evals."""
    raw_ref = str(case.get("target_skill_ref", "")).strip()
    if not raw_ref:
        fail(f"{case['case_id']} target_skill_ref is required")
    target = Path(raw_ref)
    if not target.is_absolute():
        target = repo_root / target
    target = target.resolve()
    try:
        target.relative_to(repo_root)
    except ValueError:
        fail(f"{case['case_id']} target_skill_ref escapes repository root")
    if not target.is_dir():
        fail(f"{case['case_id']} target_skill_ref missing: {target}")
    return target


def validate_audit_fixture_output(case: dict[str, Any], case_out_dir: Path) -> dict[str, Any]:
    """Validate audit-skill output for eval cases that execute the audit fixture."""
    if case.get("check_type") != "audit_fixture":
        return {}
    artifact_path = case_out_dir / "skill-audit.json"
    artifact = load_json(artifact_path)
    findings = artifact.get("findings")
    if not isinstance(findings, list):
        fail(f"{case['case_id']} audit artifact findings must be array")
    fail_finding_ids = sorted(
        str(finding.get("id"))
        for finding in findings
        if isinstance(finding, dict) and finding.get("severity") == "FAIL"
    )
    expected_fail = {str(item) for item in case.get("expected_fail_finding_ids", [])}
    missing = sorted(expected_fail - set(fail_finding_ids))
    if missing:
        fail(f"{case['case_id']} missing FAIL findings: {', '.join(missing)}")
    if case.get("expected_no_fail_findings") is True and fail_finding_ids:
        fail(f"{case['case_id']} emitted unexpected FAIL findings: {', '.join(fail_finding_ids)}")
    return {
        "artifact_type": artifact.get("artifact_type"),
        "artifact_hash": sha256_file(artifact_path),
        "fail_finding_ids": fail_finding_ids,
    }


def resolve_command_arg(
    arg: str,
    dataset_path: Path,
    manifest_path: Path,
    case: dict[str, Any],
    case_out_dir: Path,
    repo_root: Path,
) -> str:
    """Resolve safe command placeholders to concrete argv values."""
    if arg == "$DATASET":
        return str(dataset_path)
    if arg == "$MANIFEST":
        return str(manifest_path)
    if arg == "$TARGET_SKILL":
        return str(resolve_target_skill(case, repo_root))
    if arg == "$CASE_OUT_DIR":
        return str(case_out_dir)
    return arg


def run_manifest_command(case: dict[str, Any], script: dict[str, Any], dataset_path: Path, manifest_path: Path) -> dict[str, Any]:
    """Run a manifest-approved script through argv without shell interpolation."""
    raw_args = case.get("command_args", [])
    if not isinstance(raw_args, list) or any(not isinstance(arg, str) for arg in raw_args):
        fail(f"{case['case_id']} command_args must be string list")
    denied = script.get("denied_args", [])
    if any(denied_arg in arg for arg in raw_args for denied_arg in denied):
        fail(f"{case['case_id']} command_args contain denied token")
    allowed_args = script.get("allowed_args", [])
    if not isinstance(allowed_args, list) or any(not isinstance(arg, str) for arg in allowed_args):
        fail(f"{case['case_id']} manifest allowed_args invalid")
    unapproved = [arg for arg in raw_args if not argument_allowed(arg, allowed_args)]
    if unapproved:
        fail(f"{case['case_id']} command_args contain unapproved args: {', '.join(unapproved)}")
    skill_dir = manifest_path.parent.parent.resolve()
    scripts_dir = skill_dir / "scripts"
    script_path = (skill_dir / str(script.get("path", ""))).resolve()
    try:
        script_path.relative_to(scripts_dir)
    except ValueError:
        fail(f"{case['case_id']} manifest script path escapes scripts dir")
    if not script_path.is_file():
        fail(f"{case['case_id']} manifest script path missing: {script_path}")
    repo_root = repo_root_from_skill_dir(skill_dir)
    with tempfile.TemporaryDirectory(prefix=f"skill_optimizer_eval_{case['case_id']}_") as temp_dir:
        case_out_dir = Path(temp_dir)
        args = [resolve_command_arg(arg, dataset_path, manifest_path, case, case_out_dir, repo_root) for arg in raw_args]
        result = subprocess.run(
            [sys.executable, str(script_path), *args],
            cwd=str(skill_dir),
            capture_output=True,
            text=True,
            timeout=int(script["timeout_seconds"]),
            check=False,
        )
        output = (result.stdout or "") + (result.stderr or "")
        if len(output.encode("utf-8")) > int(script["output_limit_bytes"]):
            fail(f"{case['case_id']} command output exceeded limit")
        expected = int(case.get("expected_exit_code", 0))
        if result.returncode != expected:
            fail(f"{case['case_id']} command exit {result.returncode}, expected {expected}")
        evidence = {
            "exit_code": result.returncode,
            "output_hash": "sha256:" + hashlib.sha256(output.encode("utf-8")).hexdigest(),
        }
        evidence.update(validate_audit_fixture_output(case, case_out_dir))
        return evidence


def read_field(case: dict[str, Any], field: str) -> Any:
    """Read a case field used by fixture assertions."""
    if field not in case:
        fail(f"{case['case_id']} missing assertion field: {field}")
    return case[field]


def run_assertions(case: dict[str, Any]) -> None:
    """Run fixture assertions for one case."""
    assertions = case.get("assertions", [])
    if not isinstance(assertions, list) or not assertions:
        fail(f"{case['case_id']} assertions must be nonempty")
    for assertion in assertions:
        if not isinstance(assertion, dict):
            fail(f"{case['case_id']} assertion must be object")
        kind = assertion.get("kind")
        field = assertion.get("field")
        value = assertion.get("value")
        actual = read_field(case, field)
        if kind == "contains" and str(value) not in str(actual):
            fail(f"{case['case_id']} assertion failed: {field} lacks {value}")
        if kind == "equals" and actual != value:
            fail(f"{case['case_id']} assertion failed: {field} differs")
        if kind not in {"contains", "equals"}:
            fail(f"{case['case_id']} unsupported assertion kind: {kind}")


def derive_observed_decision(case: dict[str, Any]) -> str:
    """Derive decisions with format and safety signals before workflow routing."""
    text = str(case.get("input", ""))
    lower = text.lower()
    if text.strip() == "/skill-optimizer":
        return "ask_for_target_skill"
    if "--url" in text:
        return "reject_wrong_argument"
    if "$ARGUMENTS" in text:
        return "parse_arguments_contract"
    if "!command" in text:
        return "require_manifest_command_id"
    if "new-skills" in text:
        return "retire_legacy_new_skills"
    if "skills:" in text:
        return "detect_full_preload_context_risk"
    if "markdown" in lower:
        return "reject_markdown_fact_source"
    if "fork" in lower:
        return "require_fork_isolation"
    if "JSON" in text:
        return "require_json_pipeline_handoff"
    if "冲突" in text:
        return "use_priority_lattice"
    if ("Edit" in text or "写" in text) and "精确" not in text and "exact" not in lower:
        return "deny_write_without_scope"
    if "创建" in text and ("审计" in text or "优化" in text):
        return "split_creation_and_optimization"
    if "创建" in text:
        return "route_skill_creator"
    if "审计" in text or "优化" in text:
        return "use_skill_optimizer"
    return "reject_wrong_argument"


def run_case(case: dict[str, Any], scripts: dict[str, dict[str, Any]], dataset_path: Path, manifest_path: Path) -> dict[str, Any]:
    """Run one eval case and return a structured result."""
    run_assertions(case)
    command_evidence: dict[str, Any] = {}
    command_id = case.get("run_command_id")
    mode = "fixture"
    if command_id:
        mode = "manifest_command"
        command_evidence = run_manifest_command(case, scripts[command_id], dataset_path, manifest_path)
    observed_decision = derive_observed_decision(case)
    status = "PASS" if observed_decision == case.get("expected_decision") else "FAIL"
    return {
        "case_id": case["case_id"],
        "category": case["category"],
        "status": status,
        "expected_decision": case["expected_decision"],
        "observed_decision": observed_decision,
        "run_command_id": command_id,
        "execution_mode": mode,
        "pass_fail_condition": case["pass_fail_condition"],
        "evidence_refs": [f"case:{case['case_id']}"],
        "command_evidence": command_evidence,
    }


def build_results(dataset_path: Path, manifest_path: Path) -> dict[str, Any]:
    """Build the eval result artifact."""
    dataset_path = dataset_path.resolve()
    manifest_path = manifest_path.resolve()
    dataset = load_json(dataset_path)
    manifest = load_json(manifest_path)
    scripts = manifest_index(manifest)
    cases = validate_dataset(dataset, set(scripts))
    results = [run_case(case, scripts, dataset_path, manifest_path) for case in cases]
    passed = sum(1 for result in results if result["status"] == "PASS")
    total = len(results)
    return {
        "artifact_type": "eval-results",
        "schema_version": "1.0.0",
        "artifact_id": "eval-results:skill-optimizer",
        "producer": {"name": "run_evals.py", "command": "run_evals.py"},
        "inputs": [
            {"path": str(dataset_path), "role": "eval_dataset", "hash": sha256_file(dataset_path)},
            {"path": str(manifest_path), "role": "script_manifest", "hash": sha256_file(manifest_path)},
        ],
        "status": "evaluated" if passed == total else "blocked",
        "design_anchors": dataset.get("design_anchors", []),
        "verification_result_draft_input": {
            "consumer": "build_verification_result.py",
            "artifact_ref": "eval-results:skill-optimizer",
            "quality_source": False,
        },
        "summary": {"total": total, "passed": passed, "failed": total - passed},
        "usability_evidence": dataset.get("usability_evidence", {}),
        "results": results,
    }


def main() -> None:
    """Run eval dataset and write eval-results JSON."""
    parser = argparse.ArgumentParser()
    parser.add_argument("evals_json")
    parser.add_argument("manifest_json")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    artifact = build_results(Path(args.evals_json), Path(args.manifest_json))
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(artifact, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if artifact["status"] != "evaluated":
        fail("one or more eval cases failed")


if __name__ == "__main__":
    main()
