我理解：Task T3 要给 `src/api/user.ts` 的 API 响应新增 `display_name`，声明文件范围只有 `src/api/user.ts` 与 `tests/api/user.test.ts`；实现时发现必须同步 `design.json`，但 `design.json` 未显式列入范围。

判定：`BLOCKED`，原因是接口微调 `DESIGN_ISSUE:INTERFACE_TWEAK`，且需要修改范围外 canonical 设计真源。按 `developer` skill，不能擅自改 `design.json`，不能继续 GREEN/REFACTOR，也不能宣称 Task 完成。下一步是立即报告 `delivery-owner`，等待上游刷新 canonical revision 或明确扩展文件范围。

```json
{
  "runtime_status": "BLOCKED",
  "task_scope": [
    "src/api/user.ts",
    "tests/api/user.test.ts"
  ],
  "file_changes": [],
  "evidence_refs": [],
  "tdd_evidence_index": [
    {
      "ac_id": "T3.AC.display_name",
      "test_ref": null,
      "red": "BLOCKED_BEFORE_RED: design.json requires sync but is outside declared file range",
      "green": "NOT_RUN",
      "refactor": "NOT_RUN",
      "target_files": [
        "src/api/user.ts",
        "tests/api/user.test.ts"
      ],
      "evidence_refs": []
    }
  ],
  "reviewable_anchor": null,
  "self_testing": {
    "status": "NOT_RUN",
    "reason": "Blocked before implementation because required design.json update is outside declared file range"
  },
  "self_review": {
    "scope_compliance": "PASS: no out-of-scope file modified",
    "completion_claim": "BLOCKED: Task not complete"
  },
  "interface_change_log": [
    {
      "interface": "design.json#/interfaces/UserResponse",
      "change": "Add response field display_name",
      "reason": "AC requires new API response field",
      "classification": "DESIGN_ISSUE:INTERFACE_TWEAK",
      "requested_owner_action": "delivery-owner to refresh canonical design revision or explicitly expand file range"
    }
  ]
}
```

Canonical gates：`work_dir` 已有；`design.json`、`tasks.json`、active registry、`test-cases.json` 均未作为输入提供；AC 来自 eval prompt；权威文件范围已给出且不含 `design.json`。因此本轮只允许报告阻断与下一步，不执行真实代码改动。