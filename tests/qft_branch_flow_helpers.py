from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "shared/skills/qft-branch-flow/scripts/qft_branch_flow.py"


def run_flow(
    *args: str, input_payload: dict | None = None, cwd: Path = ROOT
) -> subprocess.CompletedProcess[str]:
    input_path = None
    with tempfile.TemporaryDirectory() as tmp_dir:
        if input_payload is not None:
            input_path = Path(tmp_dir) / "input.json"
            input_path.write_text(
                json.dumps(input_payload, ensure_ascii=False), encoding="utf-8"
            )
        command = [sys.executable, str(SCRIPT), *args]
        if input_path is not None:
            command.extend(["--input", str(input_path)])
        env = os.environ.copy()
        registry_override = find_registry_override(cwd)
        if registry_override is not None:
            env["QFT_BRANCH_FLOW_PROJECT_REGISTRY"] = str(registry_override)
        return subprocess.run(
            command,
            cwd=cwd,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )


def find_registry_override(cwd: Path) -> Path | None:
    current = cwd.resolve()
    for candidate in [current, *current.parents]:
        registry = candidate / "project-registry.json"
        if registry.exists():
            return registry
    return None


def run_preflight(
    repo_root: Path, plan: dict, repo_root_arg: str | None = None
) -> subprocess.CompletedProcess[str]:
    args = ["preflight"]
    if repo_root_arg is not None:
        args.extend(["--repo-root", repo_root_arg])
    return run_flow(*args, input_payload=plan, cwd=repo_root)


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
    write_project_registry(root, (repo_name, origin))
    return origin, seed


def write_project_registry(root: Path, *origins: tuple[str, Path]) -> None:
    registry_path = (
        ROOT
        / "shared"
        / "skills"
        / "qft-branch-flow"
        / "references"
        / "project-registry.json"
    )
    override_path = root / "project-registry.json"
    source = override_path if override_path.exists() else registry_path
    data = json.loads(source.read_text(encoding="utf-8"))
    remotes = {repo: str(origin) for repo, origin in origins}
    for item in data["projects"]:
        repo = item["repo"]
        if repo in remotes:
            item["remote_url"] = remotes[repo]
    (root / "project-registry.json").write_text(
        json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
    )


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
                "action": "ensure_branch",
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


def bugfix_plan(release_version: str = "0528", bug_version: str = "0602") -> dict:
    bug_branch = f"3.0.0.MASTER_BUG_{bug_version}"
    return {
        "schema_version": "1.0.0",
        "scenario": "bugfix",
        "version": release_version,
        "bug_version": bug_version,
        "projects": ["qft-app"],
        "target_branch": bug_branch,
        "steps": [
            {
                "repo": "qft-app",
                "source_branch": f"V.{release_version}",
                "target_branch": bug_branch,
                "action": "ensure_branch",
            }
        ],
        "push": {"confirmed": False, "branches": []},
    }


def blocker_codes(result: dict) -> set[str]:
    return {blocker["code"] for repo in result["repos"] for blocker in repo["blockers"]}
