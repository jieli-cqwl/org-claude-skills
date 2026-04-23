# Empirical Skill Lifecycle Eval Batch 3 Implementation Plan

**Goal:** Extend lifecycle empirical coverage to `product-director` and `design`, then merge the verified batch-3 change back to `main`.

**Architecture:** Reuse the existing local eval runner and lifecycle review updater. Strengthen the repository empirical review test first, then run real batch-3 summaries and write the resulting review updates through the existing aggregation script.

**Tech Stack:** Python standard library scripts, Bash contract tests, JSON lifecycle review files, `codex exec` local eval runner.

---

### Task 1: Raise the empirical review gate [T1]

Context: `product-director` and `design` still have no empirical sample records on `origin/main`. We need a deterministic RED before running batch-3.

Files:
- Modify: `tests/test-skill-lifecycle-empirical-review.sh`

1. [T1] Extend the repository review-file assertions first.
   - Require `product-director["encoded_preference"]["sample_size"] >= 3`
   - Require `design["capability_uplift"]["with_sample_size"] >= 3`
   - Require `design["capability_uplift"]["without_sample_size"] >= 3`

2. [T1] Run the test and confirm RED.
   - Command: `bash tests/test-skill-lifecycle-empirical-review.sh`
   - Expected: FAIL because the two target review files still lack empirical sample counts.

3. [T1] Keep the stronger assertions in place for GREEN after batch-3 review updates land.

### Task 2: Record batch-3 empirical summaries [T2]

Context: The infrastructure is already in place; this task adds breadth across one encoded_preference skill and one mixed skill.

Files:
- Create directory as needed: `tools/eval/results/skill-lifecycle-empirical-batch-3-20260423/`

1. [T2] Run `product-director` with all 3 eval ids in `with_skill`.
2. [T2] Run `design` with all 3 eval ids in `with_skill`.
3. [T2] Run `design` with all 3 eval ids in `without_skill`.
4. [T2] Inspect each `summary.json`.
   - If any summary records `infra_failures > 0`, stop review updates and diagnose before continuing.

Recommended commands:

```bash
python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills product-director --eval-ids director-baseline-no-prd,phase-boundary-drift-routes-back,legacy-brief-blocks-handoff --runs-per-eval 1 --run-mode with_skill --output-dir tools/eval/results/skill-lifecycle-empirical-batch-3-20260423/product-director-with-skill --allow-failures
python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills design --eval-ids missing-canonical-inputs-block,alternatives-and-runtime-scan,final-design-artifact-and-review --runs-per-eval 1 --run-mode with_skill --output-dir tools/eval/results/skill-lifecycle-empirical-batch-3-20260423/design-with-skill --allow-failures
python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills design --eval-ids missing-canonical-inputs-block,alternatives-and-runtime-scan,final-design-artifact-and-review --runs-per-eval 1 --run-mode without_skill --output-dir tools/eval/results/skill-lifecycle-empirical-batch-3-20260423/design-without-skill --allow-failures
```

### Task 3: Update lifecycle review and closeout documents [T3]

Context: Once the summaries are clean, the lifecycle review files become the canonical statement of batch-3 evidence.

Files:
- Modify: `shared/skills/product-director/evals/lifecycle-review.json`
- Modify: `shared/skills/design/evals/lifecycle-review.json`
- Modify: `docs/skill-lifecycle-eval/CHANGELOG.md`
- Create: `docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval-batch-3/verify-change-report.md`
- Create: `docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval-batch-3/code-review-result.json`
- Create: `docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval-batch-3/fix-result.json`

1. [T3] Update both lifecycle review files via `update_lifecycle_review.py`.
2. [T3] Re-run `bash tests/test-skill-lifecycle-empirical-review.sh` and confirm GREEN.
3. [T3] Record batch-3 command evidence, warnings, and review conclusions.
4. [T3] Mark completed tasks in `tasks.md`.

### Task 4: Fresh verification, integration, and archive [T4]

Context: Batch-3 only counts once the fresh proving commands pass and the change reaches `origin/main`.

Files:
- Modify: `docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval-batch-3/tasks.md`
- Move on archive step: `docs/archive/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval-batch-3/`

1. [T4] Run fresh proving commands:

```bash
python3 tools/community/check_task_plan_consistency.py docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval-batch-3/tasks.md docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval-batch-3/plan.md
bash tests/test-skill-lifecycle-empirical-review.sh
bash tests/test-standard-chain-local-eval-runner.sh
bash tests/test-skill-lifecycle-eval-framework.sh
bash tests/test-standard-chain-skill-evals.sh
python3 -m py_compile tools/eval/scripts/update_lifecycle_review.py tools/eval/scripts/standard_chain_local_eval/common.py tools/eval/scripts/standard_chain_local_eval/workspace.py tools/eval/scripts/standard_chain_local_eval/grading.py tools/eval/scripts/standard_chain_local_eval/runner.py
git diff --check
```

2. [T4] Commit batch-3 on the worktree branch.
3. [T4] Merge to `main`, push `origin/main`, and release the worktree branch.
4. [T4] Archive the verified batch-3 docs directory and append the changelog entry.
