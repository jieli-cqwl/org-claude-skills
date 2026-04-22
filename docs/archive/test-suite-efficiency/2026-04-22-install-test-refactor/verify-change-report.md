# Verify Change Report

## Status
- PASS

## CRITICAL
- none

## WARNING
- `test-skill-context-budget.sh` still reports existing allowed warnings for `design` and `tech-lead` exceeding the soft context budget. This predates and is unrelated to the install-test split.
- Earlier full-profile attempts observed unrelated docs commits landing during the run; those attempts were not used as final proof. The final quick and full proofs below both ran on stable `2d21856`.

## Evidence
- tasks complete:
  - T1 checked in `tasks.md`
  - T2 checked in `tasks.md`
  - T3 checked in `tasks.md`
  - T4 checked in `tasks.md`
  - T5 checked in `tasks.md`
- task-plan consistency:
  - pre-archive: `python3 tools/community/check_task_plan_consistency.py docs/test-suite-efficiency/2026-04-22-install-test-refactor/tasks.md docs/test-suite-efficiency/2026-04-22-install-test-refactor/plan.md` -> `[PASS] tasks-plan consistency (5 tasks, 24 plan steps)`
  - post-archive: `python3 tools/community/check_task_plan_consistency.py docs/archive/test-suite-efficiency/2026-04-22-install-test-refactor/tasks.md docs/archive/test-suite-efficiency/2026-04-22-install-test-refactor/plan.md` -> PASS
- migration coverage:
  - old systematic pass cases: 20
  - old runtime-audit responsibility: 1
  - scenario-map rows: 21
  - old/new case-set comparison: no differences
- existing smoke absorption:
  - old `tests/test-install-smoke.sh` responsibilities were migrated into `tests/test-install-runtime-smoke.sh`
  - migrated checks include Claude/Codex assets, agent content, hooks/config, external state, no legacy metadata, and install/uninstall cleanup shape
  - old `tests/test-install-smoke.sh` was deleted; no compatibility wrapper was kept
- review/fix closure:
  - helper unexpected install failures now report the install log tail through `install_test_fail`
  - expected failure scenarios now call allow-failure helpers
  - helper content assertions now use binary-safe `grep -aFq --`
  - Codex managed hook command detection now normalizes managed roots and command tokens, then compares on path boundaries
  - `tests/test-install-safety.sh` now proves a user hook under `hooks/managed-old` survives uninstall
  - stale active plan/task/design references to retired install entrypoints were updated
- quick proof:
  - `bash tests/run-all.sh --quick --list` -> 57 steps, `full_only_excluded=4`
  - excluded full-only tests: `test-install-safety.sh`, `test-install-runtime.sh`, `test-install-migration.sh`, `test-install-retired-skill-cleanup.sh`
  - `bash tests/run-all.sh --quick --profile` -> 57/57, `All tests passed`
  - quick install timings: `test-install-core.sh` 156s, `test-install-runtime-smoke.sh` 42s
- full proof:
  - `head_before_full=2d21856`
  - `bash tests/run-all.sh --profile` -> 61/61, `All tests passed`
  - install timings: core 163s, runtime-smoke 43s, safety 162s, runtime 149s, migration 86s, retired cleanup 24s
  - `head_after_full=2d21856`
- focused checks:
  - `bash tests/test-run-all-runner-contract.sh` -> `run-all runner contract ok`
  - `bash tests/test-install-core.sh` -> `Install core tests passed: 7`
  - `bash tests/test-install-runtime-smoke.sh` -> `Install runtime smoke tests passed: 1`
  - `bash tests/test-install-safety.sh` -> `Install safety tests passed: 6`
  - `python3 -m py_compile tools/community/manage_codex_runtime.py` -> PASS
  - `bash tests/test-deep-research-skill-contract.sh` -> `[PASS] deep-research skill contract`
  - `bash -n tests/run-all.sh tests/lib/install-test-env.sh tests/test-install-*.sh` -> PASS
  - `shellcheck -x tests/run-all.sh tests/lib/install-test-env.sh tests/test-install-*.sh` -> PASS
  - `git diff --check` -> PASS

## Efficiency Outcome
- Quick mode no longer runs the old 500s+ `tests/test-install-systematic.sh` monolith.
- The quick install path now keeps high-signal protocol and expanded runtime-smoke coverage while moving safety, runtime audit, migration, and retired cleanup coverage to full.
- Full mode remains quality-preserving because every old install scenario has a new mapped owner and passed in the final full-profile proof.

## Conclusion
- ready for archive
