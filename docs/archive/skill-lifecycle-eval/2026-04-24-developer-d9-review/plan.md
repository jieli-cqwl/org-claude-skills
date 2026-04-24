# Developer D9 Review Implementation Plan

**Goal:** Test whether `developer` has enough measured uplift to remain a standalone Skill by adding harder evals and rerunning with/without baselines.

**Architecture:** Keep the runner and grader unchanged. Add harder eval cases, prove they are present through a deterministic shell test, then use the existing local eval runner and lifecycle updater to record empirical evidence.

**Tech Stack:** JSON eval definitions, Bash contract tests, Python lifecycle review updater, `codex exec` local eval runner, Markdown closeout docs.

---

### Task 1: RED Contract [T1]

Context: The repository needs a deterministic signal that the harder D9 eval set is absent before it is added.

Files:
- Create: `tests/test-developer-d9-review-evals.sh`

1. [T1] Create the shell test.
2. [T1] Run `bash tests/test-developer-d9-review-evals.sh`.
3. [T1] Confirm it exits non-zero and reports the missing eval ids.

### Task 2: Harder Eval Cases [T2]

Context: The eval cases should target behavior that generic engineering answers omit.

Files:
- Modify: `shared/skills/developer/evals/evals.json`
- Modify: `tests/run-all.sh`

1. [T2] Add `multi-ac-report-evidence-index`.
2. [T2] Add `scope-conflict-shared-file`.
3. [T2] Add `regression-failure-blocks-completion`.
4. [T2] Add `report-schema-missing-evidence-fields`.
5. [T2] Add `tests/test-developer-d9-review-evals.sh` to `tests/run-all.sh`.
6. [T2] Run:

```bash
bash tests/test-developer-d9-review-evals.sh
bash tests/test-standard-chain-skill-evals.sh
```

### Task 3: Empirical D9 Review [T3]

Context: The D9 decision must use real local eval output, not deterministic contract tests.

Files:
- Create: `tools/eval/results/developer-d9-review-20260424/developer-with-skill/`
- Create: `tools/eval/results/developer-d9-review-20260424/developer-without-skill/`
- Modify: `shared/skills/developer/evals/lifecycle-review.json`

1. [T3] Run with-skill harder evals:

```bash
python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills developer --eval-ids multi-ac-report-evidence-index,scope-conflict-shared-file,regression-failure-blocks-completion,report-schema-missing-evidence-fields --runs-per-eval 1 --run-mode with_skill --output-dir tools/eval/results/developer-d9-review-20260424/developer-with-skill --timeout-sec 480 --allow-failures
```

2. [T3] Run without-skill harder evals:

```bash
python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills developer --eval-ids multi-ac-report-evidence-index,scope-conflict-shared-file,regression-failure-blocks-completion,report-schema-missing-evidence-fields --runs-per-eval 1 --run-mode without_skill --output-dir tools/eval/results/developer-d9-review-20260424/developer-without-skill --timeout-sec 480 --allow-failures
```

3. [T3] Confirm both summaries have `infra_failures = 0`.
4. [T3] Update lifecycle review through `update_lifecycle_review.py`.
5. [T3] If uplift is below `0.5`, add a `retire_candidate` block requiring human confirmation before retirement.

### Task 4: Closeout [T4]

Context: The final state must be verified and pushed from `main`.

Files:
- Create: `docs/skill-lifecycle-eval/2026-04-24-developer-d9-review/verify-change-report.md`
- Create: `docs/skill-lifecycle-eval/2026-04-24-developer-d9-review/code-review-result.json`
- Create: `docs/skill-lifecycle-eval/2026-04-24-developer-d9-review/fix-result.json`
- Modify: `docs/skill-lifecycle-eval/CHANGELOG.md`
- Move on archive: `docs/archive/skill-lifecycle-eval/2026-04-24-developer-d9-review/`

1. [T4] Write closeout files.
2. [T4] Archive the document directory.
3. [T4] Run fresh proving commands:

```bash
python3 tools/community/check_task_plan_consistency.py docs/archive/skill-lifecycle-eval/2026-04-24-developer-d9-review/tasks.md docs/archive/skill-lifecycle-eval/2026-04-24-developer-d9-review/plan.md
bash tests/test-developer-d9-review-evals.sh
bash tests/test-standard-chain-skill-evals.sh
bash tests/test-skill-lifecycle-empirical-review.sh
bash tests/test-standard-chain-local-eval-runner.sh
python3 -m py_compile tools/eval/scripts/update_lifecycle_review.py tools/eval/scripts/standard_chain_local_eval/common.py tools/eval/scripts/standard_chain_local_eval/workspace.py tools/eval/scripts/standard_chain_local_eval/grading.py tools/eval/scripts/standard_chain_local_eval/runner.py
git diff --check
```

4. [T4] Commit and push `main`.
