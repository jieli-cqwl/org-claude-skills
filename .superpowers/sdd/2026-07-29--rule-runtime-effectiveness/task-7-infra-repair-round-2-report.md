# Task 7 Infrastructure Repair Round 2

## RED Evidence

Command:

```bash
bash tests/test-rule-runtime-eval-runner.sh
```

Observed failure:

```text
seeded configuration retained source-local runtime settings
[FAIL] seeded Codex context retained source configuration
```

The new local regression seeds a source `config.toml` containing hook, plugin,
agent-role, project, and secret-like values. Before the repair,
`seed_codex_context` copied that file unchanged into the evaluated Codex home.
The same test update also adds unimplemented route and model-call contracts; the
suite stops at this first failure. No live Codex or model diagnostics were run.

## GREEN Evidence

The controller ran the focused local regression after the repair:

```bash
bash tests/test-rule-runtime-eval-runner.sh
```

Observed result: PASS.

This worker independently ran the remaining required checks:

```bash
python3 -m py_compile tools/eval/scripts/rule_runtime_eval/evidence.py tools/eval/scripts/rule_runtime_eval/workspace.py tools/eval/scripts/run_rule_runtime_eval.py
git diff --check
```

Observed result: both commands exited 0 with no output.

## Files Changed

- `tests/test-rule-runtime-eval-runner.sh`
- `tools/eval/scripts/rule_runtime_eval/evidence.py`
- `tools/eval/scripts/rule_runtime_eval/workspace.py`
- `tools/eval/scripts/run_rule_runtime_eval.py`

## Concerns

- No live Codex/model diagnostics were rerun by design; the account/model support limitation from the findings remains outside this local verification.
- The focused test evidence is controller-supplied; this worker independently verified syntax compilation and whitespace integrity only.

## Fix Round 3 RED Evidence

Command:

```bash
bash tests/test-rule-runtime-eval-runner.sh
```

Observed failure before the parser fix:

```text
[PASS] rule runtime evaluator contract loading and dry-run resolution
background shell command was accepted as route evidence
```

The new regression used `/bin/zsh -lc 'cat $HOME/.codex/reference/协作判断.md & true'` and failed because the parser accepted the background operator as a safe shell script.

## Fix Round 3 GREEN Evidence

After rejecting standalone `&` tokens as parser-uncertain while retaining `;` and `&&`, the same command passed:

```bash
bash tests/test-rule-runtime-eval-runner.sh
```

Observed result:

```text
[PASS] rule runtime evaluator contract loading and dry-run resolution
[PASS] rule runtime executor and fail-closed route evidence
[PASS] rule runtime blind grading, freshness, comparison, and reports
```

No live Codex/model diagnostics were run.
