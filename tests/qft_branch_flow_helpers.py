from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "shared/skills/qft-branch-flow/scripts/qft_branch_flow.py"


def run_flow(
    *args: str, input_payload: dict | None = None
) -> subprocess.CompletedProcess[str]:
    input_path = None
    with tempfile.TemporaryDirectory() as tmp_dir:
        if input_payload is not None:
            input_path = Path(tmp_dir) / "input.json"
            input_path.write_text(
                json.dumps(input_payload, ensure_ascii=False), encoding="utf-8"
            )
        command = ["python3", str(SCRIPT), *args]
        if input_path is not None:
            command.extend(["--input", str(input_path)])
        return subprocess.run(
            command,
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )


def run_preflight(repo_root: Path, plan: dict) -> subprocess.CompletedProcess[str]:
    return run_flow(
        "preflight",
        "--repo-root",
        str(repo_root),
        input_payload=plan,
    )


def run_git(
    cwd: Path, *args: str, check: bool = True
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(cwd), *args],
        text=True,
        capture_output=True,
        check=check,
    )


def configure_git_user(repo: Path) -> None:
    run_git(repo, "config", "user.email", "qft-flow-test@example.com")
    run_git(repo, "config", "user.name", "QFT Flow Test")


def commit_file(repo: Path, name: str, content: str) -> None:
    path = repo / name
    path.write_text(content, encoding="utf-8")
    run_git(repo, "add", name)
    run_git(repo, "commit", "-m", f"update {name}")


def create_remote_repo(root: Path, repo_name: str = "qft-app") -> tuple[Path, Path]:
    origin = root / f"{repo_name}.git"
    seed = root / f"{repo_name}-seed"
    subprocess.run(
        ["git", "init", "--bare", str(origin)], check=True, capture_output=True
    )
    subprocess.run(
        ["git", "init", "-b", "master", str(seed)], check=True, capture_output=True
    )
    configure_git_user(seed)
    commit_file(seed, "README.md", "initial\n")
    run_git(seed, "remote", "add", "origin", str(origin))
    run_git(seed, "push", "-u", "origin", "master")
    return origin, seed


def clone_project(root: Path, origin: Path, repo_name: str = "qft-app") -> Path:
    checkout = root / repo_name
    subprocess.run(
        ["git", "clone", str(origin), str(checkout)],
        text=True,
        capture_output=True,
        check=True,
    )
    configure_git_user(checkout)
    return checkout


def create_dev_plan(target_branch: str = "3.0.0.DEV_ZY_4109_0625") -> dict:
    return {
        "schema_version": "1.0.0",
        "scenario": "create-dev",
        "version": "0625",
        "owner": "ZY",
        "requirement": "4109",
        "delay": False,
        "projects": ["qft-app"],
        "target_branch": target_branch,
        "steps": [
            {
                "repo": "qft-app",
                "source_branch": "master",
                "target_branch": target_branch,
                "action": "create_branch",
            }
        ],
        "push": {"confirmed": False, "branches": []},
    }


def dev_sync_plan(target_branch: str = "3.0.0.DEV_ZY_4109_0625") -> dict:
    return {
        "schema_version": "1.0.0",
        "scenario": "dev-sync",
        "version": "0625",
        "projects": ["qft-app"],
        "business_branches": {"qft-app": target_branch},
        "target_branch": target_branch,
        "steps": [
            {
                "repo": "qft-app",
                "source_branch": "master",
                "target_branch": target_branch,
                "action": "merge",
            }
        ],
        "push": {"confirmed": False, "branches": []},
    }


def release_merge_plan(
    business_branch: str = "3.0.0.DEV_ZY_4109_0625",
    release_branch: str = "V.0625",
) -> dict:
    return {
        "schema_version": "1.0.0",
        "scenario": "release-merge",
        "version": "0625",
        "projects": ["qft-app"],
        "business_branches": {"qft-app": business_branch},
        "target_branch": release_branch,
        "steps": [
            {
                "repo": "qft-app",
                "source_branch": "master",
                "target_branch": release_branch,
                "action": "ensure_branch",
            },
            {
                "repo": "qft-app",
                "source_branch": business_branch,
                "target_branch": release_branch,
                "action": "merge",
            },
        ],
        "push": {"confirmed": False, "branches": []},
    }


def blocker_codes(result: dict) -> set[str]:
    return {blocker["code"] for repo in result["repos"] for blocker in repo["blockers"]}
