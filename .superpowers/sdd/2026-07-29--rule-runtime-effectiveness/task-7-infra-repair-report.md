# Task 7 Infrastructure And Evidence Repair Report

## Conclusion

`READY_FOR_FRESH_DIAGNOSTIC`

The evaluator now preserves the controller Python user-site for installer subprocesses while retaining isolated runtime `HOME` and `CODEX_HOME`. It persists redacted installer stdout, writes standalone coverage and comparison projections, and classifies incomplete lightness evidence as incomplete rather than a behavior regression.

No live Codex or model calls were made.

## RED Evidence

Command:

```bash
bash tests/test-rule-runtime-eval-runner.sh
```

Observed failure:
```text
installer did not receive Python user-site dependency path: .../runtime-manifests/candidate.json
[FAIL] installer dependency path or diagnostic evidence is invalid
```

The new fake-installer fixture required `site.getusersitepackages()` to appear in installer `PYTHONPATH`. Before the fix, isolated `HOME` removed that dependency path and the installer reported a nonzero status. The same test also specified sensitive stdout lines and asserted that only the non-sensitive `FATAL: PyYAML not installed` diagnostic may persist.

## GREEN Evidence

```bash
bash tests/test-rule-runtime-eval-runner.sh
python3 -m py_compile tools/eval/scripts/rule_runtime_eval/workspace.py tools/eval/scripts/rule_runtime_eval/reporting.py
bash tests/run-all.sh --quick
```

Results:

- Targeted evaluator regression: PASS, including fake installer/Codex isolation, stdout redaction, coverage/comparison projection, and incomplete-lightness classification.
- Python compile check: PASS.
- Quick gate: PASS, `41/41` checks.
- Evidence level: local and mock. The fake Codex executable produces deterministic JSONL and grading output; it does not invoke a model.

## Files Changed

- `tools/eval/scripts/rule_runtime_eval/workspace.py`: adds the current Python user-site to installer-only `PYTHONPATH`, keeps `HOME`/`CODEX_HOME` isolated, and retains line-redacted installer stdout while preserving the existing stderr withholding behavior.
- `tools/eval/scripts/rule_runtime_eval/reporting.py`: emits `coverage.json` and `comparison.json`; differentiates complete, incomplete, and invalid lightness projections so incomplete evidence remains an explicit blocker.
- `tests/fixtures/rule-runtime-eval/fake-install.sh`: adds controlled fixture modes for user-site dependency checks and installer stdout.
- `tests/test-rule-runtime-eval-runner.sh`: adds behavioral regressions for all four repaired evaluator contracts.

## Commit

`8da80222` `fix: unblock rule runtime live diagnostic`

## Concerns

- This proves the repaired evaluator boundaries only with local fake fixtures. A new Task 7 focused diagnostic must still run separately to obtain fresh live behavior evidence.
- Installer stdout is deliberately line-redacted. Sensitive-looking lines are withheld, so a failure whose only useful detail is embedded in such a line will remain partially diagnostic rather than leak credentials or local paths.

## Fix Round 1

### Conclusion

The evaluator no longer persists evaluator-temporary installer paths through `install.args`, incomplete required suite evidence projects as `INFRA_BLOCKED`, and installer stdout redacts the required additional credential-like forms.

### TDD Evidence

RED command:

```bash
bash tests/test-rule-runtime-eval-runner.sh
```

Observed failure before implementation:

```text
default installer path leaked through persisted args: .../rule-runtime-eval.../default-installer
[FAIL] default installer path evidence is not redacted
```

GREEN commands:

```bash
bash tests/test-rule-runtime-eval-runner.sh
python3 -m py_compile tools/eval/scripts/rule_runtime_eval/workspace.py tools/eval/scripts/rule_runtime_eval/reporting.py
git diff --check
```

Observed output summary: all three commands exited `0`. The targeted fake-fixture regression executes the default installer path, verifies no evaluator temporary path survives in persisted command evidence, verifies redaction for `password`, `api_key`, `Bearer`, `cookie`, and `session`, and verifies incomplete required lightness evidence returns `INFRA_BLOCKED`.

`bash tests/run-all.sh --quick` was started twice during completion verification, but both invocations stalled after the install canary launched and did not produce an exit status. They are not counted as passing evidence.

### Files Changed

- `tools/eval/scripts/rule_runtime_eval/workspace.py`: redacts evaluator-local paths in persisted installer arguments using the stdout path policy; broadens conservative stdout credential detection.
- `tools/eval/scripts/rule_runtime_eval/reporting.py`: projects incomplete required evidence and invalid evidence prerequisites as `INFRA_BLOCKED`, reserving `FAIL` for complete evidence with behavioral blockers.
- `tests/test-rule-runtime-eval-runner.sh`: adds default-installer-path, credential-form, and incomplete-lightness regressions.
- `.superpowers/sdd/2026-07-29--rule-runtime-effectiveness/task-7-infra-repair-report.md`: records this repair round.

### Concerns

- No live Codex or model call was made.
- The targeted evaluator proof and syntax/diff checks are fresh. The repository quick gate remains unverified because its install canary invocation did not terminate in this execution environment.
