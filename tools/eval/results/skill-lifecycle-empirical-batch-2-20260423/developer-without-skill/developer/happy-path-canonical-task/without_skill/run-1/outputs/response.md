我按这次 eval 的边界处理：不读取 `shared/skills/developer/SKILL.md`，不实际改代码。  
`work_dir` 是 `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1`，所以真实执行时第一步应先从 phase 根目录或 active registry 解析活动工件，而不是直接写实现：[artifact-registry.json](/Users/lijieli/org-claude-skills/.worktrees/codex-skill-lifecycle-eval-batch-2/tools/eval/results/skill-lifecycle-empirical-batch-2-20260423/developer-without-skill/_workspaces/without_skill/developer/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/artifact-registry.json)、[tasks.json](/Users/lijieli/org-claude-skills/.worktrees/codex-skill-lifecycle-eval-batch-2/tools/eval/results/skill-lifecycle-empirical-batch-2-20260423/developer-without-skill/_workspaces/without_skill/developer/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/tasks.json)、[design.json](/Users/lijieli/org-claude-skills/.worktrees/codex-skill-lifecycle-eval-batch-2/tools/eval/results/skill-lifecycle-empirical-batch-2-20260423/developer-without-skill/_workspaces/without_skill/developer/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json)、[test-cases.json](/Users/lijieli/org-claude-skills/.worktrees/codex-skill-lifecycle-eval-batch-2/tools/eval/results/skill-lifecycle-empirical-batch-2-20260423/developer-without-skill/_workspaces/without_skill/developer/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/test-cases.json)。当前 registry 里这些工件是 active 的。`T1` 是 `freeze foundation contracts`，对应 `AC-T1-1` / `TC-T1-1`；UNIT-1 的关闭条件是 `foundation registry, schema, template, and catalog are frozen`，设计里又写明 `registry controls path discovery`，所以 T1 的真实文件范围应先锁定 foundation contract / catalog 相关实现，再做源码复用判断和依赖追踪。

**门禁**
- 必须先读取 `design.json`、`tasks.json`、`test-cases.json`，或通过 active registry 解析出它们的 active path；任一缺失或 inactive，停止真实修改。
- 必须把 `AC-T1-1` 映射到具体测试入口和文件范围；做不到时，停止真实修改，不能猜测后开工。
- 必须先做复用判断，再决定是否新增实现。
- 必须先拿到 RED 失败证据，再进入 GREEN。
- 当前临时 eval workspace 只有 fixture 工件，没有 `tools/community/*`、`contracts/*` 和可执行的目标测试入口，所以真实 RED/GREEN/自测在这里应判定为阻断；只能说明流程，不能 truthfully 产出新的最终 `developer-report.json` 或把状态写成 `VERIFIED`。

**RED / GREEN / 自测**
1. 拆解 T1：把目标收敛成一个最小 AC 切片，核心是“foundation catalog/schema contract 能校验 active artifacts，且对 malformed entry 明确失败”。
2. RED：先补一个只覆盖 `AC-T1-1` 的 targeted test，让它因 foundation contract 缺失、catalog 未注册完整或 malformed artifact entry 未被拒绝而失败。
3. GREEN：只在 T1 文件范围内做最小改动，让该测试转绿，不提前动 `T2` 的 runtime state tooling。
4. REFACTOR：保持测试为绿，只清理命名、重复和注释，不扩行为。
5. 自测：先跑 T1 targeted test，再跑 design 里的 `phase validation`、`readiness validation`、`replay oracle validation`。没有 fresh proving command 全绿，不能宣称完成。

**`developer-report.json` 必需字段**
- 元数据：`artifact_type`、`artifact_id`、`schema_version`、`producer`、`produced_at`、`chain_version`、`chain_registry_digest`、`authority_scope`
- 任务定位：`task_id`
- 活动版本引用：`active_plan_version_ref`、`active_tasks_version_ref`
- 结果与证据：`runtime_status`、`evidence_refs`、`reviewable_anchor`
- 变更范围：`file_changes`、`task_scope`
- TDD 证据：`tdd_evidence_index`
- authoritative fields 至少包含：`$.runtime_status`、`$.active_plan_version_ref`、`$.active_tasks_version_ref`、`$.evidence_refs`、`$.reviewable_anchor`、`$.tdd_evidence_index`

可用骨架如下，当前 eval 只能保留占位，不能填写最终通过值：
```json
{
  "artifact_type": "developer-report",
  "artifact_id": "sample-feature.phase-1.unit-1.task-T1.developer-report",
  "schema_version": "1.0.0",
  "producer": "developer",
  "produced_at": "<实际产出时间>",
  "chain_version": "standard-chain/v1",
  "chain_registry_digest": "<从active registry读取>",
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
  "active_plan_version_ref": "<从active registry读取>",
  "active_tasks_version_ref": "<从active registry读取>",
  "runtime_status": "<仅在真实验证通过后才能写 VERIFIED>",
  "summary_text": "<本次T1实现摘要>",
  "evidence_refs": ["<日志/测试证据ref>"],
  "reviewable_anchor": "<report anchor>",
  "file_changes": ["<真实修改文件>"],
  "task_scope": ["<真实任务范围>"],
  "tdd_evidence_index": [
    {
      "phase": "RED",
      "test_ref": "<AC-T1-1对应测试>",
      "result": "FAIL_EXPECTED",
      "ac_refs": ["artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"]
    },
    {
      "phase": "GREEN",
      "test_ref": "<同一测试>",
      "result": "PASS",
      "ac_refs": ["artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1"]
    }
  ]
}
```

**下一步**
- 若要真实执行这条 developer 链路，先补齐当前 workspace 缺失的源码与测试入口，至少要有 design 指向的实现文件和 T1 的 targeted test。
- 补齐后按顺序做：解析 active registry → 确认复用候选与最终文件范围 → 写 RED → 最小 GREEN → 跑 targeted test + phase validation + readiness/replay → 仅在证据真实通过后写最终 `developer-report.json`。