# Routing And Packet

Trigger: 缺口责任域、executor 或 task packet 写法不清时读取。
Read: current gap、task_ref、scope、AC、可用 executor 和现有证据。
Expect: role 路由、owner 决策、packet 质量规则。
Consume: `Route / Packet / Dispatch` 步骤。
Evidence: owner 决策、task packet ref、重派原因。
Sync: 角色边界、executor 类型或 packet 字段变化时同步。

## 路由规则

固定顺序：

```text
gap -> role responsibility -> available executor -> task packet -> evidence
```

先判定责任域，再选择执行载体。executor 可以是 role subagent、当前模型使用对应 skill、确定性脚本，或必须由人类 authority 决策的对象。

## 常见路由

| Gap | Role |
| --- | --- |
| AC 行为未实现 | developer |
| 实现后需要独立验收 task scope / AC | verify |
| 代码质量、回归、可维护性风险 | review |
| 用户路径、真实运行、发布风险 | qa |
| 已知失败需要根因和最小修复 | fix |
| 跨工件漂移或追踪矛盾 | consistency-audit |
| task、scope、AC、依赖、技术基线不清 | tech-lead |
| 业务范围、风险接受、最终签收不清 | user / product / authority |

## Packet 合格线

每次派发必须包含：

```text
task_ref
role
goal
scope
input_refs
expected_evidence
stop_condition
forbidden_actions
```

不合格 packet 示例：

- `scope: 按需处理`
- `expected_evidence: 完成即可`
- 缺 `stop_condition`
- 缺 `forbidden_actions`
- 没有回指 `tech-lead` task

不合格时先修 packet，不派发。
