# Review

Trigger: 当 product-manager 需要渲染 Manager 评审闭环的人类投影视图时读取。
Read: `projections/product-manager-review-template.md`
Expect: 最终结论、审查汇总、问题台账、收敛轮次、用户裁决和未决阻断展示结构。
Consume: 只读消费 canonical `review_conclusion / issue_ledger`；不得作为下游控制输入。
Evidence: 每个 issue、round 和 verdict 可回指 canonical 字段或 JSON Pointer。
Sync: review-orchestration-contract、canonical review fields 或 completion gate 变更时同步。

## 最终结论

| 视角 | Verdict | 未决阻断 | 证据锚点 |
|------|---------|----------|----------|
| 产品 | {Verdict} | {无 / PR-*} | |
| 架构 | {Verdict} | {无 / AR-*} | |
| 测试 | {Verdict} | {无 / TR-*} | |

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

## 用户裁决记录

| Decision ID | Trigger Issue | 用户裁决 | 影响范围 | 记录时间 |
|-------------|---------------|----------|----------|----------|

## 未决阻断

| Issue ID | 视角 | Severity | Evidence Anchor | Handoff Target | 处理摘要 |
|----------|------|----------|-----------------|----------------|---------|
