# Skill Optimization Batch 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Improve measured lifecycle eval effectiveness for `product-manager` and `developer` by tightening Skill response contracts and proving the result with the existing eval set.

**Architecture:** Keep infrastructure stable and change only the two Skill bodies plus deterministic contract tests and closeout docs. The deterministic test guards intended wording, while empirical summaries remain the authority for measured effectiveness.

**Tech Stack:** Markdown Skill files, Bash contract tests, Python lifecycle review updater, JSON lifecycle review files, `codex exec` local eval runner.

---

### Task 1: Deterministic Contract Test [T1]

Context: The empirical weak points are wording-contract gaps. The RED test must fail before the Skill files are changed, proving the test catches the missing contract.

Files:
- Create: `tests/test-skill-optimization-contracts.sh`

1. [T1] Create a shell test that reads the two Skill files and asserts required contract phrases.

The test checks exact phrases that the implementation will add:

```bash
bash tests/test-skill-optimization-contracts.sh
```

Expected before Skill edits:

```text
[FAIL] product-manager missing optimization phrase
```

2. [T1] Run the new test before touching `shared/skills/product-manager/SKILL.md` or `shared/skills/developer/SKILL.md`.

Run:

```bash
bash tests/test-skill-optimization-contracts.sh
```

Expected: non-zero exit with at least one missing phrase message.

### Task 2: Skill Contract Optimization [T2]

Context: Keep existing hard gates intact. Add compact response-contract sections so eval answers expose the Skill-specific obligations that batch 2 showed were absent.

Files:
- Modify: `shared/skills/product-manager/SKILL.md`
- Modify: `shared/skills/developer/SKILL.md`
- Modify: `tests/test-skill-optimization-contracts.sh`

1. [T2] Add a `## Response Contract` section to `product-manager`.

The section must require:

```text
PM-OPT-1 UNIT 闭环锚点
PM-OPT-2 AC 与排除项追踪锚点
PM-OPT-3 阻断回答仍保留下游锚点
```

2. [T2] Add a `## Eval-Safe Response Contract` section to `developer`.

The section must require:

```text
DEV-OPT-1 说明模式仍输出 canonical gates
DEV-OPT-2 每条 AC 的 RED/GREEN/REFACTOR 证据索引
DEV-OPT-3 developer-report.json 骨架字段
DEV-OPT-4 缺少 canonical 输入时 BLOCKED
```

3. [T2] Run the deterministic contract test.

Run:

```bash
bash tests/test-skill-optimization-contracts.sh
```

Expected:

```text
[PASS] skill optimization contracts
```

4. [T2] Run existing regression tests.

Run:

```bash
bash tests/test-skill-lifecycle-empirical-review.sh
bash tests/test-standard-chain-local-eval-runner.sh
```

Expected: both commands exit 0.

### Task 3: Empirical Optimization Evidence [T3]

Context: The deterministic test only proves wording presence. The existing eval set supplies the real effectiveness measurement.

Files:
- Create: `tools/eval/results/skill-lifecycle-optimization-batch-1-20260423/product-manager-with-skill/`
- Create: `tools/eval/results/skill-lifecycle-optimization-batch-1-20260423/developer-with-skill/`
- Create: `tools/eval/results/skill-lifecycle-optimization-batch-1-20260423/developer-without-skill/`
- Modify: `shared/skills/product-manager/evals/lifecycle-review.json`
- Modify: `shared/skills/developer/evals/lifecycle-review.json`

1. [T3] Run product-manager with the same three with-skill evals.

```bash
python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills product-manager --eval-ids handoff-validation-first,director-lock-drift-blocking,canonical-review-required --runs-per-eval 1 --run-mode with_skill --output-dir tools/eval/results/skill-lifecycle-optimization-batch-1-20260423/product-manager-with-skill --allow-failures
```

2. [T3] Run developer with-skill evals.

```bash
python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills developer --eval-ids happy-path-canonical-task,ambiguous-missing-design,interface-tweak-out-of-scope --runs-per-eval 1 --run-mode with_skill --output-dir tools/eval/results/skill-lifecycle-optimization-batch-1-20260423/developer-with-skill --allow-failures
```

3. [T3] Run developer without-skill evals.

```bash
python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills developer --eval-ids happy-path-canonical-task,ambiguous-missing-design,interface-tweak-out-of-scope --runs-per-eval 1 --run-mode without_skill --output-dir tools/eval/results/skill-lifecycle-optimization-batch-1-20260423/developer-without-skill --allow-failures
```

4. [T3] Inspect all summary files before updating review files.

Run:

```bash
jq '.summary' tools/eval/results/skill-lifecycle-optimization-batch-1-20260423/*/summary.json
```

Expected: every `infra_failures` value is `0`.

5. [T3] Update lifecycle reviews from clean summaries.

Run:

```bash
python3 tools/eval/scripts/update_lifecycle_review.py --skill product-manager --summary tools/eval/results/skill-lifecycle-optimization-batch-1-20260423/product-manager-with-skill/summary.json --output shared/skills/product-manager/evals/lifecycle-review.json
python3 tools/eval/scripts/update_lifecycle_review.py --skill developer --with-summary tools/eval/results/skill-lifecycle-optimization-batch-1-20260423/developer-with-skill/summary.json --without-summary tools/eval/results/skill-lifecycle-optimization-batch-1-20260423/developer-without-skill/summary.json --output shared/skills/developer/evals/lifecycle-review.json
```

### Task 4: Closeout [T4]

Context: The branch only integrates after fresh commands prove the success criteria and the closeout documents capture the evidence.

Files:
- Create: `docs/skill-lifecycle-eval/2026-04-23-skill-optimization-batch-1/verify-change-report.md`
- Create: `docs/skill-lifecycle-eval/2026-04-23-skill-optimization-batch-1/code-review-result.json`
- Create: `docs/skill-lifecycle-eval/2026-04-23-skill-optimization-batch-1/fix-result.json`
- Modify: `docs/skill-lifecycle-eval/CHANGELOG.md`
- Modify: `docs/skill-lifecycle-eval/2026-04-23-skill-optimization-batch-1/tasks.md`
- Move on archive step: `docs/archive/skill-lifecycle-eval/2026-04-23-skill-optimization-batch-1/`

1. [T4] Write closeout files with measured metrics, command evidence, and residual gaps.

2. [T4] Run fresh proving commands:

```bash
python3 tools/community/check_task_plan_consistency.py docs/skill-lifecycle-eval/2026-04-23-skill-optimization-batch-1/tasks.md docs/skill-lifecycle-eval/2026-04-23-skill-optimization-batch-1/plan.md
bash tests/test-skill-optimization-contracts.sh
bash tests/test-skill-lifecycle-empirical-review.sh
bash tests/test-standard-chain-local-eval-runner.sh
bash tests/test-skill-lifecycle-eval-framework.sh
bash tests/test-standard-chain-skill-evals.sh
python3 -m py_compile tools/eval/scripts/update_lifecycle_review.py tools/eval/scripts/standard_chain_local_eval/common.py tools/eval/scripts/standard_chain_local_eval/workspace.py tools/eval/scripts/standard_chain_local_eval/grading.py tools/eval/scripts/standard_chain_local_eval/runner.py
git diff --check
```

3. [T4] Commit, merge to `main`, push `origin/main`, and release the optimization worktree after integration.
