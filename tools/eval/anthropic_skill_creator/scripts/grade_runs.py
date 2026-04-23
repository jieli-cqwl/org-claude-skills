"""Generate Anthropic-compatible grading.json files for adapter runs."""

from __future__ import annotations

import json
import tempfile
from pathlib import Path

from paths import apply_codex_runtime_options, run_command, write_json


def judge_schema(expectations: list[str] | None = None) -> dict:
    """Return the structured schema expected from the judge model."""

    text_schema: dict[str, object] = {"type": "string"}
    expectations_schema: dict[str, object] = {
        "type": "array",
        "items": {
            "type": "object",
            "properties": {
                "text": text_schema,
                "passed": {"type": "boolean"},
                "evidence": {"type": "string"},
            },
            "required": ["text", "passed", "evidence"],
            "additionalProperties": False,
        },
    }
    if expectations is not None:
        text_schema["enum"] = expectations
        expectations_schema["minItems"] = len(expectations)
        expectations_schema["maxItems"] = len(expectations)
    return {
        "type": "object",
        "properties": {
            "expectations": expectations_schema,
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
只返回 Expectations 列表中配置的原文，不要从 Expected output 自行新增、改写或拆分 expectation。
必须逐条返回完整 Expectations 列表，不得省略任何一条配置项。

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


def validate_judged_expectations(eval_case: dict, judged: dict) -> list[dict]:
    """Return judge results ordered by configured expectations."""

    configured = [str(item) for item in eval_case.get("expectations", [])]
    if len(configured) != len(set(configured)):
        raise ValueError("duplicate configured expectations")
    raw_expectations = judged["expectations"]
    by_text: dict[str, dict] = {}
    for item in raw_expectations:
        text = str(item["text"])
        if text in by_text:
            raise ValueError(f"duplicate judged expectation: {text}")
        if text not in configured:
            raise ValueError(f"unknown judged expectation: {text}")
        by_text[text] = item
    missing = [text for text in configured if text not in by_text]
    if missing:
        raise ValueError(f"missing judged expectations: {missing}")
    return [by_text[text] for text in configured]


def grade_run(
    skill_name: str,
    eval_case: dict,
    run_dir: Path,
    timeout_sec: int,
    model: str | None,
    reasoning_effort: str | None,
) -> None:
    """Run the judge and write grading.json."""

    response_path = run_dir / "outputs" / "response.md"
    if not response_path.is_file():
        raise FileNotFoundError(f"missing response output: {response_path}")
    response_text = response_path.read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="anthropic-adapter-judge-") as temp_dir:
        temp_path = Path(temp_dir)
        schema_path = temp_path / "schema.json"
        configured_expectations = [str(item) for item in eval_case.get("expectations", [])]
        schema_path.write_text(json.dumps(judge_schema(configured_expectations)), encoding="utf-8")
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
        apply_codex_runtime_options(command, model, reasoning_effort)
        completed = run_command(command, temp_path, timeout_sec)
    (run_dir / "grader.log").write_text((completed.stdout or "") + (completed.stderr or ""), encoding="utf-8")
    if completed.returncode != 0:
        raise RuntimeError(f"judge exited {completed.returncode}")
    judged = json.loads(completed.stdout)
    expectations = validate_judged_expectations(eval_case, judged)
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
