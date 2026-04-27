#!/usr/bin/env python3
"""Route implementation after writing-plans for active small-chain worksets."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from runtime_yaml import load_yaml


ROUTER_VERSION = 1
HIGH_RISK_PREFIXES = (
    "contracts/",
    "shared/hooks/",
    "tools/community/validate_",
    "contracts/canonical/",
    "community/SOURCES.yaml",
)
HIGH_RISK_FILES = {
    "install.sh",
    "shared/hooks/registry.json",
}
TASK_ID_PATTERN = r"(?:T\d+|\d+(?:\.\d+)+)"
TASK_CHECKBOX_RE = re.compile(rf"^(\s*[-*]\s+\[)[ xX](\]\s+{TASK_ID_PATTERN}\b)")
TASK_LINE_RE = re.compile(rf"^\s*[-*]\s+\[[ xX]\]\s+(?P<id>{TASK_ID_PATTERN})\b")
PLAN_ID_RE = re.compile(rf"\[(?P<id>{TASK_ID_PATTERN})\]")


@dataclass(frozen=True)
class RouteTask:
    task_id: str
    depends: tuple[str, ...]
    exclusive_files: tuple[str, ...]
    shared_files: tuple[str, ...]
    proving_commands: tuple[str, ...]
    touches_contract_grade: bool


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--feature-path")
    parser.add_argument("--workset")
    parser.add_argument("--force-refresh", action="store_true")
    return parser.parse_args(argv)


def sha256_text(text: str) -> str:
    normalized = text.replace("\r\n", "\n").strip() + "\n"
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def normalize_tasks_for_route_hash(text: str) -> str:
    lines: list[str] = []
    for line in text.replace("\r\n", "\n").splitlines():
        lines.append(TASK_CHECKBOX_RE.sub(r"\1 \2", line))
    return "\n".join(lines)


def sha256_json(data: object) -> str:
    payload = json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def load_json(path: Path) -> object:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def active_entry(root: Path) -> tuple[str, str]:
    registry_path = root / "contracts" / "active-doc-scope.yaml"
    data = load_yaml(registry_path)
    for entry in data.get("scope_entries", []):
        if entry.get("mode") != "small-chain":
            continue
        if entry.get("management_status") not in {"managed", "migrated"}:
            continue
        feature_path = entry.get("feature_path")
        workset = entry.get("primary_workset_relpath")
        if isinstance(feature_path, str) and isinstance(workset, str):
            return feature_path, workset
    raise ValueError("no active managed small-chain workset found")


def resolve_target(root: Path, feature_path: str | None, workset: str | None) -> tuple[str, str, Path]:
    if not feature_path or not workset:
        inferred_feature, inferred_workset = active_entry(root)
        feature_path = feature_path or inferred_feature
        workset = workset or inferred_workset
    workset_dir = root / feature_path / workset
    return feature_path, workset, workset_dir


def as_str_list(value: object, field: str, task_id: str) -> tuple[str, ...]:
    if not isinstance(value, list) or not all(isinstance(item, str) and item for item in value):
        raise ValueError(f"{task_id}.{field} must be a list of strings")
    return tuple(value)


def parse_tasks(data: object) -> list[RouteTask]:
    if not isinstance(data, dict):
        raise ValueError("routing input must be an object")
    raw_tasks = data.get("tasks")
    if not isinstance(raw_tasks, list) or not raw_tasks:
        raise ValueError("routing input tasks must be a non-empty list")
    tasks: list[RouteTask] = []
    seen: set[str] = set()
    for raw in raw_tasks:
        if not isinstance(raw, dict):
            raise ValueError("each route task must be an object")
        task_id = raw.get("task_id")
        if not isinstance(task_id, str) or not task_id:
            raise ValueError("route task missing task_id")
        if task_id in seen:
            raise ValueError(f"duplicate task_id: {task_id}")
        seen.add(task_id)
        tasks.append(
            RouteTask(
                task_id=task_id,
                depends=as_str_list(raw.get("depends", []), "depends", task_id),
                exclusive_files=as_str_list(raw.get("exclusive_files", []), "exclusive_files", task_id),
                shared_files=as_str_list(raw.get("shared_files", []), "shared_files", task_id),
                proving_commands=as_str_list(raw.get("proving_commands", []), "proving_commands", task_id),
                touches_contract_grade=bool(raw.get("touches_contract_grade", False)),
            )
        )
    known = {task.task_id for task in tasks}
    for task in tasks:
        unknown = sorted(set(task.depends) - known)
        if unknown:
            raise ValueError(f"{task.task_id}.depends references unknown task ids: {', '.join(unknown)}")
    return tasks


def task_ids_from_tasks(text: str) -> set[str]:
    task_ids: set[str] = set()
    for line in text.splitlines():
        match = TASK_LINE_RE.match(line)
        if not match:
            continue
        task_id = match.group("id")
        if task_id in task_ids:
            raise ValueError(f"tasks.md contains duplicate task id: {task_id}")
        task_ids.add(task_id)
    if not task_ids: raise ValueError("tasks.md contains no routeable task ids")
    return task_ids


def task_ids_from_plan(text: str) -> set[str]:
    task_ids = set(PLAN_ID_RE.findall(text))
    if not task_ids: raise ValueError("plan.md contains no task ids")
    return task_ids


def validate_task_scope(tasks: list[RouteTask], tasks_text: str, plan_text: str) -> None:
    tasks_ids = task_ids_from_tasks(tasks_text)
    plan_ids = task_ids_from_plan(plan_text)
    route_ids = {task.task_id for task in tasks}
    problems: list[str] = []
    if plan_ids - tasks_ids:
        problems.append(f"plan.md references unknown task ids: {', '.join(sorted(plan_ids - tasks_ids))}")
    if tasks_ids - plan_ids:
        problems.append(f"plan.md misses task ids: {', '.join(sorted(tasks_ids - plan_ids))}")
    if route_ids - tasks_ids:
        problems.append(f"execution-routing-input.json has unknown task ids: {', '.join(sorted(route_ids - tasks_ids))}")
    if tasks_ids - route_ids:
        problems.append(f"execution-routing-input.json misses task ids: {', '.join(sorted(tasks_ids - route_ids))}")
    if problems:
        raise ValueError("; ".join(problems))


def file_is_high_risk(path: str) -> bool:
    return path in HIGH_RISK_FILES or any(path.startswith(prefix) for prefix in HIGH_RISK_PREFIXES)


def high_risk_files(tasks: list[RouteTask]) -> list[str]:
    paths: set[str] = set()
    for task in tasks:
        paths.update(task.exclusive_files)
        paths.update(task.shared_files)
    return sorted(path for path in paths if file_is_high_risk(path))


def duplicate_writes(tasks: list[RouteTask]) -> list[str]:
    owners: dict[str, str] = {}
    duplicates: set[str] = set()
    for task in tasks:
        for path in task.exclusive_files:
            owner = owners.setdefault(path, task.task_id)
            if owner != task.task_id:
                duplicates.add(path)
    return sorted(duplicates)


def has_dependency_edges(tasks: list[RouteTask]) -> bool:
    return any(task.depends for task in tasks)


def shared_writes(tasks: list[RouteTask]) -> list[str]:
    paths: set[str] = set()
    for task in tasks:
        paths.update(task.shared_files)
    paths.update(duplicate_writes(tasks))
    return sorted(paths)


def touches_contract_grade(tasks: list[RouteTask]) -> bool:
    return any(task.touches_contract_grade for task in tasks)


def blocked_route(feature_path: str, workset: str, reason: str, checks: list[str], hashes: dict[str, str | None]) -> dict:
    return {
        "schema_version": 1,
        "decision": "blocked",
        "reason": reason,
        "blocking_checks": checks,
        "next_action": "Repair the plan-stage route input, then rerun implementation routing.",
        "feature_path": feature_path,
        "workset": workset,
        "eligible_tasks": [],
        "parallel_groups": [],
        "worktree_policy": "none",
        "router_version": ROUTER_VERSION,
        "generated_at": now_iso(),
        **hashes,
    }


def route_for_decision(
    feature_path: str,
    workset: str,
    decision: str,
    reason: str,
    tasks: list[RouteTask],
    hashes: dict[str, str],
) -> dict:
    task_ids = [task.task_id for task in tasks]
    if decision == "parallel":
        groups = [[task_id] for task_id in task_ids]
        worktree_policy = "per_task_worktree"
    else:
        groups = []
        worktree_policy = "single_feature_worktree"
    return {
        "schema_version": 1,
        "decision": decision,
        "reason": reason,
        "blocking_checks": [],
        "next_action": "Continue with the routed implementation path.",
        "feature_path": feature_path,
        "workset": workset,
        "eligible_tasks": task_ids,
        "parallel_groups": groups,
        "worktree_policy": worktree_policy,
        "router_version": ROUTER_VERSION,
        "generated_at": now_iso(),
        **hashes,
    }


def stale_existing_route(route_path: Path, hashes: dict[str, str]) -> list[str]:
    if not route_path.is_file(): return []
    try:
        existing = load_json(route_path)
    except Exception:
        return ["existing_route_unreadable"]
    if not isinstance(existing, dict):
        return ["existing_route_unreadable"]
    if existing.get("reason") == "stale_existing_execution_route":
        return ["stale_route_requires_force_refresh"]
    stale: list[str] = []
    for key, value in hashes.items():
        if existing.get(key) and existing.get(key) != value:
            stale.append(key)
    return stale


def build_route(root: Path, feature_path: str | None, workset: str | None, force_refresh: bool) -> tuple[dict, Path]:
    feature_path, workset, workset_dir = resolve_target(root, feature_path, workset)
    tasks_path = workset_dir / "tasks.md"
    plan_path = workset_dir / "plan.md"
    input_path = workset_dir / "execution-routing-input.json"
    route_path = workset_dir / "execution-route.json"
    hashes: dict[str, str | None] = {
        "tasks_hash": None,
        "plan_hash": None,
        "routing_input_hash": None,
    }
    if not tasks_path.is_file() or not plan_path.is_file() or not input_path.is_file():
        return (
            blocked_route(
                feature_path,
                workset,
                "missing_plan_stage_route_artifacts",
                ["tasks_plan_or_routing_input_missing"],
                hashes,
            ),
            route_path,
        )
    tasks_text = tasks_path.read_text(encoding="utf-8")
    plan_text = plan_path.read_text(encoding="utf-8")
    tasks_hash = sha256_text(normalize_tasks_for_route_hash(tasks_text))
    plan_hash = sha256_text(plan_text)
    try:
        route_input = load_json(input_path)
        routing_input_hash = sha256_json(route_input)
        tasks = parse_tasks(route_input)
        validate_task_scope(tasks, tasks_text, plan_text)
    except Exception as exc:
        hashes.update({"tasks_hash": tasks_hash, "plan_hash": plan_hash})
        return (
            blocked_route(
                feature_path,
                workset,
                "routing_input_invalid",
                [str(exc)],
                hashes,
            ),
            route_path,
        )
    concrete_hashes = {
        "tasks_hash": tasks_hash,
        "plan_hash": plan_hash,
        "routing_input_hash": routing_input_hash,
    }
    if not force_refresh:
        stale = stale_existing_route(route_path, concrete_hashes)
        if stale:
            return (
                blocked_route(feature_path, workset, "stale_existing_execution_route", stale, concrete_hashes),
                route_path,
            )
    requested_mode = route_input.get("requested_mode") if isinstance(route_input, dict) else None
    if requested_mode == "serial":
        return (
            route_for_decision(feature_path, workset, "serial", "requested_serial_execution", tasks, concrete_hashes),
            route_path,
        )
    if requested_mode != "parallel":
        return (
            blocked_route(feature_path, workset, "unsupported_requested_mode", ["requested_mode"], concrete_hashes),
            route_path,
        )
    blocks: list[str] = []
    if has_dependency_edges(tasks):
        blocks.append("dependency_edges_present")
    if shared_writes(tasks):
        blocks.append("shared_writes_present")
    if high_risk_files(tasks):
        blocks.append("high_risk_common_surface")
    if touches_contract_grade(tasks):
        blocks.append("contract_grade_surface_present")
    if blocks:
        return (
            blocked_route(feature_path, workset, "parallel_route_not_safe", blocks, concrete_hashes),
            route_path,
        )
    return (
        route_for_decision(feature_path, workset, "parallel", "parallel_route_safe", tasks, concrete_hashes),
        route_path,
    )


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = args.repo_root.resolve()
    try:
        route, route_path = build_route(root, args.feature_path, args.workset, args.force_refresh)
    except Exception as exc:
        route = blocked_route(
            args.feature_path or "",
            args.workset or "",
            "router_unavailable",
            [str(exc)],
            {"tasks_hash": None, "plan_hash": None, "routing_input_hash": None},
        )
        route_path = root / (args.feature_path or ".") / (args.workset or ".") / "execution-route.json"
    route_path.parent.mkdir(parents=True, exist_ok=True)
    write_json(route_path, route)
    print(json.dumps(route, ensure_ascii=False, sort_keys=True))
    return 0 if route["decision"] != "blocked" else 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
