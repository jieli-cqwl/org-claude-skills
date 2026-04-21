# plan.md

## 输入分析
{需求理解 + design 接口理解 + 现有代码扫描}

## 计划模式
- 计划模式: {标准实施, 探索优先}
- 采用原因: {为何采用该模式；复杂度、实施不确定性或批次策略}
- 面向执行方: AI
- 设计决策状态: {已收口；若未收口则禁止进入 /tech-lead}

## Design 评审结论
- REVIEW: DESIGN_OK
- 评审摘要：
- 关键结论：

## PRD 前置约束映射

> 逐条承接 PRD `前置约束` constraint 对象；最小字段沿用 `constraint_id`、`type`、`description`、`owner`、`affected_unit`、`scope_item_id`、`preflight_ref`、`test_ref`、`status`。最终交付的 `plan.md` 中，每条约束都必须完成 Task、执行前检查与验收证据映射；若无法闭环，应停止输出并回看 PRD / Design，禁止在最终表中保留 `BLOCKED` 行。

<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| Constraint ID | 类型 | 约束内容 | Owner | 影响 UNIT | scope_item_id | preflight_ref | test_ref | 映射 Task | 验收证据 | 状态 |
|---------------|------|----------|-------|-----------|---------------|---------------|----------|-----------|----------|------|
| CON-001 | [env/runtime/shared-service/compliance/rollout/preflight] | [不可违反的前置约束] | [负责确认该前提的人/角色] | [UNIT-1, UNIT-2] | [SCOPE-P1U1-001] | [PF-001 / design.md#preflight-1] | [TC-U1-001 / N/A] | Task-1 | [QA_A / acceptance-summary.md#前置约束验收状态] | MAPPED |

状态枚举：
- MAPPED: 已映射到 Task、preflight_ref 与验收证据
- VERIFIED: 约束已在当前 Phase 取得可引用的验收证据，可直接带入 acceptance 汇总

## PRD / Design 覆盖矩阵
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| UNIT | requirement_type | requirement_ref | requirement_desc | scope_item_id | design_ref | Task | test_ref | 影响分析 | 覆盖状态 |  <!-- all columns required -->
|------|------------------|-----------------|------------------|---------------|-----------|------|----------|---------|---------|
| UNIT-1 | AC/GAC/EX | AC-U1-01 | ... | SCOPE-P1U1-001 | MOD-001 | Task-1 | TC-U1-001 | — | COVERED |

覆盖状态枚举：
- COVERED: requirement_ref → scope_item_id → design_ref → Task → test_ref 链路完整
- COVERED-NO-TEST: 有 Task 但 test-cases.md 中无对应用例
- UNCOVERED: design_ref 已声明但无 Task 承接（阻塞输出）
- DESIGN-GAP: design 覆盖表仍为 DESIGN-GAP（回退 DESIGN_ISSUE）
- EX-VERIFIED: 排除项有 test-cases.md 中的"不应发生"验证用例
- EX-NO-TEST: 排除项已声明但无验证用例

> 此矩阵为 Phase 级矩阵：只覆盖当前阶段的 UNIT。全局追踪视图在 PRD 的「交付计划」中，每个 UNIT 标注阶段归属、工作区路径和完成状态。

## Scope Freeze 与映射矩阵
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| scope_item_id | 变更类型 | 风险等级 | 映射 Task | test_ref | rollback_ref | 状态 |  <!-- all columns required -->
|---------------|----------|----------|-----------|----------|--------------|------|
| SCOPE-P1U1-001 | 拆分/迁移/契约变更 | P1 | Task-1 | TC-U1-001 | plan.md#回滚策略-1 | FROZEN |

状态枚举：
- FROZEN: 已冻结并完成映射
- GAP: 映射不完整，阻断进入执行

## 目标闭环与执行度量
<!-- HOOK-CONTRACT:TABLE-COL 列序不可调 -->
| 目标 | goal_source_ref | 承接 Task | execution_basis_ref | 成功信号 | 基线 | 护栏 | 说明 |
|------|-----------------|----------|---------------------|---------|------|------|------|
| [brief/phase 目标摘要] | [brief.md#目标与成功标准 / prd.md#阶段目标] | [Task-1, Task-2] | [plan.md#Task-1 / design.md#... / test-cases.md#...] | [如何判断变好] | [当前基线或基线获取方式] | [不可退化的边界] | [若为观察型信号，说明原因] |

> 本章节对应 `goal_fidelity_review`。它不重新定义业务目标，只把上游目标承接到本计划的 Task 与 execution basis。
> 每个上游目标都必须在本章节中出现，并映射到当前 `Task` 与 `execution_basis_ref`；允许同一上游目标拆成多行，但不得留空、漏项或仅写“后续承接位置”。

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

> 探索优先模式下，此处只列当前已解锁批次；未解锁后续任务不得提前写入 `plan.md`。

<!-- HOOK-CONTRACT:FORMAT -->
### Task-1: {标题}
- 文件: {具体文件路径列表，Glob 验证，不存在标注 Create} <!-- required -->
- task_type: {探索, 实施} <!-- required, enum: {探索, 实施} -->
- unit_ref: {UNIT-001, UNIT-002} <!-- required, type: UNIT-{NNN} -->
- design_ref: {MOD-001, HLD-inline（设计内联于 design.md，无独立 MOD 文件）} <!-- required -->
- scope_item_ref: {SCOPE-P1U1-001, SCOPE-P1U1-002} <!-- required, type: SCOPE-P{N}U{N}-{NNN} -->
- constraint_ref: {CON-001, CON-002, 无} <!-- required, type: CON-{NNN} -->
- api_ref: {接口路径引用，如 "design.md#POST-/api/users" 或 "design/API-SPEC.md#GET-/api/orders", 无接口交互} <!-- required -->
- test_ref: {TC-U1-001, TC-U1-002, TC-GAP} <!-- required, type: TC-U{N}-{NNN} -->
- proving_command: {执行阶段需要 fresh 重跑的真实验证命令，禁止写“见上次输出”“口头说明”或 Mock-only 命令} <!-- required -->
- real_dependency_note: {说明是否依赖真实服务、真实环境、真实集成路径；若存在录制回放/第三方限制也需写清边界} <!-- required -->
- evidence_target: {指向 dev-report / qa-report / acceptance-summary / preflight-evidence 的具体承接位置，便于下游追溯} <!-- required -->
- mock_boundary_note: {说明 Mock 仅可用于分层隔离测试，最终验收不得把 Mock 当完成证据} <!-- required -->
- hypothesis: {待验证假设；仅探索任务必填，实施任务填无} <!-- conditional -->
- success_signal: {验证通过信号；仅探索任务必填，实施任务填无} <!-- conditional -->
- failure_signal: {验证失败信号；仅探索任务必填，实施任务填无} <!-- conditional -->
- unlock_condition: {允许解锁后续任务的条件；仅探索任务必填，实施任务填无} <!-- conditional -->
- baseline_note: {当前基线或基线获取方式；优化/重构/探索类 Task 必填，其他 Task 填无} <!-- conditional -->
- guardrail_note: {不可退化的护栏、不可破坏的行为或非功能边界；优化/重构/探索类 Task 必填，其他 Task 填无} <!-- conditional -->
- complexity: {S, M, L, XL} <!-- required, enum: {S, M, L, XL} -->
- split_reason: {按子功能边界, 风险边界, 接口边界, 共享基础设施边界拆分的原因} <!-- conditional: required when Task count > 1 -->
- atomicity_note: {该 Task 为何能独立实现、独立验收、独立回滚；若超过默认粒度，注明不可再拆原因} <!-- conditional: required when exceeding default granularity -->
- AC:
  1. {可 assert 的验收标准——输入 → 输出格式}
  2. {多条件时附决策表, 状态转换时附合法+非法转换}
- depends_on: []
- shared_files: {被多个 Task 同时修改的文件，无则 []}

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

## 再计划与解锁规则
- 标准实施: {无 / N/A；标准实施模式填写此值}
- 探索优先:
  - 当前已解锁批次: {Task-1, Task-2；且 Task 清单只能包含这些 Task}
  - 再计划触发条件: {哪些探索结果会触发刷新 plan.md}
  - 必须回到用户确认的条件: {会改变路线/范围/风险接受度/上线策略的结果}
  - 停止条件: {探索失败或无法确认下一步}
  - 解锁方式: {刷新 plan.md 后才允许继续执行后续任务}

## 计划版本
- plan_version: v1
- 版本说明: {当前唯一有效的执行基线版本；若发生 REPLAN，必须递增并同步写入计划修订记录}
- 引用锚点合同: 下游统一引用 `plan.md#计划版本` 和 `plan.md#计划修订记录`，禁止消费侧自造版本号

## 计划修订记录
| plan_version | 触发原因 | 变更摘要 | 是否已重新确认 |
|--------------|----------|----------|----------------|
| v1 | 初版计划 | 首次输出 | 是 |

## Phase 3 固定完整门禁

固定完整门禁: `REVIEW_A + REVIEW_B + REVIEW_C + QA_A + QA_B + QA_C + QA_D`

门禁原则:
- `/delivery-owner` 统一执行完整 Phase 3，不在 plan.md 中维护审查强度分级。
- `review / qa / fix` 分别产出独立结论，`delivery-owner` 只调度和消费结果。
- 固定门禁阶段不得整体豁免；残余风险必须记录到 waiver 或 signoff，并由用户显式确认。

## 独立审查收敛

> 本章节记录由 Agent Team（TeamCreate 协作团队）组织的并行评审收敛结果；为兼容下游消费，沿用 `独立审查收敛` 章节名和既有字段。

### 审查汇总

| 视角 | Verdict | Review Round | Issue Count | 结论摘要 |
|------|---------|--------------|-------------|---------|
| 产品 | {PASS, WARN, FAIL} | {R1, R2, ...} | {0,1,2...} | {是否仍完成本 Phase 目标、MVP 与阶段交付价值} |
| 架构 | {PASS, WARN, FAIL} | {R1, R2, ...} | {0,1,2...} | {Task 拆分、依赖、并行、design 一致性结论} |
| 测试验收 | {PASS, WARN, FAIL} | {R1, R2, ...} | {0,1,2...} | {AC / test_ref / 真实证据链是否闭环} |

### 审查问题台账

| Issue ID | 视角 | Severity | Status | Evidence Anchor | Handoff Target | Review Round | 风险接受记录 | 处理摘要 |
|----------|------|----------|--------|-----------------|----------------|--------------|--------------|---------|
| PLP-001 / PLA-001 / PLT-001 | {产品, 架构, 测试验收} | {P0, P1, P2, P3} | {OPEN, RESOLVED, ACCEPTED, CLOSED} | {plan/design/prd/test-cases 的具体锚点} | {plan.md 内修正位置 / dev-report.md / qa-report.md / acceptance-summary.md / preflight-evidence.md} | {R1, R2, ...} | {谁接受、何时接受、接受前提；若已在 plan 内修正也要写明} | {已修正 / 下游承接 / 保留理由} |

> 规则：
> - 每条 WARN 必须写清 Handoff Target、风险接受记录、处理摘要；留空或占位视为不合格
> - `COVERED-NO-TEST / EX-NO-TEST` 必须由测试验收视角显式记录 issue，并说明谁接受、何时补齐
> - 最终验收不得把 Mock 当完成证据；若只能靠 Mock 成立，必须回退修正计划

### 收敛轮次摘要

| 轮次 | 结果 | FAIL数 | 未关闭 Issue IDs | 控制动作 | 说明 |
|------|------|-------|------------------|----------|------|
| R1 | {PASS, WARN, FAIL} | {0,1,2...} | {无 / PLA-001,PLT-001} | {CONTINUE, CONFIRMATION, ASK_USER, BLOCKED} | {本轮结论与下一步动作} |

### 用户裁决记录

| 触发轮次 | 控制动作 | 用户决定 | 关联 Issue IDs | 记录时间 | 说明 |
|----------|----------|----------|----------------|----------|------|
| R3 | {ASK_USER, BLOCKED} | {继续修复, 回退上游, 终止当前阶段, 保持阻断} | {PLA-001,PLT-001} | {YYYY-MM-DD HH:mm} | {用户裁决摘要} |

<!-- HOOK-CONTRACT:ENUM 填 REVIEW_PASS, FAIL 已修正 之一 -->
独立审查收敛状态: {REVIEW_PASS, FAIL 已修正}

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
- Task 与 unit_ref / design_ref / scope_item_ref / constraint_ref 对照关系、测试策略
- 前置约束映射矩阵（全部 MAPPED 或 VERIFIED，禁止残留 BLOCKED）
- PRD 覆盖矩阵（全部 COVERED 或 COVERED-NO-TEST）
