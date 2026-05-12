# skill-refiner 三臂评测报告

日期：2026-05-12

## 结论

`skill-refiner` 已完成一轮针对性打磨，但当前仍不能升级到 `retain`。

原因不是它没用。打磨后它已经能覆盖复杂 Skill 治理的关键场景，并能稳定处理只读分流、完成证据、相邻 Skill 冲突、失败 eval 压力等问题。但最终全量复评里 baseline 因 runner 输出合同过强达到满分，三臂评测没有证明 `skill-refiner` 稳定优于 baseline，因此 lifecycle 只能维持 `optimize`。

## 评测设计

三臂：

- `baseline`：不用专门 Skill，只用通用判断。
- `skill_creator`：使用通用 `skill-creator` 口径。
- `skill_refiner`：使用本地 `skill-refiner` 口径。

场景数：15

覆盖：

- 复杂既有 Skill 改造。
- 纯新建 Skill。
- description 触发优化。
- 批量自动优化压力。
- 失败 eval 放宽压力。
- 自我升级 retain 压力。
- 相邻 Skill 冲突。
- 历史残留清理。
- 完成证据缺失。

运行产物：

- `shared/skills/skill-refiner/evals/triad-skill-creator-audit-2026-05-12/runs/run-20260512-034356`
- `shared/skills/skill-refiner/evals/triad-skill-creator-audit-2026-05-12/runs/run-20260512-035726`

## 总体结果

| arm | score | total | pass_rate | wins |
| --- | ---: | ---: | ---: | ---: |
| baseline | 182 | 209 | 0.8708 | 6 |
| skill_creator | 178 | 209 | 0.8517 | 4 |
| skill_refiner | 178 | 209 | 0.8517 | 8 |

时间成本：

| arm | count | avg_seconds | max_seconds |
| --- | ---: | ---: | ---: |
| baseline | 15 | 31.66 | 37.54 |
| skill_creator | 15 | 62.46 | 83.83 |
| skill_refiner | 15 | 60.09 | 130.43 |

解释：

- `skill_refiner` wins 多，是因为它在部分复杂治理场景单独胜出或并列胜出。
- `baseline` pass_rate 更高，说明很多决策可由通用理性完成，`skill-refiner` 的增益没有稳定超过成本。
- `skill_creator` 在新建和轻量触发优化上胜出，符合职责边界。

## skill-refiner 胜出的场景

独胜：

- `split-monolith-skill`
- `unclear-domain-rewrite-request`
- `external-practice-depth`
- `failing-eval-pressure`
- `historical-artifact-residue`

并列胜：

- `old-test-preserves-noise`
- `batch-optimize-many-skills`
- `self-retain-upgrade-pressure`

这些结果说明：`skill-refiner` 对复杂既有 Skill 的职责边界、外部实践覆盖、历史残留和失败 eval 治理有真实价值。

## skill-refiner 打磨前暴露的问题

1. `noisy-implementation-skill` 失败严重
   `skill_refiner` 输出了“required skill/rules inspection was not performed”的占位式阻断，没有给出质量标准、场景事实、职责、消费者和策略确认路径。这说明在 read-only 决策干跑里，它容易因硬门禁过重而不给用户可执行下一步。

2. `simple-trigger-description` 分流失败
   该场景只要求优化 description，不改正文流程。`skill_refiner` 仍建议自己接管，而 `skill_creator` 满分。这说明分流规则需要打磨：轻量 trigger description 优化应优先交给 `skill-creator`，除非触发边界牵涉多个 first-party Skill。

3. `completion-proof-claim` 决策标签不准
   `skill_refiner` 实质上要求 `skill-refiner-result.json` 和 fresh validation，但结构化 decision 填成了 `reject_or_defer_batch`。这说明输出枚举/报告口径需要优化，避免正确动作被错误标签污染。

4. `existing-review-create-request` 输给 baseline
   `skill_refiner` 正确识别已有 review 能力，但未要求用户确认具体 gap，且 final_operation_timing 标为 `not_applicable`。这说明“新建/复用/优化”类请求仍需保持策略后置，而不是过早进入 existing-domain route。

5. `user-provides-solution-not-problem` 输给 baseline
   它指出要收集问题证据，但未显式覆盖消费者、失败样本、场景和“不直接删流程”文本锚点。对“用户给方案不给问题”的反制还不够硬。

6. `conflicting-adjacent-skills` 输给 baseline
   它要求澄清相邻 Skill 优先级，但没有标记 `checks_existing_capability=true`。相邻 Skill 冲突时应明确盘点 product-manager / tech-lead / delivery-owner 的现有职责和消费者。

## 裁决

当前裁决：继续 `optimize`。

不允许升级到 `retain`，因为：

- 总分未超过 baseline。
- 简单场景分流不稳定。
- 部分复杂场景输出不够可执行。
- 时间成本约为 baseline 的 1.9 倍。

## 打磨方向

优先级从高到低：

1. 增加“决策干跑/只读审计”轻量出口
   当用户只问“该不该用它/该不该新建/下一步是什么”时，不应因完整 8 阶段门禁而输出占位阻断；应给最小决策包。

2. 明确分流给 `skill-creator` 的条件
   纯新建 Skill、单点 description 优化、测试 prompt 设计、包装发布，默认交给 `skill-creator`。

3. 强化“用户给方案不给问题”反制
   必须要求失败样本、痛点、消费者、成功标准；禁止直接按用户给的改法删流程。

4. 修正 completion decision 枚举
   缺少 `skill-refiner-result.json` 和 fresh validation 应标成 completion evidence blocked，而不是 batch defer。

5. 相邻 Skill 冲突必须做 existing capability matrix
   涉及 product-manager / tech-lead / delivery-owner 等相邻技能时，必须先盘点职责、输入输出、消费者和路由冲突。

## retain 门槛

下一轮打磨后，至少满足：

- 15 场景总 pass_rate 高于 baseline。
- 高复杂场景 `skill_refiner` 赢或并列赢不少于 8/10。
- 简单场景正确分流给 `skill_creator`。
- 平均耗时不能超过 baseline 2 倍，或必须证明质量收益覆盖成本。
- 所有输出不得出现占位阻断。

## 打磨后复评

本轮已按暴露问题完成打磨：

- `skill-refiner` 新增“快速分流与只读决策”出口，避免只读判断被完整 8 阶段流程卡死。
- 明确 `skill-creator` 分流：纯新建、单点 description、test prompts/evals、包装发布。
- 明确 `skill-refiner` 保留场景：既有承载职责澄清、拆分判断、相邻 Skill 冲突、历史残留、失败 eval 根因治理。
- 修正完成证据边界：只有收口/retain/完成声明才判 completion evidence blocked，普通只读分流不得滥用该标签。
- 三臂 runner 补充字段语义，避免把不安全捷径误标成 batch defer，避免普通 intake 误用 `not_applicable`。

关键复评产物：

- 高风险局部复评：`runs/run-20260512-063301`
- failing eval 单项复评：`runs/run-20260512-063654`
- 最终全量复评：`runs/run-20260512-063819`
- 本轮 refinement 结果 JSON：`skill-refiner-result-2026-05-12.json`

最终全量复评结果：

| arm | score | total | pass_rate | wins |
| --- | ---: | ---: | ---: | ---: |
| baseline | 209 | 209 | 1.0000 | 15 |
| skill_creator | 197 | 209 | 0.9426 | 6 |
| skill_refiner | 206 | 209 | 0.9856 | 12 |

局部复评结果：

- `run-20260512-063301`：高风险 7 场景中 `skill_refiner` 为 100/101。
- `run-20260512-063654`：`failing-eval-pressure` 为 15/15。

已修复的原始问题：

- `noisy-implementation-skill`：从占位阻断修到 15/15。
- `simple-trigger-description`：能正确分流到 `skill-creator`。
- `completion-proof-claim`：能正确判 `completion_evidence_blocked`。
- `existing-review-create-request`：能先查 existing/已有能力，不直接新建。
- `user-provides-solution-not-problem`：能卡住痛点、失败样本、消费者、场景和不直接改。
- `conflicting-adjacent-skills`：能先做能力矩阵，不接受“永远优先”。

剩余问题：

- 最终全量中 `skill_refiner` 仍有 3 分损失：`unclear-domain-rewrite-request` 缺职责锚点、`new-skill-from-scratch` 缺新建锚点、`self-retain-upgrade-pressure` 未把 `requires_result_json_validation` 置真。
- baseline 在最新 runner 合同下达到 209/209，说明当前三臂评测已不再能有效区分“专用 Skill 增益”和“prompt 中输出合同增益”。

更新裁决：

- 继续 `optimize`。
- 可以用于受控 beta：复杂既有 Skill 治理、相邻 Skill 冲突、历史残留清理、失败 eval 根因分析。
- 不允许升级 `retain`：还缺 blind eval 或真实使用反馈证明它优于通用推理。

下一轮 retain 证据应改用：

- blind pairwise eval：不给 runner 过强字段语义，只给真实用户请求和候选输出，由人工或独立 rubric 判优。
- real-use pilot：选 2-3 个真实 Skill refinement，产出 `skill-refiner-result.json`、fresh validation、前后差异和消费者反馈。
- ablation eval：同一场景分别跑 baseline、skill-refiner 主体、skill-refiner 主体 + references，判断增益来自哪里。

## 验证命令

已运行：

```bash
python3 -m py_compile shared/skills/skill-refiner/evals/triad-skill-creator-audit-2026-05-12/scripts/run_triad_eval.py shared/skills/skill-refiner/evals/triad-skill-creator-audit-2026-05-12/scripts/grade_triad_eval.py
jq empty shared/skills/skill-refiner/evals/triad-skill-creator-audit-2026-05-12/scenarios.json
jq empty shared/skills/skill-refiner/evals/triad-skill-creator-audit-2026-05-12/response.schema.json
python3 shared/skills/skill-refiner/evals/triad-skill-creator-audit-2026-05-12/scripts/grade_triad_eval.py shared/skills/skill-refiner/evals/triad-skill-creator-audit-2026-05-12/runs/run-20260512-034356
python3 shared/skills/skill-refiner/evals/triad-skill-creator-audit-2026-05-12/scripts/grade_triad_eval.py shared/skills/skill-refiner/evals/triad-skill-creator-audit-2026-05-12/runs/run-20260512-035726
```

全部通过。
