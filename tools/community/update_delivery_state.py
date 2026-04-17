#!/usr/bin/env python3
"""Apply runtime delivery-state transitions for task alignment, blocking, and replan."""

from __future__ import annotations

import argparse
import copy
import json
import sys
from pathlib import Path


def load_json(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path} 顶层必须是对象")
    return data


def assert_expected_subset(actual: dict, expected: dict) -> None:
    for key, value in expected.items():
        if actual.get(key) != value:
            raise ValueError(f"{key} mismatch: {actual.get(key)} != {value}")


def split_artifact_ref(ref: str) -> tuple[str, str, str, str]:
    try:
        scheme, target = ref.split("://", 1)
        artifact_target, anchor = target.split("#", 1)
        artifact_type, versioned_id = artifact_target.split("/", 1)
        artifact_id, version = versioned_id.rsplit("@", 1)
    except ValueError as exc:
        raise ValueError(f"非法 canonical ref: {ref}") from exc
    if scheme != "artifact":
        raise ValueError(f"非法 ref scheme: {ref}")
    return artifact_type, artifact_id, version, anchor


def phase_scope_from_artifact_id(artifact_id: str) -> str:
    prefix, separator, _tail = artifact_id.rpartition(".")
    if not separator or not prefix:
        raise ValueError(f"非法 artifact_id scope: {artifact_id}")
    return prefix


def assert_replan_target_refs(state: dict, plan_ref: str, tasks_ref: str, tasks_registry: dict | None = None) -> None:
    plan_type, plan_artifact_id, _plan_version, plan_anchor = split_artifact_ref(plan_ref)
    tasks_type, tasks_artifact_id, _tasks_version, tasks_anchor = split_artifact_ref(tasks_ref)

    if plan_type != "plan" or plan_anchor != "plan-version":
        raise ValueError("plan_ref 必须指向 artifact://plan/...#plan-version")
    if tasks_type != "tasks" or tasks_anchor != "task-registry":
        raise ValueError("tasks_ref 必须指向 artifact://tasks/...#task-registry")

    state_scope = phase_scope_from_artifact_id(str(state.get("artifact_id", "")))
    if phase_scope_from_artifact_id(plan_artifact_id) != state_scope:
        raise ValueError("plan_ref 必须与当前 delivery-state 属于同一 feature/phase")
    if phase_scope_from_artifact_id(tasks_artifact_id) != state_scope:
        raise ValueError("tasks_ref 必须与当前 delivery-state 属于同一 feature/phase")

    if tasks_registry is None:
        return

    if tasks_artifact_id != tasks_registry.get("artifact_id"):
        raise ValueError("tasks_ref 必须指向当前 active tasks registry")
    baseline_plan_ref = tasks_registry.get("baseline_plan_version_ref")
    if isinstance(baseline_plan_ref, str) and baseline_plan_ref and baseline_plan_ref != plan_ref:
        raise ValueError("plan_ref 必须与 tasks registry 绑定的 baseline plan 保持一致")


def assert_blocked_resume_pair(blocked_from_stage: str, resume_stage: str) -> None:
    if resume_stage not in {blocked_from_stage, "REPLAN_PENDING"}:
        raise ValueError(
            "resume_stage 只能等于 blocked_from_stage 或 REPLAN_PENDING"
        )


def assert_task_runtime_alignment(state: dict, tasks_registry: dict) -> None:
    active_tasks_version_ref = state.get("active_tasks_version_ref")
    if not isinstance(active_tasks_version_ref, str):
        raise ValueError("delivery-state 缺少 active_tasks_version_ref")
    artifact_type, artifact_id, version, anchor = split_artifact_ref(active_tasks_version_ref)
    if artifact_type != "tasks" or artifact_id != tasks_registry["artifact_id"] or anchor != "task-registry":
        raise ValueError("delivery-state active_tasks_version_ref 与 tasks registry 不一致")
    expected_task_ref_prefix = f"artifact://tasks/{artifact_id}@{version}#task-"
    task_ref_namespace = f"artifact://tasks/{artifact_id}@"
    tasks = tasks_registry.get("tasks", [])
    indexed = {task["task_id"]: task for task in tasks}
    runtime_entries = state.get("tasks", [])
    for entry in runtime_entries:
        task_id = entry.get("task_id")
        if task_id not in indexed:
            raise ValueError(f"delivery-state 包含未知 task_id: {task_id}")
        if indexed[task_id].get("task_state") in {"SUPERSEDED", "CANCELLED"}:
            raise ValueError(f"delivery-state 不得继续消费非 active task: {task_id}")
        latest_upstream_refs = entry.get("latest_upstream_refs", [])
        if f"{expected_task_ref_prefix}{task_id}" not in latest_upstream_refs:
            raise ValueError(f"runtime task 未绑定当前 active tasks version: {task_id}")
        for upstream_ref in latest_upstream_refs:
            if upstream_ref.startswith(task_ref_namespace) and not upstream_ref.startswith(expected_task_ref_prefix):
                raise ValueError(f"runtime task 引用了旧 tasks version: {upstream_ref}")


def enter_blocked(state: dict, blocker: dict) -> dict:
    if blocker["blocked_from_stage"] != state.get("current_stage"):
        raise ValueError("blocked_from_stage 必须等于当前 current_stage")
    assert_blocked_resume_pair(
        blocker["blocked_from_stage"],
        blocker["resume_stage"],
    )
    if not blocker["blocker_basis_refs"]:
        raise ValueError("blocker_basis_refs 不能为空")
    result = copy.deepcopy(state)
    result["current_stage"] = "BLOCKED"
    result["status"] = "BLOCKED"
    result["blocker_id"] = blocker["blocker_id"]
    result["blocked_from_stage"] = blocker["blocked_from_stage"]
    result["resume_stage"] = blocker["resume_stage"]
    result["blocker_reason_code"] = blocker["blocker_reason_code"]
    result["blocker_opened_at"] = blocker["blocker_opened_at"]
    result["blocker_basis_refs"] = blocker["blocker_basis_refs"]
    return result


def leave_blocked(state: dict, resolution: dict) -> dict:
    if state.get("current_stage") != "BLOCKED":
        raise ValueError("只有 BLOCKED 状态才能执行 leave_blocked")
    assert_blocked_resume_pair(
        state["blocked_from_stage"],
        state["resume_stage"],
    )
    if resolution["resume_stage"] != state["resume_stage"]:
        raise ValueError("解除 BLOCKED 时不得改写既定 resume_stage")
    if not resolution["blocker_resolution_evidence_refs"]:
        raise ValueError("没有 blocker_resolution_evidence_refs 不得离开 BLOCKED")
    result = copy.deepcopy(state)
    result["current_stage"] = resolution["resume_stage"]
    result["status"] = "IN_PROGRESS"
    result["blocker_resolution_evidence_refs"] = resolution["blocker_resolution_evidence_refs"]
    result["unblocked_by_ref"] = resolution["unblocked_by_ref"]
    result["unblocked_at"] = resolution["unblocked_at"]
    return result


def write_task_runtime(state: dict, task_update: dict) -> dict:
    result = copy.deepcopy(state)
    tasks = result.setdefault("tasks", [])
    for idx, existing in enumerate(tasks):
        if existing.get("task_id") == task_update["task_id"]:
            merged = copy.deepcopy(existing)
            merged.update(task_update)
            tasks[idx] = merged
            break
    else:
        tasks.append(copy.deepcopy(task_update))
    return result


def switch_active_baseline(state: dict, plan_ref: str, tasks_ref: str, tasks_registry: dict | None = None) -> dict:
    assert_replan_target_refs(state, plan_ref, tasks_ref, tasks_registry)
    result = copy.deepcopy(state)
    result["active_plan_version_ref"] = plan_ref
    result["active_tasks_version_ref"] = tasks_ref
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--tasks-fixture", type=Path)
    parser.add_argument("--check-task-runtime", action="store_true")
    parser.add_argument("--apply-task-runtime", action="store_true")
    parser.add_argument("--check-enter-blocked", action="store_true")
    parser.add_argument("--apply-enter-blocked", action="store_true")
    parser.add_argument("--check-leave-blocked", action="store_true")
    parser.add_argument("--apply-leave-blocked", action="store_true")
    parser.add_argument("--check-replan-switch", action="store_true")
    parser.add_argument("--apply-replan-switch", action="store_true")
    return parser.parse_args()


def dump_json(document: dict) -> None:
    json.dump(document, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")


def main() -> None:
    args = parse_args()
    enabled = [
        args.check_task_runtime,
        args.apply_task_runtime,
        args.check_enter_blocked,
        args.apply_enter_blocked,
        args.check_leave_blocked,
        args.apply_leave_blocked,
        args.check_replan_switch,
        args.apply_replan_switch,
    ]
    if sum(bool(flag) for flag in enabled) != 1:
        raise SystemExit("必须且只能选择一个检查模式")

    payload = load_json(args.fixture.resolve())
    if args.check_task_runtime or args.apply_task_runtime:
        if args.tasks_fixture is None:
            raise SystemExit("task runtime 模式需要 --tasks-fixture")
        tasks_fixture = load_json(args.tasks_fixture.resolve())
        if args.check_task_runtime:
            assert_task_runtime_alignment(payload, tasks_fixture)
            return
        result = write_task_runtime(payload["state"], payload["task_update"])
        assert_task_runtime_alignment(result, tasks_fixture)
        dump_json(result)
        return
    if args.check_enter_blocked or args.apply_enter_blocked:
        result = enter_blocked(payload["state"], payload["blocker"])
        if args.apply_enter_blocked:
            dump_json(result)
            return
        assert_expected_subset(result, payload["expected"])
        return
    if args.check_leave_blocked or args.apply_leave_blocked:
        result = leave_blocked(payload["state"], payload["resolution"])
        if args.apply_leave_blocked:
            dump_json(result)
            return
        assert_expected_subset(result, payload["expected"])
        return
    tasks_registry = load_json(args.tasks_fixture.resolve()) if args.tasks_fixture is not None else None
    result = switch_active_baseline(payload["state"], payload["plan_ref"], payload["tasks_ref"], tasks_registry)
    if args.tasks_fixture is not None:
        assert_task_runtime_alignment(result, tasks_registry)
    if args.apply_replan_switch:
        dump_json(result)
        return
    assert_expected_subset(result, payload["expected"])


if __name__ == "__main__":
    main()
