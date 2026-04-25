# Small-Chain 产出物质量强化 — 新窗口输入

## 背景

刚完成一轮以朋友团队的"客户管理 PRD"为标尺的逆向评估，修复了 product-manager 的 prd.md 模板（从 1 个 UNIT 索引表扩充为 12+ 章节）。修复过程中发现 small-chain 自身的三个核心产出物（design.md、tasks.md、plan.md）缺乏结构化的质量下限保障。

设计文档归档在 `docs/archive/product-prd-gap-analysis-20260417/design.md`。

## 已完成的工作（不需要重做）

- product-manager 的 phase-prd-template.md 已扩充（164 行，含 Mermaid 骨架、通用交互规范、P0/P1/P2 定义、QA 测试重点起始项等）
- brief-template.md 业务对象表已加"状态流转"必填列
- completeness-checklist.md 已扩展到 C1-C12
- product-manager SKILL.md 步骤表已更新（M-S1~M-S5 加 prd.md 写入要求）
- design/test-design/consistency-audit 下游 skill 已传播更新

## 本次目标

强化 small-chain 三个核心产出物的质量下限，确保"轻量流程但产出不打折"。

### 产出物 1: design.md（brainstorming skill 产出）

**现状问题**：brainstorming skill 产出 design.md 时没有等价于 product-manager C1-C12 的完整性检查。质量取决于当次对话深度，无结构化保障。

**预期修复方向**：给 brainstorming 加一个"设计完整性检查表"，在 design.md 定稿前强制逐项检查。候选维度：
- 成功标准（可量化？有基线和目标值？）
- 变更范围（涉及文件清单穷举？改动类型和量级？）
- 不变量（明确不改动的部分？）
- 风险（主要风险 + 缓解措施？）
- 下游影响（变更是否影响其他 skill/模块？传播了吗？）
- 验证方式（每个成功标准有验证命令/方法？）

### 产出物 2: tasks.md（writing-plans skill 产出）

**现状问题**：
1. AC 与 design.md 成功标准之间无显式追踪（哪个 task 覆盖哪个成功标准？）
2. 任务间无依赖声明（哪些可以并行，哪些必须串行？）
3. 无复杂度信号（subagent-driven-development 需要据此选模型，但 tasks.md 没给信号）

**预期修复方向**：扩充 tasks.md 模板，加追踪、依赖、复杂度字段。

### 产出物 3: plan.md（writing-plans skill 产出）

**现状问题**：task section 缺"why"上下文。subagent 能机械执行但不知道为什么做这个改动，遇到边界情况无法自主判断。

**预期修复方向**：每个 task section 加 context/rationale 字段。

## 优先级

design.md 完整性检查 > tasks.md 追踪/依赖 > plan.md 上下文

## 需要读取的文件

| 文件 | 目的 |
|------|------|
| `~/.claude/skills/brainstorming/SKILL.md` | brainstorming skill 完整定义，理解 design.md 产出流程 |
| `~/.claude/skills/writing-plans/SKILL.md` | writing-plans skill 完整定义，理解 tasks.md/plan.md 产出流程 |
| `~/.claude/skills/subagent-driven-development/SKILL.md` | 理解下游如何消费 tasks.md/plan.md |
| `~/.claude/skills/subagent-driven-development/implementer-prompt.md` | 理解 subagent 实际收到什么上下文 |
| `~/.claude/skills/subagent-driven-development/spec-reviewer-prompt.md` | 理解 spec review 检查什么 |
| `docs/archive/product-prd-gap-analysis-20260417/design.md` | 上一轮的实际 design.md 产出，作为质量参照 |
| `docs/archive/product-prd-gap-analysis-20260417/tasks.md` | 上一轮的实际 tasks.md 产出，作为质量参照 |
| `docs/archive/product-prd-gap-analysis-20260417/plan.md` | 上一轮的实际 plan.md 产出，作为质量参照 |
| `shared/skills/product-manager/references/completeness-checklist.md` | C1-C12 作为"完整性检查表"的设计参照 |

## 约束

- 改动范围只涉及 brainstorming 和 writing-plans 两个 skill
- 不改 subagent-driven-development 的终结链 HARD-GATE（那是独立的 P0 修复，可以另开或合并做）
- 遵循现有 skill 的设计风格（HARD-GATE + 步骤表 + 参考文件分离）
- 用 `/brainstorming` 走完整链路（brainstorming → writing-plans → 实施）

## 启动指令

```
/brainstorming 强化 small-chain 三个核心产出物（design.md、tasks.md、plan.md）的质量下限。详细背景和修复方向见 docs/small-chain-artifact-quality-input.md
```
