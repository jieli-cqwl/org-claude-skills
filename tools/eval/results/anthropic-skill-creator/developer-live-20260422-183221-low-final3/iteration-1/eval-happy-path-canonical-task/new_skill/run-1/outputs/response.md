我理解的是：这次只针对 `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1` 里的 `Task T1` 做 skill eval，目标不是改代码，而是说明如果按 `developer` skill 执行，我会怎么拆解、怎么跑 `RED -> GREEN -> 自测`，以及 `developer-report.json` 应该怎么落。

先说结论：这个输入目前**前置条件不够完整，实际执行会被 skill 阻断**，原因是 `tasks.json` 里只有 `design_refs` / `test_refs`，**没有 `file_range`、`files` 或 `task_scope`**。按 skill 规则，这意味着我不能合法进入真实实现阶段；如果是正式交付，`runtime_status` 应记为 `BLOCKED`，并等待 delivery-owner 补齐可修改文件范围。

不过，按你的要求，我可以把“我会如何做”讲清楚，针对 `T1: freeze foundation contracts` 的执行方式如下。

**我会怎么拆解**

1. 先读权威输入
   - `phase-1/design.json`
   - `phase-1/tasks.json`
   - `phase-1/unit-1/test-cases.json`
   - 以及同目录下的现成产物做参照，比如 `unit-1/tasks/T1/developer-report.json`

2. 识别 T1 的 AC
   - `AC-T1-1`：对应 `TC-T1-1`
   - 这个 AC 的含义是“foundation catalog and schema contracts validate active artifacts”

3. 识别可复用模式
   - `design.json` 明确了 runtime truth 依赖 `artifact-registry.json` 和 `delivery-state`
   - `artifact-registry.json` 已经是 append-only、active revision 驱动的 canonical 形态
   - `T1` 现成的 `developer-report.json` 也说明这个任务的证据链重点是：
     - RED 先证明 foundation contract 还没满足
     - GREEN 再证明相关校验通过
     - 最终产出的是 report 和证据索引，而不是随意改一堆实现

**我会怎么跑 RED / GREEN**

因为这是 `foundation contracts`，我会把它理解成“先让测试精确失败，再最小化修复到通过”。

1. RED
   - 只针对 `AC-T1-1` 写或补一个能表达该契约的测试
   - 测试目标会围绕：
     - canonical 目录里的 artifact catalog 是否能正确解析
     - schema / registry contract 是否会拒绝 malformed 或不一致的 active artifact
   - 先运行测试，确认它**失败且失败原因符合预期**，这一步才算 RED

2. GREEN
   - 只做满足 `AC-T1-1` 的最小改动
   - 不扩展到 T2，不顺手重构别的链路
   - 改完后重跑同一个测试，确认它通过

3. REFACTOR
   - 如果实现里有重复逻辑、硬编码、或可以抽成共享函数，就在测试保护下收敛
   - 如果没有可重构点，就写 `REFACTOR: no-op`
   - REFACTOR 后必须再跑一遍相关测试，确保仍然 PASS

**我会怎么做自测**

按 skill 的 5 层自测口径，我会这样执行：

1. 测试完备性审视
   - 对照 `test-cases.json`
   - 确认 `AC-T1-1` 已被 `TC-T1-1` 覆盖
   - 检查是否有边界和错误路径缺口
   - 这次任务如果只处理 foundation contracts，重点是“坏数据是否被拒绝”，而不是运行态功能流

2. 全量回归
   - 跑项目的完整测试套件，而不只是新增测试
   - 目标是证明没有引入别的回归
   - 如果发现既有失败，要标注为既有问题，结论不能写成完成

3. 静态分析
   - 跑 lint
   - 跑类型检查
   - 跑 build
   - 这三项都要 PASS 才能算自测完整

4. 功能集成冒烟
   - 这类 foundation contract 任务通常偏纯工具 / 纯契约校验
   - 如果没有真实服务可启动，就明确写 `不适用`，并给理由
   - 如果项目里确实有可启动服务，再做一次真实调用和健康检查

5. E2E
   - 如果没有前端链路或 E2E 框架，也写 `不适用`
   - 有的话就按 `TC-T1-1` 触发对应场景

**我会如何输出 `developer-report.json`**

如果是正式交付，我会把 report 写成 canonical JSON，并至少包含这些关键字段：

- `runtime_status`
- `active_plan_version_ref`
- `active_tasks_version_ref`
- `evidence_refs`
- `reviewable_anchor`
- `file_changes`
- `tdd_evidence_index`
- `task_scope`

但基于当前输入，`task_scope` 不可解析到可修改文件范围，所以正式报告会是：

- `runtime_status: "BLOCKED"`
- `task_scope: []`
- `file_changes: []`

**对应的 report 骨架会长这样：**

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
  "summary_text": "Task scope is incomplete; file_range/files/task_scope is not declared in tasks.json",
  "reviewable_anchor": "artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index",
  "file_changes": [],
  "tdd_evidence_index": [],
  "task_scope": []
}
```

**这次 eval 的最终判断**

- 我能明确说明 `T1` 的拆解、RED/GREEN、自测和报告结构
- 但按 `developer` skill 的硬规则，当前 `tasks.json` 没有声明可修改文件范围，所以**真实执行应阻断**
- 如果你愿意，我下一步可以继续帮你把这份 eval 产出整理成一个更像最终交付的 `developer-report.json` 文本版，或者按这个 workspace 里现有样例，逐字段对照解释它为什么是这个结构