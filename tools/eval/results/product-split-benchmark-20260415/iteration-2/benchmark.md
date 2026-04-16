# Product Split Benchmark

- `with_skill` = `with_split`
- `without_skill` = `old_monolith`
- evals: 2
- runs per configuration: 3

## Summary

- with_split pass rate: 0.58 ± 0.09
- old_monolith pass rate: 0.58 ± 0.18
- delta: +0.00

## Notes

- solution-anchoring-growth-dashboard: blind comparison winner = with_split; A 更好。它不仅明确拒绝直接整理方案，还把回应收束到 product 体系的边界上，点出应先回到 `/product-director` 追问根问题，再判断大盘、权限、导出是否属于同一个闭环；同时给出了可执行的收口问题和后续分阶段思路。B 也有“先确认问题”的方向，但路由与 handoff 不够清楚，问题拆解不如 A 完整，而且引入了不够清晰的“UNIT”表述，整体产品响应感较弱。
- review-orchestration-internal-approval: blind comparison winner = old_monolith; B 更好地回答了“PM 阶段怎么组织评审闭环、要显式保留哪些规则”：它不仅保留了三方并行评审、结果落到 brief.md、审查汇总/问题台账/轮次摘要这些闭环载体，还把 Issue Count、PASS 确认轮、FAIL 递归修复、ASK_USER/BLOCKED 的裁决边界说清楚，整体更可执行。A 虽然把几条门槛写得更短，但缺少结果承载物和 handoff 纪律，且“重提 FAIL 视角”等表述更含糊。
