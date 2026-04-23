我会按 `sample-feature / phase-1 / unit-1 / T1` 这个对象来处理，目标是：**不改代码，只说明如何完成 TDD、怎么自测，以及最后 `developer-report.json` 应该怎么落**。

**拆解方式**
1. 先锁定事实源
   - `work_dir`: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1`
   - `tasks.json` 里本次任务是 `T1: freeze foundation contracts`
   - `design.json` 的关键约束是：
     - runtime state 要区分 active / baseline refs
     - registry 控制路径发现
     - delivery-state 控制 phase stage
   - `test-cases.json` 里 T1 对应 `AC-T1-1`
     - case: `TC-T1-1`
     - 语义：foundation catalog 和 schema contracts 能校验 active artifacts
2. 再把 AC 转成一个最小 TDD 闭环
   - T1 只做 foundation contracts，因此只围绕“catalog / schema / active artifacts 校验”展开
   - 不碰 T2 的 runtime state tooling，避免越界
3. 设计自测顺序
   - 先验证单元/契约测试
   - 再跑全量回归
   - 再跑静态分析
   - 最后做和本任务相关的冒烟检查
   - 由于这是 eval 说明题，不实际执行，但报告结构里要预留这些证据位

**如果真的执行 RED / GREEN**
1. RED
   - 先针对 `AC-T1-1` 写一条会失败的测试
   - 失败点应该是“foundation catalog / schema contract 对 active artifacts 的校验还没满足”
   - 证据要求：测试必须是因功能缺失失败，而不是语法错
2. GREEN
   - 只补最小实现，让这条测试通过
   - 只改 T1 范围内允许的文件
   - 不引入 T2 的 runtime state 逻辑
3. REFACTOR
   - 只在测试仍绿的前提下做收敛
   - 如果没有可重构点，就写 `REFACTOR: no-op`
4. 自测
   - 对照 `test-cases.json` 确认 `TC-T1-1` 覆盖到位
   - 跑全量回归，确认没有回归
   - 跑 lint / type / build
   - 如果本任务没有可用 E2E，就在报告里明确写 `N/A` 和原因

**developer-report.json 应该怎么写**
- 这次 eval 不要求真写文件，但如果要输出，核心字段应包含：
  - `runtime_status`
  - `active_plan_version_ref`
  - `active_tasks_version_ref`
  - `evidence_refs`
  - `reviewable_anchor`
  - `tdd_evidence_index`
  - `task_scope`
  - `file_changes`
- 对 T1 来说，`tdd_evidence_index` 至少要记录：
  - `RED` 对应 `AC-T1-1`
  - `GREEN` 对应 `AC-T1-1`
  - 证据里要有 `test_ref`
  - `RED` 阶段结果写 `FAIL_EXPECTED`
  - `GREEN` 阶段结果写 `PASS`

**一个合格的报告骨架**
```json
{
  "artifact_type": "developer-report",
  "artifact_id": "sample-feature.phase-1.unit-1.task-T1.developer-report",
  "schema_version": "1.0.0",
  "producer": "developer",
  "chain_version": "standard-chain/v1",
  "task_id": "T1",
  "runtime_status": "VERIFIED",
  "active_plan_version_ref": "artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version",
  "active_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
  "evidence_refs": [
    "artifact://evidence/sample-feature.phase-1.task-T1.log@ev-1#log-root"
  ],
  "reviewable_anchor": "artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index",
  "file_changes": [],
  "tdd_evidence_index": [
    {
      "phase": "RED",
      "test_ref": "tests/...#developer-report",
      "result": "FAIL_EXPECTED",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ]
    },
    {
      "phase": "GREEN",
      "test_ref": "tests/...#developer-report",
      "result": "PASS",
      "ac_refs": [
        "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"
      ]
    }
  ],
  "task_scope": [
    "T1 only"
  ]
}
```

**这次 eval 的结论**
- 前置条件是满足的：`design.json`、`tasks.json`、`test-cases.json`、`artifact-registry.json` 都在
- 所以不是 BLOCKED
- 但因为你明确说“本 eval 不要求实际改代码”，我这里只给**可执行的拆解和报告格式**，不做代码变更，也不声称已经跑过测试

如果你愿意，我下一步可以直接把这份说明整理成一份更像 `developer-report.json` 的**完整字段级 JSON 示例**。