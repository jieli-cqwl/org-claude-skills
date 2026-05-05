# 测试基础分析与用例设计方法

## 目标

把产品意图和架构设计转成可断言的测试条件，再把测试条件转成可执行测试用例。无法从产品或架构证据推出时，转成 typed gap。

## Test Basis 分析

测试基础来自两类输入：

- 产品输入定义 WHAT：目标、角色、业务流程、AC、排除项、风险和 NFR。
- 架构输入来自 canonical `design.json`，定义 HOW：接口、数据、错误、权限、日志、配置、质量属性、risk response 和 verification mapping。

分析顺序：

1. 先按 UNIT 建立业务闭环，确认这个 UNIT 要证明什么用户价值。
2. 将每条 AC、排除项、风险和 NFR 拆成 test condition。
3. 为每个 condition 找到产品 source ref。
4. 为每个 condition 找到设计承接点。
5. 找不到承接点时，记录 gap。

## Example Mapping

用四类卡片整理测试条件：

- Rule：业务规则、设计约束或质量约束。
- Example：能证明规则成立或不成立的具体例子。
- Question：无法从输入中确认的问题。
- Gap：Question 已阻断测试义务形成时的 typed gap。

好的 example 必须具体到输入、操作、状态和期望结果；写清导出角色、筛选条件、字段、权限、数据规模和期望证据。

## 用例设计技术

优先使用这些技术，而不是机械堆用例：

- 等价类：把输入、状态、角色、配置分成有效类和无效类。
- 边界值：覆盖阈值、空值、最大/最小、分页边界、并发边界。
- 决策表：多条件组合会改变结果时，列出条件组合与动作。
- 状态迁移：流程状态会影响行为时，覆盖合法迁移和非法迁移。
- 错误路径：覆盖认证失败、权限不足、下游失败、超时、重试、回滚。
- 排除项验证：证明本期不交付的能力没有被误实现、误暴露或误承诺。

每条测试用例至少回答：

- 证明哪个 product ref。
- 证明哪个 design ref。
- 用什么输入和操作触发。
- 观察什么 assertion target。
- 需要什么 evidence。

## Typed Gap 裁决

只在无法形成可执行测试义务时记录 gap。

- `PRODUCT_GAP`：产品意图、范围、角色、字段、AC 或 NFR 缺失/冲突。
- `DESIGN_GAP`：产品条件存在，但设计没有接口、数据、约束或风险承接。
- `SCOPE_DRIFT`：用户要求或用例超出本期范围、排除项或冻结边界。
- `TRACE_CONFLICT`：产品 refs 与设计 refs 表达的行为冲突。
- `TESTABILITY_GAP`：缺少可观测结果、阈值、环境、数据规模或证据口径。
- `EQ_GAP`：等价性、兼容性或迁移前后对照无法证明。

非阻断优化建议归入 review note。gap 必须能指向 owner 和 next_action。

## 收敛标准

测试设计收敛时，应能从任意 AC 或设计承接点追踪到：

1. 测试条件。
2. 测试用例或 QA obligation。
3. assertion target。
4. evidence expectation。
5. gap refs，若无法测试。
