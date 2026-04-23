按 `developer` skill 处理这次 T1，我会先把结论说清楚：

当前只能**阻断**，不能进入真实 RED/GREEN 或写 `developer-report.json` 成品，因为这份任务缺少 `file_range` / `files` / `task_scope` 之一，技能规则要求这三者必须先明确，才能确定允许修改的范围。

我已经核对了这些输入：
- [design.json](/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-qjekusx7/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json)
- [tasks.json](/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-qjekusx7/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/tasks.json)
- [test-cases.json](/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-qjekusx7/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/test-cases.json)

可确认的信息：
- T1 的 AC 只有 `AC-T1-1`
- 设计引用只指向 `key-decisions`
- `test-cases.json` 已给出 `TC-T1-1`
- 但 `tasks.json` 没有给出允许修改的文件集合

如果这是一个可执行任务，我会这样拆：

1. 代码探索
- 读取 T1 对应的 canonical 设计、任务、测试用例、active registry。
- 找到同目录已有实现模式，确认命名、错误处理、报告结构复用点。

2. 模式识别与复用判断
- 先复用现有 canonical 报告/schema/registry 约定。
- 只在任务声明的文件范围内做最小修改。

3. 步骤规划
- 把 `AC-T1-1` 拆成 1 个 RED-GREEN 对：
  - RED：补一个能稳定失败的测试，证明 foundation contracts 还未满足
  - GREEN：最小实现让测试通过
  - REFACTOR：只在测试保护下清理，不扩范围

4. 风险标注
- 目前最大风险就是：**范围缺失**
- 另外还要确认是否有现成的 `developer-report.json` 生成路径和模板可复用

5. 确认/提问
- 需要 delivery-owner 补齐 `file_range`、`files` 或 `task_scope`
- 补齐后才能进入真正 TDD

如果要输出 `developer-report.json`，在当前阻断状态下我会按 canonical 骨架写成这样，`task_scope` 和 `file_changes` 置空，并标记阻断原因：

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
  "summary_text": "task scope is missing; file_range/files/task_scope must be provided before TDD execution",
  "active_plan_version_ref": "artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version",
  "active_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
  "evidence_refs": [],
  "reviewable_anchor": "artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index",
  "file_changes": [],
  "tdd_evidence_index": [],
  "task_scope": []
}
```

如果你愿意，我下一步可以继续帮你做两件事里的任意一个：
1. 基于现有 fixture，把 T1 的“可执行版”拆解写成一份完整 mini-plan。
2. 继续检查这个 eval 里是否还藏着可用的 `file_range` / 运行时模板线索。