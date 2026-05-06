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
| 测试目标 | `test_analysis.objectives[]` |
| 测试范围 | `test_analysis.in_scope[]` |
| 不测范围 | `test_analysis.out_of_scope[]` |
| 风险模型 | `test_analysis.risk_model[]` |
| 质量策略 | `test_analysis.strategy_by_quality_area[]` |
| 测试流程 | `test_analysis.test_flow[]` |
| 环境假设 | `test_analysis.environment_assumptions[]` |
| 数据假设 | `test_analysis.data_assumptions[]` |

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

## unit_coverage_view / UNIT 覆盖视图

| UNIT | 闭环目标 | 关联 AC | 用例编号 | 覆盖状态 |
|------|----------|---------|---------|---------|
| UNIT-1 | ... | AC-U1-01, AC-U1-02 | TC-U1-001, TC-U1-002 | COVERED |

## ac_coverage_matrix / AC 覆盖矩阵

| UNIT | AC 编号 | AC 描述 | 用例编号 | 覆盖状态 |
|------|---------|---------|----------|----------|
| UNIT-1 | AC-U1-01 | ... | TC-U1-001, TC-U1-002, TC-U1-003 | COVERED |

## equivalence_matrix / 等价性对照矩阵

| scope_item_id | 关联 AC | 关联 TC | 对照输入 | 不变量 | 结果状态 | 备注 |
|---------------|---------|---------|----------|--------|----------|------|
| SCOPE-P1U1-001 | AC-U1-01 | TC-U1-001, TC-U1-003 | [老/新输入对照] | [行为不变量] | EQ-COVERED | [证据链接] |

## design_gap_report / Gap 报告

| gap_id | gap_type | blocking_refs | owner | next_action | blocking |
|--------|----------|---------------|-------|-------------|----------|
| GAP-001 | DESIGN_GAP | design.json#... | design | 补齐接口约束 | true |

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

| obligation_id | test_obligation | trigger_source | qa_stage | requiredness | execution_mode | skip_rule | evidence_expectation | design_source_refs |
|---------------|-----------------|----------------|----------|--------------|----------------|-----------|----------------------|--------------------|
| QHO-SMOKE | 冒烟 | 默认强制 | QA_A | REQUIRED | non_browser_ok | 不可跳过 | 启动命令 + 健康检查 + 关键入口可用 | design.json#verification_mapping[0].manager_vp_ref |
| QHO-E2E | E2E | 核心用户旅程 / 跨 UNIT 数据流 / Web-H5 入口行为 | QA_B | REQUIRED/CONDITIONAL | browser_required / non_browser_ok | 未触发时写明原因 | 旅程表 + 数据流转证据 | design.json#verification_mapping[0].manager_vp_ref |
| QHO-NFR | NFR | 性能/安全/契约等专项触发 | NFR | CONDITIONAL | non_browser_ok | 未触发或延后时写明原因 | 专项证据或延后说明 | design.json#quality_attributes[0] |

## cross_unit_obligations / 跨 UNIT 组合义务

| journey_id | journey_title | participant_unit_refs | local_unit_ref | sequence_index | predecessor_case_refs | successor_case_refs | handoff_obligation_refs | composition_status | gap_refs |
|------------|---------------|-----------------------|----------------|----------------|-----------------------|---------------------|-------------------------|--------------------|----------|
| J-001 | 核心旅程 | UNIT-1.json#unit_id, UNIT-2.json#unit_id | UNIT-1.json#unit_id | 0 | [] | TC-U2-001 | QHO-E2E | COMPOSABLE | [] |

## special_test_triggers / 专项测试触发依据与展开策略

| trigger_id | trigger_type | source_ref | condition | qa_stage | handling | backing refs |
|------------|--------------|------------|-----------|----------|----------|--------------|
| ST-001 | quality_attribute | design.json#quality_attributes[0] | [命中信号或风险证据] | NFR | QA_HANDOFF | QHO-NFR |

## review_conclusion / 审查结论

### reviewer_verdicts / 三视角 Verdict

| 视角 | perspective | Verdict | Issue Count | Review Round | Evidence |
|------|-------------|---------|-------------|--------------|----------|
| 测试质量 | test_quality | PASS | 0 | R2 | 测试质量确认轮无阻塞问题 |
| 产品 | product | PASS | 0 | R2 | 产品确认轮无阻塞问题 |
| 架构 | architecture | PASS | 0 | R2 | 架构确认轮无阻塞问题 |

### issue_ledger / 审查问题台账

| Issue ID | 视角 | Severity | Status | Evidence Anchor | Handoff Target | Review Round | 处理摘要 |
|----------|------|----------|--------|-----------------|----------------|--------------|---------|
| TQR-001 | 测试质量 | P1 | RESOLVED | artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#traceability-matrix | TC-U1-001 | R1 | 已补齐用例映射 |

### convergence_evidence / 收敛轮次摘要

| 轮次 | 结果 | FAIL数 | 未关闭 Issue IDs | 控制动作 | 说明 |
|------|------|-------|------------------|----------|------|
| R1 | FAIL | 1 | TAR-001 | CONTINUE | 首轮发现等价性缺口，进入修复 |
| R2 | PASS | 0 | 无 | CONFIRMATION | 确认轮复核通过，允许进入 tech-lead |
