from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PROJECT_REGISTRY_PATH = ROOT / "references" / "project-registry.json"
BRANCH_POLICY_PATH = ROOT / "references" / "branch-policy.json"

SCHEMA_VERSION = "1.0.0"
PROJECT_MAIN_BRANCH_TARGET = "<project-main-branch>"
SCENARIOS = {
    "create-dev",
    "dev-sync",
    "release-merge",
    "bugfix",
    "release-sync-before",
    "release-sync-after",
}
ACTIONS = {"create_branch", "ensure_branch", "merge"}


class FlowError(Exception):
    pass


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise FlowError(f"failed to read {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise FlowError(f"failed to parse {path}: {exc}") from exc


def load_projects() -> dict[str, dict[str, str]]:
    data = read_json(PROJECT_REGISTRY_PATH)
    projects = data.get("projects")
    if not isinstance(projects, list):
        raise FlowError("project registry must contain projects")
    registry: dict[str, dict[str, str]] = {}
    for item in projects:
        repo, main_branch = project_identity(item)
        registry[repo] = {str(key): str(value) for key, value in item.items()}
        registry[repo]["repo"] = repo
        registry[repo]["main_branch"] = main_branch
    return registry


def project_identity(item: Any) -> tuple[str, str]:
    if not isinstance(item, dict):
        raise FlowError("project registry item must be an object")
    repo = item.get("repo")
    main_branch = item.get("main_branch")
    if not isinstance(repo, str) or not isinstance(main_branch, str):
        raise FlowError("project registry item must contain repo and main_branch")
    return repo, main_branch


def load_policy() -> dict[str, Any]:
    policy = read_json(BRANCH_POLICY_PATH)
    if not isinstance(policy, dict):
        raise FlowError("branch policy must be an object")
    return policy


def parse_projects(raw: str, registry: dict[str, dict[str, str]]) -> list[str]:
    projects = [part.strip() for part in raw.split(",") if part.strip()]
    if not projects:
        raise FlowError("at least one project is required")
    seen: set[str] = set()
    result: list[str] = []
    for repo in projects:
        if repo not in registry:
            raise FlowError(f"unknown project: {repo}")
        if repo in seen:
            raise FlowError(f"duplicate project: {repo}")
        seen.add(repo)
        result.append(repo)
    return result


def require_pattern(value: str | None, pattern: str, message: str) -> str:
    if value is None or re.fullmatch(pattern, value) is None:
        raise FlowError(message)
    return value


def branch_name(policy: dict[str, Any], name: str, **values: str) -> str:
    branches = policy.get("branches")
    if not isinstance(branches, dict):
        raise FlowError("branch policy must contain branches")
    template = branches.get(name)
    if not isinstance(template, str):
        raise FlowError(f"missing branch template: {name}")
    return template.format(**values)


def parse_business_branches(
    raw: str | None, projects: list[str], scenario: str = "release-merge"
) -> dict[str, str]:
    if raw is None:
        raise FlowError(f"{scenario} requires --business-branches")
    result = business_branch_pairs(raw, projects)
    missing = [repo for repo in projects if repo not in result]
    if missing:
        raise FlowError(f"missing business branch for: {', '.join(missing)}")
    return result


def business_branch_pairs(raw: str, projects: list[str]) -> dict[str, str]:
    result: dict[str, str] = {}
    for pair in [part.strip() for part in raw.split(",") if part.strip()]:
        repo, branch = parse_business_branch_pair(pair)
        if repo not in projects:
            raise FlowError(f"business branch repo is not selected: {repo}")
        if repo in result:
            raise FlowError(f"duplicate business branch repo: {repo}")
        result[repo] = branch
    return result


def parse_business_branch_pair(pair: str) -> tuple[str, str]:
    if "=" not in pair:
        raise FlowError("business branch mapping must use repo=branch")
    repo, branch = [part.strip() for part in pair.split("=", 1)]
    if not branch:
        raise FlowError(f"business branch is empty for {repo}")
    return repo, branch


def step(
    repo: str, source_branch: str, target_branch: str, action: str
) -> dict[str, str]:
    return {
        "repo": repo,
        "source_branch": source_branch,
        "target_branch": target_branch,
        "action": action,
    }


def base_plan(
    scenario: str,
    version: str,
    projects: list[str],
    target_branch: str,
    steps: list[dict[str, str]],
) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "scenario": scenario,
        "version": version,
        "projects": projects,
        "target_branch": target_branch,
        "steps": steps,
        "push": {"confirmed": False, "branches": []},
    }


def read_input_plan(path: str | None) -> dict[str, Any]:
    raw, source = read_input_text(path)
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise FlowError(f"failed to parse input {source}: {exc}") from exc
    if not isinstance(data, dict):
        raise FlowError("input plan must be an object")
    return data


def read_input_text(path: str | None) -> tuple[str, str]:
    if path is None:
        return sys.stdin.read(), "stdin"
    try:
        return Path(path).read_text(encoding="utf-8"), path
    except OSError as exc:
        raise FlowError(f"failed to read input {path}: {exc}") from exc
