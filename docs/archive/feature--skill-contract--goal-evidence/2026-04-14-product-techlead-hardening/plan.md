# Product / Tech-Lead Goal Evidence Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 让 `product` 的目标定义更适合作为后续执行输入，让 `tech-lead` 的计划更适合作为后续目标闭环的执行基线，并让 gate/tests 一起收口。

**Architecture:** 先在 `product` 侧收紧“成功信号”合同和审查口径，再在 `tech-lead` 侧补上 `goal_fidelity_review` 与场景化 Task 度量/护栏合同，最后把 completion check 与 shell contract tests 收敛到同一语义。整个实现保持稳定章节锚点和既有角色边界，不新增主干工件。

**Tech Stack:** Markdown skill docs/templates, shell completion checks, shell contract tests, existing standard-chain refs/contracts.

---

## File Boundaries

- `shared/skills/product/*`
  - 负责上游业务目标、成功信号、C9 完成信号和 reviewer 审查口径。
- `shared/skills/tech-lead/*`
  - 负责计划级目标承接、Task 级执行度量/护栏和 reviewer 审查口径。
- `tests/*`
  - 负责把新合同冻结为可回归的断言。

## Execution Order

- `T1` 先改 `product` 文档与模板，再改 `product` reviewer prompts。
- `T2` 在 `product` 合同稳定后改 `tech-lead` 文档、模板与 prompts。
- `T3` 最后更新 gate 和 tests，并跑 fresh proving commands。

### Task 1: Product success-signal contract [T1]

Files:
- Modify: `shared/skills/product/SKILL.md`
- Modify: `shared/skills/product/references/templates/brief-template.md`
- Modify: `shared/skills/product/references/completeness-checklist.md`
- Modify: `shared/skills/product/references/prd-reviewer-prompt.md`
- Modify: `shared/skills/product/references/tester-reviewer-prompt.md`
- Test: `tests/test-product-stability-guidance-contract.sh`

1. [T1] 先写 RED 测试，给 `tests/test-product-stability-guidance-contract.sh` 增加缺失断言，锁定新增合同语义。

```bash
rg -n "度量类型|当前基线|目标值/方向|观测窗口|数据来源" \
  shared/skills/product/SKILL.md \
  shared/skills/product/references/templates/brief-template.md \
  shared/skills/product/references/completeness-checklist.md
```

2. [T1] 运行 RED，确认新增断言当前失败，且失败点落在我们准备新增的字段上。

Run: `bash tests/test-product-stability-guidance-contract.sh`
Expected: FAIL，提示 `product` skill 或 brief template 缺少新增成功信号字段。

3. [T1] 最小修改 `product` 文档真源，只增强现有章节，不改稳定锚点。

```markdown
## 目标与成功标准

| 目标 | 成功标准 | 度量类型 | 当前基线 | 目标值/方向 | 观测窗口 | 数据来源 |
|------|---------|---------|---------|------------|---------|---------|
```

```markdown
3. 全共创：目标与成功标准对齐
- 新增要求：确认当前基线、目标值或方向、观测窗口、数据来源
```

4. [T1] 更新 C9 和 reviewer prompt，让“成功信号完整性”成为显式审查项。

```markdown
| C9 | 完成信号 | MVP 范围是否明确？成功信号是否包含基线、目标值/方向、观测窗口和数据来源？观察型信号是否说明原因？ | Clear / Partial / Missing |
```

5. [T1] 运行 GREEN，确认 `product` 新合同的静态断言通过。

Run: `bash tests/test-product-stability-guidance-contract.sh`
Expected: PASS，输出 `[PASS] product stability guidance contract`

### Task 2: Tech-lead goal-fidelity and execution-metric contract [T2]

Files:
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `shared/skills/tech-lead/references/templates/plan-template.md`
- Modify: `shared/skills/tech-lead/references/planning-modes.md`
- Modify: `shared/skills/tech-lead/references/plan-reviewer-prompt.md`
- Modify: `shared/skills/tech-lead/references/plan-product-reviewer-prompt.md`
- Modify: `shared/skills/tech-lead/references/plan-test-reviewer-prompt.md`
- Test: `tests/test-skill-output-and-gate-contract.sh`

1. [T2] 先写 RED 测试，在 `tests/test-skill-output-and-gate-contract.sh` 中加入 `goal_fidelity_review`、`目标闭环与执行度量`、`success_signal / baseline_note / guardrail_note` 的断言。

```bash
rg -n "goal_fidelity_review|目标闭环与执行度量|success_signal|baseline_note|guardrail_note" \
  shared/skills/tech-lead/SKILL.md \
  shared/skills/tech-lead/references/templates/plan-template.md
```

2. [T2] 运行 RED，确认失败点来自 `tech-lead` 现有模板未定义这些合同。

Run: `bash tests/test-skill-output-and-gate-contract.sh`
Expected: FAIL，提示缺失 `goal_fidelity_review` 或新增 Task 字段。

3. [T2] 最小修改 `tech-lead` 真源，补计划级承接面，不改现有骨架章节。

```markdown
## 目标闭环与执行度量
| 目标 | goal_source_ref | 承接 Task | execution_basis_ref | 成功信号 | 基线 | 护栏 | 说明 |
```

```markdown
- 对优化 / 重构 / 探索类 Task：
  - success_signal: ...
  - baseline_note: ...
  - guardrail_note: ...
- 普通功能 Task 可写 无 / N/A
```

4. [T2] 更新 `planning-modes.md` 和 reviewer prompts，让探索/优化类场景的 metric/guardrail 成为显式检查项。

```markdown
- 探索任务除 `hypothesis / success_signal / failure_signal / unlock_condition` 外，
  还应说明 success signal 的类型，以及无法机械化时的原因。
```

5. [T2] 运行 GREEN，确认 `tech-lead` 的静态合同断言通过。

Run: `bash tests/test-skill-output-and-gate-contract.sh`
Expected: PASS，至少通过新增的 `tech-lead` 相关断言。

### Task 3: Gate and test alignment [T3]

Files:
- Modify: `shared/skills/product/scripts/completion_check.sh`
- Modify: `shared/skills/tech-lead/scripts/completion_check.sh`
- Modify: `tests/test-product-stability-guidance-contract.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`
- Optional Modify: `tests/test-delivery-owner-phase3-contract.sh`

1. [T3] 为 `product` completion check 写 RED 覆盖，确保缺失成功信号字段时 gate 失败。

Run: `bash tests/test-skill-output-and-gate-contract.sh`
Expected: FAIL，直到 `product` check 引入对应验证逻辑。

2. [T3] 为 `tech-lead` completion check 写 RED 覆盖，确保缺失 `goal_fidelity_review` 或场景化 Task 字段时 gate 失败。

Run: `bash tests/test-skill-output-and-gate-contract.sh`
Expected: FAIL，直到 `tech-lead` check 引入对应验证逻辑。

3. [T3] 最小修改两个 completion check，只在触发条件成立时强制新字段。

```sh
# product
validate_goal_signal_contract() {
  # 检查目标与成功标准表头、非占位字段、C9 约束
}

# tech-lead
validate_goal_fidelity_review() {
  # 检查章节存在、数据行非空、goal_source_ref / execution_basis_ref 可回链
}

task_requires_metric_guardrail() {
  # 基于 task_type 或标题/说明中的优化、重构、探索特征触发
}
```

4. [T3] 跑最小 proving commands；若下游 phase3 contract 被波及，再补充对应 tests。

Run: `bash tests/test-product-stability-guidance-contract.sh`
Expected: PASS

Run: `bash tests/test-skill-output-and-gate-contract.sh`
Expected: PASS

Run: `bash tests/test-delivery-owner-phase3-contract.sh`
Expected: PASS 或未受影响时记录未运行原因

5. [T3] 复查 diff，确认没有改动稳定章节锚点、没有把普通功能 Task 强制成优化类模板。

Run: `git diff -- shared/skills/product shared/skills/tech-lead tests`
Expected: 仅出现设计内定义的字段、断言和 gate 逻辑变更。

## Final Verification

完成前执行：

- `bash tests/test-product-stability-guidance-contract.sh`
- `bash tests/test-skill-output-and-gate-contract.sh`
- `bash tests/test-delivery-owner-phase3-contract.sh`（若实际修改触达下游 phase3 contract）
