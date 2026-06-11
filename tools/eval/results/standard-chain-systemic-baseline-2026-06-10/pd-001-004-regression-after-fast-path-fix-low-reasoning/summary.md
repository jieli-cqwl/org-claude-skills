# Standard-Chain Local Skill Eval

- total expectations: 25
- failed expectations: 2
- infra failures: 0
- pass rate: 0.92

## Runs
- product-director / director-baseline-no-prd: 7/7 passed
- product-director / partial-answer-stays-in-problem-clarification: 6/6 passed
- product-director / clear-goal-default-judgment: 7/7 passed
- product-director / upstream-fact-replacement-backtracks: 3/5 passed
  - failed: 判定新事实替换了问题澄清已闭合的根问题；回到问题澄清重新验证根问题判断，而不是停在范围收口继续划范围；目标、成功标准与投入边界、业务语义收口的结论可能因根问题变化需要重审。
  - failed: 说明目标、成功标准与投入边界、业务语义收口的结论可能需要重审

## Optimization Findings
- 对“静默信息收集”的表达偏隐含，没有直接说明这是在静默收集线索。 -> 可在开头明确写‘先做静默信息收集：仅记录线索，不视为事实’，证据会更强。
- PA-1 的“事实未闭合时不进入最终写入”主要靠未输出PRD来侧面证明，阻断条件可更明确。 -> 可补一句‘该事实未闭合前，不进入 Director baseline 最终写入’。
- “流程边界”中写“在你明确回复 `产品总监确认` 之前，这仍是候选基线，不是冻结结论”，略微增加流程门槛，容易让人感觉在等正式确认口令。 -> 改成“以下按 Director 推荐基线暂收；若你确认 SLA 口径不同，我再改基线”，保留单一待验证事实即可。
- 单一问题“是否以审批发起后超过业务 SLA 为准”是合格的，但没有显式说明这个事实为何会改变基线。 -> 补一句“如果逾期按节点 SLA 而不是整体 SLA 计算，提醒策略和成功口径会变化”，让问题与基线变化的因果更明确。
- 未明确指出‘目标’也可能因根问题变化而重审。 -> 补一句：‘如果真正根问题变成资金占用，产品目标要从降低差错率改为缩短对账/结算周期与释放占资。’
- 未明确指出‘业务语义收口’需要重审。 -> 补一句：‘“对账问题”这个语义要重定义，核心不再是准确性，而是时效性/资金周转。’
