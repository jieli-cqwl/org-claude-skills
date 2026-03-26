# 阶段 3：整体审查与验收 — 调度详情

> 执行哪些阶段由 SKILL.md Phase 3 分级表决定（轻量/标准/完整）。以下为各阶段的完整定义，按分级裁剪执行。

## Code Review — REVIEW_A + REVIEW_B（可并行）

```
9a. Agent(subagent_type: "code-reviewer", scope=审查-A) → 代码安全性审查（正确性 + 安全性 + 错误处理）
    → REVIEW_A_OK / REVIEW_A_ISSUE
9b. Agent(subagent_type: "code-reviewer", scope=审查-B) → 代码规范审查（设计 + 测试覆盖 + 注释准确性 + 接口变更合规性：developer-report 中的接口变更记录是否符合分级标准，微调级变更确实未改变路径/方法/职责/核心结构）
    → REVIEW_B_OK / REVIEW_B_ISSUE
汇总：全部 OK → REVIEW_OK / 任一 ISSUE → REVIEW_ISSUE
```

> 报告格式：code-review-report.md 顶部标注 `审查分级: [轻量/标准/完整]`，未执行阶段标注 `N/A`。
> 结果记录要求：每个 ISSUE 需有稳定 issue id；报告末尾追加 metadata（见 `references/templates/code-review-report-template.md`）。

- REVIEW_ISSUE → Agent(subagent_type: "fixer") 仅修复对应组的问题 → 重做对应检查组 → 回 9
- REVIEW_OK → 进入 QA

## QA 验收 — QA_A 串行优先，QA_B/C/D 可并行

> 每个 QA 子代理派发 prompt 必须包含 `test-cases.md` 路径引用，供 QA 在验证-A 中参考预设计的测试用例和 AC-TC 映射。

```
10a. Agent(subagent_type: "qa", scope=验证-A, test_cases_ref="{work_dir}/test-cases.md") → AC 验收（脚本化）
     → QA_A_OK / QA_A_ISSUE
10b. Agent(subagent_type: "qa", scope=验证-B, test_cases_ref="{work_dir}/test-cases.md") → E2E 用户旅程（端到端）
     → QA_B_OK / QA_B_ISSUE
10c. Agent(subagent_type: "qa", scope=验证-C, test_cases_ref="{work_dir}/test-cases.md") → 回归验证（防御性）
     → QA_C_OK / QA_C_ISSUE
10d. Agent(subagent_type: "qa", scope=验证-D, test_cases_ref="{work_dir}/test-cases.md") → 探索性测试（创造性）
     → QA_D_OK / QA_D_ISSUE
汇总：全部 OK → QA_PASS / 任一 ISSUE → QA_FAIL
```

> 报告格式：qa-report.md 顶部标注 `审查分级: [轻量/标准/完整]`，未执行阶段标注 `N/A`。
> 结果记录要求：每个 ISSUE 需有稳定 issue id；报告末尾追加 metadata（见 `references/templates/qa-report-template.md`）。

### 收敛判定

收敛判定遵循 `reference/review-fix-loop-protocol.md`。每轮 Review-Fix / QA-Fix 循环后记录 FAIL 数量：
- 正常收敛: delta_findings = 0（新增发现数为 0）
- 不收敛: 连续 2 轮 FAIL 数不减少（含不减反增）→ AskUserQuestion 暂停，展示历次 FAIL 数趋势 + 重复 FAIL 项
- 熔断: 同一问题连续 3 轮未关闭 → BLOCKED
- 浅通过防护: 首轮无问题时强制执行第 2 轮确认
- 上限: 最多 10 轮，达上限强制终止并输出未收敛原因 + 残留问题清单

### QA 失败处理

- QA_A_ISSUE → 基础 AC 验收失败，跳过 QA-B/C/D，直接进入 fixer → code-review → 重做 QA-A
- QA_B/C/D_ISSUE → fixer 仅修复对应阶段的问题 → code-review → 仅重做失败的 QA 阶段（已通过的阶段保持 OK 状态）

> 修复路径中的 code-review 为变更范围的快速审查（仅审查 fixer 修改的文件），非完整的 REVIEW_A + REVIEW_B 重做。

- QA_PASS → [交付确认]

### 用户豁免（仅在用户明确同意时）

- 豁免必须落盘到 `waivers.md`，并关联具体 issue id，禁止“整阶段一键豁免”
- `REVIEW_A` 与 `QA_A` 为不可豁免项
- 豁免后仍需执行最小补偿控制（如额外监控、时间窗限制、回滚预案）

### 局部成功保持

修复后仅重做失败的检查组/QA 阶段，已通过的保持 OK 状态不重复执行。例外：fixer 修改了已通过阶段涉及的文件时，该阶段需要重新验证。
