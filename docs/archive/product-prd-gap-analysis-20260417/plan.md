# Product PRD Gap Analysis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Enrich product-manager's PRD output template and propagate changes to downstream skills so the PRD can be directly consumed by dev/test/ops teams.

**Architecture:** Modify 7 markdown files across 4 skills (product-manager, product-director, design, test-design, analyze). All changes are template/specification updates — no code logic changes.

**Tech Stack:** Markdown templates, SKILL.md specifications

---

### Task 1: Expand phase-prd-template.md [T1]

Files:
- Modify: `shared/skills/product-manager/references/templates/phase-prd-template.md`

1. [T1] Replace the entire content of `shared/skills/product-manager/references/templates/phase-prd-template.md` with the expanded template:

```markdown
# Phase {N}: [阶段目标]

## 阶段目标

[从 Director D-S6 继承]

## 入口与出口条件

[从 Director D-S6 继承]

## 业务流程

[M-S1 共创成果：按子模块/子流程画 Mermaid 图，每个核心流程一张图]

### 流程协同规则

[跨模块/跨流程的协同规则，如"储备客户承担线索经营；签约后转入成交客户模块建档"]

## 页面清单与组装视图

[M-S2 共创成果：页面→UNIT 映射。有 UI 的产品必填；纯后端/CLI/API 产品标注 N/A 并说明原因]

| 页面ID | 页面名称 | 路由 | 承载 UNIT | 核心交互 |
|--------|---------|------|----------|---------|

### 页面跳转与联动关系

| 来源页面 | 触发动作 | 目标页面/弹窗 | 关系类型 | 说明 |
|---------|---------|-------------|---------|------|

### 页面状态要求

| 状态 | 适用页面 | 表现要求 |
|------|---------|---------|
| 初始加载 | | 展示页面级加载状态，禁止空白页 |
| 查询中 | | 展示区域级 loading，防止重复点击 |
| 空状态 | | 显示"暂无数据"提示，保留筛选区 |
| 查询失败 | | 显示错误提示，提供重试入口 |
| 无权限 | | 隐藏按钮或提示无权限 |
| 提交成功 | | 明确反馈成功结果 |
| 提交失败 | | 明确反馈失败原因，保留上下文 |

## 角色权限矩阵

[M-S3 共创成果：结构化权限定义。多角色系统必填；单用户/无权限区分的产品标注 N/A 并说明原因]

| 角色 | [模块1] | [模块2] | ... |
|------|---------|---------|-----|

## 功能清单

### 模块能力矩阵

| 模块 | 查询 | 新增/登记 | 详情 | 记录查看 | 批量操作 | 导出 |
|------|------|----------|------|---------|---------|------|

### 功能清单表

| ID | 功能名称 | 优先级 | 端 | 描述 | 对应 UNIT |
|----|---------|--------|---|------|----------|

## 功能需求（UNIT 索引）

| UNIT | 标题 | 闭环目标 | 优先级 | 依赖 | 定义文件 |
|------|------|----------|--------|------|----------|
| [UNIT-ID] | [功能标题] | [输入/触发 -> 核心行为 -> 可观察结果] | [MVP/增强/扩展] | [无 / UNIT-N] | [units/UNIT-N.md] |

## 业务对象状态与枚举

[有状态流转的业务对象必填；无状态对象标注 N/A 并说明原因]

| 对象 | 状态/枚举 | 值列表 | 流转规则 | 说明 |
|------|----------|--------|---------|------|

## 字段校验矩阵

[有表单输入的产品必填；无表单的产品标注 N/A 并说明原因]

| 业务场景 | 字段 | 必填 | 校验规则 | 失败提示方向 |
|---------|------|------|---------|------------|

## 高风险操作清单

[有写操作/批量操作的产品必填；只读产品标注 N/A 并说明原因]

| 操作 | 模块 | 风险点 | 前端控制 | 后端控制 | 日志要求 |
|------|------|--------|---------|---------|---------|

## 验收标准

### 功能验收

| PRD编号 | 功能 | 验收条件 | 优先级 | 验证方式 |
|---------|------|---------|--------|---------|

### 流程验收

| 流程 | 验收项 | 验收标准 |
|------|--------|---------|

### 安全验收

| 类别 | 验收项 | 验收标准 |
|------|--------|---------|

## QA 测试重点

| 类别 | 测试重点 |
|------|---------|
```

2. [T1] Verify the file contains all 13 sections

Run: `grep -c '^## ' shared/skills/product-manager/references/templates/phase-prd-template.md`
Expected: 13 (阶段目标, 入口与出口条件, 业务流程, 页面清单与组装视图, 角色权限矩阵, 功能清单, 功能需求, 业务对象状态与枚举, 字段校验矩阵, 高风险操作清单, 验收标准, QA 测试重点 — 页面跳转/页面状态/模块能力/功能清单表 are ### subsections)

3. [T1] Commit

```bash
git add shared/skills/product-manager/references/templates/phase-prd-template.md
git commit -m "feat(product-manager): expand phase-prd-template with 11 new content sections

Add business process diagrams, page assembly view, role-permission matrix,
feature catalog, state machines, field validation, risk operations,
acceptance criteria, and QA testing priorities to the PRD template."
```

---

### Task 2: Update brief-template.md business objects table [T2]

Files:
- Modify: `shared/skills/product-director/references/templates/brief-template.md`

1. [T2] In `shared/skills/product-director/references/templates/brief-template.md`, replace the business objects section:

Find:
```markdown
## 业务对象

| 对象 | 说明 | 关键状态/属性 |
|------|------|---------------|
```

Replace with:
```markdown
## 业务对象

| 对象 | 说明 | 状态流转 | 关键属性 |
|------|------|----------|----------|

> 状态流转必填：列出对象的状态值和转换关系（如 `潜在→试用→正式→逾期`）。无状态流转的对象填"无状态"并说明原因。
```

2. [T2] Verify the change

Run: `grep '状态流转' shared/skills/product-director/references/templates/brief-template.md`
Expected: Two matches — table header and instruction note

3. [T2] Commit

```bash
git add shared/skills/product-director/references/templates/brief-template.md
git commit -m "feat(product-director): require state transitions in business objects table

Split '关键状态/属性' into '状态流转' (required) and '关键属性' columns
to ensure business object state machines are defined at PRD level."
```

---

### Task 3: Update completeness-checklist.md [T3]

Files:
- Modify: `shared/skills/product-manager/references/completeness-checklist.md`

1. [T3] Replace the entire content of `shared/skills/product-manager/references/completeness-checklist.md`:

```markdown
# 需求完整性检查表（12 类分类法）

## 使用方式

在 Manager 收口前，逐类扫描并标记状态。Partial / Missing 的类别必须追问，或显式标注"不适用（原因）"。

## 12 类检查

| # | 类别 | 检查要点 | 状态 |
|---|------|---------|------|
| C1 | 功能域 | 核心功能是否已定义？正常 / 异常 / 边界流程是否覆盖？是否有按子模块的 Mermaid 业务流程图？是否有功能清单表 + 模块能力矩阵？ | Clear / Partial / Missing |
| C2 | 数据模型 | 业务对象、字段、关系、生命周期是否明确？业务对象是否定义了状态流转？是否有状态/枚举定义表？ | Clear / Partial / Missing |
| C3 | 用户交互 | 输入方式、反馈形式、操作流程是否定义？是否有页面清单与组装视图（页面→UNIT 映射）？页面跳转与联动关系是否定义？页面状态要求（加载/空/错误/无权限）是否覆盖？ | Clear / Partial / Missing |
| C4 | 非功能需求 | 性能、安全、可用性、可观测性是否有量化标准？ | Clear / Partial / Missing |
| C5 | 集成边界 | 外部系统、API、第三方服务的接口和契约是否明确？ | Clear / Partial / Missing |
| C6 | 边界条件 | 数据量上限、并发上限、极端输入是否定义？是否有字段校验矩阵？ | Clear / Partial / Missing |
| C7 | 约束条件 | 技术约束、业务约束、合规要求是否列出？ | Clear / Partial / Missing |
| C8 | 术语定义 | 领域术语是否有统一定义？是否存在歧义术语？ | Clear / Partial / Missing |
| C9 | 完成信号 | MVP 范围是否明确？上线标准是否可验证？成功信号是否包含基线、目标值/方向、观测窗口和数据来源？是否有全局验收标准（功能+流程+安全）？ | Clear / Partial / Missing |
| C10 | 风险前瞻 | Pre-mortem：最可能的失败原因是什么？是否有高风险操作清单（含前端控制、后端控制、日志要求）？ | Clear / Partial / Missing |
| C11 | 角色权限 | 是否有角色×模块权限矩阵？各角色的查询/新增/修改/删除/导出权限是否明确？ | Clear / Partial / Missing |
| C12 | QA 交接 | 是否有 QA 测试重点（按类别列出优先测试区域）？ | Clear / Partial / Missing |

## 判定规则

- 全部 Clear → 可进入输出
- 存在 Partial → 必须追问补充，或记录已知不完整及原因
- 存在 Missing → 必须追问，不允许默认跳过
- C1、C9 与 C11 不允许 Missing
```

2. [T3] Verify the new checklist

Run: `grep -c '^| C' shared/skills/product-manager/references/completeness-checklist.md`
Expected: 12

3. [T3] Commit

```bash
git add shared/skills/product-manager/references/completeness-checklist.md
git commit -m "feat(product-manager): expand completeness checklist to C1-C12

Add specific checks for Mermaid diagrams, page assembly, state machines,
field validation, risk operations, acceptance criteria. New C11 (role
permissions) and C12 (QA handoff). C11 now mandatory alongside C1/C9."
```

---

### Task 4: Update product-manager SKILL.md step table [T4]

Files:
- Modify: `shared/skills/product-manager/SKILL.md:77-89`

1. [T4] In `shared/skills/product-manager/SKILL.md`, replace the step table (lines 77-89):

Find:
```
| M-S1 | 详细业务流程分析 | 全共创 | 逐 Phase 展开目标流程为具体操作步骤和业务对象状态变化 |
| M-S2 | 用户场景路径 | 全共创 | 走通用户操作路径，识别功能断点与 UNIT 边界前提 |
| M-S3 | 业务规则映射 | 全共创 | 把 Director 的业务规则映射到具体功能，并识别跨切规则 |
| M-S4 | UNIT 拆解 | 全共创 | 逐个 UNIT 共创：候选边界、闭环定义、初始 AC；每个 Phase 控制在 3-7 UNIT |
| M-S5 | AC 细化 | 草案修正 | 把正常 / 异常 / 边界场景补齐为可验证 AC |
```

Replace with:
```
| M-S1 | 详细业务流程分析 | 全共创 | 逐 Phase 展开目标流程为具体操作步骤和业务对象状态变化；共创成果写入 prd.md `## 业务流程`（按子模块画 Mermaid 图）和 `### 流程协同规则` |
| M-S2 | 用户场景路径 | 全共创 | 走通用户操作路径，识别功能断点与 UNIT 边界前提；共创成果写入 prd.md `## 页面清单与组装视图`（页面→UNIT 映射）、`### 页面跳转与联动关系`、`### 页面状态要求` |
| M-S3 | 业务规则映射 | 全共创 | 把 Director 的业务规则映射到具体功能，并识别跨切规则；共创成果写入 prd.md `## 角色权限矩阵`、`## 字段校验矩阵`、`## 高风险操作清单` |
| M-S4 | UNIT 拆解 | 全共创 | 逐个 UNIT 共创：候选边界、闭环定义、初始 AC；每个 Phase 控制在 3-7 UNIT；共创成果写入 prd.md `## 功能清单`（功能清单表 + 模块能力矩阵）和 `## 业务对象状态与枚举` |
| M-S5 | AC 细化 | 草案修正 | 把正常 / 异常 / 边界场景补齐为可验证 AC；共创成果写入 prd.md `## 验收标准`（功能+流程+安全验收）和 `## QA 测试重点` |
```

2. [T4] In the same file, update M-S7 checklist reference:

Find:
```
| M-S7 | 完整性扫描 | 条件共创 | 读取 `references/completeness-checklist.md`，完成 C1-C10 扫描 |
```

Replace with:
```
| M-S7 | 完整性扫描 | 条件共创 | 读取 `references/completeness-checklist.md`，完成 C1-C12 扫描 |
```

3. [T4] Verify the changes

Run: `grep 'prd.md' shared/skills/product-manager/SKILL.md | head -10`
Expected: Multiple lines showing M-S1 through M-S5 referencing prd.md sections

Run: `grep 'C1-C12' shared/skills/product-manager/SKILL.md`
Expected: One match in M-S7 row

4. [T4] Commit

```bash
git add shared/skills/product-manager/SKILL.md
git commit -m "feat(product-manager): add prd.md write-through requirements to M-S1~M-S5

Each co-creation step now explicitly writes results to the corresponding
prd.md section. M-S7 completeness scan updated from C1-C10 to C1-C12."
```

---

### Task 5: Update design SKILL.md S1 input extraction [T5]

Files:
- Modify: `shared/skills/design/SKILL.md:119-122`

1. [T5] In `shared/skills/design/SKILL.md`, update S1 input extraction:

Find:
```
   - 基于用户指定的 feature（$ARGUMENTS）读取 `brief.md`（目标、影响范围、GAC-*、DD-*、CON-*）+ `phase-{N}/prd.md`（阶段目标、UNIT 索引）+ `phase-{N}/units/UNIT-*.md`。
```

Replace with:
```
   - 基于用户指定的 feature（$ARGUMENTS）读取 `brief.md`（目标、影响范围、GAC-*、DD-*、CON-*）+ `phase-{N}/prd.md`（阶段目标、业务流程、页面组装视图、角色权限矩阵、功能清单、状态/枚举定义、高风险操作、验收标准、UNIT 索引）+ `phase-{N}/units/UNIT-*.md`。
```

2. [T5] Verify the change

Run: `grep '页面组装视图' shared/skills/design/SKILL.md`
Expected: One match in S1 step

3. [T5] Commit

```bash
git add shared/skills/design/SKILL.md
git commit -m "feat(design): update S1 input list to consume enriched PRD sections

Design S1 now extracts business processes, page assembly views, role
permissions, feature catalog, state definitions, risk operations, and
acceptance criteria from prd.md alongside UNIT index."
```

---

### Task 6: Update test-design SKILL.md [T6]

Files:
- Modify: `shared/skills/test-design/SKILL.md:38-44,66-67`

1. [T6] In `shared/skills/test-design/SKILL.md`, update the prerequisites section:

Find:
```
- `docs/{feature}/phase-{N}/prd.md` 必须存在（UNIT 索引）
```

Replace with:
```
- `docs/{feature}/phase-{N}/prd.md` 必须存在（UNIT 索引、QA 测试重点、高风险操作清单、角色权限矩阵）
```

2. [T6] In step 1 (按 UNIT 建立功能视图), update the extraction description:

Find:
```
   - 基于用户指定的 feature（$ARGUMENTS），从 `brief.md + phase-{N}/prd.md + phase-{N}/units/` 提取闭环功能、验收标准与排除项。
```

Replace with:
```
   - 基于用户指定的 feature（$ARGUMENTS），从 `brief.md + phase-{N}/prd.md + phase-{N}/units/` 提取闭环功能、验收标准、排除项、QA 测试重点、高风险操作清单与角色权限矩阵。
```

3. [T6] In step 6 (按 UNIT 设计基础用例), add PRD-driven test rules after the existing description:

Find:
```
6. 按 UNIT 设计基础用例
   - 先按 UNIT 分组，再为每条 AC 设计正例 / 反例 / 边界。
```

Replace with:
```
6. 按 UNIT 设计基础用例
   - 先按 UNIT 分组，再为每条 AC 设计正例 / 反例 / 边界。
   - PRD 驱动的补充用例规则：
     - 高风险操作清单中的每个操作，至少 1 个确认机制验证用例 + 1 个日志留痕验证用例
     - 角色权限矩阵中的每个角色×模块组合，至少 1 个正向权限用例 + 1 个越权拒绝用例
     - QA 测试重点中的每个类别，作为用例优先级排序的权重因子
```

4. [T6] Verify the changes

Run: `grep '高风险操作清单' shared/skills/test-design/SKILL.md`
Expected: 3 matches (prerequisites, step 1 extraction, step 6 rules)

5. [T6] Commit

```bash
git add shared/skills/test-design/SKILL.md
git commit -m "feat(test-design): consume PRD risk/permission/QA sections

Prerequisites now require QA testing priorities, risk operations, and
role permissions from prd.md. Step 6 adds rules to generate test cases
from high-risk operations and role-permission matrix combinations."
```

---

### Task 7: Update analyze check-matrix.md L1 [T7]

Files:
- Modify: `shared/skills/analyze/references/check-matrix.md:1-11`

1. [T7] In `shared/skills/analyze/references/check-matrix.md`, add 4 new L1 checks after L1-5:

Find:
```
| L1-5 | Constitution 合规 | design.md 是否与 docs/constitution.md（如存在）的原则一致？ |
```

Replace with:
```
| L1-5 | Constitution 合规 | design.md 是否与 docs/constitution.md（如存在）的原则一致？ |
| L1-6 | 页面组装视图承接 | PRD 的页面清单与组装视图是否在 design.md 中有对应的页面/模块设计？ |
| L1-7 | 状态/枚举承接 | PRD 的业务对象状态与枚举定义是否在 design.md 数据模型中承接？ |
| L1-8 | 权限方案承接 | PRD 的角色权限矩阵是否在 design.md 中有对应的权限设计方案？ |
| L1-9 | 高风险操作控制 | PRD 的高风险操作清单是否在 design.md 中有对应的控制方案（确认机制/日志/回退）？ |
```

2. [T7] Verify the new check items

Run: `grep -c '^| L1-' shared/skills/analyze/references/check-matrix.md`
Expected: 9

3. [T7] Commit

```bash
git add shared/skills/analyze/references/check-matrix.md
git commit -m "feat(analyze): add L1-6~L1-9 checks for enriched PRD sections

New consistency checks verify Design承接 for page assembly views,
state/enum definitions, role permissions, and high-risk operations
defined in the expanded PRD template."
```
