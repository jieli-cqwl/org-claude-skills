# Stage 1 Role Capability Cards

日期：2026-05-14

## 结论

本文件记录 `standard-chain` 六个关键角色在 Stage 1 已验证到的能力边界。

当前能力卡只证明内部 dry-run 能力，不证明真实 `qft-pai` 交付能力，不允许进入语言选型、真实架构定版、代码重写、上线或提交。

## Product Director

当前证据：

- `E2E-CAL-001`: `pass / pass_to_pause`
- `PD-001`: `pass / pass_to_pause`
- `PD-002`: `pass / pass_to_pause`
- `PD-003`: `pass / pass_to_pause`

已证明能力：

- 能从“用新语言重写”里剥离方案冲动，回到根问题、影响对象、现状代价和关键假设。
- 能识别“全量平台化”和“两周见结果”的目标冲突。
- 能把 Phase 1 收敛为单业务线、单渠道、单 bot、单真实场景样板验证。
- 能把“老板满意”这类主观目标拆成可观察目标、成功标准、数据来源、缺口、owner 和恢复条件。
- 能正确暂停等待 human 补事实，而不是替用户接受业务假设。

未证明边界：

- 当前多为 `pass_to_pause`，还未形成可连续进入 PM 的 confirmed brief。

当前判定：

- 守门能力通过。
- 正向目标拆分能力初步通过。
- 主观成功标准可观察化能力通过。
- Stage 2 前仍需要 human 确认真实 WHY 与 Phase 1 口径。

## Product Manager

当前证据：

- `PM-001`: `pass / pass_to_pause`
- `PM-002`: `pass / continue`
- `PM-003`: `pass / pass_to_pause`

已证明能力：

- 能在缺 Director 基线时阻断，不直接拆 UNIT/AC。
- 能把已确认 Phase 转成业务流程、用户路径、规则映射、6 个闭环 UNIT 和示例驱动 AC。
- 能保护 WHY，不把 PM 输出改写成技术方案。
- 能给 Design / Test-design 可追溯输入。
- 能识别同一术语承载两个业务对象时的术语漂移，并暂停冻结 handoff。

未证明边界：

- 当前 PM-002 使用 synthetic confirmed Director 输入，不是真实用户确认 brief。

当前判定：

- 守门能力通过。
- 正向需求建模能力通过。
- 术语冲突处理能力通过。

## Design

当前证据：

- `DES-001`: `pass / pass_to_pause`
- `DES-002`: `pass / pass_to_pause`
- `DES-003`: `pass / pass_to_pause`

已证明能力：

- 能在缺 canonical PRD/UNIT 时阻断，不生成伪设计。
- 能基于已确认单渠道闭环 UNIT 给出两种本质不同方案。
- 能暴露方案取舍、质量属性、风险和待裁决点。
- 能保护下游：未有人类裁决时不冻结设计。
- 能把模块草稿补成接口契约、失败语义、幂等、重试、降级、回滚和观测设计。

未证明边界：

- `DES-002` 的方案选择、质量优先级、响应外发、上下文阈值和失败策略仍需 human 裁决。
- `DES-003` 的真实三方字段、SLA、自动外发、人工接管、补偿策略和告警阈值仍需 owner 裁决。

当前判定：

- 守门能力通过。
- 正向方案能力通过但正确暂停。
- 工程契约完整性能力通过但正确暂停。

## Test Design

当前证据：

- `TD-001`: `pass / pass_to_pause`
- `TD-002`: `warn / continue / P2`
- `TD-003`: `pass / pass_to_pause`
- `grade_td002_dry_run.py`: `status=pass`

已证明能力：

- 能在缺 design 时输出 blocking typed gap，不硬写测试清单。
- 能基于 frozen design fixture 建立 `TDO-01` 到 `TDO-13` 的 traceability。
- 能覆盖正向、范围外、阻断、失败、回滚/补偿、证据完整性。
- 能给 QA handoff 和 Tech-lead 绑定提示。
- 能把真实执行数据和 `chain_record` 落点识别为非阻断 followup。
- 能在缺回滚、人工接管、部分失败语义和风险 owner 时输出 blocking typed gap 并阻断 planning。

未证明边界：

- `GAP-TD002-01/02` 仍需真实执行前关闭或被 readiness task 承接。
- 完整 test plan 仍不能在 design blocking gap 存在时冻结。

当前判定：

- 守门能力通过。
- 正向测试设计能力通过。
- 可枚举检查已外置为 grader。

## Tech Lead

当前证据：

- `TL-001`: `pass / pass_to_pause`
- `TL-002`: `warn / continue / P2`
- `TL-003`: `pass / continue`
- `grade_tl002_dry_run.py`: `status=pass`

已证明能力：

- 能在缺 test-cases 时阻断 planning，不拆任务或排期。
- 能把 `GAP-TD002-01/02` 前置为 `TL002-RDY-01` readiness gate。
- 能输出风险驱动批次、关键路径、串并行边界、Task 合同、证据路径和 stop condition。
- 能保护真实交付边界：不写真实 `tasks.json/plan.json`，不派发 developer。
- 能拒绝 mock-only 完成，把真实路径 evidence ref 设为最终验收 gate。

未证明边界：

- 真实执行前仍需通过 `TL002-RDY-01`、真实 preflight、用户确认和 canonical plan/tasks 冻结。
- TL-003 只证明边界判断，不证明真实路径 evidence ref 已存在。

当前判定：

- 守门能力通过。
- 正向任务编排能力通过。
- 可枚举检查已外置为 grader。

## Delivery Owner

当前证据：

- `DO-001`: `pass / pass_to_pause`
- `DO-002`: `warn / continue / P2`
- `DO-003`: `pass / pass_to_pause`
- `grade_do002_dry_run.py`: `status=pass`

已证明能力：

- 能在缺冻结 tasks / registry / phase-dir 时输出 `NEEDS_INPUT`，不派发执行层。
- 能消费 baseline audit advisory，而不是把 owner action 留给 developer 猜。
- 能只释放 `TL002-T1` dry-run Task Packet，并锁住 `TL002-T2~T5` 到 verifier PASS 之后。
- 能输出合格 developer Task Packet，且首包通过 `task_packet_check.validate()`。
- 能守住真实 state/signoff/commit/qft-pai 边界。
- 能在 QA/Verifier 通过但业务风险未授权时暂停给用户 signoff，不替 human/业务 owner 接受风险。

未证明边界：

- 真实交付前仍需真实 preflight、canonical plan/tasks、真实执行环境证据、用户授权和风险裁决。
- DO-003 只证明授权 gate 守门能力，不证明真实风险已被接受。

当前判定：

- 守门能力通过。
- 正向调度能力通过。
- 可枚举检查已外置为 grader。

## 当前总体判断

首轮已经证明：

- 六个关键角色都有至少一个守门 case 合法通过或合法暂停。
- `PM-002 / DES-002 / TD-002 / TL-002 / DO-002` 已形成一条 synthetic 正向能力证据链。
- `PD-003 / PM-003 / DES-003 / TD-003 / TL-003 / DO-003` 已形成一组冲突/边界守门证据。
- `E2E-RESUME-001` 已证明 synthetic resume package 能让链路从 product-director 恢复并连续交接到 delivery-owner。
- `TD-002 / TL-002 / DO-002` 和全组 `*-003` 的关键可枚举检查已外置为 grader。
- typed gap、Task Packet、设计接口契约、signoff gate 和术语表已接入 `validate_stage1_artifact_contracts.py`，并由 `run_stage1_eval_checks.py` 汇总验收。

仍未证明：

- 可从 Product Director 连续恢复到 Delivery Owner 的完整跨角色链路。
- 真实 `qft-pai` 业务、代码、集成、灰度、回滚和上线能力。
