# Tasks — skill lifecycle capability eval framework
Created: 2026-04-23
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 Add D9 existence-rationale standards and lifecycle rules
  - AC: `shared/reference/Skill能力有效性标准.md` and `shared/reference/Skill生命周期管理.md` exist; `shared/reference/Skill质量标准.md` registers D9 after D8 without weakening D1-D8; `bash tests/test-skill-lifecycle-eval-framework.sh` fails before the implementation and passes after it.
  - Traces: Success criteria 1, 3, 4; 交付物 1; 交付物 3; 生命周期闭环规则
  - Depends: -
  - Complexity: moderate
- [x] T2 Add lifecycle eval metadata and review records for the 12 standard-chain skills
  - AC: The 12 skills named in `design.md` each declare frontmatter `eval-type`, have an `evals/evals.json` with matching `eval_type`, at least 3 scenarios, required `preference_anchors` and/or `grader_dimensions`, and an `evals/lifecycle-review.json` with a retain/optimize/retire decision and evidence refs; `bash tests/test-skill-lifecycle-eval-framework.sh` validates the full set.
  - Traces: Success criteria 1, 2, 3; 交付物 2; 标准流程链 Skill 分类与评审计划
  - Depends: T1
  - Complexity: complex
- [x] T3 Wire D9 checks into skill-harness guidance without changing its read-only audit role
  - AC: `shared/skills/skill-harness/SKILL.md` and `shared/skills/skill-harness/references/audit-method.md` describe D9 existence-rationale checks, evidence expectations, and routing to `Skill能力有效性标准.md`; deterministic tests prove skill-harness still passes its existing gates.
  - Traces: Success criteria 3, 4; 集成点; 不变量
  - Depends: T1
  - Complexity: moderate
- [x] T4 Add repeatable validation and closeout evidence for the framework
  - AC: `tests/test-skill-lifecycle-eval-framework.sh` is included in `tests/run-all.sh`; small-chain task-plan consistency passes; targeted lifecycle, skill quality, skill-harness, standard-chain eval, and whitespace checks pass with fresh output.
  - Traces: Success criteria 4; 风险; 下游影响
  - Depends: T1, T2, T3
  - Complexity: moderate

## Definition of Done
All tasks checked = ready for verify-change.
