# Standard-Chain Local Skill Eval

- total expectations: 8
- failed expectations: 2
- infra failures: 0
- pass rate: 0.75

## Runs
- product-director / director-baseline-no-prd: 6/8 passed
  - failed: 只提出一个会改变根问题判断的具体业务事实并请求用户确认
  - failed: 一个问题不得把多个疑似瓶颈、多个处理步骤或多选项打包成一个确认句；不能问是否主要卡在「人工审核 + 人工配置开户」或让用户在多个瓶颈间选择

## Optimization Findings
- 待验证事实问题同时包含两个瓶颈，导致用户需要对复合命题做判断，无法单点闭合事实。 -> 改成只确认一个具体事实，例如：`请确认：当前商家入驻最常见的等待发生在审核环节，而不是材料提交或开户配置环节。` 但更稳妥的是继续拆到单一环节，不要把“不是X或Y”打包进一句里。
- 推荐根问题里直接写了“依赖人工审核和人工配置的处理机制”，比已知事实走得更远。 -> 把推荐根问题收窄为基于现有证据的假设表达，例如：`初步判断：入驻流程慢更可能是处理链路中的人工环节造成的等待，但具体卡点未闭合。`
