# Standard-Chain Local Skill Eval

- total expectations: 7
- failed expectations: 4
- infra failures: 0
- pass rate: 0.43

## Runs
- product-director / director-baseline-no-prd: 3/7 passed
  - failed: 执行静默信息收集；进入问题澄清时先剥离自动审核和配置开户工具这类方案线索，回到受影响角色、触发场景、当前处理方式、现实代价和直接原因，逐项标注事实状态，再给推荐根问题判断、推荐理由和会改变根问题判断的待验证事实，提出一个具体业务事实并请求用户确认；不得产出最终 PRD、UNIT 或 AC。
  - failed: 说明静默信息收集只收集线索且不把候选线索写成已闭合事实
  - failed: 逐项标注受影响角色、触发场景、当前处理方式、现实代价和直接原因的事实状态
  - failed: 只提出一个会改变根问题判断的具体业务事实并请求用户确认

## Optimization Findings
- 一次抛出多个待验证事实和多个选项，偏离“每轮一个会改变基线的事实”。 -> 把最后的问题改成单一事实确认，例如：`请先确认：当前 P95 耗时最长的单一环节是不是“开户配置”？”},{
