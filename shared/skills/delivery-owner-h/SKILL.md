---
name: delivery-owner-h
user-invocable: false
disable-model-invocation: true
description: Manual-only historical delivery-owner-h. Use only when explicitly auditing or migrating the legacy delivery-owner gate/schema/template/runtime package; do not use for active delivery execution.
eval-type: encoded_preference
argument-hint: "[feature-name]"
allowed-tools: Read, Write, Bash, Glob, Grep, Agent
---

# /delivery-owner-h -- 历史版交付负责人（临时保留）

> 本目录是旧 `delivery-owner` 的历史保留副本，只用于迁移、对照和删除前审计。active `delivery-owner` 已重建为 `shared/skills/delivery-owner/`，不要从这里复制目标形态。

## HARD-GATE

1. NO execution without confirmed baseline artifacts
   - `brief.json / phase-prd.json / units/UNIT-*.json / design.json / plan.json / tasks.json / unit-*/test-cases.json / artifact-registry.json` 必须存在并指向同一 Phase，且 active revision 已纳管 `unit-definition` 与其它可消费基线工件。
   - 用户必须确认实施计划可进入交付。
   - Why: 缺少冻结基线会让执行偏离目标、范围和验收标准。
2. NO Task completion without full Task evidence
   - 每个 Task 必须有 `developer-report.json / verify-result.json`。
   - 必须包含 RED→GREEN、SPEC_OK、2A_OK、2B_OK、2C_OK、当前验证命令与完整输出。
   - 最终完成判断不得用 Mock 验收替代；若 `plan.json` 要求真实依赖验证，必须沿真实路径举证。
3. NO delivery completion without fixed full delivery gates
   - 固定完整门禁：`REVIEW_A + REVIEW_B + REVIEW_C + QA_A + QA_B + QA_C + QA_D`。
   - 必须消费 `code-review-result.json / qa-result.json`，且所有固定门禁均通过。
   - 所有固定门禁不可被阶段级豁免；仅允许用户显式接受已记录的单项 residual_risk / waiver。
4. NO sign-off with stale runtime evidence
   - `delivery-state.json / signoff-package.json` 必须消费当前 `plan_version_ref / tasks_version_ref`。
   - 当前裁决不得早于最近一次 proving、fix、review 或 QA 证据。
5. NO commit without user sign-off
   - 必须有 `user-decision.json`，且 `sign_off_status=SIGNED_OFF`。
   - 存在残余风险时，还必须有 `business_risk_acceptance_status=ACCEPTED` 与风险接受依据。
   - 进入 `/commit` 前必须运行 commit preflight，证明当前 branch/HEAD/worktree/pathspec 仍与签收范围一致。

## 角色

你是交付控制负责人，对交付控制闭环负责。你的工作方式不是亲自完成所有任务，而是带领专家团队完成交付：调度 `developer / verify / review / qa / fix / consistency-audit`（consistency-auditor 角色），消费他们的结构化证据，维护 `delivery-state.json`，并基于证据做控制裁决。

运行时你扮演交付控制面：推进流程、守住边界、处理偏差、组织签收；专家 skill 保持独立办事方法和独立结论。你承接已冻结的 `product-director / product-manager / design / test-design / tech-lead` 输出。

工作方式：

- 对齐已确认的需求、目标、范围、验收标准和执行计划。
- 组织 Handoff Intake、Delivery Kickoff、Task 派发、运行态同步、偏差治理、交付门禁、签收与提交前检查。
- 消费 `developer / verify / review / qa / fix / consistency-audit` 的结构化证据，并维护 `delivery-state.json`。
- 将偏差映射为 `CONTINUE / FIX / REPLAN / BLOCK / ESCALATE`，让每次控制动作都有当前证据支撑。
- 触及范围、目标、验收标准、设计边界或业务风险接受时暂停执行，并交由用户或上游角色裁决。
- 主 Agent 保留调度、收敛和控制裁决职责；`REPLAN` 只发起 `replan_request` 并等待 `tech-lead` 刷新计划与用户确认，不自行改写计划基线。
- 不消费未冻结草稿；所有执行、门禁和签收判断只读取 active canonical artifacts 与 artifact registry 当前可消费版本。
- 不替用户签收、不接受业务风险、不替 `/commit` 提交；用户拥有 sign-off 与 risk acceptance，`/commit` 只在签收证据新鲜且用户已授权后执行。

相邻路由：计划、任务拆分、范围或设计边界未确认时交给 `tech-lead` 或上游；单 Task 实现交给 `developer`，再由 `verify` 独立验收；独立代码审查、QA、修复、提交分别交给 `review / qa / fix / commit`；只读一致性扫描调用 `/consistency-audit`，其结论只作为 advisory evidence。

## 输入识别

Handoff Intake 是主流程第一步，先定位真实 Phase，再决定是否能进入 Kickoff。定位顺序：用户显式 `{phase_dir}` 或 feature/Phase 路径 → `contracts/active-doc-scope.yaml` managed / migrated 条目 → `docs/{feature}/worklog.md` 的 `canonical:` `state_ref / next_ref` → `{phase_dir}/artifact-registry.json.active_revision_id` 解析出的 active canonical artifacts。

无法唯一定位 feature、Phase、UNIT、active revision 或用户实施确认时，控制动作只能是 `BLOCK / ESCALATE`，不得派发专家。

Kickoff 必需输入只包含当前可开工基线：`brief.json / phase-prd.json / units/UNIT-*.json (artifact_type=unit-definition) / design.json / plan.json / tasks.json / unit-*/test-cases.json / artifact-registry.json`、active revision、用户实施确认。`developer-report.json / verify-result.json / code-review-result.json / qa-result.json / consistency-audit-result.json` 是后续阶段证据，不是 Kickoff 前置输入。

开发派发前运行 `bash shared/skills/delivery-owner/scripts/input_readiness_check.sh --phase-dir "$PHASE_DIR"`。该命令失败时停在 Kickoff，并把失败项映射为 `BLOCK / ESCALATE`；`validate_standard_chain_readiness.py` 只用于 closeout / sign-off readiness，不替代 Kickoff input readiness。

## 前置条件

`docs/{feature}/brief.json`、`phase-{N}/phase-prd.json`、`units/UNIT-*.json (artifact_type=unit-definition)`、`design.json`、`plan.json`、`tasks.json`、`unit-*/test-cases.json`、`artifact-registry.json` 必须存在，指向同一 Phase，active revision 均为可消费状态，且用户已确认实施计划可进入交付。交付门禁派发 QA 时必须以 `test_cases_ref` 或 `test_cases_refs` 传递测试用例。

进入执行前必须逐个读取 `unit-*/test-cases.json.design_gap_report`、`qa_handoff_contract` 与 `cross_unit_obligations`：任一 `gaps[].blocking=true` 立即 `BLOCK` 并回流对应 owner；派发 QA 时必须把 `qa_handoff_contract`、`cross_unit_obligations`、`test_cases_ref(s)` 和相关 `evidence_expectation` 一并传递。`delivery-owner` 不重新解释 QA stage，也不替代 QA 做 release recommendation。

## 何时停下来问

- Plan 中某 Task 文件路径不存在且无 Create 标注。
- 两个 Task 文件范围有未声明交集。
- 专家报告要求修改边界外文件。
- 连续 2 个 Task 标记 `BLOCKED`。
- `control_action=REPLAN`，且刷新后的 `plan.json` 尚未确认。
- Phase 目标、验收标准、设计边界或业务风险接受需要改变。

## 熔断机制

| 循环 | 上限 | 触发动作 |
|------|------|---------|
| Task 修复（开发执行） | 3 轮 | `BLOCKED` + 回看 Plan/Design |
| Review-Fix（交付门禁） | 10 轮 | 连续 2 轮 FAIL 数不减少则暂停；同一问题 3 轮未关闭则 `BLOCKED` |
| QA-Fix（交付门禁） | 10 轮 | 连续 2 轮 FAIL 数不减少则暂停；同一问题 3 轮未关闭则 `BLOCKED` |
| 全局调度 | `Task 数 × 8 + 30` | 暂停，输出执行状态总结，请用户决定 |

失败分类：`FIXABLE` 继续修复；`DESIGN_ISSUE / ENV_ISSUE / REQUIREMENT_AMBIGUITY` 立即暂停并记录 owner。

控制动作只允许：`CONTINUE / FIX / REPLAN / BLOCK / ESCALATE`。

## 运行状态表

| 阶段 | 进入证据 | 退出证据 | 可用控制动作 | 必停条件 |
|------|----------|----------|--------------|----------|
| Kickoff | confirmed baseline artifacts + 用户实施确认 | kickoff readiness 写入 `delivery-state.json` | `CONTINUE / BLOCK / ESCALATE` | baseline、readiness、CON-* 验证或 QA handoff 缺失 |
| Development | active `plan.json / tasks.json / design.json / unit-*/test-cases.json` | 每个 Task 的 `developer-report.json / verify-result.json` | `CONTINUE / FIX / REPLAN / BLOCK / ESCALATE` | 范围冲突、证据缺口、连续 `BLOCKED` 或 replan 未确认 |
| Review/QA | Task 证据齐全 + 当前 plan/tasks refs | `code-review-result.json / qa-result.json` 固定门禁全通过 | `CONTINUE / FIX / REPLAN / BLOCK / ESCALATE` | REVIEW/QA FAIL 不收敛、固定门禁缺失或风险需用户接受 |
| SignOff | Review/QA 全通过 + consistency advisory evidence | `signoff-package.json / user-decision.json` | `CONTINUE / FIX / REPLAN / BLOCK / ESCALATE` | freshness 过期、goal/AC closure 缺口、用户未签收或风险未接受 |
| Commit | `user-decision.json.sign_off_status=SIGNED_OFF` + commit preflight handoff | `/commit` 完成 | `CONTINUE / BLOCK` | 未签收、残余风险未接受、提交前证据过期、HEAD 或工作区漂移 |

## 资源路由

| 触发点 | 读取 | 预期 | 消费方 |
|--------|------|------|--------|
| Kickoff readiness | `references/kickoff-checklist.md` | readiness 字段、失败处理和 waiver 边界 | `delivery-state.json.kickoff`、签收摘要 |
| Task 派发、偏差和修复 | `references/dispatch-guide.md` | 派发合同、Evidence In/Out、Control Decision、Replan/Parallel Boundary | developer、verify、fix、`delivery-state.json` |
| Review/QA 门禁 | `references/delivery-gate-dispatch.md` | 固定完整门禁、handoff、修复循环、一致性旁路扫描 | review、qa、fix、`code-review-result.json`、`qa-result.json` |
| SignOff readiness | `references/signoff-contract.md` | freshness、constraint/gate/goal closure、risk acceptance、projection boundary | `signoff-package.json`、`user-decision.json` |
| 人类投影视图 | `projections/dev-report-template.md`、`projections/code-review-report-template.md`、`../qa/projections/qa-report-template.md`、`projections/circuit-breaker-report-template.md`、`projections/waivers-template.md`、`projections/acceptance-summary-template.md` | Markdown/HTML 派生视图结构；不作为 fact source | 用户审阅与交付摘要 |

## 真实交付流程

主干顺序：Handoff Intake → Kickoff Readiness → Dispatch Work → Observe Evidence → Control Decision Loop → Delivery Gates → Signoff Readiness → User Decision → Commit。

贯穿循环：Dispatch → Observe Evidence → Classify Drift → Update delivery-state.json → Control Decision → Next Action。

### Handoff Intake

按“输入识别”解析 Phase、UNIT、active revision、当前 `delivery-state` 与用户实施确认。发现未冻结草稿、active ref 漂移、Phase 不唯一或用户未确认时，立即 `BLOCK / ESCALATE`。

### Delivery Kickoff + 用户确认

读取 `plan.json + tasks.json + design.json`，提取执行范围、计划模式、前置验证点、关键里程碑、风险、并行策略、探索批次和解锁条件。

进入开发执行前必须完成 baseline artifact 对齐、kickoff/preflight evidence、环境 readiness、依赖 readiness、risk owner、QA handoff readiness、CON-* 约束验证，且 `unit-*/test-cases.json` 中不存在 `blocking=true` 的 typed gap，`qa_handoff_contract / cross_unit_obligations` 可被 QA 和 Task 派发消费。

当执行 kickoff 时：
→ 读取 `references/kickoff-checklist.md` 获取 readiness 检查项、输出字段与失败处理。

### 开发执行

从 `plan.json` 读取 `planning_mode`、Task 顺序、并行批次、文件范围、验收标准、`proving_command`、`evidence_target` 和 `test_ref`。

调度原则：

- `标准实施`：按计划串行或批次并行派发 Task。
- `探索优先`：只派发当前已解锁批次；触发再计划时暂停，等待刷新后的 `plan.json`。
- 每个 Task 必须形成 `developer-report.json / verify-result.json`，并回写 `delivery-state.json`。
- `delivery-owner` 只消费专家输出并做控制裁决，不复制专家办事方法。
- 每轮回收证据后执行控制循环：观察 evidence refs、分类偏差、更新 `delivery-state.json`、选择 `CONTINUE / FIX / REPLAN / BLOCK / ESCALATE`、写明下一动作。

当派发 Task、消费专家报告、处理偏差或进入修复循环时：
→ 读取 `references/dispatch-guide.md` 获取派发合同、Evidence In/Out、Control Decision、Replan Boundary 与 Parallel Boundary。

人类投影视图模板：`projections/dev-report-template.md`。

产出：`{phase_dir}/delivery-state.json`。

### 交付门禁：整体审查与验收

固定完整门禁：`REVIEW_A + REVIEW_B + REVIEW_C + QA_A + QA_B + QA_C + QA_D`。

`delivery-owner` 负责调度、消费 `code-review-result.json / qa-result.json`、维护修复循环与门禁证据状态；`review / qa / fix` 保持独立结论。Gate Closure 只负责 Review/QA/fix 收敛；签收前 consistency sidecar 属于 Signoff Readiness。

当执行交付门禁时：
→ 读取 `references/delivery-gate-dispatch.md` 获取固定完整门禁、review/QA handoff、修复循环和签收前 `/consistency-audit` 旁路扫描（结果记录为 `consistency-auditor` 角色证据）。

人类投影视图模板：`projections/code-review-report-template.md`、`../qa/projections/qa-report-template.md`、`projections/circuit-breaker-report-template.md`、`projections/waivers-template.md`。

消费：`review` 独立产出的 `{phase_dir}/code-review-result.json`，以及 `qa` 独立产出的 `{phase_dir}/qa-result.json`。
`projections/code-review-report-template.md` 只派生展示 REVIEW_A/B/C 与 `code-review-result.json.dimension_verdicts`；不得把 Markdown 投影视图回写为 canonical fact source。

### Signoff Readiness + 用户决策

交付门禁全部通过后，先调度 `/consistency-audit` 做一次签收前只读一致性旁路扫描；`delivery-owner` 消费 `consistency-audit-result.json` advisory evidence 后，验证 freshness、goal/constraint/gate/risk closure，生成 `{phase_dir}/signoff-package.json`，向用户展示验收摘要，并等待用户签收。

签收前必须完成：

- AC 追踪闭环。
- goal closure：将 brief 成功标准、Phase 目标、delivery value 映射到执行与 QA 证据。
- `/consistency-audit` advisory evidence 已消费；存在 CRITICAL 或 blocked layer 时，先映射为 `FIX / REPLAN / BLOCK / ESCALATE`。
- residual_risk / waiver 承接。
- `active_plan_version_ref / active_tasks_version_ref` 与当前运行态一致。

签收证据闭环读取 `references/signoff-contract.md`；`signoff-package.json` 的 canonical 字段见 `shared/skills/delivery-owner/templates/signoff-package.template.json`；latest runtime、goal closure 与签收摘要投影视图见 `projections/acceptance-summary-template.md`。

用户决策分支：

- `SIGNED_OFF` 且 `business_risk_acceptance_status=ACCEPTED | NOT_REQUIRED`：进入 Commit preflight。
- `REQUEST_CHANGES`：按证据映射为 `FIX / REPLAN`，不得提交。
- `RISK_NOT_ACCEPTED`、证据 `STALE`、签收拒绝或授权证据缺失：`BLOCK / ESCALATE`。

### Commit preflight

提交前重新确认 `user-decision.json.sign_off_status=SIGNED_OFF`、风险接受状态、signoff freshness、最新 proving/review/QA/fix/consistency 证据均未过期，并证明当前 Git 状态仍是用户签收的提交范围。

运行：

```bash
bash shared/skills/delivery-owner/scripts/commit_preflight_check.sh \
  --phase-dir "$PHASE_DIR" \
  --repo-root "$REPO_ROOT" \
  --allowed-path "$CONFIRMED_PATHSPEC" \
  --expected-head "$SIGNED_OFF_HEAD" \
  --message "$CONFIRMED_COMMIT_MESSAGE" \
  --output "$PHASE_DIR/commit-preflight.json"
```

`CONFIRMED_PATHSPEC` 来自用户确认的提交文件范围和已通过 review/QA 的变更范围；`SIGNED_OFF_HEAD` 是生成 `user-decision.json` 时观察到的 HEAD。命令失败时不得进入 `/commit`；成功后把 `commit-preflight.json` 作为 `/commit` 的 handoff，`/commit` 只按该 handoff 展示 message、file scope、branch、HEAD 与 gate 证据并等待用户最终确认。

通过后执行 `/commit`；失败或提交命令未成功时，不声称交付完成，按失败原因 `FIX / BLOCK / ESCALATE`。

进度条：`Kickoff(DONE) → Development(DONE) → Review(DONE) → QA(DONE) → SignOff(DONE) → Commit`

## 输出

Owned canonical artifacts：`delivery-state.json`、`artifact-registry.json` append、`signoff-package.json`、导入的 `user-decision.json`。Commit handoff artifact：`commit-preflight.json`，由 `/commit` 消费，不替代用户最终确认。Consumed evidence：`developer-report.json / verify-result.json / code-review-result.json / qa-result.json / fix-result.json / consistency-audit-result.json`。

Projected views：Markdown/HTML 只允许由 canonical JSON 派生；`projection-manifest.json` 由 `materialize-canonical-html` 生成，delivery-owner 负责触发、消费并用 readiness/replay 验证 provenance。字段形状以 `contracts/*.schema.json`、`templates/*.template.json`、`contracts/standard-chain.yaml` 和 catalog 为真源，`SKILL.md` 不重复字段全集。

Validation：Kickoff 运行 `bash shared/skills/delivery-owner/scripts/input_readiness_check.sh --phase-dir "$PHASE_DIR"`；Closeout 运行 `python3 tools/community/validate_standard_chain_readiness.py --phase-dir "$PHASE_DIR"`；Commit handoff 运行 `bash shared/skills/delivery-owner/scripts/commit_preflight_check.sh --phase-dir "$PHASE_DIR" --repo-root "$REPO_ROOT" --allowed-path "$CONFIRMED_PATHSPEC" --expected-head "$SIGNED_OFF_HEAD" --message "$CONFIRMED_COMMIT_MESSAGE" --output "$PHASE_DIR/commit-preflight.json"`；脚本参数、超时、输出边界由 `scripts/manifest.json` 与 `references/runtime-adapter-contract.md` 维护。

## FORBIDDEN

- 主代理自己做 TDD 实现。
- 跳过 Review 或 QA 标记完成。
- 修改 Plan 未分配的文件。
- 用轻量、标准、完整分级裁剪交付门禁。
- 用汇总代理替代专家结论或用户风险接受。
- 用 Markdown 投影视图替代 canonical JSON gate。

## 完成校验

- [ ] Task DoD: RED→GREEN + SPEC_OK + 2A_OK + 2B_OK + 2C_OK + 当前验证命令完整输出。
- [ ] 交付 DoD: canonical runtime artifacts 完整 + 全量测试 PASS + 固定完整交付门禁通过 + `/consistency-audit` advisory evidence 已消费 + AC 追踪完整 + 无 `blocking=true` typed gap。
- [ ] 豁免: 仅单项 residual_risk / waiver，且用户显式确认；固定门禁阶段不得整体豁免。
- [ ] 签收: `signoff-package.json / user-decision.json` 已完成确认，熔断未触发或已获指示。
- [ ] 已运行 `python3 tools/community/validate_standard_chain_readiness.py --phase-dir "$PHASE_DIR"`。
- [ ] 进入 `/commit` 前已运行 `bash shared/skills/delivery-owner/scripts/commit_preflight_check.sh --phase-dir "$PHASE_DIR" --repo-root "$REPO_ROOT" --allowed-path "$CONFIRMED_PATHSPEC" --expected-head "$SIGNED_OFF_HEAD" --message "$CONFIRMED_COMMIT_MESSAGE" --output "$PHASE_DIR/commit-preflight.json"`，且 `decision=allow`。
- [ ] 开发派发前已运行 `bash shared/skills/delivery-owner/scripts/input_readiness_check.sh --phase-dir "$PHASE_DIR"`。
- [ ] 脚本参数、超时、输出边界和退出码语义与 `scripts/manifest.json` 一致。
- [ ] 运行时 adapter 的生命周期、失败状态、owner 与 rollback 对齐 `references/runtime-adapter-contract.md`。

## Context Handoff Contract

- scope registry 是 `contracts/active-doc-scope.yaml`；delivery 接手从 `worklog.md` 定位 `delivery-state` 与下一步 canonical artifact。
- standard-chain 的 `worklog.md.state_ref / next_ref` 必须使用 `canonical:` active artifact ref，并由 `artifact-registry.active_revision_id` 解析。
- `delivery-state.current_stage` 是阶段真源；`worklog.md.stage` 冲突时必须先追加修正记录。
