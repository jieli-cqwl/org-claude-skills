我按 `shared/skills/developer/SKILL.md` 读完了，这次结论是：

- `design.json`、`tasks.json`、`test-cases.json` 都在，T1 的 AC 也明确，能做“流程拆解说明”。
- 但 `tasks.json` 里没有显式 `file_range` / `files` / `task_scope`，而 skill 对真实代码修改有硬门禁：范围不清时只能阻断，不允许进入实改。
- 另外这次你明确说“本 eval 不要求实际改代码”，所以我不会跑真正的 RED/GREEN，只给出按 skill 应该怎么做，以及 `developer-report.json` 应该怎么填。

**T1 拆解方式**
1. 先确认目标：`T1 = freeze foundation contracts`，对应 `AC-T1-1`，测试指向 `TC-T1-1`。
2. 先读设计真源：`phase-1/design.json` 里的核心决策是“canonical JSON artifacts + active registry entries 作为运行时真源”。
3. 再确认任务/测试映射：`tasks.json` 里的 T1 关联 `design_refs` 和 `test_refs`，`test-cases.json` 里对应的是 foundation contract 校验。
4. 最后看已有交付痕迹：workspace 里已经有一份 `T1/developer-report.json`，说明这个 task 的预期产物就是 developer 报告，而不是别的文件。

**如果真跑 TDD，我会这样拆**
1. `RED`
- 先针对 `AC-T1-1` 写/补一个最小失败测试。
- 测试重点是：foundation catalog / schema / registry contract 的校验在当前状态下必须失败。
- 失败结果要能明确指向缺失或不满足的契约，而不是“脚本不存在”。

2. `GREEN`
- 只做最小修复，让这条契约测试通过。
- 不扩展到 T2，不碰 runtime state tooling。
- 只处理 T1 作用域内的 foundation contract 相关实现。

3. `REFACTOR`
- 在测试保护下做收敛整理。
- 如果没有可重构点，就明确写 `REFACTOR: no-op`，并重跑相关测试保持 PASS。

4. `自测`
- 对照 `test-cases.json` 复核覆盖是否够。
- 跑该 unit 的相关回归。
- 跑静态检查：lint / type / build。
- 如果 smoke / E2E 不适用，要在报告里写清理由，不能省略。

**`developer-report.json` 应该怎么输出**
如果这是一次真实交付，T1 的报告应至少包含这些核心字段：

```json
{
  "artifact_type": "developer-report",
  "artifact_id": "sample-feature.phase-1.unit-1.task-T1.developer-report",
  "schema_version": "1.0.0",
  "producer": "developer",
  "runtime_status": "VERIFIED",
  "active_plan_version_ref": "artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version",
  "active_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
  "task_id": "T1",
  "summary_text": "foundation contracts are being implemented",
  "evidence_refs": [
    "artifact://evidence/sample-feature.phase-1.task-T1.log@ev-1#log-root"
  ],
  "reviewable_anchor": "artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index",
  "file_changes": [
    "contracts/canonical/schemas/runtime/developer-report.schema.json",
    "tools/community/build_standard_chain_catalog.py"
  ],
  "tdd_evidence_index": [
    {
      "phase": "RED",
      "test_ref": "tests/test-standard-chain-foundation-registry.sh#developer-report",
      "result": "FAIL_EXPECTED",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ]
    },
    {
      "phase": "GREEN",
      "test_ref": "tests/test-standard-chain-foundation-registry.sh#developer-report",
      "result": "PASS",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ]
    }
  ],
  "task_scope": [
    "contracts/canonical",
    "tools/community/build_standard_chain_catalog.py"
  ]
}
```

**本次 eval 的实际状态**
- 我没有改代码，也没有跑真实测试。
- 原因不是技能不足，而是你明确要求“只说明如何做”，并且当前任务定义里没有可用于实改的 `file_range/files/task_scope` 明确约束。
- 如果你要我继续，我可以下一步直接把这份说明整理成一份更贴近该 skill 的 `developer-report.json` 完整骨架。