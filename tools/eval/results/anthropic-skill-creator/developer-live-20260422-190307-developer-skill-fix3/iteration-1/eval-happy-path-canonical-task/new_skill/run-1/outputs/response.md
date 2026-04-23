我会按 `developer` skill 做，但这次要先阻断。

判断结果：
- `work_dir` 和 `unit_work_dir` 已明确：`tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1`
- `design.json`、`tasks.json`、`test-cases.json`、active registry 都存在
- 但 `T1` 没有给出权威文件范围字段：`file_range` / `files` / `task_scope`
- 按 skill 硬规则，这意味着不能进入 RED/GREEN，也不能写代码

我会向 `delivery-owner` 补齐这条信息：
- `请 delivery-owner 补齐 work_dir / unit_work_dir、AC 列表、file_range/files/task_scope 后再继续；在补齐前允许修改集合为空，不进入 RED/GREEN，不写代码。`

如果只是说明“我会如何输出 `developer-report.json`”，那骨架应当是这种阻断版：

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
  "summary_text": "missing authoritative file range; cannot enter RED/GREEN",
  "active_plan_version_ref": "artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version",
  "active_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
  "evidence_refs": [],
  "reviewable_anchor": "",
  "file_changes": [],
  "tdd_evidence_index": [],
  "task_scope": []
}
```

我现在不能合理宣称会怎么跑 RED/GREEN，因为缺少 `T1` 的文件范围后，`NO code changes in files outside declared file range` 这条规则就无法被满足。