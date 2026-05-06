# Skill 能力有效性标准

## Why

Skill 会占用触发入口、上下文预算和维护成本。只有持续带来专业流程收益或稳定偏好收益的 Skill，才值得保留。

## 存在价值判断

一个 Skill 值得存在，看七项：

1. 价值来源明确：它承载专业流程、稳定偏好，或二者组合。
2. 职责真实：专业流程来自软件工程、项目管理、研究、设计、测试等真实办事路径。
3. 偏好稳定：偏好来自用户确认过的方法论、流程选择或质量判断，不是一次性口味。
4. 价值独立：它不只是相邻 Skill 的换皮、旧文档搬运或普通提示包装。
5. 行为可观察：使用它后，输出质量、稳定性、偏好保真、返工成本或错误率有可观察变化。
6. 成本可接受：加载 token、维护复杂度、误触发风险和同步成本低于它带来的收益。
7. 反证清楚：知道哪些场景不该触发、无收益或应交给其他能力。

价值方向成立但证据不足时，信号为 `optimize`；价值来源缺失或反证成立时，信号为 `retire`。

## 价值来源

| 来源 | 成立条件 | 判定标准 |
| --- | --- | --- |
| 专业流程 | Skill 承载真实专业职责或工程职责的办事路径。 | 任务结果更稳定，返工更少。 |
| 稳定偏好 | Skill 承载用户确认过、会重复使用的方法论或判断标准。 | 用户偏好被稳定执行，而不是临场发挥。 |
| 组合价值 | Skill 同时承载专业流程和稳定偏好。 | 结果提升和偏好保真同时成立。 |

## 证据路径

`eval-type` 是评测字段，不是 Skill 本体类型。它决定用哪些证据证明存在价值。

| eval-type | 证明什么 | 适用价值来源 | 常用证据 |
| --- | --- | --- | --- |
| `capability_uplift` | 专业流程或可复用操作能力带来的结果提升。 | 专业流程 | with-skill / without-skill、old/new 对比、成功率、失败模式改善。 |
| `encoded_preference` | 用户确认偏好的稳定执行。 | 稳定偏好 | 偏好锚点、用户确认、锚点命中率、误触发记录。 |
| `mixed` | 结果提升和偏好保真同时成立。 | 组合价值 | 能力增益证据 + 偏好保真证据。 |

`SKILL.md` frontmatter 的 `eval-type` 与 `evals/evals.json` 应一致。

## 证据层级

| 层级 | 含义 | 可支持的结论 |
| --- | --- | --- |
| 初始证据 | 有代表性场景、评分维度、偏好锚点或历史任务依据，但尚未完成真实对比。 | `optimize`，可继续打磨或补测。 |
| 经验证据 | 已完成 with-skill / without-skill、old/new 对比、锚点保真或用户确认。用户确认只可作为偏好保真或人工验收证据；能力增益 retain 需要基线对比，或记录无法对比的免除原因。 | `retain` 或继续 `optimize`。 |
| 反证证据 | 证明无增益、误触发严重、相邻 Skill 可替代或成本高于收益。 | `retire` 信号，需人工确认后由工程系统处理。 |

## 能力增益判断

能力增益关注任务结果是否更好。

判断依据：

- 代表性 prompt 覆盖典型成功、边界/失败、反触发或真实历史任务。
- 对比对象明确：裸模型、普通提示、旧 Skill、相邻 Skill 或旧版本。
- 评分维度绑定用户目标和失败模式；评分量表为 1-5 分，5 分表示完全达成该维度。
- 每次 retain 判断至少覆盖 3 个代表性样本；少于 3 个时必须记录样本不足原因和免除依据。
- 原始 prompt、评分维度、逐样本分数和评审输出记录在对应 skill 的 `evals/` 目录。
- 记录上下文成本和维护成本。

常用信号：

- `retain`：`with_avg >= 4.0` 且 `uplift >= 1.0`，并且关键失败模式改善、上下文成本可接受；评分量表、样本和原始记录必须满足上方判断依据。
- `retire`：`uplift < 0.5` 时形成 `retire` 信号，先复核样本质量、替代路径和影响范围。
- 其他情况：优先 `optimize`，聚焦低分维度、误导项、误触发或成本。

## 偏好保真判断

偏好保真关注 Skill 是否忠实执行用户确认的方法。

判断依据：

- 偏好锚点来自用户确认的方法论、硬约束、流程选择或质量判断。
- 锚点数量适中，覆盖关键行为。
- 评测记录命中、遗漏、误触发和与用户当前意图的冲突。

常用信号：

- `fidelity >= 0.80` 且无关键锚点遗漏或误触发：可支持 `retain`。
- `0.60 <= fidelity < 0.80`：信号为 `optimize`。
- `fidelity < 0.60`：形成重写或 `retire` 信号，先复核锚点是否仍代表用户真实意图。

## 组合价值判断

`mixed` 同时看能力增益和偏好保真。`retain` 需要两侧证据同时成立。

同一组样本可同时记录能力评分和偏好锚点命中；without-skill 只用于能力 baseline。结论同时解释增益、保真、误触发和成本。

## 价值信号

| 信号 | 含义 | 使用条件 |
| --- | --- | --- |
| `retain` | 当前证据支持继续保留和维护。 | 运行质量无阻断问题；能力增益有基线对比或免除原因，偏好价值有用户确认或锚点保真证据。 |
| `optimize` | 值得继续打磨，但证据或质量仍不足。 | 初始证据就位、价值方向成立、但缺少实测或存在明显优化点。 |
| `retire` | 价值不足，进入移除讨论。 | 连续无增益、偏好失真、相邻能力可替代或成本明显高于收益。 |

## 有效性记录

当前兼容路径：`evals/lifecycle-review.json`。该文件记录最近一次有效性信号和证据。

记录字段：

```json
{
  "skill_name": "developer",
  "eval_type": "mixed",
  "review_date": "2026-04-28",
  "decision": "optimize",
  "evidence_refs": [
    "shared/skills/developer/SKILL.md",
    "shared/skills/developer/evals/evals.json"
  ],
  "next_action": "Run fixture-backed evals before claiming retain.",
  "capability_uplift": {
    "measurement_status": "needs_empirical_baseline",
    "with_avg": null,
    "without_avg": null,
    "uplift": null,
    "grader_dimensions": ["scope_control", "fresh_proof"]
  },
  "encoded_preference": {
    "measurement_status": "anchors_defined_needs_fidelity_run",
    "anchor_count": 6,
    "eval_count": 3,
    "fidelity": null
  }
}
```

字段原则：

- `decision` 只表达有效性信号：`retain`、`optimize` 或 `retire`。
- `next_action` 说明下一次真实评测、用户确认或工程处理动作。
- `capability_uplift.uplift` 表示 `with_avg - without_avg`，不另设并行增益字段。
- `encoded_preference.anchor_count` 与 `encoded_preference.eval_count` 表示当前 `evals.json` suite 规模；`sample_size`、`anchor_passed`、`anchor_total` 与 `summary_refs` 表示最近一次 empirical sample 证据，二者可以不同。
- `encoded_preference.fidelity` 表示应命中锚点的保真比例。
