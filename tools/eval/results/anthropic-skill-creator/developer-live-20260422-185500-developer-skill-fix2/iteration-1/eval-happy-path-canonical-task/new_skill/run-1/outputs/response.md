我理解你的要求是：针对 `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1` 里的 `T1`，按 `shared/skills/developer/SKILL.md` 说明我会怎样拆解任务、按 TDD 跑 `RED/GREEN`、做自测，并产出 `developer-report.json`；这次不要求真的改代码。

当前我必须阻断，原因是 developer skill 的前置条件不完整：

- `design.json`、`tasks.json`、`test-cases.json` 都在
- 但 `tasks.json` 里没有可作为权威依据的 `file_range/files/task_scope`
- 按 skill 规定，解析不到权威文件范围时，不能进入 RED/GREEN，也不能开始实现
- 这时只能向 `delivery-owner` 补齐范围后再继续

所以这次的结论是 `runtime_status: "BLOCKED"`。

如果按规范输出 `developer-report.json`，我会给出下面这种骨架，且 `task_scope` 和 `file_changes` 为空数组：

```json
{
  "artifact_type": "developer-report",
  "artifact_id": "sample-feature.phase-1.unit-1.task-T1.developer-report",
  "schema_version": "1.0.0",
  "producer": "developer",
  "produced_at": "2026-04-22T00:00:00Z",
  "chain_version": "standard-chain/v1",
  "chain_registry_digest": "sha256:306668c17650b323b74a7d4aa616b029e8c2b17ee9bd960f15f89321bffc8bd3",
  "authority_scope": "artifact",
  "authoritative_fields": [
    "$.runtime_status",
    "$.active_plan_version_ref",
    "$.active_tasks_version_ref",
    "$.evidence_refs",
    "$.reviewable_anchor",
    "$.tdd_evidence_index"
  ],
  "task_id": "T1",
  "runtime_status": "BLOCKED",
  "summary_text": "blocked because canonical file range / task scope is missing",
  "active_plan_version_ref": "artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version",
  "active_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
  "evidence_refs": [
    "artifact://design/sample-feature.phase-1.design@v1#key-decisions",
    "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#tasks",
    "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#ac_coverage_matrix"
  ],
  "reviewable_anchor": "artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index",
  "file_changes": [],
  "tdd_evidence_index": [
    {
      "phase": "RED",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "result": "NOT_RUN",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ],
      "reason": "blocked before TDD because file_range/files/task_scope is missing"
    },
    {
      "phase": "GREEN",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "result": "NOT_RUN",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ],
      "reason": "blocked before TDD because RED could not start"
    }
  ],
  "task_scope": [],
  "blocker": {
    "missing_items": [
      "file_range",
      "files",
      "task_scope"
    ],
    "request": "请 delivery-owner 补齐 work_dir / unit_work_dir、AC 列表、file_range/files/task_scope 后再继续；在补齐前允许修改集合为空，不进入 RED/GREEN，不写代码。"
  }
}
```

如果你愿意，我下一步可以继续帮你做两件事里的任意一个：

1. 按这个 skill，把“阻断版 developer-report”整理成最终可直接落盘的 JSON
2. 先帮你检查这组 fixture 里还有哪些字段，能够支持后续解除阻断