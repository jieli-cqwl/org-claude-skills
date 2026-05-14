"""Markdown renderer for delivery-estimator schedule plans."""

from __future__ import annotations

from typing import Any


STATUS_LABELS = {
    "draft": "草案",
    "in_progress": "进行中",
    "verified": "已验证",
    "complete": "已完成",
    "completed": "已完成",
    "done": "已完成",
    "not_started": "未开始",
    "blocked": "阻塞",
}

LEVEL_LABELS = {
    "low": "低",
    "medium": "中",
    "high": "高",
}

RESOURCE_LABELS = {
    "human": "人工",
    "none": "无",
}

COMMON_TEXT_LABELS = {
    "delivery owner": "交付负责人",
    "test designer": "测试设计负责人",
    "architect": "架构负责人",
    "developer": "开发负责人",
    "developer agent": "开发 agent",
    "verifier agent": "验证 agent",
    "test-design agent": "测试设计 agent",
    "human scope decision": "人工范围决策",
    "human test review": "人工测试评审",
    "human architecture review": "人工架构评审",
    "human code review": "人工代码评审",
    "human release decision": "人工发布决策",
}

STAGE_LABELS = {
    "PM": "产品/范围",
    "QA": "质量验收",
    "discovery": "调研",
    "design": "方案设计",
    "test-design": "测试设计",
    "developer": "开发",
    "implementation": "实现",
    "integration": "集成",
    "verification": "验证",
}

RISK_SCORE = {"-": 0, "low": 1, "medium": 2, "high": 3}


def localized_common_text(value: str) -> str:
    return COMMON_TEXT_LABELS.get(value, value)


def localized_scalar(value: Any) -> str:
    if isinstance(value, bool):
        return "是" if value else "否"
    if value in (None, ""):
        return "-"
    text = str(value)
    label = STATUS_LABELS.get(text, LEVEL_LABELS.get(text, RESOURCE_LABELS.get(text, text)))
    return localized_common_text(label)


def localized_stage(value: Any) -> str:
    text = str(value) if value not in (None, "") else "-"
    return STAGE_LABELS.get(text, text)


def localized_resource(value: Any) -> str:
    text = localized_scalar(value)
    parts = [localized_scalar(part.strip()) for part in text.split(" + ")]
    return " + ".join(parts)


def md_cell(value: Any) -> str:
    if isinstance(value, list):
        text = ", ".join(localized_scalar(item) for item in value if str(item)) if value else "-"
    else:
        text = localized_scalar(value)
    return text.replace("|", "\\|").replace("\n", " ")


def md_bullets(items: list[Any]) -> str:
    return "".join(f"- {md_cell(item)}\n" for item in items) if items else "- 无\n"


def compact_number(value: Any) -> str:
    number = float(value)
    return f"{number:.2f}".rstrip("0").rstrip(".")


def hours(value: Any) -> str:
    return f"{compact_number(value)} 小时"


def duration_hours(value: Any) -> str:
    return f"{compact_number(value)}h"


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
        lines.append(f"  section {mermaid_label(localized_stage(stage))}")
        for task in [item for item in result["tasks"] if item["stage"] == stage]:
            prefix = "crit, " if task["critical"] else ""
            start = "after " + " ".join(task["depends_on"]) if task["depends_on"] else project_start
            lines.append(
                f"  {mermaid_label(task['title'])} :{prefix}{task['task_id']}, {start}, {gantt_duration(task)}"
            )
    if result["milestones"]:
        lines.append("  section 里程碑")
        for item in result["milestones"]:
            anchor = f"after {item['task_id']}" if item["task_id"] != "-" else item["planned_date"]
            lines.append(f"  {mermaid_label(item['title'])} :milestone, {item['milestone_id']}, {anchor}, 0d")
    return lines + ["```"]


def critical_path_text(result: dict[str, Any]) -> str:
    return " -> ".join(result["critical_path"]["task_ids"]) or "-"


def risk_rank(risk: dict[str, Any]) -> tuple[int, int, float]:
    probability = RISK_SCORE.get(str(risk.get("probability", "-")), 0)
    impact = RISK_SCORE.get(str(risk.get("impact", "-")), 0)
    return impact, probability, float(risk.get("buffer_hours", 0) or 0)


def top_risk_text(result: dict[str, Any]) -> str:
    risks = result["risk_register"]
    if not risks:
        return "无"
    risk = max(risks, key=risk_rank)
    trigger = md_cell(risk["trigger"])
    mitigation = md_cell(risk["mitigation"])
    return f"{md_cell(risk['risk_id'] + ' ' + risk['title'])}；触发：{trigger}；应对：{mitigation}"


def boss_one_liner(result: dict[str, Any]) -> str:
    summary = result["summary"]
    return (
        f"> 老板版一句话：建议承诺 {summary['commitment_dates']['p80']}，"
        f"P95 风险暴露到 {summary['commitment_dates']['p95']}；"
        f"人工投入 {hours(summary['total_human_investment_hours'])}，"
        f"最大 AI 并发 {summary['max_parallel_ai_agents']}。"
    )


def table_row(values: list[Any]) -> str:
    return "| " + " | ".join(md_cell(value) for value in values) + " |"


def render_decision_summary(result: dict[str, Any]) -> list[str]:
    summary = result["summary"]
    rows = [
        ["对外承诺建议", summary["commitment_recommendation"]],
        ["承诺口径", "对外按 P80 日期承诺；P95 日期只作为风险暴露，不作为默认承诺。"],
        ["交付日期", f"P50：{summary['commitment_dates']['p50']}；P80：{summary['commitment_dates']['p80']}；P95：{summary['commitment_dates']['p95']}"],
        ["人类投入", hours(summary["total_human_investment_hours"])],
        ["最大并行工作流 / AI 并发", f"{summary['max_parallel_workstreams']} / {summary['max_parallel_ai_agents']}"],
        ["关键路径", critical_path_text(result)],
        ["首要风险", top_risk_text(result)],
    ]
    return [
        "| 关注点 | 结论 |",
        "| --- | --- |",
        *(table_row(row) for row in rows),
    ]


def render_key_metrics(result: dict[str, Any]) -> list[str]:
    summary = result["summary"]
    window = summary["delivery_window_hours"]
    rows = [
        ["P50 交付日期", summary["commitment_dates"]["p50"], "中位交付窗口"],
        ["P80 交付日期", summary["commitment_dates"]["p80"], "推荐用于对外承诺"],
        ["P95 交付日期", summary["commitment_dates"]["p95"], "用于暴露高风险窗口"],
        ["P50 / P80 / P95 周期", f"{window['p50']} / {window['p80']} / {window['p95']} 小时", "基于关键路径 PERT"],
        ["人类投入", hours(summary["total_human_investment_hours"]), "不等同交付 wall-clock"],
        ["最大并行工作流", summary["max_parallel_workstreams"], "同一批次可并行推进的任务数"],
        ["最大 AI agents 并发", summary["max_parallel_ai_agents"], "同一批次建议投入的 AI agent 数"],
        ["风险缓冲", hours(window["risk_buffer_p80_minus_p50"]), "P80 - P50"],
    ]
    return [
        "| 指标 | 数值 | 说明 |",
        "| --- | --- | --- |",
        *(table_row(row) for row in rows),
    ]


def render_task_overview(result: dict[str, Any]) -> list[str]:
    lines = [
        "| WBS | 任务 | 负责人 | 资源 | 开始 | 完成 | 工期 | 状态 | 关键 | 产出 |",
        "| --- | --- | --- | --- | --- | --- | ---: | --- | --- | --- |",
    ]
    for task in result["tasks"]:
        lines.append(
            table_row(
                [
                    task["wbs_id"],
                    task["task_id"],
                    task["title"],
                    task["owner"],
                    localized_resource(task["resource"]),
                    task["schedule"]["start_date"],
                    task["schedule"]["finish_date"],
                    duration_hours(task["elapsed_hours_p50"]),
                    task["status"],
                    task["critical"],
                    task["outputs"],
                ]
            )
        )
    return lines


def render_markdown(result: dict[str, Any]) -> str:
    summary = result["summary"]
    base = summary["baseline"]
    meta = (
        f"计划基线：{base['version']}｜数据日期：{base['data_date']}｜"
        f"计划状态：{md_cell(base['status'])}｜起始日期：{summary['project_start_date']}"
    )
    lines = [
        f"# 项目排期计划｜{summary['request_name']}",
        "",
        meta,
        "",
        boss_one_liner(result),
        "",
        "## 01｜决策摘要",
        "",
        *render_decision_summary(result),
        "",
        "## 02｜关键指标",
        "",
        *render_key_metrics(result),
        "",
        "## 03｜甘特图",
        "",
        *render_gantt(result),
        "",
        "## 04｜任务排期总览",
        "",
        *render_task_overview(result),
        "",
        "## 05｜里程碑",
        "",
        "| 里程碑 | 标题 | 计划日期 | 负责人 | 退出条件 | 证据 |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for item in result["milestones"]:
        lines.append(
            table_row(
                [
                    item["milestone_id"],
                    item["title"],
                    item["planned_date"],
                    item["owner"],
                    item["exit_criteria"],
                    item["evidence"],
                ]
            )
        )
    lines += [
        "",
        "## 06｜关键路径与依赖",
        "",
        f"- 关键路径：{critical_path_text(result)}",
        "",
        "| 任务 | 前置任务 | 后续任务 | 浮动时间(h) | 关键 | 人工关口 |",
        "| --- | --- | --- | ---: | --- | --- |",
    ]
    for task in result["tasks"]:
        lines.append(
            table_row(
                [
                    task["task_id"],
                    task["depends_on"],
                    task["successors"],
                    task["total_float_hours"],
                    task["critical"],
                    task["review_gate"],
                ]
            )
        )
    lines += [
        "",
        "## 07｜资源与 Agent 批次",
        "",
        "| 批次 | 任务 | 并行工作流 | AI Agent数 | Agent分配 | 人工关口 |",
        "| ---: | --- | ---: | ---: | --- | --- |",
    ]
    for wave in result["parallel_waves"]:
        lines.append(
            table_row(
                [
                    wave["wave"],
                    wave["task_ids"],
                    wave["max_parallel_workstreams"],
                    wave["max_parallel_ai_agents"],
                    wave["agent_assignments"],
                    wave["review_gates"],
                ]
            )
        )
    lines += [
        "",
        "## 08｜环节投入与产出",
        "",
        "| 环节 | 开始 | 完成 | 人工投入 | P50 周期 | 产出 |",
        "| --- | --- | --- | ---: | ---: | --- |",
    ]
    for stage, values in result["stage_rollup"].items():
        lines.append(
            table_row(
                [
                    localized_stage(stage),
                    values["start_date"],
                    values["finish_date"],
                    hours(values["human_hours_p50"]),
                    hours(values["elapsed_hours_p50"]),
                    values["outputs"],
                ]
            )
        )
    lines += [
        "",
        "## 09｜风险与重估",
        "",
        "| 风险 | 任务 | 触发条件 | 概率 | 影响 | 缓冲(h) | 应对 | 负责人 |",
        "| --- | --- | --- | --- | --- | ---: | --- | --- |",
    ]
    for risk in result["risk_register"]:
        lines.append(
            table_row(
                [
                    risk["risk_id"] + " " + risk["title"],
                    risk["task_id"],
                    risk["trigger"],
                    risk["probability"],
                    risk["impact"],
                    risk["buffer_hours"],
                    risk["mitigation"],
                    risk["owner"],
                ]
            )
        )
    lines += ["", "### 重估 / Rebaseline 规则", "", md_bullets(result["rebaseline_rules"]).rstrip()]
    lines += [
        "",
        "### 不建议承诺条件",
        "",
        "- 范围或 AC 尚未冻结。",
        "- 关键路径任务验证失败，或验证轮次超过当前估算假设。",
        "- 高影响风险没有 owner、缓冲或应对动作。",
    ]
    lines += ["", "### 假设", "", md_bullets(result["assumptions"]).rstrip(), ""]
    return "\n".join(lines)
