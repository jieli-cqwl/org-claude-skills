# Final Review Fix Report

## Conclusion

All four Critical, both Important, and the low-risk Minor findings are addressed in the evaluator, deterministic fixtures, and regression suite. No live Codex model was rerun, no raw live result directory was added, and Task 7 remains `INFRA_BLOCKED` because its replay evidence is stale after the parser change.

## Acceptance Evidence

1. Live execution now returns `0` only for suite verdict `PASS` or `DIAGNOSTIC_PASS`; suite `FAIL`, infrastructure-blocked, stale, missing, or unknown decisions return `1`. Dry-run success remains `0`, contract errors remain `2`, and workspace/setup errors remain `1`.
2. Route evidence rejects provably zero-content `head`, `tail`, and quiet `sed` forms, including empty programs and explicit `0p` expressions. Existing positive coverage retains `cat`, `nl`, `head -n 3`, `tail -n 3`, and `sed -n '1,3p'` readers.
3. Runtime manifests hash every declared installed scene target under the evaluator-owned `CODEX_HOME`. Evidence runtime identity hashes those installed target records, while repository source hashes remain traceability fields. Missing installed targets block installation and model execution.
4. `task-7-report.md` and `progress.md` identify the parser-adjusted rerun4 observations as `STALE` and diagnostic-only, explicitly requiring a fresh live diagnostic before installation or promotion. No durable replay or fresh promotion claim was added.
5. Installer, executor, and grader stderr use one withholding boundary. The grader regression injects token, Authorization, Bearer, cookie, session, password, and api_key forms plus source Codex home, evaluator temp root, candidate/baseline runtime homes, judge HOME, and judge CODEX_HOME; persisted grader logs contain only the withholding marker.
6. `--keep-workspaces` reports the retained evaluator workspace root and the summary test rejects seeded auth/config secret content.
7. The contract loader accepts only a non-boolean integer `runs_per_configuration` equal to `1`; integer `2` and float `1.0` are rejected.

## TDD Evidence

- Red: the new float run-count regression expected contract exit `2` and observed `0`.
- Green: the loader now rejects float `1.0` with `profile_runs_unsupported`.
- Red: the new empty-program `sed` regression observed `route_pass=True` with the target listed in `read_contract_ids` even though output came only from `pwd`.
- Green: empty and explicit zero-print quiet `sed` forms now produce no route pass or read contract identity, while supported nonzero readers remain green.

## Scoped Re-review Addendum

The follow-up regression reproduced `sed -ne '' $HOME/.codex/reference/协作判断.md && pwd` as `route_pass=True` with the contract incorrectly recorded as read. The parser now treats only combined short options matching `-n+e` as an empty/`0p` script predecessor, covering `-ne` and repeated-quiet `-nne` without admitting non-equivalent option orders. Both zero-output forms are rejected, while `sed -n '1,3p'` remains a supported route read. No live model was rerun.

Scoped verification passed the evaluator runner, test-signal assertion checker, team-readiness pack, Python/shell syntax checks, and `git diff --check`.

## Verification

- `bash tests/test-rule-runtime-team-readiness-pack.sh`: exit `0`; `[PASS] rule runtime team readiness pack`.
- `bash tests/test-rule-runtime-eval-runner.sh`: exit `0`; all three evaluator sections passed.
- `bash tests/run-all.sh --quick`: exit `0`; 41/41 checks passed.
- `bash install.sh --target all --dry-run`: exit `0`; contract checks passed, Claude/Codex writes were previewed, and post-install checks were skipped by dry-run as designed.
- `git diff --check`: exit `0`; no whitespace errors.

Evidence level is local deterministic execution with fake Codex/installer boundaries. It proves evaluator contracts and failure handling, not current live model behavior.

## Residual Risk

- Task 7 live behavior remains stale because runner identity changed after rerun4. A fresh focused live diagnostic is still required before any installation or promotion decision.
- The route parser intentionally recognizes only narrow, provable reader grammars. Unsupported shell indirection remains fail closed and may require a future parser extension when backed by a captured real command and regression test.
- `--keep-workspaces` deliberately retains seeded evaluator-owned auth/config copies at the reported path; the operator remains responsible for deleting that directory after diagnosis.
