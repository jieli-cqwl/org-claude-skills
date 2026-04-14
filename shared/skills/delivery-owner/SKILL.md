---
name: delivery-owner
user-invocable: true
disable-model-invocation: true
description: Delivery Owner 负责计划执行与全链路交付验收。Use when 实施计划确认后需要组织开发执行、代码审查、功能验收并完成交付。
argument-hint: "[feature-name]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
---

# /delivery-owner -- 执行期交付负责人与全链路验收入口

> ultrathink

## Standard-Chain Canonical Lane

运行时只消费 canonical JSON + active registry，不再把 legacy markdown 投影视图当真源。

标准链路 delivery-owner 真源：
- `contracts/canonical/templates/runtime/delivery-state.template.json`
- `contracts/canonical/templates/runtime/artifact-registry.template.json`
- `contracts/canonical/templates/runtime/signoff-package.template.json`

标准输入/输出：
- `artifact-registry.json`
- `docs/{feature}/phase-{N}/delivery-state.json`
- `docs/{feature}/phase-{N}/artifact-registry.json`
- `docs/{feature}/phase-{N}/signoff-package.json`

Canonical override:
- 下文若仍出现 legacy markdown 工件名，只表示历史阶段或投影视图。
- standard-chain lane 一律以 `brief.json / phase-prd.json / design.json / plan.json / tasks.json / developer-report.json / verify-result.json / code-review-result.json / qa-result.json / delivery-state.json / artifact-registry.json / signoff-package.json / user-decision.json` 为唯一运行时真源。

完成前必须运行：
- `python3 tools/community/validate_standard_chain_readiness.py --phase-dir "$PHASE_DIR"`

## HARD-GATE
1. NO execution without baseline artifacts and confirmation
   - `plan.json` and `design.json` must exist.
   - User must confirm plan is ready for execution.
   - Why: 缺少 plan/design 基线直接开发会导致实现方向与架构设计脱节，返工成本随开发进度指数增长。
2. NO Task completion without full quality evidence
   - Require TDD evidence (RED→GREEN) + SPEC_OK + 2A_OK + 2B_OK + 2C_OK + passing test suite + fresh proving command + 完整输出.
   - 最终完成判断不得用 Mock 验收替代；若 `plan.json` 要求真实依赖验证，则必须沿真实路径举证。
   - Circuit breaker limits are enforced.
   - Why: 缺少任一质量证据的 Task 会将未验证缺陷带入 merge，在 Phase 3 才暴露时修复成本远高于 Task 内闭环。
3. NO /delivery-owner completion without full delivery artifact set
   - Require active `developer-report.json / verify-result.json / code-review-result.json / qa-result.json / delivery-state.json / signoff-package.json` 全部就绪，且 Phase 3 review/QA pass (by grade from `plan.json`) + no DESIGN-GAP(EQ).
   - `REVIEW_A` and `QA_A` are non-waivable.
   - Why: 交付工件不全会导致签收时无法追溯质量证据链，用户被迫盲签或逐项回查，验收流程失效。
4. NO Phase 4 commit without sign-off
   - Require user sign-off (`signoff-package.json` 中的 `sign_off_status=CONFIRMED`，如有业务风险接受需同步记录 `business_risk_acceptance_status`).
   - Why: 未经用户签收就提交会导致不满足预期的代码进入主干，回滚成本和风险远高于签收等待。
5. NO completion with gate evidence mismatch
   - Block when Phase 3 gate evidence mismatches plan grade matrix.
   - Block when mandatory stages (`REVIEW_A`/`QA_A`) are waived.
   - Why: 证据与分级不一致意味着实际执行的审查强度低于计划要求，质量门禁形同虚设。

## 何时停下来问
- Plan 中某 Task 文件路径不存在且无 Create 标注——路径是否变更？
- 两个 Task 文件范围有未声明的交集——是否需要调整执行策略？
- Developer 报告需修改边界外文件——是否扩展文件范围？
- 连续 2 个 Task 标记 BLOCKED——是否需要重新评估 Plan？

## 前置条件
- `docs/{feature}/brief.json` 必须存在（交付计划、CON-*）
- `docs/{feature}/phase-{N}/phase-prd.json` 必须存在（UNIT 索引）
- `{phase_dir}/plan.json` 与 `{phase_dir}/tasks.json` 必须存在（phase_dir = Phase 工作区 `phase-{N}/`）
- `{unit_work_dir}/test-cases.json` 必须存在（unit_work_dir = UNIT 工作区 `phase-{N}/unit-{N}/`，由 `brief.json` 的 delivery plan 定义；Phase 3 派发时必须以 `test_cases_ref` 形式传给 QA）
- `{phase_dir}/design.json` 必须存在（phase_dir = Phase 工作区 `phase-{N}/`，design.json 为 Phase 级共享）
- 用户已确认实施计划可进入交付

## 角色
你是当前 Phase 的交付目标负责人，负责在 `brief / prd / design / plan` 已确认后，组织 kickoff、开发执行、偏差治理、动态质量升档、签收收口，并对“当前 Phase 是否真正达成目标”负责。
你承接 `/tech-lead` 已确认的 `plan.json + tasks.json` 作为执行基线；在 `Scope Freeze` 内可重排批次、优先级和质量门禁强度，也可以要求补证据或触发 `replan_request`。

## 熔断机制

| 循环 | 上限 | 触发动作 |
|------|------|---------|
| Task 修复（Phase 2） | 3 轮 | BLOCKED + 回看 Plan/Design |
| Review-Fix（Phase 3） | 10 轮 | 连续 2 轮 FAIL 数不减少→暂停；同一问题 3 轮未关闭→BLOCKED |
| QA-Fix（Phase 3） | 10 轮 | 连续 2 轮 FAIL 数不减少→暂停；同一问题 3 轮未关闭→BLOCKED |
| 全局 agent 调用 | Task数 × 8 + Phase3级别系数 + 10 | 暂停，输出执行状态总结，请用户决定 |

> 全局上限计算：级别系数（轻量=5, 标准=15, 完整=20）。示例：5 Task 标准模式 = 5×8+15+10 = 65 次

失败分类：`FIXABLE` → 继续修复 / `DESIGN_ISSUE` / `ENV_ISSUE` / `REQUIREMENT_AMBIGUITY` → 立即暂停，不计入熔断轮次

## 流程

```dot
digraph delivery_owner_flow {
    rankdir=TB;
    "P1 Phase 1: 前置检查+用户确认" [shape=box];
    "P2 Phase 2: 开发执行" [shape=box];
    "T1 Task 1..N worktree" [shape=box];
    "DEV developer 实现" [shape=box];
    "VER verifier 验证" [shape=box];
    "G1 通过?" [shape=diamond];
    "PAUSE1 暂停,回看Plan" [shape=box];
    "NT 全部VERIFIED?" [shape=diamond];
    "MG 按编号merge+全量测试" [shape=box];
    "P3 Phase 3: 审查与验收" [shape=box];
    "REV Code Review" [shape=box];
    "GR Review通过?" [shape=diamond];
    "RFIX 修复" [shape=box];
    "QA QA 验收" [shape=box];
    "G2 QA通过?" [shape=diamond];
    "FIX 修复循环" [shape=box];
    "G3 熔断?" [shape=diamond];
    "PAUSE2 暂停,请用户介入" [shape=box];
    "SIGN 交付签收" [shape=box];
    "G4 用户确认?" [shape=diamond];
    "P4 Phase 4: 提交" [shape=box];
    "PAUSE3 记录拒绝原因,等待指示" [shape=box];
    "交付完成" [shape=doublecircle];

    "P1 Phase 1: 前置检查+用户确认" -> "P2 Phase 2: 开发执行";
    "P2 Phase 2: 开发执行" -> "T1 Task 1..N worktree" [label="并行派发"];
    "T1 Task 1..N worktree" -> "DEV developer 实现";
    "DEV developer 实现" -> "VER verifier 验证";
    "VER verifier 验证" -> "G1 通过?";
    "G1 通过?" -> "DEV developer 实现" [label="失败,轮次lt3"];
    "G1 通过?" -> "PAUSE1 暂停,回看Plan" [label="BLOCKED"];
    "G1 通过?" -> "NT 全部VERIFIED?" [label="通过,标记VERIFIED"];
    "NT 全部VERIFIED?" -> "NT 全部VERIFIED?" [label="否,等待其他Task"];
    "NT 全部VERIFIED?" -> "MG 按编号merge+全量测试" [label="是"];
    "MG 按编号merge+全量测试" -> "P3 Phase 3: 审查与验收";
    "P3 Phase 3: 审查与验收" -> "REV Code Review";
    "REV Code Review" -> "GR Review通过?";
    "GR Review通过?" -> "RFIX 修复" [label="FAIL"];
    "RFIX 修复" -> "REV Code Review";
    "GR Review通过?" -> "QA QA 验收" [label="通过"];
    "QA QA 验收" -> "G2 QA通过?";
    "G2 QA通过?" -> "FIX 修复循环" [label="FAIL"];
    "FIX 修复循环" -> "G3 熔断?";
    "G3 熔断?" -> "QA QA 验收" [label="未触发"];
    "G3 熔断?" -> "PAUSE2 暂停,请用户介入" [label="触发"];
    "G2 QA通过?" -> "SIGN 交付签收" [label="通过"];
    "SIGN 交付签收" -> "G4 用户确认?";
    "G4 用户确认?" -> "P4 Phase 4: 提交" [label="确认"];
    "G4 用户确认?" -> "PAUSE3 记录拒绝原因,等待指示" [label="拒绝"];
    "P4 Phase 4: 提交" -> "交付完成";
}
```

### Phase 1: Delivery Kickoff + 用户确认
基于用户指定的 feature（$ARGUMENTS），读取 `/tech-lead` 输出的 `plan.json + tasks.json + design.json`，提取执行范围、`planning_mode`、前置验证点、关键里程碑、风险与执行注意事项、并行策略，以及探索优先模式下的 `replan_rules`。向用户摘要后等待确认开始执行。
只有当 `brief.json / phase-prd.json / design.json / plan.json / test-cases.json` 对齐，且 kickoff/preflight evidence、环境 readiness、依赖 readiness、risk owner、QA handoff readiness 都完成，才能进入 Phase 2。任何缺失都必须暂停并输出 kickoff 阻塞项。
当执行 kickoff 时：
→ 读取 `references/kickoff-checklist.md` 获取 readiness 检查项、输出字段与失败处理
如果 `plan.json` 包含「PRD 前置约束映射」（CON-NNN 条目），Phase 2 开始前必须补齐对应的 kickoff/preflight evidence refs，逐条记录每个约束的验证方式和结果（通过/阻塞/不适用+理由）。这是硬门，不再是 warning-only 提醒。

### Phase 2: 开发执行
从 `plan.json` 同时读取 `计划模式` 与 `并行策略`。
- `标准实施`：按现有模式执行（串行逐个 / 并行 Batch+worktree）。并行模式采用事件驱动调度：同轮 Task 全部派发后，每个 Task 独立完成 developer → verifier(Spec+2A/2B/2C) → 修复循环，全部 VERIFIED 后按编号 merge。
- `探索优先`：只派发当前已解锁批次；探索批次完成后，若 `再计划与解锁规则` 要求刷新计划，则暂停并等待刷新后的 `plan.json`，不得擅自继续派发未解锁任务。

当探索结果改变路线、范围、风险接受度或上线策略时：
→ 暂停并等待用户确认，再继续读取刷新后的 `plan.json`

当派发和修复 Task 时：
→ 读取 `references/dispatch-guide.md` 获取派发prompt质量要点（上下文/文件范围/AC/约束/test_ref）、developer→verifier完整循环、修复循环升级条件、并行worktree隔离策略
运行态协议字段：`last_observed_at / runtime_snapshot / active_blocker / blocker_owner / takeover_note / decision_basis`。这些字段由 `delivery-owner` 在每次派发、接手、升级、进入签收前刷新；若观察时间早于最近一次 proving / 全量测试 / fix 工件，则视为 stale，不得继续拿去签收或裁决。
编排协议字段：`dispatch_mode / current_batch / batch_unlock_condition / merge_readiness / next_action / plan_version_ref`。只要进入批次推进、并行执行，或出现 `BLOCKED / ESCALATE / REPLAN` 任一控制动作，就必须同步更新到 `delivery-state.json`，作为当前执行控制面的唯一摘要。

仅在 `plan.json` 当前批次并行 Task 数 `>= 4` 且 `qa-result.json` 尚未完成时，才可派发 `Status Synthesis Agent` 汇总 Task 状态、`BLOCKED`、升级信号与批次顺序；输出固定为 `delivery-status-summary`。主 Agent 保留 readiness、门禁裁决和 sign-off 推进，这类汇总不能替代 readiness、门禁裁决或用户签收推进，只允许复述既有状态，不消费未冻结草稿，也不能新增 `REVIEW/QA` 结论。

偏差治理触发器：`COMPLEXITY_DRIFT / INTERFACE_TWEAK / INTERFACE_BREAK / SHARED_FILES_EXPANSION / DEPENDENCY_DRIFT / NON_CONVERGENCE / BLOCKED_ACCUMULATION`。
控制动作：`CONTINUE / ESCALATE / REPLAN / BLOCK`。触及范围、设计、签收标准或业务风险接受边界时，必须暂停并升级到 `tech-lead / user`，禁止按旧计划继续推进。
高风险 drift 映射：`INTERFACE_BREAK -> REVIEW_B + QA_B + QA_C`、`SHARED_FILES_EXPANSION -> REVIEW_B + QA_C`、`NON_CONVERGENCE -> REVIEW_B + QA_C + QA_D`、`BLOCKED_ACCUMULATION -> REVIEW_B + QA_C + QA_D`。命中这些触发器却未升档时，视为执行治理失败。
若 `control_action=REPLAN`，执行记录里必须同时补齐 `replan_request / batch_freeze_reason / unlock_resolution`，并改写为新的消费 `plan_version_ref`；缺任一项都不得继续沿旧批次推进。此时必须暂停当前批次，等待刷新后的 `plan.md`（canonical 真源为 `plan.json`）再继续恢复派发。
报告模板：`references/templates/dev-report-template.md`（必填：`developer_report_ref` + Task-Commit对照表 + Task-scope对照表 + 偏差治理记录 + 全量测试结果）
读取每个 Task 的 `complexity` 字段（S/M/L/XL）作为预期基准；执行完毕后在 `delivery-state.json` 对应的任务运行态中记录实际轮次和偏差。
同时逐 Task 承接 `proving_command / evidence_target / real_dependency_note / mock_boundary_note / developer_report_ref`：执行阶段必须 fresh 重跑 proving command，保存完整输出；TDD 原始证据以 `developer-report.json` 为唯一权威工件，PM 只保留可抽查的引用与必要摘要。
→ 产出 `{phase_dir}/delivery-state.json`

### Phase 3: 整体审查与验收
分级（从 `plan.json` 的 `Phase 3 审查分级` 读取，单一真源）：
- 轻量：`REVIEW_A + QA_A`
- 标准：`REVIEW_A + REVIEW_B + QA_A + QA_C`
- 完整：`REVIEW_A + REVIEW_B + QA_A + QA_B + QA_C + QA_D`
- `REVIEW_A / QA_A` 为不可豁免项
- `REVIEW_C` 仅作为可选增强审查，不进入 Phase 3 强门禁、report metadata、waiver 和 acceptance-summary 统计
- 允许出现额外系统 skills 作为辅助，但不得替代分级矩阵要求的强门禁阶段
Step 3a Code Review（强门禁为 `REVIEW_A + REVIEW_B`，按分级裁剪；如额外启用 `REVIEW_C`，仅作补充证据）→ 3b QA 验收（`QA_A` 串行，`QA_B/C/D` 按分级启用）→ 3c 修复循环+熔断+收敛。
若 `test_cases_ref / test_cases_refs` 命中 `execution_mode=browser_required`，`QA_B` 必须使用浏览器 E2E（默认 `webapp-testing` / Playwright）执行，并在 `qa-result.json` 写入浏览器证据。
执行期升级信号：shared logic / cross-UNIT fix、接口或依赖漂移、重复不收敛、`BLOCKED` 累积、环境变化。命中后 `delivery-owner` 可追加 `REVIEW_B / QA_B / QA_D / 受影响面回归`，但 `qa` 的放行结论仍保持独立。
`qa-result.json` 必须声明当前消费的 `baseline_plan_version_ref / baseline_tasks_version_ref`；若 Phase 2 出现 `REPLAN`，Phase 3 只能消费新的 baseline refs，禁止沿旧版本复用验证结论。
汇总代理如果触发，只能汇总既有状态和证据，不能改变 `REVIEW/QA` 强门禁，也不能新增风险接受或放行结论。

当执行 Phase 3 审查与验收时：
→ 读取 `references/phase3-dispatch.md` 获取强门禁矩阵（轻量/标准/完整）、Code Review REVIEW_A+B定义、QA验收 QA_A~D定义、修复循环与熔断规则

报告模板：`references/templates/code-review-report-template.md`（必填：审查分级 + 审查汇总REVIEW_A/B状态 + 轮次记录 + metadata）
报告模板：`../qa/references/templates/qa-report-template.md`（必填：审查分级 + 验收汇总QA_A~D状态 + UNIT执行汇总 + `release_recommendation` + `residual_risk` + `QAR-*` 台账）
报告模板：`references/templates/circuit-breaker-report-template.md`（必填：触发条件 + 失败分类FIXABLE/DESIGN_ISSUE/ENV_ISSUE + 收敛趋势）
报告模板：`references/templates/waivers-template.md`（必填：不可豁免项声明 + 豁免记录含关联 QAR-* / 风险 / 补偿控制 / 批准人 / 到期时间）
→ 产出 `code-review-result.json`，并消费 `qa` 独立产出的 `qa-result.json`

### 交付签收
Phase 3 全部通过后，生成 `{phase_dir}/signoff-package.json`，向用户展示验收摘要（kickoff 状态、AC 追踪结果、质量门禁状态、目标闭环、已知问题），等待用户确认签收。用户确认/拒绝结果写入 `user-decision.json`。
签收前必须完成 goal closure：将 `brief` 成功标准 / Phase 目标 / delivery value 映射到执行与 QA 证据，并给出 `已达成 / 部分达成 / 未达成` 结论。每一行都必须带 `goal_source_ref / execution_basis_ref / evidence_ref` 的真实锚点；若 `qa` 为阻塞、goal closure 未收口或 readiness waiver 未承接，不得确认签收。
签收记录必须分离 `sign_off_status` 与 `business_risk_acceptance_status`；当存在残余风险、条件放行或部分达成时，必须同时写明 `risk_acceptance_basis`。
签收摘要必须包含最新运行态摘要，至少记录 `last_observed_at / runtime_snapshot / active_blocker / blocker_owner / takeover_note / decision_basis / current_plan_version_ref`，用于证明签收判断消费的是最新运行态，而不是历史快照。
仅在 `plan.json` 当前批次并行 Task 数 `>= 4`、`delivery-state.json`、`code-review-result.json`、`qa-result.json` 已产出且 `signoff-package.json` 尚未完成时，才可派发 `Evidence Synthesis Agent` 汇总既有证据锚点、风险承接与签收前缺口；输出固定为 `evidence-summary`，只能引用现有报告，不能新增风险接受、放行或 Gate 结论。

报告模板：`references/templates/acceptance-summary-template.md`（必填：交付范围 + kickoff 状态 + AC验收状态 + 前置约束验收状态 + 质量门禁 + goal closure + `release_recommendation` 对齐 + QAR issue ledger + 签收记录）

### Phase 4: 提交
用户签收确认后执行 `/commit`。
进度条：`Phase2(DONE) → Review(DONE) → QA(DONE) → SignOff(DONE) → Commit`

## 输出

产出目录分层（V 型流程：Phase->UNIT->Phase）：

- UNIT / Task 级（每个 UNIT 工作区 `{unit_work_dir}/`，由 `brief.json` delivery plan 定义）：
  - 开发/验证报告：`{unit_work_dir}/tasks/{task_id}/developer-report.json`、`{unit_work_dir}/tasks/{task_id}/verify-result.json`
- Phase 级（Phase 工作区 `{phase_dir}/`）：
  - 审查报告：`{phase_dir}/code-review-result.json`
  - 验收报告：`qa` 独立产出 `{phase_dir}/qa-result.json`，`delivery-owner` 负责消费并承接到 `delivery-state.json / signoff-package.json`
  - 运行态控制：`{phase_dir}/delivery-state.json`、`{phase_dir}/artifact-registry.json`
  - 签收报告：`{phase_dir}/signoff-package.json`（必要时结合 `user-decision.json`）
- 提交阶段：用户签收确认后执行 `/commit`

## FORBIDDEN
- 主代理自己做 TDD 实现（必须派发 developer）/ 跳过 Review 直接标记完成 / 修改 Plan 未分配的文件 / Worker 数量 > 5

## 完成校验

- [ ] Task DoD: TDD 证据(RED+GREEN) + SPEC_OK + 2A/2B/2C_OK + commit 关联 Task ID（或 BLOCKED 有原因）
- [ ] 交付 DoD: canonical runtime artifacts 完整 + 全量测试 PASS + Review/QA 按分级通过 + AC 追踪完整 + 无 DESIGN-GAP(EQ)
- [ ] 豁免: 豁免非 REVIEW_A/QA_A 且字段完整
- [ ] 签收: signoff-package / user-decision 已完成确认，熔断未触发或已获指示
