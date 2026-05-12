"""Markdown renderer for delivery-estimator schedule plans."""

from __future__ import annotations

from typing import Any


def md_cell(value: Any) -> str:
    if isinstance(value, list):
        text = ", ".join(str(item) for item in value if str(item)) if value else "-"
    elif isinstance(value, bool):
        text = "yes" if value else "no"
    else:
        text = str(value) if value not in (None, "") else "-"
    return text.replace("|", "\\|").replace("\n", " ")


def md_bullets(items: list[Any]) -> str:
    return "".join(f"- {item}\n" for item in items) if items else "- 无\n"


def mermaid_label(value: str) -> str:
    return value.replace(":", "-").replace("\n", " ")


def gantt_duration(task: dict[str, Any]) -> str:
    return f"{max(1, round(float(task['elapsed_hours_p50']) * 60))}m"


def render_gantt(result: dict[str, Any]) -> list[str]:
    project_start = result["summary"]["project_start_date"] + " 09:00"
    lines = [
        "```mermaid",
        "gantt",
        f"  title {mermaid_label(result['summary']['request_name'])}",
        "  dateFormat  YYYY-MM-DD HH:mm",
        "  axisFormat  %m-%d %H:%M",
        "  excludes    weekends",
    ]
    stages: list[str] = []
    for task in result["tasks"]:
        if task["stage"] not in stages:
            stages.append(task["stage"])
    for stage in stages:
        lines.append(f"  section {mermaid_label(stage)}")
        for task in [item for item in result["tasks"] if item["stage"] == stage]:
            prefix = "crit, " if task["critical"] else ""
            start = "after " + " ".join(task["depends_on"]) if task["depends_on"] else project_start
            lines.append(
                f"  {mermaid_label(task['title'])} :{prefix}{task['task_id']}, {start}, {gantt_duration(task)}"
            )
    if result["milestones"]:
        lines.append("  section Milestones")
        for item in result["milestones"]:
            anchor = f"after {item['task_id']}" if item["task_id"] != "-" else item["planned_date"]
            lines.append(f"  {mermaid_label(item['title'])} :milestone, {item['milestone_id']}, {anchor}, 0d")
    return lines + ["```"]


def render_markdown(result: dict[str, Any]) -> str:
    summary = result["summary"]
    base = summary["baseline"]
    critical_path_text = " -> ".join(result["critical_path"]["task_ids"])
    lines = [
        f"# Schedule Plan: {summary['request_name']}",
        "",
        "## 一页结论",
        "",
        f"- baseline：{base['version']} / data date：{base['data_date']} / status：{base['status']}",
        f"- project_start_date：{summary['project_start_date']}",
        f"- 交付日期：P50：{summary['commitment_dates']['p50']}；P80：{summary['commitment_dates']['p80']}；P95：{summary['commitment_dates']['p95']}",
        f"- 推荐承诺：{summary['commitment_recommendation']}",
        f"- 交付窗口：P50/P80/P95 = {summary['delivery_window_hours']['p50']} / {summary['delivery_window_hours']['p80']} / {summary['delivery_window_hours']['p95']} 小时",
        f"- 人类投入：{summary['total_human_investment_hours']} 小时；最大并行工作流：{summary['max_parallel_workstreams']}；最大 AI agents 并发：{summary['max_parallel_ai_agents']}",
        f"- 关键路径：{critical_path_text}",
        f"- 风险缓冲：P80-P50 = {summary['delivery_window_hours']['risk_buffer_p80_minus_p50']} 小时",
        "",
        "## 甘特图",
        "",
        *render_gantt(result),
        "",
        "## WBS 字典",
        "",
        "| WBS | Task | Work package / activity | Owner | Resource | Inputs | Deliverables | Acceptance | Status | % |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: |",
    ]
    for task in result["tasks"]:
        lines.append(
            "| "
            + " | ".join(
                md_cell(value)
                for value in [
                    task["wbs_id"],
                    task["task_id"],
                    task["title"],
                    task["owner"],
                    task["resource"],
                    task["inputs"],
                    task["outputs"],
                    task["acceptance"],
                    task["status"],
                    task["percent_complete"],
                ]
            )
            + " |"
        )
    lines += [
        "",
        "## 里程碑计划",
        "",
        "| Milestone | Title | Planned date | Owner | Exit criteria | Evidence |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for item in result["milestones"]:
        lines.append(
            f"| {md_cell(item['milestone_id'])} | {md_cell(item['title'])} | {md_cell(item['planned_date'])} | {md_cell(item['owner'])} | {md_cell(item['exit_criteria'])} | {md_cell(item['evidence'])} |"
        )
    lines += [
        "",
        "## 依赖与关键路径",
        "",
        f"- 关键路径：{critical_path_text}",
        "",
        "| Task | Predecessors | Successors | Float h | Critical | Review gate |",
        "| --- | --- | --- | ---: | --- | --- |",
    ]
    for task in result["tasks"]:
        lines.append(
            f"| {md_cell(task['task_id'])} | {md_cell(task['depends_on'])} | {md_cell(task['successors'])} | {task['total_float_hours']} | {md_cell(task['critical'])} | {md_cell(task['review_gate'])} |"
        )
    lines += [
        "",
        "## 资源与 AI-Agent 计划",
        "",
        "| Wave | Task refs | Max parallel workstreams | Max AI agents | Agent assignments | Review gates |",
        "| ---: | --- | ---: | ---: | --- | --- |",
    ]
    for wave in result["parallel_waves"]:
        lines.append(
            f"| {wave['wave']} | {md_cell(wave['task_ids'])} | {wave['max_parallel_workstreams']} | {wave['max_parallel_ai_agents']} | {md_cell(wave['agent_assignments'])} | {md_cell(wave['review_gates'])} |"
        )
    lines += [
        "",
        "## 环节投入与产出",
        "",
        "| Stage | Start | Finish | Human h | Elapsed P50 h | Outputs |",
        "| --- | --- | --- | ---: | ---: | --- |",
    ]
    for stage, values in result["stage_rollup"].items():
        lines.append(
            f"| {md_cell(stage)} | {values['start_date']} | {values['finish_date']} | {values['human_hours_p50']} | {values['elapsed_hours_p50']} | {md_cell(values['outputs'])} |"
        )
    lines += [
        "",
        "## 风险、缓冲与重估",
        "",
        "| Risk | Task | Trigger | Probability | Impact | Buffer h | Mitigation | Owner |",
        "| --- | --- | --- | --- | --- | ---: | --- | --- |",
    ]
    for risk in result["risk_register"]:
        lines.append(
            f"| {md_cell(risk['risk_id'] + ' ' + risk['title'])} | {md_cell(risk['task_id'])} | {md_cell(risk['trigger'])} | {md_cell(risk['probability'])} | {md_cell(risk['impact'])} | {risk['buffer_hours']} | {md_cell(risk['mitigation'])} | {md_cell(risk['owner'])} |"
        )
    lines += ["", "### 重估 / Rebaseline 规则", "", md_bullets(result["rebaseline_rules"]).rstrip()]
    lines += ["", "### 假设", "", md_bullets(result["assumptions"]).rstrip(), ""]
    return "\n".join(lines)
