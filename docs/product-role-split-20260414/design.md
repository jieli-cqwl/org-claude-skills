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
| D-G1 | 总监确认门 | 全共创 | 确认：根问题、目标、范围、Phase 规划。**不含 UNIT 清单** |

### 产出

- `docs/{feature}/brief.md`（填写总监负责的节）
- `docs/{feature}/phase-{N}/` 目录结构
- `docs/{feature}/phase-{N}/prd.md` 骨架（阶段目标 + 进退条件，UNIT 索引留空）

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

D-G1 通过后，以下 `brief.md` 节进入锁定态，PM 只读不可改：

- `## 业务背景与根问题`
- `## 目标与成功标准`
- `## 引用锚点合同`
- `## 业务术语`
- `## 业务对象`
- `## 当前业务流程`
- `## 目标业务流程`
- `## 范围 / 本期不交付`
- `## 业务规则`
- `## 影响范围`
- `## 非功能需求`
- `## 全局排除项`
- `## 产品总监确认`

PM 允许补充的共享节仅限：`## 关键假设`（只能追加 `[PM-ASSUMPTION]`）、`## 用户角色与核心场景`、`## 已排查并排除的潜在问题`、`## 共创摘要`、`## 交付计划`。

### 漂移阻断规则

- M-S0：读取 Director 工件时，记录 Director 锁定节快照；若 `## 产品总监确认` 不是已通过，停止执行。
- M-S4~M-S9：任何需要修改 `brief.md` 的步骤，都必须限定在 PM 可写节。
- M-S8：产品评审新增一条显式检查：Director 锁定节内容是否与 D-G1 快照一致。
- M-G1：若存在 PM 改写 Director 锁定节的差异，Verdict 直接 FAIL，不允许带 WARN 继续。
- `/analyze`：只作为跨工件补充审视，不再承担 handoff 漂移的唯一防线。

### HARD-GATE

| 编号 | 规则 | 来源 |
|------|------|------|
| M-HG-0 | 总监工件缺失或确认门未通过时不得启动 | 新增 |
| M-HG-2 | UNIT 必须有闭环定义 | 保留自 HG-2 |
| M-HG-3 | 完成时必须有完整工件集 | 保留自 HG-3 |
| M-HG-4 | 审查结论无未解决 FAIL | 保留自 HG-4 |
| M-HG-5 | M-S1~M-S9 每步遵循共创模式 | 保留自 HG-5 |
| M-HG-6 | 显式交付确认 | 保留自 HG-6 |
| M-HG-7 | 禁止跳步 | 保留自 HG-7 |
| M-HG-8 | 上游问题标记未解决时不得声称完成 | 新增 |

### 反馈回路

| 问题类型 | 处理方式 |
|----------|---------|
| 小问题（可假设继续） | 记录在 brief.md `## 关键假设` 中，标注 `[PM-ASSUMPTION]` |
| 大问题（Phase 边界不合理、范围遗漏、规则模糊） | 停止执行，向用户说明问题，建议回到 `/product-director` 调整 |

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
| 前置约束 | Director 先写约束事实与 `CON-*` / `DIR-CON-P{N}-{seq}` 来源，PM 在 UNIT 归属明确后一次性生成最终 `scope_item_id=SCOPE-P{N}U{M}-{seq}` | D-S5 / M-S4 |
| 待设计决策 | **PM** | M-S6 |
| 已排查并排除的潜在问题 | Director 初始，PM 补充 | D-S5 / M-S7 |
| 产品总监确认 | Director | D-G1 |
| 共创摘要 | **双方**（Director 填前 4 阶段，PM 填后 3 阶段） | 各自步骤中 |
| 交付确认 | **PM** | M-S9 |
| 审查结论 | **PM** | M-S8 |
| 交付计划 | Director 写 Phase 骨架，**PM 填 UNIT 表** | D-S6 / M-S4+M-S9 |
| 交接项 | **PM** | M-S9 |

### 模板变更

1. 新增 `## 产品总监确认` 节（在 `## 共创摘要` 前）：
   ```markdown
   ## 产品总监确认
   - 确认状态: {待确认}
   - 确认时间: YYYY-MM-DD HH:mm
   ```
2. `## 共创摘要` 增加 `技能` 列（Director/Manager），7 个阶段名保持不变
3. `## 前置约束` 模板改为两阶段语义：Director 产物只允许 `CON-*` / `DIR-CON-P{N}-{seq}` 作为来源锚点，最终 `scope_item_id=SCOPE-P{N}U{M}-{seq}` 仅由 PM 在 UNIT 归属确定后写入一次
4. `brief.md` 模板中新增“Director 锁定节”说明，供 PM 流程和 review/gate 直接校验
5. `product-manager` 的 completion/review 需要对 Director 锁定节做差异检查，发现改写即 FAIL

---

## Reference 文件归属

| 文件 | 归属 | 说明 |
|------|------|------|
| `conversation-guide.md` | **共享** | 两个 skill 都用同一套共创模式协议。各 skill 目录各放一份 |
| `phase-splitting-guide.md` | Director | 只有 Director 做 Phase 规划 |
| `closed-loop-unit-spec.md` | PM | 只有 PM 创建 UNIT |
| `completeness-checklist.md` | PM | 只有 PM 做完整性扫描 |
| `prd-reviewer-prompt.md` | PM | 需调整 R1 范围 |
| `architect-reviewer-prompt.md` | PM | 不变 |
| `tester-reviewer-prompt.md` | PM | 不变 |
| `templates/brief-template.md` | **共享** | 各 skill 目录各放一份 |
| `templates/phase-prd-template.md` | **共享** | 各 skill 目录各放一份 |

---

## 文件结构

```
shared/skills/
  product-director/
    SKILL.md
    agents/openai.yaml
    references/
      conversation-guide.md       (共享副本)
      phase-splitting-guide.md
      templates/
        brief-template.md          (共享副本)
        phase-prd-template.md      (共享副本)
    scripts/
      completion_check.sh          (轻量版)

  product-manager/
    SKILL.md
    agents/openai.yaml
    references/
      conversation-guide.md       (共享副本)
      closed-loop-unit-spec.md
      completeness-checklist.md
      prd-reviewer-prompt.md      (R1 范围调整)
      architect-reviewer-prompt.md
      tester-reviewer-prompt.md
      templates/
        brief-template.md          (共享副本)
        phase-prd-template.md      (共享副本)
    scripts/
      completion_check.sh          (完整版)

  product/
    SKILL.md                       (兼容入口或最终 stub，取决于迁移阶段)
```

---

## Completion Check 脚本拆分

### Director 版（轻量）

- brief.md 存在且 Director 负责的节已填写
- phase-{N}/ 目录和 prd.md 骨架存在
- 目标信号合同（机械型/观察型）格式正确
- 共创摘要前 4 个阶段已填
- 产品总监确认节已填写
- **不检查**：UNIT 文件、AC、审查结论、交付确认

### PM 版（完整）

- 前置检查：Director 工件存在且确认门通过
- 继承现有 `completion_check.sh` 的大部分逻辑：
  - UNIT 文件验证（闭环、AC、排除项）
  - UNIT 交叉验证（3 层）
  - 交付计划 UNIT 表验证
  - 审查结论验证
  - 共创摘要全 7 阶段验证
  - 交付确认验证
- 新增：Director 锁定节快照校验，发现 PM 改写即 FAIL
- 新增：`scope_item_id` 必须已细化为 `SCOPE-P{N}U{M}-{seq}` 格式，且禁止把 Director 阶段的占位值视为最终 join key

---

## 下游影响

### 工件契约不变

downstream 消费的 brief.md + prd.md + units/UNIT-*.md 格式完全不变。拆分对下游透明。

### 需要更新的引用

以下仅列一线运行面，实施前必须做 repo 级全文检索，覆盖所有 `/product`、`shared/skills/product/**`、`name: product`、`"skill": "product"` 直接消费者；未纳入清单的运行时引用不得假定为“无影响”。

| 文件 | 变更 |
|------|------|
| `contracts/skill-chain.yaml` | 上游链路从单个 `product` 调整为 Director→Manager 两段，明确 alias/迁移策略 |
| `shared/hooks/registry.json` | `"skill": "product"` → 拆为 `"product-director"` + `"product-manager"` 两条；如保留 `/product` 兼容入口，也需显式登记 |
| `shared/skills/design/SKILL.md` | 上游缺失提示改为"先执行 `/product-manager`"；流程导航更新 |
| `shared/skills/test-design/SKILL.md` | 流程导航更新 |
| `shared/skills/tech-lead/SKILL.md` | 上游缺失提示改为"先执行 `/product-manager`"；流程导航更新 |
| `shared/skills/delivery-owner/SKILL.md` | 流程导航更新 |
| `shared/skills/design/references/decision-templates.md` | `../product/...` 引用改到新的共享/目标路径 |
| `shared/skills/fix/SKILL.md` | `REQUIREMENT_AMBIGUITY` 的回退目标从 `/product` 改为明确的 `/product-director` 或 `/product-manager` |
| `tests/test-codex-skill-adapter.sh` | codex runtime 中 `product` 安装/追踪断言改为新角色或兼容别名断言 |
| `tests/test-product-eval-contract.sh` | product eval 合同按新 skill 拆分或为 `/product` 兼容入口重写 |
| `tests/test-product-stability-guidance-contract.sh` 等直接依赖 `shared/skills/product/**` 的测试 | 同步迁移为新路径或兼容层断言 |
| `tools/eval/scenarios/**` 与 `tools/eval/graders/**` | 明确继续评估 `/product` 兼容入口，还是拆成 Director/Manager 两套场景 |

### 迁移兼容策略

在所有直接消费者完成迁移前，`product` 不能只剩“文案级重定向 stub”。必须二选一并在实施阶段固定：

1. **全量迁移后切换**：一次性更新 contracts/hooks/tests/evals/skills 文案与路径，再移除旧 `product` 入口。
2. **兼容别名过渡**：保留 `/product` 作为可运行兼容入口，由它显式编排/转发到 `product-director` + `product-manager`，直到全文检索命中的直接消费者全部完成迁移。

无论选哪种，验证范围都必须覆盖 contracts、hooks、tests、evals 和运行时导航，而不是只改 4 个下游 skill 文件。

### 流程导航

```text
/product-director → /product-manager → /design → /test-design → /tech-lead → /delivery-owner
```

若过渡期保留 `/product`，则需补充说明其语义是“兼容入口/编排入口”，不是继续保留旧职责混合实现。

---

## 实施顺序

### Phase 0：迁移盘点与切换策略
1. repo 级全文检索 `/product`、`shared/skills/product/**`、`name: product`、`"skill": "product"` 引用，区分运行时消费者、测试、eval、文档样例
2. 明确采用“全量迁移后切换”还是“兼容别名过渡”
3. 先补齐验证矩阵，确保切换时能覆盖 contracts/hooks/tests/evals/流程导航

### Phase 1：准备目录结构
1. 创建 `shared/skills/product-director/` 和 `shared/skills/product-manager/` 目录

### Phase 2：Product Director
1. 基于现有 SKILL.md S1-S6 编写 `product-director/SKILL.md`
2. 复制/移动对应 reference 文件
3. 编写轻量版 `completion_check.sh`
4. 创建 `openai.yaml`

### Phase 3：Product Manager
1. 编写 `product-manager/SKILL.md`（包含新步骤 M-S0~M-S3 + 改造后的 M-S4~M-S9）
2. 移动 UNIT 相关 reference 文件
3. 调整 `prd-reviewer-prompt.md` R1 范围
4. 编写完整版 `completion_check.sh`（继承现有逻辑，并新增 Director 锁定节差异检查）
5. 创建 `openai.yaml`

### Phase 4：模板与共享工件更新
1. brief-template.md 增加 `## 产品总监确认` 节
2. brief-template.md `## 共创摘要` 增加 `技能` 列
3. brief-template.md / gate 明确 Director 锁定节与 PM 可写边界
4. brief-template.md `## 前置约束` 改为 Director 来源锚点 + PM 一次性生成最终 `scope_item_id`
5. conversation-guide.md 去除步骤号硬编码

### Phase 5：下游与基础设施更新
1. 按 Phase 0 盘点结果更新 contracts/hooks/tests/evals/下游 skill 文案与引用
2. registry.json 拆分条目，并同步兼容入口策略
3. 更新 design/test-design/tech-lead/delivery-owner/fix 的流程导航和上游引用
4. 只有在兼容策略与消费者迁移完成后，才允许将现有 `product/SKILL.md` 改为 stub 或兼容入口

### Phase 6：验证
1. Dry-run Director 处理一个示例需求
2. Dry-run PM 处理 Director 产出
3. 验证 PM 无法改写 Director 锁定节；若改写则 gate/review 必须 FAIL
4. 验证下游 skill、contracts、hooks、tests、evals 可正常消费新结构或兼容入口
5. 验证两个 completion_check.sh 正确工作
6. 验证 `/product` 兼容入口（若保留）与新流程语义一致

---

## 关键风险与缓解

| 风险 | 缓解措施 |
|------|---------|
| repo 级 `/product` 消费者遗漏 | Phase 0 先全文盘点；切换前必须覆盖 contracts/hooks/tests/evals/skill 引用 |
| brief.md 双方写入冲突 | D-G1 后冻结 Director 锁定节；PM 只能写允许补充的节；M-S8/M-G1 强制做差异检查 |
| `scope_item_id` 过早生成又被改写 | Director 不再输出 `SCOPE-*` 占位值；PM 在 UNIT 归属确定后一次性生成最终 ID |
| PM 缺少 Director 对话中的隐性信息 | 这是设计意图（从工件出发消除噪音），但必须通过锁定节 + 共创摘要避免 PM 反向改写上游意图 |
| 既有项目兼容 | PM 的 M-S0 检测旧格式 brief.md（无总监确认节），按遗留项目处理，并单独声明兼容边界 |
| `/product` 兼容入口语义不清 | 明确它是兼容/编排入口，不允许再默默保留旧的职责混合实现 |

---

## 关键文件清单

| 文件 | 操作 |
|------|------|
| `contracts/skill-chain.yaml` | 调整链路定义与迁移/兼容策略 |
| `shared/hooks/registry.json` | 拆分 product 条目并同步兼容入口策略 |
| `shared/skills/product/SKILL.md` | 改为兼容入口或最终 stub（取决于迁移阶段） |
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
| 其他 `tests/**`、`tools/eval/**` 中直接引用 `product` 的文件 | 按 Phase 0 盘点结果同步迁移或纳入兼容入口 |

