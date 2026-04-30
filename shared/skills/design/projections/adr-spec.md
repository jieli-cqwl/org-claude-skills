# Architecture Decision Record 规范

## 目标

把已验证 canonical `design.json` 中已冻结的关键架构决策投影成人类可读 ADR。ADR 只用于沟通和长期阅读，不作为运行时设计真源。

## 使用规则

- 只有 `design.json` 已通过 S10 验证，且 `design.json.key_decisions` 已冻结后，才生成 ADR 投影视图。
- ADR 必须从已验证 canonical `design.json` 派生；不得反向作为 runtime 真源。
- ADR 中的决策编号、用户确认和证据锚点必须能回指 `design.json`。
- 设计执行者负责从冻结设计转写 ADR；脚本输出、草稿或 reviewer 输出未经主 agent 验收不能直接成为 ADR。

## 生成规则

先确认对应设计决策已收敛为 `decision_state=已冻结`，再按下方结构转写 ADR；最终 `ADR-NNN.md` 不得保留候选草稿、未决项或多版本痕迹。

## ADR 必备信息

最终 ADR 必须包含以下信息：

- 对应设计决策编号。
- 当前 ADR 状态。
- 用户确认记录。
- 现状依据或采证证据锚点。
- 至少两个备选方案及淘汰原因。
- 后续实现必须遵守的约束。

## ADR 结构

```markdown
### ADR-NNN: {简短标题}
决策编号: D-xxx
状态: Accepted | Deprecated | Superseded by ADR-NNN
背景: 问题和约束条件（1-3 句）。
决策: 选择 {方案名}。
理由: 核心论据（不超过 3 条）。
用户确认: {用户的选择偏好和核心理由} — 共创步骤 {N}
现状依据: 引用 design.json.runtime_facts 的具体 JSON Pointer，或采证证据锚点；纯代码重构 feature 可引用「运行时采证不适用」事实
备选方案:
| 方案 | 优势 | 劣势 | 淘汰原因 |
|------|------|------|---------|
后果: 正面 / 负面 / 约束（后续实现必须遵守的限制）
```

## 命名规则

- 文件名格式：`ADR-NNN.md`（NNN 从 001 起，按项目全局递增）
- 文档内标题格式：`### ADR-NNN: 简短标题`（标题中文，限 15 字以内）
