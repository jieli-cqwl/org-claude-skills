# Tasks — install-test-refactor
Created: 2026-04-22
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 Lock runner and install-test migration contracts
  - AC: `bash tests/test-run-all-runner-contract.sh` fails before implementation because `tests/run-all.sh --list` still exposes `tests/test-install-systematic.sh` and `tests/test-install-runtime-audit.sh`; after implementation it passes and proves default full, explicit quick, profile/list semantics, new install test files, and old entry removal.
  - Traces: default full quality gate; quick explicit development loop; list/profile auditability; no transition wrappers
  - Depends: -
  - Complexity: moderate
- [x] T2 Add install-test helper and migrate quick install coverage
  - AC: `bash tests/test-install-core.sh` and `bash tests/test-install-runtime-smoke.sh` pass; `bash -n tests/lib/install-test-env.sh tests/test-install-core.sh tests/test-install-runtime-smoke.sh` passes; helper creates isolated HOME, runs real `install.sh`, writes per-case logs, and supports process-local baseline clone without cross-run cache.
  - Traces: common helper;真实 install baseline; quick core coverage; isolated test environment; failure domain naming
  - Depends: T1
  - Complexity: complex
- [x] T3 Migrate full-only install coverage and delete old slow entries
  - AC: `bash tests/test-install-safety.sh`, `bash tests/test-install-runtime.sh`, and `bash tests/test-install-migration.sh` pass; `tests/test-install-systematic.sh` and `tests/test-install-runtime-audit.sh` are removed; every old `pass "..."` scenario plus runtime-audit responsibility has a row in `docs/test-suite-efficiency/2026-04-22-install-test-refactor/install-test-scenario-map.md`.
  - Traces: safety/runtime/migration full coverage;旧场景映射完整; runtime-audit 并入后删除; baseline 禁用边界
  - Depends: T2
  - Complexity: complex
- [x] T4 Update runner, docs, and syntax/shell quality gates
  - AC: `bash tests/run-all.sh --list`, `bash tests/run-all.sh --quick --list`, `bash tests/test-run-all-runner-contract.sh`, `bash -n tests/run-all.sh tests/lib/install-test-env.sh tests/test-install-*.sh`, `shellcheck -x tests/run-all.sh tests/lib/install-test-env.sh tests/test-install-*.sh`, and `git diff --check` pass; README documents only the current full/quick/profile/list test entrypoints.
  - Traces: single runner truth; no old wrapper noise; shell quality; documentation sync
  - Depends: T3
  - Complexity: moderate
- [x] T5 Prove quality and efficiency end to end
  - AC: `python3 tools/community/check_task_plan_consistency.py docs/test-suite-efficiency/2026-04-22-install-test-refactor/tasks.md docs/test-suite-efficiency/2026-04-22-install-test-refactor/plan.md`, `bash tests/run-all.sh --quick --profile`, and `bash tests/run-all.sh --profile` pass or report only a clearly identified pre-existing non-install blocker; profile output no longer contains a single 500s+ `test-install-systematic.sh` step.
  - Traces: task-plan consistency; fresh proving; quick/full evidence; efficiency proof; current-worktree blocker separation
  - Depends: T4
  - Complexity: complex

## Definition of Done
All tasks checked = ready for verify-change.
