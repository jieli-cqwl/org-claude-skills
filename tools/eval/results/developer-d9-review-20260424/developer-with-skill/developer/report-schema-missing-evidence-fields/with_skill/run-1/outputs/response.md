使用 `developer` skill 处理：这份 `developer-report.json` 不能交给 `verify`。

```json
{
  "runtime_status": "BLOCKED",
  "handoff_to_verify": false,
  "task_scope": [],
  "file_changes": [],
  "report_completeness": "FAIL",
  "blocked_reason": "developer-report.json 只有 file_changes 和 summary，缺少 developer skill 要求的 canonical TDD 与自测证据字段"
}
```

门禁结论：

- 缺少 `tdd_evidence_index`
- 缺少 `reviewable_anchor`
- 缺少 `self_testing`
- 缺少每条 AC 的 RED `FAIL_EXPECTED` 证据
- 缺少每条 AC 的 GREEN `PASS` 证据
- 缺少可供 verify / review 抽查的一手证据锚点

处理方式：拒绝直接交付，标记报告不完整。用户说“先这样交付，后面补证据”也不能接受，因为 `developer` skill 明确要求 `NO completion without TDD RED/GREEN evidence for every AC`，且完成前必须有 self-testing 阶段证据。

下一步：回到 TDD 证据补齐流程，逐条 AC 补齐 RED `FAIL_EXPECTED`、GREEN `PASS`、REFACTOR 结果、`evidence_refs`、`reviewable_anchor` 和 `self_testing` 后，再重新生成完整 canonical `developer-report.json`，然后才能交给 `verify`。不能宣称完成。