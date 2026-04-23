我先按 `shared/skills/developer/SKILL.md` 核对了本次 eval 的输入，结论是：

- `design.json`、`tasks.json`、`test-cases.json` 都齐了
- 但 `tasks.json` 里没有权威 `file_range / files / task_scope`
- 按 skill 规则，这会让“允许修改集合”无法确定，所以这次只能按 **BLOCKED** 处理，不能进入真实 RED/GREEN，也不能声明完成

我已核对的文件：
- [design.json](/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-tip1ri15/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json)
- [tasks.json](/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-tip1ri15/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/tasks.json)
- [test-cases.json](/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-tip1ri15/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/test-cases.json)
- [artifact-registry.json](/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-tip1ri15/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/artifact-registry.json)
- [delivery-state.json](/var/folders/lx/j765n6856kd4clzhfs7pfdjm0000gn/T/anthropic-adapter-run-tip1ri15/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/delivery-state.json)

**我会如何拆解 T1**
1. 先做输入映射
- `work_dir = tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1`
- `unit_work_dir = tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1`
- AC 来自 `test-cases.json` 的 `AC-T1-1`
- 设计依据来自 `design.json#key-decisions`
- 任务依据来自 `tasks.json#T1`

2. 再做模式识别
- 这是“foundation contracts”类任务
- 设计主线是“canonical JSON artifacts + active registry + delivery-state”
- 重点不是改业务逻辑，而是冻结契约、校验 schema、验证 registry 路径发现与阶段状态

3. TDD 拆成 3 步
- RED：为 `AC-T1-1` 推导出失败测试，验证“foundation catalog and schema contracts validate active artifacts”
- GREEN：最小修复让测试通过
- REFACTOR：在测试保护下清理，保持 PASS

4. 自测拆成 4 层
- 测试完备性审视：对照 `test-cases.json` 看 AC 是否只覆盖 T1 / 是否缺边界
- 全量回归：跑完整测试套件
- 静态分析：lint + type + build
- 冒烟 / E2E：如果这个 eval 不是可执行应用，则标注“不适用”并写原因

**为什么这次必须阻断**
- skill 明确要求：没有权威 `file_range/files/task_scope`，就要把 `runtime_status` 标成 `BLOCKED`
- 现在只能确定“要做什么”，不能确定“允许改哪些文件”
- 所以不能进入真实实现，更不能伪造 RED/GREEN 证据

**developer-report.json 应该怎么写**
下面是这次 eval 适用的骨架，核心点是 `runtime_status: "BLOCKED"`，`task_scope` 和 `file_changes` 置空：

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
  "evidence_refs": [],
  "active_plan_version_ref": "artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version",
  "active_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
  "task_id": "T1",
  "runtime_status": "BLOCKED",
  "summary_text": "missing authoritative file_range/files/task_scope, so RED/GREEN cannot start",
  "reviewable_anchor": "artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index",
  "file_changes": [],
  "tdd_evidence_index": [
    {
      "phase": "RED",
      "result": "NOT_RUN",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ],
      "reason": "blocked by missing authoritative file range"
    },
    {
      "phase": "GREEN",
      "result": "NOT_RUN",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ],
      "reason": "RED phase not permitted to run"
    },
    {
      "phase": "REFACTOR",
      "result": "NOT_RUN",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ],
      "reason": "GREEN phase not reached"
    },
    {
      "phase": "SELF_TEST",
      "result": "NOT_RUN",
      "test_ref": "full regression / lint / type / build",
      "reason": "blocked by missing authoritative file range"
    }
  ],
  "task_scope": []
}
```

如果你愿意，我下一步可以继续帮你做两种事里的任意一种：
1. 基于这份输入，整理成更像交付文档的 `developer-report.json` 最终版文本
2. 继续追查这套 eval 里是否还有别的 canonical 文件能补出 `file_range/files/task_scope`，看能不能解除阻断