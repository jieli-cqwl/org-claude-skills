#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


TASK_ID_PATTERN = r"(?:T\d+|\d+(?:\.\d+)+)"
TASK_LINE_RE = re.compile(rf"^\s*[-*]\s+\[(?P<status>[ xX])\]\s+(?P<id>{TASK_ID_PATTERN})\b")
PLAN_ID_RE = re.compile(rf"\[(?P<id>{TASK_ID_PATTERN})\]")
PLAN_CHECKBOX_RE = re.compile(r"^\s*[-*]\s+\[(?P<status>[ xX])\]\s+")
PLAN_STEP_RE = re.compile(r"^\s*\d+\.\s+")
PLAN_TASK_HEADING_RE = re.compile(r"^\s*###\s+Task\b")


def fail(message: str) -> None:
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def load(path: Path, kind: str) -> str:
    if not path.is_file():
        fail(f"缺少 {kind} 文件: {path}")
    return path.read_text(encoding="utf-8")


def parse_tasks(tasks_text: str, tasks_path: Path) -> dict[str, bool]:
    task_status: dict[str, bool] = {}
    for lineno, raw in enumerate(tasks_text.splitlines(), start=1):
        m = TASK_LINE_RE.match(raw)
        if not m:
            continue
        task_id = m.group("id")
        if task_id in task_status:
            fail(f"tasks.md 中 task id 重复: {task_id}（第 {lineno} 行）")
        task_status[task_id] = m.group("status").lower() == "x"

    if not task_status:
        fail(f"tasks.md 中未找到合法 task id: {tasks_path}")
    return task_status


def parse_plan(plan_text: str, plan_path: Path) -> tuple[set[str], int]:
    plan_ids: set[str] = set()
    numbered_step_count = 0

    for lineno, raw in enumerate(plan_text.splitlines(), start=1):
        if PLAN_CHECKBOX_RE.match(raw):
            fail(f"plan.md 第 {lineno} 行不应使用 checkbox：{raw.strip()}")

        ids = set(PLAN_ID_RE.findall(raw))
        plan_ids.update(ids)

        if PLAN_TASK_HEADING_RE.match(raw) and not ids:
            fail(f"plan.md 第 {lineno} 行 Task 标题缺少 task id：{raw.strip()}")

        if PLAN_STEP_RE.match(raw):
            numbered_step_count += 1
            if not ids:
                fail(f"plan.md 第 {lineno} 行编号步骤缺少 task id：{raw.strip()}")

    if numbered_step_count == 0:
        fail(f"plan.md 中未找到任何编号步骤: {plan_path}")
    if not plan_ids:
        fail(f"plan.md 中未找到任何 task id 引用: {plan_path}")
    return plan_ids, numbered_step_count


def main(argv: list[str]) -> None:
    if len(argv) != 3:
        fail("用法: check_task_plan_consistency.py <tasks.md> <plan.md>")

    tasks_path = Path(argv[1])
    plan_path = Path(argv[2])

    tasks_text = load(tasks_path, "tasks")
    plan_text = load(plan_path, "plan")

    task_status = parse_tasks(tasks_text, tasks_path)
    plan_ids, step_count = parse_plan(plan_text, plan_path)

    task_set = set(task_status)
    plan_set = set(plan_ids)

    missing_in_plan = sorted(task_set - plan_set)
    unknown_in_plan = sorted(plan_set - task_set)

    if missing_in_plan:
        fail(f"plan.md 未覆盖以下 task id: {', '.join(missing_in_plan)}")

    if unknown_in_plan:
        fail(f"plan.md 引用了不存在的 task id: {', '.join(unknown_in_plan)}")

    print(f"[PASS] tasks-plan consistency ({len(task_set)} tasks, {step_count} plan steps)")


if __name__ == "__main__":
    main(sys.argv)
