"""Workspace preparation for Anthropic-style existing skill evals."""

from __future__ import annotations

import io
import re
import shutil
import subprocess
import tarfile
from pathlib import Path

from paths import load_json, repo_root, run_command, write_json


def sanitized_eval_dir(eval_id: object) -> str:
    """Return the official eval directory name for an eval id."""

    safe = re.sub(r"[^A-Za-z0-9_.-]+", "-", str(eval_id)).strip("-")
    return f"eval-{safe}"


def load_evals(config: dict) -> list[dict]:
    """Load the pilot skill eval definitions."""

    evals_path = Path(str(config["evals_path"]))
    payload = load_json(evals_path)
    if not isinstance(payload, dict) or payload.get("skill_name") != config["skill_name"]:
        raise ValueError(f"{evals_path}: skill_name mismatch")
    evals = payload.get("evals")
    if not isinstance(evals, list) or not evals:
        raise ValueError(f"{evals_path}: evals must be a non-empty list")
    return evals


def next_iteration_dir(output_dir: Path) -> Path:
    """Return the reusable or next iteration directory."""

    def iteration_number(path: Path) -> int | None:
        match = re.fullmatch(r"iteration-(\d+)", path.name)
        return int(match.group(1)) if match else None

    existing = [
        (number, path)
        for path in output_dir.glob("iteration-*")
        if (number := iteration_number(path)) is not None
    ]
    existing.sort(key=lambda item: item[0])
    if not existing:
        return output_dir / "iteration-1"
    latest_number, latest = existing[-1]
    if not (latest / "benchmark.json").exists():
        return latest
    return output_dir / f"iteration-{latest_number + 1}"


def _copy_git_archive(root: Path, rel_path: str, target_root: Path) -> bool:
    """Copy a path from HEAD, preserving bytes through subprocess stdout."""

    try:
        process = subprocess.run(
            ["git", "archive", "HEAD", rel_path],
            cwd=str(root),
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=60,
        )
    except subprocess.TimeoutExpired:
        return False
    if process.returncode != 0:
        return False
    target_root.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(process.stdout), mode="r:") as archive:
        archive.extractall(target_root)
    return True


def _copy_tree(source: Path, target: Path) -> None:
    """Replace target with a copy of source."""

    if target.exists():
        shutil.rmtree(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, target)


def create_snapshot(config: dict, iteration_dir: Path) -> Path:
    """Create an old_skill snapshot and record its source."""

    root = repo_root()
    skill_path = Path(str(config["skill_path"]))
    rel_skill = str(skill_path.relative_to(root))
    snapshot_root = iteration_dir / "skill-snapshot"
    snapshot_skill = snapshot_root / rel_skill
    status = run_command(["git", "status", "--porcelain", "--", rel_skill], root, 60)
    if status.returncode != 0:
        raise RuntimeError(status.stderr or status.stdout)
    if status.stdout.strip() and _copy_git_archive(root, rel_skill, snapshot_root):
        source = "git HEAD"
    else:
        _copy_tree(skill_path, snapshot_skill)
        source = "filesystem"
    write_json(
        iteration_dir / "snapshot_metadata.json",
        {
            "skill_name": config["skill_name"],
            "old_skill_source": source,
            "old_skill_path": str(snapshot_skill),
            "new_skill_path": str(skill_path),
        },
    )
    return snapshot_skill


def write_eval_metadata(iteration_dir: Path, eval_case: dict) -> Path:
    """Write eval metadata in locations consumed by official viewer scripts."""

    eval_dir = iteration_dir / sanitized_eval_dir(eval_case["id"])
    payload = {
        "eval_id": eval_case["id"],
        "eval_name": str(eval_case["id"]),
        "prompt": eval_case["prompt"],
        "expected_output": eval_case["expected_output"],
        "files": eval_case.get("files", []),
        "assertions": eval_case.get("expectations", []),
    }
    write_json(eval_dir / "eval_metadata.json", payload)
    for config_name in ("old_skill", "new_skill"):
        write_json(eval_dir / config_name / "eval_metadata.json", payload)
    return eval_dir


def prepare_workspace(config: dict, output_dir: Path) -> tuple[Path, list[dict], Path]:
    """Prepare iteration directory, old snapshot, and eval metadata."""

    evals = load_evals(config)
    output_dir.mkdir(parents=True, exist_ok=True)
    iteration_dir = next_iteration_dir(output_dir)
    iteration_dir.mkdir(parents=True, exist_ok=True)
    snapshot_skill = create_snapshot(config, iteration_dir)
    for eval_case in evals:
        write_eval_metadata(iteration_dir, eval_case)
    return iteration_dir, evals, snapshot_skill
