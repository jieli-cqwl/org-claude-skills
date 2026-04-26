# Skill 能力有效性标准

> 触发条件：创建、审计、优化或复审 first-party Skill 的存在合理性时读取。

本文定义 first-party Skill 的有效性评估标准：一个 Skill 为什么仍应存在、如何证明它比裸模型或普通提示更有价值，以及何时进入优化或退役流程。

本标准不是 `Skill质量标准.md` 的维度，不参与 D1-D8 运行面质量裁决。运行面质量先按 `Skill质量标准.md` 裁决；有效性评估只决定 `retain`、`optimize`、`retire` 等生命周期状态。

## 有效性裁决目标

有效性评估保护的风险是：Skill 价值衰减未被发现、用户偏好发生漂移、退役延迟导致上下文浪费，或模型升级后原本的能力补丁已不再需要。

评估基线：

- `SKILL.md` frontmatter 声明 `eval-type`。
- `eval-type` 只能是 `capability_uplift`、`encoded_preference` 或 `mixed`。
- `evals/evals.json` 的 `eval_type` 与 frontmatter 匹配。
- 每个 Skill 至少有 3 个代表性 eval 场景，覆盖典型成功、边界/失败或反触发，以及真实历史任务或用户确认场景。
- 存在 `evals/lifecycle-review.json`，其 `review_date` 距本次审计日期不超过 90 天，或 `next_action` 明确说明延期原因；记录必须包含 `retain`、`optimize` 或 `retire` 结论与证据引用。
- `capability_uplift` 或 `mixed` 必须定义绑定用户目标和失败模式的 `grader_dimensions`，并在经验评审阶段产出 with-skill / without-skill baseline 数据。
- `encoded_preference` 或 `mixed` 必须定义 5-10 个偏好锚点，并在经验评审阶段产出保真度、误触发和冲突处理数据。

强证据：

- 模型大版本升级后能复跑同一 eval 集并比较趋势。
- 评审记录能追溯到 eval 输出、grader 输出、聚合脚本或人工确认记录。
- 上下文成本有记录：`SKILL.md` 行数、运行时读取 reference 行数、加载条件。
- 退役候选能给出人工确认、影响范围和回滚路径。

## Skill 类型

| 类型 | 定义 | 核心问题 | 必要数据 |
| --- | --- | --- | --- |
| `capability_uplift` | 补能力：让模型更稳定地完成原本容易失败的任务 | 这个 Skill 仍带来真实增益吗？ | with-skill / without-skill baseline、grader 维度分、上下文成本 |
| `encoded_preference` | 固化偏好：让模型按用户的方法论、流程和判断标准工作 | 它是否仍忠实执行用户偏好？ | 偏好锚点、锚点命中率、用户确认记录 |
| `mixed` | 同时补能力并固化偏好 | 增益和偏好保真是否都成立？ | 共享 eval 输出，分别产出 uplift 与 fidelity 数据 |

## Capability Uplift 协议

输入：

- 至少 3 个代表性场景 prompt：典型成功、边界/失败或反触发、真实历史任务或用户确认场景。
- `evals/evals.json` 中每个场景声明 `run_modes: ["with_skill", "without_skill"]`。
- 每个 Skill 声明 `grader_dimensions`，并说明每个维度对应的用户目标、失败模式和评分理由；不得只选择容易得分的维度。

流程：

1. 每个 prompt 分别跑 with-skill 和 without-skill。
2. 预定义 grader 按每个 `grader_dimensions` 维度给 0-5 分。
3. 计算所有场景和维度的 `with_avg`、`without_avg` 与 `uplift = with_avg - without_avg`。
4. 记录上下文成本：`SKILL.md` 行数和运行时实际读取 reference 行数。

指标是裁决信号，不是有效性结论。结论必须同时参考样本代表性、失败模式覆盖、上下文成本、评分理由和反证样本。

- `uplift < 0.5`：`retire` 候选；必须人工确认样本质量、替代路径和影响范围后才能执行退役协议。
- `with_avg >= 4.0` 且 `uplift >= 1.0`，并且关键失败模式改善、上下文成本可接受：`retain`。
- 其余：`optimize`，聚焦低分维度、上下文成本或 Skill 文本质量。

## Encoded Preference 协议

偏好锚点：

- 每个 `encoded_preference` 或 `mixed` Skill 声明 5-10 个锚点。
- 锚点来自 `HARD-GATE`、流程步骤、输出合同和用户确认的方法论。
- 锚点清单需要用户确认；锚点缺失属于评审口径问题，不能直接判定 Skill 失效。

流程：

1. 每个 prompt 用 Skill 跑一次。
2. grader 以 `expected_anchors` 为 checklist，记录命中、误触发、冲突和关键锚点遗漏。
3. 计算保真度：命中锚点数 / 应命中锚点数，并记录误触发与冲突处理。

保真度是裁决信号，不是有效性结论。结论还需参考样本代表性、用户意图冲突、误触发、上下文成本和反证样本。

- `fidelity >= 0.80` 且无关键锚点遗漏、误触发或用户意图冲突：可 `retain`。
- `0.60 <= fidelity < 0.80`：`optimize` 信号，强化系统性丢失的锚点。
- `fidelity < 0.60`：重写或退役信号；先复核锚点有效性、样本质量和替代路径。

## Mixed 协议

`mixed` Skill 共享 eval 运行以控制成本：

- with-skill 输出同时用于 uplift grader 和偏好锚点 grader。
- 额外运行 without-skill，只用于 uplift baseline。
- `lifecycle-review.json` 必须同时包含 `capability_uplift` 和 `encoded_preference` 数据。
- 任一协议未达 retain 线时，整体结论不得写 `retain`。

## 初始评审与经验评审

初始评审只证明有效性评估框架已经就位：`eval-type`、eval 场景、锚点、grader 维度和 review 记录存在。初始评审不能伪造经验分数。

经验评审才证明 Skill 是否 `retain`。如果尚未完成 with-skill / without-skill 或锚点保真度实测，结论应写 `optimize`，并在 `measurement_status` 说明下一次必须执行的真实 eval。

## lifecycle-review.json 合同

每个目标 Skill 在 `evals/lifecycle-review.json` 记录最近一次生命周期评审：

```json
{
  "skill_name": "developer",
  "eval_type": "mixed",
  "review_date": "2026-04-23",
  "decision": "optimize",
  "decision_label": "优化",
  "evidence_refs": [
    "shared/skills/developer/SKILL.md",
    "shared/skills/developer/evals/evals.json"
  ],
  "capability_uplift": {
    "measurement_status": "needs_empirical_baseline",
    "with_avg": null,
    "without_avg": null,
    "uplift": null
  },
  "encoded_preference": {
    "measurement_status": "anchors_defined_needs_fidelity_run",
    "anchor_count": 6,
    "eval_count": 3,
    "fidelity": null
  }
}
```

`decision` 枚举：

- `retain`：经验数据、失败模式和反证检查共同支持保留。
- `optimize`：价值证据不足、指标未达线，或首轮经验 eval 未完成。
- `retire`：经验数据连续不达标，且已进入人工确认退役流程。

## 与运行面质量标准的关系

有效性评估不替代 D1-D8。D1-D8 证明 Skill 是否能稳定、正确、安全地运行；有效性评估证明它是否仍值得被加载和维护。D1-D8 存在影响运行稳定性、正确性或安全性的 `severity: FAIL` 时，不能用“有价值”覆盖运行时风险。有效性证据不足时，Skill 最多只能进入 `optimize`，不能写 `retain`。
