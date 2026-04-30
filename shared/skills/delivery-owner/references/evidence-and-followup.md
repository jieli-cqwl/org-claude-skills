# Evidence And Follow-Up

Trigger: 证据质量、freshness、回派、重派或无增量循环不清时读取。
Read: evidence refs、产出角色、代码/scope/AC/环境/plan 变化、retry history。
Expect: evidence decision、follow-up packet 和无增量退出动作。
Consume: `Observe / Control` 步骤。
Evidence: 证据缺口、新增量记录、无增量原因和下一步 owner。
Sync: 证据标准、freshness 规则或循环退出规则变化时同步。

## 证据质量

可推进证据应满足：

| 标准 | 判断问题 |
| --- | --- |
| direct | 是否直接回答当前 gap |
| fresh | 是否未被后续代码、scope、AC、环境或 plan 变化失效 |
| traceable | 是否能追到文件、命令、报告、日志、diff 或 decision ref |
| role-owned | 是否由正确责任角色产出 |
| actionable | 失败或不足时是否给出下一步 owner 和动作 |

任一项不足时，不直接推进；先回派、重派或升级。

## 证据失效传播

- fix 修改代码后，旧 review / qa / verify 证据默认需要重新判定 freshness。
- plan/tasks 或 AC 变化后，旧 task packet 和验收证据默认需要重新判定。
- 环境、数据、feature flag 或依赖变化后，旧运行证据降级为参考。

## 回派格式

```text
missing_gap:
why_current_evidence_is_insufficient:
bounded_scope:
expected_new_evidence:
stop_condition:
```

每轮必须产生新增证据、修复、判断、阻塞、风险或 authority 决策。没有新增量时，选择重派、改 packet、升级或 rebaseline，不继续催办。
