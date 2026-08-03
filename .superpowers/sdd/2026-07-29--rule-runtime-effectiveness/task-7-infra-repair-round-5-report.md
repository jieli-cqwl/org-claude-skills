# Task 7 Infrastructure Repair Round 5 Report

## Conclusion

The route evidence parser now preserves later supported reads after narrowly bounded metadata and diagnostic commands. Multi-operand `wc -l` is neutral only when every operand resolves inside the isolated Codex runtime or the sibling agent-skill root; exact `pwd` and `printenv HOME` commands are also neutral. None of these commands creates route evidence by itself.

Unsupported commands that mention an expected installed target through `$HOME/.codex/...`, `${HOME}/.codex/...`, `$CODEX_HOME/...`, `${CODEX_HOME}/...`, `.codex/...`, or `./.codex/...` now set `parser_uncertain=True` instead of becoming silent route misses.

## TDD Evidence

- Red: after adding the round 5 regression cases and before changing `evidence.py`, `bash tests/test-rule-runtime-eval-runner.sh` exited 1 at `multi-operand wc probe blocked later readers`; the observed route was available but non-passing with `read_contract_ids=()`.
- Green: after the parser repair, the same command exited 0 and printed all three suite markers: evaluator contract/dry-run resolution PASS, executor/fail-closed route evidence PASS, and blind grading/freshness/comparison/reports PASS.
- Regression boundaries: the tests prove that multi-operand `wc -l` alone records no route read, `/etc/passwd` is not an accepted metadata operand, `wc -w` remains uncertain, `env` remains unsupported, and all four requested target aliases make unsupported commands uncertain.

## Verification

- `bash tests/test-rule-runtime-eval-runner.sh`: exit 0; 3 PASS markers, no failures.
- `python3 -m py_compile tools/eval/scripts/rule_runtime_eval/evidence.py`: exit 0; no output.
- `python3 tools/community/check_test_signal_assertions.py`: exit 0; no output.
- `git diff --check`: exit 0; no output.

Evidence level is local deterministic test execution. No live Codex evaluation was rerun.

## Scope And Risk

Only the parser, its existing Bash-hosted Python evidence tests, and this report changed. Runtime rules, case packs, graders, and live result output remain untouched.

The neutral command allowlist is intentionally narrow. Other `wc` modes, operands outside the runtime/agent-skill roots, `env`, mixed unsafe shell operators, and unsupported target-reading forms remain fail closed. Alias detection is conservative substring matching for variable-prefixed forms and boundary-aware for `.codex/...`; unusual shell indirection not listed above remains parser-uncertain only when the existing unsafe-form checks catch it.
