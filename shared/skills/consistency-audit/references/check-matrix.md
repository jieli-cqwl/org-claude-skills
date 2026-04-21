# 检测矩阵

## L1: brief/phase-prd/UNIT → design 一致性

| # | 检查项 | 检测方法 |
|---|--------|---------|
| L1-1 | UNIT 覆盖 | `phase-prd.json.unit_index` 与 `units/UNIT-*.json` 中的每个 UNIT 是否在 `design.json` 中有对应模块/方案？ |
| L1-2 | AC 可实现性 | `units/UNIT-*.json.acceptance_criteria` 是否能在 `design.json` 方案下实现？设计是否引入了上游未定义行为？ |
| L1-3 | 待设计决策回答 | `brief.json.design_decisions` 或 `phase-prd.json` 中的待设计决策是否在 `design.json` 中有明确回答？ |
| L1-4 | 术语一致 | `brief.json / phase-prd.json / UNIT-*.json` 定义的业务术语在 `design.json` 中是否一致使用？ |
| L1-5 | Constitution 合规 | `design.json` 是否与 `docs/constitution.md`（如存在）的原则一致？ |
| L1-6 | 页面组装视图承接 | 上游页面清单与组装视图是否在 `design.json` 中有对应页面/模块设计？ |
| L1-7 | 状态/枚举承接 | 上游业务对象状态与枚举定义是否在 `design.json` 数据模型中承接？ |
| L1-8 | 权限方案承接 | 上游角色权限矩阵是否在 `design.json` 中有对应权限设计方案？ |
| L1-9 | 高风险操作控制 | 上游高风险操作清单是否在 `design.json` 中有对应控制方案（确认机制/日志/回退）？ |

## L2: design → plan/tasks 一致性

| # | 检查项 | 检测方法 |
|---|--------|---------|
| L2-1 | 模块覆盖 | `design.json` 的每个关键模块/决策是否有 `plan.json/tasks.json` 对应 Task？ |
| L2-2 | 接口实现 | `design.json` 定义的每个接口是否有 Task 负责实现？ |
| L2-3 | 依赖顺序 | `tasks.json.tasks[].depends_on` 是否与 `design.json` 的模块依赖一致？ |
| L2-4 | design_ref 有效性 | 每个 Task 的 `design_refs` 是否指向有效 `design.json` 锚点？ |

## L3: requirement → plan/tasks 端到端追踪

| # | 检查项 | 检测方法 |
|---|--------|---------|
| L3-1 | unit_ref 覆盖 | 每个 UNIT 是否有至少一个 Task 的 `unit_refs` 或 scope refs 指向它？ |
| L3-2 | AC 覆盖 | 每条 AC 是否能通过 Task acceptance targets 或 `test_refs` 追踪到？ |
| L3-3 | 排除项尊重 | 上游 exclusions 是否在 `plan.json/tasks.json` 中被误实现？ |
| L3-4 | 非功能需求 | 上游非功能需求是否有对应 Task、execution basis 或 test obligation？ |

## L4: plan/tasks → test-cases 一致性

| # | 检查项 | 检测方法 |
|---|--------|---------|
| L4-1 | 测试覆盖 | 每个 Task 的 AC、acceptance target 或 `test_refs` 是否有 `test-cases.json` 对应测试用例？ |
| L4-2 | 测试可执行 | 测试用例的前置条件是否与 `tasks.json` 执行顺序兼容？ |

## L5: 全局一致性

| # | 检查项 | 检测方法 |
|---|--------|---------|
| L5-1 | 术语漂移 | 同一概念在不同工件中是否使用了不同名称？ |
| L5-2 | 范围漂移 | 是否有工件引入了 PRD 范围之外的功能？ |
| L5-3 | 版本一致 | 工件间 `plan_version_ref / tasks_version_ref / artifact-registry` 引用是否一致？ |
| L5-4 | 边界术语一致性 | `本期不交付`、`排除项`、`影响范围` 是否职责清晰且未混用？ |

## L6: 跨阶段一致性

> 对所有项目执行（所有项目使用 `phase-{N}/unit-{N}/` 结构）。

| # | 检查项 | 检测方法 |
|---|--------|---------|
| L6-1 | 阶段计划覆盖 | `brief.json.delivery_plan` 中的每个 UNIT 是否都有对应的 `phase-{N}/unit-{N}/` 工作区？ |
| L6-2 | 决策编号唯一 | 跨 `phase-*/design.json` 的关键决策编号是否全局唯一（无重复）？ |
| L6-3 | Constitution 同步 | 各 `phase-{N}/design.json` 引用的 constitution 决策是否与 `docs/constitution.md` 一致？ |
| L6-4 | 归档状态 | 已完成 Phase（`phase-{N}/qa-result.json` 含 PASS/ALLOW）是否已归档或明确保留原因？ |
| L6-5 | supersedes 声明 | 后续 UNIT 的 `supersedes` 声明是否指向有效的前序文件/章节？ |
