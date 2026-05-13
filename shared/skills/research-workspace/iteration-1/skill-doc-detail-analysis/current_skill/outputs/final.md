## Response

我理解你的调研对象是这个观点：

> “技能文档越详细越好，步骤越多越稳。”

默认按 `analysis` 模式处理，呈现目标按 `understanding`：不是立刻给采纳建议，而是拆清楚它**何时成立、何时失效、失效机制是什么**。

范围我会收敛为 3 个挑战焦点：

1. 详细文档提升稳定性的成立条件：任务复杂、风险高、上下文易丢、执行者差异大。
2. 步骤增多导致失效的机制：认知负担、过拟合流程、冲突规则、维护成本、执行僵化。
3. 判断边界：什么信息必须写进技能，什么应交给代码、测试、schema、hook 或更小的专门 skill。

按当前 `research` 合同，这已经足够作为范围确认式复述；下一步应进入正式研究流程。但在正式报告完成前，不能声称调研完成。若要走完整 `/research`，最终需要落盘 `docs/{feature}/research-report.md`，并包含支持证据、反方挑战、失效条件和独立挑战记录。

## Self Check
- route: `research`；不路由 `deep-research`，因为用户没有要求 Deep Research / 深度研究 / 横纵分析 / Markdown + PDF 报告。
- mode: `analysis`
- presentation_profile: `understanding`
- artifacts_required: 正式完成需要 `docs/{feature}/research-report.md`；当前只是范围确认与研究启动，不产出完成报告。