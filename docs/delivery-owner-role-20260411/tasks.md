# Tasks — Delivery Owner 最佳实践实施计划
Created: 2026-04-12
Related plan: ./plan.md

## 需求

把当前标准流程里的 `delivery-owner`，从“有门禁、有模板的执行骨架”升级成“真正可控、可恢复、可验证、可签收、可团队使用”的交付角色。

这次工作不再讨论命名，不再继续抽象角色概念，只做一件事：

`把 delivery-owner 应具备的能力，逐项落成仓库里的真约束。`

## 目标

1. 先冻结标准流程的执行合同、上游真源锚点、`plan_version` 真源和最终验收尺子，避免边实施边改标准。
2. 把最弱的能力项做实：
   - `Execution Orchestration`
   - `Progress & State Awareness`
   - `Dynamic Quality Escalation`
   - `REPLAN Recovery`
   - `Goal Closure`
   - `QA boundary + Sign-off risk package`
3. 让关键能力都能被 `SKILL.md / template / script / test / replay / pilot evidence` 同时承接。
4. 让最终结论建立在真实验证和真实试点上，而不是文档表述上。

## 验收标准

- `contracts/skill-chain.yaml` 成为当前标准流程唯一角色/产物真源，`qa-report.md` 的 producer、`sign_off` 与 `business_risk_acceptance` 无冲突。
- `plan.md` 存在上游唯一有效的 `plan_version` 真源，`brief / prd / design / plan / test-cases` 都具备稳定可解析的引用锚点合同。
- `quality-rubric.md` 与 `replay-scenarios.md` 在实施早期冻结为验收输入，不允许在最终验收阶段继续改尺子。
- 命中高风险偏差但未升档时，门禁会失败。
- `control_action=REPLAN` 但缺少 `plan_version / replan_request / batch_freeze / unlock_resolution / consumer_version_ref` 任一关键闭环时，门禁会失败。
- `goal closure` 没有绑定真实目标来源、执行基线来源和真实证据时，门禁会失败。
- 签收前风险包不完整，或 `acceptance_release_recommendation` 比 QA 更宽松时，门禁会失败。
- replay 场景全部通过。
- 至少 1 次 pilot 交付证据达到 [quality-rubric.md](/Users/lijieli/org-claude-skills/docs/delivery-owner-role-20260411/quality-rubric.md) 的 `Full rollout` 阈值前，不宣称“可投入团队使用”。

## 修改范围

- contracts
  - `contracts/skill-chain.yaml`
- upstream true source
  - `shared/skills/product/references/templates/brief-template.md`
  - `shared/skills/product/references/templates/phase-prd-template.md`
  - `shared/skills/design/references/templates/design-template.md`
  - `shared/skills/tech-lead/SKILL.md`
  - `shared/skills/tech-lead/references/templates/plan-template.md`
  - `shared/skills/tech-lead/scripts/completion_check.sh`
  - `shared/skills/test-design/references/templates/test-cases-template.md`
- docs true source
  - `docs/delivery-owner-role-20260411/goal-evidence-model.md`
  - `docs/delivery-owner-role-20260411/replay-scenarios.md`
  - `docs/delivery-owner-role-20260411/quality-rubric.md`
  - `docs/delivery-owner-role-20260411/pilot-evidence.md`
- delivery-owner
  - `shared/skills/delivery-owner/SKILL.md`
  - `shared/skills/delivery-owner/scripts/completion_check.sh`
  - `shared/skills/delivery-owner/scripts/phase3-grade-matrix.sh`
  - `shared/skills/delivery-owner/references/kickoff-checklist.md`
  - `shared/skills/delivery-owner/references/dispatch-guide.md`
  - `shared/skills/delivery-owner/references/phase3-dispatch.md`
  - `shared/skills/delivery-owner/references/templates/dev-report-template.md`
  - `shared/skills/delivery-owner/references/templates/acceptance-summary-template.md`
- qa
  - `shared/skills/qa/SKILL.md`
  - `shared/skills/qa/scripts/completion_check.sh`
  - `shared/skills/qa/references/templates/qa-report-template.md`
- developer / verify
  - `shared/skills/developer/references/templates/developer-report-template.md`
  - `shared/skills/verify/SKILL.md`
- tests / replay / rollout
  - `tests/test-chain-completeness.sh`
  - `tests/test-delivery-owner-source-anchor-contract.sh`
  - `tests/test-delivery-owner-phase3-contract.sh`
  - `tests/test-skill-output-and-gate-contract.sh`
  - `tests/test-delivery-owner-replay-contract.sh`
  - `tests/test-delivery-owner-rollout-gate.sh`

## 非目标

- 不重新设计完整 `project-manager` 角色。
- 不推翻当前标准流程分责。
- 不修改 `contracts/small-chain.yaml`；本次只处理当前标准流程真源。
- 不只做文档润色。
- 不在没有脚本和测试承接的情况下引入新要求。

## Acceptance Checklist

- [ ] T1 冻结执行合同、角色边界与验收尺子
  - AC: `contracts/skill-chain.yaml` 明确 `qa-report.md` 唯一 producer 为 `qa`，`delivery-owner` 只消费并承接。
  - AC: `tech-lead` 产出的 `plan.md` 明确包含唯一有效的 `plan_version` 与修订记录，`REPLAN` 不再依赖消费侧自填版本号。
  - AC: `brief / prd / design / plan / test-cases` 的模板具备稳定可解析的引用锚点合同，可被 `goal closure` 和 rollout gate 消费。
  - AC: `delivery-owner` 只保留 `replan_request` 语义，不再出现 `rebaseline` 灰区。
  - AC: `acceptance-summary` 分离 `sign_off` 与 `business_risk_acceptance`，二者不再混成一个签收动作。
  - AC: `goal-evidence-model.md`、`quality-rubric.md` 与 `replay-scenarios.md` 被固定为最终验收输入，不再在最终验收任务里继续修改。
  - AC: `kickoff-checklist.md` 被纳入真源范围。

- [ ] T2 修正 `qa` 边界与签收前风险包
  - AC: `qa-report` 不再前置依赖尚未生成的 `acceptance-summary`。
  - AC: `qa-report` 独立输出 `release_recommendation / residual_risk / not_executed_reason / uncovered_boundary / conditional_release_basis`。
  - AC: `acceptance-summary` 完整承接 QA 风险包，并额外输出 `sign_off_status`、`business_risk_acceptance_status`、`risk_acceptance_basis`。
  - AC: `acceptance_release_recommendation` 允许比 QA 更保守，但不允许比 QA 更宽松。

- [ ] T3 补齐运行态状态感知与执行编排基础
  - AC: `dev-report` / `acceptance-summary` 至少包含 `last_observed_at / runtime_snapshot / active_blocker / blocker_owner / takeover_note / decision_basis`。
  - AC: `dev-report` 至少包含 `dispatch_mode / current_batch / batch_unlock_condition / merge_readiness / next_action / plan_version_ref`。
  - AC: 关键状态字段必须定义 producer、刷新时机和过期判定。
  - AC: 缺失关键运行态或编排证据时，门禁会失败。

- [ ] T4 把动态质量升档与 `REPLAN` 做成可恢复强门禁
  - AC: 命中高风险 `deviation_trigger` 时，必须追加指定 review / QA / 回归范围。
  - AC: `control_action=ESCALATE` 或高风险 drift 命中但未升档时，`completion_check` 直接失败。
  - AC: `control_action=REPLAN` 时，必须同时存在 `replan_request`、新的 `plan_version`、当前 batch 冻结记录、解锁结论和 `qa-report / verify` 消费版本引用。
  - AC: `REPLAN` 后旧批次与旧版本引用不会被继续当作有效执行基线。

- [ ] T5 把证据治理升级到审计级
  - AC: `developer_report_ref / evidence_target / qa` 相关引用都要校验锚点真实存在。
  - AC: 引用不仅“格式正确”，还必须能支撑当前结论。
  - AC: 一手证据唯一真源保持不变，重复搬运继续被压缩。
  - AC: `goal closure`、`release_recommendation`、`risk package`、`pilot-evidence` 引用到的证据都能被抽查命中。
  - AC: `pilot-evidence` 必须携带当前 `plan_version_ref`，且其引用到的 pilot 包证据不得出现混版本。

- [ ] T6 把 `goal closure` 做成真源绑定校验
  - AC: `goal closure` 中每一行都必须同时包含 `goal_source_ref / execution_basis_ref / evidence_ref / result / remaining_gap`。
  - AC: `goal_source_ref` 必须回指 `brief.md / prd.md`，`execution_basis_ref` 必须回指 `design.md / plan.md / test-cases.md`。
  - AC: `remaining_gap`、`goal result`、`acceptance_release_recommendation`、`sign_off_status` 之间不能自相矛盾。
  - AC: 存在 `部分达成 / 未达成` 时，签收与风险接受动作必须符合 `goal-evidence-model.md` 规则。

- [ ] T7 补齐 replay、pilot 与 fixed rollout gate
  - AC: 至少覆盖 4 个必跑场景：`readiness failure / execution drift and replan / quality escalation after risk increase / goal closure mismatch despite green gates`。
  - AC: `tests/test-delivery-owner-replay-contract.sh` 与 `tests/test-delivery-owner-rollout-gate.sh` 可执行，且任一必跑场景未被拦截都视为 FAIL。
  - AC: 最终只使用已冻结的 `quality-rubric.md` 打分，不再在 T7 修改 rubric。
  - AC: `pilot-evidence.md` 只能引用真实 pilot 包中的锚点证据和 fresh proving output，且必须绑定当前 `plan_version_ref`，不能只靠手填摘要过 gate。
  - AC: rollout gate 必须拒绝过期或混版本的 pilot 包。
  - AC: 至少 1 次 pilot 交付证据达到 `Full rollout` 阈值前，不宣称“可投入团队使用”。

## Definition of Done

All tasks checked, `tasks.md` 与 `plan.md` 一致性通过，相关 contract tests 全绿，replay 全绿，pilot rollout gate 全绿，且 `delivery-owner` 的关键能力已经从流程骨架升级成可执行真约束。
