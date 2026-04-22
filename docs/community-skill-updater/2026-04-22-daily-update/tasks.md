# Tasks — community-skill-updater daily update
Created: 2026-04-22
Related plan: ./plan.md

## Acceptance Checklist

- [x] T1 Skill contract, installation exposure, and runner coverage are locked by tests
  - AC: `tests/test-community-skill-updater-contract.sh` fails before the skill exists and passes after `shared/skills/community-skill-updater/SKILL.md`, bundled scripts, install exposure, README references, and `tests/run-all.sh` registration exist.
  - Traces: managed source candidates checked; local adapter summary; downstream Claude Code and Codex availability
  - Depends: -
  - Complexity: moderate

- [x] T2 Candidate lookup script reads source locks, excludes OpenSpec, and classifies update status
  - AC: `python3 tests/test-community-skill-updater-scripts.py CandidateLookupTests` passes and proves managed-source selection, OpenSpec exclusion, release/default-branch candidate comparison, no-update classification, update classification, and blocker classification.
  - Traces: source candidate check; latest stable source selection; OpenSpec exclusion
  - Depends: T1
  - Complexity: moderate

- [x] T3 Update orchestration script isolates work, applies refs, invokes sync/validation/install commands, and preserves failure state
  - AC: `python3 tests/test-community-skill-updater-scripts.py RunUpdateTests` passes and proves branch naming, same-day suffixing, worktree creation, source-lock update, sync command selection, validation order, real install order after validations, success cleanup, no-update cleanup, and failure preservation.
  - Traces: source lock update; vendor and Codex adapter sync; validation evidence; real install; branch commit; worktree cleanup/failure preservation
  - Depends: T2
  - Complexity: complex

- [x] T4 Skill instructions and conversation summary output match the automation workflow
  - AC: `bash tests/test-community-skill-updater-contract.sh` passes and verifies trigger language, managed source list, OpenSpec exclusion, worktree policy, validation/install gates, success summary fields, and blocked-run summary fields.
  - Traces: conversation report; automation invocation; failure evidence
  - Depends: T2, T3
  - Complexity: moderate

- [x] T5 Repository validation proves the updater integrates with current runtime conventions
  - AC: `python3 tools/community/check_task_plan_consistency.py docs/community-skill-updater/2026-04-22-daily-update/tasks.md docs/community-skill-updater/2026-04-22-daily-update/plan.md`, `bash tests/test-community-skill-updater-contract.sh`, `python3 tests/test-community-skill-updater-scripts.py`, `bash tests/test-single-source-layout.sh`, `bash tests/test-codex-skill-adapter.sh`, `bash tests/test-community-tools.sh`, and `bash tests/run-all.sh --quick` pass or report only a clearly identified pre-existing blocker unrelated to this updater.
  - Traces: full local verification; downstream Claude Code and Codex availability; no silent degradation
  - Depends: T1, T2, T3, T4
  - Complexity: complex

## Definition of Done

All tasks checked = ready for verify-change.
