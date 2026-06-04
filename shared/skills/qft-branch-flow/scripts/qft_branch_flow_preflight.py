from __future__ import annotations

import importlib.util
import os
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
GIT_TIMEOUT_SECONDS = 10.0


def preflight_plan(
    plan: dict[str, Any], repo_root: str | None = None
) -> dict[str, Any]:
    registry = load_projects()
    root = Path(repo_root or ".").resolve()
    repos = []
    for repo in plan["projects"]:
        steps = [step for step in plan["steps"] if step["repo"] == repo]
        repo_path = resolve_repo_path(root, repo, registry[repo])
        repos.append(preflight_repo(repo, repo_path, registry[repo], steps))
    status = BLOCKED if any(item["status"] == BLOCKED for item in repos) else OK
    return {"schema_version": "1.0.0", "status": status, "repos": repos}


def resolve_repo_path(root: Path, repo: str, registry_item: dict[str, str]) -> Path:
    top_level = git_top_level(root)
    candidates = repo_path_candidates(root, repo, top_level)
    seen: set[Path] = set()
    remote_mismatch_fallback: Path | None = None
    for candidate in candidates:
        resolved = candidate.resolve()
        if resolved in seen or not resolved.exists() or not is_git_repo(resolved):
            continue
        seen.add(resolved)
        remote_blockers = check_remote(resolved, registry_item["remote_url"])
        if not remote_blockers:
            return resolved
        if resolved.name == repo and remote_mismatch_fallback is None:
            remote_mismatch_fallback = resolved
    return remote_mismatch_fallback or missing_repo_path(root, repo, top_level)


def repo_path_candidates(root: Path, repo: str, top_level: Path | None) -> list[Path]:
    candidates: list[Path] = []
    add_candidate(candidates, top_level)
    add_candidate(candidates, root)
    add_candidate(candidates, root / repo)
    if top_level is not None and top_level.parent != top_level:
        add_candidate(candidates, top_level.parent / repo)
    if root.parent != root:
        add_candidate(candidates, root.parent / repo)
    return candidates


def add_candidate(candidates: list[Path], candidate: Path | None) -> None:
    if candidate is not None:
        candidates.append(candidate)


def missing_repo_path(root: Path, repo: str, top_level: Path | None) -> Path:
    if top_level is not None and top_level.parent != top_level:
        return top_level.parent / repo
    return root / repo


def preflight_repo(
    repo: str,
    repo_path: Path,
    registry_item: dict[str, str],
    steps: list[dict[str, str]],
) -> dict[str, Any]:
    blockers: list[dict[str, str]] = []
    checks: list[dict[str, Any]] = []
    worktree = empty_worktree_status()
    remote = empty_remote_status(registry_item["remote_url"])
    if not repo_path.exists():
        return repo_result(
            repo,
            repo_path,
            [blocker("repo_missing", f"repo directory not found: {repo_path}")],
            checks,
            worktree,
            remote,
        )
    if not is_git_repo(repo_path):
        return repo_result(
            repo,
            repo_path,
            [blocker("not_git_repo", f"not a git repository: {repo_path}")],
            checks,
            worktree,
            remote,
        )

    worktree = inspect_worktree(repo_path)
    remote = inspect_remote(repo_path, registry_item["remote_url"])
    blockers.extend(worktree["blockers"])
    blockers.extend(remote["blockers"])
    if remote["blockers"]:
        return repo_result(repo, repo_path, blockers, checks, worktree, remote)
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
    return repo_result(repo, repo_path, blockers, checks, worktree, remote)


def check_worktree(repo_path: Path) -> list[dict[str, str]]:
    return inspect_worktree(repo_path)["blockers"]


def inspect_worktree(repo_path: Path) -> dict[str, Any]:
    result = git_output(repo_path, "status", "--porcelain")
    if result.returncode != 0:
        return {
            "status": UNKNOWN,
            "clean": False,
            "blockers": [blocker("git_status_failed", clean_error(result))],
        }
    if result.stdout.strip():
        return {
            "status": BLOCKED,
            "clean": False,
            "blockers": [blocker("worktree_dirty", "worktree has uncommitted changes")],
        }
    return {"status": OK, "clean": True, "blockers": []}


def check_remote(repo_path: Path, expected: str) -> list[dict[str, str]]:
    return inspect_remote(repo_path, expected)["blockers"]


def inspect_remote(repo_path: Path, expected: str) -> dict[str, Any]:
    result = git_output(repo_path, "remote", "get-url", "origin")
    if result.returncode != 0:
        return {
            "status": BLOCKED,
            "actual": None,
            "expected": expected,
            "blockers": [blocker("remote_missing", clean_error(result))],
        }
    actual = result.stdout.strip()
    if remote_matches(actual, expected):
        return {
            "status": OK,
            "actual": actual,
            "expected": expected,
            "blockers": [],
        }
    return {
        "status": BLOCKED,
        "actual": actual,
        "expected": expected,
        "blockers": [
            blocker("remote_mismatch", f"origin is {actual}, expected {expected}")
        ],
    }


def empty_worktree_status() -> dict[str, Any]:
    return {"status": UNKNOWN, "clean": False, "blockers": []}


def empty_remote_status(expected: str) -> dict[str, Any]:
    return {"status": UNKNOWN, "actual": None, "expected": expected, "blockers": []}


def is_git_repo(repo_path: Path) -> bool:
    result = git_output(repo_path, "rev-parse", "--is-inside-work-tree")
    return result.returncode == 0 and result.stdout.strip() == "true"


def git_top_level(repo_path: Path) -> Path | None:
    result = git_output(repo_path, "rev-parse", "--show-toplevel")
    if result.returncode != 0 or not result.stdout.strip():
        return None
    return Path(result.stdout.strip()).resolve()


def preflight_step(
    repo_path: Path,
    index: int,
    step: dict[str, str],
    planned_branches: set[str],
) -> dict[str, Any]:
    source = branch_state(repo_path, step["source_branch"])
    target = branch_state(repo_path, step["target_branch"])
    target_planned = step["target_branch"] in planned_branches
    target_resolution = resolve_target(step["action"], target)
    blockers = action_blockers(step["action"], source, target, target_planned)
    return {
        "index": index,
        "action": step["action"],
        "source_branch": step["source_branch"],
        "target_branch": step["target_branch"],
        "target_planned": target_planned,
        "target_resolution": target_resolution,
        "requires_user_confirmation": target_resolution == "reuse_existing",
        "status": BLOCKED if blockers else OK,
        "source": source,
        "target": target,
        "blockers": blockers,
    }


def resolve_target(action: str, target: dict[str, Any]) -> str:
    if action != "ensure_branch":
        return "not_applicable"
    if branch_exists(target):
        return "reuse_existing"
    return "create_missing"


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
    if state["local_sha"] and not state["remote_sha"]:
        return [
            blocker(
                f"{role}_local_only",
                f"{role} branch {state['name']} exists locally but not on origin",
            )
        ]
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
    actual_host, actual_port, actual_parts = remote_identity(actual)
    expected_host, expected_port, expected_parts = remote_identity(expected)
    if actual_host or expected_host:
        return (
            bool(actual_host)
            and bool(expected_host)
            and actual_host == expected_host
            and actual_port == expected_port
            and actual_parts == expected_parts
        )
    return bool(actual_parts and expected_parts and actual_parts == expected_parts)


def normalize_remote(value: str) -> str:
    return value.removesuffix(".git").rstrip("/")


def remote_identity(value: str) -> tuple[str, int | None, list[str]]:
    parsed = urlparse(value)
    if parsed.scheme:
        return (parsed.hostname or "").lower(), parsed_port(parsed), path_parts(parsed.path)
    if ":" in value and not value.startswith("/"):
        host, path = value.split(":", 1)
        return host.split("@")[-1].lower(), None, path_parts(path)
    return "", None, path_parts(value)


def parsed_port(parsed: Any) -> int | None:
    try:
        return parsed.port
    except ValueError:
        return None


def path_parts(value: str) -> list[str]:
    return [part.removesuffix(".git") for part in value.strip("/").split("/") if part]


def repo_result(
    repo: str,
    repo_path: Path,
    blockers: list[dict[str, str]],
    checks: list[dict[str, Any]],
    worktree: dict[str, Any],
    remote: dict[str, Any],
) -> dict[str, Any]:
    return {
        "repo": repo,
        "path": str(repo_path),
        "status": BLOCKED if blockers else OK,
        "worktree": worktree,
        "remote": remote,
        "blockers": blockers,
        "checks": checks,
    }


def blocker(code: str, message: str) -> dict[str, str]:
    return {"code": code, "message": message}


def clean_error(result: subprocess.CompletedProcess[str]) -> str:
    return (result.stderr or result.stdout).strip()


def git_output(repo_path: Path, *args: str) -> subprocess.CompletedProcess[str]:
    command = ["git", "-C", str(repo_path), *args]
    env = os.environ.copy()
    env["GIT_TERMINAL_PROMPT"] = "0"
    env["GCM_INTERACTIVE"] = "Never"
    timeout = git_timeout_seconds()
    try:
        return subprocess.run(
            command,
            text=True,
            capture_output=True,
            check=False,
            env=env,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout if isinstance(exc.stdout, str) else ""
        stderr = exc.stderr if isinstance(exc.stderr, str) else ""
        message = stderr or f"git command timed out after {timeout:g}s: {' '.join(command)}"
        return subprocess.CompletedProcess(command, 124, stdout, message)


def git_timeout_seconds() -> float:
    raw = os.environ.get("QFT_BRANCH_FLOW_GIT_TIMEOUT_SECONDS")
    if raw is None:
        return GIT_TIMEOUT_SECONDS
    try:
        value = float(raw)
    except ValueError:
        return GIT_TIMEOUT_SECONDS
    return value if value > 0 else GIT_TIMEOUT_SECONDS
