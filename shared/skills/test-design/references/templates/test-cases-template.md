# test-cases projection

> 运行时真源为 `test-cases.json`；本文件只作为人类投影视图。

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
- PARTIAL: AC 缺少某类用例（标注缺失类型）
- DESIGN-GAP: AC 无法映射到设计承接

## 等价性对照矩阵
| scope_item_id | 关联 AC | 关联 TC | 对照输入 | 不变量 | 结果状态 | 备注 |  <!-- all columns required -->
|---------------|---------|---------|----------|--------|----------|------|
| SCOPE-P1U1-001 | AC-U1-01 | TC-U1-001, TC-U1-003 | [老/新输入对照] | [行为不变量] | EQ-COVERED | [证据链接] |

结果状态枚举：
- EQ-COVERED: 对照验证通过
- DESIGN-GAP(EQ): 缺少设计承接，阻断进入 `/tech-lead`

## Design 问题报告
| 编号 | 问题类型 | 关联 AC | 问题描述 | 严重度 |
|------|---------|---------|---------|--------|
| DI-001 | 接口缺失/约束缺失/错误码缺失/DESIGN-GAP(EQ) | AC-U{N}-{NN} | ... | P0/P1/P2 |

> 无问题时写明：无设计缺口。

## 测试用例

### TC-U1-001: [用例标题]
- 关联 UNIT: UNIT-1 <!-- required, type: UNIT-{N} -->
- 关联 AC: AC-U1-01 <!-- required, type: AC-U{N}-{NN} -->
- scope_item_id: SCOPE-P1U1-001 <!-- required, type: SCOPE-P{N}U{N}-{NNN} -->
- 类型: 正例 | 反例 | 边界 | 排除项验证 | 专项测试（可与前三类叠加） <!-- required, enum: [正例, 反例, 边界, 排除项验证, 专项测试] -->
- 前置条件: [...] <!-- required -->
- 输入/操作: [...] <!-- required -->
- 期望输出: [可 assert 的结果描述] <!-- required -->
- 验证命令: [可执行的验证命令或步骤] <!-- required -->

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

## 专项测试触发依据与展开策略（当“专项测试”计数 > 0 时必填）

| 专项类型 | 触发依据/触发条件 | 展开策略 | 备注 |
|---------|------------------|---------|------|
| 集成/契约/安全/性能 | [命中信号或风险证据] | [展开范围与样例] | [未命中但保守展开时说明“保守展开”原因；若交给 QA 执行需同步写入 QA 交接契约] |

> 未展开专项测试时写明：无（并说明不展开理由）。

## 引用锚点合同
- `execution_basis_ref` 允许引用 `artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#ac-coverage-matrix`、`artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#equivalence-matrix`、`artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#test-cases`、`artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#qa-handoff-contract`
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
| TQR-001 | 测试质量 | P1 | RESOLVED | artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#ac-coverage-matrix | TC-U1-001 | R1 | 已补齐用例映射 |
| TPR-001 | 产品 | P2 | RESOLVED | artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#unit-coverage | AC-U1-01 | R1 | 已对齐业务意图 |
| TAR-001 | 架构 | P1 | BLOCKED | artifact://test-cases/{feature}.phase-{N}.unit-{N}.test-cases@vX#equivalence-matrix | artifact://design/{feature}.phase-{N}.design@vX#quality-attributes | R2 | 等价性缺口已上报 design 阶段 |

### 收敛轮次摘要

| 轮次 | 结果 | FAIL数 | 未关闭 Issue IDs | 控制动作 | 说明 |
|------|------|-------|------------------|----------|------|
| R1 | FAIL | 1 | TAR-001 | CONTINUE | 首轮发现等价性缺口，进入修复 |
| R2 | PASS | 0 | 无 | CONFIRMATION | 确认轮复核通过，允许进入 tech-lead |

### 用户裁决记录

| 触发轮次 | 控制动作 | 用户决定 | 关联 Issue IDs | 记录时间 | 说明 |
|----------|----------|----------|----------------|----------|------|
