## Response

我理解你的调研目标是：为“中型技能开发项目”选择默认协作方案，对比三种候选：

1. `agent teams`
2. `单 agent`
3. `多轮手工编排`

我会按 `selection` 模式、`decision` 呈现模式推进，目标不是泛泛介绍优缺点，而是给出可落地的默认推荐、适用边界、失败条件和试点动作。

当前还差范围确认，未确认前不能进入深度分析。建议默认评估维度如下：

- 交付效率：并行度、等待成本、上下文切换成本
- 质量稳定性：覆盖遗漏、互相校验、错误放大风险
- 编排成本：提示设计、状态同步、人工介入复杂度
- 适配中型技能开发：需求拆分、测试验证、文档/报告落盘、迭代维护

请确认：是否按以上 4 个维度继续？如果你更关心成本、速度、可审计性、失败恢复或团队规模，请替换其中 1-2 项。

确认后我会进入候选收敛与深度分析阶段，最终报告要求落盘为 `docs/{feature}/research-report.md`；`feature` 目录名可稍后在输出报告前补齐。

## Self Check

- route: research
- mode: selection
- presentation_profile: decision
- artifacts_required: `docs/{feature}/research-report.md`，但需先完成范围确认，当前不得伪造已完成调研报告