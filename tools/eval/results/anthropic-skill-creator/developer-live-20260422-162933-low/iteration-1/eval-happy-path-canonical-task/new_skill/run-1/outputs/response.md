按当前合同，我会把 `Task T1` 处理成**阻断态的 TDD 计划**，不是实际改代码。

结论先说：
- `design.json`、`tasks.json`、`test-cases.json` 都已存在，前置材料齐。
- 但 `tasks.json` 没有提供 `file_range / files / task_scope`，所以**没有可批准的修改文件集合**。
- 按 `developer` skill，这种情况必须停止真实实现，只能向 `delivery-owner` 要补充范围，不能进入 GREEN 和落盘改代码。

我会这样拆解 `T1`：

1. 代码探索
- 只围绕 `T1` 的 canonical 输入做分析：
  - `design.json` 里的 `key-decisions`
  - `tasks.json` 里的 `T1`
  - `unit-1/test-cases.json` 里的 `AC-T1-1` 和 `TC-T1-1`
  - `unit-1.json` 的 closure 定义
- 识别出来的语义核心是：
  - foundation registry
  - schema
  - template
  - catalog
  - active artifact vs baseline artifact 的冻结边界

2. 复用判断
- 先找是否已有“同语义”的冻结/校验逻辑。
- 这一步的目标不是抽象，而是判断：
  - 是否已有现成的 canonical schema/registry 校验入口
  - 是否已有 catalog/template 冻结逻辑可以复用
- 只有语义一致、变化节奏一致、边界健康时才复用。

3. TDD 拆分
- 对 `AC-T1-1`，我会拆成 1 个主测试链：
  - RED：新增一个失败测试，验证 foundation catalog 和 canonical tree 在 active artifacts 下必须通过校验
  - GREEN：最小实现让该测试通过
  - REFACTOR：只在绿色保护下整理代码
- 但这次因为没有 `file_range`，RED 只能停在“计划层”，不能实际写测试文件。

4. 自测
- 按 `test-cases.json` 的 QA 义务，我会把自测拆成四项：
  - 静态契约验证
  - runtime replay / readiness gate
  - blocked/recovery 覆盖
  - final signoff closure
- 如果这是 docs-only / plan-only 交付，则会明确写“不适用”，并说明原因。
- 这里同样因为没文件范围，不能执行真实代码侧验证。

我会写的 `developer-report.json` 结论应是：

```json
{
  "task_id": "T1",
  "runtime_status": "BLOCKED",
  "blocker_reason": "missing file_range/files/task_scope; cannot determine allowed modification set",
  "task_scope": [],
  "file_changes": [],
  "tdd_evidence_index": [
    {
      "ac_id": "AC-T1-1",
      "red": {
        "status": "BLOCKED",
        "evidence": "test-case and design reviewed, but no allowed file scope to author failing test"
      },
      "green": {
        "status": "NOT_RUN",
        "evidence": "blocked before implementation"
      },
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
    }
  ],
  "reviewable_anchor": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
  "evidence_refs": [
    "artifact://design/sample-feature.phase-1.design@v1#key-decisions",
    "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
    "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
    "artifact://unit-definition/sample-feature.phase-1.unit-1@v1#unit"
  ]
}
```

如果你要我继续到“可执行实现”那一步，下一条必须先补：
- `file_range`
- 或 `files`
- 或 `task_scope`

补齐后，我才能按 skill 真正进入 RED -> GREEN -> REFACTOR。