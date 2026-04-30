# 路由与 Task Packet

Trigger: 不确定派给谁、怎么派、packet 是否合格时读取。
Read: current gap、task_ref、scope、AC、可用执行角色、已有证据。
Expect: owner 决策、task packet、派发边界。
Consume: `流程/Dispatch`、`流程/Packet`。
Evidence: owner 决策、packet ref、重派原因。
Sync: 角色边界、executor 类型或 packet 字段变化时同步。

## 调度原则

先定责任域，再定资源形态：

```text
gap -> role -> available executor -> task packet -> evidence
```

资源形态只分三类：

1. role agent / subagent：例如 developer、review、qa、verify、fix、consistency-audit。
2. 脚本：确定性检查、schema 校验、readiness gate。
3. 人类 authority：scope、AC、风险接受、最终签收；这是升级，不是 Task Packet。

role 本身就是 agent 时，派发给该 role agent，并要求它按自己的 skill 输出证据。没有 role executor 时输出 `NEEDS_RESOURCE`，不要在主上下文复刻它的专业流程。`tech-lead` 只接收 rebaseline request，authority 只接收升级包，二者都不接收执行 packet。

`REROUTE` 只能换到可执行 role owner：`developer / verify / review / qa / fix / consistency-audit`。资源 owner、authority 或 tech-lead 不是执行 role；资源缺口走 `BLOCKED + blocker_packet`，基线刷新走 `REBASELINE`，裁决走 `ESCALATE`。

## 常见路由

| Gap | Action |
| --- | --- |
| AC 行为未实现 | dispatch developer |
| 实现后需要独立验证 scope / AC | dispatch verify |
| 代码质量、可维护性、回归风险 | dispatch review |
| 用户路径、真实运行、发布风险 | dispatch qa |
| 已知失败需要根因和最小修复 | dispatch fix |
| 跨工件漂移、追踪矛盾、证据断链 | dispatch consistency-audit |
| task、scope、AC、依赖、技术基线不清 | request rebaseline from tech-lead |
| 业务范围、风险接受、最终签收不清 | escalate to authority |

## Task Packet

执行派发必须包含：

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

合格线：

- `task_ref` 回指 `tech-lead` task。
- `goal` 是本轮要关闭的一个 gap。
- `scope` 是文件、路径、命令或验证边界，不能写“按需处理”。
- `expected_evidence` 指向下游可复验产物，而不是“完成即可”。
- `stop_condition` 写明成功、阻塞或交回的条件。
- `forbidden_actions` 至少覆盖不得改基线、不得扩大 scope、不得 commit、不得替其他角色下结论。
  - commit/release 是签收后的授权链路，不是 delivery-owner 派发角色。

## Role Evidence Hints

`expected_evidence` 写下游真正消费的证据，不写“完成即可”：

| Role | Expected evidence |
| --- | --- |
| developer | developer preflight 结论、RED/GREEN/REFACTOR 证据、当前验证命令输出、`developer-report.json` 路径 |
| verify | AC / scope 独立核验结论、失败定位、`verify-result.json` 路径 |
| review | 代码审查结论、风险/阻断项、`code-review-result.json` 路径 |
| qa | QA_A / QA_B / QA_C / QA_D 路径结论、真实运行证据、`qa-result.json` 路径 |
| fix | 根因、最小修复、受影响证据 freshness 判断、`fix-result.json` 路径 |
| consistency-audit | full/advisory_only 审计结论、blocked layers / CRITICAL findings、`consistency-audit-result.json` 路径 |

`task_packet_check.sh` 会按上表拦截缺少最低证据项的 packet；需要豁免时不要改 packet 糊弄通过，先升级或 rebaseline。

## 派发提示骨架

```text
你是 {role}。
任务：关闭 {gap}。
输入：{input_refs}
范围：{scope}
必须产出：{expected_evidence}
停止条件：{stop_condition}
禁止：{forbidden_actions}
返回：结论、证据引用、失败原因、下一步建议。
```

packet 不合格时先修 packet，不派发。
packet 合格后才交给 executor；executor 返回只收结论、证据引用、失败原因和下一步建议。
回到同一 owner 只是为了收窄 packet 时，在 control decision 里记录 `packet_delta` 和 `loop_state`；同一 owner/gap 的 packet correction 只做一次，下一轮仍无证据就按 `next_no_progress_action` 换策略或停止。
