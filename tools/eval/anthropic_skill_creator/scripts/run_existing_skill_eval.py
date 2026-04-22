"""Run Anthropic-style old/new evals for an existing skill."""

from __future__ import annotations

import argparse
import shutil
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

from grade_runs import grade_run
from paths import (
    load_config,
    repo_root,
    run_command,
    validate_official_skill_creator,
    write_json,
    write_process_log,
)
from prepare_workspace import prepare_workspace, sanitized_eval_dir


def is_relative_to(path: Path, root: Path) -> bool:
    """Return whether a resolved path stays within a resolved root."""

    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def resolve_case_file(skill_root: Path, file_ref: str) -> tuple[Path, Path]:
    """Resolve an eval file path under skill root or repo root."""

    rel_ref = Path(file_ref)
    if rel_ref.is_absolute() or any(part == ".." for part in rel_ref.parts):
        raise ValueError(f"eval file must stay within the skill or repo root: {file_ref}")
    root = repo_root()
    skill_root_resolved = skill_root.resolve()
    repo_root_resolved = root.resolve()
    skill_candidate = (skill_root / rel_ref).resolve()
    if skill_candidate.exists():
        if not is_relative_to(skill_candidate, skill_root_resolved):
            raise ValueError(f"eval file escapes skill root: {file_ref}")
        return skill_candidate, rel_ref
    repo_candidate = (root / rel_ref).resolve()
    if repo_candidate.exists():
        if not is_relative_to(repo_candidate, repo_root_resolved):
            raise ValueError(f"eval file escapes repo root: {file_ref}")
        return repo_candidate, rel_ref
    raise FileNotFoundError(f"missing eval input file: {file_ref}")


def validate_copy_source(source: Path, file_ref: str) -> None:
    """Reject symlinks before copying eval-declared input files."""

    if source.is_symlink():
        raise ValueError(f"eval file cannot be a symlink: {file_ref}")
    if source.is_dir():
        for child in source.rglob("*"):
            if child.is_symlink():
                raise ValueError(f"eval file directory contains symlink: {file_ref}")


def copy_case_files(skill_root: Path, eval_case: dict, workspace: Path) -> None:
    """Copy eval-declared files into a run workspace."""

    workspace_root = workspace.resolve()
    for file_ref in eval_case.get("files", []):
        source, rel_target = resolve_case_file(skill_root, str(file_ref))
        validate_copy_source(source, str(file_ref))
        target = (workspace / rel_target).resolve()
        if not is_relative_to(target, workspace_root):
            raise ValueError(f"eval file target escapes workspace: {file_ref}")
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.is_dir():
            if target.exists():
                shutil.rmtree(target)
            shutil.copytree(source, target)
        else:
            shutil.copy2(source, target)


def build_executor_prompt(skill_name: str, eval_case: dict) -> str:
    """Build the prompt used to execute one skill eval."""

    files = eval_case.get("files", [])
    file_lines = [f"- {item}" for item in files] if files else ["- none"]
    return "\n".join(
        [
            f"请按当前工作区 `shared/skills/{skill_name}/SKILL.md` 执行下面的 Anthropic-style skill eval。",
            "约束：",
            "- 先读取并遵循该 SKILL.md。",
            "- 不要联网。",
            "- 只允许在当前临时 eval workspace 内读写本次 eval 产物。",
            "- 如果前置条件不足，应按 skill 规则阻断并说明原因。",
            "",
            "Input files available in the workspace:",
            *file_lines,
            "",
            "Eval prompt:",
            str(eval_case["prompt"]),
        ]
    )


def prepare_run_workspace(source_skill: Path, eval_case: dict) -> Path:
    """Create a temporary workspace containing one skill version."""

    root = repo_root()
    workspace = Path(tempfile.mkdtemp(prefix="anthropic-adapter-run-"))
    try:
        rel_skill = Path("shared") / "skills" / "developer"
        target_skill = workspace / rel_skill
        target_skill.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source_skill, target_skill)
        ag_path = root / "AGENTS.md"
        if ag_path.is_file():
            shutil.copy2(ag_path, workspace / "AGENTS.md")
        copy_case_files(target_skill, eval_case, workspace)
        return workspace
    except Exception:
        shutil.rmtree(workspace, ignore_errors=True)
        raise


def run_executor(source_skill: Path, eval_case: dict, run_dir: Path, timeout_sec: int, model: str | None) -> None:
    """Execute one eval case against one skill version."""

    workspace = prepare_run_workspace(source_skill, eval_case)
    response_path = run_dir / "outputs" / "response.md"
    response_path.parent.mkdir(parents=True, exist_ok=True)
    command = [
        "codex",
        "exec",
        "--ephemeral",
        "--skip-git-repo-check",
        "--sandbox",
        "workspace-write",
        "--color",
        "never",
        "-C",
        str(workspace),
        "-o",
        str(response_path),
        build_executor_prompt("developer", eval_case),
    ]
    if model:
        command[2:2] = ["--model", model]
    started_at = time.time()
    try:
        completed = run_command(command, workspace, timeout_sec)
    finally:
        shutil.rmtree(workspace, ignore_errors=True)
    duration = time.time() - started_at
    (run_dir / "outputs" / "transcript.md").write_text(
        (completed.stdout or "") + (completed.stderr or ""),
        encoding="utf-8",
    )
    (run_dir / "executor.log").write_text((completed.stdout or "") + (completed.stderr or ""), encoding="utf-8")
    write_json(
        run_dir / "timing.json",
        {
            "executor_start": datetime.fromtimestamp(started_at, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "executor_end": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "total_duration_seconds": round(duration, 1),
        },
    )
    if completed.returncode != 0:
        raise RuntimeError(f"executor exited {completed.returncode}")
    if not response_path.is_file():
        raise RuntimeError(f"missing response output: {response_path}")


def run_official_aggregate(config: dict, iteration_dir: Path) -> None:
    """Run official benchmark aggregation and static review generation."""

    official = Path(str(config["official_skill_creator_path"]))
    aggregate = [
        "python3",
        "-m",
        "scripts.aggregate_benchmark",
        str(iteration_dir),
        "--skill-name",
        str(config["skill_name"]),
        "--skill-path",
        str(config["skill_path"]),
    ]
    completed = run_command(aggregate, official, 120)
    aggregate_log = iteration_dir / "aggregate.log"
    write_process_log(aggregate_log, aggregate, official, completed)
    if completed.returncode != 0:
        raise RuntimeError(f"aggregate failed; see {aggregate_log}")
    viewer = [
        "python3",
        str(official / "eval-viewer" / "generate_review.py"),
        str(iteration_dir),
        "--skill-name",
        str(config["skill_name"]),
        "--benchmark",
        str(iteration_dir / "benchmark.json"),
        "--static",
        str(iteration_dir / "review.html"),
    ]
    previous = previous_iteration(iteration_dir)
    if previous is not None:
        viewer.extend(["--previous-workspace", str(previous)])
    completed = run_command(viewer, repo_root(), 120)
    viewer_log = iteration_dir / "viewer.log"
    write_process_log(viewer_log, viewer, repo_root(), completed)
    if completed.returncode != 0:
        raise RuntimeError(f"viewer failed; see {viewer_log}")


def previous_iteration(iteration_dir: Path) -> Path | None:
    """Return the previous iteration directory when it exists."""

    number = int(iteration_dir.name.split("-")[1])
    if number <= 1:
        return None
    candidate = iteration_dir.parent / f"iteration-{number - 1}"
    return candidate if candidate.is_dir() else None


def run_eval_loop(config: dict, output_dir: Path, model: str | None, judge_model: str | None, dry_run: bool) -> Path:
    """Prepare and optionally execute the existing-skill eval loop."""

    validate_official_skill_creator(Path(str(config["official_skill_creator_path"])))
    iteration_dir, evals, snapshot_skill = prepare_workspace(config, output_dir)
    print(f"skill_name={config['skill_name']}")
    print(f"iteration_dir={iteration_dir}")
    print(f"official_skill_creator={config['official_skill_creator_path']}")
    if dry_run:
        return iteration_dir
    sources = {
        "old_skill": snapshot_skill,
        "new_skill": Path(str(config["skill_path"])),
    }
    for eval_case in evals:
        eval_dir = iteration_dir / sanitized_eval_dir(eval_case["id"])
        for config_name, source_skill in sources.items():
            run_dir = eval_dir / config_name / "run-1"
            run_executor(source_skill, eval_case, run_dir, int(config["executor_timeout_sec"]), model)
            grade_run("developer", eval_case, run_dir, int(config["judge_timeout_sec"]), judge_model)
    run_official_aggregate(config, iteration_dir)
    return iteration_dir


def main() -> None:
    """CLI entrypoint."""

    parser = argparse.ArgumentParser(description="Run developer Anthropic-style eval loop")
    parser.add_argument("--config", required=True)
    parser.add_argument("--output-dir", default=None)
    parser.add_argument("--model", default=None)
    parser.add_argument("--judge-model", default=None)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    config = load_config(Path(args.config))
    output_dir = Path(args.output_dir) if args.output_dir else Path(str(config["default_output_dir"]))
    run_eval_loop(config, output_dir.resolve(), args.model, args.judge_model, args.dry_run)


if __name__ == "__main__":
    main()
