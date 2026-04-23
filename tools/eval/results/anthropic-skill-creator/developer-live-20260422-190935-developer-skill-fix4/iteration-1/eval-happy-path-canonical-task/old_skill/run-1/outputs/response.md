我会按 `developer` skill 的标准流程处理这个 `T1`，但这次只做“说明方案”，不实际改代码。

**先确认结论**
- `design.json`、`tasks.json`、`test-cases.json` 都存在
- `UNIT-1` 的闭包目标是 `foundation registry, schema, template, and catalog are frozen`
- `T1` 的 AC 只有 1 条：`AC-T1-1`
- 由于你明确说“本 eval 不要求实际改代码”，所以这里会停在“执行方案 + `developer-report.json` 骨架说明”，不进入真实改动

**我会怎么拆解**
1. 代码探索
- 先读 `design.json` 里的 `key-decisions`、`interface_boundary`、`verification_plan`
- 再读 `tasks.json` 里 `T1` 的 `design_refs`、`test_refs`、`shared_files`
- 再读 `test-cases.json` 里 `AC-T1-1` 对应的测试语义
- 再对照同目录下已有的 `developer-report.json` / `verify-result.json` 风格，确认报告字段和证据锚点格式

2. 模式识别与复用判断
- 这类 foundation task 走的是“canonical JSON 工件 + registry 驱动”的模式
- 可复用的不是业务逻辑，而是既有的 schema / registry / report 结构
- 重点是确认报告里必须有：
  - `evidence_refs`
  - `reviewable_anchor`
  - `file_changes`
  - `tdd_evidence_index`
  - `task_scope`

3. 实现步骤映射到 AC
- `AC-T1-1`
  - RED：先写一个最小测试，验证 foundation catalog / schema contracts 对 active artifacts 的校验失败
  - GREEN：补齐最小实现，让该测试通过
  - REFACTOR：如果没有可重构点，就记 `REFACTOR: no-op`
  - 自测：再跑全量回归、lint、type、build；冒烟和 E2E 若不适用，必须写明原因

4. 风险标注
- 这个任务的主要风险是“只改报告不改实现”会伪造完成度，所以必须用 `RED -> GREEN -> self-test` 的证据闭环
- 如果 `file_range` 不明确，按 skill 规则应阻断，不允许越界改文件
- 但这次是说明模式，不涉及真实变更，所以不会触发越界修改

**RED/GREEN 我会怎么跑**
- `RED`
  - 从 `test-cases.json` 的 `TC-T1-1` 推出一个失败测试
  - 目标是先证明当前状态下还不满足 foundation contracts 的约束
- `GREEN`
  - 用最小改动让该测试通过
  - 只修 AC 相关路径，不扩展到 `T2`
- `REFACTOR`
  - 仅在测试保护下做整理
  - 如果无可整理项，明确写 `REFACTOR: no-op`

**自测我会怎么做**
1. 测试完备性审视
- 对照 `test-cases.json`，确认 `AC-T1-1` 有对应测试覆盖
- 如果发现缺口，补测后再回到 RED -> GREEN

2. 全量回归
- 跑完整测试套件，确认没有回归
- 如果有既有失败，报告必须标为 `BLOCKED` 或 `部分完成`

3. 静态分析
- `lint`
- `typecheck`
- `build`
- 三项都要记录结果

4. 冒烟 / E2E
- 如果这个 eval 没有可运行服务或浏览器场景，就写 `不适用`，并说明理由
- 不能省略不写

**`developer-report.json` 我会如何输出**
下面是符合这个 skill 语义的骨架，重点是把证据锚点和 TDD 索引写清楚：

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
  "evidence_refs": [
    "artifact://evidence/sample-feature.phase-1.task-T1.log@ev-1#log-root"
  ],
  "active_plan_version_ref": "artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version",
  "active_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
  "task_id": "T1",
  "runtime_status": "BLOCKED",
  "summary_text": "说明模式下输出 T1 的 TDD 执行方案与报告骨架，未执行真实代码改动",
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
    }
  ],
  "task_scope": []
}
```

**如果这是实际执行而不是说明**
- 我会先进入 RED，确认测试真的失败
- 再做最小 GREEN
- 然后补充自测
- 最后才写入 `developer-report.json`

如果你要，我下一步可以直接把这个 eval 的 **“可提交版 developer-report.json 完整字段清单”** 再展开成更贴近 canonical 模板的版本。