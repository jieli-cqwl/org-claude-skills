# Code Review Report

## Status
- PASS

## Scope
- `tests/run-all.sh`
- `tests/lib/install-test-env.sh`
- `tests/test-install-core.sh`
- `tests/test-install-runtime-smoke.sh`
- `tests/test-install-safety.sh`
- `tests/test-install-runtime.sh`
- `tests/test-install-migration.sh`
- `tests/test-run-all-runner-contract.sh`
- `README.md`
- archived planning and scenario-map docs in this directory
- active plan/task/design references that previously named retired install test entrypoints
- `tools/community/manage_codex_runtime.py`

## Findings
- resolved: `tests/test-install-smoke.sh` remained as an active script but had been removed from the runner without fully migrating its smoke responsibilities. The runtime smoke test now owns the old smoke asset, agent, hook/config, external-state, no-legacy-metadata, and uninstall-cleanup checks; the old file was removed.
- resolved: active planning docs still referenced retired install entrypoints. Active plan/task/design command references now point at `tests/run-all.sh` or `tests/test-install-runtime-smoke.sh`; archive history was left intact as historical evidence.
- resolved: install helper failures could exit under `set -e` without a diagnostic tail from the per-run install log. `install_test_run_install` and the fake-openspec wrapper now route unexpected failures through `install_test_fail`, while explicit negative tests call allow-failure helpers.
- resolved: helper file-content assertions used plain `grep -Fq`, which can misclassify historical install logs if grep treats the file as binary. Assertions now use `grep -aFq --`.
- resolved: Codex runtime uninstall missed managed hook commands when temp paths contained double separators. Managed hook command detection now normalizes both the managed root and command tokens, then compares on path boundaries so managed-looking user paths such as `managed-old` are preserved.

## Review Notes
- Runner semantics are explicit: default remains full; quick excludes only full-only install safety/runtime/migration/cleanup coverage; `--list` exposes excluded full-only install entries.
- The old monolithic install entrypoints were removed from `run-all`; no compatibility wrapper or transition behavior was kept.
- Old install coverage was mapped one-for-one: 20 `test-install-systematic.sh` pass cases plus 1 `test-install-runtime-audit.sh` responsibility, with 21 rows in `install-test-scenario-map.md`.
- Existing smoke coverage was also absorbed into `tests/test-install-runtime-smoke.sh` before deleting `tests/test-install-smoke.sh`, so the quick gate keeps a real install/uninstall shape check.
- The shared helper keeps HOME, state, logs, and baseline clones isolated under the per-run test temp root. Review passes fixed gate output paths, failure diagnostics, and binary-safe content assertions.
- The only full-run failure observed during review correlated with repository HEAD moving during the run (`9bb5f9f` in the failure log, then `a56f785` locally). Re-running from stable `a56f785` passed.
- Agent-team review used five perspectives: code review, general code review, verifier, test design, and QA. The first two found the blocking issues above; verifier, test-design, and QA did not find additional blockers.

## Evidence
- `bash tests/test-run-all-runner-contract.sh` -> PASS
- `bash -n tests/run-all.sh tests/lib/install-test-env.sh tests/test-install-*.sh` -> PASS
- `shellcheck -x tests/run-all.sh tests/lib/install-test-env.sh tests/test-install-*.sh` -> PASS
- `bash tests/test-install-core.sh` -> PASS, `Install core tests passed: 7`
- `bash tests/test-install-runtime-smoke.sh` -> PASS, `Install runtime smoke tests passed: 1`
- `bash tests/test-install-safety.sh` -> PASS, `Install safety tests passed: 6`
- `bash tests/run-all.sh --quick --profile` -> PASS, 57/57, `All tests passed`
- `bash tests/run-all.sh --profile` -> PASS, 61/61, `All tests passed`
- `git diff --check` -> PASS

## Conclusion
- APPROVE
