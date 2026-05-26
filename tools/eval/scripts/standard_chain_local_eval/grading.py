"""Judge prompts, grading conversion, and failure recording for local evals."""

from __future__ import annotations

import json
import tempfile
from pathlib import Path

from .common import INFRA_FAILURE_FINDING, run_command, write_json


def judge_schema() -> dict:
    """Return the structured judge schema consumed by `codex exec`."""

    return {
        "type": "object",
        "properties": {
            "expectations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "text": {"type": "string"},
                        "passed": {"type": "boolean"},
                        "evidence": {"type": "string"},
                    },
                    "required": ["text", "passed", "evidence"],
                    "additionalProperties": False,
                },
            },
            "notes": {"type": "array", "items": {"type": "string"}},
            "optimization_findings": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "issue": {"type": "string"},
                        "suggested_change": {"type": "string"},
                    },
                    "required": ["issue", "suggested_change"],
                    "additionalProperties": False,
                },
            },
            "anchor_results": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "string"},
                        "passed": {"type": "boolean"},
                        "evidence": {"type": "string"},
                    },
                    "required": ["id", "passed", "evidence"],
                    "additionalProperties": False,
                },
            },
        },
        "required": [
            "expectations",
            "notes",
            "optimization_findings",
            "anchor_results",
        ],
        "additionalProperties": False,
    }


def build_anchor_prompt(case: dict) -> str:
    """Render expected preference anchors for judge instructions."""

    anchors = case.get("preference_anchor_definitions", [])
    if not anchors:
        return "No preference anchors are expected. Return anchor_results as an empty array."
    lines = [
        "Preference anchors:",
        "For each expected anchor, return one anchor_results item with the same id.",
    ]
    for anchor in anchors:
        lines.append(f"- {anchor['id']}: {anchor['anchor']}")
    return "\n".join(lines)


def build_judge_prompt(skill_name: str, case: dict, response_text: str) -> str:
    """Build a strict grading prompt for one response."""

    expectations = "\n".join(f"- {item}" for item in case.get("expectations", []))
    anchor_prompt = build_anchor_prompt(case)
    return f"""
你是 skill eval grader。请只根据实际输出判断每条 expectation 是否被满足。
不要因为回答提到关键词就给通过；必须有清晰行为、阻断条件或下一步证据。

Skill: {skill_name}
Eval id: {case["id"]}

Prompt:
{case["prompt"]}

Expectations:
{expectations}

{anchor_prompt}

Actual output:
{response_text}
""".strip()


def normalize_anchor_results(case: dict, judged: dict) -> list[dict]:
    """Return anchor results aligned to the case-declared expected anchors."""

    expected_ids = list(case.get("expected_anchors", []))
    if not expected_ids:
        return []
    raw_results = judged.get("anchor_results", [])
    results_by_id = {
        item.get("id"): item
        for item in raw_results
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    normalized = []
    for anchor_id in expected_ids:
        result = results_by_id.get(anchor_id)
        if result is None:
            normalized.append(
                {
                    "id": anchor_id,
                    "passed": False,
                    "evidence": "grader did not return evidence for this anchor",
                }
            )
            continue
        normalized.append(
            {
                "id": anchor_id,
                "passed": bool(result.get("passed")),
                "evidence": str(result.get("evidence", "")),
            }
        )
    return normalized


def summarize_anchor_results(anchor_results: list[dict]) -> dict:
    """Summarize encoded-preference anchor fidelity for one graded run."""

    total = len(anchor_results)
    passed = sum(1 for item in anchor_results if item["passed"])
    failed = total - passed
    return {
        "passed": passed,
        "failed": failed,
        "total": total,
        "fidelity": round(passed / total, 4) if total else None,
    }


def run_judge(
    skill_name: str, case: dict, response_text: str, run_dir: Path, args: object
) -> dict:
    """Grade one response and write skill-creator-compatible grading.json."""

    timeout_sec = int(getattr(args, "timeout_sec"))
    model = getattr(args, "judge_model")
    with tempfile.TemporaryDirectory(
        prefix="standard-chain-local-eval-judge-"
    ) as temp_dir:
        temp_path = Path(temp_dir)
        schema_path = temp_path / "schema.json"
        schema_path.write_text(json.dumps(judge_schema()), encoding="utf-8")
        command = [
            "codex",
            "exec",
            "--ephemeral",
            "--skip-git-repo-check",
            "--sandbox",
            "read-only",
            "--color",
            "never",
            "-C",
            str(temp_path),
            "--output-schema",
            str(schema_path),
            build_judge_prompt(skill_name, case, response_text),
        ]
        if model:
            command[2:2] = ["--model", model]
        completed = run_command(command, temp_path, timeout_sec)
    (run_dir / "grader.log").write_text(
        (completed.stdout or "") + (completed.stderr or ""), encoding="utf-8"
    )
    if completed.returncode != 0:
        raise RuntimeError(
            f"{skill_name}/{case['id']}: judge exited {completed.returncode}"
        )
    judged = json.loads(completed.stdout)
    expectations = judged["expectations"]
    anchor_results = normalize_anchor_results(case, judged)
    anchor_summary = summarize_anchor_results(anchor_results)
    passed = sum(1 for item in expectations if item["passed"])
    total = len(expectations)
    grading = {
        "expectations": expectations,
        "anchor_results": anchor_results,
        "preference_anchor_summary": anchor_summary,
        "summary": {
            "passed": passed,
            "failed": total - passed,
            "total": total,
            "pass_rate": round((passed / total) if total else 0.0, 4),
        },
        "optimization_findings": judged.get("optimization_findings", []),
        "user_notes_summary": {
            "uncertainties": judged.get("notes", []),
            "needs_review": [],
            "workarounds": [],
        },
    }
    write_json(run_dir / "grading.json", grading)
    return grading


def summarize_grading(
    skill_name: str, case: dict, run_dir: Path, grading: dict, run_mode: str
) -> dict:
    """Convert one grading payload into the top-level run summary row."""

    failed = [item["text"] for item in grading["expectations"] if not item["passed"]]
    anchor_summary = grading.get("preference_anchor_summary", {})
    return {
        "skill_name": skill_name,
        "eval_id": case["id"],
        "run_mode": run_mode,
        "run_dir": str(run_dir),
        "passed": grading["summary"]["passed"],
        "failed": grading["summary"]["failed"],
        "total": grading["summary"]["total"],
        "pass_rate": grading["summary"]["pass_rate"],
        "status": "graded",
        "graded": True,
        "failed_expectations": failed,
        "anchor_passed": anchor_summary.get("passed", 0),
        "anchor_failed": anchor_summary.get("failed", 0),
        "anchor_total": anchor_summary.get("total", 0),
        "anchor_fidelity": anchor_summary.get("fidelity"),
        "optimization_findings": grading.get("optimization_findings", []),
    }


def write_eval_metadata(skill_name: str, case: dict, run_dir: Path) -> None:
    """Persist metadata needed by humans and benchmark viewers."""

    write_json(
        run_dir / "eval_metadata.json",
        {
            "skill_name": skill_name,
            "eval_id": case["id"],
            "prompt": case["prompt"],
            "files": case.get("files", []),
            "assertions": case.get("expectations", []),
            "expected_anchors": case.get("expected_anchors", []),
            "preference_anchor_definitions": case.get(
                "preference_anchor_definitions", []
            ),
        },
    )


def record_infra_failure(
    skill_name: str, case: dict, run_dir: Path, error: Exception, args: object
) -> dict:
    """Persist an eval infrastructure failure without hiding it as a score."""

    message = str(error)
    run_mode = str(getattr(args, "run_mode"))
    write_eval_metadata(skill_name, case, run_dir)
    write_json(
        run_dir / "grading.json",
        {
            "expectations": [],
            "anchor_results": [],
            "preference_anchor_summary": {
                "passed": 0,
                "failed": 0,
                "total": 0,
                "fidelity": None,
            },
            "summary": {
                "passed": 0,
                "failed": 0,
                "total": 0,
                "pass_rate": None,
                "graded": False,
            },
            "infrastructure_failure": message,
            "optimization_findings": [INFRA_FAILURE_FINDING],
        },
    )
    return {
        "skill_name": skill_name,
        "eval_id": case["id"],
        "run_mode": run_mode,
        "run_dir": str(run_dir),
        "passed": 0,
        "failed": 0,
        "total": 0,
        "pass_rate": None,
        "status": "infra_failure",
        "graded": False,
        "failed_expectations": [],
        "anchor_passed": 0,
        "anchor_failed": 0,
        "anchor_total": 0,
        "anchor_fidelity": None,
        "infra_failure": message,
        "optimization_findings": [INFRA_FAILURE_FINDING],
    }
