# Skill 生命周期管理

> 触发条件：新 Skill 上线、模型升级、季度复审、退役候选处理时读取。

本文定义 first-party Skill 从上线到复审再到退役的生命周期治理闭环。生命周期决策必须引用 `{{RUNTIME_HOME}}/reference/Skill能力有效性标准.md`，不能只凭主观印象。

本文不是质量裁决标准，不向 `{{RUNTIME_HOME}}/reference/Skill质量标准.md` 追加维度。运行面质量按 `Skill质量标准.md` 裁决；生命周期管理只裁决上线、复审、优化和退役状态。

## Gate 1: 上线门禁

触发条件：新 Skill 上线前，或现有 Skill 被纳入标准流程链前。

检查内容：

- `SKILL.md` frontmatter 声明 `eval-type`。
- `evals/evals.json` 至少包含 3 个代表性场景，覆盖典型成功、边界/失败或反触发，以及真实历史任务或用户确认场景。
- `eval_type` 与 `eval-type` 匹配。
- `encoded_preference` 或 `mixed` 定义 5-10 个偏好锚点。
- `capability_uplift` 或 `mixed` 定义 `grader_dimensions`。
- 首次 `evals/lifecycle-review.json` 存在，至少能说明初始评审状态和下一次经验 eval。

不通过后果：

- 不允许上线或进入标准流程链。
- 缺少经验数据时结论只能是 `optimize`，不能写 `retain`。

## Gate 2: 模型升级触发

触发条件：Claude 或 Codex 依赖的大版本模型升级后，例如 Opus 4.N 到 4.N+1。

检查内容：

- `capability_uplift` 和 `mixed` Skill 复跑 with-skill / without-skill baseline。
- 比较 `with_avg`、`without_avg`、`uplift` 与上一轮记录。
- 记录上下文成本变化。

不通过后果：

- `uplift < 0.5` 只是退役信号；进入 `retire` 候选前必须确认样本质量、失败模式覆盖、上下文成本、替代路径和影响范围。
- 其他未达保留线的 Skill 标记为 `optimize`，要求补强低分维度或降低上下文成本。

## Gate 3: 定期复审

触发条件：按季度复审，或用户认为偏好已变化时。

检查内容：

- `encoded_preference` 和 `mixed` Skill 复跑偏好锚点保真度检测。
- 用户确认偏好锚点仍反映当前意图。
- 若锚点不再代表当前意图，先更新锚点和 eval，再重新评审。

不通过后果：

- 保真度低于 0.80 是 `optimize` 信号；先检查锚点有效性、误触发和样本代表性。
- 保真度低于 0.60 是重写或退役信号；进入退役候选前仍需人工确认替代路径和影响范围。

## Gate 4: 退役协议

触发条件：同一门禁类型连续两次评审不达标，或用户明确要求评估退役。

强约束：

- 退役始终需要人工确认。
- 不得自动删除或移动 Skill。
- 退役前必须列出影响范围、替代路径和回滚方式。

退役操作清单：

1. `SKILL.md` frontmatter 标记 `deprecated: true`。
2. 从 `contracts/standard-chain.yaml` 摘除对应标准链入口。
3. Skill 目录移至 `shared/skills/archive/` 或项目约定的归档位置。
4. 更新 runtime catalog、adapter、install 暴露、eval/lifecycle 记录和相关 changelog；不得为了退役单个 Skill 修改 `Skill质量标准.md`。
5. 在标准流程链文档或 changelog 中记录退役原因、证据和日期。

## 决策记录

每轮生命周期评审必须更新对应 Skill 的 `evals/lifecycle-review.json`：

- `decision`: `retain`、`optimize` 或 `retire`
- `decision_label`: `保留`、`优化` 或 `退役`
- `evidence_refs`: 指向 eval、review、grader、用户确认或退役记录
- `capability_uplift`: 仅适用于 `capability_uplift` / `mixed`
- `encoded_preference`: 仅适用于 `encoded_preference` / `mixed`
- `next_action`: 下一次运行或人工确认动作

## 不变量

- 生命周期治理只裁决上线、复审、优化和退役状态，不追加质量维度，不替换 D1-D8 运行面质量标准。
- `skill-creator` 不因本闭环被修改；它只作为 eval 执行能力被调用。
- `skill-harness` 保持只读审计性质；它只按 `Skill质量标准.md` 检查 D1-D8，不检查 `eval-type`，不读取 `lifecycle-review.json`，不执行退役。
- 没有经验数据时，不能把初始评审当作 retain 证据。
