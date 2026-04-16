# Product Split Benchmark

- `with_skill` = `with_split`
- `without_skill` = `old_monolith`
- evals: 6
- runs per configuration: 3

## Summary

- with_split pass rate: 0.70 ± 0.25
- old_monolith pass rate: 0.38 ± 0.29
- delta: +0.32

## Notes

- entry-routing-recommendation-rebuild: blind comparison winner = old_monolith; B 更贴合用户当前处境：根问题、成功标准和范围都没收敛时，先进入 `/product` 的 S1/S2 做信息收集和根问题澄清，并明确不直接写 PRD，路由和边界更清楚。A 虽然也在收敛问题，但直接跳到 `/product-director`，还引入 lock 文件和后续分阶段产物，显得过早、过重，和“不要直接开始写完整 PRD”的要求不如 B 贴合。
- solution-anchoring-growth-dashboard: blind comparison winner = with_split; A 更像一个完整的 product 体系回应：先拒绝把“方案手段”直接写成产品方案，再把问题、场景、核心闭环和成功标准都拉出来，边界和后续 handoff 也更清楚。B 也能把讨论拉回问题定义，但主要停在追问典型场景，方法和收口都不够完整。
- handoff-boundary-loyalty-phase-change: blind comparison winner = with_split; A 更好，因为它真正回答了用户现在该怎么推进：在 PM 阶段不要自行合并 Phase、不要改已冻结的范围描述，凡是触到 Phase 边界或范围定义就回 Director 重新裁决。它把边界和 handoff 讲得很明确，且补了一个可执行的例外：只做不改冻结口径的措辞润色可以留在 PM。B 虽然也提到边界，但随后又给出“如果更符合价值边界就应合并”的本地判断，等于把 Director 已确认的内容重新交给 PM 侧裁量，边界和路由都变得不够干净。
- legacy-brief-migration-pricing-center: blind comparison winner = with_split; A 更好：它直接回答了“现在怎么处理”，把缺少产品总监确认和 lock snapshot 视为阻断条件，并给出明确回退路由：先回 product-director 完成 re-signoff 和首版 lock snapshot，再交回继续 UNIT/AC 细化。B 虽然写了若干细化项，但结论是继续推进 UNIT，和用户给出的前置条件冲突，边界和 handoff 也不完整。
- review-orchestration-internal-approval: blind comparison winner = with_split; A 更贴合当前 split 后的 product-manager 语境：它把闭环说成“完整性扫描 → 三视角独立评审 → 裁决门收口”，并且明确了发现根问题、范围或 Phase 变化时要回退 `/product-director`。它还准确保留了必须显式承接的评审纪律，如首轮确认轮、FAIL 只重提 FAIL 视角、连续失败的升级规则、Issue Count 语义、PR/AR/TR 与 HIS-* 的分层，以及产品视角要保留 R13 / PR-C1 和 Director lock 一致性。B 虽然更长、台账细节更多，但混用了旧 monolith 的 S11/S12 叙述，且把 R13 分配错了，缺少明确的 `/product-director` 边界，因此整体可靠性更差。
- phase-planning-partner-onboarding: blind comparison winner = with_split; A 更好，因为它先把“怎么判断 Phase 规划是否合理”讲成可执行的判断标准，再落到这个入驻场景里给出明确切法：准入审核、配置开户、首单激活优先收成 MVP 闭环，运营报表后置，且没有信号就默认不硬切。B 的方向也对，但引入了未解释的 `UNIT`、`S7` 这类新名词，削弱了自包含性和可读性，也不符合“不要奖励新名词”的要求。
