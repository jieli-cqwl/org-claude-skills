# 证据与跟进

Trigger: 不确定证据能否推进、是否失效、如何回派时读取。
Read: executor 结论、evidence refs、diff/命令/报告、后续变更、retry history。
Expect: evidence decision、follow-up packet、无增量退出动作。
Consume: `流程/Observe`、`流程/Control`、`流程/Follow up`。
Evidence: 证据缺口、新增量记录、下一步 owner。
Sync: 证据标准、freshness 或 follow-up 规则变化时同步。

## 证据合格线

推进状态前回答五个问题：

| 标准 | 问题 | 不满足时 |
| --- | --- |
| direct | 是否直接回答当前 gap | 回派，要求补对应证据 |
| fresh | 是否仍有效 | 重跑验证或重派受影响角色 |
| traceable | 是否可追溯到文件、命令、报告、diff 或日志 | 要求补 evidence ref |
| role-owned | 是否由正确 role 产出 | 重派给正确 owner |
| actionable | 失败时是否给出可执行下一步 | 要求补最小下一步 |

## Freshness 传播

真实交付里，后续动作会让旧证据失效：

- fix 改代码后，旧 review、qa、verify 默认重新判定。
- plan/tasks/AC 变化后，旧 task packet 和验收证据默认重新判定。
- 环境、数据、feature flag 或依赖变化后，旧运行证据降级为参考。
- 只改文档但影响用户承诺时，qa 或 authority 证据也要重新判断。

## 回派包

不要写“继续处理”。回派必须带差距：

```text
missing_gap:
why_current_evidence_is_insufficient:
bounded_scope:
expected_new_evidence:
stop_condition:
```

## 无增量处理

连续一轮没有新增证据、修复、判断、阻塞或风险时：

1. packet 是否太大或目标不清：改 packet。
2. owner 是否不匹配：重派。
3. 是否缺权限、环境或资源：`NEEDS_RESOURCE`。
4. 是否触及 scope、AC、技术基线或业务风险：升级。
5. 仍无法推进：停止，给出阻塞证据和需要裁决的人。
