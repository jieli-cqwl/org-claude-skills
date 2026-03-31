# plan.md

## 输入分析
{需求理解 + design 接口理解 + 现有代码扫描}

## Design 评审结论
- REVIEW: DESIGN_OK
- 评审摘要：
- 关键结论：

## PRD / Design 覆盖矩阵
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| UNIT | PRD AC | 描述 | scope_item_id | Design MOD | Task | test_ref | 影响分析 | 覆盖状态 |  <!-- all columns required -->
|------|--------|------|---------------|-----------|------|----------|---------|---------|
| UNIT-1 | AC-U1-01 | ... | SCOPE-P1U1-001 | MOD-001 | Task-1 | TC-U1-001 | impact_files 已标注 | COVERED |

覆盖状态枚举：
- COVERED: AC → MOD → Task → test_ref 链路完整
- COVERED-NO-TEST: 有 Task 但 test-cases.md 中无对应用例
- UNCOVERED: 有 MOD 映射但无 Task 承接（阻塞输出）
- DESIGN-GAP: PRD AC 在 Design 中无 MOD 映射（回退 DESIGN_ISSUE）
- EX-VERIFIED: 排除项有 test-cases.md 中的"不应发生"验证用例
- EX-NO-TEST: 排除项已声明但无验证用例

> 此矩阵为 Phase 级矩阵：只覆盖当前阶段的 UNIT。全局追踪视图在 PRD 的「交付计划」中，每个 UNIT 标注阶段归属、工作区路径和完成状态。

## Scope Freeze 与映射矩阵
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| scope_item_id | 变更类型 | 风险等级 | 映射 Task | test_ref | impact_files | rollback_ref | 状态 |  <!-- all columns required -->
|---------------|----------|----------|-----------|----------|--------------|--------------|------|
| SCOPE-P1U1-001 | 拆分/迁移/契约变更 | P1 | Task-1 | TC-U1-001 | services/user.ts, api/user.ts | plan.md#回滚策略-1 | FROZEN |

状态枚举：
- FROZEN: 已冻结并完成映射
- GAP: 映射不完整，阻断进入执行

## 实施分组（满足任一条件时必须提供）

- 存在 `2` 个及以上稳定交付结果 / 子功能主线（workstream）
- 存在 `2` 轮及以上执行批次（batch）
- Task 清单无法直接表达主线，必须先按阶段或子功能分组后才能稳定执行

### Workstream-A / Phase-1: {名称}
- 目标: {该分组要完成的稳定交付结果}
- 包含 Task: {Task-1, Task-2}
- 进入条件: {依赖哪个前置 Task, MOD, 验证点}
- 完成标志: {完成后系统具备什么可观察能力}

## Task 清单

<!-- HOOK-CONTRACT:FORMAT -->
### Task-1: {标题}
- 文件: {具体文件路径列表，Glob 验证，不存在标注 Create} <!-- required -->
- unit_ref: {UNIT-001, UNIT-002} <!-- required, type: UNIT-{NNN} -->
- design_ref: {MOD-001, HLD-inline（设计内联于 design.md，无独立 MOD 文件）} <!-- required -->
- scope_item_ref: {SCOPE-P1U1-001, SCOPE-P1U1-002} <!-- required, type: SCOPE-P{N}U{N}-{NNN} -->
- api_ref: {接口路径引用，如 "design.md#POST-/api/users" 或 "design/API-SPEC.md#GET-/api/orders", 无接口交互} <!-- required -->
- test_ref: {TC-U1-001, TC-U1-002, TC-GAP} <!-- required, type: TC-U{N}-{NNN} -->
- complexity: {S, M, L, XL} <!-- required, enum: {S, M, L, XL} -->
- split_reason: {按子功能边界, 风险边界, 接口边界, 共享基础设施边界拆分的原因} <!-- conditional: required when Task count > 1 -->
- atomicity_note: {该 Task 为何能独立实现、独立验收、独立回滚；若超过默认粒度，注明不可再拆原因} <!-- conditional: required when exceeding default granularity -->
- AC:
  1. {可 assert 的验收标准——输入 → 输出格式}
  2. {多条件时附决策表, 状态转换时附合法+非法转换}
- depends_on: []
- shared_files: {被多个 Task 同时修改的文件，无则 []}
- impact_files:
  - {文件路径}: {修改原因，如"引用了被重命名的接口"}
  - 已由其他 Task 主文件覆盖的标注"已由 Task-N 覆盖"
  - 无关联修改时 []

## 依赖关系
- Task-2 depends_on: {Task-1}

## 并行策略

团队规模：N 名开发者

#### Batch 1（可并行）
| 开发者 | Task | 文件范围 | worktree 隔离 | 说明 |
|--------|------|---------|--------------|------|

#### Batch 2（依赖 Batch 1）
| 开发者 | Task | 依赖 | 说明 |
|--------|------|------|------|

并行安全检查：
- Batch 1 内 Task-X 与 Task-Y 文件范围无交集
- shared_files: 无 / {列表} → merge 时需人工确认冲突
- worktree 隔离策略：每个并行 Task 使用 `isolation: "worktree"`

> 无并行候选时简化为：`并行策略：串行执行（按 Task 顺序执行）`

> `impact_files` 的共享格式契约见 `reference/影响文件格式.md`；影响面推导方法见 `reference/影响范围分析.md`。

## Phase 3 审查分级

<!-- HOOK-CONTRACT:ENUM 填 轻量, 标准, 完整 之一 -->
审查分级: {轻量, 标准, 完整}

判定依据:
- 轻量: `1-2` Task 且无安全风险
- 标准: `3-5` Task 或涉及安全风险
- 完整: `6+` Task 或核心业务链路

强门禁矩阵:
- 轻量: `REVIEW_A + QA_A`
- 标准: `REVIEW_A + REVIEW_B + QA_A + QA_C`
- 完整: `REVIEW_A + REVIEW_B + QA_A + QA_B + QA_C + QA_D`
- `REVIEW_C` 仅作为可选增强审查，不进入 `/project-manager` 的强门禁判定

> 该字段是 `/project-manager` Phase 3 校验的唯一分级真源；后续报告分级必须与此一致。

## 前置验证点
- {验证点 1}

## 关键里程碑
- {里程碑 1}

## 风险与执行注意事项
- {风险 1}

## 用户确认记录
- 确认状态: 确认
- 确认时间: YYYY-MM-DD HH:mm
- 确认备注: [可选]

## 交接项
- 任务执行顺序、文件改动清单、每任务 AC
- Task 与 unit_ref / design_ref / scope_item_ref 对照关系、测试策略
- PRD 覆盖矩阵（全部 COVERED 或 COVERED-NO-TEST）
