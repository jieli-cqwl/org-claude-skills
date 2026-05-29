from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path
from types import ModuleType
from typing import Any
from urllib.parse import urlparse


def load_shared() -> ModuleType:
    module_path = Path(__file__).resolve().with_name("qft_branch_flow_shared.py")
    spec = importlib.util.spec_from_file_location("qft_branch_flow_shared", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"failed to load {module_path}")
    if spec.name in sys.modules:
        return sys.modules[spec.name]
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


shared = load_shared()
load_projects = shared.load_projects

OK = "ok"
BLOCKED = "blocked"
UNKNOWN = "unknown"


def preflight_plan(
    plan: dict[str, Any], repo_root: str | None = None
) -> dict[str, Any]:
    registry = load_projects()
    root = Path(repo_root or ".").resolve()
    repos = []
    for repo in plan["projects"]:
        steps = [step for step in plan["steps"] if step["repo"] == repo]
        repos.append(preflight_repo(repo, root / repo, registry[repo], steps))
    status = BLOCKED if any(item["status"] == BLOCKED for item in repos) else OK
    return {"schema_version": "1.0.0", "status": status, "repos": repos}


def preflight_repo(
    repo: str,
    repo_path: Path,
    registry_item: dict[str, str],
    steps: list[dict[str, str]],
) -> dict[str, Any]:
    blockers: list[dict[str, str]] = []
    checks: list[dict[str, Any]] = []
    if not repo_path.exists():
        return repo_result(
            repo,
            repo_path,
            [blocker("repo_missing", f"repo directory not found: {repo_path}")],
            checks,
        )
    if not is_git_repo(repo_path):
        return repo_result(
            repo,
            repo_path,
            [blocker("not_git_repo", f"not a git repository: {repo_path}")],
            checks,
        )

    blockers.extend(check_worktree(repo_path))
    blockers.extend(check_remote(repo_path, registry_item["remote_url"]))
    planned_branches: set[str] = set()
    for index, step in enumerate(steps, start=1):
        check = preflight_step(repo_path, index, step, planned_branches)
        checks.append(check)
        blockers.extend(check["blockers"])
        if not check["blockers"] and step["action"] in {
            "create_branch",
            "ensure_branch",
        }:
            planned_branches.add(step["target_branch"])
    return repo_result(repo, repo_path, blockers, checks)


def check_worktree(repo_path: Path) -> list[dict[str, str]]:
    result = git_output(repo_path, "status", "--porcelain")
    if result.returncode != 0:
        return [blocker("git_status_failed", clean_error(result))]
    if result.stdout.strip():
        return [blocker("worktree_dirty", "worktree has uncommitted changes")]
    return []


def check_remote(repo_path: Path, expected: str) -> list[dict[str, str]]:
    result = git_output(repo_path, "remote", "get-url", "origin")
    if result.returncode != 0:
        return [blocker("remote_missing", clean_error(result))]
    actual = result.stdout.strip()
    if remote_matches(actual, expected):
        return []
    return [blocker("remote_mismatch", f"origin is {actual}, expected {expected}")]


def is_git_repo(repo_path: Path) -> bool:
    result = git_output(repo_path, "rev-parse", "--is-inside-work-tree")
    return result.returncode == 0 and result.stdout.strip() == "true"


def preflight_step(
    repo_path: Path,
    index: int,
    step: dict[str, str],
    planned_branches: set[str],
) -> dict[str, Any]:
    source = branch_state(repo_path, step["source_branch"])
    target = branch_state(repo_path, step["target_branch"])
    target_planned = step["target_branch"] in planned_branches
    blockers = action_blockers(step["action"], source, target, target_planned)
    return {
        "index": index,
        "action": step["action"],
        "source_branch": step["source_branch"],
        "target_branch": step["target_branch"],
        "target_planned": target_planned,
        "status": BLOCKED if blockers else OK,
        "source": source,
        "target": target,
        "blockers": blockers,
    }


def action_blockers(
    action: str,
    source: dict[str, Any],
    target: dict[str, Any],
    target_planned: bool,
) -> list[dict[str, str]]:
    if action == "create_branch":
        return create_branch_blockers(source, target)
    if action == "ensure_branch":
        return ensure_branch_blockers(source, target)
    if action == "merge":
        return merge_blockers(source, target, target_planned)
    return [blocker("unknown_action", f"unsupported action: {action}")]


def create_branch_blockers(
    source: dict[str, Any], target: dict[str, Any]
) -> list[dict[str, str]]:
    blockers = remote_check_blockers(source, "source")
    blockers.extend(remote_check_blockers(target, "target"))
    blockers.extend(require_existing_branch(source, "source"))
    blockers.extend(require_current_branch(source, "source"))
    if branch_exists(target):
        blockers.append(
            blocker("target_exists", f"target branch exists: {target['name']}")
        )
    blockers.extend(case_conflict_blockers(target, "target"))
    return blockers


def ensure_branch_blockers(
    source: dict[str, Any], target: dict[str, Any]
) -> list[dict[str, str]]:
    blockers = remote_check_blockers(target, "target")
    blockers.extend(case_conflict_blockers(target, "target"))
    if branch_exists(target):
        blockers.extend(require_current_branch(target, "target"))
        return blockers
    blockers.extend(remote_check_blockers(source, "source"))
    blockers.extend(require_existing_branch(source, "source"))
    blockers.extend(require_current_branch(source, "source"))
    return blockers


def merge_blockers(
    source: dict[str, Any], target: dict[str, Any], target_planned: bool
) -> list[dict[str, str]]:
    blockers = remote_check_blockers(source, "source")
    blockers.extend(require_existing_branch(source, "source"))
    blockers.extend(case_conflict_blockers(source, "source"))
    blockers.extend(require_current_branch(source, "source"))
    if target_planned:
        return blockers
    blockers.extend(remote_check_blockers(target, "target"))
    blockers.extend(require_existing_branch(target, "target"))
    blockers.extend(case_conflict_blockers(target, "target"))
    blockers.extend(require_current_branch(target, "target"))
    return blockers


def branch_exists(state: dict[str, Any]) -> bool:
    return bool(state["local_sha"] or state["remote_sha"])


def remote_check_blockers(state: dict[str, Any], role: str) -> list[dict[str, str]]:
    if state["remote_error"]:
        return [
            blocker(
                f"{role}_remote_check_failed",
                f"failed to check origin branch {state['name']}: {state['remote_error']}",
            )
        ]
    return []


def require_existing_branch(state: dict[str, Any], role: str) -> list[dict[str, str]]:
    if branch_exists(state):
        return []
    return [blocker(f"{role}_missing", f"{role} branch not found: {state['name']}")]


def require_current_branch(state: dict[str, Any], role: str) -> list[dict[str, str]]:
    if not state["local_sha"] or not state["remote_sha"]:
        return []
    if state["local_sha"] == state["remote_sha"]:
        return []
    if state["behind"] != UNKNOWN and state["behind"] > 0:
        return [
            blocker(
                f"{role}_behind_remote",
                f"{role} branch {state['name']} is behind origin by {state['behind']} commits",
            )
        ]
    return [
        blocker(
            f"{role}_differs_remote",
            f"{role} branch {state['name']} differs from origin/{state['name']}",
        )
    ]


def case_conflict_blockers(state: dict[str, Any], role: str) -> list[dict[str, str]]:
    conflicts = [item for item in state["case_conflicts"] if item != state["name"]]
    if not conflicts:
        return []
    return [
        blocker(
            f"{role}_case_conflict",
            f"{role} branch {state['name']} conflicts with case variants: {', '.join(conflicts)}",
        )
    ]


def branch_state(repo_path: Path, branch: str) -> dict[str, Any]:
    local_sha = local_branch_sha(repo_path, branch)
    exact_remote = remote_heads(repo_path, f"refs/heads/{branch}")
    all_remote = remote_heads(repo_path, None)
    remote_sha = exact_remote["heads"].get(branch)
    ahead, behind = compare_local_remote(repo_path, local_sha, remote_sha)
    return {
        "name": branch,
        "local_sha": local_sha,
        "remote_sha": remote_sha,
        "remote_error": exact_remote["error"] or all_remote["error"],
        "remote_refs": sorted(exact_remote["heads"]),
        "case_conflicts": casefold_matches(all_remote["heads"], branch),
        "ahead": ahead,
        "behind": behind,
    }


def local_branch_sha(repo_path: Path, branch: str) -> str | None:
    result = git_output(
        repo_path, "show-ref", "--hash", "--verify", f"refs/heads/{branch}"
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def remote_heads(repo_path: Path, pattern: str | None) -> dict[str, Any]:
    args = ["ls-remote", "--heads", "origin"]
    if pattern is not None:
        args.append(pattern)
    result = git_output(repo_path, *args)
    if result.returncode != 0:
        return {"heads": {}, "error": clean_error(result)}
    return {"heads": parse_remote_heads(result.stdout), "error": ""}


def compare_local_remote(
    repo_path: Path, local_sha: str | None, remote_sha: str | None
) -> tuple[int | str, int | str]:
    if not local_sha or not remote_sha or local_sha == remote_sha:
        return 0, 0
    result = git_output(
        repo_path, "rev-list", "--left-right", "--count", f"{local_sha}...{remote_sha}"
    )
    if result.returncode != 0:
        return UNKNOWN, UNKNOWN
    ahead_raw, behind_raw = result.stdout.strip().split()
    return int(ahead_raw), int(behind_raw)


def parse_remote_heads(raw: str) -> dict[str, str]:
    heads: dict[str, str] = {}
    for line in raw.splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        prefix = "refs/heads/"
        if parts[1].startswith(prefix):
            heads[parts[1][len(prefix) :]] = parts[0]
    return heads


def casefold_matches(heads: dict[str, str], branch: str) -> list[str]:
    folded = branch.casefold()
    return sorted(name for name in heads if name.casefold() == folded)


def remote_matches(actual: str, expected: str) -> bool:
    if normalize_remote(actual) == normalize_remote(expected):
        return True
    actual_host, actual_parts = remote_identity(actual)
    expected_host, expected_parts = remote_identity(expected)
    if actual_host and expected_host and actual_host != expected_host:
        return False
    if actual_host and expected_host:
        return actual_parts == expected_parts
    return bool(
        actual_parts and expected_parts and actual_parts[-1] == expected_parts[-1]
    )


def normalize_remote(value: str) -> str:
    return value.removesuffix(".git").rstrip("/")


def remote_identity(value: str) -> tuple[str, list[str]]:
    parsed = urlparse(value)
    if parsed.scheme:
        return parsed.hostname or "", path_parts(parsed.path)
    if ":" in value and not value.startswith("/"):
        host, path = value.split(":", 1)
        return host.split("@")[-1], path_parts(path)
    return "", path_parts(value)


def path_parts(value: str) -> list[str]:
    return [part.removesuffix(".git") for part in value.strip("/").split("/") if part]


def repo_result(
    repo: str,
    repo_path: Path,
    blockers: list[dict[str, str]],
    checks: list[dict[str, Any]],
) -> dict[str, Any]:
    return {
        "repo": repo,
        "path": str(repo_path),
        "status": BLOCKED if blockers else OK,
        "blockers": blockers,
        "checks": checks,
    }


def blocker(code: str, message: str) -> dict[str, str]:
    return {"code": code, "message": message}


def clean_error(result: subprocess.CompletedProcess[str]) -> str:
    return (result.stderr or result.stdout).strip()


def git_output(repo_path: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(repo_path), *args],
        text=True,
        capture_output=True,
        check=False,
    )
