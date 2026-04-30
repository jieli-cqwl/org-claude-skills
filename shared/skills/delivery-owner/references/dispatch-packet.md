# Dispatch Packet Contract

Trigger: 派发 developer agent、verifier agent、qa agent、fixer agent 或 `/commit` 前读取。 Read: gap、task_ref、scope、AC、input refs、可用执行入口。 Expect: 逻辑角色、Task Packet、commit handoff。 Consume: DO-S4、DO-S5、DO-S7、DO-S8。 Evidence: packet check 输出、agent evidence refs、commit result。 Sync: agent 证据合同或 packet 字段变化时同步。

## Route

```text
gap -> logical role -> runtime executor -> packet -> evidence
```

executor 从当前运行时的 agent catalog、tooling 或命令入口解析；packet 只写逻辑 `role`，不写 runtime 专属文件路径。没有可用 executor 时，暂停并输出 `NEEDS_RESOURCE`。

| Gap | Logical role | Packet `role` |
| --- | --- | --- |
| AC 未实现 | developer agent | `developer` |
| 实现后验 AC/scope | verifier agent | `verifier` |
| QA FAIL 或已知 bug | fixer agent | `fixer` |
| 用户路径或端到端验收 | qa agent | `qa` |
| QA PASS 后提交 | /commit handoff | n/a |
| scope/AC/风险/授权不清 | user decision | n/a |

## Packet Fields

```text
task_ref:
role:
goal:
scope:
input_refs:
expected_evidence:
stop_condition:
forbidden_actions:
```

合格 packet 必须让执行者清楚：处理哪个 task/gap、能改哪里、读哪些输入、交付什么证据、何时停止、哪些边界不能越过。

## Evidence Hints

| Agent | Minimum evidence |
| --- | --- |
| developer agent | developer preflight、RED/GREEN/REFACTOR、developer-report.json |
| verifier agent | AC/scope 独立核验、verify-result.json |
| qa agent | QA_A/QA_B/QA_C/QA_D 或等价用户路径证据、qa-result.json |
| fixer agent | root cause、minimal fix、freshness 判断、fix-result.json |

`/commit` 是 handoff，不走 `task_packet_check.sh`；提交前仍要确认 QA PASS、风险状态、授权和提交摘要。
