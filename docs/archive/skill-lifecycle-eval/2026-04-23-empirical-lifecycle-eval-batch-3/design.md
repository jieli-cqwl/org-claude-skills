# Empirical Skill Lifecycle Eval Batch 3

## 问题陈述

batch-2 已经把 `product-manager` 与 `developer` 从单点 pilot 扩成 3 条样本，但 12 个标准链 Skill 里仍有大部分停在 `needs_empirical_baseline` 或 `anchors_defined_needs_fidelity_run`。当前最值当的增量不是继续加厚已经稳定的两项，而是把 empirical evidence 扩到链路前段和中段，验证这条 lifecycle eval 基础设施在不同 skill 类型上都能重复工作。

本轮选择：

- `product-director`：encoded_preference
- `design`：mixed

这样能在不扩大范围到全量 12 个 Skill 的前提下，同时补一个上游 encoded_preference skill 和一个中段 mixed skill。

## 目标与成功标准

目标：让 `product-director` 与 `design` 进入和 `product-manager` / `developer` 一样的 empirical review 状态，并把 deterministic review gate 扩到这两个 skill。

成功标准：

1. `product-director` 的 lifecycle review 记录 `pilot_empirical_sample_recorded`，`encoded_preference.sample_size >= 3`。
2. `design` 的 lifecycle review 记录 `pilot_empirical_sample_recorded`，`capability_uplift.with_sample_size >= 3`、`without_sample_size >= 3`，并同步写入 encoded preference fidelity。
3. `tests/test-skill-lifecycle-empirical-review.sh` 先因为 `product-director` / `design` 还没有 empirical evidence 而 RED，再在 batch-3 evidence 落盘后变为 GREEN。
4. 两个 skill 的正式 `decision` 仍保持 `optimize`。
5. batch-3 结果、review 结论与 small-chain 工件能独立归档和追溯。

## 方案

### 范围冻结

本轮只扩这两个 skill：

- `product-director`
  - `director-baseline-no-prd`
  - `phase-boundary-drift-routes-back`
  - `legacy-brief-blocks-handoff`
- `design`
  - `missing-canonical-inputs-block`
  - `alternatives-and-runtime-scan`
  - `final-design-artifact-and-review`

运行组合：

- `product-director`: 3 条 eval，`with_skill`
- `design`: 3 条 eval，`with_skill`
- `design`: 3 条 eval，`without_skill`

### 实现策略

本轮默认不改 runner 和 updater 主逻辑，继续复用 batch-1 / batch-2 已验证的执行链路，只做三类动作：

1. 收紧 deterministic gate
   - 扩展 `tests/test-skill-lifecycle-empirical-review.sh`
   - 让仓库内真实 review 文件同时要求 `product-director` 与 `design` 达到 batch-3 样本门槛

2. 记录 batch-3 empirical summaries
   - 结果目录：
     - `tools/eval/results/skill-lifecycle-empirical-batch-3-20260423/product-director-with-skill/`
     - `tools/eval/results/skill-lifecycle-empirical-batch-3-20260423/design-with-skill/`
     - `tools/eval/results/skill-lifecycle-empirical-batch-3-20260423/design-without-skill/`
   - 若任何 summary 出现 infra failure，则该 summary 不能进入 lifecycle review 聚合

3. 更新 canonical review 与 closeout 证据
   - 用 `update_lifecycle_review.py` 写回 `product-director` 和 `design`
   - 产出 batch-3 verify report、code review result、fix result
   - 归档 batch-3 small-chain 目录并更新 changelog

### 不变量

- 不改写 `evals/evals.json` 的语义、锚点或 run_modes。
- 不把 batch-3 扩成全量 skill 扫描。
- 不把 batch-3 empirical evidence 升格为 retain / retire。
- 不触碰主工作区 `codex/upstream-fidelity-noise-cleanup` 的未提交改动。

## 风险与处理

- `design/alternatives-and-runtime-scan` 涉及代码扫描和双方案对比，耗时高于 batch-2 中位数；如果 hit timeout，先保留 response artifact，再按 batch-2 的受控重跑方式恢复 grading。
- `product-director` 的 anchor fidelity 如果持续偏低，应在 report 中写明是稳定结果，不得美化。
- `design` 的 with/without 结果如果没有 uplift，必须如实写回 review。
