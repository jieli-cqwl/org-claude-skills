# Skill Optimization Batch 1

## Problem Statement

The empirical lifecycle eval batches proved that the runner and lifecycle review path work. The current bottleneck is Skill effectiveness.

`product-manager` passed expectation checks in batch 2, but its encoded-preference fidelity stayed at `0.3333` across three with-skill evals. The grader findings point to missing explicit coverage of UNIT closed-loop structure and AC / exclusion traceability in blocking and canonical-review answers.

`developer` achieved `1.0` fidelity in both with-skill and without-skill modes, leaving `capability_uplift = 0.0`. That result means the current eval set cannot distinguish the Skill from generic engineering behavior. The safe optimization target is to strengthen the Skill contract around canonical inputs, scope blocking, TDD evidence indexing, report output, and self-testing so future eval answers expose Skill-specific obligations more consistently.

This batch optimizes the two Skill bodies. It does not change grader scoring rules, eval prompts, lifecycle aggregation code, or baseline result semantics.

## Goals And Success Criteria

1. `product-manager` with-skill batch rerun records at least 3 graded runs, zero infra failures, and `encoded_preference.fidelity >= 0.6667`.
2. `developer` with/without rerun records at least 3 graded runs per mode, zero infra failures, and `capability_uplift.uplift > 0.0`.
3. A deterministic Skill contract test proves the new wording requirements before empirical runs.
4. Lifecycle review files are updated only from clean summaries with `infra_failures = 0`, and both reviews keep `decision: "optimize"`.
5. Small-chain documents and changelog record the optimization evidence and any remaining measured gap.

## Scope

In scope:

- `shared/skills/product-manager/SKILL.md`
- `shared/skills/developer/SKILL.md`
- A deterministic shell contract test for the optimized Skill wording.
- Batch-1 optimization result summaries under `tools/eval/results/skill-lifecycle-optimization-batch-1-20260423/`.
- Lifecycle review updates for `product-manager` and `developer`.
- Small-chain closeout documents and changelog entry.

Out of scope:

- Changing eval case prompts or expected anchors.
- Changing grader prompts, runner scoring, lifecycle aggregation, or `evals/evals.json`.
- Promoting any Skill to `retain` or `retire`.
- Touching unrelated worktrees or upstream-fidelity branches.

## Design

The optimization is a Skill-contract change, not an infrastructure change.

For `product-manager`, add a compact response contract near the output and completion sections. It forces PM answers, including blocking answers, to mention the downstream invariant: every future UNIT needs `输入 / 触发 / 核心行为 / 可观察结果`, Integration Context, dependency and exclusion traceability, AC examples, and Verification Plan mapping. This targets the exact missing preference anchors from batch 2 without loosening hard gates.

For `developer`, add an eval-safe response contract that makes explanation-mode behavior more concrete. When the prompt says the eval does not require code changes, the Skill still has to output the canonical input gate, file-range gate, per-AC RED/GREEN plan, `developer-report.json` skeleton obligations, `tdd_evidence_index`, `reviewable_anchor`, `task_scope`, self-testing levels, and `BLOCKED` behavior when canonical inputs are missing. This gives with-skill answers more contract-specific evidence than without-skill answers.

The deterministic test checks for these phrases and field names in the Skill files. It is not the final effectiveness proof. The final proof remains the empirical rerun using the existing eval set.

## Verification

The proving chain is:

1. RED: add deterministic Skill contract assertions and run them before Skill edits.
2. GREEN: update the two Skill files and rerun the deterministic test.
3. Regression: run existing lifecycle and runner contract tests.
4. Empirical: rerun the same batch-2 eval groups under a new optimization result directory.
5. Aggregation: update lifecycle reviews only after all summaries show zero infra failures.
6. Closeout: run task-plan consistency, target tests, py_compile, and `git diff --check`.

## Risks And Handling

- If an empirical summary records an infra failure, do not update lifecycle metrics from that summary. Diagnose the failed executor or judge output first.
- If `developer` uplift remains `0.0`, record the result as an eval-set separability gap and stop changing Skill wording in this batch.
- If deterministic contract tests pass but empirical fidelity does not improve, keep the empirical conclusion authoritative.
