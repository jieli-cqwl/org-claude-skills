# pilot-evidence.md

> 当前试点证据包。该文件只汇总已冻结、可抽查的真证据，不允许手填摘要替代锚点引用。

pilot_object: delivery-owner-T7-pilot
plan_version_ref: pilot/plan.md#计划版本
plan_version_value: v1
acceptance_summary_ref: pilot/acceptance-summary.md#发布建议对齐
qa_report_ref: pilot/qa-report.md#验收汇总
fresh_proving_output_ref: pilot/dev-report.md#fresh-proving-output-task-1
rubric_ref: quality-rubric.md#准入阈值
rubric_score: total=31; 角色边界=4; Kickoff=4; 偏差治理=4; 动态升档=4; 目标闭环=5; 证据卫生=5; 团队可用性=5
residual_risk_ref: pilot/acceptance-summary.md#residual-risk

## 审计规则

- `plan_version_ref` 与 `plan_version_value` 必须绑定当前试点消费的唯一执行基线。
- `acceptance_summary_ref / qa_report_ref / fresh_proving_output_ref / rubric_ref / residual_risk_ref` 都必须指向真实存在的文件与锚点。
- `acceptance-summary.md`、`qa-report.md`、`dev-report.md` 中声明的版本，必须与本文件 `plan_version_value` 一致。
- 出现混版本、过期版本或跨版本拼装的 pilot 包，直接拒绝。
- `fresh_proving_output_ref` 必须落在真实 fresh proving output 所在锚点块内，不能只指向同文件任意存在锚点。
- `rubric_ref` 必须落在冻结阈值所在锚点块内，不能只指向同文件任意存在锚点。
- `rubric_score` 只允许引用已冻结的 `quality-rubric.md` 打分结果；不得临时改尺子。
- `residual_risk_ref` 只能引用已冻结报告中的残余风险结论，不得在本文件重写一份新风险判断。

## Full Rollout 判定

- `total >= 30`
- 无单项低于 `4`
- 未命中混版本拒绝规则
- 所有引用都能被抽查命中
