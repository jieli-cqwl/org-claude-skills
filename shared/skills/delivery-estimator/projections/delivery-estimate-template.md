# 项目排期计划

> Markdown 由 `scripts/estimate_schedule.py --markdown` 生成；JSON 结果是可复验真源。本模板定义给业务、老板和交付负责人看的排期计划包结构。报告默认使用中文标题、中文表头、中文状态值；时间、文件路径、任务 ID、agent 名称和必要技术名词可保留原文。

计划基线：{baseline.version}｜数据日期：{baseline.data_date}｜计划状态：{baseline.status}｜起始日期：{project_start_date}

> 老板版一句话：建议承诺 {commitment_dates.p80}，P95 风险暴露到 {commitment_dates.p95}；人工投入 {total_human_investment_hours} 小时，最大 AI 并发 {max_parallel_ai_agents}。

## 01｜决策摘要

| 关注点 | 结论 |
| --- | --- |
| 对外承诺建议 | {commitment_recommendation} |
| 承诺口径 | 对外按 P80 日期承诺；P95 日期只作为风险暴露，不作为默认承诺。 |
| 交付日期 | P50：{commitment_dates.p50}；P80：{commitment_dates.p80}；P95：{commitment_dates.p95} |
| 人类投入 | {total_human_investment_hours} 小时 |
| 最大并行工作流 / AI 并发 | {max_parallel_workstreams} / {max_parallel_ai_agents} |
| 关键路径 | {critical_path.task_ids} |
| 首要风险 | {top_risk} |

## 02｜关键指标

| 指标 | 数值 | 说明 |
| --- | --- | --- |
| P50 交付日期 | {commitment_dates.p50} | 中位交付窗口 |
| P80 交付日期 | {commitment_dates.p80} | 推荐用于对外承诺 |
| P95 交付日期 | {commitment_dates.p95} | 用于暴露高风险窗口 |
| P50 / P80 / P95 周期 | {delivery_window_hours.p50} / {delivery_window_hours.p80} / {delivery_window_hours.p95} 小时 | 基于关键路径 PERT |
| 人类投入 | {total_human_investment_hours} 小时 | 不等同交付 wall-clock |
| 最大并行工作流 | {max_parallel_workstreams} | 同一批次可并行推进的任务数 |
| 最大 AI agents 并发 | {max_parallel_ai_agents} | 同一批次建议投入的 AI agent 数 |
| 风险缓冲 | {risk_buffer_hours} 小时 | P80 - P50 |

## 03｜甘特图

```mermaid
gantt
  title {request_name}
  dateFormat  YYYY-MM-DD HH:mm
  axisFormat  %m-%d %H:%M
  excludes    weekends
  section {stage}
  {task.title} :{crit}, {task_id}, {start_or_after_dependency}, {duration_minutes}m
  section 里程碑
  {milestone.title} :milestone, {milestone_id}, {planned_date_or_after_task}, 0d
```

## 04｜任务排期总览

| WBS | 任务 | 负责人 | 资源 | 开始 | 完成 | 工期 | 状态 | 关键 | 产出 |
| --- | --- | --- | --- | --- | --- | ---: | --- | --- | --- |
| {wbs_id} | {task_id} | {title} | {owner} | {resource} | {start_date} | {finish_date} | {elapsed_hours_p50}h | {status} | {critical} | {outputs} |

## 05｜里程碑

| 里程碑 | 标题 | 计划日期 | 负责人 | 退出条件 | 证据 |
| --- | --- | --- | --- | --- | --- |
| {milestone_id} | {title} | {planned_date} | {owner} | {exit_criteria} | {evidence} |

## 06｜关键路径与依赖

- 关键路径：{critical_path.task_ids}

| 任务 | 前置任务 | 后续任务 | 浮动时间(h) | 关键 | 人工关口 |
| --- | --- | --- | ---: | --- | --- |
| {task_id} | {depends_on} | {successors} | {total_float_hours} | {critical} | {review_gate} |

## 07｜资源与 Agent 批次

| 批次 | 任务 | 并行工作流 | AI Agent数 | Agent分配 | 人工关口 |
| ---: | --- | ---: | ---: | --- | --- |
| {wave} | {task_ids} | {max_parallel_workstreams} | {max_parallel_ai_agents} | {agent_assignments} | {review_gates} |

## 08｜环节投入与产出

| 环节 | 开始 | 完成 | 人工投入 | P50 周期 | 产出 |
| --- | --- | --- | ---: | ---: | --- |
| {stage} | {start_date} | {finish_date} | {human_hours_p50} 小时 | {elapsed_hours_p50} 小时 | {outputs} |

## 09｜风险与重估

| 风险 | 任务 | 触发条件 | 概率 | 影响 | 缓冲(h) | 应对 | 负责人 |
| --- | --- | --- | --- | --- | ---: | --- | --- |
| {risk_id} {title} | {task_id} | {trigger} | {probability} | {impact} | {buffer_hours} | {mitigation} | {owner} |

### 重估 / Rebaseline 规则

- scope or AC changes
- critical path task fails verification
- external dependency or readiness task fails
- QA main path fails
- verification rounds exceed estimate assumptions

### 不建议承诺条件

- 范围或 AC 尚未冻结。
- 关键路径任务验证失败，或验证轮次超过当前估算假设。
- 高影响风险没有 owner、缓冲或应对动作。

### 假设

- {assumption}
