# Product / Tech-Lead 目标与证据合同加固设计

Created: 2026-04-14
Updated: 2026-04-14

## 一页对齐摘要

### 最初场景

- `product` 已经能把根问题、目标、范围、UNIT、AC 收口成较强的 PRD 基线。
- `tech-lead` 已经能把 design 拆成带追踪链和真实证据要求的 `plan.md`。
- 但两者之间还缺一层更硬的“目标如何被执行与验收承接”的合同。

### 当前问题定义

当前不是“没有目标定义”，也不是“没有 proving_command”，而是中间还存在两处松动：

1. `product` 的“目标与成功标准”已经存在，但很多时候仍停留在自然语言层，缺少基线、目标值、观测窗口和数据来源。
2. `tech-lead` 的 Task 已有 `proving_command`、`evidence_target` 等字段，但缺少一层清晰的“这个 Task 为什么能支撑上游目标、怎么证明变好、怎么防退化”的合同。

结果是：

- 上游知道“想达到什么”，下游知道“怎么做与怎么验”，但“为什么这组 Task 足以闭环目标”还不够显式。
- 对优化类、重构类、探索类需求，`product` 的成功判据和 `tech-lead` 的执行证据之间存在信息损耗。
- `delivery-owner` 的 `acceptance-summary.md` 已经要求 `目标闭环`，但上游 `plan.md` 还没有等强度的中间承接面。

### 本次明确要做

- 强化 `product` 的“成功信号”格式，让目标不只可理解，还可观测、可交接。
- 强化 `tech-lead` 的“目标闭环与执行度量”格式，让 Task 与上游目标的关系更可追溯。
- 保持现有角色边界：`product` 不下沉到实现计划，`tech-lead` 不吞并设计共创。
- 同步 reviewer prompt、template、completion check 与 contract tests。

### 本次明确不做

- 不重写 `product → design → test-design → tech-lead → delivery-owner` 主链。
- 不引入新的主干工件类型。
- 不把所有 Task 都强制改造成“数值优化任务”。
- 不要求所有成功标准都必须是单一数字；允许观察型成功信号，但必须写清原因与观测方式。
- 不改动 `delivery-owner` / `qa` 的权责边界。

### 已冻结决策

- `brief.md#目标与成功标准` 继续作为 `goal_source_ref` 的稳定来源之一。
- `phase-{N}/prd.md#阶段目标` 继续作为 phase 级目标来源。
- `plan.md` 继续保留现有 `覆盖矩阵 / Scope Freeze / Task 清单 / plan_version` 主骨架。
- 本次采用“增量补强”而不是“模式重构”。
- 优化类约束采用“按场景启用”，不对所有 Task 一刀切。

## Why

仓库当前已经形成比较完整的标准链路，但“目标定义”和“执行证据”仍偏分层孤立：

- `product` 擅长定义业务问题、闭环 UNIT 和 AC。
- `tech-lead` 擅长做设计评审、追踪覆盖和 Task 拆分。
- `delivery-owner` 则在最终 `acceptance-summary.md` 中要求把 `goal_source_ref / execution_basis_ref / evidence_ref` 显式闭环。

也就是说，最终签收层已经要求“目标闭环”，但上游 `product` 与 `tech-lead` 之间还缺少一层更强的中间合同。这会导致最终阶段才暴露“目标和任务没对齐”“有 proving_command 但无法解释为什么它证明了目标达成”“优化任务缺少非退化护栏”等问题。

本次设计的目标，是在不破坏现有主链的前提下，把这层中间合同补齐，让：

- `product` 输出的目标更适合作为后续执行与验收输入；
- `tech-lead` 输出的计划更适合作为后续目标闭环的执行基线；
- `delivery-owner` 的最终目标闭环不再主要依赖临场解释，而有更强的上游承接。

## Scope

- In scope:
  - `shared/skills/product/SKILL.md`
  - `shared/skills/product/references/templates/brief-template.md`
  - `shared/skills/product/references/completeness-checklist.md`
  - `shared/skills/product/references/prd-reviewer-prompt.md`
  - `shared/skills/product/references/tester-reviewer-prompt.md`
  - `shared/skills/tech-lead/SKILL.md`
  - `shared/skills/tech-lead/references/templates/plan-template.md`
  - `shared/skills/tech-lead/references/planning-modes.md`
  - `shared/skills/tech-lead/references/plan-reviewer-prompt.md`
  - `shared/skills/tech-lead/references/plan-product-reviewer-prompt.md`
  - `shared/skills/tech-lead/references/plan-test-reviewer-prompt.md`
  - `shared/skills/product/scripts/completion_check.sh`
  - `shared/skills/tech-lead/scripts/completion_check.sh`
  - 相关 shell contract tests
- Out of scope:
  - `design` / `test-design` / `delivery-owner` 的大规模角色重构
  - 新建独立的 metrics registry 或数据库
  - 让 `product` 直接产出实现命令、guard 命令或执行脚本
  - 让 `tech-lead` 负责业务目标定义

## Current State

### `product` 的现状

已有优点：

- 强制根问题确认，避免直接把方案抄成需求。
- S3 专门做“目标与成功标准对齐”。
- `brief-template.md` 已有 `目标 | 成功标准 | 度量方式`。
- 完整性检查的 C9 已要求“成功标准是否有可观察的度量方式”。

当前缺口：

- `度量方式` 仍偏轻，缺少统一的“基线 / 目标值 / 观测窗口 / 数据来源 / 度量类型”格式。
- 观察型成功信号与机械型成功信号没有明确区分。
- 成功标准常能表达“好不好”，但不一定能表达“比现在好多少”“什么时候看”“看哪里”。

### `tech-lead` 的现状

已有优点：

- 强制 `DESIGN_OK`、覆盖矩阵、可追踪 Task 与真实证据链。
- 每个 Task 已有 `proving_command / real_dependency_note / evidence_target / mock_boundary_note`。
- `planning-modes.md` 已具备“探索优先 / 先探后决”的分流能力。

当前缺口：

- Task 证明“做完了”很强，但证明“因此更接近上游目标”还不够显式。
- 对优化类、重构类、探索类任务，缺少统一的基线与护栏表达。
- `contracts/skill-chain.yaml` 已为 `plan.md` 预留 `goal_fidelity_review`，但模板尚未显式落出这一章节。

### 下游闭环现状

`delivery-owner` 的 `acceptance-summary.md` 已要求：

- `## 目标闭环`
- `goal_source_ref`
- `execution_basis_ref`
- `evidence_ref`

这说明“目标闭环”已经是链路后段的刚性要求。当前最值得补强的，不是再强化最终签收，而是把前段输入对齐到更适合作为目标闭环的执行基线。

## Goals

- 让 `product` 输出的目标与成功标准具备更强的可观测性与可交接性。
- 让 `tech-lead` 输出的计划能显式承接 `product` 目标，并说明 Task 如何支撑目标闭环。
- 对优化类、重构类、探索类计划，补充“基线 / 方向 / 护栏”合同，但不把普通功能计划过度复杂化。
- 保持稳定章节锚点，避免破坏下游引用和现有 tests。
- 让 reviewer prompt 和 completion check 能识别新增合同，而不是只有模板增加字段。

## Non-Goals

- 不要求所有目标都转成单一数值 KPI。
- 不要求所有 Task 都新增 metric 字段。
- 不把 `guard_command` 上推到 `product` 层。
- 不在本次设计中重构 `acceptance-summary.md`。
- 不通过修改自由文本措辞来“隐式支持”新合同，必须体现在模板、prompt 或 gate 上。

## Constraints

1. 稳定锚点优先
   - `brief.md#目标与成功标准`
   - `phase-{N}/prd.md#阶段目标`
   - `plan.md#计划版本`
   - `plan.md#Task 清单`
   - 这些章节继续保留，禁止通过重命名章节解决问题。

2. 角色边界不可漂移
   - `product` 负责业务目标与成功信号定义。
   - `tech-lead` 负责计划级目标承接与执行证据合同。
   - 设计不确定仍回退 `/design`。

3. 默认不增加下游消费复杂度
   - 新字段优先挂在现有章节中或以新章节承接现有 contract key。
   - 非优化类任务不得因为模板膨胀而被迫填写低价值字段。

4. completion check 必须与模板同步
   - 若新合同被定义为 required，就必须进入 gate。
   - 若只定义为场景化 required，就必须在 gate 里体现触发条件。

## Alternatives Considered

| Option | 做法 | 优点 | 缺点 | Verdict |
|--------|------|------|------|---------|
| A. 只改文案提示 | 只在 `SKILL.md` 加几句“请写清指标与基线” | 风险最低 | 模板、gate、tests 不跟，容易漂移 | Rejected |
| B. 平衡式合同补强 | `product` 强化成功信号格式，`tech-lead` 增加目标闭环与执行度量承接，gate 与 tests 同步 | 兼顾可读性、可执行性与兼容性 | 需要同时改文档、脚本和测试 | Chosen |
| C. 全链指标模型重构 | 新建统一 metrics schema，贯穿 product 到 acceptance | 结构最整齐 | 改动面过大，短期回归风险高 | Rejected for this change |

## Chosen Approach

### D1. `product`：把“成功标准”升级为“成功信号合同”

核心思想：

- 目标不再只回答“什么叫成功”，还要回答“现在是多少、希望变成多少、多久看、去哪里看”。
- 成功信号允许两种类型：
  - `机械型`
    - 可以通过数值、计数、比例、明确状态等稳定方式观察。
  - `观察型`
    - 暂时无法压成单一数值，但仍能通过具体行为变化、运营反馈窗口、指定数据源进行判断。

设计落点：

1. `brief.md#目标与成功标准` 扩展字段
   - 在现有 `目标 / 成功标准 / 度量方式` 基础上扩展为：
     - `目标`
     - `成功标准`
     - `度量类型`
     - `当前基线`
     - `目标值/方向`
     - `观测窗口`
     - `数据来源`
   - 保持章节名不变，避免破坏 `goal_source_ref`。

2. `product` S3 追问口径增强
   - 当前只要求“为什么做、做到什么算完成”。
   - 新增要求：
     - 当前基线是什么
     - 希望变到什么方向或区间
     - 多久看结果
     - 从哪里拿到结果

3. `C9 完成信号` 收紧
   - `C9` 不再满足于“有度量方式”。
   - 至少要判断：
     - 是否有基线
     - 是否有目标值或明确方向
     - 是否有观测窗口
     - 是否有数据来源
   - 若为观察型，必须写清“为什么此时不能机械化”。

4. reviewer prompt 同步
   - `prd-reviewer-prompt.md` 增加对成功信号完整性的审查。
   - `tester-reviewer-prompt.md` 增加对“是否可被验证、是否缺基线/窗口”的审查。

### D2. `tech-lead`：补上 `goal_fidelity_review` 与场景化度量/护栏合同

核心思想：

- `plan.md` 不只回答“做哪些 Task”，还要回答“这些 Task 如何承接上游目标”。
- 对优化类、重构类、探索类 Task，除了 `proving_command`，还要显式说明“衡量变好”和“防止退化”的方式。

设计落点：

1. 新增 `## 目标闭环与执行度量` 章节
   - 该章节对应 `contracts/skill-chain.yaml` 已存在的 `goal_fidelity_review`。
   - 表结构建议：
     - `目标`
     - `goal_source_ref`
     - `承接 Task`
     - `execution_basis_ref`
     - `成功信号`
     - `基线`
     - `护栏`
     - `说明`
   - 用途：
     - 把 `brief/phase goal` 与 `Task / plan / test-cases` 的承接关系前置到计划阶段。
     - 为后续 `delivery-owner` 的 `目标闭环` 提供更强的 execution basis。

2. Task 级合同按场景补强，而不是全量加码
   - 对“优化 / 重构 / 探索”类 Task，新增以下可机读风格字段：
     - `success_signal`
     - `baseline_note`
     - `guardrail_note`
   - 这些字段不替代 `proving_command`，而是补充解释：
     - 什么算变好
     - 当前基线在哪里
     - 不允许坏到什么程度

3. `proving_command` 质量要求增强
   - 对机械型成功信号的 Task：
     - `proving_command` 应尽量能 stable 产出明确结果。
     - 若需要数值比较，至少要写清 baseline 获取方式。
   - 对观察型成功信号的 Task：
     - `proving_command` 仍必须证明实现和验收路径成立；
     - 同时在 `success_signal` 中写清上线后或验证阶段的观测信号。

4. `planning-modes.md` 纳入探索型度量约束
   - 探索任务除了 `hypothesis / success_signal / failure_signal / unlock_condition`，还应明确：
     - success signal 是机械型还是观察型
     - 若无法机械化，为什么仍允许进入探索批次

5. reviewer prompt 同步
   - 架构视角：目标承接是否完整、Task 是否真的支撑目标。
   - 产品视角：计划是否改写了上游成功标准，或遗漏了关键目标。
   - 测试验收视角：优化类 Task 是否有可落地的 baseline / 护栏 / 验证方法。

### D3. `product → tech-lead → delivery-owner` 的目标闭环前移

本次设计不是新增一套“目标闭环模型”，而是把现有后段要求前移：

- `product`
  - 给出更强的 `goal_source_ref` 内容质量。
- `tech-lead`
  - 给出更强的 `execution_basis_ref` 前置承接。
- `delivery-owner`
  - 继续做最终 `goal_source_ref / execution_basis_ref / evidence_ref` 闭环。

这样链路会变成：

1. `product` 说清“目标 + 成功信号”
2. `tech-lead` 说清“哪些 Task 承接目标 + 用什么计划依据和度量方法证明”
3. `delivery-owner` 再把实际执行证据挂上去

### D4. completion check 与 tests 的落地策略

采用两层收口：

1. 文档合同层
   - 模板与 prompt 先收口语义。

2. 运行时门禁层
   - `product completion_check`
     - 对 `目标与成功标准` 检查列完整性和非占位。
     - 对 `C9` 检查最小闭环条件。
   - `tech-lead completion_check`
     - 检查 `goal_fidelity_review` 章节存在且非空。
     - 对场景化 Task 检查 `success_signal / baseline_note / guardrail_note` 是否齐备。

配套 tests：

- `tests/test-product-stability-guidance-contract.sh`
- `tests/test-skill-output-and-gate-contract.sh`
- 如锚点或 gate 影响到下游，再补：
  - `tests/test-delivery-owner-phase3-contract.sh`
  - `tests/test-delivery-owner-source-anchor-contract.sh`
  - `tests/test-constraint-closure-contract.sh`

### D5. 兼容性策略

为避免“模板一加字段，旧任务全失败”，本次采用以下兼容策略：

1. `product` 新字段优先作为 S3 与模板必填项
   - 因为 `brief.md#目标与成功标准` 本就属于上游真源，增强其密度是合理的。

2. `tech-lead` 新字段采用场景化必填
   - 普通功能 Task：可写 `无 / N/A`
   - 优化、重构、探索 Task：required

3. `goal_fidelity_review` 为计划级必填
   - 因为它承接已有 contract key，不属于新增角色职责，而是补齐既有缺口。

## File Impact

| 文件 | 变更类型 | 目的 |
|------|----------|------|
| `shared/skills/product/SKILL.md` | Modify | 强化 S3、C9 与成功信号定义口径 |
| `shared/skills/product/references/templates/brief-template.md` | Modify | 扩展 `目标与成功标准` 结构 |
| `shared/skills/product/references/completeness-checklist.md` | Modify | 收紧 C9 判定 |
| `shared/skills/product/references/prd-reviewer-prompt.md` | Modify | 增加成功信号完整性检查 |
| `shared/skills/product/references/tester-reviewer-prompt.md` | Modify | 增加成功信号可验证性检查 |
| `shared/skills/product/scripts/completion_check.sh` | Modify | 把成功信号最小闭环纳入 gate |
| `shared/skills/tech-lead/SKILL.md` | Modify | 定义 `goal_fidelity_review` 与场景化 metric/guard 规则 |
| `shared/skills/tech-lead/references/templates/plan-template.md` | Modify | 新增 `目标闭环与执行度量`，补强 Task 场景字段 |
| `shared/skills/tech-lead/references/planning-modes.md` | Modify | 探索任务纳入度量约束说明 |
| `shared/skills/tech-lead/references/plan-reviewer-prompt.md` | Modify | 增加目标承接与执行度量审查 |
| `shared/skills/tech-lead/references/plan-product-reviewer-prompt.md` | Modify | 增加上游目标保真检查 |
| `shared/skills/tech-lead/references/plan-test-reviewer-prompt.md` | Modify | 增加 baseline/guardrail 检查 |
| `shared/skills/tech-lead/scripts/completion_check.sh` | Modify | 校验 `goal_fidelity_review` 与场景化字段 |
| `tests/test-product-stability-guidance-contract.sh` | Modify | 锁定 `product` 新合同 |
| `tests/test-skill-output-and-gate-contract.sh` | Modify | 锁定 `product + tech-lead` 新合同 |
| `tests/test-delivery-owner-phase3-contract.sh` | Optional Modify | 如新增 execution basis 约束需同步下游验证 |

## Rollout

### Batch 1: 文档与 prompt 收口

- 更新 `product` 与 `tech-lead` 的 `SKILL.md`
- 更新模板与 reviewer prompt
- 目标：先冻结人类可读与 LLM 可输出的合同

### Batch 2: completion check 收口

- 更新 `product/scripts/completion_check.sh`
- 更新 `tech-lead/scripts/completion_check.sh`
- 目标：让 required 合同真正进入门禁

### Batch 3: 测试回归收口

- 更新 shell contract tests
- 跑最小验证集与必要扩展集
- 目标：防止后续回归时再把新合同削弱掉

## Acceptance

### `product`

- `brief.md#目标与成功标准` 能稳定回答：
  - 目标是什么
  - 什么叫成功
  - 度量类型是什么
  - 当前基线是什么
  - 目标值或方向是什么
  - 多久看
  - 去哪里看
- `C9` 不再允许仅用模糊“度量方式”蒙混通过。

### `tech-lead`

- `plan.md` 有显式的 `goal_fidelity_review` 承接面。
- 优化/重构/探索类 Task 有 `success_signal / baseline / guardrail` 合同。
- 普通功能 Task 不因模板膨胀而被迫填写低价值内容。

### 联动结果

- `product` 的目标输出更适合作为 `goal_source_ref`。
- `tech-lead` 的计划输出更适合作为 `execution_basis_ref`。
- 下游 `delivery-owner` 的 `目标闭环` 不再主要依赖临场解释。

### 验证命令

实施后至少运行：

- `bash tests/test-product-stability-guidance-contract.sh`
- `bash tests/test-skill-output-and-gate-contract.sh`

按改动面补充：

- `bash tests/test-delivery-owner-phase3-contract.sh`
- `bash tests/test-delivery-owner-source-anchor-contract.sh`
- `bash tests/test-constraint-closure-contract.sh`

## Risks And Mitigations

| 风险 | 说明 | 缓解方式 |
|------|------|----------|
| 目标字段过度结构化 | 让简单需求写起来太重 | `product` 只增强最小必要字段，不引入独立 metrics schema |
| `tech-lead` 模板膨胀 | 普通功能计划噪音上升 | 采用场景化 required，只对优化/重构/探索任务强制 |
| reviewer prompt 与 gate 不一致 | 文档写了但脚本不认，或脚本认了但 reviewer 不查 | prompt、template、completion check、tests 四层一起改 |
| 锚点漂移影响下游 | `delivery-owner` 的 `goal_source_ref` / `execution_basis_ref` 失效 | 保留稳定章节名，不改现有来源锚点 |
| 新 gate 过严导致历史 fixture 全挂 | completion check 一次性收得过猛 | 先做文档合同，再做场景化 gate，并配套 fixture 调整 |

## Open Questions

当前无必须阻断实施的开放问题。

后续若实施中发现以下情况，再单独回到设计层处理：

- 是否需要把观察型成功信号进一步细分为运营观察 / 用户行为观察 / 灰度观察。
- 是否需要在 `design` 或 `test-design` 层补一个显式的目标承接面。
