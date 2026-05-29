# test-cases projection

> 运行时真源为 `test-cases.json`；本文件只作为人类投影视图。

## 枚举标签映射

| canonical enum | 人类标签 |
|----------------|----------|
| `positive` | 正例 |
| `negative` | 反例 |
| `boundary` | 边界 |
| `exclusion` | 排除项验证 |
| `specialty` | 专项测试 |
| `PRODUCT_GAP` | 产品缺口 |
| `DESIGN_GAP` | 设计承接缺口 |
| `SCOPE_DRIFT` | 范围漂移 |
| `TRACE_CONFLICT` | 产品/设计追踪冲突 |
| `TESTABILITY_GAP` | 可测试性缺口 |
| `EQ_GAP` | 等价性缺口 |

展示可使用人类标签；写回 `test-cases.json` 时保留 canonical enum 原文。

## test_analysis / 测试分析

| 视图项 | JSON 来源 |
|--------|-----------|
| 风险模型 | `test_analysis.risk_model[]` |
| 质量策略 | `test_analysis.strategy_by_quality_area[]` |
| 测试流程 | `test_analysis.test_flow[]` |

## traceability_matrix / 追踪矩阵

| product_ref | unit_ref | ac_ref | design_ref | test_case_refs | gap_refs |
|-------------|----------|--------|------------|----------------|----------|
| brief.json#... | UNIT-1.json#... | UNIT-1.json#... | design.json#... | TC-1 | GAP-1 |

## 用例统计

| 类别 | 数量 |
|------|------|
| 正例 | N |
| 反例 | N |
| 边界 | N |
| 排除项验证 | N |
| 专项测试 | N |
| 合计 | N |

## ac_coverage_matrix / AC 覆盖矩阵

| UNIT | AC 编号 | AC 描述 | 用例编号 | 覆盖状态 |
|------|---------|---------|----------|----------|
| UNIT-1 | AC-U1-01 | ... | TC-U1-001, TC-U1-002, TC-U1-003 | COVERED |

## design_gap_report / Gap 报告

| gap_id | gap_type | blocking_refs | owner | required_artifact_ref | decision_needed | blocking |
|--------|----------|---------------|-------|-----------------------|-----------------|----------|
| GAP-001 | DESIGN_GAP | design.json#... | design | design.json#interfaces[0] | true | true |

无问题时展示：无 blocking typed gap。

## test_cases / 测试用例

### TC-U1-001: [用例标题]
- 关联 UNIT: UNIT-1
- product_refs: `UNIT-1.json#acceptance_criteria[0].ac_id`, `phase-prd.json#...`
- design_refs: `design.json#verification_mapping[0].manager_vp_ref`
- 类型: positive | negative | boundary | exclusion | specialty
- 优先级: P0 | P1 | P2 | P3
- 前置条件: [...]
- 测试数据: [...]
- 步骤: [...]
- 期望输出: [可 assert 的结果描述]
- assertion_target: [可验证断言目标]
- execution_mode: browser_required | non_browser_ok
- automation_level: manual | automatable | automated
- evidence_expectation: [期望证据]
- owner_stage: developer | verify | qa | nfr

## qa_handoff_contract / QA 交接契约

| obligation_id | obligation_type | trigger_refs | qa_stage | requiredness | execution_mode | skip_policy | evidence_contract_ref | design_source_refs |
|---------------|-----------------|--------------|----------|--------------|----------------|-------------|-----------------------|--------------------|
| QHO-SMOKE | RELEASE_READINESS | design.json#verification_mapping[0] | QA_A | REQUIRED | non_browser_ok | NOT_SKIPPABLE | artifact://qa-result/{feature}.phase-{N}.qa@active#smoke | design.json#verification_mapping[0].manager_vp_ref |
| QHO-E2E | BROWSER_FLOW | design.json#verification_mapping[0] | QA_B | REQUIRED/CONDITIONAL | browser_required / non_browser_ok | RECORD_NOT_EXECUTED_REASON | artifact://qa-result/{feature}.phase-{N}.qa@active#e2e | design.json#verification_mapping[0].manager_vp_ref |
| QHO-NFR | NFR | design.json#quality_attributes[0] | NFR | CONDITIONAL | non_browser_ok | RECORD_NOT_EXECUTED_REASON | artifact://qa-result/{feature}.phase-{N}.qa@active#nfr | design.json#quality_attributes[0] |

## cross_unit_obligations / 跨 UNIT 组合义务

| journey_id | participant_unit_refs | local_unit_ref | sequence_index | predecessor_case_refs | successor_case_refs | handoff_obligation_refs | composition_status | gap_refs |
|------------|-----------------------|----------------|----------------|-----------------------|---------------------|-------------------------|--------------------|----------|
| J-001 | UNIT-1.json#unit_id, UNIT-2.json#unit_id | UNIT-1.json#unit_id | 0 | [] | TC-U2-001 | QHO-E2E | COMPOSABLE | [] |

## special_test_triggers / 专项测试触发依据与展开策略

| trigger_id | trigger_type | source_ref | trigger_rule | threshold_ref | qa_stage | handling | backing refs |
|------------|--------------|------------|--------------|---------------|----------|----------|--------------|
| ST-001 | quality_attribute | design.json#quality_attributes[0] | QUALITY_ATTRIBUTE_REQUIRED | design.json#quality_attributes[0].target_metrics[0] | NFR | QA_HANDOFF | QHO-NFR |

## review_conclusion / 审查结论

| 字段 | JSON 来源 |
|------|-----------|
| reviewed_test_cases_digest | `review_conclusion.reviewed_test_cases_digest` |
| closure_status | `review_conclusion.closure_status` |

### reviewer_verdicts / 三视角 Verdict

| 视角 | perspective | Verdict | Issue Count | Review Round | reviewed_test_cases_digest | Evidence Refs |
|------|-------------|---------|-------------|--------------|----------------------------|---------------|
| 测试质量 | test_quality | PASS | 0 | R2 | sha256:<64 hex> | test-cases.json#review_conclusion.reviewed_test_cases_digest |
| 产品 | product | PASS | 0 | R2 | sha256:<64 hex> | test-cases.json#review_conclusion.reviewed_test_cases_digest |
| 架构 | architecture | PASS | 0 | R2 | sha256:<64 hex> | test-cases.json#review_conclusion.reviewed_test_cases_digest |

### issue_ledger / 审查问题台账

| Issue ID | Review Round | Status | Evidence Refs | Handling Action |
|----------|--------------|--------|---------------|-----------------|
| TQR-001 | R1 | CLOSED | artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#traceability-matrix | FIXED |

### convergence_evidence / 收敛轮次摘要

| 轮次 | 结果 | FAIL数 | 控制动作 | Evidence Refs |
|------|------|-------|----------|---------------|
| R1 | FAIL | 1 | CONTINUE | test-cases.json#review_conclusion.reviewer_verdicts |
| R2 | PASS | 0 | CONFIRMATION | test-cases.json#review_conclusion.reviewer_verdicts |
