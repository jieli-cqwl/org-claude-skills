# Tasks — skill-harness best-practice baseline
Created: 2026-04-19
Related plan: ./plan.md

## Acceptance Checklist

- [x] T1 Build the `skill-harness` runtime entry and reference routing
  - AC: `shared/skills/skill-harness/SKILL.md` exists with frontmatter name `skill-harness`, read-first/default Markdown audit flow, explicit JSON upgrade gate, Darwin boundary, content order, runtime noise, and completion checks; `bash tests/test-skill-harness-contract.sh` exits 0.
  - Traces: 语义与工程分工清楚, 默认路径轻量, JSON 触发清楚, standard-chain 经验被吸收
  - Depends: -
  - Complexity: moderate
- [x] T2 Add deterministic engineering gates and calibration fixtures
  - AC: `shared/skills/skill-harness/scripts/check_skill_harness_contract.py` validates the good fixture and rejects `no-evidence-fail`, `missing-command`, `active-alias`, `markdown-fact-source`, `darwin-tail-hard-gate`, and `json-without-consumer`; `bash tests/test-skill-harness-gates.sh` exits 0.
  - Traces: 复杂度有消费者, 漂移样本可阻断, 过重样本可识别, JSON 触发清楚
  - Depends: T1
  - Complexity: complex
- [x] T3 Migrate install and runtime exposure to `skill-harness`
  - AC: `install.sh`, `tests/test-single-source-layout.sh`, `tests/test-codex-skill-adapter.sh`, and `tests/test-skill-context-budget.sh` require `skill-harness`, reject active `skill-auditor`, and pass their targeted commands.
  - Traces: 语义与工程分工清楚, 默认路径轻量, 漂移样本可阻断
  - Depends: T1
  - Complexity: moderate
- [x] T4 Archive old `skill-auditor` runtime source and update active references
  - AC: `shared/skills/skill-auditor` is absent; old source is preserved under `docs/archive/skill-auditor/runtime-source-2026-04-19/`; active runtime/reference text uses `skill-harness` for the Harness role; old-name hits outside archive, fixtures, evals, and migration docs are removed or justified by `bash tests/test-skill-harness-migration.sh`.
  - Traces: 复杂度有消费者, 漂移样本可阻断, standard-chain 经验被吸收
  - Depends: T3
  - Complexity: complex
- [x] T5 Verify and package the small-chain result
  - AC: `python3 tools/community/check_task_plan_consistency.py docs/skill-harness/2026-04-19-best-practice-baseline/tasks.md docs/skill-harness/2026-04-19-best-practice-baseline/plan.md`, `bash tests/test-skill-harness-contract.sh`, `bash tests/test-skill-harness-gates.sh`, `bash tests/test-skill-harness-migration.sh`, `bash tests/test-install-smoke.sh`, `bash tests/run-all.sh`, and `git diff --check` all exit 0; `verify-change-report.md` records commands, results, and residual risks.
  - Traces: 语义与工程分工清楚, 复杂度有消费者, 默认路径轻量, JSON 触发清楚, 过重样本可识别, 漂移样本可阻断, standard-chain 经验被吸收
  - Depends: T1, T2, T3, T4
  - Complexity: moderate

## Definition of Done

All tasks checked = ready for verify-change.
