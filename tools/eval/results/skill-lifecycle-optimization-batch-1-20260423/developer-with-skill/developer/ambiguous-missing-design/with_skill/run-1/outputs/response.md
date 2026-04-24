使用 `shared/skills/developer/SKILL.md` 处理本 eval。我的理解：用户要求“直接实现 Task T2：修订单金额计算 bug”，但只有一句描述，缺少 developer skill 的必需前置输入；预期结果是阻断，不进入 TDD、不改代码、不生成实际产物。

处理结论：`runtime_status: "BLOCKED"`

已解析 / 缺失 gates：

```json
{
  "task_id": "T2",
  "task_description": "修一个订单金额计算 bug",
  "runtime_status": "BLOCKED",
  "gates": {
    "work_dir": "MISSING",
    "design.json": "MISSING",
    "tasks.json": "MISSING",
    "active_registry_or_artifact_registry": "MISSING",
    "test-cases.json": "OPTIONAL_MISSING",
    "AC_list": "MISSING",
    "file_range_or_files_or_task_scope": "MISSING"
  },
  "task_scope": [],
  "file_changes": [],
  "allowed_to_modify": []
}
```

阻断原因：

- 缺少 `work_dir / unit_work_dir / phase_dir`，无法定位 canonical 工件。
- 缺少 `{phase_dir}/design.json`，developer skill 明确要求缺失时终止并报告 delivery-owner。
- 缺少 Task T2 的 AC 列表，无法建立逐 AC 的 RED/GREEN/REFACTOR 证据。
- 缺少权威文件范围 `file_range / files / task_scope`，因此 `仅允许修改：空集合`。
- 当前不能猜测订单金额 bug 的实现位置、计算规则或测试口径。

不会执行：

- 不进入 TDD RED 阶段。
- 不修改任何代码。
- 不启动服务。
- 不调用审查 agent。
- 不声明 Task T2 已完成。

向 `delivery-owner` 提问：

1. 请提供本 Task 的 `work_dir / unit_work_dir / phase_dir`。
2. 请提供或指定 `{phase_dir}/design.json`、`{phase_dir}/tasks.json` 和 active artifact registry。
3. 请提供 Task T2 的完整内容：AC 列表、`design_refs`、`test_refs`。
4. 请提供权威文件范围：`file_range`、`files` 或 `task_scope`。