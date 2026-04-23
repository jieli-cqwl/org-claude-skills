我理解的是：你要我按 `shared/skills/developer/SKILL.md`，针对 `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1` 里的 `T1`，说明我会如何拆解、跑 `RED/GREEN`、做自测，并产出 `developer-report.json`。这次是说明型 eval，不要求我真的改代码。

结论先说：**当前应阻断，不能进入真实 `RED/GREEN`**。
原因是我已经读到 `design.json`、`tasks.json`、`test-cases.json` 和 active `artifact-registry.json`，但 `tasks.json` 里的 `T1` **没有权威的 `file_range / files / task_scope`**，而 skill 明确要求：缺失这项时必须请求 delivery-owner 补齐，且不能开始执行型 TDD。

需要补齐给 delivery-owner 的内容是：

- `work_dir / unit_work_dir`
- `AC` 列表
- `file_range / files / task_scope`

在补齐前，按 skill 规则：
- 允许修改集合为空
- 不进入 `RED/GREEN`
- 不写代码
- 只能给出说明型计划和 `developer-report.json` 骨架

**我会怎么拆解 T1**
1. 先确认输入源：`design.json` 的关键决策是“registry controls path discovery”“delivery-state controls phase stage”，`test-cases.json` 里 `AC-T1-1` 对应 `TC-T1-1`。
2. 再做模式识别：当前样本的同类产物已经有 `unit-1/tasks/T1/developer-report.json`，可以作为格式参照，但不能替代本次 task 的权威范围。
3. 形成 TDD 计划：
   - `RED`：按 `AC-T1-1` 推导失败测试
   - `GREEN`：最小实现让测试通过
   - `REFACTOR`：在测试保护下整理
4. 做自测：
   - 全量回归
   - lint/type/build
   - 如适用再做 smoke / E2E
5. 输出 `developer-report.json`，必须包含 `evidence_refs`、`reviewable_anchor`、`file_changes`、`tdd_evidence_index`、`task_scope`

**本次说明型 eval 的 `developer-report.json` 骨架**
```json
{
  "artifact_type": "developer-report",
  "artifact_id": "sample-feature.phase-1.unit-1.task-T1.developer-report",
  "schema_version": "1.0.0",
  "producer": "developer",
  "produced_at": "2026-04-22T00:00:00Z",
  "chain_version": "standard-chain/v1",
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
  "summary_text": "missing authoritative task scope; cannot enter RED/GREEN",
  "active_plan_version_ref": "artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version",
  "active_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
  "evidence_refs": [
    "artifact://evidence/sample-feature.phase-1.task-T1.log@ev-1#log-root"
  ],
  "reviewable_anchor": "artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index",
  "task_scope": [],
  "file_changes": [],
  "tdd_evidence_index": [
    {
      "phase": "RED",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "result": "NOT_RUN",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ],
      "reason": "blocked: authoritative file_range/files/task_scope missing"
    },
    {
      "phase": "GREEN",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "result": "NOT_RUN",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ],
      "reason": "blocked: RED not permitted without authoritative task scope"
    },
    {
      "phase": "REFACTOR",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "result": "NOT_RUN",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ],
      "reason": "blocked: no GREEN phase"
    }
  ]
}
```

如果你愿意，我下一步可以继续做两件事里的一个：
1. 按这份样本，帮你把 `T1` 的**完整执行计划**写成可交付的 developer 报告文字版
2. 帮你定位这个 eval 里**应该由谁补齐 `task_scope`**，以及补齐后我会如何进入 TDD