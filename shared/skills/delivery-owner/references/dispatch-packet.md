# Dispatch Packet Contract

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
developer / verifier / fixer packet 的可写边界只来自 Task `file_range`；`scope_item_refs` 只能作为 `input_refs` 中的范围来源证据，不能授权写文件。

`task_packet_check.sh --packet` 只接收 packet JSON 文件路径；不要把 JSON 字符串直接传给 `--packet`。临时文件命名使用当前运行环境的安全临时目录，校验后按环境约定清理。

## Packet Quality Rules

- `goal`：只写一个可验收目标，带 task/gap/AC 标识。
- `scope`：列出允许处理的文件、目录、用户路径或 QA 范围；developer / verifier / fixer 使用 Task `file_range`，不能写“按需处理”。
- `input_refs`：指向冻结 plan/tasks、当前 gap、最新角色报告和失败证据；不能只写口头摘要。
- 现场事实只提供报告名、缺少真实路径时，先用逻辑引用写清输入，例如 `developer-report:T2`、`verify-result:AC-2-missing`，并标注 `path=unavailable`；可写成字符串，也可写成 `{ref, path}` 对象；路径缺失不能替代内联 packet。
- `expected_evidence`：使用对应角色的证据合同；不能写“完成即可”。
- `stop_condition`：写 PASS 条件或精确阻塞条件；不能写 “done”。
- 模糊词的标点或嵌入短语变体同样不合格，例如“按需处理。”和“done when ready”。
- `forbidden_actions`：必须覆盖 scope、baseline/AC、commit/release 和其他角色结论边界。

## Role Packet Contracts

| Packet | Use when | Required input refs | Expected evidence | Stop condition |
| --- | --- | --- | --- | --- |
| developer packet | AC 未实现、verifier missing gap 或实现证据缺口 | plan/tasks、AC/test refs、`file_range`、最新 verify-result 或 missing gap | developer preflight、RED/GREEN/REFACTOR、developer-report.json | AC green，或 scope/AC/环境阻塞 |
| verifier packet | developer/fixer 返回后需要独立验 AC/scope | Task `file_range`、AC、developer-report.json 或 fix-result.json | AC/scope 独立核验、verify-result.json | PASS，或明确 missing gap |
| qa packet | 已验证批次需要用户路径/端到端验收 | qa_handoff_contract、verify-result、用户路径、环境入口 | QA_A/QA_B/QA_C/QA_D 或等价用户路径证据、qa-result.json | 全部必测路径 PASS，或可复现缺陷 |
| fixer packet | qa-result/verify-result 给出可复现失败或已知 bug | failing qa-result/verify-result、scope、相关报告 | root cause、minimal fix、freshness 判断、fix-result.json | failure fixed，或精确 blocker |

回派时必须收窄 packet：把上一轮 `missing gap / failing result / stale evidence` 写入 `goal` 或 `input_refs`，把下一轮必须新增的证据写入 `expected_evidence`，把停止条件写成“gap closed 或 exact blocker reported”。

`/commit` 是 handoff，不走 `task_packet_check.sh`；提交前仍要确认 QA PASS、风险状态、授权和提交摘要。

受限环境无法实际调用 `/commit` 时，仍输出 handoff：

```text
handoff: /commit
dispatch_ready: true
change_scope:
evidence_refs:
risk_status:
authorization:
commit_summary:
stop_condition:
```

如果输入已明确 developer/verifier/qa 证据闭合、无未决风险且用户授权，`evidence_refs` 可以使用逻辑引用，例如 `developer-report:all-tasks`、`verify-result:PASS`、`qa-result:PASS`；不要因为路径不可用而把已满足的提交门禁改判为 DO-S1 阻断。
