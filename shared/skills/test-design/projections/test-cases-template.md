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

> 展示可使用人类标签，但写回 `test-cases.json` 必须保留 canonical enum 原文。

## test_analysis / 测试分析

| 字段 | 内容 |
|------|------|
| 测试目标 | 来自 `test_analysis.objectives[]` |
| 测试范围 | 来自 `test_analysis.in_scope[]` |
| 不测范围 | 来自 `test_analysis.out_of_scope[]` |
| 风险模型 | 来自 `test_analysis.risk_model[]`，必须带 source ref |
| 质量策略 | 来自 `test_analysis.strategy_by_quality_area[]` |
| 测试流程 | 来自 `test_analysis.test_flow[]` |
| 环境假设 | 来自 `test_analysis.environment_assumptions[]` |
| 数据假设 | 来自 `test_analysis.data_assumptions[]` |

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

## UNIT 覆盖视图
| UNIT | 闭环目标 | 关联 AC | 用例编号 | 覆盖状态 |
|------|----------|---------|---------|---------|
| UNIT-1 | ... | AC-U1-01, AC-U1-02 | TC-U1-001, TC-U1-002 | COVERED |

## AC 覆盖矩阵
| UNIT | AC 编号 | AC 描述 | scope_item_id | 用例编号 | 类型（正例/反例/边界） | 覆盖状态 |  <!-- all columns required -->
|------|---------|---------|---------------|---------|----------------------|---------|
| UNIT-1 | AC-U1-01 | ... | SCOPE-P1U1-001 | TC-U1-001, TC-U1-002, TC-U1-003 | 正例, 反例, 边界 | COVERED |

覆盖状态枚举：
- COVERED: AC 有正例 + 反例 + 边界用例
- PARTIAL: AC 缺少某类用例（标注缺失类型，并在 `gap_refs` 中关联 typed gap）
- DESIGN_GAP: AC 无法映射到设计承接，必须同步写入 `design_gap_report.gaps[]`

canonical 字段：`ac_coverage_matrix[].positive_case_refs`、`negative_case_refs`、`boundary_case_refs` 必须分别非空，且 negative + boundary 数量不得少于 positive。

## 等价性对照矩阵
| scope_item_id | 关联 AC | 关联 TC | 对照输入 | 不变量 | 结果状态 | 备注 |  <!-- all columns required -->
|---------------|---------|---------|----------|--------|----------|------|
| SCOPE-P1U1-001 | AC-U1-01 | TC-U1-001, TC-U1-003 | [老/新输入对照] | [行为不变量] | EQ-COVERED | [证据链接] |

结果状态枚举：
- EQ-COVERED: 对照验证通过
- EQ_GAP: 等价性缺口，必须同步写入 `design_gap_report.gaps[]` 并按 `blocking` 决定是否阻断进入 `/tech-lead`

## Gap 报告
| gap_id | gap_type | blocking_refs | owner | next_action | blocking |
|--------|----------|---------------|-------|-------------|----------|
| GAP-001 | DESIGN_GAP | design.json#... | design | 补齐接口约束 | true |

> 无问题时写明：无 blocking typed gap。

## 测试用例

### TC-U1-001: [用例标题]
- 关联 UNIT: UNIT-1 <!-- required, type: UNIT-{N} -->
- product_refs: `UNIT-1.json#acceptance_criteria[0].ac_id`, `phase-prd.json#...` <!-- required -->
- design_refs: `design.json#verification_mapping[0].manager_vp_ref` <!-- required -->
- 类型: positive | negative | boundary | exclusion | specialty <!-- required, canonical enum -->
- 优先级: P0 | P1 | P2 | P3 <!-- required -->
- 前置条件: [...] <!-- required -->
- 测试数据: [...] <!-- required -->
- 步骤: [...] <!-- required -->
- 期望输出: [可 assert 的结果描述] <!-- required -->
- assertion_target: [可验证断言目标] <!-- required -->
- execution_mode: browser_required | non_browser_ok <!-- required -->
- automation_level: manual | automatable | automated <!-- required -->
- evidence_expectation: [期望证据] <!-- required -->
- owner_stage: developer | verify | qa | nfr <!-- required -->

### TC-U{N}-{NNN}: [用例标题]
...

## QA 交接契约

| test_obligation | trigger_source | qa_stage | requiredness | execution_mode | skip_rule | evidence_expectation |
|-----------------|----------------|----------|--------------|----------------|-----------|----------------------|
| 冒烟 | 默认强制 | QA_A | REQUIRED | non_browser_ok | 不可跳过 | 启动命令 + 健康检查 + 关键入口可用 |
| AC/功能 | AC 覆盖矩阵 | QA_A | REQUIRED | non_browser_ok | 不可跳过 | AC 追踪表 + 规则级证据 |
| API/接口 | artifact://design/{feature}.phase-{N}.design@vX#interface-boundary / 对外接口变更 | QA_A | REQUIRED | non_browser_ok | 仅在明确无接口影响时可写 N/A，必须写理由 | 请求/响应证据 + 错误路径验证 |
| E2E | 核心用户旅程 / 跨 UNIT 数据流 / Web-H5 入口行为 | QA_B | REQUIRED/CONDITIONAL | browser_required / non_browser_ok | 未触发时必须写未触发原因 | 旅程表 + 数据流转证据 |
| 回归 | 变更影响面分析 | QA_C | REQUIRED | non_browser_ok | 不可跳过 | 回归命令 + 影响面验证 |
| 探索 | 风险清单 / 未知交互面 | QA_D | CONDITIONAL | non_browser_ok | 未触发时必须写风险评估结论 | 章程 + 发现记录 |
| UX | Web/H5 页面交互约束 / 可用性风险 | QA_B | CONDITIONAL | browser_required / non_browser_ok | 未触发时必须写不执行理由 | 检查点 + 截图/录屏/描述证据 |
| 异常恢复 | Web/H5 中断/重试/幂等/补偿风险 | QA_B | CONDITIONAL | browser_required / non_browser_ok | 未触发时必须写不执行理由 | 恢复路径证据 |
| NFR | 性能/安全/契约等专项触发 | NFR | CONDITIONAL | non_browser_ok | 未触发或延后执行都必须写理由 | 专项证据或延后说明 |

> 要求：
> 1. `requiredness` 仅允许：`REQUIRED` / `CONDITIONAL`
> 2. `qa_stage` 仅允许：`QA_A` / `QA_B` / `QA_C` / `QA_D` / `NFR`
> 3. `execution_mode` 仅允许：`browser_required`, `non_browser_ok`
>    取值示例：browser_required, non_browser_ok
> 4. 当真实入口是 Web/H5，且验收依赖页面渲染、交互反馈、前端状态或路由行为时，`E2E / UX / 异常恢复` 必须标记 `browser_required`
> 5. 默认必须标记 `browser_required` 的场景：登录/权限/重定向/路由守卫、多步骤表单/向导/下单、文件上传下载、富交互状态切换、错误提示与恢复路径、关键 UX 反馈影响任务完成
> 6. 未展开或允许跳过时，必须在 `skip_rule` 中写清条件与理由，禁止写占位词。

## cross_unit_obligations / 跨 UNIT 组合义务

| journey_id | journey_title | participant_unit_refs | local_unit_ref | sequence_index | handoff_obligation_refs | composition_status | gap_refs |
|------------|---------------|-----------------------|----------------|----------------|-------------------------|--------------------|----------|
| J-001 | 核心旅程 | UNIT-1.json#unit_id, UNIT-2.json#unit_id | UNIT-1.json#unit_id | 0 | QA_B | COMPOSABLE | - |

composition_status 仅允许 `COMPOSABLE` 或 `BLOCKED_GAP`；`BLOCKED_GAP` 必须关联 typed gap。

## 专项测试触发依据与展开策略（当“专项测试”计数 > 0 时必填）

| 专项类型 | 触发依据/触发条件 | 展开策略 | 备注 |
|---------|------------------|---------|------|
| 集成/契约/安全/性能 | [命中信号或风险证据] | [展开范围与样例] | [未命中但保守展开时说明“保守展开”原因；若交给 QA 执行需同步写入 QA 交接契约] |

> 未展开专项测试时写明：无（并说明不展开理由）。

## 引用锚点合同
- `execution_basis_ref` 允许引用 `artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#test-analysis`、`artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#traceability-matrix`、`artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#ac-coverage-matrix`、`artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#equivalence-matrix`、`artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#test-cases`、`artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#qa-handoff-contract`、`artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#cross-unit-obligations`
- 当 `goal closure`、回归策略或 QA handoff 需要引用测试真源时，只能使用上述稳定章节锚点
- 禁止引用临时执行记录代替 `test-cases.json` 真源

## 审查结论
### 审查汇总

| 视角 | Verdict | Issue Count |
|------|---------|-------------|
| 测试质量 | PASS | 0 |
| 产品 | PASS | 0 |
| 架构 | PASS | 0 |

### 审查问题台账

| Issue ID | 视角 | Severity | Status | Evidence Anchor | Handoff Target | Review Round | 处理摘要 |
|----------|------|----------|--------|-----------------|----------------|--------------|---------|
| TQR-001 | 测试质量 | P1 | RESOLVED | artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#traceability-matrix | TC-U1-001 | R1 | 已补齐用例映射 |
| TPR-001 | 产品 | P2 | RESOLVED | artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#unit-coverage | AC-U1-01 | R1 | 已对齐业务意图 |
| TAR-001 | 架构 | P1 | BLOCKED | artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#design-gap-report | artifact://design/{feature}.phase-{N}.design@vX#quality-attributes | R2 | typed gap 已上报对应 owner |

### 收敛轮次摘要

| 轮次 | 结果 | FAIL数 | 未关闭 Issue IDs | 控制动作 | 说明 |
|------|------|-------|------------------|----------|------|
| R1 | FAIL | 1 | TAR-001 | CONTINUE | 首轮发现等价性缺口，进入修复 |
| R2 | PASS | 0 | 无 | CONFIRMATION | 确认轮复核通过，允许进入 tech-lead |

canonical 字段：`review_conclusion.review_round` 记录最新轮次；`review_conclusion.convergence_evidence[]` 记录每轮 `round/result/fail_count/control_action/evidence`；WARN 的承接记录写入 `issue_ledger[].review_round / evidence / handling_record`。FAIL 不允许作为完成态。

### 用户裁决记录

| 触发轮次 | 控制动作 | 用户决定 | 关联 Issue IDs | 记录时间 | 说明 |
|----------|----------|----------|----------------|----------|------|
