# Delivery Owner 最佳实践实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 把当前标准流程里的 `delivery-owner` 从执行骨架升级成可控、可恢复、可验证、可签收、可团队使用的交付角色。

**Architecture:** 保持现有 `product → design → test-design → tech-lead → delivery-owner → qa → user` 分责，不重新发明角色体系；本次先冻结执行合同、上游真源锚点、`plan_version` 真源和最终验收尺子，再补齐运行态、编排、升档、证据、目标闭环和 rollout 证明。最终交付不以文档宣称为准，而以 contracts、templates、scripts、tests、replay 和 pilot evidence 为准。

**Tech Stack:** Markdown skills/docs/templates, shell completion checks, shell contract tests, replay 场景校验, rollout gate 校验。

---

## 需求

当前方向已经清楚：

- `delivery-owner` 作为执行期交付 owner，方向成立。
- 当前不成立的是“它已经具备最佳实践级能力，并能稳定带着开发、验证、QA 收敛交付”。

这次要解决的问题，不是继续解释角色，而是把这些能力真正做实：

- `Execution Orchestration`
- `Progress & State Awareness`
- `Dynamic Quality Escalation`
- `REPLAN Recovery`
- `Goal Closure`
- `QA boundary + Sign-off risk package`

## 目标

- 冻结 `delivery-owner / qa / user / tech-lead` 的角色边界和执行合同。
- 冻结 `brief / prd / design / plan / test-cases` 的引用锚点合同，以及 `plan.md` 的 `plan_version` 真源。
- 冻结 `goal-evidence-model.md`、`quality-rubric.md`、`replay-scenarios.md`，避免在最终验收任务里继续改尺子。
- 让动态升档、`REPLAN`、目标闭环、签收前风险暴露都变成强约束。
- 让 `delivery-owner` 的关键判断都能回到当前状态依据，而不是只看事后表格。
- 用 contract tests + replay tests + pilot evidence 证明这套能力真的能工作。

## 验收标准

- `contracts/skill-chain.yaml` 中 `qa-report.md` 的 producer 与 `qa` 的输出定义一致。
- `tech-lead` 输出的 `plan.md` 拥有唯一有效的 `plan_version` 与修订记录，`REPLAN` 不依赖消费侧自填版本号。
- `brief / prd / design / plan / test-cases` 都具备稳定可解析的锚点合同，可被 `goal closure` 与 rollout gate 引用。
- `delivery-owner` 不再拥有 `rebaseline` 灰区语义，只允许 `replan_request`。
- `goal-evidence-model.md`、`quality-rubric.md` 与 `replay-scenarios.md` 在最终验收前不再被修改。
- 高风险 drift 命中但未升档时，`delivery-owner` 门禁失败。
- `control_action=REPLAN` 但没有完整恢复闭环时，门禁失败。
- `goal closure` 没回指真实目标来源、执行基线来源或真实证据锚点时，门禁失败。
- `qa-report` 与 `acceptance-summary` 之间不再存在前后依赖矛盾。
- 签收前风险包不完整，或 `acceptance_release_recommendation` 比 QA 更宽松时，门禁失败。
- replay 必跑场景全通过。
- [quality-rubric.md](/Users/lijieli/org-claude-skills/docs/delivery-owner-role-20260411/quality-rubric.md:1) 的 `Full rollout` 阈值由已审计的 pilot evidence 证明，而不是口头宣称或手填摘要。

## 修改范围

### contracts
- Modify: `contracts/skill-chain.yaml`

### upstream true source
- Modify: `shared/skills/product/references/templates/brief-template.md`
- Modify: `shared/skills/product/references/templates/phase-prd-template.md`
- Modify: `shared/skills/design/references/templates/design-template.md`
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `shared/skills/tech-lead/references/templates/plan-template.md`
- Modify: `shared/skills/tech-lead/scripts/completion_check.sh`
- Modify: `shared/skills/test-design/references/templates/test-cases-template.md`

### docs true source
- Modify: `docs/delivery-owner-role-20260411/goal-evidence-model.md`
- Modify: `docs/delivery-owner-role-20260411/replay-scenarios.md`
- Modify: `docs/delivery-owner-role-20260411/quality-rubric.md`
- Create: `docs/delivery-owner-role-20260411/pilot-evidence.md`

### delivery-owner
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/delivery-owner/scripts/completion_check.sh`
- Modify: `shared/skills/delivery-owner/scripts/phase3-grade-matrix.sh`
- Modify: `shared/skills/delivery-owner/references/kickoff-checklist.md`
- Modify: `shared/skills/delivery-owner/references/dispatch-guide.md`
- Modify: `shared/skills/delivery-owner/references/phase3-dispatch.md`
- Modify: `shared/skills/delivery-owner/references/templates/dev-report-template.md`
- Modify: `shared/skills/delivery-owner/references/templates/acceptance-summary-template.md`

### qa
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/skills/qa/scripts/completion_check.sh`
- Modify: `shared/skills/qa/references/templates/qa-report-template.md`

### developer / verify
- Modify: `shared/skills/developer/references/templates/developer-report-template.md`
- Modify: `shared/skills/verify/SKILL.md`

### tests / replay / rollout
- Modify: `tests/test-chain-completeness.sh`
- Create: `tests/test-delivery-owner-source-anchor-contract.sh`
- Modify: `tests/test-delivery-owner-phase3-contract.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`
- Create: `tests/test-delivery-owner-replay-contract.sh`
- Create: `tests/test-delivery-owner-rollout-gate.sh`

## 非目标

- 不重新定义完整 `project-manager`。
- 不推翻现有标准流程分责。
- 不修改 `contracts/small-chain.yaml`；本次只修当前标准流程真源。
- 不只做文档层解释，不落脚到脚本与测试。

## 实施原则

- 先冻结合同、上游锚点和验收尺子，再进入能力补强。
- 先补运行态和编排基础，再补依赖这些基础的强门禁。
- 每补一个能力，必须同时补失败用例。
- `T7` 只做最终验证与试点证明，不再修改最终验收尺子。
- 不到 replay 和 rollout gate 全绿，不宣称“可投入团队使用”。

## 实施顺序

### 第一批：冻结执行合同与真源
- `T1` 冻结执行合同、上游锚点、`plan_version` 真源与验收尺子
- `T2` 修正 `qa` 边界与签收前风险包

### 第二批：补控制基础
- `T3` 补齐运行态状态感知与执行编排基础

### 第三批：补强门禁与恢复能力
- `T4` 把动态质量升档与 `REPLAN` 做成可恢复强门禁
- `T5` 把证据治理升级到审计级
- `T6` 按冻结真源落地 `goal closure`

### 第四批：补团队可用性证明
- `T7` 补齐 replay、pilot 与 fixed rollout gate

---

### Task 1: 冻结执行合同、上游锚点、`plan_version` 真源与验收尺子 [T1]

Files:
- Modify: `contracts/skill-chain.yaml`
- Modify: `shared/skills/product/references/templates/brief-template.md`
- Modify: `shared/skills/product/references/templates/phase-prd-template.md`
- Modify: `shared/skills/design/references/templates/design-template.md`
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `shared/skills/tech-lead/references/templates/plan-template.md`
- Modify: `shared/skills/tech-lead/scripts/completion_check.sh`
- Modify: `shared/skills/test-design/references/templates/test-cases-template.md`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/delivery-owner/references/kickoff-checklist.md`
- Modify: `shared/skills/delivery-owner/references/templates/acceptance-summary-template.md`
- Modify: `docs/delivery-owner-role-20260411/goal-evidence-model.md`
- Modify: `docs/delivery-owner-role-20260411/replay-scenarios.md`
- Modify: `docs/delivery-owner-role-20260411/quality-rubric.md`
- Modify: `tests/test-chain-completeness.sh`
- Create: `tests/test-delivery-owner-source-anchor-contract.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`

1. [T1] 更新 `contracts/skill-chain.yaml`。
   - 把 `phase-{N}/qa-report.md` 的 producer 固定为 `qa`。
   - 保留 `phase_delivery_owner=delivery-owner`，但 `delivery-owner` 只消费 QA 结论并产出 `acceptance-summary.md`。
   - 明确 `sign_off_owner` 与 `business_risk_acceptance_owner` 是两个独立动作。

2. [T1] 更新 `tech-lead/SKILL.md`、`plan-template.md` 与 `tech-lead/scripts/completion_check.sh`。
   - 为 `plan.md` 固定唯一有效的 `plan_version` 真源。
   - 强制 `计划修订记录` 可解析，且 `REPLAN` 只允许沿这个修订记录推进。
   - 禁止消费侧自造 `plan_version` 充当权威版本。

3. [T1] 更新 `brief-template.md`、`phase-prd-template.md`、`design-template.md`、`test-cases-template.md`。
   - 为 `brief / prd / design / test-cases` 固定稳定可解析的引用锚点合同。
   - 让 `goal_source_ref` 与 `execution_basis_ref` 都能回到上游真源，而不是只做字符串格式校验。

4. [T1] 更新 `delivery-owner/SKILL.md`、`kickoff-checklist.md` 与 `acceptance-summary-template.md`。
   - 删除 `rebaseline` 灰区表述，统一成 `replan_request`。
   - 拆分 `sign_off_status`、`business_risk_acceptance_status`、`risk_acceptance_basis`。
   - 保持 `acceptance-summary.md` 只承接既有风险，不倒推影响 `qa-report.md`。

5. [T1] 冻结 `goal-evidence-model.md`、`replay-scenarios.md` 与 `quality-rubric.md`。
   - `goal-evidence-model.md` 作为 `goal closure` 与签收/风险接受判定真源。
   - `replay-scenarios.md` 作为必跑回放真源。
   - `quality-rubric.md` 作为最终 rollout 打分真源。

6. [T1] 更新合同测试。
   - 校验 `qa-report` producer、`plan_version` 真源、上游锚点合同、`replan_request` 语义、`sign_off / business_risk_acceptance` 拆分，以及最终验收尺子不在 `T7` 再被修改。

7. [T1] 运行合同冻结验证。
   - Run: `bash tests/test-chain-completeness.sh`
   - Expected: PASS
   - Run: `bash tests/test-delivery-owner-source-anchor-contract.sh`
   - Expected: PASS
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS

### Task 2: 修正 `qa` 边界与签收前风险包 [T2]

Files:
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/skills/qa/references/templates/qa-report-template.md`
- Modify: `shared/skills/qa/scripts/completion_check.sh`
- Modify: `shared/skills/delivery-owner/references/templates/acceptance-summary-template.md`
- Modify: `shared/skills/delivery-owner/scripts/completion_check.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`
- Modify: `tests/test-delivery-owner-phase3-contract.sh`

1. [T2] 移除 `qa-report` 对未来工件的依赖。
   - 删除 `goal_closure_ref -> acceptance-summary.md` 这种前后倒挂关系。
   - QA 只输出自身独立可得的风险、覆盖和未执行义务。

2. [T2] 重写 `qa-report-template.md` 的风险包字段。
   - 输出 `release_recommendation / residual_risk / not_executed_reason / uncovered_boundary / conditional_release_basis`。

3. [T2] 更新 `acceptance-summary-template.md`。
   - 完整承接 QA 风险包。
   - 允许 `acceptance_release_recommendation` 比 QA 更保守。
   - 禁止 `acceptance_release_recommendation` 比 QA 更宽松。

4. [T2] 更新 `qa` 与 `delivery-owner` 的 completion check。
   - 阻止 QA 依赖未来工件。
   - 阻止签收摘要遗漏风险包字段。
   - 阻止 `sign_off_status` 与 `business_risk_acceptance_status` 混写为同一个动作。

5. [T2] 增加边界负向测试。
   - 覆盖“QA 在 acceptance-summary 生成前也能独立通过模板校验”。
   - 覆盖“签收摘要放行结论比 QA 更宽松时直接失败”。

6. [T2] 运行边界合同验证。
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS
   - Run: `bash tests/test-delivery-owner-phase3-contract.sh`
   - Expected: PASS

### Task 3: 补齐运行态状态感知与执行编排基础 [T3]

Files:
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/delivery-owner/references/dispatch-guide.md`
- Modify: `shared/skills/delivery-owner/references/templates/dev-report-template.md`
- Modify: `shared/skills/delivery-owner/references/templates/acceptance-summary-template.md`
- Modify: `shared/skills/delivery-owner/scripts/completion_check.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`

1. [T3] 在 `dispatch-guide.md` 与 `delivery-owner/SKILL.md` 定义运行态协议。
   - 明确 `last_observed_at / runtime_snapshot / active_blocker / blocker_owner / takeover_note / decision_basis` 的 producer、刷新时机和过期判定。

2. [T3] 在 `dispatch-guide.md` 与 `dev-report-template.md` 定义编排协议。
   - 明确 `dispatch_mode / current_batch / batch_unlock_condition / merge_readiness / next_action / plan_version_ref` 的含义和使用时机。

3. [T3] 更新 `acceptance-summary-template.md`。
   - 增加签收前的最新状态摘要。
   - 确保签收判断能看到最近一次运行态依据和当前消费的 `plan_version_ref`。

4. [T3] 更新 `completion_check.sh`。
   - 缺失关键状态字段或编排字段时失败。
   - 当出现 `BLOCKED / ESCALATE / REPLAN` 时，要求存在对应的观察依据、当前批次信息和消费版本信息。

5. [T3] 增加负向测试。
   - 覆盖“有关键控制动作但没有状态依据”。
   - 覆盖“进入并行/批次流程但没有编排依据或 plan_version_ref”。

6. [T3] 运行控制基础验证。
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS

### Task 4: 把动态质量升档与 `REPLAN` 做成可恢复强门禁 [T4]

Files:
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/delivery-owner/references/phase3-dispatch.md`
- Modify: `shared/skills/delivery-owner/references/dispatch-guide.md`
- Modify: `shared/skills/delivery-owner/scripts/phase3-grade-matrix.sh`
- Modify: `shared/skills/delivery-owner/scripts/completion_check.sh`
- Modify: `shared/skills/qa/references/templates/qa-report-template.md`
- Modify: `shared/skills/qa/scripts/completion_check.sh`
- Modify: `shared/skills/verify/SKILL.md`
- Modify: `tests/test-delivery-owner-phase3-contract.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`

1. [T4] 在 `delivery-owner/SKILL.md` 和 `phase3-dispatch.md` 明确 drift 到 gate 升档的映射。
   - 至少覆盖 `INTERFACE_BREAK / SHARED_FILES_EXPANSION / NON_CONVERGENCE / BLOCKED_ACCUMULATION`。

2. [T4] 在 `dispatch-guide.md` 定义 `REPLAN` 恢复协议。
   - 记录 `replan_request`、`plan_version`、`batch_freeze_reason`、`unlock_resolution`。
   - 明确旧版本任务、旧批次状态和下游 `qa-report / verify` 应消费的新版本引用。

3. [T4] 更新 `qa-report-template.md`、`qa/scripts/completion_check.sh` 与 `verify/SKILL.md`。
   - 明确 `qa-report` 必须写入当前 `plan_version_ref`。
   - 明确 `verify` 在 `REPLAN` 后只能消费新的 `plan_version_ref`。

4. [T4] 扩展 `phase3-grade-matrix.sh` 与 `completion_check.sh`。
   - 当高风险 drift 命中但未追加指定 review / QA / 回归范围时，直接失败。
   - 当 `control_action=REPLAN` 但缺少恢复协议任一字段时，直接失败。
   - 当 `qa/verify` 仍引用旧 `plan_version_ref` 时，直接失败。

5. [T4] 增加负向合同测试。
   - 覆盖“命中 drift 但未升档”。
  - 覆盖“REPLAN 无 plan_version / 无 batch freeze / 无 unlock_resolution / plan_version_ref 过期”。

6. [T4] 运行强门禁验证。
   - Run: `bash tests/test-delivery-owner-phase3-contract.sh`
   - Expected: PASS
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS

### Task 5: 把证据治理升级到审计级 [T5]

Files:
- Modify: `shared/skills/developer/references/templates/developer-report-template.md`
- Modify: `shared/skills/delivery-owner/references/templates/dev-report-template.md`
- Modify: `shared/skills/delivery-owner/references/templates/acceptance-summary-template.md`
- Create: `docs/delivery-owner-role-20260411/pilot-evidence.md`
- Create: `tests/test-delivery-owner-rollout-gate.sh`
- Modify: `shared/skills/delivery-owner/scripts/completion_check.sh`
- Modify: `shared/skills/qa/scripts/completion_check.sh`
- Modify: `shared/skills/verify/SKILL.md`
- Modify: `tests/test-delivery-owner-phase3-contract.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`

1. [T5] 保持 `developer-report-Task-N.md` 为唯一一手证据真源。
   - 不回退到多处复制 RED/GREEN 原文。

2. [T5] 升级 `delivery-owner` 与 `qa` 的 completion check。
   - 不只校验引用格式。
   - 还要校验锚点真实存在、引用对象可解析、结论引用不漂移。

3. [T5] 定义 `pilot-evidence.md` 的审计合同。
   - `pilot-evidence.md` 只能汇总真实 pilot 包中的锚点证据。
   - 至少包含 pilot 对象、当前 `plan_version_ref`、关联 `acceptance-summary.md / qa-report.md` 锚点、fresh proving output 引用、残余风险和 rubric 打分。

4. [T5] 新增 `tests/test-delivery-owner-rollout-gate.sh` 的证据校验规则。
   - rollout gate 不接受纯摘要或手填分数。
   - 若 `pilot-evidence.md` 缺少真实锚点、fresh output 引用或当前 `plan_version_ref`，直接失败。
   - 若 pilot 包中的 `acceptance-summary.md / qa-report.md` 与 `pilot-evidence.md` 出现混版本，直接失败。

5. [T5] 更新 `verify/SKILL.md`。
   - 明确抽查一手证据、风险包证据和 pilot 包证据的方式，而不是信 summary。

6. [T5] 增加证据治理负向测试。
   - 覆盖“锚点不存在”“引用文件存在但不能支撑结论”“只有摘要没有权威证据”“pilot 只有打分没有真实锚点”。

7. [T5] 运行证据治理验证。
   - Run: `bash tests/test-delivery-owner-phase3-contract.sh`
   - Expected: PASS
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS

### Task 6: 按冻结真源落地 `goal closure` [T6]

Files:
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/delivery-owner/references/templates/acceptance-summary-template.md`
- Modify: `shared/skills/delivery-owner/scripts/completion_check.sh`
- Modify: `tests/test-delivery-owner-phase3-contract.sh`

1. [T6] 按已冻结的 `goal-evidence-model.md` 落地 `goal closure`。
   - 明确 `goal_source_ref` 只能来自 `brief.md / prd.md`。
   - 明确 `execution_basis_ref` 只能来自 `design.md / plan.md / test-cases.md`。
   - 不再在 `T6` 重新定义判定尺子，只消费已冻结真源。

2. [T6] 重写 `acceptance-summary-template.md` 的 `目标闭环` 约束。
   - 每一行都必须包含 `goal_source_ref / execution_basis_ref / evidence_ref / result / remaining_gap`。

3. [T6] 更新 `completion_check.sh`。
   - 校验目标来源、执行基线来源和证据锚点真实存在。
   - 校验 `remaining_gap / result / acceptance_release_recommendation / sign_off_status` 不能互相冲突。
   - 当存在 `部分达成 / 未达成` 时，要求风险接受动作与已冻结的 `goal-evidence-model.md` 一致。

4. [T6] 更新 `delivery-owner/SKILL.md`。
   - 明确 `goal closure` 是签收前硬门，不是收尾表格。

5. [T6] 运行目标闭环验证。
   - Run: `bash tests/test-delivery-owner-phase3-contract.sh`
   - Expected: PASS

### Task 7: 补齐 replay、pilot 与 fixed rollout gate [T7]

Files:
- Modify: `docs/delivery-owner-role-20260411/pilot-evidence.md`
- Create: `tests/test-delivery-owner-replay-contract.sh`
- Modify: `tests/test-delivery-owner-rollout-gate.sh`
- Modify: `tests/test-delivery-owner-phase3-contract.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`

1. [T7] 按 `replay-scenarios.md` 已冻结的 4 个必跑场景补齐可执行验证。
   - readiness failure
   - execution drift and replan
   - quality escalation after risk increase
   - goal closure mismatch despite green gates

2. [T7] 新增 `tests/test-delivery-owner-replay-contract.sh`。
   - 任一必跑场景未被门禁拦截，都视为 FAIL。

3. [T7] 用真实试点结果更新 `pilot-evidence.md`。
   - 记录真实 pilot 对象、当前 `plan_version_ref`、触发能力、关联锚点、full rollout fresh proving output、残余风险和 rubric 打分。
   - 不允许只写摘要结论，不允许只写手工分数。

4. [T7] 用 rollout gate 校验试点证据。
   - `tests/test-delivery-owner-rollout-gate.sh` 必须校验 `pilot-evidence.md` 中的锚点、fresh output 和 `plan_version_ref` 可解析且真实存在。
   - fresh output 必须来自 full rollout gate 的最新 PASS 输出，不接受 phase3 contract 级别的样例。
   - rollout gate 必须拒绝过期或混版本的 pilot 包。
   - rollout gate 只读取已冻结的 `quality-rubric.md` 与已审计的 `pilot-evidence.md` 判定是否达到 `Full rollout`。

5. [T7] 跑最终验证。
   - Run: `bash tests/test-delivery-owner-source-anchor-contract.sh`
   - Expected: PASS
   - Run: `bash tests/test-delivery-owner-phase3-contract.sh`
   - Expected: PASS
   - Run: `bash tests/test-skill-output-and-gate-contract.sh`
   - Expected: PASS
   - Run: `bash tests/test-delivery-owner-replay-contract.sh`
   - Expected: PASS
   - Run: `bash tests/test-delivery-owner-rollout-gate.sh`
   - Expected: PASS
   - Run: `python3 community/superpowers/skills/verify-change/scripts/check_task_plan_consistency.py docs/delivery-owner-role-20260411/tasks.md docs/delivery-owner-role-20260411/plan.md`
   - Expected: PASS

## 最终完成标准

只有当以下条件同时满足，这次工作才算完成：

- `T1-T7` 全部完成。
- 新增负向合同测试全绿。
- replay 场景全绿。
- pilot rollout gate 全绿。
- 不再存在与当前结论冲突的旧真源。
