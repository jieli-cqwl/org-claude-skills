from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from types import ModuleType
from typing import Any


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
ACTIONS = shared.ACTIONS
SCENARIOS = shared.SCENARIOS
PROJECT_MAIN_BRANCH_TARGET = shared.PROJECT_MAIN_BRANCH_TARGET
SCHEMA_VERSION = shared.SCHEMA_VERSION
FlowError = shared.FlowError
branch_name = shared.branch_name
load_policy = shared.load_policy
load_projects = shared.load_projects
require_pattern = shared.require_pattern


def validate_plan(plan: dict[str, Any]) -> None:
    registry = load_projects()
    policy = load_policy()
    validate_shape(plan, registry)
    scenario = plan["scenario"]
    validators = {
        "create-dev": validate_create_dev,
        "dev-sync": validate_dev_sync,
        "bugfix": validate_bugfix,
        "bugfix-finish": validate_bugfix_finish,
        "release-merge": validate_release_merge,
        "release-sync-before": validate_release_sync_before,
        "release-sync-after": validate_release_sync_after,
    }
    validators[scenario](plan, registry, policy)


def validate_shape(plan: dict[str, Any], registry: dict[str, dict[str, str]]) -> None:
    require_plan_fields(plan)
    if plan["schema_version"] != SCHEMA_VERSION:
        raise FlowError(f"schema_version must be {SCHEMA_VERSION}")
    if plan["scenario"] not in SCENARIOS:
        raise FlowError(f"unknown scenario: {plan['scenario']}")
    require_pattern(plan.get("version"), r"^[0-9]{4}$", "version must match ^[0-9]{4}$")
    projects = validate_plan_projects(plan["projects"], registry)
    if not isinstance(plan["target_branch"], str) or not plan["target_branch"]:
        raise FlowError("target_branch must be non-empty string")
    validate_steps(plan["steps"], projects)
    validate_push(plan["push"])


def require_plan_fields(plan: dict[str, Any]) -> None:
    allowed = {
        "schema_version",
        "scenario",
        "version",
        "owner",
        "requirement",
        "delay",
        "bug_version",
        "projects",
        "business_branches",
        "target_branch",
        "steps",
        "push",
    }
    required = {
        "schema_version",
        "scenario",
        "version",
        "projects",
        "target_branch",
        "steps",
        "push",
    }
    extra = sorted(set(plan) - allowed)
    if extra:
        raise FlowError(f"unexpected plan fields: {', '.join(extra)}")
    missing = sorted(required - set(plan))
    if missing:
        raise FlowError(f"missing plan fields: {', '.join(missing)}")


def validate_plan_projects(
    projects: Any, registry: dict[str, dict[str, str]]
) -> set[str]:
    if not isinstance(projects, list) or not projects:
        raise FlowError("projects must be a non-empty array")
    seen: set[str] = set()
    for repo in projects:
        if not isinstance(repo, str):
            raise FlowError("project repo must be string")
        if repo not in registry:
            raise FlowError(f"unknown project: {repo}")
        if repo in seen:
            raise FlowError(f"duplicate project: {repo}")
        seen.add(repo)
    return seen


def validate_steps(steps: Any, projects: set[str]) -> None:
    if not isinstance(steps, list) or not steps:
        raise FlowError("steps must be a non-empty array")
    for index, item in enumerate(steps, start=1):
        validate_step(item, index, projects)


def validate_step(item: Any, index: int, projects: set[str]) -> None:
    if not isinstance(item, dict):
        raise FlowError(f"step {index} must be an object")
    require_exact_fields(
        item, {"repo", "source_branch", "target_branch", "action"}, f"step {index}"
    )
    if item["repo"] not in projects:
        raise FlowError(f"step {index} repo is not selected: {item['repo']}")
    if item["action"] not in ACTIONS:
        raise FlowError(f"step {index} action is invalid: {item['action']}")
    for key in ("source_branch", "target_branch"):
        if not isinstance(item[key], str) or not item[key]:
            raise FlowError(f"step {index} {key} must be non-empty string")


def validate_push(push: Any) -> None:
    if not isinstance(push, dict):
        raise FlowError("push must be an object")
    require_exact_fields(push, {"confirmed", "branches"}, "push")
    if not isinstance(push["confirmed"], bool):
        raise FlowError("push.confirmed must be boolean")
    if push["confirmed"]:
        raise FlowError("push.confirmed must be false before local execution")
    branches = push["branches"]
    if not isinstance(branches, list):
        raise FlowError("push.branches must be an array")
    if branches:
        raise FlowError("push.branches must be empty before local execution")


def require_exact_fields(item: dict[str, Any], fields: set[str], label: str) -> None:
    extra = sorted(set(item) - fields)
    if extra:
        raise FlowError(f"{label} has unexpected fields: {', '.join(extra)}")
    missing = sorted(fields - set(item))
    if missing:
        raise FlowError(f"{label} missing fields: {', '.join(missing)}")


def validate_create_dev(
    plan: dict[str, Any], registry: dict[str, dict[str, str]], policy: dict[str, Any]
) -> None:
    owner = require_pattern(
        plan.get("owner"), r"^[A-Z0-9]+$", "owner must match ^[A-Z0-9]+$"
    )
    requirement = require_pattern(
        plan.get("requirement"), r"^[0-9]+$", "requirement must match ^[0-9]+$"
    )
    delay = plan.get("delay", False)
    if not isinstance(delay, bool):
        raise FlowError("delay must be boolean")
    template = "dev_delay" if delay else "dev"
    expected_target = branch_name(
        policy, template, owner=owner, requirement=requirement, version=plan["version"]
    )
    require_target(plan, expected_target)
    expected_steps = [
        (repo, registry[repo]["main_branch"], expected_target, "ensure_branch")
        for repo in plan["projects"]
    ]
    require_steps(
        plan,
        expected_steps,
        "create-dev must ensure DEV branch from project main branch",
    )


def validate_dev_sync(
    plan: dict[str, Any], registry: dict[str, dict[str, str]], policy: dict[str, Any]
) -> None:
    del policy
    business_branches = require_business_branches(plan, "dev-sync")
    target_branch = require_common_branch(
        business_branches, plan["projects"], "dev-sync"
    )
    require_target(plan, target_branch)
    expected_steps = [
        (repo, registry[repo]["main_branch"], business_branches[repo], "merge")
        for repo in plan["projects"]
    ]
    require_steps(
        plan,
        expected_steps,
        "dev-sync must merge project main branch to business branch",
    )


def require_bug_version(plan: dict[str, Any]) -> str:
    return require_pattern(
        plan.get("bug_version"),
        r"^[0-9]{4}$",
        "bug_version must match ^[0-9]{4}$",
    )


def validate_bugfix(
    plan: dict[str, Any], registry: dict[str, dict[str, str]], policy: dict[str, Any]
) -> None:
    del registry
    bug_version = require_bug_version(plan)
    release_branch = branch_name(policy, "release", version=plan["version"])
    expected_target = branch_name(policy, "bugfix", version=bug_version)
    require_target(plan, expected_target)
    expected_steps = [
        (repo, release_branch, expected_target, "ensure_branch")
        for repo in plan["projects"]
    ]
    require_steps(
        plan, expected_steps, f"bugfix must ensure BUG branch from {release_branch}"
    )


def validate_bugfix_finish(
    plan: dict[str, Any], registry: dict[str, dict[str, str]], policy: dict[str, Any]
) -> None:
    del registry
    bug_version = require_bug_version(plan)
    release_branch = branch_name(policy, "release", version=plan["version"])
    bug_branch = branch_name(policy, "bugfix", version=bug_version)
    require_target(plan, release_branch)
    expected_steps = [
        (repo, bug_branch, release_branch, "merge") for repo in plan["projects"]
    ]
    require_steps(
        plan,
        expected_steps,
        f"bugfix-finish must merge BUG branch back to {release_branch}",
    )


def validate_release_merge(
    plan: dict[str, Any], registry: dict[str, dict[str, str]], policy: dict[str, Any]
) -> None:
    release_branch = branch_name(policy, "release", version=plan["version"])
    business_branches = require_business_branches(plan, "release-merge")
    require_target(plan, release_branch)
    expected_steps = []
    for repo in plan["projects"]:
        business_branch = business_branches.get(repo)
        if not isinstance(business_branch, str) or not business_branch:
            raise FlowError(f"missing business branch for: {repo}")
        expected_steps.append(
            (repo, registry[repo]["main_branch"], release_branch, "ensure_branch")
        )
        expected_steps.append((repo, business_branch, release_branch, "merge"))
    require_steps(
        plan,
        expected_steps,
        f"release-merge must merge business branch to {release_branch}",
    )


def validate_release_sync_before(
    plan: dict[str, Any], registry: dict[str, dict[str, str]], policy: dict[str, Any]
) -> None:
    release_branch = branch_name(policy, "release", version=plan["version"])
    require_target(plan, release_branch)
    expected_steps = []
    for repo in plan["projects"]:
        main_branch = registry[repo]["main_branch"]
        expected_steps.append((repo, main_branch, release_branch, "ensure_branch"))
        expected_steps.append((repo, main_branch, release_branch, "merge"))
    require_steps(
        plan,
        expected_steps,
        f"release-sync-before must ensure {release_branch} and merge main branch",
    )


def validate_release_sync_after(
    plan: dict[str, Any], registry: dict[str, dict[str, str]], policy: dict[str, Any]
) -> None:
    release_branch = branch_name(policy, "release", version=plan["version"])
    require_target(plan, PROJECT_MAIN_BRANCH_TARGET)
    expected_steps = [
        (repo, release_branch, registry[repo]["main_branch"], "merge")
        for repo in plan["projects"]
    ]
    require_steps(
        plan,
        expected_steps,
        "release-sync-after must merge release branch back to main branch",
    )


def require_business_branches(plan: dict[str, Any], scenario: str) -> dict[str, Any]:
    business_branches = plan.get("business_branches")
    if not isinstance(business_branches, dict):
        raise FlowError(f"{scenario} requires business_branches")
    return business_branches


def require_common_branch(
    business_branches: dict[str, Any], projects: list[str], scenario: str
) -> str:
    target_branch = business_branches[projects[0]]
    mismatched = [repo for repo in projects if business_branches[repo] != target_branch]
    if mismatched:
        raise FlowError(
            f"{scenario} requires one target branch across selected projects"
        )
    return target_branch


def require_target(plan: dict[str, Any], expected_target: str) -> None:
    if plan["target_branch"] != expected_target:
        raise FlowError(f"target_branch must be {expected_target}")


def require_steps(
    plan: dict[str, Any], expected_steps: list[tuple[str, str, str, str]], message: str
) -> None:
    actual_steps = [
        (item["repo"], item["source_branch"], item["target_branch"], item["action"])
        for item in plan["steps"]
    ]
    if actual_steps != expected_steps:
        raise FlowError(message)
