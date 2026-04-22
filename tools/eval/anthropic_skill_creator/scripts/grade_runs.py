"""Generate Anthropic-compatible grading.json files for adapter runs."""

from __future__ import annotations

import json
import tempfile
from pathlib import Path

from paths import run_command, write_json


def judge_schema() -> dict:
    """Return the structured schema expected from the judge model."""

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


def build_judge_prompt(skill_name: str, eval_case: dict, response_text: str) -> str:
    """Build the strict judge prompt for one run."""

    expectations = "\n".join(f"- {item}" for item in eval_case.get("expectations", []))
    return f"""
你是 Anthropic skill-creator 兼容 grader。只根据实际输出判断 expectation。
不要因为回答提到关键词就通过；必须有清晰行为、阻断条件或证据。

Skill: {skill_name}
Eval id: {eval_case["id"]}

Prompt:
{eval_case["prompt"]}

Expected output:
{eval_case["expected_output"]}

Expectations:
{expectations}

Actual output:
{response_text}
""".strip()


def grade_run(skill_name: str, eval_case: dict, run_dir: Path, timeout_sec: int, model: str | None) -> None:
    """Run the judge and write grading.json."""

    response_path = run_dir / "outputs" / "response.md"
    if not response_path.is_file():
        raise FileNotFoundError(f"missing response output: {response_path}")
    response_text = response_path.read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="anthropic-adapter-judge-") as temp_dir:
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
            build_judge_prompt(skill_name, eval_case, response_text),
        ]
        if model:
            command[2:2] = ["--model", model]
        completed = run_command(command, temp_path, timeout_sec)
    (run_dir / "grader.log").write_text((completed.stdout or "") + (completed.stderr or ""), encoding="utf-8")
    if completed.returncode != 0:
        raise RuntimeError(f"judge exited {completed.returncode}")
    judged = json.loads(completed.stdout)
    expectations = judged["expectations"]
    passed = sum(1 for item in expectations if item["passed"])
    total = len(expectations)
    write_json(
        run_dir / "grading.json",
        {
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
        },
    )
