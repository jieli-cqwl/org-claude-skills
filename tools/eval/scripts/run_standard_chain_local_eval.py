#!/usr/bin/env python3
"""Run skill-local evals for standard-chain skills.

This runner turns `shared/skills/<skill>/evals/evals.json` from static examples
into executable evidence. It runs each prompt against the target skill, grades
the response with a structured judge, and summarizes failed expectations so the
skill owner can optimize the wording or workflow.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


@dataclass(frozen=True)
class EvalSelection:
    """Selected skill and case ids for one local eval run."""

    skills: list[str]
    eval_ids: set[str] | None


def write_json(path: Path, payload: object) -> None:
    """Write stable UTF-8 JSON for human review and downstream scripts."""

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load_json(path: Path) -> object:
    """Load one JSON document from disk."""

    return json.loads(path.read_text(encoding="utf-8"))


def run_command(cmd: list[str], cwd: Path, timeout_sec: int | None) -> subprocess.CompletedProcess[str]:
    """Run a subprocess with nested Codex session guards removed."""

    env = {key: value for key, value in os.environ.items() if key != "CLAUDECODE"}
    return subprocess.run(
        cmd,
        cwd=str(cwd),
        text=True,
        capture_output=True,
        timeout=timeout_sec,
        env=env,
        check=False,
    )


def parse_csv(value: str | None) -> list[str]:
    """Parse a comma-separated CLI value into a list."""

    if not value:
        return []
    return [part.strip() for part in value.split(",") if part.strip()]


def parse_selection(args: argparse.Namespace) -> EvalSelection:
    """Convert CLI arguments into a normalized eval selection."""

    skills = parse_csv(args.skills)
    eval_ids = set(parse_csv(args.eval_ids)) or None
    return EvalSelection(skills=skills, eval_ids=eval_ids)


def load_skill_evals(skill_name: str, eval_ids: set[str] | None) -> list[dict]:
    """Load eval cases for one standard-chain skill."""

    eval_path = ROOT / "shared" / "skills" / skill_name / "evals" / "evals.json"
    if not eval_path.is_file():
        raise FileNotFoundError(f"missing evals file: {eval_path}")
    payload = load_json(eval_path)
    if not isinstance(payload, dict) or payload.get("skill_name") != skill_name:
        raise ValueError(f"{eval_path}: skill_name mismatch")
    evals = payload.get("evals")
    if not isinstance(evals, list):
        raise ValueError(f"{eval_path}: evals must be a list")
    if eval_ids is None:
        return evals
    selected = [case for case in evals if str(case.get("id")) in eval_ids]
    missing = eval_ids - {str(case.get("id")) for case in selected}
    if missing:
        raise ValueError(f"{eval_path}: unknown eval ids: {', '.join(sorted(missing))}")
    return selected


def prepare_workspace(skill_name: str, output_dir: Path) -> Path:
    """Create a minimal read-only workspace containing the target skill."""

    workspace = output_dir / "_workspaces" / skill_name
    if workspace.exists():
        shutil.rmtree(workspace)
    skill_source = ROOT / "shared" / "skills" / skill_name
    skill_target = workspace / "shared" / "skills" / skill_name
    skill_target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(skill_source, skill_target)
    ag_path = ROOT / "AGENTS.md"
    if ag_path.is_file():
        shutil.copy2(ag_path, workspace / "AGENTS.md")
    return workspace


def build_executor_prompt(skill_name: str, case: dict) -> str:
    """Build the prompt that executes one eval case against a target skill."""

    return "\n".join(
        [
            f"请按当前工作区 `shared/skills/{skill_name}/SKILL.md` 执行下面的 skill eval。",
            "约束：",
            "- 先读取并遵循该 SKILL.md。",
            "- 不要联网。",
            "- 不要修改文件。",
            "- 回答必须体现该 skill 的流程边界、阻断条件和下一步。",
            "- 如果 prompt 要求产出最终工件但前置条件不足，应按 skill 规则阻断并说明原因。",
            "",
            "Eval prompt:",
            str(case["prompt"]),
            "",
            "Expected outcome:",
            str(case["expected_output"]),
        ]
    )


def run_executor(skill_name: str, case: dict, workspace: Path, run_dir: Path, timeout_sec: int, model: str | None) -> None:
    """Run one eval prompt and persist the raw response."""

    response_path = run_dir / "outputs" / "response.md"
    response_path.parent.mkdir(parents=True, exist_ok=True)
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
        str(workspace),
        "-o",
        str(response_path),
        build_executor_prompt(skill_name, case),
    ]
    if model:
        command[2:2] = ["--model", model]
    started_at = time.time()
    completed = run_command(command, workspace, timeout_sec)
    duration_seconds = time.time() - started_at
    (run_dir / "executor.log").write_text((completed.stdout or "") + (completed.stderr or ""), encoding="utf-8")
    write_json(
        run_dir / "timing.json",
        {
            "executor_start": datetime.fromtimestamp(started_at, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "executor_end": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "total_duration_seconds": round(duration_seconds, 1),
        },
    )
    if completed.returncode != 0:
        raise RuntimeError(f"{skill_name}/{case['id']}: executor exited {completed.returncode}")
    if not response_path.is_file():
        raise RuntimeError(f"{skill_name}/{case['id']}: missing response output")


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


def write_eval_metadata(skill_name: str, case: dict, run_dir: Path) -> None:
    """Persist metadata needed by humans and benchmark viewers."""

    write_json(
        run_dir / "eval_metadata.json",
        {
            "skill_name": skill_name,
            "eval_id": case["id"],
            "prompt": case["prompt"],
            "expected_output": case["expected_output"],
            "assertions": case.get("expectations", []),
        },
    )


def run_case(skill_name: str, case: dict, workspace: Path, run_dir: Path, args: argparse.Namespace) -> dict:
    """Execute and grade one skill-local eval case."""

    write_eval_metadata(skill_name, case, run_dir)
    run_executor(skill_name, case, workspace, run_dir, args.timeout_sec, args.model)
    response_text = (run_dir / "outputs" / "response.md").read_text(encoding="utf-8")
    grading = run_judge(skill_name, case, response_text, run_dir, args.timeout_sec, args.judge_model)
    failed = [item["text"] for item in grading["expectations"] if not item["passed"]]
    return {
        "skill_name": skill_name,
        "eval_id": case["id"],
        "run_dir": str(run_dir),
        "passed": grading["summary"]["passed"],
        "failed": grading["summary"]["failed"],
        "total": grading["summary"]["total"],
        "pass_rate": grading["summary"]["pass_rate"],
        "failed_expectations": failed,
        "optimization_findings": grading.get("optimization_findings", []),
    }


def write_summary(output_dir: Path, runs: list[dict]) -> dict:
    """Write JSON and Markdown summaries focused on failed expectations."""

    total = sum(item["total"] for item in runs)
    failed = sum(item["failed"] for item in runs)
    optimization_findings = [
        finding
        for run in runs
        for finding in run.get("optimization_findings", [])
    ]
    summary = {
        "runs": runs,
        "summary": {
            "total_expectations": total,
            "failed_expectations": failed,
            "pass_rate": round(((total - failed) / total) if total else 0.0, 4),
        },
        "optimization_findings": optimization_findings,
    }
    write_json(output_dir / "summary.json", summary)
    markdown = [
        "# Standard-Chain Local Skill Eval",
        "",
        f"- total expectations: {total}",
        f"- failed expectations: {failed}",
        f"- pass rate: {summary['summary']['pass_rate']:.2f}",
        "",
        "## Runs",
    ]
    for run in runs:
        markdown.append(f"- {run['skill_name']} / {run['eval_id']}: {run['passed']}/{run['total']} passed")
        for expectation in run["failed_expectations"]:
            markdown.append(f"  - failed: {expectation}")
    if optimization_findings:
        markdown.extend(["", "## Optimization Findings"])
        for finding in optimization_findings:
            markdown.append(f"- {finding['issue']} -> {finding['suggested_change']}")
    (output_dir / "summary.md").write_text("\n".join(markdown) + "\n", encoding="utf-8")
    return summary


def run_selected_evals(selection: EvalSelection, args: argparse.Namespace) -> dict:
    """Run all selected skill-local eval cases."""

    args.output_dir.mkdir(parents=True, exist_ok=True)
    runs: list[dict] = []
    for skill_name in selection.skills:
        workspace = prepare_workspace(skill_name, args.output_dir)
        for case in load_skill_evals(skill_name, selection.eval_ids):
            for run_number in range(1, args.runs_per_eval + 1):
                run_dir = args.output_dir / skill_name / str(case["id"]) / f"run-{run_number}"
                runs.append(run_case(skill_name, case, workspace, run_dir, args))
    return write_summary(args.output_dir, runs)


def print_dry_run(selection: EvalSelection) -> None:
    """Print selected eval ids without executing them."""

    for skill_name in selection.skills:
        evals = load_skill_evals(skill_name, selection.eval_ids)
        print(f"{skill_name}: {len(evals)} evals")
        for case in evals:
            print(f"- {case['id']}: {case['prompt']}")


def main() -> None:
    """CLI entrypoint."""

    parser = argparse.ArgumentParser(description="Run standard-chain skill-local evals")
    parser.add_argument("--skills", required=True, help="Comma-separated skill names, e.g. product-director,product-manager")
    parser.add_argument("--eval-ids", default=None, help="Comma-separated eval ids to run")
    parser.add_argument("--runs-per-eval", type=int, default=1)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "tools" / "eval" / "results" / "standard-chain-local")
    parser.add_argument("--timeout-sec", type=int, default=240)
    parser.add_argument("--model", default=None)
    parser.add_argument("--judge-model", default=None)
    parser.add_argument("--allow-failures", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    selection = parse_selection(args)
    if not selection.skills:
        raise SystemExit("--skills must include at least one skill")
    if args.dry_run:
        print_dry_run(selection)
        return

    args.output_dir = args.output_dir.resolve()
    summary = run_selected_evals(selection, args)
    if summary["summary"]["failed_expectations"] and not args.allow_failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
