# Empirical Skill Lifecycle Eval Batch 2

## 问题陈述

上一轮 empirical pilot 已经证明标准链 local eval 可以输出 `with_skill` / `without_skill` summary，并能把聚合结果写回 `lifecycle-review.json`。当前缺口不在基础设施，而在样本量：`product-manager` 只记录了 1 条 with-skill 样本，`developer` 只记录了 1 条 with-skill 和 1 条 without-skill 样本。这样的 evidence 只能证明链路通了，不能支撑后续 retain / retire 判断。

本轮要做的是扩充代表样本，而不是重写 runner、扩到全部 12 个 Skill，或把 pilot 数据包装成最终结论。

## 目标与成功标准

目标：把 `product-manager` 与 `developer` 的 lifecycle empirical evidence 从单点 pilot 扩成可重复的小批量样本，并把验证门槛同步收紧到 batch-2 水平。

成功标准：

1. `product-manager` 的 empirical review 至少覆盖 3 条 with-skill eval，`encoded_preference.sample_size >= 3`。
2. `developer` 的 empirical review 至少覆盖 3 条 with-skill 和 3 条 without-skill eval，`capability_uplift.with_sample_size >= 3` 且 `without_sample_size >= 3`。
3. `tests/test-skill-lifecycle-empirical-review.sh` 先以当前 sample size 不足为 RED，再在 review 更新后变为 GREEN。
4. 生命周期 review 仍保持 `decision: "optimize"`，不把 batch-2 evidence 升格为 retain / retire。
5. 新增 small-chain 文档、verify 证据、review 结论与结果目录都能独立追溯 batch-2。

## 方案

### 范围冻结

本轮只扩充两个代表 Skill：

- `product-manager`
  - `handoff-validation-first`
  - `director-lock-drift-blocking`
  - `canonical-review-required`
- `developer`
  - `happy-path-canonical-task`
  - `ambiguous-missing-design`
  - `interface-tweak-out-of-scope`

运行组合：

- `product-manager`: 3 条 eval，`with_skill`
- `developer`: 3 条 eval，`with_skill`
- `developer`: 3 条 eval，`without_skill`

### 实现策略

本轮默认不改 runner 主逻辑。Batch-1 已经为 runner、judge 和 lifecycle 聚合器补齐了所需能力；batch-2 复用这条链路，只做三类改动：

1. 收紧 deterministic review 测试门槛
   - 让 `tests/test-skill-lifecycle-empirical-review.sh` 对 repository 内真实 review 文件要求 batch-2 sample size。
   - 当前 `origin/main` 的 review 文件 sample size 仍是 1，测试先红，再通过真实 batch-2 summary 变绿。

2. 运行真实 batch-2 empirical eval
   - 新建结果目录：
     - `tools/eval/results/skill-lifecycle-empirical-batch-2-20260423/product-manager-with-skill/`
     - `tools/eval/results/skill-lifecycle-empirical-batch-2-20260423/developer-with-skill/`
     - `tools/eval/results/skill-lifecycle-empirical-batch-2-20260423/developer-without-skill/`
   - 如 summary 出现 infra failure，则该 summary 不得进入 review 聚合；需要先定位并记录阻塞。

3. 更新 lifecycle review 与 closeout 证据
   - 用 `update_lifecycle_review.py` 写回两个 Skill 的 `lifecycle-review.json`
   - 记录 batch-2 verify-change 报告、code review 结果、必要的 fix 结果
   - 接入 `docs/skill-lifecycle-eval/CHANGELOG.md`

### 不变量

- 不改写 `evals/evals.json` 的语义与锚点定义。
- 不扩到其他 Skill。
- 不把 batch-2 样本直接写成 retain / retire。
- 不用 fake runner 输出替代真实 empirical evidence。
- 不触碰主工作区 `codex/upstream-fidelity-noise-cleanup` 上的未提交改动。

## 风险与处理

- 真实模型执行出现 infra failure：停止使用该 summary 更新 review，先记录阻塞与日志，再决定是否修 runner 或重跑。
- `without_skill` 结果继续和 `with_skill` 一样高：如实记录 `uplift`，不人为调分。
- 外部 CLI 噪声污染 raw log：沿用 batch-1 做法，只把可验证产物纳入 evidence 目录与 verify 报告。
