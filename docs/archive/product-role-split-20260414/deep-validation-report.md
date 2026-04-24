# Product Split 深度验证 Scorecard

日期：2026-04-15

## 证据边界

这份报告只记录历史 benchmark 结果、可复核工件和已知限制。它不把历史结果当作当前 HEAD 的无条件放行证明。

## Scorecard

| 证据面 | 当前状态 | 证据位置 | 边界 |
|--------|----------|----------|------|
| Runtime contract | 已有覆盖 | `tests/test-product-role-split-contract.sh` | 证明接线和关键断言存在，不证明输出质量 |
| Product eval wiring | 已有覆盖 | `tests/test-product-eval-contract.sh` | 证明轨道接入，不证明每轮生成质量 |
| Benchmark smoke | 已有覆盖 | `tests/test-product-split-benchmark-contract.sh` | 证明 runner 可运行，不等于完整重跑 |
| 历史全量 benchmark | 可复核 | `tools/eval/results/product-split-benchmark-20260415/iteration-4/benchmark.json` | 结果来自 2026-04-15 的历史产物 |
| Blind comparison | 可复核 | `tools/eval/results/product-split-benchmark-20260415/iteration-4/comparison-*.json` | 历史实现使用固定 A/B 和代表 run |

## 历史 Benchmark 摘要

来源：[benchmark.json](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/benchmark.json)

| 案例 | with_split | old_monolith | blind winner |
|------|-----------|--------------|--------------|
| entry-routing-recommendation-rebuild | `0.7778` | `0.3333` | `old_monolith` |
| solution-anchoring-growth-dashboard | `0.4444` | `0.3333` | `with_split` |
| handoff-boundary-loyalty-phase-change | `0.5556` | `0.0000` | `with_split` |
| legacy-brief-migration-pricing-center | `0.5556` | `0.2222` | `with_split` |
| review-orchestration-internal-approval | `1.0000` | `0.8333` | `with_split` |
| phase-planning-partner-onboarding | `0.8889` | `0.5556` | `with_split` |

总体指标：
- skill-creator 风格 benchmark pass rate：`with_split 0.7037`，`old_monolith 0.3796`
- Blind comparison：`with_split 5`，`old_monolith 1`，`tie 0`
- 覆盖：`6 个真实案例`

## Known Limitations

- 历史 eval set 含有 split 术语，不能作为架构无关 outcome 评测。
- 历史 grading 以正则命中为主，不能替代语义级 judge。
- 历史 Blind comparison 使用固定 A/B 顺序。
- 历史 runner 选择代表 run，不代表全量 run 稳定性。
- 当前 contract test 仍以 smoke 和产物存在性为主，不能替代当前 HEAD 全量重跑。

## 验证工件

- 计划与边界：[evidence-and-eval-plan.md](/Users/lijieli/org-claude-skills/docs/product-role-split-20260414/evidence-and-eval-plan.md)
- 全量 benchmark 结果：[iteration-4/benchmark.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/benchmark.md)
- 静态 review 页面：[iteration-4/review.html](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-4/review.html)
- 第一轮 baseline：[iteration-1/benchmark.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-1/benchmark.md)
- 定点复验：[iteration-2/benchmark.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-2/benchmark.md)、[iteration-3/benchmark.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/benchmark.md)
