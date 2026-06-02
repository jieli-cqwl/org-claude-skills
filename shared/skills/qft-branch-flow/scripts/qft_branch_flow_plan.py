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
FlowError = shared.FlowError
base_plan = shared.base_plan
branch_name = shared.branch_name
load_policy = shared.load_policy
load_projects = shared.load_projects
parse_business_branches = shared.parse_business_branches
parse_projects = shared.parse_projects
require_pattern = shared.require_pattern
PROJECT_MAIN_BRANCH_TARGET = shared.PROJECT_MAIN_BRANCH_TARGET
step = shared.step


def make_plan(args: Any) -> dict[str, Any]:
    registry = load_projects()
    policy = load_policy()
    version = require_pattern(
        args.version, r"^[0-9]{4}$", "version must match ^[0-9]{4}$"
    )
    projects = parse_projects(args.projects, registry)
    if args.scenario == "create-dev":
        return make_create_dev_plan(args, registry, policy, version, projects)
    release_branch = branch_name(policy, "release", version=version)
    if args.scenario == "bugfix":
        return make_bugfix_plan(args, policy, version, projects, release_branch)
    if args.scenario == "bugfix-finish":
        return make_bugfix_finish_plan(args, policy, version, projects, release_branch)
    if args.scenario == "dev-sync":
        return make_dev_sync_plan(args, registry, version, projects)
    if args.scenario == "release-merge":
        return make_release_merge_plan(
            args, registry, version, projects, release_branch
        )
    if args.scenario == "release-sync-before":
        return make_release_sync_before_plan(
            args, registry, version, projects, release_branch
        )
    if args.scenario == "release-sync-after":
        return make_release_sync_after_plan(
            args, registry, version, projects, release_branch
        )
    raise FlowError(f"unsupported scenario: {args.scenario}")


def make_create_dev_plan(
    args: Any,
    registry: dict[str, dict[str, str]],
    policy: dict[str, Any],
    version: str,
    projects: list[str],
) -> dict[str, Any]:
    owner = require_pattern(args.owner, r"^[A-Z0-9]+$", "owner must match ^[A-Z0-9]+$")
    requirement = require_pattern(
        args.requirement, r"^[0-9]+$", "requirement must match ^[0-9]+$"
    )
    template = "dev_delay" if args.delay else "dev"
    target_branch = branch_name(
        policy, template, owner=owner, requirement=requirement, version=version
    )
    steps = [
        step(repo, registry[repo]["main_branch"], target_branch, "ensure_branch")
        for repo in projects
    ]
    plan = base_plan(args.scenario, version, projects, target_branch, steps)
    plan["owner"] = owner
    plan["requirement"] = requirement
    plan["delay"] = bool(args.delay)
    return plan


def require_bug_version(args: Any) -> str:
    return require_pattern(
        args.bug_version, r"^[0-9]{4}$", "bug-version must match ^[0-9]{4}$"
    )


def make_bugfix_plan(
    args: Any,
    policy: dict[str, Any],
    version: str,
    projects: list[str],
    release_branch: str,
) -> dict[str, Any]:
    bug_version = require_bug_version(args)
    target_branch = branch_name(policy, "bugfix", version=bug_version)
    steps = [
        step(repo, release_branch, target_branch, "ensure_branch") for repo in projects
    ]
    plan = base_plan(args.scenario, version, projects, target_branch, steps)
    plan["bug_version"] = bug_version
    return plan


def make_bugfix_finish_plan(
    args: Any,
    policy: dict[str, Any],
    version: str,
    projects: list[str],
    release_branch: str,
) -> dict[str, Any]:
    bug_version = require_bug_version(args)
    bug_branch = branch_name(policy, "bugfix", version=bug_version)
    steps = [step(repo, bug_branch, release_branch, "merge") for repo in projects]
    plan = base_plan(args.scenario, version, projects, release_branch, steps)
    plan["bug_version"] = bug_version
    return plan


def make_dev_sync_plan(
    args: Any,
    registry: dict[str, dict[str, str]],
    version: str,
    projects: list[str],
) -> dict[str, Any]:
    business_branches = parse_business_branches(
        args.business_branches, projects, "dev-sync"
    )
    target_branch = require_common_branch(business_branches, projects, "dev-sync")
    steps = [
        step(repo, registry[repo]["main_branch"], business_branches[repo], "merge")
        for repo in projects
    ]
    plan = base_plan(args.scenario, version, projects, target_branch, steps)
    plan["business_branches"] = business_branches
    return plan


def require_common_branch(
    business_branches: dict[str, str], projects: list[str], scenario: str
) -> str:
    target_branch = business_branches[projects[0]]
    mismatched = [repo for repo in projects if business_branches[repo] != target_branch]
    if mismatched:
        raise FlowError(
            f"{scenario} requires one target branch across selected projects"
        )
    return target_branch


def make_release_merge_plan(
    args: Any,
    registry: dict[str, dict[str, str]],
    version: str,
    projects: list[str],
    release_branch: str,
) -> dict[str, Any]:
    business_branches = parse_business_branches(args.business_branches, projects)
    steps = []
    for repo in projects:
        steps.append(
            step(repo, registry[repo]["main_branch"], release_branch, "ensure_branch")
        )
        steps.append(step(repo, business_branches[repo], release_branch, "merge"))
    plan = base_plan(args.scenario, version, projects, release_branch, steps)
    plan["business_branches"] = business_branches
    return plan


def make_release_sync_before_plan(
    args: Any,
    registry: dict[str, dict[str, str]],
    version: str,
    projects: list[str],
    release_branch: str,
) -> dict[str, Any]:
    steps = []
    for repo in projects:
        main_branch = registry[repo]["main_branch"]
        steps.append(step(repo, main_branch, release_branch, "ensure_branch"))
        steps.append(step(repo, main_branch, release_branch, "merge"))
    return base_plan(args.scenario, version, projects, release_branch, steps)


def make_release_sync_after_plan(
    args: Any,
    registry: dict[str, dict[str, str]],
    version: str,
    projects: list[str],
    release_branch: str,
) -> dict[str, Any]:
    steps = [
        step(repo, release_branch, registry[repo]["main_branch"], "merge")
        for repo in projects
    ]
    return base_plan(
        args.scenario, version, projects, PROJECT_MAIN_BRANCH_TARGET, steps
    )
