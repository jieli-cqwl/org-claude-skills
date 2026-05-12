"""Deterministic schedule-plan calculation for delivery-estimator."""

from __future__ import annotations

import math
from datetime import date
from typing import Any

from schedule_common import (
    DEFAULT_REBASELINE_RULES,
    EstimateError,
    WorkCalendar,
    Z_P80,
    Z_P95,
    as_list,
    pert,
    read_estimate,
    rounded,
)


def normalize_tasks(payload: dict[str, Any]) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]]]:
    tasks = payload.get("tasks")
    if not isinstance(tasks, list) or not tasks:
        raise EstimateError("tasks must be a non-empty array")
    normalized: list[dict[str, Any]] = []
    by_id: dict[str, dict[str, Any]] = {}
    for index, task in enumerate(tasks, start=1):
        if not isinstance(task, dict):
            raise EstimateError(f"task #{index} must be an object")
        task_id = str(task.get("id") or "").strip()
        if not task_id:
            raise EstimateError(f"task #{index} missing id")
        if task_id in by_id:
            raise EstimateError(f"duplicate task id: {task_id}")
        item = dict(task)
        item["id"] = task_id
        item["depends_on"] = [str(dep) for dep in task.get("depends_on", [])]
        item["outputs"] = [str(output) for output in as_list(task.get("outputs"))]
        item["inputs"] = [str(input_item) for input_item in as_list(task.get("inputs"))]
        normalized.append(item)
        by_id[task_id] = item
    for task in normalized:
        for dependency in task["depends_on"]:
            if dependency not in by_id:
                raise EstimateError(f"{task['id']} has unknown dependency: {dependency}")
    return normalized, by_id


def topological_order(tasks: list[dict[str, Any]], by_id: dict[str, dict[str, Any]]) -> list[str]:
    visiting: set[str] = set()
    visited: set[str] = set()
    order: list[str] = []

    def visit(task_id: str) -> None:
        if task_id in visited:
            return
        if task_id in visiting:
            raise EstimateError(f"cycle detected at task: {task_id}")
        visiting.add(task_id)
        for dependency in by_id[task_id]["depends_on"]:
            visit(dependency)
        visiting.remove(task_id)
        visited.add(task_id)
        order.append(task_id)

    for task in tasks:
        visit(task["id"])
    return order


def best_predecessor(dependencies: list[str], metrics: dict[str, dict[str, Any]]) -> str | None:
    return max(dependencies, key=lambda item: metrics[item]["earliest_finish"]) if dependencies else None


def build_metrics(order: list[str], by_id: dict[str, dict[str, Any]]) -> dict[str, dict[str, Any]]:
    metrics: dict[str, dict[str, Any]] = {}
    for task_id in order:
        task = by_id[task_id]
        human_expected, human_sigma, _ = pert(read_estimate(task.get("human_hours"), "human_hours", task_id))
        elapsed_expected, elapsed_sigma, elapsed_variance = pert(
            read_estimate(task.get("elapsed_hours"), "elapsed_hours", task_id)
        )
        predecessor = best_predecessor(task["depends_on"], metrics)
        start = metrics[predecessor]["earliest_finish"] if predecessor else 0.0
        path_variance = (metrics[predecessor]["path_variance"] if predecessor else 0.0) + elapsed_variance
        metrics[task_id] = {
            "task_id": task_id,
            "wbs_id": str(task.get("wbs_id") or task_id),
            "title": str(task.get("title", task_id)),
            "stage": str(task.get("stage", "unspecified")),
            "owner": str(task.get("owner", "delivery owner")),
            "resource": str(task.get("resource", "human + AI agent")),
            "status": str(task.get("status", "not_started")),
            "percent_complete": int(task.get("percent_complete", 0)),
            "depends_on": task["depends_on"],
            "parallelizable": bool(task.get("parallelizable", False)),
            "inputs": task["inputs"],
            "outputs": task["outputs"],
            "acceptance": str(task.get("acceptance", "-")),
            "review_gate": str(task.get("review_gate", "-")),
            "agent_assignment": str(task.get("agent_assignment", "-")),
            "milestone": bool(task.get("milestone", False)),
            "risks": as_list(task.get("risks")),
            "human_hours_p50": human_expected,
            "human_sigma": human_sigma,
            "elapsed_hours_p50": elapsed_expected,
            "elapsed_sigma": elapsed_sigma,
            "earliest_start": start,
            "earliest_finish": start + elapsed_expected,
            "path_variance": path_variance,
            "predecessor": predecessor,
        }
    return metrics


def apply_backward_pass(order: list[str], metrics: dict[str, dict[str, Any]], project_finish: float) -> None:
    successors = {task_id: [] for task_id in order}
    for task_id in order:
        for dependency in metrics[task_id]["depends_on"]:
            successors[dependency].append(task_id)
    for task_id in reversed(order):
        next_tasks = successors[task_id]
        latest_finish = min(metrics[item]["latest_start"] for item in next_tasks) if next_tasks else project_finish
        latest_start = latest_finish - metrics[task_id]["elapsed_hours_p50"]
        total_float = max(0.0, latest_start - metrics[task_id]["earliest_start"])
        metrics[task_id].update(
            {
                "successors": next_tasks,
                "latest_start": latest_start,
                "latest_finish": latest_finish,
                "total_float_hours": total_float,
                "critical": total_float <= 0.01,
            }
        )


def critical_path(metrics: dict[str, dict[str, Any]]) -> tuple[list[str], float, float]:
    end_task = max(metrics, key=lambda item: metrics[item]["earliest_finish"])
    path: list[str] = []
    current: str | None = end_task
    while current:
        path.append(current)
        current = metrics[current]["predecessor"]
    path.reverse()
    return path, metrics[end_task]["earliest_finish"], metrics[end_task]["path_variance"]


def build_waves(order: list[str], metrics: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    levels: dict[str, int] = {}
    for task_id in order:
        deps = metrics[task_id]["depends_on"]
        levels[task_id] = max((levels[dep] + 1 for dep in deps), default=1)
    waves: list[dict[str, Any]] = []
    for level in sorted(set(levels.values())):
        task_ids = [task_id for task_id in order if levels[task_id] == level]
        parallel_workstreams = sum(1 for item in task_ids if metrics[item]["parallelizable"])
        agent_task_count = sum(
            1
            for item in task_ids
            if metrics[item]["agent_assignment"] not in ("-", "none")
            and (metrics[item]["parallelizable"] or len(task_ids) == 1)
        )
        agents = sorted(
            {metrics[item]["agent_assignment"] for item in task_ids if metrics[item]["agent_assignment"] not in ("-", "none")}
        )
        gates = [metrics[item]["review_gate"] for item in task_ids if metrics[item]["review_gate"] != "-"]
        waves.append(
            {
                "wave": level,
                "task_ids": task_ids,
                "max_parallel_workstreams": max(1, parallel_workstreams),
                "max_parallel_agents": max(1, parallel_workstreams),
                "max_parallel_ai_agents": agent_task_count,
                "agent_assignments": agents,
                "review_gates": gates,
                "note": "parallel where dependencies and shared-state boundaries allow",
            }
        )
    return waves


def rollup_by_stage(order: list[str], metrics: dict[str, dict[str, Any]], calendar: WorkCalendar) -> dict[str, dict[str, Any]]:
    rollup: dict[str, dict[str, Any]] = {}
    for task_id in order:
        item = metrics[task_id]
        target = rollup.setdefault(item["stage"], {"human": 0.0, "elapsed": 0.0, "outputs": [], "start": [], "finish": []})
        target["human"] += item["human_hours_p50"]
        target["elapsed"] += item["elapsed_hours_p50"]
        target["outputs"].extend(str(output) for output in item["outputs"])
        target["start"].append(item["earliest_start"])
        target["finish"].append(item["earliest_finish"])
    return {
        stage: {
            "human_hours_p50": rounded(values["human"]),
            "elapsed_hours_p50": rounded(values["elapsed"]),
            "start_date": calendar.start_date_for(min(values["start"])),
            "finish_date": calendar.finish_date_for(max(values["finish"])),
            "outputs": values["outputs"],
        }
        for stage, values in rollup.items()
    }


def normalize_risk(task_id: str, stage: str, risk: Any, index: int) -> dict[str, Any]:
    if isinstance(risk, dict):
        title = str(risk.get("title") or risk.get("risk") or risk.get("description") or f"risk {index}")
        return {
            "task_id": task_id,
            "stage": stage,
            "risk_id": str(risk.get("id") or f"{task_id}-R{index}"),
            "title": title,
            "trigger": str(risk.get("trigger", "-")),
            "probability": str(risk.get("probability", "-")),
            "impact": str(risk.get("impact", "-")),
            "buffer_hours": rounded(float(risk.get("buffer_hours", 0) or 0)),
            "mitigation": str(risk.get("mitigation", "-")),
            "owner": str(risk.get("owner", "-")),
        }
    return {
        "task_id": task_id,
        "stage": stage,
        "risk_id": f"{task_id}-R{index}",
        "title": str(risk),
        "trigger": "-",
        "probability": "-",
        "impact": "-",
        "buffer_hours": 0.0,
        "mitigation": "-",
        "owner": "-",
    }


def risk_register(order: list[str], metrics: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    risks: list[dict[str, Any]] = []
    for task_id in order:
        item = metrics[task_id]
        for index, risk in enumerate(item["risks"], start=1):
            risks.append(normalize_risk(task_id, item["stage"], risk, index))
    return risks


def build_milestones(payload: dict[str, Any], metrics: dict[str, dict[str, Any]], calendar: WorkCalendar) -> list[dict[str, Any]]:
    raw = as_list(payload.get("milestones"))
    if not raw:
        raw = [
            {"id": f"M{index}", "title": item["title"], "task_id": task_id, "owner": item["owner"]}
            for index, (task_id, item) in enumerate(metrics.items(), start=1)
            if item["milestone"]
        ]
    milestones: list[dict[str, Any]] = []
    for index, item in enumerate(raw, start=1):
        if not isinstance(item, dict):
            continue
        task_id = str(item.get("task_id", ""))
        planned = str(item.get("planned_date") or item.get("date") or "")
        if task_id in metrics:
            planned = calendar.finish_date_for(metrics[task_id]["earliest_finish"])
        milestones.append(
            {
                "milestone_id": str(item.get("id") or f"M{index}"),
                "title": str(item.get("title") or item.get("name") or f"Milestone {index}"),
                "planned_date": planned or calendar.start.isoformat(),
                "owner": str(item.get("owner", "-")),
                "exit_criteria": str(item.get("exit_criteria") or item.get("done") or "-"),
                "evidence": str(item.get("evidence", "-")),
                "task_id": task_id or "-",
            }
        )
    return milestones


def public_task(item: dict[str, Any], calendar: WorkCalendar) -> dict[str, Any]:
    return {
        "task_id": item["task_id"],
        "wbs_id": item["wbs_id"],
        "title": item["title"],
        "stage": item["stage"],
        "owner": item["owner"],
        "resource": item["resource"],
        "status": item["status"],
        "percent_complete": item["percent_complete"],
        "depends_on": item["depends_on"],
        "successors": item.get("successors", []),
        "inputs": item["inputs"],
        "outputs": item["outputs"],
        "acceptance": item["acceptance"],
        "review_gate": item["review_gate"],
        "agent_assignment": item["agent_assignment"],
        "risks": [risk["title"] if isinstance(risk, dict) else str(risk) for risk in item["risks"]],
        "human_hours_p50": rounded(item["human_hours_p50"]),
        "elapsed_hours_p50": rounded(item["elapsed_hours_p50"]),
        "earliest_start": rounded(item["earliest_start"]),
        "earliest_finish": rounded(item["earliest_finish"]),
        "total_float_hours": rounded(item.get("total_float_hours", 0.0)),
        "critical": bool(item.get("critical", False)),
        "parallelizable": item["parallelizable"],
        "schedule": {
            "start_date": calendar.start_date_for(item["earliest_start"]),
            "finish_date": calendar.finish_date_for(item["earliest_finish"]),
            "duration_working_days": calendar.duration_days(item["elapsed_hours_p50"]),
        },
    }


def baseline(payload: dict[str, Any]) -> dict[str, str]:
    block = payload.get("baseline") if isinstance(payload.get("baseline"), dict) else {}
    return {
        "version": str(block.get("version", "v0")),
        "data_date": str(block.get("data_date", payload.get("project_start_date", date.today().isoformat()))),
        "status": str(block.get("status", "draft")),
    }


def build_result(payload: dict[str, Any]) -> dict[str, Any]:
    calendar = WorkCalendar(payload)
    tasks, by_id = normalize_tasks(payload)
    order = topological_order(tasks, by_id)
    metrics = build_metrics(order, by_id)
    path, p50_hours, variance = critical_path(metrics)
    apply_backward_pass(order, metrics, p50_hours)
    sigma = math.sqrt(variance)
    p80_hours = p50_hours + Z_P80 * sigma
    p95_hours = p50_hours + Z_P95 * sigma
    total_human = sum(metrics[task_id]["human_hours_p50"] for task_id in order)
    waves = build_waves(order, metrics)
    commitment_dates = {
        "p50": calendar.finish_date_for(p50_hours),
        "p80": calendar.finish_date_for(p80_hours),
        "p95": calendar.finish_date_for(p95_hours),
    }
    return {
        "summary": {
            "request_name": str(payload.get("request_name", "delivery-estimate")),
            "baseline": baseline(payload),
            "project_start_date": calendar.start.isoformat(),
            "task_count": len(order),
            "total_human_investment_hours": rounded(total_human),
            "max_parallel_workstreams": max(wave["max_parallel_workstreams"] for wave in waves),
            "max_parallel_ai_agents": max(wave["max_parallel_ai_agents"] for wave in waves),
            "critical_path_elapsed_hours_p50": rounded(p50_hours),
            "delivery_window_hours": {
                "p50": rounded(p50_hours),
                "p80": rounded(p80_hours),
                "p95": rounded(p95_hours),
                "risk_buffer_p80_minus_p50": rounded(p80_hours - p50_hours),
            },
            "delivery_window_days": {
                "p50": rounded(p50_hours / calendar.hours_per_day),
                "p80": rounded(p80_hours / calendar.hours_per_day),
                "p95": rounded(p95_hours / calendar.hours_per_day),
            },
            "commitment_dates": commitment_dates,
            "commitment_recommendation": f"建议承诺 P80：{commitment_dates['p80']}；P95 {commitment_dates['p95']} 作为风险暴露。",
        },
        "confidence_model": {"method": "PERT critical path", "p80_z_score": Z_P80, "p95_z_score": Z_P95},
        "critical_path": {
            "task_ids": path,
            "sigma_hours": rounded(sigma),
            "float_hours_by_task": {task_id: rounded(metrics[task_id].get("total_float_hours", 0.0)) for task_id in order},
        },
        "parallel_waves": waves,
        "stage_rollup": rollup_by_stage(order, metrics, calendar),
        "tasks": [public_task(metrics[task_id], calendar) for task_id in order],
        "milestones": build_milestones(payload, metrics, calendar),
        "risk_register": risk_register(order, metrics),
        "rebaseline_rules": [str(item) for item in as_list(payload.get("rebaseline_rules"))] or DEFAULT_REBASELINE_RULES,
        "assumptions": [str(item) for item in as_list(payload.get("assumptions"))],
    }
