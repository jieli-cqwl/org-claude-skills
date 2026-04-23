我先按 `developer` skill 复述一下当前结论：本次对象是 `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1` 下的 `T1`，已存在 `design.json`、`tasks.json`、`test-cases.json`，并且 `T1` 只覆盖 `AC-T1-1`。
但按该 skill 的硬门槛，**真实代码实现前必须有显式 `file_range/files/task_scope`**；当前 `tasks.json` 里没给出可直接修改的权威文件范围，所以如果这是实做任务，我会先阻断并向 `delivery-owner` 补齐范围。因为你这次明确说“**不要求实际改代码**”，下面我给的是我会怎么拆解、怎么跑 RED/GREEN、怎么自测，以及 `developer-report.json` 会怎么写。

**拆解方式**
1. 代码探索
   - 先看 `design.json` 的 `key-decisions` 和 `interface_boundary`
   - 再看 `tasks.json` 里的 `T1`、`design_refs`、`test_refs`
   - 再看 `test-cases.json` 里的 `AC-T1-1` 和 `TC-T1-1`
   - 结合现有的 `developer-report.json` 样例，确认报告字段和证据格式

2. 复用判断
   - `T1` 是 foundation contracts，优先复用现有 canonical JSON、registry、schema 的表达方式
   - 不新建抽象层，不扩展到 `T2` 的 runtime tooling 范围
   - 只围绕 `AC-T1-1` 做最小闭环

3. TDD 步骤
   - RED：先写一个能直接覆盖 `TC-T1-1` 的失败测试/失败检查
   - GREEN：只做最小实现让这个测试过
   - REFACTOR：在测试保护下清理，若无可重构项就记 `REFACTOR: no-op`

4. 风险标注
   - 不能越过 `T1` 范围去碰 `T2`
   - 不能修改未声明的文件
   - 若设计或任务里没有明确文件范围，真实实现必须先停下来补范围

5. 确认
   - 这次是说明模式，所以我不会真的改文件
   - 如果是实做任务，我会先向 `delivery-owner` 确认文件范围，再进入写代码

**RED / GREEN 我会怎么跑**
- RED
  - 先针对 `AC-T1-1` 选最小验证入口
  - 目标是让它先失败，并在报告里记为 `FAIL_EXPECTED`
  - 失败证据要能指回 `TC-T1-1`

- GREEN
  - 只补最小改动，让同一个测试通过
  - 不顺手做额外功能
  - 通过后复跑同一条测试，记录 `PASS`

- REFACTOR
  - 只有在测试仍然全绿时才整理
  - 如果没有可改的结构，就写 `REFACTOR: no-op`
  - 然后再跑一次同类验证，确保没回退

**自测我会怎么做**
1. 先对照 `test-cases.json` 检查覆盖是否完整
2. 跑这次任务相关的回归验证
3. 跑静态分析：
   - lint
   - type check
   - build
4. 如果有真实服务，再做冒烟验证
5. 如果有 E2E，再跑对应端到端检查
6. 如果某项不适用，必须写清楚原因，不能省略

**`developer-report.json` 我会怎么输出**
- 这是按你给的样例风格，且贴合本次 `T1` 的骨架。
- 因为本次不做实际改代码，所以我会把它当作“说明版骨架”来写；真实执行时，`runtime_status` 应该由实际测试结果决定。

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
  "summary_text": "说明模式下给出 T1 的 TDD 执行方案；真实实现因缺少显式 file_range/files/task_scope 需先补齐范围",
  "reviewable_anchor": "artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index",
  "file_changes": [],
  "tdd_evidence_index": [
    {
      "phase": "RED",
      "commit_sha": "",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "result": "FAIL_EXPECTED",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ]
    },
    {
      "phase": "GREEN",
      "commit_sha": "",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "result": "PASS",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ]
    },
    {
      "phase": "REFACTOR",
      "commit_sha": "",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "result": "PASS",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ]
    }
  ],
  "task_scope": []
}
```

如果你要，我下一步可以继续把这份说明压成一版更像“交付给 delivery-owner 的简短报告”，或者按“真执行版”把 `RED / GREEN / self-test` 的命令顺序写成可直接执行的 checklist。