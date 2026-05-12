# Schedule Plan

> Markdown 由 `scripts/estimate_schedule.py --markdown` 生成；JSON 结果是可复验真源。本模板定义人类可读排期计划包的必备结构。

## 一页结论

- baseline：{baseline.version} / data date：{baseline.data_date} / status：{baseline.status}
- project_start_date：{project_start_date}
- 交付日期：P50：{commitment_dates.p50}；P80：{commitment_dates.p80}；P95：{commitment_dates.p95}
- 推荐承诺：{commitment_recommendation}
- 人类投入：{total_human_investment_hours} 小时；最大并行工作流：{max_parallel_workstreams}；最大 AI agents 并发：{max_parallel_ai_agents}
- 关键路径：{critical_path.task_ids}
- 风险缓冲：P80-P50 = {risk_buffer_hours} 小时

## 甘特图

```mermaid
gantt
  title {request_name}
  dateFormat  YYYY-MM-DD HH:mm
  axisFormat  %m-%d %H:%M
  excludes    weekends
  section {stage}
  {task.title} :{crit}, {task_id}, {start_or_after_dependency}, {duration_minutes}m
  section Milestones
  {milestone.title} :milestone, {milestone_id}, {planned_date_or_after_task}, 0d
```

## WBS 字典

| WBS | Task | Work package / activity | Owner | Resource | Inputs | Deliverables | Acceptance | Status | % |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: |
| {wbs_id} | {task_id} | {title} | {owner} | {resource} | {inputs} | {outputs} | {acceptance} | {status} | {percent_complete} |

## 里程碑计划

| Milestone | Title | Planned date | Owner | Exit criteria | Evidence |
| --- | --- | --- | --- | --- | --- |
| {milestone_id} | {title} | {planned_date} | {owner} | {exit_criteria} | {evidence} |

## 依赖与关键路径

- 关键路径：{critical_path.task_ids}

| Task | Predecessors | Successors | Float h | Critical | Review gate |
| --- | --- | --- | ---: | --- | --- |
| {task_id} | {depends_on} | {successors} | {total_float_hours} | {critical} | {review_gate} |

## 资源与 AI-Agent 计划

| Wave | Task refs | Max parallel workstreams | Max AI agents | Agent assignments | Review gates |
| ---: | --- | ---: | ---: | --- | --- |
| {wave} | {task_ids} | {max_parallel_workstreams} | {max_parallel_ai_agents} | {agent_assignments} | {review_gates} |

## 环节投入与产出

| Stage | Start | Finish | Human h | Elapsed P50 h | Outputs |
| --- | --- | --- | ---: | ---: | --- |
| {stage} | {start_date} | {finish_date} | {human_hours_p50} | {elapsed_hours_p50} | {outputs} |

## 风险、缓冲与重估

| Risk | Task | Trigger | Probability | Impact | Buffer h | Mitigation | Owner |
| --- | --- | --- | --- | --- | ---: | --- | --- |
| {risk_id} {title} | {task_id} | {trigger} | {probability} | {impact} | {buffer_hours} | {mitigation} | {owner} |

### 重估 / Rebaseline 规则

- scope or AC changes
- critical path task fails verification
- external dependency or readiness task fails
- QA main path fails
- verification rounds exceed estimate assumptions

### 假设

- {assumption}
