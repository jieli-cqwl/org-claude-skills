我先按 `shared/skills/developer/SKILL.md` 的规则核对了输入，结论是：

- `design.json`、`tasks.json`、`test-cases.json`、`artifact-registry.json` 都存在
- 但这条 `T1` 任务里没有显式的 `file_range` / `files` / `task_scope`
- 按 skill 硬门槛，**没有可确认的修改范围时，不能进入真实 TDD 改代码阶段**

所以这次只能给出**阻断式说明**，不能声称完成实现。基于当前输入，我会这样处理：

1. 先做拆解
- 读 `design.json` 的 canonical 设计片段，确认 `T1` 的目标是 `foundation contracts`
- 读 `tasks.json`，确认 `T1` 对应 `AC-T1-1`
- 读 `test-cases.json`，确认测试覆盖点是 `TC-T1-1: foundation catalog and schema contracts validate active artifacts`
- 复核 `artifact-registry.json`，确认 `T1` 的产物位置是 `phase-1/unit-1/tasks/T1/developer-report.json`
- 但由于没有明确的可修改文件范围，我会在这一步停住并上报 `BLOCKED`

2. 如果范围补齐，我会怎么跑 RED/GREEN
- `RED`：先从 `test-cases.json` 的 `AC-T1-1` 推导出必须失败的测试
- `GREEN`：只做最小改动，让该测试通过
- `REFACTOR`：在测试保护下整理实现，但不扩范围
- 每一步都要记录到 `tdd_evidence_index`，并确保每条 AC 都有 `RED -> GREEN` 证据

3. 自测会怎么做
- 对照 `test-cases.json` 检查覆盖是否完整
- 跑全量回归
- 跑静态分析：lint / type / build
- 如果适用，再跑冒烟或 E2E
- 任何一项失败都不能写成完成，只能写 `BLOCKED` 或 `PARTIAL`

4. `developer-report.json` 会怎么输出
- 由于当前是说明模式，我会输出完整 JSON 骨架
- 但因为范围缺失，`task_scope` 和 `file_changes` 必须是空数组
- `runtime_status` 必须是 `BLOCKED`

一个符合当前状态的骨架如下：

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
  "summary_text": "blocked because task scope is not explicitly declared with file_range/files/task_scope",
  "active_plan_version_ref": "artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version",
  "active_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
  "evidence_refs": [],
  "reviewable_anchor": "artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index",
  "file_changes": [],
  "tdd_evidence_index": [
    {
      "phase": "DECOMPOSITION",
      "result": "BLOCKED",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ],
      "reason": "task scope is not declared in file_range/files/task_scope"
    },
    {
      "phase": "RED",
      "result": "NOT_RUN",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ]
    },
    {
      "phase": "GREEN",
      "result": "NOT_RUN",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ]
    },
    {
      "phase": "SELF_TEST",
      "result": "NOT_RUN",
      "test_ref": "full regression + lint/type/build + smoke/e2e as applicable",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ]
    }
  ],
  "task_scope": []
}
```

如果你愿意，我下一步可以继续帮你做两件事之一：

1. 按这个 eval 的规范，整理成一份更贴近最终验收的 `developer-report.json` 模板说明
2. 继续帮你定位 `T1` 为什么没有显式 `file_range/files/task_scope`，看是不是上游 canonical 输入本身缺字段