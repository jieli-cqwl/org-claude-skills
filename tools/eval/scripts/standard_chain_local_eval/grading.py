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
        },
        "required": ["expectations", "notes", "optimization_findings"],
        "additionalProperties": False,
    }


def build_judge_prompt(skill_name: str, case: dict, response_text: str) -> str:
    """Build a strict grading prompt for one response."""

    expectations = "\n".join(f"- {item}" for item in case.get("expectations", []))
    return f"""
你是 skill eval grader。请只根据实际输出判断每条 expectation 是否被满足。
不要因为回答提到关键词就给通过；必须有清晰行为、阻断条件或下一步证据。

Skill: {skill_name}
Eval id: {case["id"]}

Prompt:
{case["prompt"]}

Expected output:
{case["expected_output"]}

Expectations:
{expectations}

Actual output:
{response_text}
""".strip()


def run_judge(skill_name: str, case: dict, response_text: str, run_dir: Path, timeout_sec: int, model: str | None) -> dict:
    """Grade one response and write skill-creator-compatible grading.json."""

    with tempfile.TemporaryDirectory(prefix="standard-chain-local-eval-judge-") as temp_dir:
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
    (run_dir / "grader.log").write_text((completed.stdout or "") + (completed.stderr or ""), encoding="utf-8")
    if completed.returncode != 0:
        raise RuntimeError(f"{skill_name}/{case['id']}: judge exited {completed.returncode}")
    judged = json.loads(completed.stdout)
    expectations = judged["expectations"]
    passed = sum(1 for item in expectations if item["passed"])
    total = len(expectations)
    grading = {
        "expectations": expectations,
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


def summarize_grading(skill_name: str, case: dict, run_dir: Path, grading: dict) -> dict:
    """Convert one grading payload into the top-level run summary row."""

    failed = [item["text"] for item in grading["expectations"] if not item["passed"]]
    return {
        "skill_name": skill_name,
        "eval_id": case["id"],
        "run_dir": str(run_dir),
        "passed": grading["summary"]["passed"],
        "failed": grading["summary"]["failed"],
        "total": grading["summary"]["total"],
        "pass_rate": grading["summary"]["pass_rate"],
        "status": "graded",
        "graded": True,
        "failed_expectations": failed,
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
            "expected_output": case["expected_output"],
            "files": case.get("files", []),
            "assertions": case.get("expectations", []),
        },
    )


def record_infra_failure(skill_name: str, case: dict, run_dir: Path, error: Exception) -> dict:
    """Persist an eval infrastructure failure without hiding it as a score."""

    message = str(error)
    write_eval_metadata(skill_name, case, run_dir)
    write_json(
        run_dir / "grading.json",
        {
            "expectations": [],
            "summary": {"passed": 0, "failed": 0, "total": 0, "pass_rate": None, "graded": False},
            "infrastructure_failure": message,
            "optimization_findings": [INFRA_FAILURE_FINDING],
        },
    )
    return {
        "skill_name": skill_name,
        "eval_id": case["id"],
        "run_dir": str(run_dir),
        "passed": 0,
        "failed": 0,
        "total": 0,
        "pass_rate": None,
        "status": "infra_failure",
        "graded": False,
        "failed_expectations": [],
        "infra_failure": message,
        "optimization_findings": [INFRA_FAILURE_FINDING],
    }
