# Tasks - product skills capability and structure redesign
Created: 2026-04-23
Related plan: ./plan.md

## Acceptance Checklist

- [x] T1 Add capability-redesign regression coverage
  - AC: `tests/test-product-capability-structure-redesign.sh` fails before the skill/reference/template changes because current artifacts lack the redesigned Director/Manager fields and structure.
  - AC: The test asserts Director user profile, appetite, explicit non-goals, feasibility constraints, risks and unknowns, decision rationale, D-S5.5, and removal of the standalone flow-reference section.
  - AC: The test asserts Manager example-driven AC, boundary and failure modes, Verification Plan, Integration Context, structured design decisions, AI executability review, M-S5.5, and removal of the standalone flow-reference section.
  - Traces: 完整变更清单; Skill 结构优化; Director -> Manager 衔接契约; 风险缓解: 结构优化同步进行.
  - Depends: -
  - Complexity: moderate

- [x] T2 Redesign product-director capability contract
  - AC: `shared/skills/product-director/SKILL.md` uses the target structure with HARD-GATE Why notes, role/boundary, flow overview, flow diagram, step details, output contract, completion checklist, and navigation.
  - AC: Director flow includes D-S2 user profile, D-S3 success criteria plus appetite, D-S5 scope plus Non-goals, feasibility constraints and decision rationale, and D-S5.5 risks and unknowns before Phase planning.
  - AC: Director references and templates expose user profile, appetite, non-goals, feasibility constraints, risks and unknowns, and decision rationale without adding UNIT/AC ownership.
  - Traces: product-director 能力重定义; Director 必须回答的 9 个核心问题; Director 流程步骤; Director -> Manager 衔接契约.
  - Depends: T1
  - Complexity: complex

- [x] T3 Redesign product-manager capability contract
  - AC: `shared/skills/product-manager/SKILL.md` uses the target structure with HARD-GATE Why notes, role/boundary, flow overview, flow diagram, step details, output contract, completion checklist, and navigation.
  - AC: Manager flow includes M-S0 content completeness checks, M-S4 Integration Context, M-S5 example-driven AC plus boundary and failure modes, M-S5.5 Verification Plan, M-S6 structured design decisions, and M-S7/M-S8 AI executability review.
  - AC: Manager references, reviewer prompts, and templates expose example input, expected result, boundary case, failure mode, verification plan, integration context, and structured design decision fields at WHAT-layer boundaries.
  - Traces: product-manager 能力重定义; AC 增强; Verification Plan; Integration Context; 三方评审焦点调整; Manager 流程步骤.
  - Depends: T1
  - Complexity: complex

- [x] T4 Align existing product contract tests with canonical redesign
  - AC: Existing failing product checks are reconciled with the canonical JSON direction rather than restored to retired markdown-lock assumptions.
  - AC: `tests/test-product-artifact-contract.sh`, `tests/test-product-role-split-contract.sh`, `tests/test-product-inherited-capability-parity.sh`, and `tests/test-product-template-purity-contract.sh` assert the redesigned contracts without weakening real coverage.
  - AC: `contracts/product-artifacts.yaml` remains either a supported compatibility contract with current sections or is tested only as a compatibility artifact, while runtime gates continue to validate canonical JSON artifacts.
  - Traces: output-contract 更新; templates 更新; 验证脚本作为关联变更一并处理; 不变项: canonical JSON 输出格式.
  - Depends: T2, T3
  - Complexity: moderate

- [x] T5 Verify and close the small-chain package
  - AC: `python3 tools/community/check_task_plan_consistency.py docs/product-skills-governance/2026-04-23-capability-and-structure-redesign/tasks.md docs/product-skills-governance/2026-04-23-capability-and-structure-redesign/plan.md` exits 0.
  - AC: Targeted product tests exit 0: `tests/test-product-capability-structure-redesign.sh`, `tests/test-product-artifact-contract.sh`, `tests/test-product-role-split-contract.sh`, `tests/test-product-inherited-capability-parity.sh`, `tests/test-product-output-contract-reference.sh`, `tests/test-product-template-purity-contract.sh`.
  - AC: Residual risk from any skipped long-running product benchmark is recorded with the exact command and reason.
  - Traces: 完成校验; 风险; small-chain verification-before-completion; verify-change.
  - Depends: T4
  - Complexity: moderate

## Definition of Done

All tasks checked = ready for verify-change.
