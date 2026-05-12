# 产品经理评审投影

> 运行时真源为 canonical `review_conclusion / issue_ledger`；人类投影视图不得作为下游控制输入。

## 渲染规则

- `审查汇总` 的 `Issue Count` 统计当前仍未关闭的稳定 issue（`PR-* / AR-* / TR-*`）；PASS 视角填 `0`。
- 已关闭但保留修订痕迹的内容使用 `HIS-*`；活跃 `PR-* / AR-* / TR-*` 行表示仍需承接。
- `审查问题台账` 保留至少 1 条历史或确认轮记录；`Review Round` 填 issue 首次出现轮次。
- `收敛轮次摘要` 的 `未关闭 Issue IDs` 列当前未关闭 issue；`FAIL数` 不统计 WARN；首轮全 PASS 时记录 `R2 / CONFIRMATION`。
- `阻断事实记录` 用于 `ASK_USER` 或 `BLOCKED` 场景；其他场景保留表头和空表体。

## 最终结论

| 视角 | Verdict | 未决阻断 | 证据锚点 |
|------|---------|----------|----------|
| 产品 | {Verdict} | {无 / PR-*} | |
| 架构 | {Verdict} | {无 / AR-*} | |
| 测试 | {Verdict} | {无 / TR-*} | |

## Agent Team Evidence

| 字段 | 当前值 | 证据锚点 |
|------|--------|----------|
| `$.review_conclusion.agent_team_review.mode` | `agent_teams` | |
| `$.review_conclusion.agent_team_review.round` | R{N} | |
| `$.review_conclusion.agent_team_review.reviewed_artifact_refs[]` | | |
| `$.review_conclusion.agent_team_review.reviewed_bundle_digest` | `sha256:<64 hex>` | |
| `$.review_conclusion.agent_team_review.reviewer_verdicts[]` | product / architecture / test | |
| `$.review_conclusion.agent_team_review.convergence_evidence[]` | CONFIRMATION | |

## 审查汇总

| 视角 | Verdict | Review Round | Issue Count | 结论摘要 |
|------|---------|--------------|-------------|----------|
| 产品 | {PASS / WARN / FAIL} | R{N} | {0 / N} | |
| 架构 | {PASS / WARN / FAIL} | R{N} | {0 / N} | |
| 测试 | {PASS / WARN / FAIL} | R{N} | {0 / N} | |

## 审查问题台账

| Issue ID | 视角 | Severity | Status | Evidence Anchor | Resolution Anchor | Review Round | 处理摘要 |
|----------|------|----------|--------|-----------------|-------------------|--------------|----------|
| PR-* / AR-* / TR-* / HIS-* | | P0/P1/P2/P3 | OPEN / RESOLVED / BLOCKED / HISTORICAL | | | R{N} | |

## 收敛轮次摘要

| Review Round | Trigger | FAIL数 | 未关闭 Issue IDs | 下一步 |
|--------------|---------|--------|-------------------|--------|
| R{N} | INITIAL / RETRY / CONFIRMATION | {0 / N} | {无 / PR-* / AR-* / TR-*} | {继续 / ASK_USER / BLOCKED} |

## 阻断事实记录

| Fact ID | Trigger Issue | 补充事实 | 影响范围 | 记录时间 |
|-------------|---------------|----------|----------|----------|

## 未决阻断

| Issue ID | 视角 | Severity | Evidence Anchor | Handoff Target | 处理摘要 |
|----------|------|----------|-----------------|----------------|---------|
