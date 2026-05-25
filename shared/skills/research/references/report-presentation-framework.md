# 调研报告呈现框架

`/research` 不是单一模板生成器，而是同一套研究过程加不同首屏呈现路径。`research_mode` 决定怎么研究，`presentation_profile` 决定先让读者看到什么。

正式报告的底层顺序固定为 source targeting -> evidence qualification -> judgment -> audit；profile 只改变首屏呈现，不改变 Source Targeting Package、Evidence Qualification、Judgment Calibration 和 Decision Package 的先后关系。

## 使用边界

- 读取时机：`presentation_profile` 不清楚，或准备写正式 `research-report.md`。
- 允许动作：选择首屏结构、安排 Source Targeting Package、Evidence Qualification、Judgment Calibration、Decision Package、证据层和审计层的阅读顺序。
- 禁止动作：不得降低证据标准，不得跳过 Report Self-Review，不得跳过 User Confirmation Gate。
- 停止条件：读者、读后动作或留档要求不清楚时，只补这一个缺口；不要重问已明确的信息。

## 输出合同

本文件输出三个决定：

1. 使用哪个 profile：`decision`、`understanding` 或 `audit`。
2. 首屏先回答什么。
3. Source Targeting Package、Evidence Qualification、Judgment Calibration、Decision Package、审计层和用户确认如何收口。

正式报告完成前必须经过 Report Self-Review。正式报告完成后必须进入 User Confirmation Gate。用户未确认前，不得进入下游设计、计划、实现或相邻 skill。

## 四层阅读路径

所有 profile 都遵循同一信息分层，只是首屏落点不同：

1. 定位层：Source Targeting Package，证明资料/对象找对了。
2. 答案层：这次回答什么问题，当前判断是什么。
3. 判断层：Evidence Qualification、Judgment Calibration、决定性理由、最大风险、建议动作。
4. 证据层：深度分析、正反论证、项目适配、Decision Package。
5. 审计层：独立 challenge 记录、覆盖证明、项目上下文、证据索引。

## presentation_profile

### `decision`

- 适用问题：该不该选、值不值得做、现在怎么推进。
- 首屏重点：问题、当前判断、2-4 个决定性理由、最大风险、下一步。
- 常见误用：把 challenge 和覆盖证明堆到首屏，导致答案不突出。

### `understanding`

- 适用问题：这是什么、为什么重要、和相近对象差在哪。
- 首屏重点：对象定义、价值、核心机制、关键差异、适用边界。
- 常见误用：过早写推荐/不推荐，打断理解过程。

### `audit`

- 适用问题：为什么能定这个案、证据是否充分、还有哪些盲区。
- 首屏重点：当前判断、挑战表、覆盖证明、剩余盲区。
- 常见误用：把 `audit` 当成更高级版本，导致所有报告都变成审计文档。

## 默认路由

| research_mode | 默认 profile | 何时切换 |
| --- | --- | --- |
| `selection` | `decision` | 用户更想先搞懂概念时切到 `understanding` |
| `analysis` | `decision` 或 `understanding` | 是否采纳选 `decision`；先看懂观点选 `understanding` |
| `discovery` | `understanding` 或 `audit` | 定位对象选 `understanding`；证明命中/排除选 `audit` |

## 结构约束

- `decision`：下一步必须早于共享审计层；这不是证据豁免。
- `understanding`：这是什么、核心机制、适用边界必须在首屏区；不提前推荐。
- `audit`：当前判断、关键论点挑战表、覆盖证明摘要必须先于完整审计附录；audit 不是更高级版本。
- 所有 profile：权威来源都必须被拆成可验证论点。
- 所有正式报告：必须附共享审计层，完成 Report Self-Review，再等待用户确认。
