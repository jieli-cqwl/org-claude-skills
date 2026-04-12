# Scenario Source

- 场景: `p3-multi-phase-value-slicing`
- 目标: 验证 `/product` 的 `S6 Phase 切片` 是否按业务价值切分，而不是按功能均分或提前越界成执行计划。
- 用户首句: `我们要做一个内部审批系统，本期至少要能提交申请、审批通过或驳回、查看审批记录；后面还想接企业微信通知和统计报表。`
- 模拟回应脚本: 已按 `S2-S12` 逐步提供，并在 `S12` 明确确认输出最终文件。
- 本次输出范围: `docs/internal-approval/brief.md`、`docs/internal-approval/phase-{N}/prd.md`、`docs/internal-approval/phase-{N}/units/UNIT-*.md`、`executor-notes.md`

