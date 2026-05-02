#!/usr/bin/env python3
"""Core helpers for the product split benchmark."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SKILL_CREATOR = Path.home() / ".codex" / "skills" / "skill-creator"
AGGREGATE_SCRIPT = SKILL_CREATOR / "scripts" / "aggregate_benchmark.py"
DEFAULT_EVAL_SET = (
    ROOT / "tools" / "eval" / "scenarios" / "product-split-benchmark-evals.json"
)
DEFAULT_OUTPUT = (
    ROOT
    / "tools"
    / "eval"
    / "results"
    / "product-split-benchmark-20260415"
    / "iteration-1"
)
OLD_COMMIT = "f548a32"
SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))


@dataclass(frozen=True)
class BenchmarkConfig:
    """Describe one benchmark configuration and its display label."""

    bench_name: str
    display_name: str


CONFIGS = (
    BenchmarkConfig("with_skill", "with_split"),
    BenchmarkConfig("without_skill", "old_monolith"),
)


def grade_run(
    eval_item: dict,
    response_text: str,
    run_dir: Path,
    duration_seconds: float,
    returncode: int,
) -> None:
    """Grade one benchmark run."""

    from product_split_benchmark_scoring import grade_run as scoring_grade_run

    scoring_grade_run(eval_item, response_text, run_dir, duration_seconds, returncode)


def run_command(
    cmd: list[str], cwd: Path | None = None, timeout_sec: int | None = None
) -> subprocess.CompletedProcess[str]:
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

    archive = run_command(
        ["git", "archive", "--format=tar", OLD_COMMIT, *paths], cwd=ROOT
    )
    if archive.returncode != 0:
        raise RuntimeError(archive.stderr.strip() or "git archive failed")
    extract = subprocess.run(
        ["tar", "-x", "-C", str(workspace)],
        input=archive.stdout.encode(),
        capture_output=True,
        check=False,
    )
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


def run_executor(
    eval_item: dict,
    config: BenchmarkConfig,
    workspace: Path,
    run_dir: Path,
    model: str | None,
    timeout_sec: int,
) -> None:
    """Execute one benchmark run in an isolated workspace."""

    response_path = run_dir / "outputs" / "response.md"
    last_error = ""
    for attempt in (1, 2):
        outputs_dir = run_dir / "outputs"
        outputs_dir.mkdir(parents=True, exist_ok=True)
        if response_path.exists():
            response_path.unlink()
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
        (run_dir / "executor.log").write_text(
            (completed.stdout or "") + (completed.stderr or "")
        )
        write_json(
            run_dir / "timing.json",
            {
                "executor_start": datetime.fromtimestamp(
                    started_at, timezone.utc
                ).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "executor_end": datetime.now(timezone.utc).strftime(
                    "%Y-%m-%dT%H:%M:%SZ"
                ),
                "total_duration_seconds": round(duration_seconds, 1),
                "attempt": attempt,
            },
        )
        if completed.returncode != 0:
            last_error = f"executor exited {completed.returncode} on attempt {attempt}"
            continue
        if response_path.exists():
            grade_run(
                eval_item,
                response_path.read_text(),
                run_dir,
                duration_seconds,
                completed.returncode,
            )
            return
        last_error = f"missing response output on attempt {attempt}: {response_path}"
    raise RuntimeError(
        last_error or f"missing response output after retry: {response_path}"
    )


def median_representative_run(run_dirs: list[Path]) -> Path:
    """Choose the median scoring run instead of the best run."""

    ranked = []
    for run_dir in run_dirs:
        grading = load_json(run_dir / "grading.json")
        response_path = run_dir / "outputs" / "response.md"
        run_number = int(run_dir.name.split("-")[1])
        ranked.append(
            (
                grading["summary"]["pass_rate"],
                grading["summary"]["passed"],
                run_number,
                response_path,
            )
        )
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


def aggregate_benchmark(output_dir: Path) -> None:
    """Aggregate all run-level grading files into benchmark.json / benchmark.md."""

    aggregate = run_command(
        [
            "python3",
            str(AGGREGATE_SCRIPT),
            str(output_dir),
            "--skill-name",
            "product-split-best-practice",
            "--skill-path",
            str(ROOT / "shared" / "skills"),
        ],
        cwd=ROOT,
        timeout_sec=120,
    )
    if aggregate.returncode != 0:
        raise RuntimeError(
            aggregate.stderr.strip()
            or aggregate.stdout.strip()
            or "aggregate benchmark failed"
        )


def enrich_benchmark(
    benchmark_path: Path,
    eval_items: list[dict],
    comparisons: dict[int, dict],
    model: str | None,
    judge_model: str | None,
) -> dict:
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
        notes.append(
            f"{eval_item['name']}: blind comparison winner = {mapped}; {compare['reasoning']}"
        )
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
