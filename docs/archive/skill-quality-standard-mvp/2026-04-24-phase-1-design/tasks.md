# Tasks - Skill Quality Standard MVP Phase 1
Created: 2026-04-24
Related plan: ./plan.md

## Acceptance Checklist

- [x] T1 Freeze the Phase 1 MVP quality standard as the first-party truth source
  - AC: `shared/reference/Skill质量标准.md` defines Phase 1 scope for standard-chain first-party Skills plus `skill-harness`, keeps D1-D8 as runtime-surface quality concerns, treats D9 as readiness only, uses `PASS / FAIL / COMMENT` findings, states line-count budgets are warning heuristics rather than hard quality standards, and prevents fixed budgets, small eval samples, or D9 readiness metadata from becoming hard proof; `shared/skills/scan/references/skills-scan-rules.md` and `tests/test-skill-context-budget.sh` align line-count checks to warning or health-signal behavior; `bash tests/test-skill-quality-standard.sh` and `bash tests/test-skill-context-budget.sh` exit 0.
  - Traces: Skill runtime-surface quality; D9 readiness boundary; Handling Local Heuristics; Finding Boundary
  - Depends: -
  - Complexity: complex
- [x] T2 Align `skill-harness` to consume the MVP standard without becoming a second source of truth
  - AC: `shared/skills/skill-harness/SKILL.md` and `shared/skills/skill-harness/references/audit-method.md` state that `skill-harness` is read-only assurance, consumes the source standard through the runtime-safe `{{RUNTIME_HOME}}/reference/Skill质量标准.md` route, does not define the standard, self-certify, or make lifecycle decisions, maps every finding to one MVP quality concern, keeps legacy labels only as migration or baseline-smoke evidence, and treats D9 as readiness evidence that must not produce retain, retire, or proven-effectiveness conclusions; existing harness contract tests plus `bash tests/test-skill-harness-mvp-boundary.sh` exit 0.
  - Traces: Harness Governance; Finding Boundary; D9 readiness boundary; Double-source prevention
  - Depends: T1
  - Complexity: moderate
- [x] T3 Produce reviewable Phase 1 sample findings for `delivery-owner` and `skill-harness`
  - AC: `docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/sample-findings.md` contains reviewable findings for both samples; every finding has verdict, mapped MVP quality concern, evidence, impact, recommendation, and a field stating whether the `skill-harness` dimension is only an output label; findings do not cite historical labels, fixed line-count thresholds, or D9 readiness metadata as authority; `bash tests/test-skill-quality-standard-mvp-samples.sh` exits 0.
  - Traces: Validation Samples; Acceptance Criteria; Finding Boundary
  - Depends: T1, T2
  - Complexity: moderate
- [x] T4 Verify and package the small-chain result
  - AC: primary proof commands for T1-T3 exit 0; targeted existing harness and lifecycle smoke commands exit 0; `tests/run-all.sh` includes the new MVP tests and `bash tests/run-all.sh --full --profile` exits 0; `python3 tools/community/check_task_plan_consistency.py docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/tasks.md docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/plan.md` exits 0; `git diff --check` exits 0; `docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/verify-change-report.md` records evidence and residual risk.
  - Traces: all success criteria
  - Depends: T1, T2, T3
  - Complexity: moderate

## Definition of Done

All tasks checked = ready for verify-change.
