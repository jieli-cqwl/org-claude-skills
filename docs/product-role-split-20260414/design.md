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

- M-S0：读取 Director 工件时，记录 Director 锁定内容快照；若 `## 产品总监确认` 不是已通过，停止执行。
- M-S4~M-S9：任何需要修改 `brief.md` 的步骤，都必须限定在 PM 可写节或 PM 可写字段。
- M-S8：产品评审新增一条显式检查：Director 锁定内容是否与 D-G1 快照一致，覆盖 `brief.md` 锁定节、`brief.md#交付计划` Phase 级结构字段（不含阶段状态）和 `phase-{N}/prd.md` Director 骨架字段。校验源为 `brief.lock.json` / `prd.lock.json`。
- M-G1：若存在 PM 改写 Director 锁定内容的差异，Verdict 直接 FAIL，不允许带 WARN 继续。
- `/analyze`：只作为跨工件补充审视，不再承担 handoff 漂移的唯一防线。

### HARD-GATE

| 编号 | 规则 | 来源 |
|------|------|------|
| M-HG-0 | 总监工件缺失或确认门未通过时不得启动；legacy brief 必须先补齐兼容标记后才能进入 PM | 新增 |
| M-HG-2 | UNIT 必须有闭环定义 | 保留自 HG-2 |
| M-HG-3 | 完成时必须有完整工件集 | 保留自 HG-3 |
| M-HG-4 | 审查结论无未解决 FAIL | 保留自 HG-4 |
| M-HG-5 | M-S1~M-S9 每步遵循共创模式 | 保留自 HG-5 |
| M-HG-6 | 显式交付确认 | 保留自 HG-6 |
| M-HG-7 | 禁止跳步 | 保留自 HG-7 |
| M-HG-8 | 上游问题标记未解决时不得声称完成 | 新增 |
| M-HG-9 | 不得改写 Director 锁定内容；允许修改的共享节/字段必须受字段级约束 | 新增 |
| M-HG-10 | 未完成 legacy backfill/adapter 的旧格式 brief 不得直接按新 Manager 流程放行 | 新增 |

### 反馈回路

| 问题类型 | 处理方式 |
|----------|---------|
| 小问题（可假设继续） | 记录在 brief.md `## 关键假设` 中，标注 `[PM-ASSUMPTION]` |
| 大问题（Phase 边界不合理、范围遗漏、规则模糊、Director 锁定内容需变更、前置约束事实需改写） | 停止执行，向用户说明问题，建议回到 `/product-director` 调整 |

---

## brief.md 节归属

brief-template.md 不拆分。两个 skill 写同一个文件，按节划分所有权：

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

### Legacy 兼容策略

legacy brief（无 `## 产品总监确认`、无快照元数据）不允许直接绕过 M-HG-0 进入新 Manager 流程。唯一兼容路径是“迁移元数据 + 显式 re-signoff”：

1. 迁移工具只允许生成候选 metadata / 差异报告 / 待确认快照草稿，**不得自动写入任何代表 Director 或用户已确认的字段**。
2. Director 或用户必须基于候选 metadata 做一次显式 re-signoff，确认后才写入 `## 产品总监确认` 或等价确认记录。
3. re-signoff 完成后，生成首版 Director 锁定内容快照，并标记来源为 legacy migration + re-signoff。
4. 在 brief 或 metadata 中写明当前 legacy mode 的确认来源、哪些字段视为 Director 锁定字段。
5. 只有 re-signoff + 快照都完成后，PM 才能继续执行；否则一律阻塞。

也就是说，legacy 支持不是“无确认门也可继续”，也不是“迁移工具自动补齐确认门”，而是“迁移工具只给候选，最终确认必须由人完成”。

### Legacy 工件接收（M-S0）

M-S0 对旧格式 brief 的处理固定为两步：

- 能生成候选 migration metadata 的，先产出候选内容并停在 re-signoff；**不得自动放行到 Manager 流程**。
- 不能生成候选 metadata 的，停止执行并要求回到 `/product-director` 或专门的 migration 步骤。

Manager 不得自行发明临时放行条件，也不得把 migration 生成的候选标记当成已确认基线。

### 锁定快照契约

Director 锁定快照不能靠自由格式 markdown diff 临时实现，必须先定义可机器校验的 authoritative contract：

- 固定存放位置：例如 `brief.lock.json` / `phase-{N}/prd.lock.json` 或等价 canonical metadata 文件
- 固定字段路径：使用稳定的 field-path grammar 指向锁定内容，而不是按段落文本做模糊匹配
- 固定 canonicalization：表格行序、空白、换行、列表顺序都要有统一序列化规则
- 固定 legacy 映射：legacy artifact 如何映射到同一份快照 schema，必须在迁移设计里明示

`completion_check.sh`、review 和 handoff gate 只比较这份 canonical 快照，不直接比较自由编辑的 markdown 文本。

在这套快照契约未定义前，不应声称“锁定快照校验”已具备可实现性。

### Legacy 工件接收（M-S0）补充

M-S0 需要先判断：当前 feature 是标准新流程，还是 legacy migration。

- 标准新流程：要求 `## 产品总监确认=已通过` + canonical 锁定快照存在。
- legacy migration：只允许进入“候选 metadata + re-signoff”子流程；未 re-signoff 前不得继续到 M-S1。

这样 M-S0、M-HG-0 和 legacy 兼容策略保持单一口径。

Manager 不得自行发明临时放行条件。

### 锁定快照契约命名建议

为减少实现歧义，设计阶段先约定两个最小工件名：

- `docs/{feature}/brief.lock.json`
- `docs/{feature}/phase-{N}/prd.lock.json`

其中保存 Director 锁定字段的 canonical 快照、字段路径和值摘要；后续 gate 直接消费它们。

若最终命名调整，也必须保持“单一 canonical 文件 + 单一字段路径语法”的原则。

### Legacy 风险修订

legacy 兼容不再描述为“按遗留项目处理”，而是“必须先进入 migration + re-signoff 流程”。

Manager 不得自行发明临时放行条件。

### Legacy 文案统一要求

文档内所有 legacy 相关表述必须统一为：

- 迁移工具可生成候选 metadata / 快照草稿
- 不得自动写入确认门
- 必须显式 re-signoff
- re-signoff 前不得进入 Manager 主流程

禁止再出现“旧格式 brief 可直接继续”“按遗留项目处理即可”这类宽松表述。

### Legacy 工件接收（M-S0）一句话规则

旧格式 brief = 先 migration + re-signoff，再进入 Manager；否则阻塞。

### Legacy 风险项

| 情况 | 处理 |
|------|------|
| 旧 brief 无确认门 | 进入 migration + re-signoff；未完成前阻塞 |
| 旧 brief 有内容但无快照 | 进入 migration + re-signoff；未完成前阻塞 |
| migration 只能给候选快照 | 等待 Director/用户确认，不得自动放行 |
| migration 无法生成候选 | 回到 `/product-director` 或专门 migration 流程 |

### Legacy 兼容结论

legacy 支持的本质是“补齐人的确认”，不是“让工具替人确认”。

### Legacy 风险与缓解

- 风险：迁移工具越权写入确认门
- 缓解：明确禁止自动写入确认字段，必须 re-signoff

- 风险：旧文档缺少 canonical 锁定快照导致 gate 无法稳定判断
- 缓解：先定义 `brief.lock.json` / `prd.lock.json` 契约，再实现 gate

### Legacy 相关实施要求

- Phase 0 盘点时同步识别哪些 feature 是 legacy，是否需要 migration
- Phase 4 模板更新时补齐 `*.lock.json` 契约说明
- Phase 6 验证时必须覆盖 legacy migration + re-signoff 路径

### Legacy 相关完成标准

- 无自动补确认门路径
- 有 canonical 锁定快照契约
- legacy 只能经 re-signoff 放行

### Legacy 相关一句话总结

legacy 能迁移，但不能自动被“视为已确认”。

### Legacy 风险说明（替换旧表述）

旧格式 brief 不是“按遗留项目处理即可”，而是“必须先补齐 migration + re-signoff 才能进入新链路”。

### Legacy 风险在风险表中的表述

见下方“关键风险与缓解”已同步更新。

### Legacy 文案收口

本节为 legacy 的唯一真源；其他章节不得再给出更宽松解释。

### Legacy 工件接收（M-S0）结束语

旧格式 brief = 阻塞，直到 re-signoff 完成。

### 快照契约结束语

锁定边界要先 canonical，再 gate。

### Legacy / 快照联合约束

legacy migration 与锁定快照是同一条防线：没有人的确认，就没有可冻结的 canonical 基线。

### Manager 流程入口结论

M-S0 的准入条件统一为：
- 新流程：确认门 + canonical 锁定快照
- legacy：migration 候选 + re-signoff 完成后生成 canonical 锁定快照

除此之外没有第三条放行路径。

Manager 不得自行发明临时放行条件。 

### 模板变更

1. 新增 `## 产品总监确认` 节（在 `## 共创摘要` 前）：
   ```markdown
   ## 产品总监确认
   - 确认状态: {待确认}
   - 确认时间: YYYY-MM-DD HH:mm
   ```
2. `## 共创摘要` 增加 `技能` 列（Director/Manager），7 个阶段名保持不变
3. `## 前置约束` 模板改为两阶段语义：Director 负责约束事实/Owner/内容与初始来源锚点，PM 仅补 UNIT 归属、最终 `scope_item_id=SCOPE-P{N}U{M}-{seq}`、`test_ref`、状态字段
4. `brief.md` 模板中新增“Director 锁定内容 + 字段级冻结规则”说明，供 PM 流程和 review/gate 直接校验
5. `brief.md#交付计划` 与 `phase-{N}/prd.md` 增加 Director 锁定字段说明，防止 PM 静默改写 Phase 基线
6. `product-manager` 的 completion/review 需要对 Director 锁定内容做差异检查，发现改写即 FAIL
7. legacy brief 必须先经 backfill/adapter 补齐确认门与锁定快照，才能进入新 Manager 流程

---

## Reference 文件归属

各 skill 独立维护自己的 reference 文件，不共享、不 symlink。即使内容初始相同，后续各自独立演进。

| 文件 | 归属 | 说明 |
|------|------|------|
| `conversation-guide.md` | Director 独立一份，PM 独立一份 | 初始内容相同，后续各自维护 |
| `phase-splitting-guide.md` | Director | 只有 Director 做 Phase 规划 |
| `closed-loop-unit-spec.md` | PM | 只有 PM 创建 UNIT |
| `completeness-checklist.md` | PM | 只有 PM 做完整性扫描 |
| `prd-reviewer-prompt.md` | PM | 需调整 R1 范围 |
| `architect-reviewer-prompt.md` | PM | 不变 |
| `tester-reviewer-prompt.md` | PM | 不变 |
| `templates/brief-template.md` | Director 独立一份，PM 独立一份 | 初始内容相同，后续各自维护 |
| `templates/phase-prd-template.md` | Director 独立一份，PM 独立一份 | 初始内容相同，后续各自维护 |

---

## 文件结构

```
shared/skills/
  product-director/
    SKILL.md
    agents/openai.yaml
    references/
      conversation-guide.md
      phase-splitting-guide.md
      templates/
        brief-template.md
        phase-prd-template.md
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
      templates/
        brief-template.md
        phase-prd-template.md
    scripts/
      completion_check.sh          (完整版)
```

旧 `shared/skills/product/` 目录只能在 Phase 0 盘点清零、直接消费者全部迁移完成且验证矩阵全部 PASS 后删除；删除前必须保留可运行的兼容入口或转发层。

---

## Completion Check 脚本拆分

### Director 版（轻量）

- brief.md 存在且 Director 负责的节已填写
- phase-{N}/ 目录和 prd.md 骨架存在
- 目标信号合同（机械型/观察型）格式正确
- 共创摘要前 4 个阶段已填
- 产品总监确认节已填写
- `brief.lock.json` 存在且与 brief.md 中 Director 锁定字段一致
- 每个 `phase-{N}/prd.lock.json` 存在且与对应 prd.md 骨架字段一致
- **不检查**：UNIT 文件、AC、审查结论、交付确认

### PM 版（完整）

- 前置检查：Director 工件存在且确认门通过，`brief.lock.json` 和 `phase-{N}/prd.lock.json` 存在
- 继承现有 `completion_check.sh` 的大部分逻辑：
  - UNIT 文件验证（闭环、AC、排除项）
  - UNIT 交叉验证（3 层）
  - 交付计划 UNIT 表验证
  - 审查结论验证
  - 共创摘要全 7 阶段验证
  - 交付确认验证
- 新增：Director 锁定节快照校验 — 比对 `brief.lock.json` / `prd.lock.json` 与当前 brief.md / prd.md 中 Director 锁定字段，发现 PM 改写即 FAIL
- 新增：`scope_item_id` 必须已细化为 `SCOPE-P{N}U{M}-{seq}` 格式，且禁止把 Director 阶段的占位值视为最终 join key

---

## 下游影响

### 工件契约不变

downstream 消费的 brief.md + prd.md + units/UNIT-*.md 格式完全不变。拆分对下游透明。

### 需要更新的引用

以下仅列一线运行面，实施前必须做 repo 级全文检索，覆盖所有 `/product`、`shared/skills/product/**`、`name: product`、`"skill": "product"` 直接消费者；未纳入清单的运行时引用不得假定为“无影响”。

| 文件 | 变更 |
|------|------|
| `contracts/skill-chain.yaml` | 上游链路从单个 `product` 调整为 Director→Manager 两段，删除旧 product 定义 |
| `shared/hooks/registry.json` | `"skill": "product"` → 拆为 `"product-director"` + `"product-manager"` 两条；删除旧 `product` 条目 |
| `shared/skills/design/SKILL.md` | 上游缺失提示改为"先执行 `/product-manager`"；流程导航更新 |
| `shared/skills/test-design/SKILL.md` | 流程导航更新 |
| `shared/skills/tech-lead/SKILL.md` | 上游缺失提示改为"先执行 `/product-manager`"；流程导航更新 |
| `shared/skills/delivery-owner/SKILL.md` | 流程导航更新 |
| `shared/skills/design/references/decision-templates.md` | `../product/...` 引用改到新的共享/目标路径 |
| `shared/skills/fix/SKILL.md` | `REQUIREMENT_AMBIGUITY` 的回退目标从 `/product` 改为明确的 `/product-director` 或 `/product-manager` |
| `tests/test-codex-skill-adapter.sh` | codex runtime 中 `product` 安装/追踪断言改为新角色断言 |
| `tests/test-product-eval-contract.sh` | product eval 合同按新 skill 拆分重写 |
| `tests/test-product-stability-guidance-contract.sh` 等直接依赖 `shared/skills/product/**` 的测试 | 同步迁移为新路径断言 |
| `tools/eval/scenarios/**` 与 `tools/eval/graders/**` | 拆成 Director/Manager 两套场景 |

### 迁移策略

采用**迁移完成后再删除旧入口**：先更新 contracts/hooks/tests/evals/skills 的路径与引用，并保留可运行的兼容入口或转发层；仅当 `/product` 与 `shared/skills/product/**` 的直接消费者全部清零且验证矩阵全部 PASS 后，才删除旧 `shared/skills/product/` 目录。

### 流程导航

```text
/product-director → /product-manager → /design → /test-design → /tech-lead → /delivery-owner
```

---

## 实施顺序

### Phase 0：迁移盘点
1. repo 级全文检索 `/product`、`shared/skills/product/**`、`name: product`、`"skill": "product"` 引用，覆盖 contracts、hooks、downstream skills、tests、evals、runtime probes 与文档样例
2. 产出完整引用清单，逐条标注迁移目标（改为 `product-director` / `product-manager` / 删除）
3. 补齐验证矩阵：每个引用点对应一个验证用例，确保切换时能覆盖 contracts/hooks/tests/evals/流程导航
4. 验证矩阵必须在 Phase 5 删除旧目录前全部 PASS，否则阻塞删除

### Phase 1：准备目录结构
1. 创建 `shared/skills/product-director/` 和 `shared/skills/product-manager/` 目录

### Phase 2：Product Director
1. 基于现有 SKILL.md S1-S6 编写 `product-director/SKILL.md`
2. 复制/移动对应 reference 文件
3. 编写轻量版 `completion_check.sh`（含 lock 文件生成与校验逻辑）
4. 实现 D-G1 自动生成 `brief.lock.json` / `phase-{N}/prd.lock.json` 的逻辑
5. 创建 `openai.yaml`

### Phase 3：Product Manager
1. 编写 `product-manager/SKILL.md`（包含新步骤 M-S0~M-S3 + 改造后的 M-S4~M-S9）
2. 移动 UNIT 相关 reference 文件
3. 调整 `prd-reviewer-prompt.md` R1 范围
4. 编写完整版 `completion_check.sh`（继承现有逻辑，并新增 Director 锁定内容/字段级差异检查与 legacy backfill 校验）
5. 创建 `openai.yaml`

### Phase 4：模板与共享工件更新
1. brief-template.md 增加 `## 产品总监确认` 节
2. brief-template.md `## 共创摘要` 增加 `技能` 列
3. brief-template.md / gate 明确 Director 锁定内容、字段级冻结规则与 PM 可写边界
4. brief-template.md `## 前置约束` 改为 Director 约束事实 + PM 映射字段协作模型
5. `brief.md#交付计划` 与 `phase-prd-template.md` 标注 Director 锁定字段与 PM 可写字段
6. 增加 legacy backfill/adapter 所需的确认门与快照元数据说明
7. conversation-guide.md 去除步骤号硬编码

### Phase 5：下游与基础设施更新
1. 按 Phase 0 盘点结果更新 contracts/hooks/tests/evals/下游 skill 文案与引用
2. registry.json 拆分条目，删除旧 `product` 条目
3. 更新 design/test-design/tech-lead/delivery-owner/fix 的流程导航和上游引用
4. 运行 Phase 0 验证矩阵，全部 PASS 后再执行下一步
5. 删除 `shared/skills/product/` 目录
6. 再次运行验证矩阵，确认删除后无断裂

### Phase 6：验证
1. Dry-run Director 处理一个示例需求，确认 `brief.lock.json` / `prd.lock.json` 正确生成
2. Dry-run PM 处理 Director 产出，确认 M-S0 正确读取 lock 文件
3. 验证 PM 无法改写 Director 锁定节；若改写则 gate/review 必须 FAIL
4. 验证 Phase 阶段状态可被下游正常流转（`NOT_STARTED → IN_PROGRESS → DONE`）
5. 验证下游 skill、contracts、hooks、tests、evals 可正常消费新结构
6. 验证两个 completion_check.sh 正确工作
7. repo 级全文检索确认无残留 `/product` 或 `shared/skills/product/` 引用

---

## 关键风险与缓解

| 风险 | 缓解措施 |
|------|---------|
| repo 级 `/product` 消费者遗漏 | Phase 0 产出完整引用清单 + 验证矩阵；Phase 5 删除前后各跑一轮验证矩阵；Phase 6 再做全文检索兜底 |
| brief.md 双方写入冲突 | D-G1 后生成 `brief.lock.json` / `prd.lock.json`；PM 只能写允许补充的节/字段；M-S8/M-G1 通过 lock 文件做差异检查 |
| `scope_item_id` 过早生成又被改写 | Director 不再输出 `SCOPE-*` 占位值；PM 在 UNIT 归属确定后一次性生成最终 ID |
| PM 缺少 Director 对话中的隐性信息 | 这是设计意图（从工件出发消除噪音），但必须通过锁定节 + 共创摘要避免 PM 反向改写上游意图 |
| 既有项目兼容 | PM 的 M-S0 检测旧格式 brief.md（无总监确认节），必须先进入 migration + re-signoff 流程，未完成前阻塞 |
| Phase 阶段状态流转被阻断 | 阶段状态不纳入 Director 锁定字段，定义为运行时流转字段，由 PM 及下游按 `NOT_STARTED → IN_PROGRESS → DONE` 更新 |
| lock 快照工件缺失导致 PM 准入悬空 | `brief.lock.json` / `prd.lock.json` 是 Director D-G1 的正式产出，Director completion_check 强制校验其存在与一致性 |

---

## 关键文件清单

| 文件 | 操作 |
|------|------|
| `contracts/skill-chain.yaml` | 调整链路定义，删除旧 product 条目 |
| `shared/hooks/registry.json` | 拆分 product 条目，删除旧条目 |
| `shared/skills/product/` | 整体删除 |
| `shared/skills/product/scripts/completion_check.sh` | 作为拆分参考源，迁移逻辑到 Director/Manager 两个版本 |
| `shared/skills/product/references/templates/brief-template.md` | 增加产品总监确认节、Director 锁定节说明、前置约束两阶段语义、共创摘要列 |
| `shared/skills/product/references/prd-reviewer-prompt.md` | R1 范围调整，加入 Director 锁定节漂移检查 |
| `shared/skills/product/references/conversation-guide.md` | 去除步骤号硬编码 |
| `shared/skills/design/SKILL.md` | 更新上游引用和流程导航 |
| `shared/skills/test-design/SKILL.md` | 更新流程导航 |
| `shared/skills/tech-lead/SKILL.md` | 更新上游引用和流程导航 |
| `shared/skills/delivery-owner/SKILL.md` | 更新流程导航 |
| `shared/skills/design/references/decision-templates.md` | 更新对 `product` reference 的相对引用 |
| `shared/skills/fix/SKILL.md` | 更新需求歧义回退目标 |
| `tests/test-codex-skill-adapter.sh` | 更新 codex runtime `product` 断言 |
| `tests/test-product-eval-contract.sh` | 更新 eval 合同 |
| 其他 `tests/**`、`tools/eval/**` 中直接引用 `product` 的文件 | 按 Phase 0 盘点结果同步迁移 |

