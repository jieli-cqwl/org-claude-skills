# Follow-up Loop Contract

## Progress Signal

有效进展只认这些信号：`gap_closed`、`gap_narrowed`、`new_evidence`、`new_blocker`、`new_risk`、`owner_changed`。

无进展：remaining gap 未缩小，evidence refs 未更新，没有新阻塞/风险，owner 未变化，或只有“继续处理/已优化”等自报。

## Loop Decision

| Signal | Next |
| --- | --- |
| PASS evidence | advance |
| clear missing gap | return to same role with expected evidence |
| wrong owner | reroute |
| fixer agent changed code | rerun affected verifier agent / qa agent |
| first no-progress round | change packet, owner, evidence target, or strategy |
| second no-progress round on same gap | pause user |
| round 10 | pause user |
| scope/AC/risk/authorization | pause user |

暂停时使用 `templates/user-decision-package.template.md`；状态卡使用 `templates/status-card.template.md`。
