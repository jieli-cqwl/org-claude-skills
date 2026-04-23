# Empirical Skill Lifecycle Eval Batch 2 Implementation Plan

**Goal:** Expand lifecycle empirical evidence for `product-manager` and `developer` from single-sample pilot data to three-eval batch evidence, then merge the verified change back to `main`.

**Architecture:** Reuse the batch-1 runner and lifecycle aggregator without changing the main execution path. Strengthen the repository review-file assertions first, then run real batch-2 eval summaries and write the review updates through the existing aggregator.

**Tech Stack:** Python standard library scripts, Bash contract tests, JSON lifecycle review files, `codex exec` local eval runner.

---

### Task 1: Raise the empirical review gate [T1]

Context: Repository review files on `origin/main` still record pilot sample size `1`. We need a deterministic RED that proves batch-2 evidence is still missing.

Files:
- Modify: `tests/test-skill-lifecycle-empirical-review.sh`

1. [T1] Extend the repository review-file assertions first.
   - Require `product-manager["encoded_preference"]["sample_size"] >= 3`
   - Require `developer["capability_uplift"]["with_sample_size"] >= 3`
   - Require `developer["capability_uplift"]["without_sample_size"] >= 3`

2. [T1] Run the test and confirm RED.
   - Command: `bash tests/test-skill-lifecycle-empirical-review.sh`
   - Expected: FAIL because current review files still record pilot sample size `1`.

3. [T1] Keep the stronger assertions in place for GREEN after batch-2 review updates land.

### Task 2: Record batch-2 empirical summaries [T2]

Context: The infrastructure already exists. This task only records larger real summaries for the two representative skills.

Files:
- Create directory as needed: `tools/eval/results/skill-lifecycle-empirical-batch-2-20260423/`

1. [T2] Run `product-manager` with all 3 eval ids in `with_skill`.
2. [T2] Run `developer` with all 3 eval ids in `with_skill`.
3. [T2] Run `developer` with all 3 eval ids in `without_skill`.
4. [T2] Inspect each `summary.json`.
   - If any summary records `infra_failures > 0`, stop review updates and diagnose.

Recommended commands:

```bash
python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills product-manager --eval-ids handoff-validation-first,director-lock-drift-blocking,canonical-review-required --runs-per-eval 1 --run-mode with_skill --output-dir tools/eval/results/skill-lifecycle-empirical-batch-2-20260423/product-manager-with-skill --allow-failures
python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills developer --eval-ids happy-path-canonical-task,ambiguous-missing-design,interface-tweak-out-of-scope --runs-per-eval 1 --run-mode with_skill --output-dir tools/eval/results/skill-lifecycle-empirical-batch-2-20260423/developer-with-skill --allow-failures
python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills developer --eval-ids happy-path-canonical-task,ambiguous-missing-design,interface-tweak-out-of-scope --runs-per-eval 1 --run-mode without_skill --output-dir tools/eval/results/skill-lifecycle-empirical-batch-2-20260423/developer-without-skill --allow-failures
```

### Task 3: Update lifecycle review and closeout documents [T3]

Context: Once the new summaries are clean, lifecycle review files become the canonical statement of batch-2 evidence.

Files:
- Modify: `shared/skills/product-manager/evals/lifecycle-review.json`
- Modify: `shared/skills/developer/evals/lifecycle-review.json`
- Modify: `docs/skill-lifecycle-eval/CHANGELOG.md`
- Create: `docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval-batch-2/verify-change-report.md`
- Create: `docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval-batch-2/code-review-result.json`
- Create: `docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval-batch-2/fix-result.json`

1. [T3] Update both lifecycle review files via `update_lifecycle_review.py`.
2. [T3] Re-run `bash tests/test-skill-lifecycle-empirical-review.sh` and confirm GREEN.
3. [T3] Record batch-2 command evidence, warnings, and review conclusions.
4. [T3] Mark completed tasks in `tasks.md`.

### Task 4: Fresh verification, integration, and archive [T4]

Context: Batch-2 only counts once the fresh proving commands pass and the change reaches `origin/main`.

Files:
- Modify: `docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval-batch-2/tasks.md`
- Move on archive step: `docs/archive/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval-batch-2/`

1. [T4] Run fresh proving commands:

```bash
python3 tools/community/check_task_plan_consistency.py docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval-batch-2/tasks.md docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval-batch-2/plan.md
bash tests/test-skill-lifecycle-empirical-review.sh
bash tests/test-standard-chain-local-eval-runner.sh
bash tests/test-skill-lifecycle-eval-framework.sh
bash tests/test-standard-chain-skill-evals.sh
python3 -m py_compile tools/eval/scripts/update_lifecycle_review.py tools/eval/scripts/standard_chain_local_eval/common.py tools/eval/scripts/standard_chain_local_eval/workspace.py tools/eval/scripts/standard_chain_local_eval/grading.py tools/eval/scripts/standard_chain_local_eval/runner.py
git diff --check
```

2. [T4] Commit batch-2 on the worktree branch.
3. [T4] Merge to `main`, push `origin/main`, and release the worktree branch.
4. [T4] Archive the verified batch-2 docs directory and append the changelog entry.
