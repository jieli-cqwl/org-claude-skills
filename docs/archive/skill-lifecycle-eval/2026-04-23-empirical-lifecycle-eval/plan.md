# Empirical Skill Lifecycle Eval Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Build a repeatable pilot path that turns standard-chain local eval outputs into lifecycle review metrics for `product-manager` and `developer`.

**Architecture:** Extend the existing standard-chain local eval runner instead of introducing a second execution path. Add one focused lifecycle aggregation script that consumes runner summaries and emits updated review JSON while keeping pilot decisions conservative.

**Tech Stack:** Python standard library, Bash contract tests, JSON lifecycle review files, existing `tools/eval/scripts/standard_chain_local_eval` modules.

---

### Task 1: Runner Run Mode And Anchor Grading [T1]

Context: Existing local eval runner has one execution mode and grades expectations only. This task keeps default behavior intact while adding explicit run mode and anchor-aware metadata.

Files:
- Modify: `tools/eval/scripts/standard_chain_local_eval/workspace.py`
- Modify: `tools/eval/scripts/standard_chain_local_eval/grading.py`
- Modify: `tools/eval/scripts/standard_chain_local_eval/runner.py`
- Modify: `tools/eval/scripts/standard_chain_local_eval/common.py`
- Modify: `tests/test-standard-chain-local-eval-runner.sh`

1. [T1] Extend `tests/test-standard-chain-local-eval-runner.sh` first.

Add assertions to the fake `codex` flow so the runner must produce:

- `eval_metadata.json.expected_anchors`
- `eval_metadata.json.preference_anchor_definitions`
- `grading.json.anchor_results`
- `grading.json.preference_anchor_summary`
- `summary.json.runs[0].run_mode`
- `summary.json.runs[0].anchor_total`
- `summary.json.runs[0].anchor_fidelity`

Also add a `--run-mode without_skill` invocation and assert that the response output exists under a separate output directory.

2. [T1] Run the test and confirm RED.

Run: `bash tests/test-standard-chain-local-eval-runner.sh`

Expected: FAIL on missing run mode or anchor fields.

3. [T1] Update `common.py`.

Add allowed run modes:

```python
RUN_MODES = {"with_skill", "without_skill"}
```

4. [T1] Update `workspace.py`.

Change `prepare_workspace(skill_name, output_dir)` to `prepare_workspace(skill_name, output_dir, run_mode)`.

- For `with_skill`, copy the target skill as today.
- For `without_skill`, create only the minimal workspace and copied case files; do not copy `shared/skills/{skill_name}`.

Change `build_executor_prompt(skill_name, case)` to `build_executor_prompt(skill_name, case, run_mode)`.

- `with_skill` prompt instructs the executor to read `shared/skills/{skill_name}/SKILL.md`.
- `without_skill` prompt instructs the executor not to read or rely on that Skill.

5. [T1] Update `load_skill_evals`.

When eval payload has `preference_anchors`, attach `preference_anchor_definitions` to each selected case using its `expected_anchors`. Unknown anchors must raise `ValueError`.

6. [T1] Update `grading.py`.

Extend judge schema with:

```json
"anchor_results": [
  {"id": "PA-1", "passed": true, "evidence": "actual evidence"}
]
```

If a case has expected anchors, include the anchor list in the judge prompt. After judging, write `anchor_results` and `preference_anchor_summary` into `grading.json`.

7. [T1] Update `runner.py`.

Add CLI argument `--run-mode` defaulting to `with_skill`, validate it against `RUN_MODES`, pass it through `prepare_workspace`, `run_case`, and `run_executor`, and include it in summary rows.

8. [T1] Run targeted verification.

Run: `bash tests/test-standard-chain-local-eval-runner.sh`

Expected: PASS.

### Task 2: Lifecycle Review Aggregator [T2]

Context: The lifecycle review files need a deterministic writer that can be tested without model calls. This task consumes runner summaries and emits review JSON.

Files:
- Create: `tools/eval/scripts/update_lifecycle_review.py`
- Create: `tests/test-skill-lifecycle-empirical-review.sh`

1. [T2] Write the failing aggregator test.

Create `tests/test-skill-lifecycle-empirical-review.sh` that:

- Creates fixture `summary.json` files for product-manager with anchor totals.
- Creates fixture `summary.json` files for developer with with-skill and without-skill pass rates plus anchor totals.
- Runs `python3 tools/eval/scripts/update_lifecycle_review.py` for both skills into a temporary output directory.
- Asserts product-manager review has `encoded_preference.measurement_status = "pilot_empirical_sample_recorded"` and `fidelity = 0.75`.
- Asserts developer review has `capability_uplift.with_avg = 0.75`, `without_avg = 0.5`, `uplift = 0.25`, and `encoded_preference.fidelity = 0.5`.
- Asserts both reviews retain `decision = "optimize"`.

2. [T2] Run the new test and confirm RED.

Run: `bash tests/test-skill-lifecycle-empirical-review.sh`

Expected: FAIL because the aggregator script does not exist.

3. [T2] Implement `update_lifecycle_review.py`.

The script must:

- Parse `--skill`, `--with-summary`, optional `--without-summary`, `--output-review`, and `--write-review`.
- Load `shared/skills/{skill}/evals/evals.json` and `lifecycle-review.json`.
- Compute pass-rate averages from `summary.runs[].pass_rate`.
- Compute anchor fidelity from `summary.runs[].anchor_passed / anchor_total`.
- Preserve the existing review structure and add `pilot_empirical`.
- Keep `decision` as `optimize`.
- Write stable UTF-8 JSON.

4. [T2] Run targeted verification.

Run: `bash tests/test-skill-lifecycle-empirical-review.sh`

Expected: PASS.

### Task 3: Pilot Review Evidence [T3]

Context: The pilot review files must show empirical sample status without pretending the full lifecycle decision is complete.

Files:
- Modify: `shared/skills/product-manager/evals/lifecycle-review.json`
- Modify: `shared/skills/developer/evals/lifecycle-review.json`
- Create directory as needed: `tools/eval/results/skill-lifecycle-empirical-pilot-20260423/`

1. [T3] Run a bounded real pilot sample.

Commands:

```bash
python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills product-manager --eval-ids handoff-validation-first --runs-per-eval 1 --run-mode with_skill --output-dir tools/eval/results/skill-lifecycle-empirical-pilot-20260423/product-manager-with-skill --allow-failures
python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills developer --eval-ids ambiguous-missing-design --runs-per-eval 1 --run-mode with_skill --output-dir tools/eval/results/skill-lifecycle-empirical-pilot-20260423/developer-with-skill --allow-failures
python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills developer --eval-ids ambiguous-missing-design --runs-per-eval 1 --run-mode without_skill --output-dir tools/eval/results/skill-lifecycle-empirical-pilot-20260423/developer-without-skill --allow-failures
```

If a command records infrastructure failure, do not use it to update review metrics; record the failure in verify evidence.

2. [T3] Update lifecycle review files through the aggregator.

Run:

```bash
python3 tools/eval/scripts/update_lifecycle_review.py --skill product-manager --with-summary tools/eval/results/skill-lifecycle-empirical-pilot-20260423/product-manager-with-skill/summary.json --output-review shared/skills/product-manager/evals/lifecycle-review.json --write-review
python3 tools/eval/scripts/update_lifecycle_review.py --skill developer --with-summary tools/eval/results/skill-lifecycle-empirical-pilot-20260423/developer-with-skill/summary.json --without-summary tools/eval/results/skill-lifecycle-empirical-pilot-20260423/developer-without-skill/summary.json --output-review shared/skills/developer/evals/lifecycle-review.json --write-review
```

3. [T3] Run lifecycle tests.

Run:

```bash
bash tests/test-skill-lifecycle-empirical-review.sh
bash tests/test-skill-lifecycle-eval-framework.sh
```

Expected: PASS.

### Task 4: Validation And Closeout [T4]

Context: This connects the new empirical lifecycle test to quick validation and records proof.

Files:
- Modify: `tests/run-all.sh`
- Modify: `docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval/tasks.md`
- Create: `docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval/verify-change-report.md`

1. [T4] Add the new empirical lifecycle test to `tests/run-all.sh`.

Place `tests/test-skill-lifecycle-empirical-review.sh` near the lifecycle framework and standard-chain local eval tests.

2. [T4] Run final targeted verification.

Run:

```bash
python3 tools/community/check_task_plan_consistency.py docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval/tasks.md docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval/plan.md
bash tests/test-standard-chain-local-eval-runner.sh
bash tests/test-skill-lifecycle-empirical-review.sh
bash tests/test-skill-lifecycle-eval-framework.sh
bash tests/test-standard-chain-skill-evals.sh
git diff --check
```

Expected: every command exits 0.

3. [T4] Mark tasks complete only after task evidence is green.

Change each task checkbox in `tasks.md` from `[ ]` to `[x]` after its AC is proven.

4. [T4] Create `verify-change-report.md`.

Include status, CRITICAL/WARNING/SUGGESTION sections, command evidence, and explicit notes about which empirical sample commands produced usable metrics.

5. [T4] Run final consistency.

Run: `python3 tools/community/check_task_plan_consistency.py docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval/tasks.md docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval/plan.md`

Expected: PASS.
