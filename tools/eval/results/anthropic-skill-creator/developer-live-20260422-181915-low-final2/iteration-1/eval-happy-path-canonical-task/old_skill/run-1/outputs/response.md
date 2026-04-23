我已按 `shared/skills/developer/SKILL.md` 核对过这次 eval 的前置条件。

结论先说：**当前不能进入真正的 TDD 执行**，原因是 `tasks.json` 里只有 `design_refs` / `test_refs`，**没有可执行所需的 `file_range` / `files` / `task_scope`**。按 skill 规则，这会导致**允许修改集合为空**，因此我不能宣称会实际改代码，也不能伪造 RED/GREEN 证据。

我会这样处理这次 `sample-feature / T1`：

1. 先确认输入事实
- `design.json` 存在，且设计边界指向：
  - `tools/community/canonical_ref_resolver.py`
  - `tools/community/manage_artifact_registry.py`
  - `tools/community/update_delivery_state.py`
- `tasks.json` 中 T1 的 AC 只有 `AC-T1-1`
- `test-cases.json` 中 T1 对应 `TC-T1-1`
- 但**任务未声明可修改文件范围**，所以不能进入实际改动

2. 如果只是说明“我会如何拆”
- 代码探索：看设计边界文件、同级目录惯例、相关测试 fixture
- 模式识别：提炼 canonical JSON、registry、delivery-state 的既有约定
- 步骤规划：把 `AC-T1-1` 拆成 RED -> GREEN -> REFACTOR
- 风险标注：重点记录“文件范围缺失”“不可越界改动”“只能阻断等待补齐”
- 确认/提问：向 delivery-owner 要求补齐 `file_range/files/task_scope`

3. 如果文件范围补齐后，TDD 会这样跑
- RED
  - 从 `test-cases.json` 的 `TC-T1-1` 推导/定位失败用例
  - 先运行，确认失败是预期失败
- GREEN
  - 只做最小实现，限制在声明文件范围内
  - 再跑同一测试，确认通过
- REFACTOR
  - 在测试保护下清理结构，不扩大行为
  - 重跑测试，保持 PASS
- 自测
  - 全量回归
  - lint / type / build
  - 如适用再做烟测 / E2E
- 输出 `developer-report.json`
  - 写清 `runtime_status`
  - 填 `evidence_refs`
  - 填 `reviewable_anchor`
  - 填 `tdd_evidence_index`
  - 填 `task_scope`
  - 填 `file_changes`

按当前信息，`developer-report.json` 我会写成下面这种**阻断态骨架**：

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
  "summary_text": "task scope is missing; cannot start RED/GREEN safely",
  "active_plan_version_ref": "artifact://plan/sample-feature.phase-1.plan@plan-v2#plan-version",
  "active_tasks_version_ref": "artifact://tasks/sample-feature.phase-1.tasks@tasks-v2#task-registry",
  "evidence_refs": [],
  "reviewable_anchor": "artifact://developer-report/sample-feature.phase-1.unit-1.task-T1.developer-report@v1#tdd-evidence-index",
  "file_changes": [],
  "tdd_evidence_index": [],
  "task_scope": [],
  "blockers": [
    {
      "code": "MISSING_TASK_SCOPE",
      "message": "tasks.json does not declare file_range/files/task_scope for T1"
    }
  ]
}
```

如果你要，我下一步可以继续做两种之一：
1. 直接按这个 eval 的要求，帮你把**完整的说明稿**整理成可提交的中文答案。
2. 如果你愿意补齐任务范围，我再按 skill 继续往下模拟完整 RED/GREEN/self-test 流程。