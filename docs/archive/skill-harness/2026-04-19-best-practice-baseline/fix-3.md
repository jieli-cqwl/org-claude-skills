# fix-3: review hardening after parallel agent review

## Context

- Review source: parallel agent review after `fb73a37`
- Historical fix reports read: `fix-1.md`, `fix-2.md`
- Worktree: `/Users/lijieli/org-claude-skills/.worktrees/skill-harness-small-chain`
- Branch: `codex/skill-harness-small-chain`
- failure_class: all items below are `FIXABLE`

## Observed Findings

### F1: quality standard still made JSON the default fact source

- Evidence: `shared/reference/Skill质量标准.md:7` stated that audit, optimization, verification, and flow skills use JSON artifact as machine fact source.
- Contract evidence: `docs/skill-harness/2026-04-19-best-practice-baseline/design.md:50` and `design.md:160` state that structured Markdown is the default and JSON is triggered by consumption.
- Root cause: the active quality standard retained old artifact wording after the `skill-harness` baseline changed the fact-source rule.
- Hypotheses checked: active runtime docs were wrong; rejected because `skill-harness/SKILL.md` and `json-upgrade-gate.md` already use consumption-triggered JSON. Standard text was stale; confirmed by the line above.
- Fix: rewrote the standard to state that JSON is triggered by machine consumers, cross-round state, automatic gates, release verification, or derived reports; otherwise structured Markdown remains the default human audit output.
- RED: `bash tests/test-skill-quality-standard.sh` failed with missing `JSON 由消费触发`.
- GREEN: `bash tests/test-skill-quality-standard.sh` -> `[PASS] skill quality standard`.

### F2: checker accepted incomplete FAIL findings

- Evidence: `shared/skills/skill-harness/scripts/check_skill_harness_contract.py:15` lacked `recommendation` in the enforced sample contract, and `check_skill_harness_contract.py:99` accepted any nonempty `file_line` string.
- Contract evidence: `shared/skills/skill-harness/SKILL.md:13` requires FAIL findings to include `file:line`, evidence, impact, recommendation, and proof command.
- Root cause: the calibration checker covered broad failure codes, but did not enforce the actionable finding fields that make a FAIL review reproducible.
- Hypotheses checked: fixture data omitted optional prose; rejected because `recommendation` is part of the FAIL contract. Shell gate missed a negative sample; confirmed by adding failing fixtures.
- Fix: added `MISSING_RECOMMENDATION` and `INVALID_FILE_LINE` checks, added negative fixtures, and added recommendations to existing fixtures.
- Boundary note: the checker now describes itself as a deterministic calibration fixture checker, not a generalized candidate package validator.
- RED: `bash tests/test-skill-harness-gates.sh` failed with `missing recommendation did not report MISSING_RECOMMENDATION`.
- GREEN: `bash tests/test-skill-harness-gates.sh` -> `[PASS] skill-harness gates`.

### F3: gate test used fixed `/tmp` output files

- Evidence: `tests/test-skill-harness-gates.sh:20` wrote expected-fail output to fixed `/tmp/skill_harness_expected_fail.out` and `/tmp/skill_harness_expected_fail.err`.
- Root cause: the helper used stable filenames for convenience, which creates collision and symlink-truncation risk under parallel test runs.
- Hypotheses checked: checker writes were the source; rejected because only the shell helper wrote fixed `/tmp` paths. Existing runtime `mktemp` fix covered other scripts; confirmed by prior `fix-2.md`.
- Fix: create a per-run temporary directory with `mktemp -d`, write per-call stdout/stderr files under it, and remove the directory through `trap`.
- RED evidence: static review showed fixed `/tmp` paths in the helper.
- GREEN: `bash tests/test-skill-harness-gates.sh` -> `[PASS] skill-harness gates`.

### F4: old skill-auditor design chain remained outside archive

- Evidence: the former active design-chain document, now archived under `docs/archive/skill-auditor/design-chain-2026-04-16-course-derived-methodology/`, still described building the retired runtime source as the default entry.
- Contract evidence: `docs/skill-harness/2026-04-19-best-practice-baseline/design.md:263` says old-name migration material must live in archive, fixtures, or migration context.
- Root cause: the runtime source and test scripts were archived, but the old design chain stayed in an active docs path.
- Hypotheses checked: active runtime noise scan covered it; rejected because the migration test did not scan the retired docs directory. Archive docs were enough; rejected because the active docs path still existed.
- Fix: moved the design chain to `docs/archive/skill-auditor/design-chain-2026-04-16-course-derived-methodology/`, updated the active design reference, and added a migration test assertion that the retired docs directory is absent.
- RED: `bash tests/test-skill-harness-migration.sh` failed with `skill-auditor design docs must be archived`.
- GREEN: `bash tests/test-skill-harness-migration.sh` -> `[PASS] skill-harness migration`.

### F5: active docs retained retired path literals after archive

- Evidence: second review found active `docs/skill-harness/**` files still containing retired runtime and design-chain path literals after the files had moved to archive.
- Root cause: the first archive fix moved files but left migration command examples and evidence text with direct retired-path literals in active docs.
- Hypotheses checked: the literals were harmless migration history; rejected because active docs are read by downstream agents. Tests alone were enough; rejected because docs still transmitted stale paths.
- Fix: changed active docs to reference archive paths or neutral retired-directory wording, and extended `tests/test-skill-harness-migration.sh` to reject retired active path literals inside `docs/skill-harness/**`.
- RED: `bash tests/test-skill-harness-migration.sh` failed with `legacy active path leaked into skill-harness docs`.
- GREEN: `bash tests/test-skill-harness-migration.sh` -> `[PASS] skill-harness migration`.

## Verification

- `python3 tools/community/check_task_plan_consistency.py docs/skill-harness/2026-04-19-best-practice-baseline/tasks.md docs/skill-harness/2026-04-19-best-practice-baseline/plan.md` -> `[PASS] tasks-plan consistency (5 tasks, 36 plan steps)`
- `bash tests/test-skill-harness-contract.sh` -> `[PASS] skill-harness contract`
- `bash tests/test-skill-harness-gates.sh` -> `[PASS] skill-harness gates`
- `bash tests/test-skill-harness-migration.sh` -> `[PASS] skill-harness migration`
- `bash tests/test-skill-quality-standard.sh` -> `[PASS] skill quality standard`
- `bash tests/test-install-systematic.sh` -> `Systematic tests passed: 20, skipped: 0`
- `bash tests/run-all.sh` -> `All tests passed`
- `git diff --check` -> PASS

## Impact And Regression

- Modified runtime surface: `skill-harness` checker and manifest wording.
- Modified docs surface: active quality standard, active `skill-harness` plan/tasks/design/report, archived old design chain.
- Modified tests: harness gates, quality standard, migration fixtures.
- Regression surface: install exposure, active runtime noise, quality standard, task-plan consistency.
- Result: the parallel review FAIL items are now represented by regression tests and the targeted verification set is green.
