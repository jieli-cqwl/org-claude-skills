我按 `shared/skills/developer/SKILL.md` 读完了这次 eval 的约束，并检查了 `design.json`、`tasks.json`、`test-cases.json`、`artifact-registry.json`、`delivery-state.json`、`UNIT-1.json`。

结论先说：
- 这次 `T1` 的前置条件里，`design.json` 和 `tasks.json` 都在。
- 但 `tasks.json` 没有提供 `file_range` / `files` / `task_scope`，所以**真实代码改动范围是空集合**。
- 你这次又明确说“本 eval 不要求实际改代码”，所以我不会做代码修改，只会说明我会怎么拆解、怎么做 RED/GREEN、自测，以及 `developer-report.json` 应该怎么落。

**我会如何拆解 T1**

`T1 = freeze foundation contracts`，对应的 AC 是 `AC-T1-1`，test ref 是 `TC-T1-1`，目标是“foundation registry, schema, template, and catalog are frozen”。

我会按下面 5 步做执行拆解：

1. 代码探索
- 读 `design.json` 里和 T1 相关的 canonical 设计片段。
- 读 `UNIT-1.json` 确认验收边界是 foundation 冻结，不包含 legacy migration。
- 读同级的 registry / delivery-state / plan / QA / review，确认当前 active 版本和运行时状态。
- 记录可复用点：例如已经存在的 canonical registry、schema、template、catalog 结构，不重复造轮子。

2. 模式识别与复用判断
- 识别当前仓库是否已有“canonical JSON + active registry + phase state”这一套模式。
- 如果已有语义一致实现，就复用同类校验/写入/冻结逻辑。
- 如果没有可复用候选，就在报告里明确写“无复用候选”，但这次因为不改代码，所以只做说明，不落实现。

3. 步骤规划
- 把 `AC-T1-1` 转成一个最小 TDD 步骤组：
  - RED：补一个能证明“foundation 未冻结/冻结校验失败”的测试。
  - GREEN：实现最小的冻结校验或冻结标记逻辑。
  - REFACTOR：在测试保护下收敛命名、拆分边界、清理重复。
- 这一步本任务只做计划，不实际改代码。

4. 风险标注
- 关键风险是：任务没有 `file_range/files/task_scope`，所以按 skill 规则，**允许修改集合为空**。
- 另一个风险是：`T1` 名称是“freeze foundation contracts”，如果上游设计对“冻结”的定义不够具体，容易把“校验冻结”误做成“生成冻结”。需要以 canonical artifact 语义为准。

5. 确认 / 阻断
- 因为本次不需要实际改代码，而且修改范围为空，所以不会进入真实 TDD 改码。
- 如果要进入实现阶段，需要 delivery-owner 补齐明确的文件范围。

**如果真的执行 RED / GREEN，我会这样跑**

- RED
  - 选 `TC-T1-1` 对应的测试场景。
  - 先运行测试，确认它失败。
  - 失败要能直接证明“foundation contract 还没被冻结”或“冻结校验不通过”。

- GREEN
  - 用最小改动让测试通过。
  - 只覆盖 `T1`，不碰 `T2`，不扩功能。

- REFACTOR
  - 在测试全绿前提下，收敛结构和命名。
  - 不做范围外优化。

**自测我会怎么做**

按 skill 的 5 层自测：

1. 测试完备性审视
- 对照 `test-cases.json`，确认 `AC-T1-1` 已有对应测试。
- 检查是否漏了边界、错误路径、排除项。
- 这次 `T1` 是 foundation 冻结，重点看“未冻结”“重复冻结”“冻结后仍可改写”这类边界。

2. 全量回归
- 跑完整测试套件，而不是只跑新增测试。
- 如果存在既有失败，标记为 blocked，不把任务算完成。

3. 静态分析
- 跑 lint、类型检查、构建。
- 必须全过。

4. 功能集成冒烟
- 如果这个任务涉及真实服务或可执行链路，就跑冒烟。
- 如果只是纯 canonical JSON / schema / catalog 约束，没有可启动服务，就写“不适用”，并说明原因。

5. E2E
- 如果有前端/端到端链路就跑。
- 这个 sample-feature 看起来更像 canonical 链路工件，不像 UI 任务，所以大概率写“不适用”。

**`developer-report.json` 我会怎么输出**

因为你要求“说明如何输出”，我会按 canonical runtime template 填一个完整 JSON 骨架。
这次由于不实际改代码，`file_changes` 会是空数组；由于没有实际运行测试，`tdd_evidence_index` 也只能写“未执行 / BLOCKED / N/A”。

一个适合这次 eval 的骨架如下：

```json
{
  "artifact_type": "developer-report",
  "artifact_id": "sample-feature.phase-1.unit-1.T1.developer-report",
  "schema_version": "1.0.0",
  "producer": "developer",
  "produced_at": "2026-04-22T00:00:00Z",
  "task_id": "T1",
  "task_title": "freeze foundation contracts",
  "unit_id": "UNIT-1",
  "runtime_status": "BLOCKED",
  "blocker_reason": "task_scope/file_range/files not provided; allowed modification set is empty, and this eval explicitly requests no code changes",
  "task_scope": [],
  "file_changes": [],
  "execution_decomposition": {
    "code_exploration": [
      "Read canonical design and unit definition to confirm foundation freeze boundary",
      "Read active registry and delivery-state to confirm current phase truth source",
      "Confirmed test case coverage for AC-T1-1"
    ],
    "reuse_candidates": [
      "canonical registry/state validation patterns, if implementation were needed"
    ],
    "implementation_steps": [
      {
        "step": 1,
        "phase": "RED",
        "ac": "AC-T1-1",
        "target_files": [],
        "mode": "would write failing test for foundation freeze contract",
        "reuse": "canonical validation pattern"
      },
      {
        "step": 2,
        "phase": "GREEN",
        "ac": "AC-T1-1",
        "target_files": [],
        "mode": "would implement minimal freeze behavior",
        "reuse": "existing canonical artifact handling"
      },
      {
        "step": 3,
        "phase": "REFACTOR",
        "ac": "AC-T1-1",
        "target_files": [],
        "mode": "would clean up while keeping tests green",
        "reuse": "same as above"
      }
    ],
    "risks": [
      "No file range was declared, so real implementation is blocked by contract",
      "Task semantics are canonical-freeze oriented, so a write-path implementation would be out of scope"
    ],
    "confirmation": "No code changes requested in this eval; proceed as explanation-only"
  },
  "tdd_evidence_index": [
    {
      "ac": "AC-T1-1",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "red": {
        "status": "NOT_RUN",
        "evidence_ref": null,
        "result": "BLOCKED"
      },
      "green": {
        "status": "NOT_RUN",
        "evidence_ref": null,
        "result": "BLOCKED"
      }
    }
  ],
  "self_test": {
    "test_completeness_review": {
      "status": "PASS",
      "notes": "AC-T1-1 is represented by TC-T1-1 in test-cases.json"
    },
    "full_regression": {
      "status": "NOT_RUN",
      "reason": "eval is explanation-only"
    },
    "static_analysis": {
      "status": "NOT_RUN",
      "reason": "eval is explanation-only"
    },
    "smoke": {
      "status": "N/A",
      "reason": "no runnable service boundary in this explanation-only eval"
    },
    "e2e": {
      "status": "N/A",
      "reason": "no front-end end-to-end chain in this explanation-only eval"
    }
  },
  "self_review": {
    "ac_completeness": "BLOCKED",
    "tdd_completeness": "BLOCKED",
    "evidence_completeness": "BLOCKED",
    "scope_compliance": "PASS",
    "code_quality": "PASS",
    "report_completeness": "PASS",
    "execution_decomposition_followed": "PASS"
  },
  "reviewable_anchor": {
    "primary": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
    "secondary": "artifact://design/sample-feature.phase-1.design@v1#key-decisions"
  },
  "evidence_refs": [
    "artifact://design/sample-feature.phase-1.design@v1#key-decisions",
    "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-T1",
    "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
    "artifact://unit-definition/sample-feature.phase-1.unit-1@v1#unit",
    "artifact://delivery-state/sample-feature.phase-1.delivery-state@v1#tasks"
  ]
}
```

**这次的关键阻断点**
- 不是 `design.json` 或 `test-cases.json` 缺失。
- 是 `tasks.json` 没有明确 `file_range/files/task_scope`，所以如果要做真实实现，按 skill 规则只能先找 delivery-owner 补齐。
- 由于你这次明确说“不要求实际改代码”，所以我把它处理成“解释型 eval”：给出完整拆解和报告骨架，但不宣称已完成 TDD。

如果你愿意，我下一步可以直接把这个 `developer-report.json` 骨架整理成更贴近该仓库 canonical 模板的最终版。