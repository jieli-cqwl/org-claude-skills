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

## Packet Quality Rules

- `goal`：只写一个可验收目标，带 task/gap/AC 标识。
- `scope`：列出允许处理的文件、目录、用户路径或 QA 范围；不能写“按需处理”。
- `input_refs`：指向冻结 plan/tasks、当前 gap、最新角色报告和失败证据；不能只写口头摘要。
- `expected_evidence`：使用对应角色的证据合同；不能写“完成即可”。
- `stop_condition`：写 PASS 条件或精确阻塞条件；不能写 “done”。
- `forbidden_actions`：必须覆盖 scope、baseline/AC、commit/release 和其他角色结论边界。

## Role Packet Contracts

| Packet | Use when | Required input refs | Expected evidence | Stop condition |
| --- | --- | --- | --- | --- |
| developer packet | AC 未实现、verifier missing gap 或实现证据缺口 | plan/tasks、AC/test refs、scope、最新 verify-result 或 missing gap | developer preflight、RED/GREEN/REFACTOR、developer-report.json | AC green，或 scope/AC/环境阻塞 |
| verifier packet | developer/fixer 返回后需要独立验 AC/scope | task scope、AC、developer-report.json 或 fix-result.json | AC/scope 独立核验、verify-result.json | PASS，或明确 missing gap |
| qa packet | 已验证批次需要用户路径/端到端验收 | qa_handoff_contract、verify-result、用户路径、环境入口 | QA_A/QA_B/QA_C/QA_D 或等价用户路径证据、qa-result.json | 全部必测路径 PASS，或可复现缺陷 |
| fixer packet | qa-result/verify-result 给出可复现失败或已知 bug | failing qa-result/verify-result、scope、相关报告 | root cause、minimal fix、freshness 判断、fix-result.json | failure fixed，或精确 blocker |

回派时必须收窄 packet：把上一轮 `missing gap / failing result / stale evidence` 写入 `goal` 或 `input_refs`，把下一轮必须新增的证据写入 `expected_evidence`，把停止条件写成“gap closed 或 exact blocker reported”。

`/commit` 是 handoff，不走 `task_packet_check.sh`；提交前仍要确认 QA PASS、风险状态、授权和提交摘要。
