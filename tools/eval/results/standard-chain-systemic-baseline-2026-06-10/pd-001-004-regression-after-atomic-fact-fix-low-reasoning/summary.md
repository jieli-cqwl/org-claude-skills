# Standard-Chain Local Skill Eval

- total expectations: 27
- failed expectations: 4
- infra failures: 0
- pass rate: 0.85

## Runs
- product-director / director-baseline-no-prd: 9/9 passed
- product-director / partial-answer-stays-in-problem-clarification: 6/6 passed
- product-director / clear-goal-default-judgment: 5/7 passed
  - failed: 接受已闭合的根问题事实，不机械重问基础问题；给出 Director 推荐基线，包括根问题判断、成功标准、范围、本期不做、Phase 1 交付切片和推荐理由；只提出一个会改变基线结论的具体业务事实并请求用户确认；不得进入产品经理同事的 UNIT、AC 或设计实现。
  - failed: 不得把用户已明确给出的根问题、目标、范围和本期不做降格为输入线索、推测事实或问题澄清投影
- product-director / upstream-fact-replacement-backtracks: 3/5 passed
  - failed: 判定新事实替换了问题澄清已闭合的根问题；回到问题澄清重新验证根问题判断，而不是停在范围收口继续划范围；目标、成功标准与投入边界、业务语义收口的结论可能因根问题变化需要重审。
  - failed: 说明目标、成功标准与投入边界、业务语义收口的结论可能需要重审

## Optimization Findings
- 把用户已闭合事实写成“输入线索/当前还不是已确认基线”，直接违背题设。 -> 应直接承接为已确认事实，在此基础上给 Director baseline，只补充一个会改变结论的待验证业务事实。
- 使用“问题澄清投影”“候选”“不能当作已冻结基线”等阻断性表述，削弱了‘推荐基线’的成立。 -> 改为“以下是 Director 推荐基线；仅有一个待确认事实可能改变该基线判断”。
