#!/usr/bin/env python3
"""Core helpers for the product split benchmark."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import tempfile
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SKILL_CREATOR = Path.home() / ".codex" / "skills" / "skill-creator"
AGGREGATE_SCRIPT = SKILL_CREATOR / "scripts" / "aggregate_benchmark.py"
REVIEW_SCRIPT = SKILL_CREATOR / "eval-viewer" / "generate_review.py"
DEFAULT_EVAL_SET = ROOT / "tools" / "eval" / "scenarios" / "product-split-benchmark-evals.json"
DEFAULT_OUTPUT = ROOT / "tools" / "eval" / "results" / "product-split-benchmark-20260415" / "iteration-1"
OLD_COMMIT = "f548a32"


@dataclass(frozen=True)
class BenchmarkConfig:
    """Describe one benchmark configuration and its display label."""

    bench_name: str
    display_name: str


CONFIGS = (
    BenchmarkConfig("with_skill", "with_split"),
    BenchmarkConfig("without_skill", "old_monolith"),
)


def run_command(cmd: list[str], cwd: Path | None = None, timeout_sec: int | None = None) -> subprocess.CompletedProcess[str]:
    """Run a subprocess with a nested-Codex-safe environment."""

    env = {key: value for key, value in os.environ.items() if key != "CLAUDECODE"}
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        text=True,
        capture_output=True,
        timeout=timeout_sec,
        env=env,
        check=False,
    )


def write_json(path: Path, payload: object) -> None:
    """Write JSON with stable formatting."""

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")


def load_json(path: Path) -> object:
    """Load JSON from disk."""

    return json.loads(path.read_text())


def ensure_clean_dir(path: Path) -> None:
    """Recreate a generated directory from scratch."""

    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def copy_current_path(relative_path: str, workspace: Path) -> None:
    """Copy one current repo path into the benchmark workspace."""

    source = ROOT / relative_path
    if not source.exists():
        return
    target = workspace / relative_path
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        shutil.copytree(source, target, dirs_exist_ok=True)
        return
    shutil.copy2(source, target)


def export_old_paths(workspace: Path, paths: list[str]) -> None:
    """Export historical paths from the old monolith commit."""

    archive = run_command(["git", "archive", "--format=tar", OLD_COMMIT, *paths], cwd=ROOT)
    if archive.returncode != 0:
        raise RuntimeError(archive.stderr.strip() or "git archive failed")
    extract = subprocess.run(["tar", "-x", "-C", str(workspace)], input=archive.stdout.encode(), capture_output=True, check=False)
    if extract.returncode != 0:
        raise RuntimeError(extract.stderr.decode().strip() or "tar extract failed")


def prepare_workspaces(output_dir: Path) -> dict[str, Path]:
    """Create isolated read-only workspaces for split and old monolith."""

    workspace_root = output_dir / "workspaces"
    ensure_clean_dir(workspace_root)
    split_workspace = workspace_root / "with_split"
    monolith_workspace = workspace_root / "old_monolith"
    split_workspace.mkdir(parents=True, exist_ok=True)
    monolith_workspace.mkdir(parents=True, exist_ok=True)

    for relative_path in [
        "AGENTS.md",
        "shared/skills/product-director",
        "shared/skills/product-manager",
    ]:
        copy_current_path(relative_path, split_workspace)

    copy_current_path("AGENTS.md", monolith_workspace)
    export_old_paths(monolith_workspace, ["shared/skills/product"])
    return {"with_skill": split_workspace, "without_skill": monolith_workspace}


def benchmark_prompt(user_prompt: str) -> str:
    """Wrap the user prompt with benchmark constraints."""

    return "\n".join(
        [
            "请只依据当前工作区中的 skill / playbook 文档回答下面的问题。",
            "- 不要联网",
            "- 不要修改文件",
            "- 默认回答控制在 180-220 字；如果问题明确在问规则清单或显式保留项，可以展开到 320-380 字",
            "- 如果工作区里没有对应 skill，就按现有文档如实回答",
            "",
            user_prompt,
        ]
    )


def extract_evidence(text: str, pattern: str) -> str:
    """Return a short evidence snippet for a matched expectation."""

    match = re.search(pattern, text, flags=re.IGNORECASE | re.MULTILINE | re.DOTALL)
    if not match:
        return "未找到匹配片段"
    start = max(match.start() - 30, 0)
    end = min(match.end() + 30, len(text))
    return text[start:end].replace("\n", " ").strip()[:180]


def grade_run(eval_item: dict, response_text: str, run_dir: Path, duration_seconds: float, return_code: int) -> None:
    """Emit a skill-creator-compatible keyword-smoke grading.json for one run."""

    expectations = []
    passed = 0
    for expectation in eval_item["expectations"]:
        pattern = expectation["pattern"]
        is_pass = bool(re.search(pattern, response_text, flags=re.IGNORECASE | re.MULTILINE | re.DOTALL))
        passed += int(is_pass)
        expectations.append({"text": expectation["text"], "passed": is_pass, "evidence": extract_evidence(response_text, pattern)})
    total = len(expectations)
    grading = {
        "grading_mode": "outcome_rubric_plus_keyword_smoke",
        "rubric_type": eval_item.get("rubric_type", "keyword_smoke"),
        "outcome_rubric": eval_item.get("outcome_rubric", []),
        "expectations": expectations,
        "summary": {"passed": passed, "failed": total - passed, "total": total, "pass_rate": round((passed / total) if total else 0.0, 4)},
        "execution_metrics": {"total_tool_calls": 0, "errors_encountered": 0 if return_code == 0 else 1, "output_chars": len(response_text)},
        "timing": {"total_duration_seconds": round(duration_seconds, 1)},
        "user_notes_summary": {"uncertainties": [], "needs_review": [], "workarounds": []},
    }
    write_json(run_dir / "grading.json", grading)


def run_executor(eval_item: dict, config: BenchmarkConfig, workspace: Path, run_dir: Path, model: str | None, timeout_sec: int) -> None:
    """Execute one benchmark run in an isolated workspace."""

    response_path = run_dir / "outputs" / "response.md"
    for attempt in (1, 2):
        outputs_dir = run_dir / "outputs"
        outputs_dir.mkdir(parents=True, exist_ok=True)
        write_json(
            run_dir / "eval_metadata.json",
            {
                "eval_id": eval_item["id"],
                "eval_name": eval_item["name"],
                "prompt": eval_item["prompt"],
                "expected_output": eval_item["expected_output"],
                "configuration": config.display_name,
            },
        )
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
            benchmark_prompt(eval_item["prompt"]),
        ]
        if model:
            command[2:2] = ["--model", model]
        started_at = time.time()
        completed = run_command(command, timeout_sec=timeout_sec)
        duration_seconds = time.time() - started_at
        run_dir.mkdir(parents=True, exist_ok=True)
        outputs_dir.mkdir(parents=True, exist_ok=True)
        (run_dir / "executor.log").write_text((completed.stdout or "") + (completed.stderr or ""))
        write_json(
            run_dir / "timing.json",
            {
                "executor_start": datetime.fromtimestamp(started_at, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "executor_end": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "total_duration_seconds": round(duration_seconds, 1),
                "attempt": attempt,
            },
        )
        if response_path.exists():
            grade_run(eval_item, response_path.read_text(), run_dir, duration_seconds, completed.returncode)
            return
    raise RuntimeError(f"missing response output after retry: {response_path}")


def median_representative_run(run_dirs: list[Path]) -> Path:
    """Choose the median scoring run instead of the best run."""

    ranked = []
    for run_dir in run_dirs:
        grading = load_json(run_dir / "grading.json")
        response_path = run_dir / "outputs" / "response.md"
        run_number = int(run_dir.name.split("-")[1])
        ranked.append((grading["summary"]["pass_rate"], grading["summary"]["passed"], run_number, response_path))
    ranked.sort()
    return ranked[len(ranked) // 2][3]


def representative_run(run_dirs: list[Path]) -> Path:
    """Backward-compatible wrapper for callers that still import the old name."""

    return median_representative_run(run_dirs)


def blind_order_for_eval(eval_id: int) -> tuple[str, str]:
    """Alternate A/B assignment so blind comparison does not assume A is split."""

    if eval_id % 2 == 0:
        return ("with_skill", "without_skill")
    return ("without_skill", "with_skill")


def run_structured_judge(prompt: str, output_path: Path, log_path: Path, model: str | None) -> dict:
    """Run a structured Codex judge with a temporary schema."""

    schema = {
        "type": "object",
        "properties": {
            "winner": {"type": "string", "enum": ["A", "B", "Tie"]},
            "reasoning": {"type": "string"},
            "strengths": {"type": "object", "properties": {"A": {"type": "array", "items": {"type": "string"}}, "B": {"type": "array", "items": {"type": "string"}}}, "required": ["A", "B"], "additionalProperties": False},
            "weaknesses": {"type": "object", "properties": {"A": {"type": "array", "items": {"type": "string"}}, "B": {"type": "array", "items": {"type": "string"}}}, "required": ["A", "B"], "additionalProperties": False},
        },
        "required": ["winner", "reasoning", "strengths", "weaknesses"],
        "additionalProperties": False,
    }
    with tempfile.TemporaryDirectory(prefix="product-split-benchmark-judge-") as temp_dir:
        schema_path = Path(temp_dir) / "schema.json"
        schema_path.write_text(json.dumps(schema))
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
            temp_dir,
            "--output-schema",
            str(schema_path),
            prompt,
        ]
        if model:
            command[2:2] = ["--model", model]
        result = run_command(command, timeout_sec=240)
    log_path.write_text((result.stdout or "") + (result.stderr or ""))
    output_path.write_text(result.stdout)
    return json.loads(result.stdout)


def compare_outputs(eval_item: dict, text_a: str, text_b: str, blind_order: dict[str, str], output_path: Path, log_path: Path, model: str | None) -> dict:
    """Blind-compare one split output against one monolith output."""

    prompt = f"""
你是盲评比较器。下面有同一个用户问题的两个候选回答，分别记为 A 和 B。
不要猜测版本来源，也不要奖励新名词。只按回答质量判断谁更好。

优先比较这 4 件事：
1. 是否真正回答了用户问题
2. 是否区分已确认事实、待确认问题和下游执行内容
3. 是否避免方案锚定和无依据承诺
4. 是否给出清晰下一步和风险边界

用户问题：
{eval_item["prompt"]}

输出 A：
{text_a}

输出 B：
{text_b}
""".strip()
    result = run_structured_judge(prompt, output_path, log_path, model)
    result["blind_order"] = blind_order
    write_json(output_path, result)
    return result


def aggregate_benchmark(output_dir: Path) -> None:
    """Aggregate all run-level grading files into benchmark.json / benchmark.md."""

    aggregate = run_command(
        ["python3", str(AGGREGATE_SCRIPT), str(output_dir), "--skill-name", "product-split-best-practice", "--skill-path", str(ROOT / "shared" / "skills")],
        cwd=ROOT,
        timeout_sec=120,
    )
    if aggregate.returncode != 0:
        raise RuntimeError(aggregate.stderr.strip() or aggregate.stdout.strip() or "aggregate benchmark failed")


def enrich_benchmark(benchmark_path: Path, eval_items: list[dict], comparisons: dict[int, dict], model: str | None, judge_model: str | None) -> dict:
    """Attach eval names, labels and notes to benchmark.json."""

    benchmark = load_json(benchmark_path)
    eval_names = {item["id"]: item["name"] for item in eval_items}
    labels = {config.bench_name: config.display_name for config in CONFIGS}
    notes = []
    winner_counts = {"with_split": 0, "old_monolith": 0, "tie": 0}
    for run in benchmark["runs"]:
        run["eval_name"] = eval_names.get(run["eval_id"], f"eval-{run['eval_id']}")
    for eval_item in eval_items:
        compare = comparisons[eval_item["id"]]
        winner = compare["winner"]
        mapped = compare["blind_order"].get(winner, "tie")
        winner_counts[mapped] += 1
        notes.append(f"{eval_item['name']}: blind comparison winner = {mapped}; {compare['reasoning']}")
    benchmark["metadata"]["skill_name"] = "product-split-best-practice"
    benchmark["metadata"]["skill_path"] = str(ROOT / "shared" / "skills")
    benchmark["metadata"]["executor_model"] = model or "default"
    benchmark["metadata"]["analyzer_model"] = judge_model or "default"
    benchmark["metadata"]["configuration_labels"] = labels
    benchmark["notes"] = notes
    write_json(benchmark_path, benchmark)
    return {"winner_counts": winner_counts, "notes": notes}


def write_benchmark_markdown(benchmark_path: Path) -> None:
    """Render a concise markdown summary after benchmark enrichment."""

    benchmark = load_json(benchmark_path)
    summary = benchmark["run_summary"]
    labels = benchmark["metadata"]["configuration_labels"]
    with_skill = summary["with_skill"]["pass_rate"]
    without_skill = summary["without_skill"]["pass_rate"]
    markdown = "\n".join(
        [
            "# Product Split Benchmark",
            "",
            f"- `with_skill` = `{labels['with_skill']}`",
            f"- `without_skill` = `{labels['without_skill']}`",
            f"- evals: {len(benchmark['metadata']['evals_run'])}",
            f"- runs per configuration: {benchmark['metadata']['runs_per_configuration']}",
            "",
            "## Summary",
            "",
            f"- with_split pass rate: {with_skill['mean']:.2f} ± {with_skill['stddev']:.2f}",
            f"- old_monolith pass rate: {without_skill['mean']:.2f} ± {without_skill['stddev']:.2f}",
            f"- delta: {summary['delta']['pass_rate']}",
            "",
            "## Notes",
            "",
            *[f"- {note}" for note in benchmark["notes"]],
        ]
    )
    benchmark_path.with_suffix(".md").write_text(markdown + "\n")


def generate_review(output_dir: Path, benchmark_path: Path) -> None:
    """Generate a static skill-creator review page for human inspection."""

    completed = run_command(
        ["python3", str(REVIEW_SCRIPT), str(output_dir), "--skill-name", "product-split-best-practice", "--benchmark", str(benchmark_path), "--static", str(output_dir / "review.html")],
        cwd=ROOT,
        timeout_sec=120,
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or completed.stdout.strip() or "generate_review failed")
