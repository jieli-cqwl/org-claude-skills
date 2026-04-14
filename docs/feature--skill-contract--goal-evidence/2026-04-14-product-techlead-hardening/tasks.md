# Tasks — Product / Tech-Lead Goal Evidence Hardening
Created: 2026-04-14
Related plan: ./plan.md

## 需求

把 `product` 的“目标与成功标准”升级成更强的成功信号合同，把 `tech-lead` 的计划升级成更强的目标承接与执行度量合同，并让 reviewer prompt、completion check、contract tests 一起收口。

## 目标

1. `product` 的 `brief.md#目标与成功标准` 不再只有自然语言成功标准，而是能稳定表达基线、目标方向、观测窗口和数据来源。
2. `tech-lead` 的 `plan.md` 新增计划级 `goal_fidelity_review` 承接面，并对优化/重构/探索类 Task 增加场景化 `success_signal / baseline / guardrail` 合同。
3. completion check 与 shell contract tests 能识别新合同，避免文档与门禁漂移。

## 验收标准

- `product` 模板、流程说明与 reviewer prompt 都能明确“成功信号”的结构要求，且 `C9` 不再只接受模糊“度量方式”。
- `tech-lead` 模板、流程说明与 reviewer prompt 都能明确 `goal_fidelity_review` 和场景化 Task 度量/护栏要求。
- `product` 与 `tech-lead` 的 completion check 会在应当触发时拒绝缺失的新合同字段。
- 受影响的 contract tests fresh 运行通过，至少覆盖 `product` 与 `tech-lead` 的新增合同。

## 修改范围

- `shared/skills/product/SKILL.md`
- `shared/skills/product/references/templates/brief-template.md`
- `shared/skills/product/references/completeness-checklist.md`
- `shared/skills/product/references/prd-reviewer-prompt.md`
- `shared/skills/product/references/tester-reviewer-prompt.md`
- `shared/skills/product/scripts/completion_check.sh`
- `shared/skills/tech-lead/SKILL.md`
- `shared/skills/tech-lead/references/templates/plan-template.md`
- `shared/skills/tech-lead/references/planning-modes.md`
- `shared/skills/tech-lead/references/plan-reviewer-prompt.md`
- `shared/skills/tech-lead/references/plan-product-reviewer-prompt.md`
- `shared/skills/tech-lead/references/plan-test-reviewer-prompt.md`
- `shared/skills/tech-lead/scripts/completion_check.sh`
- `tests/test-product-stability-guidance-contract.sh`
- `tests/test-skill-output-and-gate-contract.sh`
- 视 gate 影响面决定是否补 `tests/test-delivery-owner-phase3-contract.sh`

## 非目标

- 不重构 `delivery-owner` 模板与角色边界。
- 不引入新的独立 artifact 类型。
- 不要求所有 Task 都必须填写优化类度量字段。

## Acceptance Checklist

- [ ] T1 强化 `product` 的成功信号合同与审查口径
  - AC: `shared/skills/product/SKILL.md` 在 S3、价值假设验证或 C9 相关位置明确要求 `成功信号` 至少包含 `度量类型 / 当前基线 / 目标值或方向 / 观测窗口 / 数据来源`。
  - AC: `shared/skills/product/references/templates/brief-template.md` 的 `## 目标与成功标准` 能稳定承载上述字段，并保持章节名不变。
  - AC: `shared/skills/product/references/completeness-checklist.md` 的 C9 明确要求基线、目标方向/目标值、窗口和来源；观察型成功信号必须写明原因。
  - AC: `shared/skills/product/references/prd-reviewer-prompt.md` 与 `shared/skills/product/references/tester-reviewer-prompt.md` 能从产品和测试视角独立检查成功信号完整性与可验证性。

- [ ] T2 强化 `tech-lead` 的目标承接与场景化执行度量合同
  - AC: `shared/skills/tech-lead/SKILL.md` 明确 `goal_fidelity_review` 为计划级必填承接面，并说明它用于承接上游目标而非改写业务目标。
  - AC: `shared/skills/tech-lead/references/templates/plan-template.md` 新增 `## 目标闭环与执行度量` 章节，并能把 `goal_source_ref -> Task -> execution_basis_ref` 串起来。
  - AC: `plan-template.md` 的 Task 模板仅对优化/重构/探索类 Task 强制 `success_signal / baseline_note / guardrail_note`，普通功能 Task 可写 `无 / N/A`。
  - AC: `shared/skills/tech-lead/references/planning-modes.md` 与三个 reviewer prompt 能识别探索/优化类 Task 的度量和护栏要求。

- [ ] T3 更新 gate 与 contract tests，验证新合同真正生效
  - AC: `shared/skills/product/scripts/completion_check.sh` 在 `brief.md#目标与成功标准` 与 C9 维度能拒绝缺失的新合同字段或非法占位。
  - AC: `shared/skills/tech-lead/scripts/completion_check.sh` 在 `goal_fidelity_review` 缺失、以及场景化 Task 缺少 `success_signal / baseline_note / guardrail_note` 时会失败。
  - AC: `tests/test-product-stability-guidance-contract.sh` 与 `tests/test-skill-output-and-gate-contract.sh` fresh 通过，并覆盖新增合同。
  - AC: 若 `execution_basis_ref / goal_source_ref` 的稳定锚点或下游联动受影响，则补充并通过 `tests/test-delivery-owner-phase3-contract.sh`。

## Definition of Done

All tasks checked，且以下 fresh proving commands 通过：

- `bash tests/test-product-stability-guidance-contract.sh`
- `bash tests/test-skill-output-and-gate-contract.sh`
- 按影响面补充：`bash tests/test-delivery-owner-phase3-contract.sh`
