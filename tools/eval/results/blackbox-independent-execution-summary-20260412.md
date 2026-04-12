# /product 黑盒独立执行证据汇总

日期：2026-04-12

## 目标

这份汇总只回答一个问题：

- 当 `/product` 由独立 agent 黑盒执行时，结果是否仍与我们当前的人工 replay 结论基本一致？

## 取证范围

- 场景：
  - `P1: clear-single-phase`
  - `P2: solution-anchoring`
  - `P3: multi-phase-value-slicing`
- 输入约束：
  - 只读场景文件
  - 只读当前 `product` skill 及必要 references
  - 不读取既有 `tools/eval/results/p*-run-*` 人工 replay 结果

## 阶段结果

| 场景 | 初始黑盒样本 | 首轮加固后 | 二轮加固后 | 最终状态 |
|------|--------------|------------|------------|----------|
| P1 | `p1-clear-single-phase-blackbox-run-2`：BLOCK | `p1-clear-single-phase-blackbox-rerun-1`：PASS | - | PASS |
| P2 | `p2-solution-anchoring-blackbox-run-1`：BLOCK | `p2-solution-anchoring-blackbox-rerun-1`：BLOCK，确认时间带 `CST` 后缀 | `p2-solution-anchoring-blackbox-rerun-2`：BLOCK，交付计划缺少 `工作区/状态` 映射；`p2-solution-anchoring-blackbox-rerun-3`：PASS | PASS |
| P3 | `p3-multi-phase-value-slicing-blackbox-run-1`：BLOCK | `p3-multi-phase-value-slicing-blackbox-rerun-1`：BLOCK，审查问题台账留空 | `p3-multi-phase-value-slicing-blackbox-rerun-2`：PASS | PASS |

## 关键观察

### 1. 语义能力一直稳定

- `P1` 黑盒下仍保持轻量收口，没有把简单需求扩成复杂项目。
- `P2` 黑盒下仍能把“角色树/批量授权”退回成候选方案，而不是直接写死进需求。
- `P3` 黑盒下仍能按业务价值切出主链路、通知、报表三个 Phase，而不是按功能数量平均切分。

这说明 `/product` 的核心问题发现、范围收口、Phase 切片能力在黑盒下是成立的。

### 2. 结构化收口问题可通过显式合同逐步收敛

初始黑盒样本的失败点主要集中在：

- `前置约束` 字段不完整
- `审查问题台账 / 收敛轮次摘要 / 用户裁决记录` 不一致
- `交付确认` 时间格式不稳

补充显式合同后，残留问题进一步收敛为单点格式偏差：

- `P2 rerun-1`：确认时间追加了 `CST`
- `P3 rerun-1`：`审查问题台账` 留空
- `P2 rerun-2`：`交付计划` 表头偏离模板，缺少 `工作区/状态`

继续把这些点上浮到 `SKILL.md + brief-template + contract test` 后，`P2/P3` 均在后续黑盒 rerun 中通过 gate。

### 3. 当前最合理的结论

- 不支持“`product` 主定义明显错误”这个结论。
- 更支持“`product` 的语义能力存在，但黑盒下的结构化收口需要强合同支撑”。
- 现在这条链已经从“黑盒方向对但 gate 不稳”推进到了“3 个代表场景均出现 gate 通过的黑盒样本”。

## 当前通过样本

- `P1`：`tools/eval/results/p1-clear-single-phase-blackbox-rerun-1/`
- `P2`：`tools/eval/results/p2-solution-anchoring-blackbox-rerun-3/`
- `P3`：`tools/eval/results/p3-multi-phase-value-slicing-blackbox-rerun-2/`

## 仍需关注的业务风险

- `P2`：权限矩阵交互形态、批量调整能力、审计承载方式仍留给 `design` 收口，后续若复杂度抬高，可能影响 Phase 1 边界。
- `P3`：企业微信通知触发与失败补偿、统计口径与刷新方式仍是 `DD-*` 开放问题，后续 design 不能再把这些细节写回 `/product` 正文。

## 综合判断

- `/product` 的黑盒独立执行证据已经从“发现问题”阶段推进到“证明可修复、可稳定”阶段。
- 当前最有价值的收获不是改角色定义，而是把高频格式性失稳点沉淀成显式合同和自动回归。
- 后续如果继续扩场景，优先补更多黑盒样本，而不是再先验扩大 `/product` 的角色描述。
