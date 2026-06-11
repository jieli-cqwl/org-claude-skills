不能直接改。

**结论**
- 这不是 PM 可自行收口的问题。
- `phase goal`、`exit`、`non-goal` 这类属于 Director 侧锁定边界；用户把“租户自动扣费”加进成功标准，等于在改 Phase 边界和优先级。
- PM 不能在当前草稿里直接改 `phase goal`、`出口` 再继续 review；应先阻断并回流裁决。

**阻断信息**
- `owner`：Director / 用户裁决
- `blocking_fact`：新增成功标准与 Director baseline 的非目标冲突，属于边界漂移，不是 UNIT 可独立吸收的细化
- `impacted_artifacts`：`phase-prd.json` 的 phase goal / exit / non-goal / UNIT 边界 / review digest
- `recovery_condition`：Director 重新确认是否把“租户自动扣费”纳入本 Phase；若纳入，先重锁边界后再重跑 Handoff gate 与 Pre-UNIT gate

**推荐默认值**
- 先保留现有 Director baseline，不改 phase goal / exit
- 将“租户自动扣费”记录为 `pre_review_issue_ledger` 里的 `NEEDS_DECISION`，等待 Director 重新定边界

**下一步**
- 如果你要继续做，先拿到 Director 对这条新成功标准的明确裁决，再回到 Handoff gate。  

**需要你确认的一件事**
- 这条“租户自动扣费”是要升级为本 Phase 的新目标，还是只作为后续 Phase 的候选需求？