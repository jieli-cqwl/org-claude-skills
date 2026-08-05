# Rule Runtime Eval Credibility Implementation Plan

**Goal:** Make the evaluator distinguish regression, over-reading, and observed uplift without overstating causality.

**Architecture:** Extend case contracts with positive and negative routing bounds, validate baseline identity and source deltas, aggregate repeated runs, and separate deterministic quick tests from expensive live evaluation.

**Tech Stack:** Python 3 standard library, JSON contracts, shell test harness.

---

### Task 1: Strengthen contracts with failing tests

**Files:**
- Modify: `tools/eval/scripts/rule_runtime_eval/contracts.py`
- Modify: `tests/test-rule-runtime-eval-runner.sh`

1. Add failing tests for forbidden reads, identical candidate/baseline, same-head baseline, entry drift, filtered verdicts, and repeated-run aggregation.
2. Add `forbidden_scene_contracts` and `max_successful_scene_reads` to `EvalCase`.
3. Require at least two runs for effectiveness profiles.

### Task 2: Correct evidence and comparison semantics

**Files:**
- Modify: `tools/eval/scripts/rule_runtime_eval/evidence.py`
- Modify: `tools/eval/scripts/rule_runtime_eval/reporting.py`
- Modify: `tools/eval/scripts/run_rule_runtime_eval.py`

1. Preserve exact successful reads even when unrelated shell parsing is ambiguous.
2. Include the rendered assistant entry in installed-runtime identity.
3. Reject non-ancestor or identical baselines for comparative claims.
4. Emit `NO_OBSERVED_UPLIFT` when candidate and baseline evidence is equivalent.
5. Compute verdict thresholds from the selected profile/case subset, not a hard-coded case count.
6. Call bundle-level comparison an association unless an ablation isolates a source.

### Task 3: Split quick and exhaustive gates

**Files:**
- Create: focused Python test modules under `tests/`
- Modify: `tests/test-rule-runtime-eval-runner.sh`
- Modify: `tests/gate-plan.json`

1. Move deterministic contract/report/evidence cases into fast focused tests.
2. Keep the shell runner integration test outside quick.
3. Target a quick evaluator smoke runtime below 30 seconds and verify it remains below the existing timeout.
4. Run targeted tests and `bash tests/run-all.sh --quick`.
