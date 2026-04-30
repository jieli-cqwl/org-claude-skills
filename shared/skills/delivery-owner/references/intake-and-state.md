# 接手与状态

Trigger: 接手条件、状态优先级或当前状态不清时读取。
Read: plan/tasks、版本、scope、AC、依赖、可用资源、已有证据。
Expect: 接手结论、当前最高优先级 gap、最小状态卡。
Consume: `输入识别`、`流程/Intake`、`流程/Pick`。
Evidence: `ACCEPTED / NEEDS_BASELINE / NEEDS_INPUT / NEEDS_RESOURCE` 和对应缺口。
Sync: 接手门槛、状态字段或 authority 边界变化时同步。

## 接手判断

交付负责人只接手已经可执行的计划，不负责把计划补成计划。

| 结论 | 判断 | 下一步 |
| --- | --- | --- |
| `ACCEPTED` | plan/tasks 冻结，scope、AC、依赖、证据入口和资源足够 | 建状态卡 |
| `NEEDS_BASELINE` | 目标、scope、AC、依赖、技术基线或 task 本身不清 | 交回 `tech-lead / product / user` |
| `NEEDS_INPUT` | 基线存在，但缺路径、版本、工作区或证据引用 | 请求补输入 |
| `NEEDS_RESOURCE` | 缺 executor、权限、环境、工具或账号 | 请求补资源 |

## 状态优先级

真实交付中先处理会让后续证据失效的问题：

```text
rebaseline_needed / authority_unclear
> blocked
> needs_rework
> in_progress
> evidence_ready
> signoff_ready
```

示例：

- fix 改了代码，旧 review/qa 证据先降级，状态回到 `needs_rework` 或 `in_progress`。
- AC 与实现范围冲突，状态是 `rebaseline_needed`，不是继续派 developer。
- QA PASS 但用户风险接受未明确，状态是 `authority_unclear`，不是 `business_signed_off`。

## 状态卡写法

只保留控制字段：

```text
plan_ref:
task_ref:
state:
owner:
gap:
evidence_refs:
increment:
gap_delta:
packet_delta:
loop_state:
decision:
next_action:
blocked_by:
```

不要复制长报告。需要细节时读取 evidence ref。
