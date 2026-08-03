# Task 7 Infrastructure Repair Round 4 Report

## Conclusion

The evaluator now accepts `wc -l <known installed target>` only as a neutral metadata probe within an otherwise safe sequential shell reader script. The probe never contributes a route read; a subsequent supported reader must still provide the contract evidence.

## Cause And Repair

`_shell_read_targets` treated every non-reader shell segment as unsupported, so an initial `wc -l` caused it to discard later valid `sed` reads. `_is_wc_line_probe` narrowly recognizes only three-token `wc -l <expected installed target>` segments and skips them without adding targets.

## Evidence

- Red: before the implementation, `bash tests/test-rule-runtime-eval-runner.sh` failed at `wc metadata probe blocked a later reader`; its route evidence had no read contracts.
- Green: the focused test now proves that `wc -l` followed by `sed` passes, `wc -l` alone has available but non-passing route evidence and no read contracts, and `wc -w` remains parser-uncertain and non-passing.
- Verification: `bash tests/test-rule-runtime-eval-runner.sh`, `python3 -m py_compile tools/eval/scripts/rule_runtime_eval/evidence.py`, and `python3 tools/community/check_test_signal_assertions.py` completed successfully.

## Scope And Risk

No runtime rule/reference document changed and no live Codex diagnostic was run. Existing evaluator checks continue to cover unsafe backgrounding, pipes, redirects, newlines, malformed JSONL, and unknown event/item shapes. The deliberately narrow probe parser rejects any `wc` form other than `wc -l` against an expected installed target.
