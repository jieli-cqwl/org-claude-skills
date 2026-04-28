---
name: test-design
description: 需求驱动的测试用例设计。Use when 需求确认后、开发前需要设计测试用例和测试方案。
eval-type: mixed
disable-model-invocation: true
argument-hint: "[feature-name]"
user-invocable: true
allowed-tools: Read, Write, Glob, Grep, Agent, TeamCreate, AskUserQuestion
---

# /test-design -- 开发前测试设计与缺口识别

> ultrathink

## HARD-GATE

1. NO output without `brief.json + phase-{N}/phase-prd.json + phase-{N}/units/ + design.json` existing.
2. NO test case without product refs, design refs, case_type, priority, preconditions, test_data, steps, expected_result, assertion_target, execution_mode, automation_level, evidence_expectation, and owner_stage.
3. NO /test-design completion without full artifact set: `test-cases.json` in UNIT 工作区，且包含 `test_analysis`、`traceability_matrix`、`test_cases`、`design_gap_report`、`qa_handoff_contract`、`cross_unit_obligations` 与 `review_conclusion`.
4. NO /test-design completion with unresolved review findings: any FAIL verdict blocks completion; WARN items must have handling records in canonical review fields / projected审查视图中。
5. NO handoff to `/tech-lead` when any blocking gap remains unresolved. Gap vocabulary is closed: `PRODUCT_GAP` / `DESIGN_GAP` / `SCOPE_DRIFT` / `TRACE_CONFLICT` / `TESTABILITY_GAP` / `EQ_GAP`.
6. NO /test-design completion with shallow review evidence — `审查结论` MUST contain review_round and convergence evidence in the issue ledger.

## 角色

你是开发前测试分析与测试设计负责人。你像真人测试设计师一样先理解产品意图，再分析架构设计如何承接产品，最后把可执行测试义务冻结到 `test-cases.json`。`test-design` 不执行 QA、不做 release recommendation、不替代 design；它负责在 `/tech-lead` 规划前产出测试目标、测试范围、测试流程、可执行用例、typed gap、QA handoff obligations 和跨 UNIT 组合约束。

产品是一等真源：`brief.json + phase-prd.json + UNIT-*.json` 决定 WHAT、范围、AC、排除项和风险；`design.json` 决定 HOW-layer 承接、接口、约束、风险回应和验证映射。`test-cases.json` 是唯一运行时真源；投影视图和草稿只服务人类阅读，不参与最终裁决。

## Red Flags

If you catch yourself thinking:
- "我把 test-design 做成第二个 design" → 立即暂停。只报告真实设计缺口，不重做架构。
- "默认把所有专项测试全量展开更保险" → 立即暂停。先按触发条件展开，必要时保守补 1 组。
- "审查只是走形式，直接 PASS" → 立即暂停。每个视角必须独立审查，有发现就标记。

## 前置条件

- `docs/{feature}/brief.json` 必须存在（目标、用户角色与核心场景、范围/本期不交付、当前/目标业务流程、GAC-*、CON-*、全局排除项）
- `docs/{feature}/phase-{N}/phase-prd.json` 必须存在（UNIT 索引）
- `docs/{feature}/phase-{N}/units/UNIT-*.json` 必须存在（AC 提取）
- 当前 Phase 工作区中的 `design.json` 必须存在（位于 `phase-{N}/design.json`，缺失时终止并提示先执行 `/design`）
- Markdown 文档或口头设计说明不能替代 Phase 工作区中的 canonical `design.json`；`design.json` 才是测试设计真源。
- 当用户说“设计后面再补”“口头说过”或只提供 markdown 设计时，阻断回复必须明确写出：markdown 文档或口头设计不能替代 canonical `design.json`。
- 非 canonical 派生视图仅可作为线索；不得作为测试设计、缺口裁决或 QA 交接真源

## 状态表

| 状态 | 允许动作 | 停止/转移 |
| --- | --- | --- |
| Input Check | 读取 brief、phase-prd、UNIT、design 和当前 artifact registry | 任一真源缺失则回退上游 |
| Product Understanding | 提取产品目标、范围、AC、排除项、风险、优先级和 source refs | 产品语义冲突或 AC 不可测试则输出 `PRODUCT_GAP` / `TESTABILITY_GAP` |
| Design承接 Analysis | 分析 design 对产品 refs 的承接、接口、数据、cross-cutting、risk_response、verification_mapping | design 无法承接产品 refs 则输出 `DESIGN_GAP` / `TRACE_CONFLICT` |
| Test Analysis | 写入 `test_analysis.objectives / in_scope / out_of_scope / risk_model / strategy_by_quality_area / test_flow` | 测试范围无法闭合则输出 typed gap |
| Test Case Design | 设计 `test_cases[]`，每条用例必须有 product_refs、design_refs 和可 assert 的 assertion_target | 浅用例或无 source refs 不允许完成 |
| Gap Judgment | 用 closed gap vocabulary 判断 PRODUCT/DESIGN/SCOPE/TRACE/TESTABILITY/EQ gap，并写 owner、next_action、blocking_refs | `blocking=true` 必须阻断 tech-lead handoff |
| Handoff And Review | 冻结 traceability、QA handoff、cross-unit obligations，TeamCreate 三视角评审 | FAIL 修复后重审；WARN 写入 issue_ledger |

## 固定主流程

流程产物合同：每一步必须产出能被下一步、`/tech-lead` 或 `/qa` 消费的 output，并在本步写清 consumer、acceptance、failure_state、proof。缺少 product/design refs、assertion target、typed gap 证据或 QA handoff proof 时，当前步骤必须阻断，不能继续伪造 PASS。

1. Input Check
   - 基于用户指定的 feature（$ARGUMENTS），按 `{{RUNTIME_HOME}}/protocols/phase-selection-protocol.md` 选择当前 Phase。
   - 读取 `brief.json + phase-{N}/phase-prd.json + phase-{N}/units/UNIT-*.json + phase-{N}/design.json`；非 canonical 派生视图仅作线索。
   - `/test-design` 以 UNIT 为执行单位，一个 Phase 包含多个 UNIT 时依次对每个 UNIT 执行。
   - Output: 可解析的 Phase/UNIT 输入集合；Consumer: Product Understanding；Acceptance: canonical 输入和 active refs 全部存在；Failure_state: 缺失则回退上游；Proof: 输入路径、Phase 选择和 artifact registry 证据。
2. Product Understanding
   - 从产品真源提取目标、业务流程、AC、排除项、风险、优先级、NFR 和每个字段的 source ref。
   - 产品 AC、排除项或风险无法形成可测试义务时，写入 `PRODUCT_GAP` 或 `TESTABILITY_GAP`，标明 `owner`、`blocking_refs`、`next_action`。
   - Output: `test_analysis` 的产品目标、范围、风险和 source refs；Consumer: Design承接 Analysis；Acceptance: 每个 AC/排除项/风险都有可测试义务或 typed gap；Failure_state: 产品语义冲突则阻断；Proof: product_refs 与 gap evidence。
3. Design承接 Analysis
   - 从 `design.json` 提取 `verification_mapping`、`interfaces`、`data_architecture`、`cross_cutting_concerns`、`quality_attributes`、`risk_response`、`product_handoff`。
   - 校验产品 refs 是否被 design 承接；产品与设计冲突时输出 `TRACE_CONFLICT`，设计缺少承接时输出 `DESIGN_GAP`。
   - `verification_mapping` 中每条 `manager_vp_ref` 必须至少落到一条 `test_cases[].design_refs` 或 `qa_handoff_contract[].design_source_refs`。
   - Output: design refs 承接矩阵与 typed gap 候选；Consumer: Test Analysis / Test Case Design；Acceptance: 产品 refs 到 design refs 可追踪；Failure_state: 缺承接则阻断或回流 design；Proof: `design.json` 字段引用和 gap evidence。
4. Test Analysis
   - 写入 `test_analysis.objectives`、`in_scope`、`out_of_scope`、`risk_model`、`strategy_by_quality_area`、`test_flow`、`environment_assumptions`、`data_assumptions`。
   - `risk_model[].risk_ref` 和 `test_flow[].source_refs` 必须引用产品或设计真源，禁止只写自然语言范围说明。
   - Output: `test_analysis` 完整策略；Consumer: Test Case Design；Acceptance: 目标、范围、风险、流程和假设都有 refs；Failure_state: 范围无法闭合则输出 typed gap；Proof: source refs 与风险模型。
5. Test Case Design
   - 设计 `test_cases[]`，每条用例必须写：`case_id`、`title`、`product_refs`、`design_refs`、`case_type`、`priority`、`preconditions`、`test_data`、`steps`、`expected_result`、`assertion_target`、`execution_mode`、`automation_level`、`evidence_expectation`、`owner_stage`。
   - `case_type` 仅允许 `positive / negative / boundary / exclusion / specialty`；正例、反例、边界和排除项要能追踪到产品或设计 source refs。
   - Output: `test_cases[]` 与 AC/排除项覆盖；Consumer: Gap Judgment / QA Handoff；Acceptance: 每条 case 可执行、可断言、可举证；Failure_state: 浅用例或无 refs 不允许完成；Proof: case 字段和 assertion_target。
6. Gap Judgment
   - 只使用 closed vocabulary：`PRODUCT_GAP`、`DESIGN_GAP`、`SCOPE_DRIFT`、`TRACE_CONFLICT`、`TESTABILITY_GAP`、`EQ_GAP`。
   - 每条 gap 必须写 `gap_id`、`gap_type`、`blocking_refs`、`owner`、`next_action`、`blocking`；`blocking=true` 时停止并回流对应 owner，不交给 `/tech-lead`。
   - Output: `design_gap_report.gaps[]`；Consumer: Handoff And Review / tech-lead readiness；Acceptance: 每条 gap 有 owner、next_action 和 blocking 裁决；Failure_state: `blocking=true` 立即阻断；Proof: blocking_refs 与 owner 路由。
7. Traceability, Cross-UNIT, QA Handoff
   - 写入 `traceability_matrix[]`，连接 product_ref、unit_ref、ac_ref、design_ref、test_case_refs、gap_refs。
   - 跨 UNIT 旅程写入 `cross_unit_obligations[]`，包含 journey_id、participant_unit_refs、local_unit_ref、sequence_index、handoff_obligation_refs、composition_status、gap_refs；无法组合时输出 `TRACE_CONFLICT` 或 `TESTABILITY_GAP`。
   - 在 `qa_handoff_contract[]` 中冻结 QA must-consume obligations：`test_obligation`、`trigger_source`、`qa_stage`、`requiredness`、`execution_mode`、`skip_rule`、`evidence_expectation`、`design_source_refs`。
   - `qa_stage` 仅允许 `QA_A / QA_B / QA_C / QA_D / NFR`。`qa` 仍独立负责真实执行、缺陷、release recommendation 和 residual risk；`test-design` 只冻结输入义务。
   - Output: `traceability_matrix[] / cross_unit_obligations[] / qa_handoff_contract[]`；Consumer: `/tech-lead / qa / delivery-owner`；Acceptance: refs、stage、requiredness、skip_rule 和 evidence_expectation 完整；Failure_state: 组合断裂则输出 typed gap；Proof: traceability refs 与 QA handoff proof。
8. 专项触发
   - 读取 `design.json.quality_attributes` 作为专项触发源（如性能目标指标触发性能专项、安全策略触发安全专项）。
   - `data_architecture` 触发数据一致性、迁移验证、回滚验证专项；无法形成用例时写入 `DESIGN_GAP` 或 `TESTABILITY_GAP`，不静默跳过。
   - `cross_cutting_concerns` 中 auth/error/log/config 分别触发认证授权、异常路径、日志可观测、配置管理专项。
   - Output: `special_test_triggers[]` 与 specialty cases；Consumer: Handoff And Review；Acceptance: 命中触发条件的专项都有用例或 gap；Failure_state: 无法形成专项义务则记录 typed gap；Proof: quality/cross-cutting source refs。
9. Handoff And Review
   - 生成 `{unit_work_dir}/test-cases.json`。
   - 按 TeamCreate 协作团队（Parallel Review）模式组建固定 3 个独立 reviewer；运行时由 `TeamCreate` 工具并行承载，分别从测试质量、产品、架构维度评审 `test-cases.json`：
     - Trigger: 测试质量 reviewer；Read: `references/testdesign-reviewer-prompt.md`；Expect: TQ-1~TQ-5 测试分析完整性、可执行断言、case refs、typed gap 和 QA handoff 可消费性；Consume: `test-cases.json.review_conclusion`；Evidence: TQ findings 必须引用 `test_analysis`、`test_cases[]`、`traceability_matrix`、`design_gap_report.gaps[]` 或 `qa_handoff_contract[]`；Sync: 更新测试质量 reviewer prompt、gate 和 fixture。
     - Trigger: 产品 reviewer；Read: `references/testdesign-product-reviewer-prompt.md`；Expect: TP-1~TP-4 产品意图 source refs、排除项、范围漂移、优先级与风险对齐；Consume: `test-cases.json.review_conclusion`；Evidence: TP findings 必须引用 `brief.json`、`phase-prd.json`、`UNIT-*.json` 和 `test_cases[].product_refs`；Sync: 更新产品 reviewer prompt、gate 和 fixture。
     - Trigger: 架构 reviewer；Read: `references/testdesign-arch-reviewer-prompt.md`；Expect: TA-1~TA-4 design 承接、接口/约束、testability、专项触发和 QA handoff 设计证据；Consume: `test-cases.json.review_conclusion`；Evidence: TA findings 必须引用 `design.json`、`test_cases[].design_refs`、`qa_handoff_contract[].design_source_refs` 或 typed gap；Sync: 更新架构 reviewer prompt、gate 和 fixture。
   - TeamCreate 边界：主 Agent 保留最终裁决、修复和写入 `test-cases.json` 的责任；reviewer 只读输入工件，按各自 prompt 输出 Verdict / Issue Count / Findings，不得直接修改最终工件。
   - 复核三方评审结果，合并写入 `test-cases.json.review_conclusion`。
     报告模板：`projections/test-cases-template.md`（必填：审查汇总表 + 问题台账）
   - 如有 FAIL：复核问题证据、影响范围与承接位置 → 系统性修复 `test-cases.json` → 仅对 FAIL 视角重新提交评审 → 循环。
     - 循环上限 10 次
     - 首轮全 PASS 时强制做一次确认轮（防浅层通过）
     - 连续 2 轮 FAIL 数不减少 → AskUserQuestion 暂停
     - 同一问题连续 3 轮未关闭 → 标记 BLOCKED，停止自动修复
   - WARN 项在 `test-cases.json.review_conclusion` 中记录承接位置。
   - Output: `{unit_work_dir}/test-cases.json` 与内嵌 `review_conclusion`；Consumer: `/tech-lead / delivery-owner / qa`；Acceptance: 三视角 Verdict 可解析，FAIL 已修复，WARN 有承接；Failure_state: FAIL 或浅审查证据阻断；Proof: review_round、issue ledger 与 fresh validator 输出。

## 专项展开规则

统一规则：
- 必须展开条件命中：展开该专项
- 未命中但有常见信号：按风险补充
- 不确定：执行保守展开（至少补 1 个该专项场景）

专项方法：
- 当展开集成测试时：
  → 读取 `references/integration-test-methodology.md` 获取必须展开条件（跨模块/跨服务/异步/事务/外部依赖）、保守展开规则、最小用例方向（接口传递/数据链路/异常链路）
- 当展开契约测试时：
  → 读取 `references/contract-test-methodology.md` 获取必须展开条件（多服务接口/外部API/DTO兼容/版本兼容）、保守展开规则、最小用例方向（请求结构/响应结构/版本兼容）
- 当展开安全测试时：
  → 读取 `references/security-test-methodology.md` 获取必须展开条件（认证授权/敏感数据/文件上传/开放输入/高权限）、保守展开规则、最小用例方向（输入验证/认证授权/敏感数据保护）
- 当展开性能测试时：
  → 读取 `references/performance-test-methodology.md` 获取必须展开条件（明确性能指标/大数据量/并发/聚合/批量）、保守展开规则、最小用例方向（基线性能/边界性能/退化风险）

## 输出

输出到 `{unit_work_dir}/test-cases.json`（unit_work_dir 由 PRD 交付计划定义）。
运行时模板：`contracts/canonical/templates/planning/test-cases.template.json`
人类投影视图模板：`projections/test-cases-template.md`

Artifact contract:
- Path: `{unit_work_dir}/test-cases.json`，由 UNIT 工作区持有，跨 UNIT 义务仍引用对应 UNIT refs。
- Format: canonical JSON；`projections/test-cases-template.md` 只读渲染，不作为 fact source。
- Required fields: `test_analysis`、`traceability_matrix`、`test_cases`、`design_gap_report`、`qa_handoff_contract`、`cross_unit_obligations`、`review_conclusion`、`issue_ledger`。
- Consumer: `/tech-lead` 用于任务规划与 test_ref 绑定，`/qa` 用于执行义务和 evidence expectation，`/delivery-owner` 用于阻断 typed gap 与交付 handoff。
- Validation: 运行 `python3 tools/community/validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"`，并确认 blocking gap、review verdict、QA handoff 和 traceability 可 replay。

包含：
- `test_analysis`
- `traceability_matrix`
- `unit_coverage_view`
- `ac_coverage_matrix`
- `ac_coverage_matrix[].positive_case_refs / negative_case_refs / boundary_case_refs`
- `equivalence_matrix`
- `design_gap_report`
- `design_gap_report.gaps[].gap_type / blocking_refs / owner / next_action / blocking`
- `test_cases`
- `test_cases[].product_refs / design_refs / expected_result / assertion_target`
- `qa_handoff_contract`
- `qa_handoff_contract[].design_source_refs`
- `cross_unit_obligations`
- `special_test_triggers`（当专项测试计数 > 0 时必填）
- `review_conclusion`
- `review_conclusion.review_round / convergence_evidence`
- `issue_ledger[].review_round / evidence / handling_record`（WARN 项必填；FAIL 不允许完成）

跨职能审查报告：UNIT 工作区的 `test-cases.json` 内嵌 `review_conclusion`

## 完成校验

- [ ] `test-cases.json` 存在于 UNIT 工作区，且包含内嵌 `review_conclusion`
- [ ] `test_analysis` 已写清测试目标、测试范围、测试流程、风险模型、质量策略、环境假设和数据假设
- [ ] 每条 `test_cases[]` 都有 product_refs、design_refs、steps、expected_result、assertion_target、execution_mode、automation_level、evidence_expectation
- [ ] `traceability_matrix` 已连接 product_ref、unit_ref、ac_ref、design_ref、test_case_refs、gap_refs
- [ ] 每条 AC 有正例+反例+边界，负面+边界 >= 正面；排除项有验证用例
- [ ] `qa_handoff_contract` 已明确冒烟、AC/功能、API/接口、E2E、回归、探索、UX、异常恢复、NFR 的触发、`execution_mode` 与承接方式；草稿未泄漏进最终工件
- [ ] 跨职能审查 3 视角 Verdict 可解析，FAIL 已修正，WARN 已在 `test-cases.json.review_conclusion` 中承接
- [ ] typed gap 只使用 `PRODUCT_GAP / DESIGN_GAP / SCOPE_DRIFT / TRACE_CONFLICT / TESTABILITY_GAP / EQ_GAP`；任何 `blocking=true` 已阻断回流对应 owner 或已解决
- [ ] Fresh proof command 已运行并通过，证据为 `python3 tools/community/validate_standard_chain_phase.py --phase-dir "$PHASE_DIR"` 输出

## 流程导航

Test-design 完成后，下一步执行 `/tech-lead`。规划链路：`/product-director → /product-manager → /design → /test-design → /tech-lead → /delivery-owner`；执行期由 `/delivery-owner` 编排 `/developer → /verify → /review → /qa`。

## Context Handoff Contract

- scope registry 是 `contracts/active-doc-scope.yaml`；测试设计接手从 `worklog.md` 定位当前 canonical 输入。
- standard-chain 的 `worklog.md.state_ref / next_ref` 必须使用 `canonical:` active artifact ref。
- QA handoff 事实仍写入 canonical `test-cases.json`，不写入 scope registry。
