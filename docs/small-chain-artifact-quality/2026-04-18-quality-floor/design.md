# Small-Chain 产出物质量下限强化

功能名: small-chain-artifact-quality | 产出时间: 2026-04-18

## Why

small-chain 的三个核心产出物（design.md、tasks.md、plan.md）的质量取决于当次对话深度，无结构化的下限保障。上游产出质量不稳定，下游（subagent-driven-development）消费时遇到追踪缺失、依赖不明、复杂度信号缺失、设计意图丢失等问题。product-manager 的 C1-C12 检查表已证明"结构化检查 → 稳定质量下限"模式有效，本次将同一模式应用到 small-chain 的三个产出物上。

## Scope

- In scope:
  - 在 `contracts/small-chain.yaml` 中为 design.md、tasks.md、plan.md 声明 key_fields
  - 扩充 brainstorming 的 `design-template.md`，新建 `design-completeness-checklist.md`
  - 扩充 writing-plans 的 tasks.md 模板（加 Traces/Depends/Complexity）
  - 扩充 writing-plans 的 plan.md task section 结构（加 Context）
  - 扩充 writing-plans 的 HARD-GATE（加 3 项检查）
  - 更新 `contracts/superpowers-boundary.yaml` 声明分叉
- Out of scope:
  - subagent-driven-development 的终结链 HARD-GATE
  - subagent-driven-development 的 model selection 逻辑
  - product-manager/design/test-design 等 skill（上一轮已完成）
  - 自动化脚本（check_design_completeness.py 等）

## Goals & Success Criteria

| 目标 | 成功标准 | 验证方式 |
|------|---------|---------|
| design.md 内容完整性有结构化保障 | brainstorming SKILL.md spec self-review 包含第 5 项"Content completeness"，引用 design-completeness-checklist.md | grep SKILL.md 确认步骤存在 |
| design.md 检查表与契约对齐 | design-completeness-checklist.md 的 D1-D8 与 small-chain.yaml design.md key_fields 一一对应 | 人工对照两个文件 |
| tasks.md 有追踪/依赖/复杂度字段 | tasks.md 模板包含 Traces/Depends/Complexity 三个字段及说明 | grep writing-plans SKILL.md 确认字段存在 |
| plan.md 有上下文字段 | plan.md task section 模板包含 Context 字段 | grep writing-plans SKILL.md 确认字段存在 |
| HARD-GATE 覆盖新字段 | writing-plans HARD-GATE 包含 Trace completeness、Dependency validity、Context presence 三项检查 | grep writing-plans SKILL.md 确认检查项存在 |
| overlay 声明完整 | superpowers-boundary.yaml 包含新增 declared_forks 和 overlay_files | 读取文件确认 |

## Approach

**契约驱动、职责分离**：

1. **契约层**（`contracts/small-chain.yaml`）：定义每个产出物必须包含的 key_fields，作为质量要求的权威来源
2. **模板层**（`design-template.md`）：写作结构参考，引用契约；不定义规则，只提供结构
3. **检查层**（`design-completeness-checklist.md`）：验证程序，引用契约的 key_fields 逐项检查
4. **流程层**（`SKILL.md`）：在适当环节引用检查表

每一层只做一件事，不重复其他层的职责。上游更新时，契约层是唯一需要对照的权威源。

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| 只加检查表，不加契约 | 改动更少 | 检查表的"规则"来源不明确，模板和检查表可能不一致 | 否决——缺权威源 |
| 契约 + 检查表 + 模板 | 职责分离清晰，每层引用契约 | 多一个文件（契约层） | 采纳 |
| 契约 + 检查表 + 模板 + 自动化脚本 | 可机器验证 | 引入 Python 脚本增加维护成本；成功标准 ID 编号增加对话摩擦 | 否决——ROI 不足 |

## Key Decisions

- D1: 检查表维度用 D1-D8（8 项），不用 C1-C12 的 12 项 — Reason: design doc 和 PRD 服务不同目的，8 维覆盖工程准备度需要，不需要用户交互/数据模型等 PRD 维度
- D2: Traces 字段用自然语言引用成功标准名，不用形式化 ID — Reason: brainstorming 对话中编号增加认知负担，LLM 能理解自然语言映射
- D3: Complexity 三档信号（simple/moderate/complex），不做更细粒度 — Reason: 与 subagent-driven-development Model Selection 的三层对应，不增加无消费者的维度
- D4: 新文件放 `community/superpowers/` 仓库副本内而非 `~/.claude/skills/` — Reason: 仓库是版本控制和 overlay 管理的权威源，安装到 skills 目录是部署行为
- D5: HARD-GATE 扩充而非新增独立 GATE — Reason: 现有 HARD-GATE 已是 writing-plans 的定稿检查点，扩充比新增步骤的流程摩擦更小

## Change Scope

| 文件 | 改动类型 | 改动量级 |
|------|---------|---------|
| `contracts/small-chain.yaml` | 扩充 brainstorming/writing-plans outputs 的 key_fields | 小（~20 行） |
| `community/superpowers/skills/brainstorming/references/design-template.md` | 扩充节（Why/Scope/Approach/Alternatives/Key Decisions/Success Criteria → 加 Change Scope/Invariants/Downstream Impact/Risks） | 中（~40 行新增） |
| `community/superpowers/skills/brainstorming/references/design-completeness-checklist.md` | 新建 | 中（~35 行） |
| `community/superpowers/skills/brainstorming/SKILL.md` | spec self-review 加第 5 项 | 极小（~3 行） |
| `community/superpowers/skills/writing-plans/SKILL.md` | tasks.md 模板扩充 + plan.md task section 加 Context + HARD-GATE 加 3 项 | 中（~30 行改动） |
| `contracts/superpowers-boundary.yaml` | 加 2 个 declared_forks + 1 个 overlay_files | 小（~10 行） |

## Invariants

> 与 Out of scope 的区别：Out of scope 是"不做的事"，Invariants 是"已有且不能破坏的事"。

- brainstorming 的对话流程（探索→方案→设计→确认）不变
- brainstorming spec self-review 现有 4 项检查（placeholder/consistency/scope/ambiguity）保持原样
- writing-plans self-review 现有 3 项检查（spec coverage/placeholder scan/type consistency）保持原样
- writing-plans HARD-GATE 现有 4 项检查（task-plan mapping/AC verifiability/design.md coverage/placeholder scan）保持原样
- subagent-driven-development 的所有文件（SKILL.md、implementer-prompt.md、spec-reviewer-prompt.md、code-quality-reviewer-prompt.md）不改动
- verify-change、finishing-a-development-branch、archive 不改动
- small-chain.yaml 的 chain 结构（节点顺序、inputs/outputs/consumers）不变，仅追加 key_fields

## Downstream Impact

| 受影响模块 | 影响方式 | 是否需要传播改动 |
|-----------|---------|---------------|
| subagent-driven-development | controller 消费 tasks.md 的新字段（Traces/Depends/Complexity）和 plan.md 的 Context 字段。新字段是附加信息，不改变现有格式（仍然是 `- [ ] T1` 开头），向后兼容 | 否——controller 自然消费新字段，不需要改代码 |
| verify-change | 读取 design.md 的成功标准。模板扩充后成功标准位置不变（Goals & Success Criteria 节），格式兼容 | 否 |
| check_task_plan_consistency.py | 已有脚本检查 task-plan mapping。新字段不影响已有检查逻辑 | 否 |
| `~/.claude/skills/` 安装目录 | 仓库文件修改后需同步到 skills 安装目录 | 是——实施完成后手动同步或通过部署流程同步 |

## Risks

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 社区 upstream 更新覆盖本地 overlay | 需要重新合并改动 | declared_forks 文档化分叉点和原因，合并时有明确的对照清单 |
| 检查表增加 brainstorming 流程耗时 | 每次 design.md 定稿多 1-2 分钟检查 | 8 项检查都是结构化判断，LLM 可快速完成；与 C1-C12 在 product-manager 中的实践一致 |
| Traces 自然语言引用导致模糊匹配 | HARD-GATE 检查 Trace completeness 时可能误判 | Traces 引用的是 Goals & Success Criteria 表中的"目标"列值，表格行明确，匹配歧义低 |
| tasks.md 新字段增加 writing-plans 产出时间 | 每个 task 多写 3 行 | 字段值简短（Traces 几个词、Depends 1-2 个 ID、Complexity 一个词），总增量可控 |

---

## 修复设计详述

### 修复 1：契约层 — small-chain.yaml key_fields

在现有 brainstorming outputs `design.md` 和 writing-plans outputs `tasks.md`、`plan.md` 下追加 key_fields 声明。

**design.md key_fields：**

```yaml
key_fields:
  always_required:
    - problem_statement
    - goals_success_criteria
    - approach
    - alternatives_considered
    - risks
  conditionally_required:
    - change_scope           # 修改型必填
    - invariants             # 修改型必填
    - downstream_impact      # 有下游消费者时必填
```

**tasks.md key_fields：**

```yaml
key_fields:
  per_task:
    - deliverable
    - acceptance_criteria
    - traces
    - depends
    - complexity
```

**plan.md key_fields：**

```yaml
key_fields:
  per_task_section:
    - context
    - files
    - steps
```

### 修复 2：design-template.md 扩充

在现有 6 节（Why/Scope/Approach/Alternatives Considered/Key Decisions/Success Criteria）基础上：

1. `Success Criteria` 升级为 `Goals & Success Criteria` 表格，加"验证方式"列
2. 新增 4 节：`Change Scope`、`Invariants`（含与 Out of scope 的区别说明）、`Downstream Impact`、`Risks`
3. 每节标注必填条件和 N/A 规则
4. 头部加契约引用：`> 结构参照：contracts/small-chain.yaml → brainstorming → design.md key_fields`

### 修复 3：新建 design-completeness-checklist.md

8 项检查（D1-D8），每项对应 small-chain.yaml 的一个 key_field：

| # | 维度 | 对应 key_field | 必填条件 |
|---|------|---------------|---------|
| D1 | 问题陈述 | problem_statement | 总是 |
| D2 | 目标与成功标准 | goals_success_criteria | 总是 |
| D3 | 方案设计 | approach | 总是 |
| D4 | 备选方案 | alternatives_considered | 总是 |
| D5 | 变更范围 | change_scope | 修改型 |
| D6 | 不变量 | invariants | 修改型 |
| D7 | 下游影响 | downstream_impact | 有下游消费者 |
| D8 | 风险 | risks | 总是 |

判定规则：D1、D2、D3、D4、D8 不允许 Missing；D5、D6、D7 可标 N/A（须附原因）。

### 修复 4：brainstorming SKILL.md spec self-review 扩充

在现有 4 项检查之后追加第 5 项：

```
5. Content completeness
   - Run `references/design-completeness-checklist.md` against the spec.
   - Fix any Missing or Partial items inline.
```

### 修复 5：writing-plans SKILL.md tasks.md 模板扩充

现有模板：
```markdown
- [ ] T1 {deliverable description}
  - AC: {verifiable criteria}
```

扩充为：
```markdown
- [ ] T1 {deliverable description}
  - AC: {verifiable criteria}
  - Traces: {design.md Goals & Success Criteria 表中的目标名}
  - Depends: {依赖的 task ID，无依赖写 -}
  - Complexity: {simple | moderate | complex}
```

### 修复 6：writing-plans SKILL.md plan.md task section 扩充

现有结构：
```markdown
### Task N: [Component Name] [T{N}]

Files:
- Create: `path`
```

扩充为：
```markdown
### Task N: [Component Name] [T{N}]

Context: {1-2 句设计意图和关键约束}

Files:
- Create: `path`
```

### 修复 7：writing-plans SKILL.md HARD-GATE 扩充

在现有 4 项检查之后追加 3 项：

```
5. Trace completeness
   - Every success criterion in design.md Goals & Success Criteria
     is referenced by at least one task's Traces field.
6. Dependency validity
   - Every task ID in Depends fields exists in tasks.md.
   - No circular dependencies.
7. Context presence
   - Every task section in plan.md has a non-empty Context field.
```

### 修复 8：superpowers-boundary.yaml 更新

新增 declared_forks：
```yaml
- id: brainstorming_design_completeness_gate
  scope: community/superpowers/skills/brainstorming
  reason: add design completeness checklist (D1-D8) and expanded template per small-chain.yaml key_fields
  owner_source: contracts/superpowers-boundary.yaml

- id: writing_plans_task_traceability
  scope: community/superpowers/skills/writing-plans/SKILL.md
  reason: add Traces/Depends/Complexity to tasks.md template, Context to plan.md, and 3 HARD-GATE checks
  owner_source: contracts/superpowers-boundary.yaml
```

新增 overlay_files：
```yaml
- community/superpowers/skills/brainstorming/references/design-completeness-checklist.md
```
