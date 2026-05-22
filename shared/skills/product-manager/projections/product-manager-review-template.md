# 产品经理评审投影

> 下游控制输入以 canonical `review_conclusion / issue_ledger` 为准；本文只做人类投影视图。

## 渲染规则

- `Issue Count` 只统计未关闭的 `PR-* / AR-* / TR-*`；PASS 视角填 `0`。
- `HIS-*` 只保留历史修订痕迹；活跃 `PR-* / AR-* / TR-*` 表示仍需承接。
- `Review Round` 填 issue 首次出现轮次。
- `FAIL数` 不统计 WARN。
- `阻断事实记录` 只用于 ASK_USER 或 BLOCKED。

## 最终结论

| 视角 | Verdict | 未决阻断 | 证据 |
|------|---------|----------|------|
| 产品 | PASS / WARN / FAIL | 无 / PR-* | |
| 架构 | PASS / WARN / FAIL | 无 / AR-* | |
| 测试 | PASS / WARN / FAIL | 无 / TR-* | |

## Agent Team Evidence

| Review Bundle | Digest | Round | Reviewer Verdicts | Confirmation |
|---------------|--------|-------|-------------------|--------------|
| brief + phase-prd + UNITs | sha256:<64 hex> | R{N} | product / architecture / test | yes / no |

## 审查汇总

| 视角 | Verdict | Review Round | Issue Count | 结论摘要 |
|------|---------|--------------|-------------|----------|
| 产品 | PASS / WARN / FAIL | R{N} | 0 / N | |
| 架构 | PASS / WARN / FAIL | R{N} | 0 / N | |
| 测试 | PASS / WARN / FAIL | R{N} | 0 / N | |

## 审查问题台账

| Issue ID | 视角 | Severity | Status | Evidence | Resolution | Review Round | 处理摘要 |
|----------|------|----------|--------|----------|------------|--------------|----------|
| PR-* / AR-* / TR-* / HIS-* | | P0/P1/P2/P3 | OPEN / RESOLVED / BLOCKED / HISTORICAL | | | R{N} | |

## 收敛轮次摘要

| Review Round | Trigger | FAIL数 | 未关闭 Issue IDs | 下一步 |
|--------------|---------|--------|-------------------|--------|
| R{N} | INITIAL / RETRY / CONFIRMATION | 0 / N | 无 / PR-* / AR-* / TR-* | 继续 / ASK_USER / BLOCKED |

## 阻断事实记录

| Fact ID | Trigger Issue | 补充事实 | 影响范围 | 记录时间 |
|---------|---------------|----------|----------|----------|
