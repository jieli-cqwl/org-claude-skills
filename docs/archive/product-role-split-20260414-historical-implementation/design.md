# 设计：拆分 /product 为 /product-director + /product-manager

## Context

当前 `/product` skill（S1-S12）将产品总监（战略决策）和产品经理（精度定义）两种认知模式混在同一个 skill 中。导致：

1. **角色职责混合**（根因）：方向性判断与精度性判断共用一个会话，切换成本高
2. **上下文噪音**：S2-S6 的发散探索对话残留到 S7 时，模型有效注意力下降
3. **UNIT 共创深度不足**：S7 用草案修正模式（AI 一次性生成所有 UNIT），用户只能事后纠错

拆分的目标是让每个角色在干净的上下文中、用匹配的交互模式完成其职责。

### 问题因果链

```
角色职责混合（根因）
  ├─ 导致 → 上下文噪音（产品总监的发散探索对话残留到产品经理的精度判断阶段）
  └─ 导致 → 共创深度不足（S7 用草案修正，因为若改全共创则会话更长、噪音更大）
```

只有从根因入手，两个问题同时消解：
- product-manager 在干净上下文中启动 → 噪音消失
- product-manager 可以从一开始就用全共创模式 → 深度保障

### 设计原则

- **从工件出发**：product-manager 从 brief.md + phase-prd.md 获取上下文，不依赖对话记忆
- **全共创 UNIT 定义**：UNIT 边界判断用全共创模式，逐个讨论，不一次性全部生成
- **INVEST 原则**：Independent / Negotiable / Valuable / Estimable / Small / Testable
- **Phase 粒度约束**：每个 Phase 包含 3-7 个 UNIT
- **用户场景驱动**：从用户操作路径中"发现"UNIT 边界，而不是凭模板推理

---

## 角色职责定义

### 产品总监 (product-director)

| 职责 | 说明 | 对应需求层次 |
|------|------|-------------|
| 根问题定义 | 为什么做 | Business Requirements |
| 目标与成功标准 | 做成什么样、怎么衡量（产品级度量） | Business Requirements |
| 业务域上下文 | 术语、业务对象、高层当前/目标流程 | 高层 User Requirements |
| 范围与业务规则 | 做什么、不做什么、规则约束 | Business Requirements |
| 非功能需求 | 性能、安全等产品级约束 | Business Requirements |
| Phase 交付规划 | 分几步走、每步到哪（3-7 UNIT/Phase 粒度约束） | WBS Level 2 |

### 产品经理 (product-manager)

| 职责 | 说明 | 对应需求层次 |
|------|------|-------------|
| 详细业务流程分析 | 展开目标流程为具体操作步骤 + 业务对象状态变化 | 详细 User Requirements |
| 用户场景路径 | 走通用户操作路径，发现功能断点 | 详细 User Requirements |
| 业务规则映射 | 把总监定义的规则映射到具体 UNIT | Functional Requirements |
| UNIT 闭环定义 | 输入/触发 → 核心行为 → 可观察结果 | Functional Requirements |
| 验收标准 (AC) | 正常/异常/边界三场景，可测可判定 | Functional Requirements |
| 依赖 + 优先级 + 排除项 | UNIT 间关系和优先级判断 | WBS Level 3 |
| 待设计决策 | 从 UNIT 分析中浮现的技术问题 | 架构接口 |
| 完整性验证 + 质量评审 | 覆盖检查 + 三方交叉审查 | 需求验证 |

### 关键区分：成功标准 vs 验收标准

| 维度 | 成功标准（产品总监） | 验收标准（产品经理） |
|------|-------------------|-------------------|
| 层次 | 产品级 | 功能级 |
| 回答 | "这件事做成了吗？" | "这个功能做对了吗？" |
| 示例 | "注册转化率提升 20%" | "AC-U1-01: 邮箱格式非法 → 提示'请输入有效邮箱'" |
| 度量时间 | 上线后观测窗口内 | 开发完成即可验证 |

---

## 产品总监步骤设计

基于当前 S1-S6，最小调整：

| 步骤 | 名称 | 交互模式 | 变更说明 |
|------|------|---------|---------|
| D-S1 | 静默信息收集 | 静默 | 不变。Context Scan Agent + Problem Hypothesis Agent |
| D-S2 | 根问题澄清 | 全共创 | 不变。读 `conversation-guide.md` |
| D-S3 | 目标与成功标准 | 全共创 | 不变。包含度量类型（机械型/观察型） |
| D-S4 | 业务语义收口 | 草案修正 | 不变。术语、业务对象、当前/目标流程 |
| D-S5 | 范围与规则收口 | 草案修正 | 只记录范围、规则、前置约束和 `CON-*` / `DIR-CON-P{N}-{seq}` 来源；禁止输出 `scope_item_id` 或任何 `SCOPE-*` 占位值 |
| D-S6 | Phase 规划 | 草案修正 | 新增：每个 Phase 标注预期 UNIT 数量范围（3-7）。读 `phase-splitting-guide.md` |
| D-G1 | 总监确认门 | 全共创 | 确认：根问题、目标、范围、Phase 规划。**不含 UNIT 清单；通过后冻结 Director 负责的 brief 节、`brief.md#交付计划` 的 Phase 级结构字段，以及 `phase-{N}/prd.md` 的阶段骨架；同时生成 canonical 锁定快照文件** |

### 产出

- `docs/{feature}/brief.md`（填写总监负责的节）
- `docs/{feature}/phase-{N}/` 目录结构
- `docs/{feature}/phase-{N}/prd.md` 骨架（阶段目标 + 进退条件，UNIT 索引留空）
- `docs/{feature}/brief.lock.json`（D-G1 通过时自动生成，记录 Director 锁定字段的 canonical 快照）
- `docs/{feature}/phase-{N}/prd.lock.json`（D-G1 通过时自动生成，记录 prd.md 骨架中 Director 锁定字段的 canonical 快照）

### HARD-GATE

| 编号 | 规则 | 来源 |
|------|------|------|
| D-HG-1 | 问题确认前不得产出 PRD | 保留自 HG-1 |
| D-HG-5 | D-S2~D-S6 每步必须遵循共创模式 | 保留自 HG-5（范围缩小） |
| D-HG-7 | 禁止跳步 | 保留自 HG-7 |
| D-HG-8 | D-S1 不得越权 | 保留自 HG-8 |
| D-HG-9 | D-G1 用户确认后才算完成 | 新增（从 HG-6 派生） |

移除：HG-2（UNIT 闭环）、HG-3（完整工件集）、HG-4（审查结论）→ 归 PM

---

## 产品经理步骤设计

从工件出发，干净上下文，全共创为主：

| 步骤 | 名称 | 交互模式 | 说明 |
|------|------|---------|------|
| M-S0 | 工件接收与验证 | 静默 | 读取 brief.md + phase-prd.md，校验总监确认门已通过。发现问题时：小问题记假设，大问题停止并建议回到 Director |
| M-S1 | 详细业务流程分析 | **全共创** | **新增**。逐 Phase 展开目标流程为具体操作步骤 + 业务对象状态变化 |
| M-S2 | 用户场景路径 | **全共创** | **新增**。走通用户操作路径，发现功能断点（UNIT 边界的认知前提） |
| M-S3 | 业务规则映射 | **全共创** | **新增**。把总监的业务规则映射到具体功能，识别跨切规则 |
| M-S4 | UNIT 拆解 | **全共创** | **模式变更**（原 S7 草案修正 → 全共创）。逐个 UNIT 共创：提出候选 → 讨论边界 → 写闭环定义 + 初始 AC。INVEST 原则检验。3-7 UNIT/Phase 约束 |
| M-S5 | AC 细化 | 草案修正 | 基于 M-S4 的初始 AC，补充完整的正常/异常/边界场景 |
| M-S6 | 待设计决策 | 条件共创 | 同现有 S9。收集需架构阶段回答的开放问题 |
| M-S7 | 完整性扫描 | 条件共创 | 同现有 S10。读 `completeness-checklist.md`（C1-C10） |
| M-S8 | 三方评审 | 评审模式 | 同现有 S11。3 视角 × 最多 10 轮。评审范围调整见下 |
| M-G1 | PM 裁决门 | 裁决门 | FAIL → 回 M-S8 修复；PASS/WARN → 继续 |
| M-S9 | 用户确认与输出 | 全共创 | 同现有 S12。写最终工件 + 交付确认 |

### 三方评审范围调整

| 视角 | 调整 | 理由 |
|------|------|------|
| 产品评审 | R1 改为"UNIT 与根问题的一致性检查 + Director 锁定节是否被改动"；不重做根问题探索，但必须复核 PM 是否改写 Director 已确认意图 | 根问题已在 Director 阶段确认，但 handoff 后仍需防止共享 brief 漂移 |
| 架构评审 | R7-R9 不变 | 技术可行性、隐藏依赖、约束充分性均需保留 |
| 测试评审 | R10-R12/R13 不变 | AC 可测性、异常覆盖、影响范围均需保留 |

`brief.md` 整体一致性不能只靠 `/analyze` 兜底：M-S0 必须先校验 `## 产品总监确认` 为已通过，M-S8/M-G1 必须再次检查 Director 锁定节未被 PM 改写；一旦检测到 PM 改动 Director 锁定节，立即阻塞并回到 `/product-director` 重新确认。

### Director 锁定节

D-G1 通过后，以下内容进入锁定态，PM 不可改写：

- `brief.md` 的 `## 业务背景与根问题`
- `brief.md` 的 `## 目标与成功标准`
- `brief.md` 的 `## 引用锚点合同`
- `brief.md` 的 `## 业务术语`
- `brief.md` 的 `## 业务对象`
- `brief.md` 的 `## 当前业务流程`
- `brief.md` 的 `## 目标业务流程`
- `brief.md` 的 `## 范围 / 本期不交付`
- `brief.md` 的 `## 业务规则`
- `brief.md` 的 `## 影响范围`
- `brief.md` 的 `## 非功能需求`
- `brief.md` 的 `## 全局排除项`
- `brief.md` 的 `## 产品总监确认`
- `brief.md#交付计划` 中的 Phase 级结构字段：阶段标题、入口条件、出口条件、交付价值（**不含阶段状态** — 阶段状态是运行时流转字段，由下游按 `NOT_STARTED → IN_PROGRESS → DONE` 更新）
- `phase-{N}/prd.md` 骨架中的阶段目标、入口/出口条件等 Director 已确认字段

PM 可写范围改为“共享节 + 局部字段”模型：

- `## 关键假设`：只能追加 `[PM-ASSUMPTION]`
- `## 用户角色与核心场景`：可补充场景路径细节
- `## 已排查并排除的潜在问题`：可补充 PM 排查结果
- `## 共创摘要`：填写 PM 阶段摘要
- `## 交付计划`：**允许补 UNIT 表、UNIT 状态和 Phase 阶段状态流转（`NOT_STARTED → IN_PROGRESS → DONE`），不得改 Phase 级结构字段（标题、入口/出口条件、交付价值）**
- `## 前置约束`：**允许 PM 在不改写 Director 约束事实/Owner/约束内容的前提下，补齐 UNIT 归属、最终 `scope_item_id`、`test_ref`、状态细化等执行映射字段；若约束事实本身要变，必须回到 `/product-director`**
- `## 审查结论` / `## 交付确认` / `## 交接项` / `## 待设计决策` / `## MVP 最小闭环说明`：由 PM 负责

换句话说，`## 前置约束` 不是整节冻结，而是“Director 定义约束事实，PM 只补执行映射字段”的共享节。

### 漂移阻断规则

- M-S0：读取 Director 工件时，比对 lock 文件内容与当前 `brief.md` / `prd.md` 中 Director 锁定字段是否一致，确认未被篡改后记录 Director 锁定内容快照；若 `## 产品总监确认` 不是已通过，停止执行。lock 文件不内嵌 commit hash（避免自证），以内容级一致性校验为 authoritative gate；`git log --follow` 可作为辅助溯源手段，但不作为准入硬依赖。
- M-S4~M-S9：任何需要修改 `brief.md` 的步骤，都必须限定在 PM 可写节或 PM 可写字段。
- M-S8：产品评审新增一条显式检查：Director 锁定内容是否与 D-G1 快照一致，覆盖 `brief.md` 锁定节、`brief.md#交付计划` Phase 级结构字段（不含阶段状态）和 `phase-{N}/prd.md` Director 骨架字段。校验源为 `brief.lock.json` / `prd.lock.json`，比对方式为内容级一致性校验。
- M-G1：若存在 PM 改写 Director 锁定内容的差异，Verdict 直接 FAIL，不允许带 WARN 继续。
- `/analyze`：只作为跨工件补充审视，不再承担 handoff 漂移的唯一防线。

### HARD-GATE

| 编号 | 规则 | 来源 |
|------|------|------|
| M-HG-0 | 准入三条件缺一不可：(1) `## 产品总监确认=已通过`；(2) `brief.lock.json` 存在且与 brief.md 锁定字段内容一致；(3) 每个 `phase-{N}/prd.lock.json` 存在且与对应 prd.md 骨架字段内容一致。以内容级一致性校验为 authoritative gate，不内嵌 commit hash（`git log --follow` 可作为辅助溯源，不作为准入硬依赖）。legacy brief 必须先完成 migration candidate + Director/用户显式 re-signoff + 首版 lock snapshot 生成，三步全部完成后才能进入 M-S1 | 新增 |
| M-HG-2 | UNIT 必须有闭环定义 | 保留自 HG-2 |
| M-HG-3 | 完成时必须有完整工件集 | 保留自 HG-3 |
| M-HG-4 | 审查结论无未解决 FAIL | 保留自 HG-4 |
| M-HG-5 | M-S1~M-S9 每步遵循共创模式 | 保留自 HG-5 |
| M-HG-6 | 显式交付确认 | 保留自 HG-6 |
| M-HG-7 | 禁止跳步 | 保留自 HG-7 |
| M-HG-8 | 上游问题标记未解决时不得声称完成 | 新增 |
| M-HG-9 | 不得改写 Director 锁定内容；允许修改的共享节/字段必须受字段级约束 | 新增 |
| M-HG-10 | legacy brief 不得通过任何自动补标记方式放行；必须经过 migration candidate → Director/用户显式 re-signoff → 首版 lock snapshot 生成的完整路径 | 新增 |

### 反馈回路

| 问题类型 | 处理方式 |
|----------|---------|
| 小问题（可假设继续） | 记录在 brief.md `## 关键假设` 中，标注 `[PM-ASSUMPTION]` |
| 大问题（Phase 边界不合理、范围遗漏、规则模糊、Director 锁定内容需变更、前置约束事实需改写） | 停止执行，向用户说明问题，建议回到 `/product-director` 调整 |

---

## brief.md 节归属

`brief.md` 与 `phase-{N}/prd.md` 是共享工件，模板语义必须保持单一真源。Director / Manager 的差异只体现在“谁写哪些节、哪些字段锁定、哪些字段可补充”，不体现在模板分叉。

两个 skill 写同一个文件，按节划分所有权：

| 节 | 归属 | 时机 |
|---|------|------|
| 业务背景与根问题 | Director | D-S2 |
| 目标与成功标准 | Director | D-S3 |
| 引用锚点合同 | Director | D-S4 |
| 关键假设 | Director 初始，PM 补充 `[PM-ASSUMPTION]` | D-S3 / M-S* |
| 用户角色与核心场景 | Director 初始，PM 从场景路径补充 | D-S2 / M-S2 |
| 业务术语 | Director | D-S4 |
| 业务对象 | Director | D-S4 |
| 当前业务流程 | Director | D-S4 |
| 目标业务流程 | Director | D-S4 |
| 范围 / 本期不交付 | Director | D-S5 |
| 业务规则 | Director | D-S5 |
| 影响范围 | Director | D-S5 |
| MVP 最小闭环说明 | **PM** | M-S4 |
| 非功能需求 | Director | D-S5 |
| 全局排除项 | Director | D-S5 |
| 前置约束 | Director 定义约束事实、Owner、约束内容、影响 UNIT 与初始 `CON-*` / `DIR-CON-P{N}-{seq}` 来源；PM 只补最终 `scope_item_id=SCOPE-P{N}U{M}-{seq}`、`test_ref`、状态细化，必要时通过独立映射层承接多 UNIT 落地 | D-S5 / M-S4 |
| 待设计决策 | **PM** | M-S6 |
| 已排查并排除的潜在问题 | Director 初始，PM 补充 | D-S5 / M-S7 |
| 产品总监确认 | Director | D-G1 |
| 共创摘要 | **双方**（Director 填前 4 阶段，PM 填后 3 阶段） | 各自步骤中 |
| 交付确认 | **PM** | M-S9 |
| 审查结论 | **PM** | M-S8 |
| 交付计划 | Director 写 Phase 级骨架与结构字段（标题/入口/出口/交付价值），**PM 填 UNIT 表、UNIT 状态和阶段状态流转** | D-S6 / M-S4+M-S9 |
| `phase-{N}/prd.md` 骨架 | Director 产出阶段目标与进退条件，PM 只补 UNIT 索引/UNIT 级承接信息 | D-S6 / M-S4+M-S9 |
| 交接项 | **PM** | M-S9 |

### 字段级冻结规则

为避免“共享节整节冻结”与“下游必须补字段”冲突，冻结粒度统一改为字段级：

- `## 前置约束`
  - Director 锁定字段：约束事实、Owner、约束内容、影响 UNIT、初始来源锚点
  - PM 可写字段：最终 `scope_item_id`、`test_ref`、状态细化
  - 若一条 Director 约束需要在多个 UNIT 上落地，不改写原约束行；改为新增 PM 映射层（`director_constraint_id -> unit/scope/test`）或拆分出新的约束映射行，但原始 Director 约束对象保持不变
- `## 交付计划`
  - Director 锁定字段：Phase 标题、入口条件、出口条件、交付价值
  - 运行时流转字段（不锁定）：阶段状态（`NOT_STARTED → IN_PROGRESS → DONE`，由 PM 及下游按实际进度更新）
  - PM 可写字段：UNIT 表、UNIT 工作区、UNIT 状态
- `phase-{N}/prd.md`
  - Director 锁定字段：阶段目标、入口条件、出口条件
  - PM 可写字段：UNIT 索引、UNIT 闭环承接内容

任何对 Director 锁定字段的修改，都视为 handoff 漂移，必须回到 `/product-director`。

### Legacy 与锁定快照契约

Manager 的 handoff 准入依赖可机器校验的 Director 基线。M-S0 只有两种合法入口：

- 新流程：`## 产品总监确认=已通过`，且 `brief.lock.json` 与各 `phase-{N}/prd.lock.json` 存在，并和当前锁定字段内容一致
- legacy migration：只能进入“migration candidate → 显式 re-signoff → 首版 lock snapshot”子流程；未完成前不得进入 M-S1

除此之外没有第三条放行路径，Manager 也不得自行发明临时放行条件。

锁定快照契约统一如下：

- 固定工件名：`docs/{feature}/brief.lock.json` 与 `docs/{feature}/phase-{N}/prd.lock.json`
- 固定字段路径：使用稳定的 field-path grammar 指向锁定字段，不依赖自由格式段落 diff
- 固定 canonicalization：表格行序、空白、换行、列表顺序都要有统一序列化规则
- 固定比较方式：gate、review、handoff 只比较 canonical 快照，不直接比较 markdown 文本
- 固定 legacy 映射：旧格式 brief / prd 如何映射到同一份 schema，必须在实现前定义清楚

legacy 兼容规则统一如下：

1. 迁移工具只允许生成候选 metadata、差异报告和待确认快照草稿，**不得自动写入任何代表 Director 或用户已确认的字段**。
2. Director 或用户必须基于候选内容做一次显式 re-signoff，确认后才可写入 `## 产品总监确认` 或等价确认记录。
3. re-signoff 完成后，生成首版 Director 锁定快照，并标记来源为 legacy migration + re-signoff。
4. 若无法生成候选 metadata，则阻塞 Manager 流程，并回到 `/product-director` 或单独的 migration 路径处理。
5. 在 re-signoff 和首版锁定快照都完成之前，legacy brief 一律不得进入 Manager 主流程。

也就是说，legacy 支持的本质是“补齐人的确认”，不是“让工具替人确认”。

### 模板与工件变化

- 新增 `## 产品总监确认` 节，作为 D-G1 的显式确认记录
- `## 共创摘要` 增加 `技能` 列，区分 Director / Manager 各自的阶段摘要
- `## 前置约束` 改为两阶段语义：Director 定义约束事实，PM 只补执行映射字段
- `brief.md` 模板中新增 Director 锁定内容与字段级冻结规则说明
- `brief.md#交付计划` 与 `phase-{N}/prd.md` 明确区分 Director 锁定字段和 PM 可写字段
- Manager 的 completion / review 必须比对 lock 文件，发现改写 Director 锁定内容即 FAIL
- legacy brief 必须先完成 migration candidate、显式 re-signoff 和首版锁定快照生成，才能进入新 Manager 流程

---

## Reference 文件归属

除共享工件模板外，各 skill 独立维护自己的 reference 文件，不共享、不 symlink。即使内容初始相同，后续也可各自演进。模板是例外：`brief-template.md` 与 `phase-prd-template.md` 必须保持单一真源，不能在 Director / Manager 两侧分叉。

| 文件 | 归属 | 说明 |
|------|------|------|
| `conversation-guide.md` | Director 独立一份，PM 独立一份 | 初始内容相同，后续各自维护 |
| `phase-splitting-guide.md` | Director | 只有 Director 做 Phase 规划 |
| `closed-loop-unit-spec.md` | PM | 只有 PM 创建 UNIT |
| `completeness-checklist.md` | PM | 只有 PM 做完整性扫描 |
| `prd-reviewer-prompt.md` | PM | 需调整 R1 范围 |
| `architect-reviewer-prompt.md` | PM | 不变 |
| `tester-reviewer-prompt.md` | PM | 不变 |
| `templates/brief-template.md` | 共享模板真源 | Director / Manager 共同消费，同一套节结构与字段语义 |
| `templates/phase-prd-template.md` | 共享模板真源 | Director / Manager 共同消费，同一套阶段骨架语义 |

---

## 文件结构

```
shared/skills/
  product-shared/
    references/
      templates/
        brief-template.md
        phase-prd-template.md

  product-director/
    SKILL.md
    agents/openai.yaml
    references/
      conversation-guide.md
      phase-splitting-guide.md
    scripts/
      completion_check.sh          (轻量版)

  product-manager/
    SKILL.md
    agents/openai.yaml
    references/
      conversation-guide.md
      closed-loop-unit-spec.md
      completeness-checklist.md
      prd-reviewer-prompt.md      (R1 范围调整)
      architect-reviewer-prompt.md
      tester-reviewer-prompt.md
    scripts/
      completion_check.sh          (完整版)
```

旧 `shared/skills/product/` 目录只能在直接消费者全部迁移完成且验证矩阵全部 PASS 后删除；删除前必须保留兼容入口（重定向说明页）。

---

## Gate 责任边界

### Director gate

- brief.md 存在且 Director 负责的节已填写
- phase-{N}/ 目录和 prd.md 骨架存在
- 目标信号合同（机械型/观察型）格式正确
- 共创摘要前 4 个阶段已填
- 产品总监确认节已填写
- `brief.lock.json` 存在且与 brief.md 中 Director 锁定字段一致
- 每个 `phase-{N}/prd.lock.json` 存在且与对应 prd.md 骨架字段一致
- **不检查**：UNIT 文件、AC、审查结论、交付确认

### Manager gate

- 前置检查：Director 工件存在且确认门通过，`brief.lock.json` 和 `phase-{N}/prd.lock.json` 存在
- 继承现有 product gate 中与 UNIT、AC、审查结论、交付确认有关的完整校验职责
- 新增：Director 锁定节快照校验 — 比对 `brief.lock.json` / `prd.lock.json` 与当前 brief.md / prd.md 中 Director 锁定字段，发现 PM 改写即 FAIL
- 新增：`scope_item_id` 必须已细化为 `SCOPE-P{N}U{M}-{seq}` 格式，且禁止把 Director 阶段的占位值视为最终 join key

---

## 下游影响

### 核心工件兼容边界

拆分后，`brief.md + prd.md + units/UNIT-*.md` 的核心业务载荷和消费关系保持兼容，下游仍然围绕同一组业务工件工作；但这不是“结构完全不变”。

本次设计明确引入了以下结构性变化：

- `brief.md` 新增 `## 产品总监确认` 节
- `## 共创摘要` 新增 `技能` 列
- `brief.md` 与 `phase-{N}/prd.md` 新增 Director 锁定字段与 PM 可写字段的边界语义
- 新增 `brief.lock.json` 与 `phase-{N}/prd.lock.json` 两类 sidecar 工件

因此，只消费业务内容的下游可视为“核心兼容”；凡是依赖节名、表格列、文件枚举或元信息结构的消费者，都必须纳入迁移审计。

### 迁移范围

这次拆分会影响以下直接消费者，后续计划必须覆盖 repo 级全文检索与迁移：

- small-chain / skill-chain contract
- hook registry、active-skill state tracking、stop dispatch
- `install.sh` 与 runtime probe
- 下游 skills 的流程导航和上游引用
- tests、eval scenarios、eval graders 中直接依赖 `/product` 的断言

### 运行时迁移设计

运行时需要满足以下原则：

- 过渡期 `registry.json` 中保留 3 个相关条目：`product-director`、`product-manager`，以及兼容入口 `product`
- 兼容入口 `product` 必须明确标记为 `supported: false`，只负责重定向说明，不再承载旧的混合职责
- 兼容入口不参与 completion gate、active-skill state tracking 和 stop dispatch；用户误输 `/product` 也不得破坏已有受管 skill 状态
- stop dispatch、installer、runtime probe 都要按新 skill 名更新
- 只有在直接消费者迁移完成且验证矩阵通过后，旧 `shared/skills/product/` 才能删除

### 流程导航

```text
/product-director → /product-manager → /design → /test-design → /tech-lead → /delivery-owner
```

---

## 关键风险与缓解

| 风险 | 缓解措施 |
|------|---------|
| repo 级 `/product` 消费者遗漏 | 先做 repo 级全文检索，建立验证矩阵，并在迁移前后各跑一轮 live-source 检索兜底 |
| brief.md 双方写入冲突 | D-G1 后生成 `brief.lock.json` / `prd.lock.json`；PM 只能写允许补充的节/字段；M-S8/M-G1 通过 lock 文件做差异检查 |
| `scope_item_id` 过早生成又被改写 | Director 不再输出 `SCOPE-*` 占位值；PM 在 UNIT 归属确定后一次性生成最终 ID |
| PM 缺少 Director 对话中的隐性信息 | 这是设计意图（从工件出发消除噪音），但必须通过锁定节 + 共创摘要避免 PM 反向改写上游意图 |
| 既有项目兼容 | PM 的 M-S0 检测旧格式 brief.md（无总监确认节），必须先进入 migration + re-signoff 流程，未完成前阻塞 |
| Phase 阶段状态流转被阻断 | 阶段状态不纳入 Director 锁定字段，定义为运行时流转字段，由 PM 及下游按 `NOT_STARTED → IN_PROGRESS → DONE` 更新 |
| lock 快照工件缺失导致 PM 准入悬空 | `brief.lock.json` / `prd.lock.json` 是 Director D-G1 的正式产出，Director gate 必须强制校验其存在与一致性；schema 冻结前不得编码 gate 逻辑 |
| 运行时迁移断裂 | hook dispatcher、active-skill state、installer 均需处理 `product → product-director/product-manager` 映射；过渡期保留兼容入口，验证矩阵覆盖运行时路径 |
| 升级中活跃 `/product` 会话 fail-open | 两层防护：(1) `codex_user_prompt_submit.py` 行为变更——unsupported skill 不再删除已有 state，消除跨 skill gate 旁路；(2) installer 检测到旧 `product` state 时**阻塞升级**，防止残留 state 在新 registry 下被 stop_dispatch 静默放行。`/product` 是 `manual_only`，Codex 侧活跃 session 概率极低 |
| lock schema 未定义时 gate 逻辑各自发明 | 必须先冻结 schema，再开始实现 Director / Manager 的 gate 与 handoff 校验 |
